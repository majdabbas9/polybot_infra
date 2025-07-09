
# This module creates the necessary AWS resources for a Kubernetes cluster
# including DynamoDB tables and an S3 bucket.
resource "aws_dynamodb_table" "prediction_session_dev" {
  name           = "${var.username}_dev_prediction_session"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "uid"
  attribute {
    name = "uid"
    type = "S"
  }
  tags = {
    Environment ="dev"
    Owner       = var.username
  }
}
resource "aws_dynamodb_table" "prediction_session_prod" {
  name           = "${var.username}_prod_prediction_session"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "uid"
  attribute {
    name = "uid"
    type = "S"
  }
  tags = {
    Environment = "prod"
    Owner       = var.username
  }
}

# This DynamoDB table stores detection objects with various attributes and indices.
resource "aws_dynamodb_table" "detection_objects_dev" {
  name           = "${var.username}_dev_detection_objects"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "prediction_uid"
  range_key      = "score"
  attribute {
    name = "prediction_uid"
    type = "S"
  }
  attribute {
    name = "score"
    type = "S"
  }
  attribute {
    name = "label"
    type = "S"
  }

  attribute {
    name = "label_score"
    type = "N"
  }

  attribute {
    name = "score_partition"
    type = "S"
  }

  global_secondary_index {
    name               = "label-index"
    hash_key           = "label"
    range_key          = "label_score"
    projection_type    = "ALL"
  }

  global_secondary_index {
    name               = "score_partition-score-index"
    hash_key           = "score_partition"
    range_key          = "label_score"
    projection_type    = "ALL"
  }
  tags = {
    Environment = "dev"
    Owner       = var.username
  }
}
resource "aws_dynamodb_table" "detection_objects_prod" {
  name           = "${var.username}_prod_detection_objects"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "prediction_uid"
  range_key      = "score"
  attribute {
    name = "prediction_uid"
    type = "S"
  }
  attribute {
    name = "score"
    type = "S"
  }
  attribute {
    name = "label"
    type = "S"
  }

  attribute {
    name = "label_score"
    type = "N"
  }

  attribute {
    name = "score_partition"
    type = "S"
  }

  global_secondary_index {
    name               = "label-index"
    hash_key           = "label"
    range_key          = "label_score"
    projection_type    = "ALL"
  }

  global_secondary_index {
    name               = "score_partition-score-index"
    hash_key           = "score_partition"
    range_key          = "label_score"
    projection_type    = "ALL"
  }
  tags = {
    Environment = "prod"
    Owner       = var.username
  }
}
# This S3 bucket is used to store data related to the Kubernetes cluster.
resource "aws_s3_bucket" "bucket_dev" {
  bucket         = "${var.username}-dev-polybot-bucket"
  force_destroy  = true
  tags = {
    Environment = "dev"
    Owner       = var.username
  }
}
resource "aws_s3_bucket" "bucket_prod" {
  bucket         = "${var.username}-prod-polybot-bucket"
  force_destroy  = true
  tags = {
    Environment = "prod"
    Owner       = var.username
  }
}
# This SQS queue is used for message queuing in the Kubernetes cluster.
resource "aws_sqs_queue" "sqs_dev" {
  name = "${var.username}_dev_sqs"
  tags = {
    Environment = "dev"
    Owner       = var.username
  }
}
resource "aws_sqs_queue" "sqs_prod" {
  name = "${var.username}_prod_sqs"
  tags = {
    Environment = "prod"
    Owner       = var.username
  }
}

module "polybot_service_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "${var.username}-polybot-vpc"
  cidr = "10.0.0.0/16"

  azs            = var.azs
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  enable_nat_gateway   = false

  tags = {
    Name = "${var.username}-polybot-vpc"
  }
}

resource "aws_security_group" "cp_SG" {
  name        = "cp-sg"
  description = "Control plane security group"
  vpc_id      = module.polybot_service_vpc.vpc_id
}

resource "aws_security_group_rule" "cp_allow_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cp_SG.id
  description       = "Allow SSH to control plane"
}

resource "aws_security_group_rule" "cp_allow_http" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cp_SG.id
  description       = "Allow HTTP to control plane"
}

resource "aws_security_group_rule" "cp_allow_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cp_SG.id
  description       = "Allow all outbound from control plane"
}

resource "aws_security_group" "node_SG" {
  name        = "node-sg"
  description = "Worker nodes security group"
  vpc_id      = module.polybot_service_vpc.vpc_id
}

resource "aws_security_group_rule" "node_allow_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.node_SG.id
  description       = "Allow SSH to node"
}

resource "aws_security_group_rule" "node_allow_nodeport" {
  type              = "ingress"
  from_port         = 31080
  to_port           = 31080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.node_SG.id
  description       = "Allow NodePort access to node"
}

resource "aws_security_group_rule" "node_allow_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.node_SG.id
  description       = "Allow all outbound from node"
}

resource "aws_security_group_rule" "cp_allow_node_k8s_api" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.cp_SG.id
  source_security_group_id = aws_security_group.node_SG.id
  description              = "Allow all traffic from workers"
}

resource "aws_security_group_rule" "node_allow_cp_all" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.node_SG.id
  source_security_group_id = aws_security_group.cp_SG.id
  description              = "Allow all traffic from control plane"
}

resource "aws_iam_role" "polybot_role" {
  name = "${var.username}_polybot_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "polybot_policy" {
  name        = "${var.username}_polybot_policy"
  description = "Policy for access to DynamoDB, S3, SQS, SSM, and Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "*"
      },
      {
        Sid    = "SQSAccess"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage"
        ]
        Resource = "*"
      },
      {
        Sid    = "SSMPutParameterAccess"
        Effect = "Allow"
        Action = [
          "ssm:PutParameter"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:PutSecretValue",
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:majd/*"
      }
    ]
  })
}

# This IAM role policy attachment associates the policy with the role.
resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.polybot_role.name
  policy_arn = aws_iam_policy.polybot_policy.arn
}

# This IAM instance profile allows EC2 instances to assume the role.
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.username}_ec2_profile"
  role = aws_iam_role.polybot_role.name
}

#--------------------------------------------------------- load balancer-----------------------------------
resource "aws_security_group" "lb_sg" {
  name        = "alb-sg"
  description = "Allow HTTPS traffic to ALB"
  vpc_id      = module.polybot_service_vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "worker_tg" {
  name        = "${var.username}-tg"
  port        = 31080                # NodePort
  protocol    = "HTTP"
  vpc_id      = module.polybot_service_vpc.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/healthz"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb" "worker_alb" {
  name               = "${var.username}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = module.polybot_service_vpc.public_subnets
  security_groups    = [aws_security_group.lb_sg.id]
}
# Lookup the hosted zone for fursa.click
data "aws_route53_zone" "main_zone" {
  name         = "fursa.click"
  private_zone = false
}

# Create A record for majd.app.fursa.click -> ALB
resource "aws_route53_record" "majd_subdomain_dev" {
  zone_id = data.aws_route53_zone.main_zone.zone_id
  name    = "majd.app.dev"
  type    = "A"

  alias {
    name                   = aws_lb.worker_alb.dns_name
    zone_id                = aws_lb.worker_alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_acm_certificate" "majd_cert_dev" {
  domain_name       = "majd.app.dev.fursa.click"
  validation_method = "DNS"

  tags = {
    Name = "majd.app.dev.fursa.click"
  }
}

resource "aws_route53_record" "majd_cert_validation_dev" {
  name    = tolist(aws_acm_certificate.majd_cert_dev.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.majd_cert_dev.domain_validation_options)[0].resource_record_type
  zone_id = data.aws_route53_zone.main_zone.zone_id
  records = [tolist(aws_acm_certificate.majd_cert_dev.domain_validation_options)[0].resource_record_value]
  ttl     = 300
}

resource "aws_acm_certificate_validation" "majd_cert_validation_dev" {
  certificate_arn         = aws_acm_certificate.majd_cert_dev.arn
  validation_record_fqdns = [aws_route53_record.majd_cert_validation_dev.fqdn]
}

resource "aws_route53_record" "majd_subdomain_prod" {
  zone_id = data.aws_route53_zone.main_zone.zone_id
  name    = "majd.app.prod"
  type    = "A"

  alias {
    name                   = aws_lb.worker_alb.dns_name
    zone_id                = aws_lb.worker_alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_acm_certificate" "majd_cert_prod" {
  domain_name       = "majd.app.prod.fursa.click"
  validation_method = "DNS"

  tags = {
    Name = "majd.app.prod.fursa.click"
  }
}

resource "aws_route53_record" "majd_cert_validation_prod" {
  name    = tolist(aws_acm_certificate.majd_cert_prod.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.majd_cert_prod.domain_validation_options)[0].resource_record_type
  zone_id = data.aws_route53_zone.main_zone.zone_id
  records = [tolist(aws_acm_certificate.majd_cert_prod.domain_validation_options)[0].resource_record_value]
  ttl     = 300
}

resource "aws_acm_certificate_validation" "majd_cert_validation_prod" {
  certificate_arn         = aws_acm_certificate.majd_cert_prod.arn
  validation_record_fqdns = [aws_route53_record.majd_cert_validation_prod.fqdn]
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.worker_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.majd_cert_validation_dev.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.worker_tg.arn
  }
}

resource "aws_lb_listener_certificate" "prod_cert" {
  listener_arn    = aws_lb_listener.https.arn
  certificate_arn = aws_acm_certificate_validation.majd_cert_validation_prod.certificate_arn
}
#--------------------------------------------------------- k8s cluster-----------------------------------
# This EC2 instance serves as the Kubernetes control plane (CP).
resource "aws_instance" "k8s_cp" {
  ami                         = var.ami # Ubuntu 22.04 LTS (us-east-1)
  instance_type               = "t2.medium"
  subnet_id                   = module.polybot_service_vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.cp_SG.id]
  associate_public_ip_address = true
  iam_instance_profile        =  aws_iam_instance_profile.ec2_profile.name
  key_name                    = var.key_pair_name
  root_block_device {
    volume_size = 20              # 20 GB EBS volume
    volume_type = "gp3"           # gp3 recommended over gp2 for performance and cost
    delete_on_termination = true  # cleans up on destroy
  }
  user_data = <<-EOF
    #!/bin/bash
    set -eux
    exec > /var/log/user-data.log 2>&1

    KUBERNETES_VERSION=v1.32
    echo "Reached k1" >> /var/log/k.txt

    apt-get update
    apt-get install -y jq unzip ebtables ethtool curl software-properties-common apt-transport-https ca-certificates gpg

    echo "Reached k2" >> /var/log/k.txt

    # install awscli
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    ./aws/install --update

    echo "Reached k3" >> /var/log/k.txt

    cat <<EOT | tee /etc/sysctl.d/k8s.conf
    net.ipv4.ip_forward = 1
    net.bridge.bridge-nf-call-iptables = 1
    EOT

    sysctl --system

    echo "Reached k4" >> /var/log/k.txt

    curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

    curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | tee /etc/apt/sources.list.d/cri-o.list

    apt-get update
    apt-get install -y cri-o kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl

    echo "Reached k5" >> /var/log/k.txt

    systemctl start crio
    systemctl enable --now crio
    systemctl enable --now kubelet

    swapoff -a
    (crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab -

    echo "Finished setup" >> /var/log/k.txt

    # Run kubeadm init and configure cluster only if not already done
    if [ ! -f /etc/kubernetes/admin.conf ]; then
      kubeadm init --pod-network-cidr=10.244.0.0/16

      # Set up kubeconfig for root user (for script use)
      export KUBECONFIG=/etc/kubernetes/admin.conf

      # Set up kubeconfig for ubuntu user
      mkdir -p /home/ubuntu/.kube
      cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
      chown ubuntu:ubuntu /home/ubuntu/.kube/config

      # Install Flannel CNI
      su - ubuntu -c "kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"

      # Save join command to SSM
      TOKEN=$(kubeadm token create --ttl 48h --print-join-command)
      aws ssm put-parameter \
        --name "/k8s/worker/join-command-majd" \
        --value "$TOKEN" \
        --type "SecureString" \
        --overwrite \
        --region "eu-west-1"

      echo "Cluster init completed" >> /var/log/k.txt
    fi
  EOF


  tags = {
    Name = "${var.username}-k8s-cp"
  }
}

# This launch template is used to create worker nodes in the Kubernetes cluster.
resource "aws_launch_template" "worker_lt" {
  name_prefix   = "${var.username}_worker_lt"
  image_id      = var.ami
  instance_type = "t2.medium"
  key_name      = var.key_pair_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.node_SG.id]
  }
  block_device_mappings {
    device_name = "/dev/sda1"   # <-- update based on CLI output
    ebs {
      volume_size           = 20      # 20 GiB root volume
      volume_type           = "gp2"
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.username}_worker"
    }
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euxo pipefail
    exec > /var/log/worker-init.log 2>&1
    apt-get update
    apt-get install -y curl jq unzip ebtables ethtool gpg apt-transport-https ca-certificates software-properties-common

    curl -L "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install --update

    echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/k8s.conf
    sysctl --system

    mkdir -p /etc/apt/keyrings

    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

    curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" > /etc/apt/sources.list.d/cri-o.list

    apt-get update
    apt-get install -y cri-o kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl

    systemctl enable --now crio
    systemctl enable --now kubelet

    sudo apt install -y snapd
    sudo snap install amazon-ssm-agent --classic
    sudo systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
    sudo systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

    sudo modprobe br_netfilter
    echo 'br_netfilter' | sudo tee /etc/modules-load.d/k8s.conf
    echo 'net.bridge.bridge-nf-call-iptables = 1' | sudo tee /etc/sysctl.d/k8s.conf
    sudo sysctl --system

    echo "[INFO] Waiting for AWS metadata service..."
    until curl -s --connect-timeout 1 http://169.254.169.254/latest/meta-data/iam/security-credentials/; do
      sleep 2
    done

    echo "[INFO] Ensuring AWS CLI is in PATH..."
    export PATH=$PATH:/usr/local/bin
    for i in {1..60}; do
      echo "[INFO] Attempt $i: Fetching join command from SSM..."
      JOIN_CMD=$(aws ssm get-parameter \
        --name "/k8s/worker/join-command-majd" \
        --with-decryption \
        --query "Parameter.Value" \
        --output text \
        --region "eu-west-1") && break
      sleep 5
    done

    if [ -z "$JOIN_CMD" ]; then
      echo "[ERROR] Failed to fetch join command after 5 attempts" >&2
      exit 1
    fi

    echo "[INFO] Running join command..."
    sudo $JOIN_CMD

    growpart /dev/xvda 1
    resize2fs /dev/xvda1 || xfs_growfs /

    swapoff -a
    (crontab -l 2>/dev/null || true; echo "@reboot /sbin/swapoff -a") | crontab -
  EOF
  )
}

# This Auto Scaling Group (ASG) manages the worker nodes in the Kubernetes cluster.
resource "aws_autoscaling_group" "worker_asg" {
  name                      = "${var.username}_worker_asg"
  desired_capacity          = 1
  max_size                  = 1
  min_size                  = 1
  vpc_zone_identifier       = module.polybot_service_vpc.public_subnets
  health_check_type         = "EC2"
  health_check_grace_period = 300
  target_group_arns         = [aws_lb_target_group.worker_tg.arn]

  launch_template {
    id      = aws_launch_template.worker_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.username}_worker"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

#--------------------------------------------------------- Join use (Lambda + Lifecycle Hook + SNS + SSM)-----------------------------------
resource "aws_sns_topic" "asg_notifications" {
  name = "${var.username}-worker-asg-lifecycle"
}

resource "aws_iam_role" "asg_lifecycle_role" {
  name = "${var.username}-asg-lifecycle-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Principal = { Service = "autoscaling.amazonaws.com" },
      Effect    = "Allow"
    }]
  })
}

resource "aws_autoscaling_lifecycle_hook" "worker_join_hook" {
  name                   = "${var.username}-worker-join-hook"
  autoscaling_group_name = aws_autoscaling_group.worker_asg.name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_LAUNCHING"
  default_result         = "CONTINUE"
  heartbeat_timeout      = 600
  notification_target_arn = aws_sns_topic.asg_notifications.arn
  role_arn               = aws_iam_role.asg_lifecycle_role.arn
}

resource "aws_iam_role_policy" "asg_sns" {
  role = aws_iam_role.asg_lifecycle_role.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "sns:Publish",
      Resource = aws_sns_topic.asg_notifications.arn
    }]
  })
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.username}-lambda-worker-join"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_exec_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:DescribeInstanceInformation",
          "ssm:GetCommandInvocation",
          "ssm:SendCommand",
          "ssm:ListCommands",
          "ssm:UpdateInstanceInformation",
          "ssmmessages:*",
          "ec2messages:*",
          "ssm:GetParameter",
          "ssm:PutParameter"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:DescribeInstances"  # 🔑 REQUIRED for control-plane lookup
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "autoscaling:CompleteLifecycleAction"  # 🔄 REQUIRED to end lifecycle
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "worker_join_lambda" {
  filename         = "lambda_payload.zip"
  function_name    = "worker-auto-join"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 60
  environment {
    variables = {
      REGION = var.region
    }
  }
}

resource "aws_lambda_permission" "sns_invoke" {
  statement_id  = "AllowSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.worker_join_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.asg_notifications.arn
}

resource "aws_sns_topic_subscription" "sub" {
  topic_arn = aws_sns_topic.asg_notifications.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.worker_join_lambda.arn
}

resource "aws_iam_policy" "ssm_logs_policy" {
  name = "${var.username}_ssm_logs_policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:DescribeInstanceInformation",
          "ssm:GetCommandInvocation",
          "ssm:SendCommand",
          "ssm:ListCommands"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_ssm_logs" {
  role       = aws_iam_role.polybot_role.name
  policy_arn = aws_iam_policy.ssm_logs_policy.arn
}

resource "aws_iam_policy" "ssm_instance_policy" {
  name        = "${var.username}_ssm_instance_policy"
  description = "Allow EC2 instances to work with SSM"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:DescribeAssociation",
          "ssm:GetDeployablePatchSnapshotForInstance",
          "ssm:GetDocument",
          "ssm:DescribeDocument",
          "ssm:GetManifest",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:ListAssociations",
          "ssm:ListInstanceAssociations",
          "ssm:PutInventory",
          "ssm:PutComplianceItems",
          "ssm:PutConfigurePackageResult",
          "ssm:UpdateAssociationStatus",
          "ssm:UpdateInstanceAssociationStatus",
          "ssm:UpdateInstanceInformation",
          "ssmmessages:*",
          "ssm:PutParameter",
          "ec2messages:*",
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_ssm_instance_policy" {
  role       = aws_iam_role.polybot_role.name
  policy_arn = aws_iam_policy.ssm_instance_policy.arn
}
#--------------------------------------------------------- terminating ec2 instance life hook-----------------------------------
resource "aws_sns_topic" "asg_notification_2" {
  name = "${var.username}_asg_notifications"
}

resource "aws_iam_role" "asg_lifecycle_role_2" {
  name = "${var.username}_asg_lifecycle_role_2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "autoscaling.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "asg_lifecycle_policy_2" {
  name = "${var.username}_asg_lifecycle_policy_2"
  role = aws_iam_role.asg_lifecycle_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sns:Publish"
      ]
      Resource = aws_sns_topic.asg_notification_2.arn
    }]
  })
}

resource "aws_autoscaling_lifecycle_hook" "worker_termination_hook" {
  name                   = "pause-on-termination"
  autoscaling_group_name = aws_autoscaling_group.worker_asg.name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
  heartbeat_timeout      = 300         # Pause for 5 minutes
  default_result         = "CONTINUE"  # If Lambda/SSM fails
  notification_target_arn = aws_sns_topic.asg_notification_2.arn
  role_arn               = aws_iam_role.asg_lifecycle_role.arn
}

resource "aws_sns_topic_subscription" "email_notify" {
  topic_arn = aws_sns_topic.asg_notification_2.arn
  protocol  = "email"
  endpoint  = "majd.abbas999@gmail.com"  # Replace with your email
}

