AWS EKS DevOps Platform

A hands-on DevOps portfolio project demonstrating Infrastructure as
Code, Amazon EKS, Kubernetes, Helm, GitOps with Argo CD, CI validation,
DevSecOps security scanning, troubleshooting, and cost-aware teardown.

Project Overview

This project implements an end-to-end AWS EKS delivery platform rather
than only deploying a sample Kubernetes workload. Terraform defines the
AWS infrastructure, Helm packages the application, GitHub stores the
desired state, GitHub Actions performs CI and security validation, and
Argo CD continuously reconciles the Kubernetes application into Amazon
EKS.

Key outcomes

Provisioned an AWS VPC and Amazon EKS platform with Terraform.

Deployed EKS managed worker nodes into private subnets across two
Availability Zones.

Configured controlled EKS API access and IAM/EKS access entries.

Packaged a demo application with Helm.

Implemented Argo CD GitOps delivery from GitHub to EKS.

Verified Git-driven automatic scaling from 2 to 3 replicas.

Enabled Argo CD automated sync, pruning, and self-healing.

Implemented GitHub Actions validation for Terraform and Helm.

Integrated Checkov Infrastructure-as-Code security scanning.

Remediated Checkov CKV_TF_1 module supply-chain findings by
pinning Terraform modules to immutable Git commit SHAs.

Integrated Trivy repository/security scanning and hardened it into a
blocking security gate.

Separated environment-specific Terraform values from committed
infrastructure code.

Troubleshot EKS networking, authentication/authorization, and Helm
validation issues.

Designed the lab so the live AWS infrastructure can be destroyed
after validation while the complete platform remains reproducible
from Git.

Architecture

Developer / Local Mac
        |
        | git push
        v
+-------------------------+
|         GitHub          |
|   aws-eks-platform      |
+-----------+-------------+
            |
            +------------------------------+
            |                              |
            v                              v
+-------------------------+      +-------------------------+
|     GitHub Actions      |      |         Argo CD         |
|                         |      |                         |
| Terraform fmt/validate  |      | Watches Git repository |
| Helm lint/template      |      | Automated sync          |
| Checkov IaC scan        |      | Pruning                 |
| Trivy security scan     |      | Self-healing            |
+-------------------------+      +------------+------------+
                                             |
                                             | Helm desired state
                                             v
                                  +-------------------------+
                                  |       Amazon EKS        |
                                  |                         |
                                  | demo namespace          |
                                  | demo-app Deployment     |
                                  | ClusterIP Service       |
                                  +------------+------------+
                                               |
                              +----------------+----------------+
                              |                                 |
                              v                                 v
                       Private Subnet                    Private Subnet
                           AZ 1                              AZ 2
                              \                               /
                               +---------- AWS VPC ----------+

Technology Stack

Technology       Purpose

AWS              Cloud platform
Amazon VPC       Network isolation, routing, public/private subnets
Amazon EKS       Managed Kubernetes control plane
Terraform        Infrastructure as Code
Kubernetes       Container orchestration
Helm             Kubernetes application packaging
Argo CD          GitOps continuous delivery and reconciliation
GitHub           Source control and desired-state repository
GitHub Actions   CI validation and security automation
Checkov          Terraform/IaC security scanning
Trivy            Repository, vulnerability, and secret scanning
AWS CLI          AWS administration and identity validation
kubectl          Kubernetes administration

Repository Structure

aws-eks-platform/
├── .github/
│   └── workflows/
│       └── validate.yml
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   ├── .terraform.lock.hcl
│   └── terraform.tfvars.example
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

Local terraform.tfvars, Terraform state, plan files, credentials,
tokens, private keys, kubeconfig files, and other environment-specific
secrets are intentionally excluded from Git.

Infrastructure Design

VPC

The Terraform configuration creates a VPC using the 10.20.0.0/16 CIDR
across two Availability Zones in us-east-1.

Private subnets:

10.20.1.0/24
10.20.2.0/24

Public subnets:

10.20.101.0/24
10.20.102.0/24

The lab uses a single NAT Gateway to provide outbound connectivity for
private resources while limiting unnecessary lab cost.

Amazon EKS

The EKS configuration includes:

Kubernetes 1.31 for the implementation captured in this project.

Managed node group using t3.medium instances.

Two desired worker nodes during validation.

Worker nodes attached to private subnets.

Public and private Kubernetes API endpoint access.

Public API access restricted through an environment-specific CIDR
variable.

IAM/EKS access entries managed through Terraform.

Kubernetes and module versions age over time. Verify currently
supported versions before rebuilding the environment.

Environment-specific configuration

Sensitive/environment-specific values are passed through Terraform
variables rather than hard-coded in reusable infrastructure code.

Example terraform/terraform.tfvars.example:

cluster_admin_principal_arn = "arn:aws:iam::<AWS-ACCOUNT-ID>:user/<IAM-USER>"
cluster_public_access_cidr  = "<YOUR-PUBLIC-IP>/32"

The real terraform.tfvars is local and ignored by Git.

Terraform Workflow

From terraform/:

terraform fmt -check -recursive
terraform init
terraform validate
terraform plan
terraform apply

The infrastructure build was validated before Kubernetes and GitOps
configuration proceeded.

EKS Connectivity and Authentication Troubleshooting

1. Kubernetes API timeout

Symptom

dial tcp 10.20.x.x:443: i/o timeout

Root cause

The EKS API was initially reachable only through private VPC addressing
while kubectl was running from a local Mac without a network route
into the VPC.

Resolution

The lab was configured with both public and private EKS API endpoint
access. Public access was restricted to the administrator's configured
/32 CIDR rather than broadly exposing the endpoint.

This separated network reachability from later authentication
problems.

2. EKS authentication/authorization

After endpoint connectivity was corrected, kubectl returned a
credentials/login error.

The troubleshooting sequence included:

aws sts get-caller-identity
aws eks get-token --cluster-name portfolio-eks --region us-east-1
aws eks describe-cluster --name portfolio-eks --region us-east-1 --query "cluster.accessConfig"
aws eks list-access-entries --cluster-name portfolio-eks --region us-east-1

The administrator identity could obtain an EKS token but required an EKS
access entry and associated cluster access policy. That access was
managed through Terraform.

A useful troubleshooting model from the project is:

i/o timeout
    -> network reachability

"You must be logged in"
    -> authentication / EKS IAM access

Forbidden
    -> authenticated, but insufficient authorization/RBAC

Helm Application

The demo application is packaged as a Helm chart under helm/demo-app.

Key values:

replicaCount: 2

image:
  repository: nginx
  tag: "1.27"

service:
  type: ClusterIP
  port: 80

Validation commands:

helm lint helm/demo-app
helm template demo-app helm/demo-app

A chart metadata error encountered during implementation was corrected
by fixing Chart.yaml and rerunning Helm validation.

Argo CD and GitOps

Argo CD installation

Argo CD runs in the argocd namespace. For this lab, the UI is accessed
locally rather than exposing another public AWS load balancer.

kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl get pods -n argocd

For a production implementation, pin and review a specific Argo CD
release instead of relying on a moving stable reference.

Local UI access:

kubectl port-forward svc/argocd-server -n argocd 8080:443

Then browse locally to https://localhost:8080.

Application configuration

argocd/application.yaml points Argo CD to:

Repository: this GitHub project.

Revision: main.

Path: helm/demo-app.

Destination namespace: demo.

Automated synchronization: enabled.

Pruning: enabled.

Self-healing: enabled.

Namespace creation: enabled.

Git therefore acts as the desired-state source for the Kubernetes
application.

GitOps automatic synchronization test

The Helm replica count was changed in Git from:

replicaCount: 2

to:

replicaCount: 3

The change was committed and pushed to main. Argo CD detected the
updated desired state and Kubernetes created a third application pod
without a manual kubectl apply.

Observed final Argo CD status after synchronization:

demo-app   Synced   Healthy

The configuration was subsequently restored through Git to the normal
two-replica state.

Configuration drift and self-healing

The Argo CD Application is configured with selfHeal: true. The project
includes a drift test in which the live Deployment is manually scaled
away from the Git-defined replica count and Argo CD reconciles the
resource back toward the desired state stored in Git.

This demonstrates the operational difference between directly
manipulating live Kubernetes state and managing desired state
declaratively through GitOps.

CI/CD and DevSecOps Automation

Design

The project separates Continuous Integration from Continuous Delivery:

Git push / pull request
        |
        v
GitHub Actions
        |
        +--> Terraform formatting / validation
        +--> Helm lint / template rendering
        +--> Checkov IaC security scan
        +--> Trivy security scan
        |
        v
Validated repository state
        |
        v
Argo CD
        |
        v
Amazon EKS

GitHub Actions validates code and configuration. Argo CD owns Kubernetes
reconciliation. The CI workflow does not need to run kubectl apply for
application delivery.

GitHub Actions workflow

The workflow is stored at:

.github/workflows/validate.yml

It runs on pushes to main, pull requests targeting main, and manual
execution.

Terraform validation

terraform fmt -check -recursive
        |
terraform init -backend=false
        |
terraform validate

-backend=false allows CI to validate providers, modules, syntax, and
configuration without requiring access to a live Terraform state
backend.

Helm validation

helm lint helm/demo-app
        |
helm template demo-app helm/demo-app

Checkov

Checkov performs static security analysis of the Terraform
configuration.

An important finding was:

CKV_TF_1

The original VPC and EKS module references were version-pinned but not
pinned to immutable source revisions. The modules were changed to
verified Git sources pinned to exact commit SHAs corresponding to the
intended releases.

Validation after remediation:

Passed checks: 5
Failed checks: 0
Skipped checks: 0

CKV_TF_1 PASSED for resource: vpc
CKV_TF_1 PASSED for resource: eks

This reduces Terraform module supply-chain risk by ensuring the reviewed
source revision cannot move unexpectedly.

Trivy

Trivy performs repository/filesystem security scanning, including
vulnerability and secret-detection capabilities relevant to the
repository contents.

The Trivy workflow was hardened from reporting behavior into a blocking
security gate for qualifying findings.

A future container phase can extend Trivy to scan a custom application
image before publishing it to Amazon ECR.

Security Controls

The project demonstrates the following controls:

Private subnets for EKS worker nodes.

Restricted public EKS API CIDR plus private endpoint access.

IAM-based EKS administration.

EKS access entries managed as code.

Environment-specific IAM/network values separated from committed
Terraform configuration.

terraform.tfvars excluded from Git.

Terraform state and plan files excluded from Git.

.terraform.lock.hcl retained for reproducible provider selections.

Terraform modules pinned to immutable Git commit SHAs.

Checkov IaC security scanning.

Blocking Trivy security gate.

Read-only GitHub Actions repository permissions where appropriate.

GitOps desired-state management rather than direct CI-to-cluster
application deployment.

Validation Results

Validation                          Result

Terraform formatting                Passed

Terraform initialization            Passed

Terraform validation                Passed

Terraform infrastructure deployment Completed successfully

EKS worker nodes                    2 nodes observed Ready during
validation

Core Kubernetes system Pods         Running during validation

EKS administrator access            Verified

Helm lint                           Passed

Helm template rendering             Passed

Argo CD installation                Components observed Running

Argo CD Application                 Observed Synced and Healthy

GitOps scaling                      Verified Git-driven scale from 2 to
3 replicas

Restore through Git                 Verified return to normal 2-replica
configuration

Checkov                             5 passed, 0 failed after
remediation

Trivy                               Integrated and hardened as a
blocking security gate

Cost Management and Cleanup

This lab can generate AWS charges from resources such as:

Amazon EKS control plane.

EC2 managed worker nodes.

NAT Gateway.

Public IPv4 usage.

EBS/storage and data transfer.

The recommended portfolio workflow is:

Provision -> Validate -> Capture evidence -> Destroy

Cleanup:

cd terraform
terraform destroy

After destruction, verify that the EKS cluster and supporting resources
have been removed. The Git repository remains the reproducible
definition of the platform.

Portfolio Evidence

Useful screenshots to retain in screenshots/:

GitHub Actions workflow showing successful CI/security checks.

Checkov result showing zero failed checks after remediation.

Argo CD UI showing demo-app as Synced and Healthy.

kubectl get nodes showing both EKS worker nodes Ready.

kubectl get all -n demo showing the Deployment, Pods, ReplicaSet,
and Service.

Git history showing the GitOps test, security-gate hardening, and
Terraform module hardening commits.

Before publishing screenshots, redact or avoid AWS account IDs,
credentials, tokens, passwords, private IP-sensitive context, Terraform
state, and environment-specific values.

Engineering Lessons

This project demonstrates an engineering workflow rather than a perfect
first-pass build:

BUILD
  |
TEST
  |
OBSERVE FAILURE
  |
INVESTIGATE
  |
IDENTIFY ROOT CAUSE
  |
FIX THROUGH CODE
  |
RETEST
  |
VALIDATE
  |
COMMIT + DOCUMENT

The most important troubleshooting lesson was to separate EKS problems
into network reachability, authentication, and authorization instead of
treating every kubectl failure as the same issue.

Production Improvements

This is a portfolio/lab platform. Production improvements could include:

Remote encrypted Terraform state with locking.

Separate development, test, staging, and production environments.

Stronger least-privilege IAM and workload identity using EKS Pod
Identity or IRSA as appropriate.

Secrets Manager/External Secrets integration.

Custom application container build pipeline.

Amazon ECR.

Trivy container image scanning before publication/deployment.

Immutable image tags/digests.

Ingress/load balancing, DNS, and TLS.

Horizontal/cluster autoscaling.

Prometheus/Grafana or managed observability.

Centralized logging and alerting.

Backup and disaster-recovery controls.

Policy-as-code admission controls.

Controlled environment promotion and required review gates.

Project Status

Core project complete.

Completed capabilities include Terraform-based AWS/EKS provisioning, EKS
access troubleshooting, Helm packaging and validation, Argo CD GitOps
delivery, Git-driven synchronization, GitHub Actions CI, Checkov IaC
scanning and remediation, Trivy security gating, and reproducible
teardown.

The strongest next technical extension is a complete container
lifecycle:

Application source
       |
       v
Docker build
       |
       v
Trivy image scan
       |
       v
Amazon ECR
       |
       v
Helm image configuration
       |
       v
Argo CD
       |
       v
Amazon EKS