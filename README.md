### Description of Configuring a Kubernetes Namespace

Configuring a Kubernetes namespace involves several steps, each of which ensures the namespace is set up correctly for your applications and services. Below is a comprehensive description of the configuration process, including creating a namespace, setting up resource quotas and limits, and configuring access control with service accounts and secrets.

#### 1. Create a Namespace

A namespace in Kubernetes is a virtual cluster within a Kubernetes cluster. It helps you organize and manage resources in a multi-tenant environment.

#### 2. Set Resource Quotas

Resource quotas ensure that the resources used by all the pods in a namespace do not exceed the defined limits. This helps prevent a single namespace from consuming too many resources.

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: resource-quota
  namespace: my-namespace
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
```

Apply the resource quota:

```bash
kubectl apply -f resource-quota.yaml
```

#### 3. Define Limit Ranges

Limit ranges set default resource requests and limits for pods and containers within a namespace, ensuring that each pod and container has a reasonable amount of resources allocated.

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: limit-range
  namespace: my-namespace
spec:
  limits:
  - default:
      cpu: "1"
      memory: 2Gi
    defaultRequest:
      cpu: "0.5"
      memory: 1Gi
    type: Container
```

Apply the limit range:

```bash
kubectl apply -f limit-range.yaml
```

#### 4. Create a Service Account

Service accounts provide an identity for processes that run in a pod. Create a service account in your namespace:

```bash
kubectl create serviceaccount my-service-account -n my-namespace
```

#### 5. Configure Secrets

Secrets store sensitive data such as passwords, OAuth tokens, and SSH keys. Create a Docker registry secret to allow access to private Docker images:


Patch the service account to use the Docker registry secret:

```bash
kubectl patch serviceaccount my-service-account -n my-namespace \
  -p '{"imagePullSecrets": [{"name": "my-docker-secret"}]}'
```

#### 6. Assign Roles and RoleBindings

Roles and RoleBindings manage access control within the namespace. Define a role that allows read access to pods:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: my-namespace
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
```

Create a RoleBinding to assign the role to the service account:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: my-namespace
subjects:
- kind: ServiceAccount
  name: my-service-account
  namespace: my-namespace
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```


#### 7. Use the Namespace in Deployments

Specify the namespace in your deployment manifests to deploy resources into the created namespace:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment
  namespace: my-namespace
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      serviceAccountName: my-service-account
      containers:
      - name: my-container
        image: <docker-server>/my-image:latest
        ports:
        - containerPort: 80
      imagePullSecrets:
      - name: my-docker-secret
```

These steps help ensure a well-organized, secure, and efficient Kubernetes environment.

Kubernetes supports several types of secrets, each designed for different use cases. Here are the primary types of Kubernetes secrets:

1. **Opaque Secret**:
   - Used to store arbitrary key-value pairs.
   - Default secret type if not specified.

   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: opaque-secret
   type: Opaque
   data:
     key1: base64-encoded-value1
     key2: base64-encoded-value2
   ```

2. **kubernetes.io/dockerconfigjson**:
   - Used to store Docker registry credentials in JSON format.
   - Allows Kubernetes to pull private images.

   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: docker-secret
   type: kubernetes.io/dockerconfigjson
   data:
     .dockerconfigjson: base64-encoded-docker-config-json
   ```


3. **kubernetes.io/service-account-token**:
   - Automatically created by Kubernetes to provide a token for service accounts.
   - Used to access the Kubernetes API.

   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: my-service-account-token
     annotations:
       kubernetes.io/service-account.name: my-service-account
   type: kubernetes.io/service-account-token
   ```

Each type of secret is designed to handle specific types of sensitive information, making it easier to manage and secure your credentials, tokens, and keys within a Kubernetes environment.

![image](https://github.com/user-attachments/assets/656cd831-37cd-43a1-b5fe-7d5eb4df3868)

