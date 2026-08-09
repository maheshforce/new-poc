resource "aws_security_group" "efs" {
  name        = "${var.cluster_name}-efs-sg"
  description = "Security group for EFS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "NFS from EKS nodes"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [var.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cluster_name}-efs-sg"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Component   = "EFS"
  }
}


resource "aws_efs_file_system" "this" {
  creation_token = "${var.cluster_name}-efs"

  encrypted = true

  tags = {
    Name        = "${var.cluster_name}-efs"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Component   = "EFS"
  }
}


resource "aws_efs_mount_target" "this" {
  count = length(var.subnet_ids)

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}


resource "aws_eks_addon" "efs_csi" {
  cluster_name = var.cluster_name
  addon_name   = "aws-efs-csi-driver"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
    Component   = "EKS"
  }
}


resource "aws_efs_access_point" "jenkins" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/jenkins"

    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = {
    Name      = "${var.cluster_name}-jenkins"
    ManagedBy = "Terraform"
  }
}

resource "aws_efs_access_point" "dev" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/dev"

    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = {
    Name      = "${var.cluster_name}-dev"
    ManagedBy = "Terraform"
  }
}

resource "aws_efs_access_point" "prod" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/prod"

    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = {
    Name      = "${var.cluster_name}-prod"
    ManagedBy = "Terraform"
  }
}