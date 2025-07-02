# This module creates the necessary AWS resources for a Kubernetes cluster
# including DynamoDB tables and an S3 bucket.
resource "aws_dynamodb_table" "prediction_session" {
  name           = "${var.username}_${var.env}_prediction_session"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "uid"
  attribute {
    name = "uid"
    type = "S"
  }
  tags = {
    Environment = var.env
    Owner       = var.username
  }
}

# This DynamoDB table stores detection objects with various attributes and indices.
resource "aws_dynamodb_table" "detection_objects" {
  name           = "${var.username}_${var.env}_detection_objects"
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
    Environment = var.env
    Owner       = var.username
  }
}

# This S3 bucket is used to store data related to the Kubernetes cluster.
resource "aws_s3_bucket" "bucket" {
  bucket         = "${var.username}-${var.env}-polybot-bucket"
  force_destroy  = true
  tags = {
    Environment = var.env
    Owner       = var.username
  }
}

# This SQS queue is used for message queuing in the Kubernetes cluster.
resource "aws_sqs_queue" "sqs" {
  name = "${var.username}_${var.env}_sqs"
  tags = {
    Environment = var.env
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
    Env  = var.env
  }
}

resource "aws_security_group" "cp" {
  name        = "cp-sg"
  description = "Control plane security group"
  vpc_id      = module.polybot_service_vpc.vpc_id

  # Allow HTTP service (port 8080) from anywhere
  ingress {
    description = "Allow TCP on port 8080 from anywhere"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH from anywhere
  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all traffic between instances in the same SG
  ingress {
    description     = "Allow all from self"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    self            = true
  }

  # Egress: allow all traffic out
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cp-sg"
    Env  = var.env
  }
}

resource "aws_security_group" "node" {
  name        = "node-sg"
  description = "Worker nodes security group"
  vpc_id      = module.polybot_service_vpc.vpc_id

  # Allow 8443, 443, 22, 3000, 8080 from cp SG
  dynamic "ingress" {
    for_each = [8443, 443, 22, 3000, 8080]
    content {
      description     = "Allow port ${ingress.value} from cp SG"
      from_port       = ingress.value
      to_port         = ingress.value
      protocol        = "tcp"
      security_groups = [aws_security_group.cp.id]
    }
  }

  # Allow 8443, 443, 22, 3000, 8080 from self (same SG)
  dynamic "ingress" {
    for_each = [8443, 443, 22, 3000, 8080]
    content {
      description = "Allow port ${ingress.value} from self"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      self        = true
    }
  }

  # Egress: allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "node-sg"
    Env  = var.env
  }
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
  description = "Policy for access to DynamoDB, S3, and SQS"

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
  name = "${var.username}_${var.env}_ec2_profile"
  role = aws_iam_role.polybot_role.name
}

# This EC2 instance serves as the Kubernetes control plane (CP).
resource "aws_instance" "k8s_cp" {
  ami                         = var.ami # Ubuntu 22.04 LTS (us-east-1)
  instance_type               = "t2.medium"
  subnet_id                   = module.polybot_service_vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.cp.id]
  associate_public_ip_address = true
  iam_instance_profile        =  aws_iam_instance_profile.ec2_profile.name
  key_name                    = var.key_pair_name
  # count = var.env ? "dev" : 0
  user_data = <<-EOF
                #!/bin/bash
                KUBERNETES_VERSION=v1.32

                apt-get update
                apt-get install -y jq unzip ebtables ethtool

                curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                unzip awscliv2.zip
                sudo ./aws/install

                echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/k8s.conf
                sysctl --system

                mkdir -p /etc/apt/keyrings
                curl -fsSL https://pkgs.k8s.io/core:/stable:/$${KUBERNETES_VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
                echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$${KUBERNETES_VERSION}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

                curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
                echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" > /etc/apt/sources.list.d/cri-o.list

                apt-get update
                apt-get install -y software-properties-common apt-transport-https ca-certificates curl gpg
                apt-get install -y cri-o kubelet kubeadm kubectl
                apt-mark hold kubelet kubeadm kubectl

                systemctl start crio.service
                systemctl enable --now crio.service
                systemctl enable --now kubelet

                swapoff -a
                (crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab -
                EOF

  tags = {
    Name = "${var.username}-${var.env}-k8s-cp"
    Env  = var.env
  }
}

# This launch template is used to create worker nodes in the Kubernetes cluster.
resource "aws_launch_template" "worker_lt" {
  name_prefix   = "${var.username}_worker_lt"
  image_id      = var.ami
  instance_type = "t2.medium"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.node.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.username}_worker"
    }
  }

  user_data = base64encode(<<-EOF
                #!/bin/bash
                KUBERNETES_VERSION=v1.32

                apt-get update
                apt-get install -y jq unzip ebtables ethtool

                curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                unzip awscliv2.zip
                sudo ./aws/install

                echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/k8s.conf
                sysctl --system

                mkdir -p /etc/apt/keyrings
                curl -fsSL https://pkgs.k8s.io/core:/stable:/$${KUBERNETES_VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
                echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$${KUBERNETES_VERSION}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

                curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
                echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" > /etc/apt/sources.list.d/cri-o.list

                apt-get update
                apt-get install -y software-properties-common apt-transport-https ca-certificates curl gpg
                apt-get install -y cri-o kubelet kubeadm kubectl
                apt-mark hold kubelet kubeadm kubectl

                systemctl start crio.service
                systemctl enable --now crio.service
                systemctl enable --now kubelet

                swapoff -a
                (crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab -
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
