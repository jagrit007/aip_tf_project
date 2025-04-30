output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.prefect_cluster.arn
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.prefect_vpc.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = [for subnet in aws_subnet.private_subnets : subnet.id]
}

output "prefect_worker_service_name" {
  description = "Name of the Prefect worker ECS service"
  value       = aws_ecs_service.prefect_worker_service.name
}

output "service_discovery_namespace" {
  description = "DNS namespace for service discovery"
  value       = aws_service_discovery_private_dns_namespace.prefect_namespace.name
}