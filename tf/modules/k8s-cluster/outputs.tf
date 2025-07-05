output "control_plane_public_ip" {
  value = aws_instance.k8s_cp.public_ip
  description = "Public IP of the control plane node"
}
output "dev_s3_bucket_id" {
  value = aws_s3_bucket.bucket_dev.id
}

output "prod_s3_bucket_id" {
  value = aws_s3_bucket.bucket_prod.id
}

output "dev_sqs_queue_url" {
  value = aws_sqs_queue.sqs_dev.id
}

output "prod_sqs_queue_url" {
  value = aws_sqs_queue.sqs_prod.id
}