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

    
Notes GKE Firewall Rules


Automatically Created Firewall Rules
Here are the key firewall rules that are typically created when you create a GKE cluster:

Node-to-Node Communication:

Allows all network traffic (all protocols and ports) between the nodes within the cluster.
This rule is essential for the nodes to communicate with each other and for the proper functioning of Kubernetes networking components like the kubelet and kube-proxy.

Master-to-Node Communication:

Allows traffic from the Kubernetes control plane (master) to the nodes on specific ports (e.g., TCP 443 for the Kubernetes API server, TCP 10250 for kubelet).
This rule is necessary for the control plane to manage and monitor the nodes in the cluster.

Node-to-Master Communication:

Allows traffic from the nodes to the control plane on specific ports (e.g., TCP 443 for the Kubernetes API server).
This rule is needed for the nodes to communicate with the Kubernetes API server.

Health Checks:

Allows traffic from the GKE control plane to the nodes for health checks.
Ensures that the control plane can monitor the health and status of the nodes.

Viewing the Automatically Created Firewall Rules
You can view the firewall rules created for your GKE cluster using the Google Cloud Console or the gcloud command-line tool.

Using Google Cloud Console:

Navigate to the VPC network > Firewall rules page.
Look for firewall rules that are prefixed with the cluster name or gke-.

Using gcloud Command-Line Tool:

sh
Copy code
gcloud compute firewall-rules list --filter="name:gke-"
