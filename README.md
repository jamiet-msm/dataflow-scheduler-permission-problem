
Assumes you have authenticated to GCP on your host by running `gcloud auth login` & `gcloud auth application-default`


To run the demo, issue:

```bash
export PROJECT=your_gcp_project
export REGION=your_gcp_region #e.g. europe-west2, us-central1, etc...
docker run -it -v $(pwd):/tf -w /tf hashicorp/terraform init 
docker run -it -v ~/.config/gcloud:/root/.config/gcloud \
        -v $(pwd):/tf \
        -w /tf \
        hashicorp/terraform apply \
        -var project=${PROJECT} \
        -var region=${REGION} \
        -auto-approve
```

If the Dataflow job runs successfully then there should be some data in the BigQuery table. You cna check this by issuing:

```bash
bq query --nouse_legacy_sql "select count(*) from ${PROJECT}.dataflow_demo.t"
```