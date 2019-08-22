#######################################################
#####     AWS PROVIDE & AVAILABILITY ZONES        #####
#######################################################

provider "aws" {
  region = "${var.region}"
}

#######################################################
#####     VIRTUAL PRIVATE CLOUD	                  #####
#######################################################

resource "aws_vpc" "iac_vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  enable_classiclink   = "false"

  tags {
    Name = "iac_vpc"
  }
}

#######################################################
#####     PUBLIC SUBNET			          #####
#######################################################

resource "aws_subnet" "iac_public_subnet" {
  vpc_id                  = "${aws_vpc.iac_vpc.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = "eu-west-1a"

  tags {
    Name = "iac_public_subnet"
  }
}

#######################################################
#####     PRIVATE SUBNET 	                  #####
#######################################################

resource "aws_subnet" "iac_private_subnet" {
  vpc_id                  = "${aws_vpc.iac_vpc.id}"
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = "false"
  availability_zone       = "eu-west-1a"

  tags {
    Name = "iac_private_subnet"
  }
}

#######################################################
######     INTERNET GATEWAY                       #####
#######################################################
resource "aws_internet_gateway" "iac_gw" {
  vpc_id = "${aws_vpc.iac_vpc.id}"

  tags {
    Name = "iac_gw"
  }
}

#######################################################
#####     NETWORK ADDRESS TRANSLATION ELASTIC IP ######
#######################################################

resource "aws_eip" "ngw_elastic_ip" {
  vpc = true

  tags = {
    Name = "iac_ngw"
  }
}

resource "aws_nat_gateway" "iac_nat_gateway" {
  allocation_id = "${aws_eip.ngw_elastic_ip.id}"
  subnet_id     = "${aws_subnet.iac_public_subnet.id}"
  depends_on    = ["aws_internet_gateway.iac_gw"]

  tags {
    Name = "iac_nat_eip"
  }
}

#######################################################
######     ROUTE TABLE 			          #####
#######################################################

resource "aws_route_table" "iac_public_rt" {
  vpc_id = "${aws_vpc.iac_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.iac_gw.id}"
  }

  tags {
    Name = "iac_public_rt"
  }
}

#######################################################
#####     ASSIGN ROUTE TABLE TO PUBLIC SUBNET     #####
#######################################################

resource "aws_route_table_association" "iac_public_assoc" {
  subnet_id      = "${aws_subnet.iac_public_subnet.id}"
  route_table_id = "${aws_route_table.iac_public_rt.id}"
}

#######################################################
#####     SSH and SECURITY GROUP        	  #####
#######################################################

resource "aws_security_group" "iac_secgroup" {
  name = "iac-secgroup"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_key_pair" "web-ec2-key" {
  key_name   = "web-key"
  public_key = "${file("~/.ssh/app-ec2-key.pub")}"
}

#######################################################
#####     AUTO SCALING GROUP    		  #####
#######################################################

resource "aws_launch_configuration" "iac_lc_asg" {
  name_prefix     = "iac_asg_launchconfig"
  image_id        = "${var.ami}"
  instance_type   = "${var.instance_type}"
  key_name        = "${aws_key_pair.web-ec2-key.key_name}"
  security_groups = ["${aws_security_group.iac_secgroup.id}"]

  user_data = <<-EOF
                 #!/bin/bash
                 yum -y install httpd
                 echo 'bernard - - - - > Website 01!' > /var/www/html/index.html
                 systemctl restart httpd
                 systemctl enable  httpd
                 firewall-cmd --permanent --add-port=80/tcp
                 firewall-cmd --reload
                EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "iac_asg" {
  name                 = "iac_instance_asg"
  launch_configuration = "${aws_launch_configuration.iac_lc_asg.id}"
  availability_zones   = ["${data.aws_availability_zones.all.names}"]

  load_balancers    = ["${aws_elb.iac_elb.name}"]
  health_check_type = "ELB"

  max_size = 3
  min_size = 2

  tag {
    key                 = "name"
    value               = "iac-asg-setup"
    propagate_at_launch = true
  }
}

data "aws_availability_zones" "all" {}

#######################################################
#####     ELASTIC LOAD BALANCER                   #####
#######################################################
resource "aws_elb" "iac_elb" {
  name               = "iac-elb"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  security_groups    = ["${aws_security_group.iac_secgroup.id}"]

  "listener" {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    interval            = 30
    target              = "HTTP:80/"
    timeout             = 3
    unhealthy_threshold = 2
  }
}
