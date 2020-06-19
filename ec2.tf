provider "aws"{
     region = "ap-south-1"
     profile = "mylogin"
}
resource "tls_private_key" "example" {
  algorithm   = "RSA"
  rsa_bits = "2048"
}
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key =  tls_private_key.example.public_key_openssh
}
resource "local_file" "foo" {
    content     = tls_private_key.example.private_key_pem
    filename = "C:/Users/HP/Downloads/aws_keys/deployer-key.pem"
}

resource "aws_security_group" "allow_SSH_HTTP" {
  name = "allow_SSH_HTTP"
  description = "Allows SSH and HTTP"
  vpc_id = "vpc-c21804aa"

  ingress {
      description = "SSH"
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
      description = "HTTP"
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      
  }
tags = {
    Name = "allow_SSH_HTTP"
  }
}


resource "aws_instance" "web" {
  
  depends_on = [
    local_file.foo,
  ]

  ami           = "ami-052c08d70def0ac62"
  instance_type = "t2.micro"
  key_name = "deployer-key"
  security_groups = ["allow_SSH_HTTP"]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.example.private_key_pem
    host     = aws_instance.web.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
  tags = {
    Name = "HelloWorld"
  }
}

resource "aws_ebs_volume" "myebs" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1
  tags = {
    Name = "lwhybridebs"
  }
}


resource "aws_volume_attachment" "AttachVolume" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.myebs.id
  instance_id = aws_instance.web.id
  force_detach = true
}

output "My_instance_ip" {
value = aws_instance.web.public_ip
}

resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.AttachVolume,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.example.private_key_pem
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Ma9si/LwProject.git /var/www/html/",
      "sudo restorecon -r /var/www/html"
    ]
  }
}

resource "null_resource" "nullremote2"  {
provisioner "local-exec" {
	    command = "git clone https://github.com/Ma9si/LwProject.git C:/Users/HP/Documents/myhybridfolder"
  	}
}

resource "aws_s3_bucket" "mybucket" {
  bucket = "mybucket112"
  
  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.mybucket.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object" "object" {
  bucket = aws_s3_bucket.mybucket.bucket
  key    = "mansi.jpg"
  source = "C:/Users/HP/Documents/myhybridfolder/mansi.jpg"
  acl    = "private"
}

locals {
  s3_origin_id = "myS3Origin"
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Some comment"
}

resource "aws_cloudfront_distribution" "s3_distribution" {

depends_on = [
    aws_s3_bucket.mybucket,
    aws_s3_bucket_object.object
  ]
  origin {
    domain_name = aws_s3_bucket.mybucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }

}
  
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"


  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    viewer_protocol_policy = "redirect-to-https"
    }
 
    restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN"] 
      }
    }  
    
    viewer_certificate {
    cloudfront_default_certificate = true
    }
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.mybucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = ["${aws_s3_bucket.mybucket.arn}"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }
}

resource "aws_s3_bucket_policy" "example" {
  bucket = aws_s3_bucket.mybucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

resource "null_resource" "nullremote4"  {

depends_on = [
    aws_cloudfront_distribution.s3_distribution
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.example.private_key_pem
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo sed -i '$a <img src = https://${aws_cloudfront_distribution.s3_distribution.domain_name}/mansi.jpg width = '200' height ='200' />' /var/www/html/project.html",
    ]
  }
}

 output "Cloud_Front_Domain_Name" {
   value = aws_cloudfront_distribution.s3_distribution.domain_name 
}

resource "null_resource" "nullremote5" {

depends_on = [ 

null_resource.nullremote4, 

]
 provisioner "local-exec" { 

command = "chrome ${aws_instance.web.public_ip}/project.html" 

}

}

