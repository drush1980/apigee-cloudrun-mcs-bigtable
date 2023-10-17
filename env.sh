#!/bin/bash

export PROJECT="<GCP_PROJECT_ID>"
export REGION="<REGION>"
export APIGEE_ENV="<APIGEE_ENVIRONMENT>"
export APIGEE_HOST="<APIGEE_ENV_GROUP_HOSTNAME>"

gcloud config set project $PROJECT