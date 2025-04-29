provider "aws" {
  region = "us-east-1"
}
resource "aws_instance" "tomcat_server" {
  ami           = "ami-084568db4383264d4"
  instance_type = "t2.micro"
  security_groups = ["sgalltraffic"]  # Reference the existing security group
  key_name      = "mujahed"
  tags = {
    Name = "Tomcat-Server"
  }
}
resource "aws_instance" "mysql_server"{
    ami="ami-084568db4383264d4"
    instance_type = "t2.micro"
    security_groups = ["sgalltraffic"]  # Reference the existing security group
    key_name      = "mujahed"
    tags = {
      Name = "mysql_server-Server"
  }
}
resource "aws_instance" "maven_server"{
    ami="ami-084568db4383264d4"
    instance_type = "t2.micro"
    security_groups = ["sgalltraffic"]  # Reference the existing security group
    key_name      = "mujahed"
    tags = {
      Name = "maven_server-Server"
  }
}

output "tomcat_server_ip" {
  value = aws_instance.tomcat_server.public_ip
}
output "mysql_server_ip" {
  value = aws_instance.mysql_server.public_ip
}
output "maven_server_ip" {
  value = aws_instance.maven_server.public_ip
