output "jenkins_public_ip" {
  description = "Public IP of the Jenkins server"
  value       = aws_instance.jenkins.public_ip
}

output "jenkins_url" {
  description = "Jenkins UI"
  value       = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "sonarqube_url" {
  description = "SonarQube UI (default login: admin / admin, change on first login)"
  value       = "http://${aws_instance.jenkins.public_ip}:9000"
}

output "instance_id" {
  description = "Instance ID (use with: aws ssm start-session --target <id>)"
  value       = aws_instance.jenkins.id
}

output "get_jenkins_password" {
  description = "Run this on the server to read the initial Jenkins admin password"
  value       = "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
}
