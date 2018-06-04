Setup SSH Access for AWS instances
===
This walkthrough will help you generate an rsa key pair and ssh into AWS machines created automatically using terraform. All the steps mentioned below assume you to be in the directory which has all the terraform `*.tf` files. Its always advised to delete ssh keys after debugging to prevent any security threats.

Generate an ssh key pair
--------------
Create a directory named `ssh_keys` and execute the given command to generate a new rsa key pair and set the key password to be null. The null private key password allows for automated SSH connections.

```
$ ssh-keygen -t rsa -C "tmp-key" -P '' -f ssh_keys/tmp-key
```

Register the key pair on aws
----------------
Create a new file `key-pairs.tf` with the below configuration and register the newly generated ssh key pair by running `$ terraform plan` and `$ terraform apply`.

```
resource "aws_key_pair" "debugging" {
    key_name = "tmp-key"
    public_key = "${file(\"ssh_keys/tmp-key.pub\")}"
}
```

Allow ssh connection in security group
-----
Make sure to allow ssh connections on the port you are using, default is 22. If you don't have a security group you can add one

```
resource "aws_security_group" "allow_ssh" {
  name = "allow_ssh"
    description = "Allow ssh connections on port 22"

  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
}
```
Run `$ terraform plan` followed by `$ terraform apply` to create security group.

Add key pair and security group to aws instance
------
Link key pair and security group to the instance by adding `key_name = "${aws_key_pair.debugging.key_name}"` and `security_groups = ["${aws_security_group.allow_ssh.id}"]` in terraform configuration of aws instance. Note that this instance assumes you are in the `us-east-1` region. If you are in a different region, use an AMI specific to that region.

```
resource "aws_instance" "app_server" {
  count = 1
  ami = "ami-408c7f28"
  instance_type = "t1.micro"
  security_groups = ["${aws_security_group.allow_ssh.name}"]
  key_name = "${aws_key_pair.debugging.key_name}"
}
```
Run `$ terraform plan` followed by `$ terraform apply` to create the new instance linked with security group and ssh keys.

SSH into the machine
------------
That's it ! You can now ssh into the machine using the newly generated key pair. Replace the ip with the public ip of instance as given by `terraform show` and ssh using `ubuntu` as a default username.

```
ssh -i ssh_keys/tmp-key ubuntu@54.165.54.137
```
