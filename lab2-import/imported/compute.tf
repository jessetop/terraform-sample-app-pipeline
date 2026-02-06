# compute.tf - Launch Template and Auto Scaling Group (imported)

resource "aws_launch_template" "legacy" {
  name          = "${var.student_id}-legacy-lt"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2.id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf install -y httpd git
    systemctl enable httpd
    systemctl start httpd

    # Clone 2048 game (small repo, fast download)
    git clone https://github.com/gabrielecirulli/2048.git /tmp/2048
    cp -r /tmp/2048/* /var/www/html/

    # Add instance info to the page
    echo "<!-- Instance: $(hostname) | Student: ${var.student_id} | AZ: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone) -->" >> /var/www/html/index.html
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.student_id}-legacy-instance"
    }
  }

  tags = {
    Name = "${var.student_id}-legacy-lt"
  }
}

resource "aws_autoscaling_group" "legacy" {
  name                = "${var.student_id}-legacy-asg"
  desired_capacity    = 2
  max_size            = 4
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.legacy.arn]
  vpc_zone_identifier = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  launch_template {
    id      = aws_launch_template.legacy.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.student_id}-legacy-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Student"
    value               = var.student_id
    propagate_at_launch = true
  }
}
