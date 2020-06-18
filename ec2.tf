provider "aws" {
  region = "ap-south-1"
  profile = "usertf"
}

resource "aws_security_group" "sg_group" {
  name        = "TLS"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-30405c58"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_group"
  }
}

resource "aws_instance" "tfinst" {
  ami = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "keyos1"
  security_groups = [ aws_security_group.sg_group.id ]
  subnet_id = "subnet-e3bcd7af"
  
  connection {
	type = "ssh"
	user = "ec2-user"
	private_key = file("C:/Users/KIIT/Downloads/keyos1.pem")
	host = aws_instance.tfinst.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
     ]
  }

  tags = {
    Name = "tfinst"
  }

}

resource "aws_ebs_volume" "vol1" {
  availability_zone = aws_instance.tfinst.availability_zone
  size = 1

  tags = {
    Name = "vol1"
  }
}

resource "aws_volume_attachment" "vol_attach" {
  device_name = "/dev/sdf"
  volume_id = aws_ebs_volume.vol1.id
  instance_id = aws_instance.tfinst.id
  force_detach = true
}

resource "null_resource" "mount" {
  depends_on = [ aws_volume_attachment.vol_attach, ]

  connection {
    type = "ssh"
    user = "ec2-user"
    private_key = file("C:/Users/KIIT/Downloads/keyos1.pem")
    host = aws_instance.tfinst.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdf",
      "sudo rm -rf /var/www/html/*",
      "sudo mount  /dev/xvdf  /var/www/html",
      "sudo git clone https://github.com/sarthakSharma5/cloud1.git /workspace",
      "sudo cp -r /workspace/* /var/www/html",
    ]
  }
}

resource "aws_s3_bucket" "tbuck1" {
  bucket = "terracode"
  acl = "public-read"
  versioning {
    enabled = true
  }

  tags = {
    Name = "terra 1"
    Env = "Dev"
  }
}

resource "aws_s3_bucket_object" "tbobj1" {
  bucket = aws_s3_bucket.tbuck1.bucket
  key = "terraObj"
  acl = "public-read"
  source = "C:/Users/KIIT/Downloads/cldcomp.jpg"
  depends_on = [ aws_s3_bucket.tbuck1 ]
}

resource "aws_cloudfront_distribution" "terra_distrb" {
  origin {
    domain_name = "cldcomp.jpg"
    origin_id = "Cloud_comp"

    custom_origin_config {
      http_port = 80
      https_port = 80
      origin_protocol_policy = "match-viewer"
      origin_ssl_protocols = [ "TLSv1", "TLSv1.1", "TLSv1.2" ]
    }
  }
  enabled = true
  default_cache_behavior {
    allowed_methods = [ "DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT",]
    cached_methods = [ "GET", "HEAD" ]
    target_origin_id = "Cloud_comp"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
