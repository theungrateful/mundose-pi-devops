output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_public_dns" {
  description = "Public DNS name of the bastion host"
  value       = aws_instance.bastion.public_dns
}

output "ssh_command" {
  description = "Command to SSH into the bastion host"
  value       = "ssh -i ${var.ssh_public_key_path} ec2-user@${aws_instance.bastion.public_dns}"
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "kubectl_config_command" {
  description = "Command to configure kubectl to access the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "next_steps" {
  description = "Next steps after terraform apply"
  value       = <<-EOT
    1. Connect to your bastion host:
       ${format("ssh -i %s ec2-user@%s", var.ssh_public_key_path, aws_instance.bastion.public_dns)}
       
    2. From the bastion host, configure kubectl:
       aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}
       
    3. To access from your local machine (if your IAM user has been configured):
       ${format("aws eks update-kubeconfig --region %s --name %s", var.region, module.eks.cluster_name)}
       
    4. Deploy Nginx:
       ./scripts/deploy-nginx.sh
       
    5. Deploy Prometheus and Grafana:
       ./scripts/install-monitoring.sh
       
    6. Access Prometheus (from bastion host):
       kubectl -n monitoring port-forward svc/prometheus-server 9090:80 --address 0.0.0.0
       Then browse to: http://${aws_instance.bastion.public_ip}:9090
       
    7. Get Grafana URL:
       kubectl -n monitoring get svc grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
       Default credentials: admin / EKS!sAWSome
  EOT
}