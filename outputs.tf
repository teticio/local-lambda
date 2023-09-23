output "ip" {
  description = "IP address"
  value       = aws_instance.ec2.public_ip
}
