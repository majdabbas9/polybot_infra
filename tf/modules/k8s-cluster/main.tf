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
}

# This S3 bucket is used to store data related to the Kubernetes cluster.
resource "aws_s3_bucket" "bucket" {
  bucket         = "${var.username}-${var.env}-polybot-bucket"
  force_destroy  = true
}

# This SQS queue is used for message queuing in the Kubernetes cluster.
resource "aws_sqs_queue" "sqs" {
  name = "${var.username}_${var.env}_sqs"
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
  name = "${var.username}_${var.env}_polybot_role"

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

  tags = {
    Env = var.env
  }
}

resource "aws_iam_policy" "polybot_policy" {
  name        = "${var.username}_${var.env}_polybot_policy"
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
        Resource = [
          aws_dynamodb_table.prediction_session.arn,
          aws_dynamodb_table.detection_objects.arn,
          "${aws_dynamodb_table.detection_objects.arn}/index/*"
        ]
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.bucket.arn}/*"
      },
      {
        Sid    = "SQSAccess"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage"
        ]
        Resource = aws_sqs_queue.sqs.arn
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
  user_data = file("./modules/k8s-cluster/setup-k8s-cp.sh")

  tags = {
    Name = "${var.username}-${var.env}-k8s-cp"
    Env  = var.env
  }
}


