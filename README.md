
Assumes you have authenticated to GCP on your host by running `gcloud auth login` & `gcloud auth application-default`


The commands below can be used to deploy the terraform configuration herein. I deliberately used
docker image `hashicorp/terraform` rather than assuming one would have `terraform` installed
however one would still need docker installed.

You will also need to have the [Google Cloud SDK (aka `gcloud`)](https://cloud.google.com/sdk) installed.

```bash
export PROJECT=$(gcloud config get-value core/project) # or whatever project you wish to use
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

If the Dataflow job runs successfully then there should be some data in the BigQuery table. You can check this by issuing:

```bash
bq query --nouse_legacy_sql "select count(*) from ${PROJECT}.dataflow_demo.t"
```