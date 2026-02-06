# security.tf - Security Groups (imported)

resource "aws_security_group" "alb" {
  name        = "${var.student_id}-legacy-alb-sg"
  description = "Security group for legacy ALB"
  vpc_id      = aws_vpc.legacy.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.student_id}-legacy-alb-sg"
  }
}

resource "aws_security_group" "ec2" {
  name        = "${var.student_id}-legacy-ec2-sg"
  description = "Security group for legacy EC2 instances"
  vpc_id      = aws_vpc.legacy.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.student_id}-legacy-ec2-sg"
  }
}
