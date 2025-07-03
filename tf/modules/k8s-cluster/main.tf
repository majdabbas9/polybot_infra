
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
  name = "${var.username}_ec2_profile"
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
  user_data                   = file("${path.module}/init_k8s_cp.sh")

  tags = {
    Name = "${var.username}-k8s-cp"
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

  user_data = base64encode(templatefile("${path.module}/init_k8s_worker.sh.tpl", {
    region      = var.region,
    secret_name = "kubeadm-join-command"
  }))
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