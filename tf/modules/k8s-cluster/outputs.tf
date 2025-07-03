output "control_plane_public_ip" {
  value = aws_instance.k8s_cp.public_ip
  description = "Public IP of the control plane node"
}