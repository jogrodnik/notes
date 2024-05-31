# Variables
PROJECT_ID=my-project
SERVICE_ACCOUNT_EMAIL=example-service-account@my-project.iam.gserviceaccount.com
MEMBER_SERVICE_ACCOUNT_EMAIL=another-service-account@my-project.iam.gserviceaccount.com

# Create the service account (if not already created)
gcloud iam service-accounts create example-service-account \
    --display-name "Example Service Account"

# Assign the iam.serviceAccountUser role to the member service account on the target service account
gcloud iam service-accounts add-iam-policy-binding $SERVICE_ACCOUNT_EMAIL \
    --member="serviceAccount:${MEMBER_SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/iam.serviceAccountUser"
Notes 


