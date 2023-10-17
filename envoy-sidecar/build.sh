#!/bin/bash

if [ -z "$PROJECT" ]; then
    echo "No PROJECT variable set"
    exit
fi

gcloud builds submit --tag us-docker.pkg.dev/$PROJECT/apigee-cloudrun-mcs-bigtable/envoy-sidecar:latest