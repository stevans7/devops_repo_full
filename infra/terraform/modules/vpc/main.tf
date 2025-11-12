resource "aws_vpc" "this" { cidr_block = var.vpc_cidr  tags = { Name = "${var.project}-vpc" } }
resource "aws_subnet" "public" { count=2 vpc_id=aws_vpc.this.id cidr_block=cidrsubnet(var.vpc_cidr,4,count.index) map_public_ip_on_launch=true }
resource "aws_subnet" "private" { count=2 vpc_id=aws_vpc.this.id cidr_block=cidrsubnet(var.vpc_cidr,4,count.index+2) }

# Internet access for public subnets
resource "aws_internet_gateway" "igw" { vpc_id = aws_vpc.this.id }
resource "aws_route_table" "public" { vpc_id = aws_vpc.this.id route { cidr_block = "0.0.0.0/0" gateway_id = aws_internet_gateway.igw.id } }
resource "aws_route_table_association" "public" { count = length(aws_subnet.public) subnet_id = aws_subnet.public[count.index].id route_table_id = aws_route_table.public.id }

# NAT for private subnets (single NAT in first public subnet)
resource "aws_eip" "nat" { domain = "vpc" }
resource "aws_nat_gateway" "nat" { allocation_id = aws_eip.nat.id subnet_id = aws_subnet.public[0].id }
resource "aws_route_table" "private" { vpc_id = aws_vpc.this.id route { cidr_block = "0.0.0.0/0" nat_gateway_id = aws_nat_gateway.nat.id } }
resource "aws_route_table_association" "private" { count = length(aws_subnet.private) subnet_id = aws_subnet.private[count.index].id route_table_id = aws_route_table.private.id }
output "vpc_id" { value = aws_vpc.this.id }
output "public_subnets" { value = aws_subnet.public[*].id }
output "private_subnets" { value = aws_subnet.private[*].id }
