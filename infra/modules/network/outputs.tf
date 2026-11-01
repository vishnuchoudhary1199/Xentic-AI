output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnets (ALB, NAT gateways)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private application subnets (ECS/Fargate tasks)."
  value       = aws_subnet.private[*].id
}

output "data_subnet_ids" {
  description = "Isolated data subnets with no internet route (RDS)."
  value       = aws_subnet.data[*].id
}

output "data_subnet_cidrs" {
  description = "CIDR blocks of the data subnets."
  value       = aws_subnet.data[*].cidr_block
}

output "nat_gateway_public_ips" {
  description = "Public egress IPs of the NAT gateways (useful for third-party allow-lists)."
  value       = aws_eip.nat[*].public_ip
}
