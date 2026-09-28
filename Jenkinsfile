// Jenkins pipeline: create / destroy the EKS cluster with Terraform and deploy an nginx demo app.
//
// Setup:
//   * New Item -> Pipeline -> "Pipeline script from SCM" -> your GitHub repo, branch */main,
//     Script Path = Jenkinsfile   (so the repo URL is NOT hardcoded here).
//   * AWS access comes from the IAM instance profile of the Jenkins EC2 server (see jenkins_server/).
//     No AWS keys are stored in Jenkins. If you must use keys instead, wrap the stages in
//     withCredentials([usernamePassword(credentialsId: "aws-creds", usernameVariable: "AWS_ACCESS_KEY_ID", passwordVariable: "AWS_SECRET_ACCESS_KEY")]) { ... }
//   * Run with "Build with Parameters".
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 90, unit: "MINUTES")
    }

    parameters {
        choice(name: "ACTION", choices: ["plan", "apply", "destroy"], description: "plan = preview only, apply = create/update cluster + deploy app, destroy = remove app + cluster")
        choice(name: "ENVIRONMENT", choices: ["dev", "test", "prod"], description: "Selects variables/<env>.tfvars and the state key")
        string(name: "TF_STATE_BUCKET", defaultValue: "", description: "Name of the S3 bucket that stores Terraform state (required)")
    }

    environment {
        AWS_DEFAULT_REGION = "us-east-1"
        TF_IN_AUTOMATION   = "true"
        TF_INPUT           = "0"
    }

    stages {
        stage("Check parameters") {
            steps {
                script {
                    if (!params.TF_STATE_BUCKET?.trim()) {
                        error("TF_STATE_BUCKET is required. Create the S3 bucket first (see README).")
                    }
                }
                sh "aws sts get-caller-identity"
                sh "terraform version"
            }
        }

        stage("Terraform init") {
            steps {
                dir("tf-aws-eks") {
                    sh """
                        terraform init -input=false \\
                          -backend-config="bucket=${params.TF_STATE_BUCKET}" \\
                          -backend-config="key=eks/${params.ENVIRONMENT}/terraform.tfstate"
                    """
                }
            }
        }

        stage("Terraform validate") {
            steps {
                dir("tf-aws-eks") {
                    sh "terraform validate"
                }
            }
        }

        stage("Terraform plan") {
            steps {
                dir("tf-aws-eks") {
                    script {
                        def destroyFlag = (params.ACTION == "destroy") ? "-destroy" : ""
                        sh "terraform plan ${destroyFlag} -var-file=variables/${params.ENVIRONMENT}.tfvars -out=tfplan"
                    }
                }
            }
        }

        stage("Approval") {
            when { expression { params.ACTION != "plan" } }
            steps {
                timeout(time: 30, unit: "MINUTES") {
                    input message: "Review the plan above. ${params.ACTION} the ${params.ENVIRONMENT} environment?", ok: "Proceed"
                }
            }
        }

        // The nginx Service creates an AWS load balancer that Terraform does not know about.
        // It must be deleted first, otherwise terraform destroy hangs on the VPC.
        stage("Delete app (before destroy)") {
            when { expression { params.ACTION == "destroy" } }
            steps {
                sh """
                    set +e
                    CLUSTER=\$(cd tf-aws-eks && terraform output -raw cluster_name 2>/dev/null)
                    [ -z "\$CLUSTER" ] && exit 0
                    aws eks update-kubeconfig --name "\$CLUSTER" --region "\$AWS_DEFAULT_REGION" || exit 0
                    kubectl delete -f manifest/ --ignore-not-found --wait=true --timeout=300s
                    exit 0
                """
            }
        }

        stage("Terraform apply / destroy") {
            when { expression { params.ACTION != "plan" } }
            steps {
                dir("tf-aws-eks") {
                    sh "terraform apply -input=false tfplan"
                }
            }
        }

        stage("Deploy nginx to EKS") {
            when { expression { params.ACTION == "apply" } }
            steps {
                script {
                    def cluster = sh(script: "cd tf-aws-eks && terraform output -raw cluster_name", returnStdout: true).trim()
                    sh "aws eks update-kubeconfig --name ${cluster} --region ${env.AWS_DEFAULT_REGION}"
                }
                sh "kubectl apply -f manifest/"
                sh "kubectl -n eks-nginx-app rollout status deployment/nginx --timeout=300s"
                sh "kubectl -n eks-nginx-app get svc nginx"
            }
        }
    }

    post {
        always {
            sh "rm -f tf-aws-eks/tfplan || true"
        }
        success {
            echo "Pipeline finished: ${params.ACTION} / ${params.ENVIRONMENT}"
        }
        failure {
            echo "Pipeline failed. Read the console output above. If the cluster was created, you are still being billed - run ACTION=destroy."
        }
    }
}
