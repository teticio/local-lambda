module "key_pair" {
  source     = "terraform-aws-modules/key-pair/aws"
  key_name   = var.key_name
  public_key = file(var.public_key_file)
}

resource "aws_security_group" "ec2" {
  name = "ssh"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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

data "aws_ami" "lambda" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami_name]
  }
}

resource "aws_instance" "ec2" {
  ami                    = data.aws_ami.lambda.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = var.key_name

  root_block_device {
    volume_type = "gp2"
    volume_size = var.volume_size
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'SSH is now available.'"
    ]
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(var.private_key_file)
    host        = self.public_ip
  }
}

resource "aws_ebs_volume" "lambda" {
  availability_zone = aws_instance.ec2.availability_zone
  snapshot_id       = data.aws_ami.lambda.root_snapshot_id
}

resource "aws_volume_attachment" "lambda" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.lambda.id
  instance_id = aws_instance.ec2.id
}
