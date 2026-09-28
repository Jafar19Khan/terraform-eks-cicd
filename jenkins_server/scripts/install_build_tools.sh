#!/bin/bash
# EC2 user-data for the Jenkins build server. Target OS: Amazon Linux 2023 (dnf, not yum/apt).
# Runs once as root at first boot. Progress log: /var/log/install_build_tools.log
set -euo pipefail
exec > >(tee -a /var/log/install_build_tools.log) 2>&1

# Keep this in sync with kubernetes_version in tf-aws-eks (kubectl may differ by +/- 1 minor version).
KUBECTL_MINOR="1.35"

echo "=== System update + base packages ==="
dnf update -y
dnf install -y git wget unzip tar jq fontconfig docker java-21-amazon-corretto

echo "=== Docker ==="
systemctl enable --now docker
usermod -aG docker ec2-user
usermod -aG docker jenkins 2>/dev/null || true   # jenkins user is created later; re-applied below

echo "=== Kernel settings required by SonarQube (embedded Elasticsearch) ==="
cat > /etc/sysctl.d/99-sonarqube.conf <<SYSCTL
vm.max_map_count=524288
fs.file-max=131072
SYSCTL
sysctl --system

echo "=== Jenkins (LTS repo, Java 21) ==="
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
# Import whatever signing key the repo file currently points to (the key is rotated periodically).
JENKINS_KEY_URL="$(grep -m1 "^gpgkey=" /etc/yum.repos.d/jenkins.repo | cut -d= -f2-)"
rpm --import "${JENKINS_KEY_URL}" || true
dnf install -y jenkins
usermod -aG docker jenkins          # must happen before Jenkins starts
systemctl enable --now jenkins

echo "=== SonarQube Community Build (container) ==="
docker run -d --name sonarqube --restart unless-stopped \
  -p 9000:9000 \
  --ulimit nofile=131072:131072 --ulimit nproc=8192:8192 \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  -v sonarqube_logs:/opt/sonarqube/logs \
  sonarqube:community

echo "=== AWS CLI v2 (preinstalled on AL2023, install only if missing) ==="
if ! command -v aws >/dev/null 2>&1; then
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install
fi

echo "=== Terraform ==="
wget -O /etc/yum.repos.d/hashicorp.repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
dnf install -y terraform

echo "=== kubectl ${KUBECTL_MINOR}.x (system-wide, so the jenkins user can run it) ==="
KUBECTL_VERSION="$(curl -fsSL "https://dl.k8s.io/release/stable-${KUBECTL_MINOR}.txt")"
curl -fsSL -o /tmp/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
curl -fsSL -o /tmp/kubectl.sha256 "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"
echo "$(cat /tmp/kubectl.sha256)  /tmp/kubectl" | sha256sum --check
install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl

echo "=== Trivy ==="
cat > /etc/yum.repos.d/trivy.repo <<TRIVY
[trivy]
name=Trivy repository
baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://aquasecurity.github.io/trivy-repo/rpm/public.key
TRIVY
dnf install -y trivy

echo "=== Helm 3 ==="
curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
bash /tmp/get_helm.sh

echo "=== Installed versions ==="
java -version 2>&1 | head -1
git --version
docker --version
terraform version | head -1
aws --version
kubectl version --client
trivy --version | head -1
helm version --short

touch /var/log/install_build_tools.done
echo "=== Provisioning finished. Jenkins: :8080  SonarQube: :9000 ==="
