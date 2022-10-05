output "public-ip" {
  value       = aws_instance.my-public-instance.public_ip
}