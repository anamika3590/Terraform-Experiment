# Creating a VPC!
resource "aws_vpc" "my_VPC" {
  cidr_block = "192.168.0.0/16"
  # Enabling automatic hostname assigning
  enable_dns_hostnames = true
  tags = {
    Name = "test VPC"
  }
}
# Creating Public subnet!
resource "aws_subnet" "pub_subnet" {
  depends_on = [
    aws_vpc.my_VPC
  ]
  vpc_id = aws_vpc.my_VPC.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "eu-west-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet"
  }
}
# Creating Private subnet!
resource "aws_subnet" "pri_subnet" {
  depends_on = [
    aws_vpc.my_VPC,
    aws_subnet.pub_subnet
  ]
  vpc_id = aws_vpc.my_VPC.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "eu-west-1b"
  tags = {
    Name = "Private Subnet"
  }
}
# Creating an Internet Gateway
resource "aws_internet_gateway" "Internet_Gateway" {
  depends_on = [
    aws_vpc.my_VPC,
    aws_subnet.pub_subnet,
    aws_subnet.pri_subnet
  ]
  vpc_id = aws_vpc.my_VPC.id
  tags = {
    Name = "IG-Public-&-Private-VPC"
  }
}
# Creating an Route Table for the public subnet!
resource "aws_route_table" "Public-Subnet-RT" {
  depends_on = [
    aws_vpc.my_VPC,
    aws_internet_gateway.Internet_Gateway
  ]
  vpc_id = aws_vpc.my_VPC.id
  # NAT Rule
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Internet_Gateway.id
  }
  tags = {
    Name = "Route Table for Internet Gateway"
  }
}
# Creating a resource for the Route Table Association!
resource "aws_route_table_association" "RT-IG-Association" {

  depends_on = [
    aws_vpc.my_VPC,
    aws_subnet.pub_subnet,
    aws_subnet.pri_subnet,
    aws_route_table.Public-Subnet-RT
  ]
# Public Subnet ID
  subnet_id      = aws_subnet.pub_subnet.id
#  Route Table ID
  route_table_id = aws_route_table.Public-Subnet-RT.id
}
# Creating an Elastic IP for the NAT Gateway!
resource "aws_eip" "Nat-Gateway-EIP" {
  depends_on = [
    aws_route_table_association.RT-IG-Association
  ]
  vpc = true
}
# Creating a NAT Gateway!
resource "aws_nat_gateway" "NAT_GATEWAY" {
  depends_on = [
    aws_eip.Nat-Gateway-EIP
  ]
  # Allocating the Elastic IP to the NAT Gateway!
  allocation_id = aws_eip.Nat-Gateway-EIP.id
  # Associating it in the Public Subnet!
  subnet_id = aws_subnet.pub_subnet.id
  tags = {
    Name = "Nat-Gateway_Project"
  }
}
# Creating a Route Table for the Nat Gateway!
resource "aws_route_table" "NAT-Gateway-RT" {
  depends_on = [
    aws_nat_gateway.NAT_GATEWAY
  ]
  vpc_id = aws_vpc.my_VPC.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NAT_GATEWAY.id
  }
  tags = {
    Name = "Route Table for NAT Gateway"
  }
}
# Creating an Route Table Association of the NAT Gateway route 
# table with the Private Subnet!
resource "aws_route_table_association" "Nat-Gateway-RT-Association" {
  depends_on = [
    aws_route_table.NAT-Gateway-RT
  ]
#  Private Subnet ID for adding this route table to the DHCP server of Private subnet!
  subnet_id      = aws_subnet.pri_subnet.id
  route_table_id = aws_route_table.NAT-Gateway-RT.id
}

# Creating an AWS instance for the Webserver!
resource "aws_instance" "webserver" {
  depends_on = [
    aws_vpc.my_VPC,
    aws_subnet.pub_subnet,
    aws_subnet.pri_subnet,
    aws_security_group.BH-SG,
    aws_security_group.DB-SG-SSH
  ]
  ami = "ami-0ac43988dfd31ab9a"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.pub_subnet.id
  key_name = "Terraform_key"
  vpc_security_group_ids = [aws_security_group.WS-SG.id]
  tags = {
   Name = "Webserver_From_Terraform"
  }

  # Installing required softwares into the system!
  connection {
    type = "ssh"
    user = "ec2-user"
    private_key = file("./Terraform_key.pem")
    host = aws_instance.webserver.public_ip
  }

  # Code for installing the softwares!
  provisioner "remote-exec" {
    inline = [
        "sudo yum update -y",
        "sudo yum install php php-mysqlnd httpd -y",
        "wget https://wordpress.org/wordpress-4.8.14.tar.gz",
        "tar -xzf wordpress-4.8.14.tar.gz",
        "sudo cp -r wordpress /var/www/html/",
        "sudo chown -R apache.apache /var/www/html/",
        "sudo systemctl start httpd",
        "sudo systemctl enable httpd",
        "sudo systemctl restart httpd"
    ]
  }
}
# Creating an AWS instance for the Bastion Host, It should be launched in the public Subnet!
resource "aws_instance" "Bastion-Host" {
   depends_on = [
    aws_instance.webserver,
     aws_instance.MySQL
  ]
  ami = "ami-0ac43988dfd31ab9a"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.pub_subnet.id
  key_name = "Terraform_key"
  vpc_security_group_ids = [aws_security_group.BH-SG.id]
  tags = {
   Name = "Bastion_Host_From_Terraform"
  }
}

# Creating an AWS instance for the MySQL! It should be launched in the private subnet!
resource "aws_instance" "MySQL" {
  depends_on = [
    aws_instance.webserver,
  ]
  ami = "ami-0ac43988dfd31ab9a"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.pri_subnet.id
  key_name = "Terraform_key"
  vpc_security_group_ids = [aws_security_group.MySQL-SG.id, aws_security_group.DB-SG-SSH.id]
  tags = {
   Name = "MySQL_From_Terraform"
  }
}

