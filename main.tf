# Variables will be included in a base.tfvars file

provider "aws" {
  access_key = "${var.ak}"
  secret_key = "${var.sk}"
  region = "eu-west-1"
}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {}

# Not required: currently used in conjuction with using
# icanhazip.com to determine local workstation external IP
# to open EC2 Security Group access to the Kubernetes cluster.
# See workstation-external-ip.tf for additional information.
provider "http" {}


# VPC Resources
#  * VPC
#  * Subnets
#  * Internet Gateway
#  * Route Table
#

resource "aws_vpc" "demo-vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "demo-sub" {
  count = 2
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block        = "10.0.${count.index}.0/24"
  vpc_id            = "${aws_vpc.demo-vpc.id}"

}

resource "aws_internet_gateway" "demo-gate" {
  vpc_id = "${aws_vpc.demo-vpc.id}"

}

resource "aws_route_table" "demo-route" {
  vpc_id = "${aws_vpc.demo-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.demo-gate.id}"
  }
}

resource "aws_route_table_association" "demo" {
  count = 2

  subnet_id      = "${aws_subnet.demo-sub.*.id[count.index]}"
  route_table_id = "${aws_route_table.demo-route.id}"
}


# AWS S3 bucket

resource "aws_s3_bucket" "b" {
  bucket = "sgrosu-buchetel"
  acl    = "private"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

# AWS s3 endpoint

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = "${aws_vpc.demo-vpc.id}"
  service_name = "com.amazonaws.eu-west-1.s3"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "test_s3" {
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
  subnet_id =  "${aws_subnet.demo-sub.*.id[0]}"
  key_name = "${aws_key_pair.deployer.key_name}"

  tags = {
    Name = "Test_S3_Endpoint"
  }
}

resource "aws_eip" "lb" {
  instance = "${aws_instance.test_s3.id}"
  vpc      = true
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = "${var.pk}"
}