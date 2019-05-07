terraform {
  backend "s3" {
  }
}

provider "aws" {
}

variable "NAME" {
  default = "aol"
}

resource "aws_vpc" "VPC" {
  cidr_block = "192.168.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags {
    Name = "${var.NAME}"
  }
}

data "aws_availability_zones" "AZS" {
}

resource "aws_subnet" "PUBLIC_SUBNETS" {
  count = "${length(data.aws_availability_zones.AZS.names)}"
  cidr_block = "${cidrsubnet(aws_vpc.VPC.cidr_block, 8, count.index)}"
  vpc_id = "${aws_vpc.VPC.id}"
  availability_zone = "${data.aws_availability_zones.AZS.names[count.index]}"
  tags {
    Name = "${var.NAME}"
    Type = "Public"
  }
}

resource "aws_internet_gateway" "INTERNET" {
  vpc_id = "${aws_vpc.VPC.id}"

  tags {
    Name = "${var.NAME}"
  }
}

resource "aws_route" "PUBLIC_ROUTES" {
  route_table_id = "${aws_route_table.INTERNET_TABLE.id}"
  gateway_id = "${aws_internet_gateway.INTERNET.id}"
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table" "INTERNET_TABLE" {
  vpc_id = "${aws_vpc.VPC.id}"
  tags {
    Name = "${var.NAME}"
    Type = "Public"
  }
}

resource "aws_route_table_association" "PUBLIC_TABLES" {
  count = "${length(data.aws_availability_zones.AZS.names)}"
  subnet_id = "${element(aws_subnet.PUBLIC_SUBNETS.*.id, count.index)}"
  route_table_id = "${aws_route_table.INTERNET_TABLE.id}"
}

resource "aws_eip" "IP" {
  vpc = true
}

resource "aws_nat_gateway" "NAT" {
  allocation_id = "${aws_eip.IP.id}"
  subnet_id = "${aws_subnet.PUBLIC_SUBNETS.0.id}"
  
  tags {
    Name = "${var.NAME}"
  }
}

resource "aws_subnet" "PRIVATE_SUBNETS" {
  count = "${length(data.aws_availability_zones.AZS.names)}"
  cidr_block = "${cidrsubnet(aws_vpc.VPC.cidr_block, 8, count.index + length(data.aws_availability_zones.AZS.names))}"
  vpc_id = "${aws_vpc.VPC.id}"
  availability_zone = "${data.aws_availability_zones.AZS.names[count.index]}"

  tags {
    Name = "${var.NAME}"
    Type = "Private"
  }
}

resource "aws_route" "BRIDGE_ROUTE" {
  route_table_id  = "${aws_route_table.NAT_TABLE.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = "${aws_nat_gateway.NAT.id}"
}

resource "aws_route_table" "NAT_TABLE" {
  vpc_id = "${aws_vpc.VPC.id}"

  tags {
    Name = "${var.NAME}"
    Type = "Private"
  }
}

resource "aws_route_table_association" "PRIVATE_ROUTES" {
  count = "${length(data.aws_availability_zones.AZS.names)}"
  subnet_id = "${element(aws_subnet.PRIVATE_SUBNETS.*.id, count.index)}"
  route_table_id = "${aws_route_table.NAT_TABLE.id}"
}
