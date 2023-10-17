#!/bin/bash

if [ -z "$PROJECT" ]; then
    echo "No PROJECT variable set"
    exit
fi

if [ -z "$APIGEE_ENV" ]; then
    echo "No APIGEE_ENV variable set"
    exit
fi

TOKEN=$(gcloud auth print-access-token)

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/master/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Deleting Apigee config..."

echo "Deleting Developer App..."
DEVELOPER_ID=$(apigeecli developers get --email sampledev@acme.com --org "$PROJECT" --token "$TOKEN" --disable-check | jq .'developerId' -r)
apigeecli apps delete --id "$DEVELOPER_ID" --name sample-bigtable-app --org "$PROJECT" --token "$TOKEN"

echo "Deleting Developer..."
apigeecli developers delete --email sampledev@acme.com --org "$PROJECT" --token "$TOKEN"

echo "Deleting API Product..."
apigeecli products delete --name bigtable --org "$PROJECT" --token "$TOKEN"

echo "Undeploying Remote Token Proxy..."
REV=$(apigeecli envs deployments get --env "$APIGEE_ENV" --org "$PROJECT" --token "$TOKEN" --disable-check | jq .'deployments[]| select(.apiProxy=="remote-token-bigtable").revision' -r)
apigeecli apis undeploy --name remote-token-bigtable --env "$APIGEE_ENV" --rev "$REV" --org "$PROJECT" --token "$TOKEN"

echo "Deleting Remote Token Proxy..."
apigeecli apis delete --name remote-token-bigtable --org $PROJECT --token $TOKEN

echo "Undeploying GCP Auth Sharedflow..."
REV=$(apigeecli sharedflows listdeploy --env $APIGEE_ENV --org $PROJECT --token $TOKEN | grep -v 'WARNING' | jq .'deployments[]| select(.apiProxy=="gcp-auth-v2").revision' -r)
apigeecli sharedflows undeploy --name gcp-auth-v2 -e $APIGEE_ENV --rev $REV --org $PROJECT --token $TOKEN  

echo "Deleting GCP Auth Sharedflow..."
apigeecli sharedflows delete --name gcp-auth-v2 --org $PROJECT --token $TOKEN

echo "Deleting KVM..."
apigeecli kvms delete --token $TOKEN --org $PROJECT --env $APIGEE_ENV --name gcp-auth

echo "Deleting Service Account..."
gcloud iam service-accounts delete apigee-bigtable

echo "Deleting key file..."
rm ./apigee-bigtable-key.json

echo "Deleting Cloud Run service..."
gcloud run services delete apigee-envoy

echo " "
echo "Cleanup complete. You may wish to also delete build artifacts from Artifact Registry."
echo " "