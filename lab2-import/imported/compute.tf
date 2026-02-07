# compute.tf - EC2 Instance (imported)

resource "aws_instance" "legacy" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.legacy.id]

  # Note: user_data cannot be imported. If the instance was created with
  # user_data, you'll need to add it here based on what you know about
  # the original configuration.

  tags = {
    Name = "${var.student_id}-legacy-server"
  }

  lifecycle {
    prevent_destroy = true
  }
}
