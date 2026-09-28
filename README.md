# Project 19 - EKS cluster with Jenkins CI/CD and Terraform (updated for 2026)

Provision a Jenkins build server on AWS with Terraform, then use a Jenkins pipeline to create an
Amazon EKS cluster with Terraform and deploy a demo nginx app to it.

> Based on the upstream tutorial in NotHarshhaa/DevOps-Projects (project 19). The original is kept as
> `README-original.md`. See `CHANGES.md` for everything that was modernised and why.

## Architecture

```
You ──► Terraform (laptop) ──► Jenkins EC2 (AL2023: Jenkins, Docker, SonarQube, Terraform, kubectl, Trivy, Helm)
                                     │  IAM instance profile (no stored AWS keys)
                                     ▼
                       Jenkins pipeline ──► Terraform ──► VPC + NAT + EKS 1.35 (managed node group, AL2023)
                                     └────► kubectl apply ──► nginx Deployment + LoadBalancer Service
```

## Repository layout

| Path | Purpose |
|------|---------|
| `jenkins_server/tf-aws-ec2/` | Terraform for the Jenkins VPC, security group, IAM role and EC2 instance |
| `jenkins_server/scripts/install_build_tools.sh` | EC2 user-data that installs all tools (Amazon Linux 2023) |
| `tf-aws-eks/` | Terraform for the VPC and EKS cluster (run by the pipeline) |
| `manifest/` | Kubernetes manifests for the demo nginx app |
| `Jenkinsfile` | Parameterised pipeline: plan / apply / destroy |

## Prerequisites

* AWS account, and an IAM user (not root) with admin rights for this lab; `aws configure` done locally
* Terraform >= 1.10, AWS CLI v2, git
* A GitHub repo containing this project at its root, default branch `main`
* Set a billing budget alert first. **This lab costs roughly $0.30-0.40/hour while running** (EKS control plane,
  NAT gateway, EC2 instances). Always destroy when you stop working.

## Step 1 - S3 bucket for Terraform state (once)

```bash
BUCKET=tfstate-<your-name>-<random-digits>      # must be globally unique
aws s3api create-bucket --bucket "$BUCKET" --region us-east-1
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

State locking uses S3 itself (`use_lockfile`), so no DynamoDB table is needed.

## Step 2 - Create the Jenkins server

```bash
cd jenkins_server/tf-aws-ec2
terraform init -backend-config="bucket=$BUCKET"
terraform validate
terraform plan  -var-file=variables/dev.tfvars -var="allowed_cidr=$(curl -s https://checkip.amazonaws.com)/32"
terraform apply -var-file=variables/dev.tfvars -var="allowed_cidr=$(curl -s https://checkip.amazonaws.com)/32"
```

* Only your IP can reach Jenkins (8080) and SonarQube (9000). If your IP changes, re-apply.
* Shell access: `aws ssm start-session --target <instance_id>` (needs the Session Manager plugin), or pass
  `-var="key_name=<keypair>"` to enable SSH.
* Provisioning takes 3-6 minutes after the instance starts. Follow it with
  `sudo tail -f /var/log/install_build_tools.log` and wait for `/var/log/install_build_tools.done`.

## Step 3 - Configure Jenkins

1. Open the `jenkins_url` output. Get the initial password:
   `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`.
2. Install suggested plugins, create an admin user.
3. Create a **Pipeline** job -> *Pipeline script from SCM* -> Git -> your repo URL -> branch `*/main` -> Script Path `Jenkinsfile`.
4. Run **Build with Parameters** once (it may only register the parameters on the very first run).

## Step 4 - Run the pipeline

Build with parameters: `ACTION=plan`, `ENVIRONMENT=dev`, `TF_STATE_BUCKET=<your bucket>` first and read the plan.
Then `ACTION=apply` and approve. Creating the cluster takes about 15-20 minutes.

Verify (from the Jenkins server shell):

```bash
aws eks update-kubeconfig --name my-eks-dev --region us-east-1
kubectl get nodes
kubectl -n eks-nginx-app get svc nginx      # open the EXTERNAL-IP hostname in a browser (wait 1-3 min)
```

## Step 5 - Clean up (do not skip)

1. Run the pipeline with `ACTION=destroy` (it deletes the app and its load balancer first, then the cluster).
2. Destroy the Jenkins server: `terraform destroy` in `jenkins_server/tf-aws-ec2` with the same `-var` flags.
3. Delete the state bucket only when you are completely done.
4. Check the EC2, VPC (NAT gateways, Elastic IPs) and Load Balancer consoles for leftovers.

## Troubleshooting

| Symptom | Likely cause / fix |
|---------|--------------------|
| `terraform init` fails: no such bucket | Pass `-backend-config="bucket=..."`; check the bucket name and region |
| `You must be logged in to the server (Unauthorized)` | Cluster was created without `enable_cluster_creator_admin_permissions = true` (already set here) |
| Node group `CREATE_FAILED` / nodes not Ready | vpc-cni add-on must have `before_compute = true` (already set); check `kubectl get pods -n kube-system` |
| Version not supported error | Change `kubernetes_version`; list versions with `aws eks describe-cluster-versions` |
| SonarQube container keeps restarting | `sudo sysctl vm.max_map_count` must be 524288 (set by the install script) |
| `terraform destroy` hangs on the VPC | A load balancer created by a Kubernetes Service is still alive: delete the app first |
| Cannot reach Jenkins on 8080 | Your IP changed; re-run apply with the new `allowed_cidr` |

## Before you push to GitHub

* Run `terraform init` in both Terraform folders once and **commit `.terraform.lock.hcl`**.
* Never commit `*.pem`, `*.tfstate` or `.terraform/` (already in `.gitignore`).
