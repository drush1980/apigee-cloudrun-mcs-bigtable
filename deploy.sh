#!/bin/bash

if [ -z "$PROJECT" ]; then
    echo "No PROJECT variable set"
    exit
fi

if [ -z "$REGION" ]; then
    echo "No REGION variable set"
    exit
fi

if [ -z "$APIGEE_ENV" ]; then
    echo "No APIGEE_ENV variable set"
    exit
fi

if [ -z "$APIGEE_HOST" ]; then
    echo "No APIGEE_HOST variable set"
    exit
fi

sed -i -e "s/@@REGION@@/$REGION/" apigee-envoy-service.yaml
sed -i -e "s/@@PROJECT@@/$PROJECT/" apigee-envoy-service.yaml
sed -i -e "s/@@APIGEE_HOST@@/$APIGEE_HOST/" apigee-envoy-service.yaml

echo "Deploying Cloud Run service..."
gcloud run services replace apigee-envoy-service.yaml
echo Y | gcloud run services set-iam-policy apigee-envoy policy.yaml --region=$REGION> /dev/null 2>&1

echo "Getting Cloud Run service domain..."
export RUN_DOMAIN=$(gcloud run services describe apigee-envoy --platform managed --region $REGION --format 'value(status.url)' | awk '{print substr($0, 9)}')
sed -i -e "s/@@ENVOY_CLOUD_RUN_SERVICE@@/$RUN_DOMAIN/" bigtable-product-ops.json

echo "Creating Service Account..."
gcloud iam service-accounts create apigee-bigtable --description="Allows API requests to query Bigtable" --display-name="apigee-bigtable"

echo "Adding Bigtable User role binding..."
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:apigee-bigtable@$PROJECT.iam.gserviceaccount.com" --role="roles/bigtable.user"

echo "Generating key..."
gcloud iam service-accounts keys create ./apigee-bigtable-key.json --iam-account=apigee-bigtable@$PROJECT.iam.gserviceaccount.com
SA_KEY=$(cat ./apigee-bigtable-key.json | jq ."private_key" -r)

TOKEN=$(gcloud auth print-access-token)
APP_NAME=sample-bigtable-app

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/master/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Deploying Apigee config..."

echo "Creating Key Value Map entries..."
apigeecli kvms create --token $TOKEN --org $PROJECT --env $APIGEE_ENV --name gcp-auth
apigeecli kvms entries create --token $TOKEN --org $PROJECT --env $APIGEE_ENV --map gcp-auth --key GCP.jwt_issuer --value "apigee-bigtable@$PROJECT.iam.gserviceaccount.com"
apigeecli kvms entries create --token $TOKEN --org $PROJECT --env $APIGEE_ENV --map gcp-auth --key GCP.privKeyPem --value "$SA_KEY"

echo "Importing and Deploying GCP Auth Sharedflow..."
apigeecli sharedflows import -f ./sharedflow --org $PROJECT --token $TOKEN
apigeecli sharedflows deploy --name gcp-auth-v2 --ovr --org $PROJECT --env $APIGEE_ENV --token $TOKEN

echo "Importing and Deploying modified Remote Token Proxy..."
apigeecli apis import -f ./proxy --org $PROJECT --token $TOKEN
apigeecli apis deploy --wait --name remote-token-bigtable --ovr --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

echo "Creating API Product"
apigeecli products create --name bigtable --displayname "bigtable" --opgrp ./bigtable-product-ops.json --envs "$APIGEE_ENV" --approval auto --quota 10 --interval 1 --unit minute --org "$PROJECT" --token "$TOKEN"

echo "Creating Developer"
apigeecli developers create --user sampledev --email sampledev@acme.com --first Sample --last Developer --org "$PROJECT" --token "$TOKEN"

echo "Creating Developer App"
apigeecli apps create --name $APP_NAME --email sampledev@acme.com --prods bigtable --org "$PROJECT" --token "$TOKEN" --disable-check

export CLIENT_ID=$(apigeecli apps get --name $APP_NAME --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerKey" -r)
export CLIENT_SECRET=$(apigeecli apps get --name $APP_NAME --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerSecret" -r)

export REMOTE_TOKEN_URL="https://$APIGEE_HOST/remote-token-bigtable/token"

echo " "
echo "Apigee artifacts are successfully deployed!"
echo " "
echo "Apigee Remote Service Token URL: $REMOTE_TOKEN_URL"
echo "Your app client id is: $CLIENT_ID"
echo "Your app client secret is: $CLIENT_SECRET"
echo " "
echo "-----------------------------"
echo " "
echo "To obtain an access token, run the following command:"
echo " "
echo "curl -v POST \$REMOTE_TOKEN_URL -d \"{\"client_id\": \"\$CLIENT_ID\",\"client_secret\": \"\$CLIENT_SECRET\",\"grant_type\": \"client_credentials\"}"
echo " "
echo "To access the protected resource, copy the value of the access_token property"
echo "from the response body of the previous request and include it as a bearer token"
echo "in a gRPC request to the Envoy proxy at https://$RUN_DOMAIN"
echo " "