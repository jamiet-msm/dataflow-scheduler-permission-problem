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
  region = var.region
}



variable "project" {}
variable "region" {}

variable "network" {
    default = "default"
}
variable "subnetwork" {
    default = ""
}

resource "google_storage_bucket" "bucket" {
  name          = "${var.project}-df-demo"
  location      = "EU"
  force_destroy = true
  uniform_bucket_level_access = true
}
resource "google_storage_bucket_object" "transform_js" {
  name   = "transform.js"
  source = "./transform.js"
  bucket = google_storage_bucket.bucket.name
}

resource "google_storage_bucket_object" "bqtable_schema_json" {
  name   = "bqtable-schema.json"
#   source = "./bqtable-schema.json"
  content = "{\"BigQuery Schema\": ${file("${path.module}/bqtable-schema.json")}}"
  bucket = google_storage_bucket.bucket.name
}

resource "google_storage_bucket_object" "lorem_ipsum" {
  name   = "loremipsum.txt"
  source = "./loremipsum.txt"
  bucket = google_storage_bucket.bucket.name
}

resource "google_bigquery_dataset" "bqdataset" {
    dataset_id = "dataflow_demo"
}
resource "google_bigquery_table" "bqtable"{
    dataset_id = google_bigquery_dataset.bqdataset.dataset_id
    table_id = "t"
    schema = file("${path.module}/bqtable-schema.json")
    deletion_protection = false
}

resource "google_service_account" "sa" {
    account_id   = "dataflow-demo"
}

resource "google_project_iam_member" "df_worker" {
  role    = "roles/dataflow.worker"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_project_iam_member" "storage_admin" {
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_project_iam_member" "bq_admin" {
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.sa.email}"
}


resource "google_dataflow_job" "big_data_job" {
  name              = "dataflow-job"
  template_gcs_path = "gs://dataflow-templates/latest/GCS_Text_to_BigQuery"
  service_account_email = google_service_account.sa.email
  temp_gcs_location = "gs://${google_storage_bucket.bucket.id}/tmp_dir"
  network = var.network
  subnetwork = "regions/${var.region}/subnetworks/${var.subnetwork}"
  parameters = {
      javascriptTextTransformGcsPath = "${google_storage_bucket.bucket.url}/${google_storage_bucket_object.transform_js.name}"
      JSONPath = "${google_storage_bucket.bucket.url}/${google_storage_bucket_object.bqtable_schema_json.name}"
      javascriptTextTransformFunctionName = "transform"
      outputTable = "${var.project}:${google_bigquery_table.bqtable.dataset_id}.${google_bigquery_table.bqtable.table_id}"
      bigQueryLoadingTemporaryDirectory = "${google_storage_bucket.bucket.url}/bq_tmp_dir"
      inputFilePattern = "${google_storage_bucket.bucket.url}/${google_storage_bucket_object.lorem_ipsum.name}"
  }
  on_delete = "cancel"
  depends_on = [
    google_project_iam_member.df_worker, google_project_iam_member.storage_admin, google_project_iam_member.bq_admin
  ]
}
