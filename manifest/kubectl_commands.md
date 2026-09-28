# Handy kubectl commands

```bash
# Point kubectl at the cluster (cluster name = value of cluster_name in variables/<env>.tfvars)
aws eks update-kubeconfig --name my-eks-dev --region us-east-1

kubectl get nodes -o wide
kubectl get ns
kubectl get all -n eks-nginx-app
kubectl -n eks-nginx-app get svc nginx          # EXTERNAL-IP / hostname of the load balancer
kubectl -n eks-nginx-app rollout status deployment/nginx
kubectl -n eks-nginx-app logs deploy/nginx
kubectl -n eks-nginx-app describe pod -l app=nginx

# Test the app (wait 1-3 minutes after the service is created for DNS to propagate)
curl -I http://<EXTERNAL-IP-hostname>
```

Before destroying the cluster, delete the app first so the AWS load balancer is removed
(otherwise `terraform destroy` hangs on the VPC):

```bash
kubectl delete -f manifest/ --wait=true
```
