
output "vpc_id" { 
    description = "ID of the VPC" 
    value = aws_vpc.my-vpc.id
}


output "private_subnet_ids" {
  value = aws_subnet.private_subnet[*].id
}

output "public_subnet_ids" {
  value = aws_subnet.public_subnet[*].id
}