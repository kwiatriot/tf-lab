output "mgmt_jump_pub_ip" {
  description = "The Public IP for the Bastion Host"
  value       = aws_instance.mgmt_jump.public_ip
}
output "prod_host_private_ip" {
  description = "The Private IP of the Prod Host"
  value       = aws_instance.prod_host.private_ip
}
output "shared_host_private_ip" {
  description = "The Private IP of the Shared Host"
  value       = aws_instance.shared_host.private_ip
}
output "dev_host_private_ip" {
  description = "The Private IP of the Dev Host"
  value       = aws_instance.dev_host.private_ip
}
output "transit_host_private_ip" {
  description = "The Private IP for the transit host"
  value       = aws_instance.transit_host.private_ip
}
output "asav-mgmt_eip" {
  description = "The Public IP of the asav-mgmt interface"
  value       = aws_eip.asav_mgmt_eip.public_ip
}
output "asav-outside_eip" {
  description = "The Public IP of the asav-outside interface"
  value       = aws_eip.asav_outside_eip.public_ip
}