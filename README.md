# AWS EKS Kubernetes Platform

A hands-on DevOps portfolio project that builds, deploys, validates, troubleshoots, and operates an Amazon EKS platform using Terraform, Kubernetes, Helm, Argo CD, Git, and GitHub.

## Project Overview

This project demonstrates an end-to-end DevOps workflow rather than only deploying a sample application. The environment is provisioned as Infrastructure as Code, connected to Kubernetes from a local workstation, packaged with Helm, and managed through GitOps with Argo CD.

The project also documents real troubleshooting performed during implementation, including EKS API endpoint connectivity, EKS IAM authentication/authorization, and Helm chart validation.

### What this project demonstrates

- AWS infrastructure provisioning with Terraform
- Amazon VPC networking with public and private subnets
- Amazon EKS and managed worker nodes
- IAM/EKS access management
- Kubernetes administration with `kubectl`
- Helm chart creation and validation
- Kubernetes deployment, scaling, and self-healing tests
- Git and GitHub source control
- Argo CD installation and GitOps deployment
- GitOps drift detection and self-healing
- Practical troubleshooting and root-cause analysis
- Safe teardown of lab infrastructure

## Architecture

```text
Local Mac / VS Code
        |
        | Git push
        v
      GitHub
        |
        +----------------------+
        |                      |
        |                Argo CD watches Git
        |                      |
        v                      v
 Terraform                 Amazon EKS
        |                      |
        v                      v
      AWS VPC              Kubernetes
        |                      |
 Public + Private              v
    Subnets                  Helm
        |                      |
        v                      v
   EKS Control Plane       demo-app
        |
        v
Managed Node Group
```

## Technology Stack

| Technology | Purpose |
|---|---|
| AWS | Cloud platform |
| Amazon VPC | Network isolation and subnetting |
| Amazon EKS | Managed Kubernetes control plane |
| Terraform | Infrastructure as Code |
| Kubernetes | Container orchestration |
| Helm | Kubernetes application packaging |
| Argo CD | GitOps continuous delivery |
| Git | Version control |
| GitHub | Source repository |
| VS Code | Local development environment |
| AWS CLI | AWS authentication and administration |
| kubectl | Kubernetes administration |

---

# Complete Implementation Guide

## 1. Create the GitHub repository

Create a public GitHub repository named:

```text
aws-eks-platform
```

Suggested description:

```text
AWS EKS DevOps portfolio project using Terraform, Kubernetes, Helm, ArgoCD, and GitOps practices.
```

For this implementation, the repository is:

```text
https://github.com/jerrysarpey7-spec/aws-eks-platform
```

Do not initialize the repository with generated infrastructure state or credentials.

## 2. Verify local prerequisites

The workstation should have:

- Visual Studio Code
- Git
- Terraform
- AWS CLI
- kubectl
- Helm
- Docker Desktop (for later container/CI work)

Verify installations:

```bash
git --version
terraform --version
aws --version
kubectl version --client
helm version
docker --version
```

If a command returns `command not found`, install that tool before proceeding.

## 3. Create the local projects directory

```bash
cd ~
mkdir -p DevOps-Projects
cd DevOps-Projects
```

Verify:

```bash
pwd
```

## 4. Clone the GitHub repository

```bash
git clone https://github.com/jerrysarpey7-spec/aws-eks-platform.git
cd aws-eks-platform
```

Check Git:

```bash
git status
```

## 5. Open the repository in VS Code

```bash
code .
```

If the `code` command is unavailable, open VS Code manually and select the `aws-eks-platform` folder.

## 6. Create the initial project structure

Create:

```text
aws-eks-platform/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── helm/
│   └── demo-app/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── deployment.yaml
│           └── service.yaml
├── argocd/
│   └── application.yaml
├── screenshots/
├── .gitignore
└── README.md
```

The Helm and Argo CD directories can be created later as their phases are reached.

---

# Terraform and AWS Infrastructure

## 7. Configure Terraform provider requirements

Create `terraform/versions.tf`:

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

## 8. Create Terraform variables

Create `terraform/variables.tf`:

```hcl
variable "aws_region" {
  description = "AWS region for the EKS project"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "portfolio-eks"
}
```

## 9. Configure the VPC and EKS modules

Create `terraform/main.tf`.

The initial configuration provisions a VPC and an EKS cluster using community Terraform AWS modules:

```hcl
provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "portfolio-eks-vpc"
  cidr = "10.20.0.0/16"

  azs = [
    "${var.aws_region}a",
    "${var.aws_region}b"
  ]

  private_subnets = [
    "10.20.1.0/24",
    "10.20.2.0/24"
  ]

  public_subnets = [
    "10.20.101.0/24",
    "10.20.102.0/24"
  ]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_dns_hostnames = true
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.31.6"

  cluster_name    = var.cluster_name
  cluster_version = "1.31"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
    }
  }
}
```

> **Note:** Kubernetes versions and Terraform module versions age over time. Before rebuilding the lab later, verify that the configured EKS version is still supported and update versions deliberately rather than blindly changing them.

## 10. Create Terraform outputs

Create `terraform/outputs.tf`:

```hcl
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
```

## 11. Create `.gitignore`

At the repository root, create `.gitignore`:

```gitignore
.terraform/
*.tfstate
*.tfstate.*
crash.log
.env
.env.*
*.pem
*.key
.aws/
kubeconfig
.DS_Store
tfplan
```

Do **not** ignore `.terraform.lock.hcl`; commit it so provider selections are reproducible.

Never commit AWS credentials, EKS tokens, passwords, private keys, Terraform state, or a real kubeconfig.

## 12. Initialize Terraform

From the repository root:

```bash
cd terraform
terraform fmt
terraform init
```

Expected final message:

```text
Terraform has been successfully initialized!
```

## 13. Validate Terraform

```bash
terraform fmt -check
terraform validate
```

Expected:

```text
Success! The configuration is valid.
```

Do not proceed to deployment while validation errors remain.

## 14. Authenticate the AWS CLI

Configure the local AWS CLI using an appropriate lab/admin identity:

```bash
aws configure
```

Use `us-east-1` as the region for this project.

Never place the resulting access key or secret access key in this repository.

Verify authentication:

```bash
aws sts get-caller-identity
```

A successful response returns the active AWS identity. Do not copy sensitive credentials into documentation.

## 15. Create and inspect a Terraform plan

```bash
terraform plan -out=tfplan
terraform show tfplan
```

Review resources carefully before applying. Expect resources related to VPC networking, subnets, routing/NAT, IAM, EKS, security groups, and managed worker nodes.

Do not apply a plan containing an unexpected cluster replacement or destruction.

## 16. Apply the infrastructure

```bash
terraform apply tfplan
```

After completion:

```bash
terraform output
```

Expected outputs include the cluster name, cluster endpoint, and VPC ID.

> **Cost warning:** EKS, NAT Gateway, EC2 worker nodes, and related AWS resources can generate charges. Destroy the lab when it is no longer needed.

---

# EKS Connectivity and Authentication

## 17. Generate kubeconfig

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name portfolio-eks
```

Check the current context:

```bash
kubectl config current-context
kubectl config get-contexts
```

## 18. Initial EKS connectivity test

```bash
kubectl get nodes
```

During this project, the first attempt failed with an `i/o timeout`. The EKS hostname resolved to private addresses in the `10.20.0.0/16` VPC.

### Troubleshooting: EKS API `i/o timeout`

Representative error:

```text
dial tcp 10.20.x.x:443: i/o timeout
```

### Diagnosis

Check endpoint configuration:

```bash
aws eks describe-cluster \
  --name portfolio-eks \
  --region us-east-1 \
  --query "cluster.resourcesVpcConfig.{Public:endpointPublicAccess,Private:endpointPrivateAccess,PublicCIDRs:publicAccessCidrs}"
```

A private-only EKS API endpoint cannot be reached directly from a local Mac that has no network path into the VPC.

### Resolution used for the portfolio lab

Enable both public and private endpoint access, while restricting public access to the administrator's current public IP `/32`.

First obtain the workstation's public IP locally. Do not commit it to Git:

```bash
curl https://checkip.amazonaws.com
```

Then configure the EKS module conceptually as:

```hcl
cluster_endpoint_public_access  = true
cluster_endpoint_private_access = true

cluster_endpoint_public_access_cidrs = [
  "<YOUR-PUBLIC-IP>/32"
]
```

Format, validate, plan, and apply:

```bash
terraform fmt
terraform validate
terraform plan
terraform apply
```

Verify the endpoint settings again with `aws eks describe-cluster`.

Refresh kubeconfig:

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name portfolio-eks
```

## 19. Troubleshooting EKS authentication

After network connectivity was fixed, `kubectl get nodes` returned a different error:

```text
the server has asked for the client to provide credentials
error: You must be logged in to the server
```

This was progress: the API server was now reachable, but the local AWS principal did not have EKS cluster access.

### Verify the AWS identity

```bash
aws sts get-caller-identity
```

### Verify EKS can generate a token

```bash
aws eks get-token \
  --cluster-name portfolio-eks \
  --region us-east-1
```

A successful token response confirms the AWS CLI can generate an EKS authentication token. Never paste or commit the returned token.

### Check the cluster authentication mode

```bash
aws eks describe-cluster \
  --name portfolio-eks \
  --region us-east-1 \
  --query "cluster.accessConfig"
```

For this implementation, the cluster reported:

```json
{
  "authenticationMode": "API_AND_CONFIG_MAP"
}
```

### Inspect EKS access entries

```bash
aws eks list-access-entries \
  --cluster-name portfolio-eks \
  --region us-east-1
```

The workstation administrator IAM principal was missing from the cluster access entries.

### Add administrator access through Terraform

Use a placeholder rather than publishing the real account ID or IAM principal:

```hcl
access_entries = {
  itadmin = {
    principal_arn = "arn:aws:iam::<AWS-ACCOUNT-ID>:user/<ADMIN-USER>"

    policy_associations = {
      cluster_admin = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

        access_scope = {
          type = "cluster"
        }
      }
    }
  }
}
```

Then:

```bash
terraform fmt
terraform validate
terraform plan
```

Review the plan. It should add/update access configuration rather than replace the EKS cluster.

Apply:

```bash
terraform apply
```

Verify:

```bash
aws eks list-access-entries \
  --cluster-name portfolio-eks \
  --region us-east-1
```

Check the associated policy:

```bash
aws eks list-associated-access-policies \
  --cluster-name portfolio-eks \
  --principal-arn arn:aws:iam::<AWS-ACCOUNT-ID>:user/<ADMIN-USER> \
  --region us-east-1
```

Refresh kubeconfig and test:

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name portfolio-eks

kubectl get nodes
kubectl get pods -A
kubectl cluster-info
```

### Troubleshooting model learned

```text
i/o timeout
    -> Network reachability

"You must be logged in"
    -> Authentication / EKS IAM access

Forbidden
    -> Authenticated but insufficient authorization/RBAC
```

This distinction is useful when troubleshooting EKS in production environments.

---

# Helm Application

## 20. Create the Helm chart structure

Create:

```text
helm/
└── demo-app/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── deployment.yaml
        └── service.yaml
```

## 21. Create `Chart.yaml`

```yaml
apiVersion: v2
name: demo-app
description: Demo Kubernetes application for AWS EKS portfolio project
type: application
version: 0.1.0
appVersion: "1.0.0"
```

## 22. Create `values.yaml`

```yaml
replicaCount: 2

image:
  repository: nginx
  tag: "1.27"

service:
  type: ClusterIP
  port: 80
```

## 23. Create `templates/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: {{ .Release.Name }}

spec:
  replicas: {{ .Values.replicaCount }}

  selector:
    matchLabels:
      app: {{ .Release.Name }}

  template:
    metadata:
      labels:
        app: {{ .Release.Name }}

    spec:
      containers:
        - name: demo-app
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"

          ports:
            - containerPort: 80

          readinessProbe:
            httpGet:
              path: /
              port: 80

          livenessProbe:
            httpGet:
              path: /
              port: 80
```

## 24. Create `templates/service.yaml`

```yaml
apiVersion: v1
kind: Service

metadata:
  name: {{ .Release.Name }}

spec:
  selector:
    app: {{ .Release.Name }}

  ports:
    - port: {{ .Values.service.port }}
      targetPort: 80

  type: {{ .Values.service.type }}
```

## 25. Validate the Helm chart

From `helm/demo-app`:

```bash
helm lint .
```

Successful result observed during this project:

```text
==> Linting .
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
```

Render the templates:

```bash
helm template demo-app .
```

Optionally validate the rendered manifests with Kubernetes without creating resources:

```bash
helm template demo-app . | kubectl apply --dry-run=client -f -
```

### Troubleshooting: `chart.metadata.name is required`

An earlier render attempt returned:

```text
Error: validation: chart.metadata.name is required
```

The `Chart.yaml` metadata was checked and corrected to contain:

```yaml
apiVersion: v2
name: demo-app
description: Demo Kubernetes application for AWS EKS portfolio project
type: application
version: 0.1.0
appVersion: "1.0.0"
```

The fix was verified with:

```bash
cat Chart.yaml
helm lint .
```

Result: `1 chart(s) linted, 0 chart(s) failed`.

## 26. Deploy the Helm application

Create the namespace:

```bash
kubectl create namespace demo
```

Install:

```bash
helm install demo-app . --namespace demo
```

Verify:

```bash
kubectl get pods -n demo
kubectl get deployments -n demo
kubectl get services -n demo
kubectl get pods -n demo -o wide
kubectl describe deployment demo-app -n demo
```

## 27. Test Kubernetes self-healing

List the Pods:

```bash
kubectl get pods -n demo
```

Delete one Pod:

```bash
kubectl delete pod <POD-NAME> -n demo
```

Immediately inspect the namespace:

```bash
kubectl get pods -n demo
```

Because the Pod is managed by a Deployment, Kubernetes should create a replacement to return the workload to the desired replica count.

## 28. Test manual Kubernetes scaling

Scale to three replicas:

```bash
kubectl scale deployment demo-app \
  --replicas=3 \
  -n demo
```

Verify:

```bash
kubectl get pods -n demo
```

Restore to two:

```bash
kubectl scale deployment demo-app \
  --replicas=2 \
  -n demo
```

---

# Git Workflow

## 29. Commit the initial Terraform work

From the repository root:

```bash
git status
git add .
git status
git commit -m "Add initial Terraform EKS infrastructure"
git push origin main
```

## 30. Commit the Helm work

```bash
git status
git add .
git commit -m "Add Helm deployment for demo application"
git push origin main
```

Use `git diff` before commits when reviewing a specific change:

```bash
git diff
```

---

# Argo CD and GitOps

## 31. Verify cluster health before installing Argo CD

```bash
kubectl get nodes
kubectl get pods -A
kubectl get pods -n demo
```

Resolve serious `Pending`, `CrashLoopBackOff`, or `ImagePullBackOff` issues before continuing.

## 32. Check for an existing Argo CD namespace

```bash
kubectl get namespace argocd
```

If it does not exist, create it:

```bash
kubectl create namespace argocd
```

## 33. Install Argo CD

For this lab, install Argo CD using the project installation manifest:

```bash
kubectl apply \
  -n argocd \
  --server-side \
  --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

> For a production environment, pin and review a specific Argo CD version instead of relying on a moving `stable` reference.

## 34. Verify Argo CD Pods

```bash
kubectl get pods -n argocd
```

Wait for the major components to reach `Running`.

If a Pod fails:

```bash
kubectl describe pod <POD-NAME> -n argocd
```

## 35. Inspect Argo CD services

```bash
kubectl get svc -n argocd
```

For the lab, access the UI with local port forwarding rather than creating a public load balancer.

## 36. Port-forward the Argo CD server

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Keep this terminal running and open a second terminal for other commands.

Open locally:

```text
https://localhost:8080
```

A local certificate warning may appear.

## 37. Retrieve the initial Argo CD admin password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d

echo
```

Username:

```text
admin
```

Never commit the password.

## 38. Create the Argo CD Application manifest

Create `argocd/application.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:
  name: demo-app
  namespace: argocd

spec:
  project: default

  source:
    repoURL: https://github.com/jerrysarpey7-spec/aws-eks-platform.git
    targetRevision: main
    path: helm/demo-app

  destination:
    server: https://kubernetes.default.svc
    namespace: demo

  syncPolicy:
    automated:
      enabled: true
      prune: true
      selfHeal: true

    syncOptions:
      - CreateNamespace=true
```

### What this configuration does

- `repoURL` tells Argo CD which Git repository contains the desired state.
- `targetRevision: main` watches the `main` branch.
- `path: helm/demo-app` identifies the Helm application.
- `destination.server` targets the cluster where Argo CD is running.
- `namespace: demo` deploys the application into the `demo` namespace.
- `automated.enabled` enables automated synchronization.
- `prune` permits removal of live resources removed from desired state.
- `selfHeal` allows Argo CD to reconcile live drift back to Git.

## 39. Validate the Argo CD Application YAML

From the repository root:

```bash
kubectl apply --dry-run=client -f argocd/application.yaml
```

Expected:

```text
application.argoproj.io/demo-app created (dry run)
```

### Troubleshooting: `no objects passed to apply`

During the project, this command returned:

```text
error: no objects passed to apply
```

This indicates that the referenced YAML file contains no valid Kubernetes object, commonly because it is empty or unsaved.

Check the file:

```bash
ls -l argocd/application.yaml
cat -n argocd/application.yaml
```

Ensure it starts with:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
```

Save it in VS Code (`Command + S`) and verify the Argo CD CRD exists:

```bash
kubectl get crd applications.argoproj.io
```

Then rerun the dry-run command.

## 40. Commit the Argo CD manifest

```bash
git status
git add argocd/application.yaml
git commit -m "Add ArgoCD GitOps application"
git push origin main
```

## 41. Register the Application with Argo CD

```bash
kubectl apply -f argocd/application.yaml
```

Check:

```bash
kubectl get applications -n argocd
```

The target state is:

```text
demo-app   Synced   Healthy
```

Also verify:

```bash
kubectl get all -n demo
```

## 42. Test GitOps with a Git-based scaling change

Open `helm/demo-app/values.yaml` in VS Code. Do not try to execute a YAML file directly from zsh.

Correct ways to open/read it include:

```bash
code helm/demo-app/values.yaml
cat helm/demo-app/values.yaml
```

Attempting this:

```text
helm/demo-app/values.yaml
```

causes zsh to try to execute the YAML file and can return:

```text
zsh: permission denied: helm/demo-app/values.yaml
```

Change:

```yaml
replicaCount: 2
```

to:

```yaml
replicaCount: 3
```

Save and verify:

```bash
cat helm/demo-app/values.yaml
git status
git diff
```

Commit and push:

```bash
git add helm/demo-app/values.yaml
git commit -m "Scale demo application to three replicas"
git push origin main
```

Do **not** manually scale Kubernetes for this test. The purpose is to prove Git -> Argo CD -> Kubernetes reconciliation.

Watch Argo CD:

```bash
kubectl get applications -n argocd -w
```

In another terminal:

```bash
kubectl get pods -n demo -w
```

Verify the Deployment reaches three replicas:

```bash
kubectl get deployment demo-app -n demo
kubectl get pods -n demo
```

## 43. Test Argo CD self-healing / configuration drift

With Git still declaring three replicas, deliberately change the live cluster:

```bash
kubectl scale deployment demo-app \
  --replicas=1 \
  -n demo
```

Watch:

```bash
kubectl get deployment demo-app -n demo -w
```

Because `selfHeal: true` is configured, Argo CD should eventually restore the Deployment to the Git-defined three replicas.

This demonstrates configuration drift detection and reconciliation.

## 44. Restore the application to two replicas through Git

Change `values.yaml` back to:

```yaml
replicaCount: 2
```

Then:

```bash
git add helm/demo-app/values.yaml
git commit -m "Restore demo application to two replicas"
git push origin main
```

Verify Argo CD reconciles the environment:

```bash
kubectl get pods -n demo
```

## 45. Review repository history

```bash
git status
git log --oneline -5
```

The repository history should show incremental implementation rather than one giant upload.

---

# Planned CI / DevSecOps Extension

> The following section describes the next planned phase. Do not present these checks as completed until they have actually been implemented and successfully executed.

The intended CI flow is:

```text
Developer Push / Pull Request
          |
          v
     GitHub Actions
          |
          +--> Terraform fmt
          +--> Terraform validate
          +--> Helm lint
          +--> IaC security scan (Checkov)
          +--> Container/image scan (Trivy, when an application image is added)
          |
          v
    Validated Git change
          |
          v
        Argo CD
          |
          v
      Amazon EKS
```

Potential additional controls:

- Secret scanning
- Pull-request validation
- Terraform security checks
- Helm linting
- Container vulnerability scanning
- Least-privilege GitHub Actions permissions

---

# Validation Checklist

Record only tests actually performed.

| Validation | Expected Result | Status |
|---|---|---|
| `terraform fmt -check` | Terraform formatting valid | Completed during build workflow |
| `terraform validate` | Configuration valid | Completed during build workflow |
| `terraform plan` | Expected infrastructure changes only | Completed during build workflow |
| AWS authentication | `get-caller-identity` succeeds | Completed |
| EKS API connectivity | No network timeout | Completed after endpoint fix |
| EKS authentication | kubectl authorized through EKS access | Completed after access fix |
| `helm lint .` | 0 charts failed | Completed |
| `helm template demo-app .` | Valid rendered manifests | Continue recording actual result |
| Helm deployment | Workload deploys to `demo` | Record actual result |
| Kubernetes Pod recovery | Deleted Pod is replaced | Record actual result |
| Kubernetes scaling | Replica count changes as expected | Record actual result |
| Argo CD installation | Argo CD components Running | Record actual result |
| Argo CD Application | Synced + Healthy | Record actual result |
| GitOps scaling | Git change reconciles replicas | Record actual result |
| Argo CD self-healing | Manual drift restored to Git state | Record actual result |
| GitHub Actions | Pipeline passes | Planned |
| Checkov | IaC scan executed/reviewed | Planned |
| Trivy | Image scan executed/reviewed | Planned |

---

# Troubleshooting Summary

## 1. EKS API timeout

**Symptom**

```text
dial tcp 10.20.x.x:443: i/o timeout
```

**Root cause**

The EKS API endpoint was resolving to private VPC addresses while `kubectl` was running on a Mac without private VPC connectivity.

**Resolution**

Enable public and private EKS endpoint access for the lab and restrict public API access to the administrator's `/32` public IP.

## 2. EKS client credentials error

**Symptom**

```text
the server has asked for the client to provide credentials
You must be logged in to the server
```

**Root cause**

The local IAM administrator could generate an EKS token but did not have an EKS access entry/policy granting cluster access.

**Resolution**

Manage an EKS access entry and `AmazonEKSClusterAdminPolicy` association through Terraform for the lab administrator.

## 3. Helm chart metadata validation

**Symptom**

```text
Error: validation: chart.metadata.name is required
```

**Resolution**

Correct and save `Chart.yaml`, then validate with:

```bash
helm lint .
```

Observed successful result:

```text
1 chart(s) linted, 0 chart(s) failed
```

## 4. Empty/unsaved Argo CD Application manifest

**Symptom**

```text
error: no objects passed to apply
```

**Resolution**

Inspect and save `argocd/application.yaml`, confirm it contains a valid `Application` object, verify the Argo CD CRD, and rerun the dry run.

## 5. Attempting to execute a YAML file

**Symptom**

```text
zsh: permission denied: helm/demo-app/values.yaml
```

**Cause**

Entering a file path by itself asks zsh to execute the file.

**Correct approach**

```bash
code helm/demo-app/values.yaml
```

or:

```bash
cat helm/demo-app/values.yaml
```

---

# Security Considerations

This is a learning environment, but the project follows several important security practices:

- Do not commit AWS access keys or secret keys.
- Do not commit EKS authentication tokens.
- Do not commit Argo CD passwords.
- Do not commit Terraform state.
- Do not commit kubeconfig files.
- Do not publish the workstation's real public IP unnecessarily.
- Restrict the EKS public API endpoint to a trusted `/32` where practical.
- Keep worker workloads in private subnets.
- Use EKS access entries rather than undocumented manual cluster access changes.
- Use Infrastructure as Code so important configuration changes are reviewable.
- Use cluster-admin access only for the lab administrator; production identities should use least privilege.

Use placeholders in public documentation:

```text
<AWS-ACCOUNT-ID>
<ADMIN-USER>
<YOUR-PUBLIC-IP>/32
```

---

# Cost Considerations

This lab can incur AWS charges. Cost-generating components can include:

- Amazon EKS control plane
- EC2 managed worker nodes
- NAT Gateway
- Data transfer
- EBS/storage and other supporting resources

Do not leave the environment running unnecessarily.

---

# Cleanup

Before destroying infrastructure, ensure anything you need has been committed to GitHub.

From the Terraform directory:

```bash
cd terraform
terraform plan -destroy
```

Review the plan carefully.

Then:

```bash
terraform destroy
```

Confirm when prompted.

Afterward, verify in AWS that the lab EKS cluster and associated infrastructure have been removed as expected. Also check for resources that may have been created outside Terraform during later extensions.

---

# Engineering Workflow Demonstrated

```text
BUILD
  |
  v
TEST
  |
  v
FAILURE / OBSERVATION
  |
  v
INVESTIGATE
  |
  v
ROOT CAUSE
  |
  v
FIX THROUGH CODE
  |
  v
RETEST
  |
  v
VALIDATE
  |
  v
COMMIT + DOCUMENT
```

The objective is not to claim that every component worked perfectly on the first attempt. The project demonstrates the ability to provision infrastructure, observe failures, distinguish networking from authentication and authorization issues, correct configuration, validate the result, and document the engineering process.

---

# Interview Talking Points

## Project summary

> I built and validated an AWS EKS platform using Terraform, Kubernetes, Helm, GitHub, and Argo CD. Terraform provisions the AWS networking and EKS environment, Helm packages the Kubernetes workload, and Argo CD provides GitOps-based reconciliation from GitHub to the cluster. I also tested and documented operational scenarios including EKS endpoint connectivity, IAM/EKS authentication, Kubernetes recovery and scaling, Helm validation, and GitOps drift reconciliation.

## EKS troubleshooting story

> My first `kubectl` connection timed out because the EKS API was resolving to private VPC addresses that my local workstation could not route to. I separated the problem into networking, authentication, and authorization layers. After fixing endpoint reachability, I received an authentication error. I verified the AWS identity and EKS token generation, inspected the cluster's access entries, identified that the administrator principal was missing, and managed the required EKS access entry through Terraform. This restored `kubectl` access without making an undocumented manual cluster change.

## GitOps explanation

> Git contains the desired application state. Argo CD watches the repository and compares that desired state with the live EKS cluster. When the Helm values change in Git, Argo CD synchronizes Kubernetes. With self-healing enabled, a manual change to the live Deployment creates drift and Argo CD restores the Git-defined state.

## Helm explanation

> Helm packages the Kubernetes Deployment and Service into a reusable chart. Application-specific settings such as replica count and image values are stored in `values.yaml`. I validate the chart with `helm lint` and render it with `helm template` before deployment.

---

# Repository Structure

```text
aws-eks-platform/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   └── .terraform.lock.hcl
│
├── helm/
│   └── demo-app/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── deployment.yaml
│           └── service.yaml
│
├── argocd/
│   └── application.yaml
│
├── screenshots/
├── .gitignore
└── README.md
```

---

## Project Status

Core infrastructure, EKS access troubleshooting, and Helm validation have been worked through as part of the project. Argo CD/GitOps validation should be marked complete only after the corresponding commands have successfully run in the environment. CI/DevSecOps automation remains a planned extension until implemented and tested.

# Phase 4: CI/CD and DevSecOps Automation with GitHub Actions

## Overview

After provisioning the AWS infrastructure with Terraform, deploying the Kubernetes application with Helm, and implementing GitOps continuous delivery with ArgoCD, the next phase of the project introduces automated Continuous Integration (CI) and DevSecOps validation.

The objective of this phase is to ensure that infrastructure and application configuration changes are automatically validated and security-scanned before they become part of the desired state managed by ArgoCD.

The CI pipeline uses GitHub Actions to perform:

- Terraform formatting validation
- Terraform initialization
- Terraform configuration validation
- Helm chart linting
- Helm template rendering
- Infrastructure-as-Code security scanning with Checkov
- Repository security scanning with Trivy

ArgoCD remains responsible for Continuous Delivery (CD).

The resulting workflow is:

```text
Developer
    |
    v
Git Push / Pull Request
    |
    v
GitHub
    |
    v
GitHub Actions
    |
    +-----------------------------+
    |                             |
    v                             v
Terraform Validation        Helm Validation
    |                             |
    +-------------+---------------+
                  |
                  v
              Checkov
                  |
                  v
               Trivy
                  |
                  v
        Validated Git Repository
                  |
                  v
               ArgoCD
                  |
                  v
             Amazon EKS
                  |
                  v
        Kubernetes Application
```

---

## 1. CI/CD Design

This project separates Continuous Integration and Continuous Delivery responsibilities.

### Continuous Integration

GitHub Actions performs CI validation.

The CI pipeline checks:

```text
Terraform
├── terraform fmt
├── terraform init
└── terraform validate

Helm
├── helm lint
└── helm template

Security
├── Checkov
└── Trivy
```

### Continuous Delivery

ArgoCD performs CD.

```text
GitHub Repository
        |
        v
      ArgoCD
        |
        v
Desired State Comparison
        |
        v
Automatic Synchronization
        |
        v
    Amazon EKS
```

This separation means GitHub Actions validates changes while ArgoCD continuously reconciles the approved desired state stored in Git with the Kubernetes cluster.

---

# 2. Create the GitHub Actions Directory

From the root of the repository, create the GitHub Actions workflow directory.

Project structure:

```text
aws-eks-platform/
│
├── .github/
│   └── workflows/
│       └── validate.yml
│
├── argocd/
│   └── application.yaml
│
├── helm/
│   └── demo-app/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── deployment.yaml
│           └── service.yaml
│
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   └── .terraform.lock.hcl
│
├── .gitignore
└── README.md
```

The workflow file is located at:

```text
.github/workflows/validate.yml
```

GitHub automatically recognizes YAML workflow files stored under:

```text
.github/workflows/
```

---

# 3. Create the Initial GitHub Actions Workflow

Create:

```text
.github/workflows/validate.yml
```

Add the following configuration:

```yaml
name: Validate Infrastructure

on:
  push:
    branches:
      - main

  pull_request:
    branches:
      - main

  workflow_dispatch:

permissions:
  contents: read

jobs:

  terraform:
    name: Terraform Validation
    runs-on: ubuntu-latest

    defaults:
      run:
        working-directory: terraform

    steps:

      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Terraform Init
        run: terraform init -backend=false

      - name: Terraform Validate
        run: terraform validate

  helm:
    name: Helm Validation
    runs-on: ubuntu-latest

    steps:

      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Helm
        uses: azure/setup-helm@v4

      - name: Helm Lint
        run: helm lint helm/demo-app

      - name: Render Helm Templates
        run: helm template demo-app helm/demo-app
```

---

# 4. Workflow Triggers

The workflow contains three triggers.

## Push to Main

```yaml
push:
  branches:
    - main
```

The workflow runs whenever code is pushed to the `main` branch.

Example:

```text
Developer
   |
   v
git push origin main
   |
   v
GitHub Actions starts
```

---

## Pull Requests

```yaml
pull_request:
  branches:
    - main
```

The workflow also runs when a pull request targets `main`.

This supports a more production-like workflow:

```text
Feature Branch
      |
      v
Pull Request
      |
      v
GitHub Actions
      |
      +--> Terraform Validation
      +--> Helm Validation
      +--> Security Scanning
      |
      v
Review
      |
      v
Merge
```

---

## Manual Execution

```yaml
workflow_dispatch:
```

This allows the workflow to be started manually from the GitHub Actions interface.

---

# 5. Repository Checkout

Each job begins by checking out the repository.

```yaml
- name: Checkout repository
  uses: actions/checkout@v4
```

GitHub Actions runners start with a clean environment.

Therefore, the repository must first be downloaded onto the runner before Terraform, Helm, Checkov, or Trivy can inspect the project.

Conceptually:

```text
GitHub Repository
       |
       v
actions/checkout
       |
       v
GitHub Actions Runner
       |
       v
Project files available
```

---

# 6. Terraform Validation Job

The Terraform job validates the Infrastructure-as-Code configuration.

```yaml
terraform:
  name: Terraform Validation
  runs-on: ubuntu-latest
```

The runner uses:

```text
Ubuntu Linux
```

The Terraform working directory is configured as:

```yaml
defaults:
  run:
    working-directory: terraform
```

This means Terraform commands execute inside:

```text
terraform/
```

instead of the repository root.

---

# 7. Install Terraform in the Runner

Terraform is installed using:

```yaml
- name: Setup Terraform
  uses: hashicorp/setup-terraform@v3
```

The runner can then execute Terraform commands.

---

# 8. Terraform Formatting Validation

The first Terraform test is:

```yaml
- name: Terraform Format Check
  run: terraform fmt -check -recursive
```

Equivalent local command:

```bash
terraform fmt -check -recursive
```

This checks whether Terraform files follow standard Terraform formatting conventions.

It does not modify the files because `-check` is being used.

If formatting is incorrect, the CI job fails.

To correct formatting locally:

```bash
cd terraform
terraform fmt -recursive
cd ..
```

Then review the changes:

```bash
git status
git diff
```

Commit the formatting correction:

```bash
git add terraform
git commit -m "Format Terraform configuration"
git push origin main
```

The workflow automatically runs again.

---

# 9. Terraform Initialization

The next step is:

```yaml
- name: Terraform Init
  run: terraform init -backend=false
```

This initializes the Terraform working directory.

The option:

```text
-backend=false
```

is intentional.

CI validation does not need access to the production Terraform state backend.

The objective is to initialize:

- Terraform providers
- Terraform modules
- provider dependencies

without accessing remote state.

Conceptually:

```text
Terraform Source
      |
      v
terraform init
      |
      +--> AWS Provider
      |
      +--> VPC Module
      |
      +--> EKS Module
      |
      v
Terraform initialized
```

---

# 10. Terraform Configuration Validation

The final Terraform validation command is:

```yaml
- name: Terraform Validate
  run: terraform validate
```

Equivalent local command:

```bash
terraform validate
```

A successful result looks similar to:

```text
Success! The configuration is valid.
```

This checks Terraform configuration syntax and internal consistency.

The CI pipeline therefore validates Terraform in the following order:

```text
Terraform Code
      |
      v
terraform fmt -check
      |
      v
terraform init
      |
      v
terraform validate
      |
      v
Terraform Validation Passed
```

---

# 11. Helm Validation Job

The second CI job validates the Helm chart.

```yaml
helm:
  name: Helm Validation
  runs-on: ubuntu-latest
```

The Helm validation process performs:

```text
Helm Chart
    |
    v
helm lint
    |
    v
helm template
    |
    v
Rendered Kubernetes YAML
```

---

# 12. Install Helm

Helm is installed on the GitHub Actions runner using:

```yaml
- name: Setup Helm
  uses: azure/setup-helm@v4
```

---

# 13. Helm Lint Validation

The first Helm test is:

```yaml
- name: Helm Lint
  run: helm lint helm/demo-app
```

Equivalent local command:

```bash
helm lint helm/demo-app
```

A successful result is similar to:

```text
==> Linting helm/demo-app
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
```

Helm lint checks the chart for problems before deployment.

---

# 14. Helm Template Rendering

The second Helm validation step is:

```yaml
- name: Render Helm Templates
  run: helm template demo-app helm/demo-app
```

Equivalent local command:

```bash
helm template demo-app helm/demo-app
```

This renders the Helm templates into Kubernetes manifests without deploying them.

Conceptually:

```text
Chart.yaml
     +
values.yaml
     +
templates/
     |
     v
Helm Rendering Engine
     |
     v
Kubernetes YAML
```

This provides an additional validation layer before ArgoCD attempts to synchronize the application.

---

# 15. Test the CI Workflow Locally

Before pushing the workflow, the same major validation commands were tested locally.

Terraform:

```bash
cd terraform

terraform fmt -check -recursive

terraform validate

cd ..
```

Helm:

```bash
helm lint helm/demo-app
```

Then:

```bash
helm template demo-app helm/demo-app
```

This follows the principle:

```text
Test Locally
     |
     v
Commit
     |
     v
Push
     |
     v
Test Again in CI
```

---

# 16. Commit the Initial CI Workflow

Check repository status:

```bash
git status
```

Stage the workflow:

```bash
git add .github/workflows/validate.yml
```

Review what will be committed:

```bash
git diff --cached
```

Commit:

```bash
git commit -m "Add Terraform and Helm validation workflow"
```

Push:

```bash
git push origin main
```

Because the workflow listens for pushes to `main`, pushing the commit automatically starts GitHub Actions.

---

# 17. Validate the Workflow in GitHub

Navigate to:

```text
GitHub Repository
      |
      v
Actions
      |
      v
Validate Infrastructure
```

The initial workflow contains:

```text
Terraform Validation
Helm Validation
```

Successful execution should show both jobs passing.

```text
✓ Terraform Validation
✓ Helm Validation
```

This confirms that infrastructure and Helm configuration can be validated automatically outside the local development environment.

---

# 18. Add Infrastructure Security Scanning with Checkov

After establishing the initial CI validation pipeline, Infrastructure-as-Code security scanning is added using Checkov.

Checkov analyzes Terraform configuration against security and configuration policies.

The purpose is to identify potentially insecure infrastructure configuration before deployment.

The flow becomes:

```text
Terraform
    |
    v
Syntax Validation
    |
    v
Checkov
    |
    v
Security Findings
```

---

# 19. Add the Checkov Job

Add the following job to:

```text
.github/workflows/validate.yml
```

```yaml
  checkov:
    name: Checkov IaC Scan
    runs-on: ubuntu-latest

    permissions:
      contents: read

    steps:

      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run Checkov
        uses: bridgecrewio/checkov-action@v12
        with:
          directory: terraform
          framework: terraform
          quiet: false
          soft_fail: true
```

The workflow now contains:

```text
jobs:
├── terraform
├── helm
└── checkov
```

---

# 20. Checkov Scan Scope

The configuration:

```yaml
directory: terraform
```

tells Checkov to scan:

```text
terraform/
```

The configuration:

```yaml
framework: terraform
```

limits this particular scan to Terraform Infrastructure-as-Code.

---

# 21. Initial Checkov Reporting Mode

The initial implementation uses:

```yaml
soft_fail: true
```

This is intentional.

During the first security assessment, findings should be visible without immediately blocking the CI pipeline.

The initial process is:

```text
Checkov Scan
     |
     v
Security Finding
     |
     v
Review Finding
     |
     +--> Fix
     |
     +--> Accept with justification
     |
     +--> Investigate further
```

Security findings should not automatically be suppressed without understanding the reason for the finding.

The long-term objective is to move from:

```yaml
soft_fail: true
```

to:

```yaml
soft_fail: false
```

after important findings have been remediated or appropriately documented.

At that point Checkov becomes a blocking security gate.

---

# 22. Review Checkov Results

After pushing the workflow, navigate to:

```text
GitHub
→ Actions
→ Validate Infrastructure
→ Checkov IaC Scan
→ Run Checkov
```

Checkov output can include:

```text
Passed checks
Failed checks
Skipped checks
```

Failed checks generally identify:

```text
Check ID
Resource
File
Security issue
Guidance
```

Each finding should be evaluated based on:

1. What resource is affected?
2. What configuration caused the finding?
3. What security risk is being identified?
4. Can the configuration be remediated?
5. Is the control appropriate for this environment?
6. If an exception is necessary, can it be justified and documented?

---

# 23. Commit Checkov Integration

Review changes:

```bash
git diff .github/workflows/validate.yml
```

Stage:

```bash
git add .github/workflows/validate.yml
```

Commit:

```bash
git commit -m "Add Checkov Terraform security scanning"
```

Push:

```bash
git push origin main
```

The workflow now performs:

```text
Terraform Validation
Helm Validation
Checkov IaC Scan
```

---

# 24. Add Trivy Security Scanning

The next DevSecOps control is Trivy.

At this stage of the project, the demo application uses an existing NGINX image rather than a custom application image built by this repository.

Therefore, Trivy is initially configured as a repository/filesystem security scan.

Later phases can extend Trivy to scan custom container images before they are pushed to a container registry.

---

# 25. Add the Trivy Job

Add the following job to:

```text
.github/workflows/validate.yml
```

```yaml
  trivy:
    name: Trivy Security Scan
    runs-on: ubuntu-latest

    permissions:
      contents: read

    steps:

      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run Trivy filesystem scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: fs
          scan-ref: .
          severity: CRITICAL,HIGH
          exit-code: "0"
          ignore-unfixed: true
```

The complete workflow now contains four major jobs:

```text
jobs:
├── terraform
├── helm
├── checkov
└── trivy
```

---

# 26. Trivy Severity Configuration

The scan is configured for:

```yaml
severity: CRITICAL,HIGH
```

This focuses the initial assessment on higher-severity findings.

The configuration:

```yaml
ignore-unfixed: true
```

avoids treating vulnerabilities without available fixes in the same manner as actionable findings.

---

# 27. Initial Trivy Reporting Mode

The initial configuration uses:

```yaml
exit-code: "0"
```

This means Trivy reports findings without causing the GitHub Actions job to fail.

This is intentional during the initial security assessment.

The eventual production-style configuration can use:

```yaml
exit-code: "1"
```

so qualifying findings cause CI to fail.

The progression is:

```text
Phase 1
Security Visibility
exit-code: 0
      |
      v
Review Findings
      |
      v
Remediation
      |
      v
Phase 2
Security Enforcement
exit-code: 1
```

---

# 28. Commit Trivy Integration

Stage the updated workflow:

```bash
git add .github/workflows/validate.yml
```

Commit:

```bash
git commit -m "Add Trivy security scanning"
```

Push:

```bash
git push origin main
```

GitHub Actions automatically starts another workflow run.

---

# 29. Final CI Workflow

After implementing both security tools, the CI pipeline contains:

```text
                   Git Push / PR
                        |
                        v
                  GitHub Actions
                        |
        +---------------+---------------+
        |               |               |
        v               v               v
    Terraform          Helm          Security
        |               |               |
        |               |       +-------+-------+
        |               |       |               |
        v               v       v               v
      fmt             lint   Checkov          Trivy
        |               |
        v               v
      init          template
        |
        v
    validate
```

The expected GitHub Actions jobs are:

```text
✓ Terraform Validation
✓ Helm Validation
✓ Checkov IaC Scan
✓ Trivy Security Scan
```

---

# 30. CI and GitOps Integration

The CI pipeline does not directly deploy the application to EKS.

This is an intentional architectural decision.

GitHub Actions performs validation and security analysis.

ArgoCD performs deployment and reconciliation.

The complete flow is:

```text
Developer
    |
    v
Code Change
    |
    v
Git Commit
    |
    v
Git Push / Pull Request
    |
    v
GitHub Actions
    |
    +--> Terraform Validation
    |
    +--> Helm Validation
    |
    +--> Checkov
    |
    +--> Trivy
    |
    v
Repository Desired State
    |
    v
ArgoCD
    |
    v
Compare Git vs Cluster
    |
    v
Automatic Synchronization
    |
    v
Amazon EKS
    |
    v
Kubernetes Deployment
```

This creates a clear separation between:

```text
CI = GitHub Actions

CD = ArgoCD
```

---

# 31. Why AWS Credentials Are Not Required for CI Validation

The initial GitHub Actions workflow does not perform:

```text
terraform apply
aws eks update-kubeconfig
kubectl apply
helm install
```

Therefore, AWS credentials are not required for the validation workflow.

This reduces the number of credentials exposed to CI and follows the principle of least privilege.

The CI pipeline validates source configuration rather than modifying AWS infrastructure.

---

# 32. DevSecOps Strategy

The project introduces security checks early in the software delivery lifecycle.

Instead of:

```text
Build
   |
   v
Deploy
   |
   v
Discover Security Problem
```

the target process is:

```text
Code
   |
   v
Validate
   |
   v
Security Scan
   |
   v
Review
   |
   v
Merge
   |
   v
Deploy
```

This is an example of shifting security validation earlier in the delivery lifecycle.

---

# 33. Security Gate Maturity

The initial security tools run in reporting mode.

Checkov:

```yaml
soft_fail: true
```

Trivy:

```yaml
exit-code: "0"
```

This allows findings to be collected and evaluated.

After remediation, the pipeline can be hardened to:

```yaml
soft_fail: false
```

and:

```yaml
exit-code: "1"
```

The resulting workflow becomes:

```text
Code Change
     |
     v
CI Validation
     |
     v
Security Scan
     |
     +---- FAIL ----> Developer fixes issue
     |
     |
    PASS
     |
     v
Merge
     |
     v
ArgoCD
     |
     v
EKS
```

---

# 34. Troubleshooting GitHub Actions

## Terraform Formatting Failure

If GitHub Actions reports a failure during:

```text
Terraform Format Check
```

run locally:

```bash
cd terraform
terraform fmt -recursive
cd ..
```

Review:

```bash
git diff
```

Then commit:

```bash
git add terraform
git commit -m "Format Terraform configuration"
git push origin main
```

---

## Terraform Initialization Failure

If:

```text
Terraform Init
```

fails, inspect the GitHub Actions logs.

Possible areas to investigate include:

- provider configuration
- Terraform module versions
- module download failures
- Terraform syntax
- dependency configuration

Reproduce locally with:

```bash
cd terraform
terraform init -backend=false
```

---

## Terraform Validation Failure

Reproduce locally:

```bash
cd terraform
terraform validate
```

Correct the reported Terraform error before pushing another change.

---

## Helm Lint Failure

Reproduce locally:

```bash
helm lint helm/demo-app
```

Check:

```text
Chart.yaml
values.yaml
templates/
```

for YAML or Helm template errors.

---

## Helm Template Failure

Run:

```bash
helm template demo-app helm/demo-app
```

Inspect the rendered Kubernetes manifests.

This is particularly useful for identifying:

- invalid Helm template expressions
- missing values
- YAML indentation issues
- incorrect variable references

---

## Checkov Findings

A Checkov finding should be investigated rather than automatically suppressed.

Recommended process:

```text
Finding
   |
   v
Identify Resource
   |
   v
Understand Security Control
   |
   v
Determine Applicability
   |
   +--> Remediate
   |
   +--> Document justified exception
```

---

## Trivy Findings

Review:

```text
Severity
Affected component
Available fix
Configuration
```

Critical and High findings should receive priority during remediation.

---

# 35. Git Workflow for CI Changes

Each CI change follows the same Git workflow used throughout this project.

Check modifications:

```bash
git status
```

Review:

```bash
git diff
```

Stage:

```bash
git add .github/workflows/validate.yml
```

Review staged changes:

```bash
git diff --cached
```

Commit:

```bash
git commit -m "<describe the CI change>"
```

Push:

```bash
git push origin main
```

Then verify:

```text
GitHub
→ Repository
→ Actions
→ Validate Infrastructure
```

---

# 36. CI/CD Security Practices

The following practices are used in this phase:

### No AWS credentials stored in source code

AWS credentials must never be committed to:

```text
README.md
Terraform files
GitHub Actions workflow files
Helm values
Kubernetes manifests
```

### Read-only repository permissions

The workflow specifies:

```yaml
permissions:
  contents: read
```

where appropriate.

### No direct infrastructure deployment from CI

The validation workflow does not run:

```bash
terraform apply
```

### No direct Kubernetes deployment from CI

GitHub Actions does not run:

```bash
kubectl apply
```

for the application deployment.

ArgoCD owns Kubernetes reconciliation.

### Security scanning before enforcement

Checkov and Trivy begin in reporting mode so findings can be reviewed before hard enforcement is enabled.

---

# 37. Validation Checklist

The CI/DevSecOps phase is considered successfully implemented when the following have been verified:

```text
[ ] .github/workflows/validate.yml exists

[ ] Workflow triggers on pushes to main

[ ] Workflow supports pull requests to main

[ ] Workflow can be manually triggered

[ ] Terraform formatting validation runs

[ ] Terraform initialization succeeds

[ ] Terraform validation succeeds

[ ] Helm lint succeeds

[ ] Helm templates render successfully

[ ] Checkov scans Terraform

[ ] Checkov findings are visible in GitHub Actions

[ ] Trivy scans the repository

[ ] Trivy findings are visible in GitHub Actions

[ ] CI does not contain AWS credentials

[ ] CI does not directly deploy infrastructure

[ ] ArgoCD remains responsible for Kubernetes CD

[ ] GitHub Actions workflow is committed to Git

[ ] GitHub Actions workflow runs successfully
```

Only mark a checkbox complete after verifying it in the environment.

---

# 38. Interview Talking Points

## Explain the CI/CD architecture

A concise explanation of the project architecture is:

> GitHub Actions provides the Continuous Integration layer for the project. Every push or pull request can run Terraform formatting and validation, Helm linting and template rendering, and security scanning with Checkov and Trivy. ArgoCD provides the Continuous Delivery layer by monitoring the Git repository and reconciling the Helm-defined desired state into Amazon EKS.

---

## Why separate GitHub Actions and ArgoCD?

The design separates validation from deployment.

```text
GitHub Actions
      |
      v
CI / Validation / Security

ArgoCD
      |
      v
CD / GitOps / Reconciliation
```

GitHub Actions determines whether configuration meets quality and security checks.

ArgoCD continuously ensures that the Kubernetes cluster matches the desired state stored in Git.

---

## Why not run kubectl from GitHub Actions?

Using ArgoCD as the deployment mechanism provides a GitOps model where Git is the source of truth.

Instead of CI pushing changes directly into Kubernetes:

```text
CI
 |
 v
kubectl apply
 |
 v
Cluster
```

the project uses:

```text
Git
 |
 v
ArgoCD
 |
 v
Cluster
```

This makes the desired state visible and version-controlled.

---

## What role does Checkov play?

Checkov performs static security analysis against Terraform Infrastructure-as-Code.

It helps identify potentially insecure cloud infrastructure configuration before deployment.

---

## What role does Trivy play?

Trivy provides additional security scanning.

In the current phase it scans the repository/filesystem.

A future phase can extend Trivy to scan custom container images before they are published and deployed.

---

## Why are the security scanners initially non-blocking?

The initial implementation focuses on security visibility and remediation.

Checkov uses:

```yaml
soft_fail: true
```

and Trivy uses:

```yaml
exit-code: "0"
```

This allows findings to be collected without immediately stopping development.

After important findings are remediated, both tools can be converted into blocking CI security gates.

---

# 39. Skills Demonstrated in This Phase

This phase demonstrates hands-on experience with:

- GitHub Actions
- Continuous Integration
- CI/CD architecture
- Terraform validation
- Infrastructure as Code
- Helm validation
- Kubernetes manifest generation
- Checkov
- Trivy
- DevSecOps
- Shift-left security
- GitOps
- ArgoCD
- Git workflow
- Automated quality gates
- Security gates
- CI troubleshooting

---

# 40. Future Improvements

The next phase of the project can introduce:

```text
Feature Branch
      |
      v
Pull Request
      |
      v
Required CI Checks
      |
      v
Security Gates
      |
      v
Code Review
      |
      v
Merge to Main
      |
      v
ArgoCD
      |
      v
Amazon EKS
```

Planned improvements include:

- GitHub branch protection
- Required pull-request checks
- Blocking Checkov security gates
- Blocking Trivy security gates
- Custom Docker application
- Docker image build pipeline
- Container image vulnerability scanning
- Amazon ECR
- Image tagging strategy
- ArgoCD deployment of versioned container images
- Improved Kubernetes security controls
- Additional observability and monitoring

---

# Phase 4 Summary

The CI and DevSecOps phase extends the AWS EKS platform from an infrastructure and GitOps project into an automated software delivery platform.

The project now combines:

```text
Terraform
    |
    v
AWS Infrastructure
    |
    v
Amazon EKS
    |
    v
Kubernetes
    |
    v
Helm
    |
    v
GitHub
    |
    +---------------------+
    |                     |
    v                     v
GitHub Actions          ArgoCD
    |                     |
    v                     v
CI Validation          GitOps CD
    |                     |
    v                     v
Checkov + Trivy        Amazon EKS
```

The resulting platform demonstrates Infrastructure as Code, Kubernetes orchestration, Helm packaging, GitOps continuous delivery, automated CI validation, security scanning, and operational troubleshooting within a single end-to-end DevOps project.