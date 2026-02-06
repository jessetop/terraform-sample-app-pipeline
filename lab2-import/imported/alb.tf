# alb.tf - Application Load Balancer (imported)

resource "aws_lb" "legacy" {
  name               = "${var.student_id}-legacy-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = {
    Name = "${var.student_id}-legacy-alb"
  }
}

resource "aws_lb_target_group" "legacy" {
  name     = "${var.student_id}-legacy-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.legacy.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.student_id}-legacy-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.legacy.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.legacy.arn
  }

  tags = {
    Name = "${var.student_id}-legacy-listener"
  }
}
