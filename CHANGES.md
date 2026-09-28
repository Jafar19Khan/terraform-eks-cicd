# What was changed and why

| Area | Original | Now | Why |
|------|----------|-----|-----|
| EKS version | `1.29` | `1.35` (variable `kubernetes_version`) | 1.29 is past end of extended support and can no longer be created |
| EKS Terraform module | `~> 20.0` | `~> 21.0` (`name`, `kubernetes_version`, `endpoint_public_access`, `addons`) | Current major version; v21 renamed inputs |
| Cluster admin | not set | `enable_cluster_creator_admin_permissions = true` | Without it `kubectl` returns `Unauthorized` |
| EKS add-ons | not defined | `vpc-cni` + `eks-pod-identity-agent` with `before_compute = true`, `coredns`, `kube-proxy` | Nodes need the CNI before they start |
| Worker nodes | `t2.small` SPOT, default AMI | `t3.medium`/`t3a.medium`, `AL2023_x86_64_STANDARD`, capacity type per environment | t2 is previous generation; t3.small only fits ~11 pods |
| AWS provider | `5.25.0` pinned / `>=5.25.0` | `~> 6.0` | Required by EKS module v21 |
| VPC module | unpinned | `~> 6.0`, 3 AZs sliced explicitly | Reproducible builds |
| Jenkins OS | Amazon Linux 2 (hardcoded AMI ID) | Amazon Linux 2023 via `aws_ami` data source | AL2 is end-of-life; hardcoded AMI IDs are region-specific and go stale |
| Install script | `yum`, `apt install unzip` (fails on AL2), kubectl 1.23 in root `$HOME/bin`, `chmod 777 docker.sock`, Java 17 | `dnf`, AWS CLI already present, kubectl 1.35 checksum-verified in `/usr/local/bin`, docker group only, Java 21, Jenkins key taken from repo file | Script bugs; kubectl was not usable by the `jenkins` user; security |
| SonarQube | `sonarqube:lts-community`, no kernel tuning | `sonarqube:community`, `vm.max_map_count`/ulimits, data volumes, `--restart unless-stopped` | Old tag; container crashes without the sysctl settings |
| Jenkins EC2 | module, `t2.large`, 8 GB default disk | native resources, `t3.large`, 30 GB gp3 encrypted, IMDSv2 required, SSM access | Docker images + SonarQube + Trivy need disk; security |
| Security group | ports 22/80/443/8080/9000 open to `0.0.0.0/0` | 8080/9000 (and optional 22) only from `allowed_cidr` (0.0.0.0/0 rejected by validation) | Public Jenkins/SonarQube get attacked quickly |
| AWS credentials | Access keys stored in Jenkins credentials | IAM instance profile on the Jenkins server | No long-lived keys to leak (still AdministratorAccess: lab only) |
| Terraform state | S3 bucket hardcoded, DynamoDB-style era, same key for every env | Bucket passed at init, `use_lockfile = true`, one key per environment | Bucket names are global; envs no longer overwrite each other |
| Terraform version | unpinned | `>= 1.10` | Needed for native S3 locking |
| tfvars | Real AWS account ID committed; `prod`/`test` EKS files contained Jenkins values | No account ID, sensible per-environment values, no unused variables | Privacy; copy-paste bug |
| Jenkinsfile | Hardcoded upstream repo URL, `$action` param never declared, deploy stage ran after destroy, `kubectl create namespace` failed on re-run | Pipeline from SCM, declared `ACTION`/`ENVIRONMENT`/`TF_STATE_BUCKET` parameters, saved plan, approval, `when` conditions, app deleted before destroy, idempotent `kubectl apply` | Would not run as written |
| Manifests | 1 replica, `nginx:latest`, no probes, namespace created by the pipeline | 2 replicas, `nginx:stable-alpine`, resources, probes, `namespace.yaml` | Basic good practice; idempotent |
| Extras | none | `.gitignore`, `outputs.tf`, `default_tags`, new README | Safer pushes, easier operation |

## Not verified

These files were updated and syntax-checked (bash, YAML, bracket balance) but **`terraform init/validate/plan` could
not be run** where they were prepared (no network access). Run the commands in README steps 2 and 4 (`plan` first)
and fix any module-version issue before applying.
