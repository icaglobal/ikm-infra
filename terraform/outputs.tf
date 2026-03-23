output "public_ip" {
  description = "Elastic IP of the Tinkar service instance"
  value       = aws_eip.tinkar.public_ip
}

output "rest_endpoint" {
  description = "Base URL for the REST API"
  value       = "http://${aws_eip.tinkar.public_ip}:8085"
}

output "grpc_endpoint" {
  description = "Host:port for the gRPC API"
  value       = "${aws_eip.tinkar.public_ip}:9095"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i <your-key.pem> ec2-user@${aws_eip.tinkar.public_ip}"
}
