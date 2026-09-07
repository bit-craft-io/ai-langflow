data "aws_ami" "al2023" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

locals {
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.al2023[0].id

  secret_arns = compact([
    var.langflow_api_key_secret_arn,
    var.google_api_key_secret_arn,
    var.langflow_superuser_password_secret_arn,
    var.rds_langflow_master_secret_arn,
  ])
}

# --- デプロイ成果物（compose定義）を置くS3バケット ---
resource "aws_s3_bucket" "deploy" {
  bucket = var.deploy_bucket_name

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "deploy" {
  bucket = aws_s3_bucket.deploy.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "deploy" {
  bucket                  = aws_s3_bucket.deploy.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "compose_agent" {
  bucket = aws_s3_bucket.deploy.id
  key    = "docker-compose.agent.yaml"
  source = var.compose_agent_local_path
  etag   = filemd5(var.compose_agent_local_path)
}

# Langflowのflows(agents/*.json)。on-premisesの ./langflow/agents:/app/flows bindマウントを
# EC2上で再現するため、S3経由でホストにsyncする（cloud/docs/assumptions.md「3.」参照）。
resource "aws_s3_object" "langflow_flows" {
  for_each = fileset(var.langflow_flows_local_dir, "**")

  bucket = aws_s3_bucket.deploy.id
  key    = "langflow-flows/${each.value}"
  source = "${var.langflow_flows_local_dir}/${each.value}"
  etag   = filemd5("${var.langflow_flows_local_dir}/${each.value}")
}

# --- IAM ---
resource "aws_iam_role" "instance" {
  name = "${var.name}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# SSMセッションマネージャ経由でのアクセスを可能にする（SSH鍵・踏み台不要）
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "app" {
  name = "${var.name}-app-policy"
  role = aws_iam_role.instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = local.secret_arns
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.deploy.arn, "${aws_s3_bucket.deploy.arn}/*"]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-instance-profile"
  role = aws_iam_role.instance.name
}

# --- Security Group ---
resource "aws_security_group" "instance" {
  name_prefix = "${var.name}-"
  vpc_id      = var.vpc_id
  description = "EC2 docker compose host (bridge/langflow/voicevox)"

  dynamic "ingress" {
    for_each = var.enable_alb ? [1] : []
    content {
      description     = "bridge WebSocket from ALB (ADR-0002)"
      from_port       = 8765
      to_port         = 8765
      protocol        = "tcp"
      security_groups = [var.alb_security_group_id]
    }
  }

  dynamic "ingress" {
    for_each = var.enable_alb ? [] : (length(var.direct_ingress_cidr_blocks) > 0 ? [1] : [])
    content {
      description = "bridge WebSocket direct access (dev, no ALB)"
      from_port   = 8765
      to_port     = 8765
      protocol    = "tcp"
      cidr_blocks = var.direct_ingress_cidr_blocks
    }
  }

  dynamic "ingress" {
    for_each = var.enable_alb ? [] : (length(var.direct_ingress_cidr_blocks) > 0 ? [1] : [])
    content {
      description = "langflow direct access (dev, no ALB)"
      from_port   = 7860
      to_port     = 7860
      protocol    = "tcp"
      cidr_blocks = var.direct_ingress_cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = var.name })
}

# --- EC2インスタンス ---
resource "aws_instance" "this" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.instance.id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = var.associate_public_ip_address

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required" # IMDSv2必須
  }

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    aws_region                             = var.aws_region
    deploy_bucket_name                     = var.deploy_bucket_name
    bridge_image                           = var.bridge_image
    langflow_image                         = var.langflow_image
    voicevox_image                         = var.voicevox_image
    langflow_secret_key                    = var.langflow_secret_key
    langflow_flow_id                       = var.langflow_flow_id
    langflow_api_key_secret_arn            = var.langflow_api_key_secret_arn
    google_api_key_secret_arn              = var.google_api_key_secret_arn
    langflow_superuser_password_secret_arn = var.langflow_superuser_password_secret_arn
    rds_langflow_master_secret_arn         = var.rds_langflow_master_secret_arn
    rds_langflow_host                      = var.rds_langflow_host
    rds_langflow_port                      = var.rds_langflow_port
    rds_langflow_dbname                    = var.rds_langflow_dbname
  })

  tags = merge(var.tags, { Name = var.name })

  depends_on = [aws_s3_object.compose_agent, aws_s3_object.langflow_flows]
}

resource "aws_lb_target_group_attachment" "bridge" {
  count = var.enable_alb ? 1 : 0

  target_group_arn = var.alb_target_group_arn
  target_id        = aws_instance.this.id
  port             = 8765
}
