data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_cidrs[count.index]
  count = 3
  availability_zone = data.aws_availability_zone.available.names[count.index]

  tags = {
    Name = "public-subnet-${count.index}"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidrs[count.index]
  count = 3
  availability_zone = data.aws_availability_zone.available.names[count.index]

  tags = {
    Name = "private-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw"
  }
}

resource "aws_eip" "ip" {


  tags = {
    Name = "elastic-ip" 
  }
}

resource "aws_nat_gateway" "nat" {
  subnet_id = aws_subnet.public_subnet[0].id
  allocation_id = aws_eip.ip.id

  tags = {
    Name = "nat" 
  }
}

resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-route-table" }
}

resource "aws_route_table" "private-route-table" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "private-route-table" }
}

resource "aws_route_table_association" "public" {
  count = 3
  route_table_id = aws_route_table.public-route-table.id
  subnet_id = aws_subnet.public_subnet[count.index].id
}

resource "aws_route_table_association" "private" {
  count = 3
  route_table_id = aws_route_table.private-route-table.id
  subnet_id = aws_subnet.private_subnet[count.index].id
}