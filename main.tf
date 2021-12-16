terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.84.0"
    }

    google-beta = {
      source  = "hashicorp/google-beta"
      version = "3.84.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
}



variable "project" {}
variable "region" {}


resource "google_compute_network" "network" {
  name = "dataflow-demo"
  auto_create_subnetworks = true
}

resource "google_storage_bucket" "bucket" {
  name                        = "${var.project}-df-demo"
  location                    = "EU"
  force_destroy               = true
  uniform_bucket_level_access = true
}
resource "google_storage_bucket_object" "transform_js" {
  name   = "transform.js"
  source = "./transform.js"
  bucket = google_storage_bucket.bucket.name
}

resource "google_storage_bucket_object" "bqtable_schema_json" {
  name = "bqtable-schema.json"
  #   source = "./bqtable-schema.json"
  content = "{\"BigQuery Schema\": ${file("${path.module}/bqtable-schema.json")}}"
  bucket  = google_storage_bucket.bucket.name
}

resource "google_storage_bucket_object" "lorem_ipsum" {
  name   = "loremipsum.txt"
  source = "./loremipsum.txt"
  bucket = google_storage_bucket.bucket.name
}

resource "google_bigquery_dataset" "bqdataset" {
  dataset_id = "dataflow_demo"
}
resource "google_bigquery_table" "bqtable" {
  dataset_id          = google_bigquery_dataset.bqdataset.dataset_id
  table_id            = "t"
  schema              = file("${path.module}/bqtable-schema.json")
  deletion_protection = false
}

resource "google_service_account" "sa" {
  account_id = "dataflow-demo"
}

resource "google_project_iam_member" "df_worker" {
  role   = "roles/dataflow.worker"
  member = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_project_iam_member" "storage_admin" {
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_project_iam_member" "bq_admin" {
  role   = "roles/bigquery.admin"
  member = "serviceAccount:${google_service_account.sa.email}"
}


resource "google_dataflow_job" "dataflow_job" {
  name                  = "dataflow-job"
  template_gcs_path     = "gs://dataflow-templates/latest/GCS_Text_to_BigQuery"
  service_account_email = google_service_account.sa.email
  temp_gcs_location     = "gs://${google_storage_bucket.bucket.id}/tmp_dir"
  network               = google_compute_network.network.name
  parameters = {
    javascriptTextTransformGcsPath      = "${google_storage_bucket.bucket.url}/${google_storage_bucket_object.transform_js.name}"
    JSONPath                            = "${google_storage_bucket.bucket.url}/${google_storage_bucket_object.bqtable_schema_json.name}"
    javascriptTextTransformFunctionName = "transform"
    outputTable                         = "${var.project}:${google_bigquery_table.bqtable.dataset_id}.${google_bigquery_table.bqtable.table_id}"
    bigQueryLoadingTemporaryDirectory   = "${google_storage_bucket.bucket.url}/bq_tmp_dir"
    inputFilePattern                    = "${google_storage_bucket.bucket.url}/${google_storage_bucket_object.lorem_ipsum.name}"
  }
  on_delete = "cancel"
  depends_on = [
    google_project_iam_member.df_worker, google_project_iam_member.storage_admin, google_project_iam_member.bq_admin
  ]
}

locals {
  df_base_uri               = "https://dataflow.googleapis.com/v1b3/projects/${var.project}/locations/${var.region}"
  url_encoded_template_path = urlencode("gs://dataflow-templates/latest/GCS_Text_to_BigQuery")
}
resource "google_cloud_scheduler_job" "trigger_dataflow_job_via_api" {
  name      = "aaa-schedule-dataflow-job" #appear at top of alphabetically ordered list
  schedule  = "23 */6 * * *"
  time_zone = "Europe/London"
  http_target {
    http_method = "POST"
    uri         = "${local.df_base_uri}/templates:launch?gcsPath=${local.url_encoded_template_path}"

    headers = {
      "Content-Type" = "application/json"
    }
    body = base64encode(
      jsonencode(
        {
          jobName = "dataflow-job-from-scheduler"
          parameters = {
            javascriptTextTransformGcsPath      = "${google_storage_bucket.bucket.url}/${google_storage_bucket_object.transform_js.name}"
            JSONPath                            = "${google_storage_bucket.bucket.url}/${google_storage_bucket_object.bqtable_schema_json.name}"
            javascriptTextTransformFunctionName = "transform"
            outputTable                         = "${var.project}:${google_bigquery_table.bqtable.dataset_id}.${google_bigquery_table.bqtable.table_id}"
            bigQueryLoadingTemporaryDirectory   = "${google_storage_bucket.bucket.url}/bq_tmp_dir"
            inputFilePattern                    = "${google_storage_bucket.bucket.url}/${google_storage_bucket_object.lorem_ipsum.name}"
          }
          environment = {
            tempLocation        = "gs://dataflow-templates/latest/GCS_Text_to_BigQuery"
            network             = google_compute_network.network.name
            serviceAccountEmail = google_service_account.sa.email
          }
        }
      )
    )
    oauth_token {
      service_account_email = google_service_account.sa.email
    }
  }
}



data "google_project" "project" {}

  
resource "google_project_iam_member" "sa_may_act_as_any_service_account" {
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.sa.email}"
}


