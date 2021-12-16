
Assumes you have authenticated to GCP on your host by running `gcloud auth login` & `gcloud auth application-default`


To run the demo, issue:

```bash
export PROJECT=your_gcp_project
export REGION=your_gcp_region #e.g. europe-west2, us-central1, etc...
export NETWORK=your_network
export SUBNETWORK=your_subnetwork
docker run -it -v $(pwd):/tf -w /tf hashicorp/terraform init 
docker run -it -v ~/.config/gcloud:/root/.config/gcloud -v $(pwd):/tf -w /tf hashicorp/terraform apply -var project=${PROJECT} -var region=${REGION} -var network=${NETWORK} -auto-approve -var subnetwork=${SUBNETWORK}
```