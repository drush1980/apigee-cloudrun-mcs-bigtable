#!/bin/bash

if [ -z "$PROJECT" ]; then
    echo "No PROJECT variable set"
    exit
fi

if [ ! -f "./config.yaml" ]; then
    echo "config.yaml not found. Provision the Apigee Envoy Adapter and copy the config.yaml to this directory."
    echo "See: https://cloud.google.com/apigee/docs/api-platform/envoy-adapter/latest/example-apigee#provision-apigee"
    exit
fi

gcloud builds submit --tag us-docker.pkg.dev/$PROJECT/apigee-cloudrun-mcs-bigtable/envoy-adapter:latest