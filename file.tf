provider "aws" {
  region     = "ap-south-1"
  profile    = "sahil123"
}
resource "aws_security_group" "my-security-group" {
  name        = "my-security-group"
  description = "Allow TLS inbound traffic"


  ingress {
    description = "allow http traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    description = "allow ssh traffic"
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

  tags = {
    Name = "my-security-group"
  }
}
resource "aws_instance" "my-webserver" {
  ami             = "ami-0447a12f28fddb066"
  instance_type   = "t2.micro"
  key_name        = "mykey11"
  security_groups = [aws_security_group.my-security-group.name]
  
  tags = {
    Name = "myterraos"
  }
}
resource "aws_ebs_volume" "myvol" {
  availability_zone = aws_instance.my-webserver.availability_zone
  size              = 1
  tags = {
    Name = "volume-1"
  }
}


resource "aws_volume_attachment" "myvol-attach" {
  device_name = "/dev/xvdh"
  volume_id   = aws_ebs_volume.myvol.id
  instance_id = aws_instance.my-webserver.id
  force_detach = true
}
resource "null_resource" "nullremote1" {
depends_on = [
aws_volume_attachment.myvol-attach,
]
connection {
type = "ssh"
user = "ec2-user"
private_key = file("C:/Users/sahil/Downloads/mykey11.pem")
host = aws_instance.my-webserver.public_ip
}
provisioner "remote-exec" {
                inline = [
                            "sudo yum install httpd git php -y",
                            "sudo systemctl restart httpd",
                            "sudo systemctl enable httpd",
                            "sudo mkfs.ext4 /dev/xvdh",
                            "sudo mount /dev/xvdh /var/www/html",
                            "sudo rm -rf /var/www/html/*",
                            "sudo git clone https://github.com/sahil2019/myrepo.git /var/www/html/"
                          ]
  }
}

resource "aws_s3_bucket" "mybucket" {
  bucket    = "sahil3514-terraform-bucket"
  acl       = "public-read"
  versioning {
    enabled = true
  }

}
locals {
  s3_origin_id = "myS3Origin"
}
resource "aws_s3_bucket_object" "object" {
  bucket       =  aws_s3_bucket.mybucket.bucket
  key          = "my-image.png"
  acl          = "public-read"
  source       = "C:/Users/sahil/Pictures/thumbnail.png"
  content_type = "image/png"
}
/*creating cloudfront*/
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "my-website-s3"
}
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.mybucket.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"
s3_origin_config {
  origin_access_identity = "${aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path}"
}
   
  }
 enabled             = true
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

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
  

}
resource "null_resource" nullremote2{
depends_on = [
          null_resource.nullremote1,
          #aws_cloudfront_distribution.s3_distribution,
]
connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/sahil/Downloads/mykey11.pem")
    host     = aws_instance.my-webserver.public_ip
  }

provisioner "remote-exec" {
    inline = [
             "sudo su <<EOF",
             "sudo echo \"<img src='https://${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.object.key}' width='1000' height='1000'>\" >> /var/www/html/my.html",
             "EOF"
             ]
    
  }
}

resource "null_resource" "nullremote3"  {

depends_on = [
    null_resource.nullremote1,
    null_resource.nullremote2,

    
    ]
provisioner "local-exec" {
	    command = "chrome  ${aws_instance.my-webserver.public_ip}/my.html"
  	}
}



 