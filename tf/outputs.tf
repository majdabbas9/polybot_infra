output "control_plane_public_ip" {
  value = module.k8s-cluster.control_plane_public_ip
}
output "s3_bucket_id_dev" {
  value = module.k8s-cluster.dev_s3_bucket_id
}
output "s3_bucket_id_prod" {
  value = module.k8s-cluster.prod_s3_bucket_id
}
output "sqs_queue_url_dev" {
  value = module.k8s-cluster.dev_sqs_queue_url
}
output "sqs_queue_url_prod" {
  value = module.k8s-cluster.prod_sqs_queue_url
}
# output "alb_dns_name" {
#   description = "DNS name of the ALB"
#   value       = module.k8s-cluster.alb_dns_name
# }