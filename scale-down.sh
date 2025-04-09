scale_down_deployment() {
  DEPLOYMENT_NAME=$1
  NAMESPACE=$2

  # Scale the deployment down to 0 replicas
  kubectl scale deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" --replicas=0

  # Wait until the deployment's pods are scaled down to 0
  echo "Waiting for deployment '$DEPLOYMENT_NAME' in namespace '$NAMESPACE' to scale down to 0 replicas..."
  
  # Use kubectl wait to monitor the deployment's availability until replicas = 0
  kubectl wait --for=condition=available deployment/"$DEPLOYMENT_NAME" -n "$NAMESPACE" --timeout=0 --field-selector=status.replicas=0
  
  echo "Deployment '$DEPLOYMENT_NAME' is successfully scaled down to 0 replicas."
}
