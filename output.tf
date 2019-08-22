output "VPC ID" {
  value = "${aws_vpc.iac_vpc.id}"
}

output "Public Subnet ID" {
  value = "${aws_subnet.iac_public_subnet.id}"
}

output "Private Subnet ID" {
  value = "${aws_subnet.iac_private_subnet.id}"
}

output "NAT Elastic IP" {
  value = "${aws_eip.ngw_elastic_ip.public_ip}"
}

output "elb_dns_name" {
  value = "${aws_elb.iac_elb.dns_name}"
}
