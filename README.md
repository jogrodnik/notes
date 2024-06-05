### Essential Commands for Initiating Work

Below is a compilation of key commands to effectively manage your Kubernetes cluster and Helm configurations:

1. **Cluster Connection**:
   - **Command**: `KUBECONFIG=<dir>/ns-coract-dev-apps.geos-coract-dev.kubeconfig`
     - **Description**: Establish a connection to the CorAct namespace within the cluster. Replace `<dir>` with the path to your kubeconfig file.
   - **Command**: `KUBECONFIG=<dir>/admin.conf`
     - **Description**: Connect to the Kubernetes cluster as an administrator. Replace `<dir>` with the directory path to your admin configuration file.

2. **Display Available Namespaces**:
   - **Command**: `kubectl get namespaces`
     - **Description**: Retrieve and display a list of all namespaces currently available within the cluster. For instance, `ns-coract-dev-apps` represents the CorAct development namespace.

3. **Set Current Namespace**:
   - **Command**: `kubectl config set-context --current --namespace ns-coract-dev-apps`
     - **Description**: Configure the current context to operate within the `ns-coract-dev-apps` namespace, streamlining namespace-specific operations.

4. **List Deployed Helm Charts**:
   - **Command**: `helm list`
     - **Description**: Generate a list of all Helm charts that have been deployed in the cluster, facilitating the management of these deployments.

5. **Uninstall a Helm Chart**:
   - **Command**: `helm uninstall chart`
     - **Description**: Remove the Helm chart named `coract` from the cluster, thereby uninstalling the associated application.

These commands are fundamental for efficiently managing your Kubernetes cluster and Helm deployments.
