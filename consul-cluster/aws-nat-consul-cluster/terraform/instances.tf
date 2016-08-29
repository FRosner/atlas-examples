data "template_file" "consul_update" {
  template = "${file("${module.shared.path}/consul/userdata/consul_update.sh.tpl")}"

  vars {
    region                  = "${var.region}"
    atlas_token             = "${var.atlas_token}"
    atlas_username          = "${var.atlas_username}"
    atlas_environment       = "${var.atlas_environment}"
    consul_bootstrap_expect = "${var.consul_bootstrap_expect}"
  }
}

//
// Consul Client
//
data "atlas_artifact" "consul_client" {
  name = "${var.atlas_username}/consul_client"
  type = "amazon.image"
}

resource "aws_instance" "consul_client" {
  instance_type          = "${var.instance_type}"
  ami                    = "${data.atlas_artifact.consul_client.metadata_full.region-us-east-1}"
  key_name               = "${aws_key_pair.main.key_name}"

  user_data              = "${data.template_file.consul_update.rendered}"

  vpc_security_group_ids = ["${aws_security_group.default_egress.id}","${aws_security_group.admin_access.id}","${aws_security_group.consul_client.id}"]
  subnet_id              = "${aws_subnet.subnet_a.id}"

  tags {
    Name = "consul_client"
  }

}

//
// Consul Servers
//
data "atlas_artifact" "consul" {
  name = "${var.atlas_username}/consul"
  type = "amazon.image"
}

resource "aws_instance" "consul_0" {
  instance_type          = "${var.instance_type}"
  ami                    = "${data.atlas_artifact.consul.metadata_full.region-us-east-1}"
  key_name               = "${aws_key_pair.main.key_name}"

  user_data              = "${data.template_file.consul_update.rendered}"

  vpc_security_group_ids = ["${aws_security_group.default_egress.id}","${aws_security_group.admin_access.id}","${aws_security_group.consul.id}"]
  subnet_id              = "${aws_subnet.subnet_a.id}"

  tags {
    Name = "consul_0"
  }

}

resource "aws_instance" "consul_1" {
  instance_type          = "${var.instance_type}"
  ami                    = "${data.atlas_artifact.consul.metadata_full.region-us-east-1}"
  key_name               = "${aws_key_pair.main.key_name}"

  user_data              = "${data.template_file.consul_update.rendered}"

  vpc_security_group_ids = ["${aws_security_group.default_egress.id}","${aws_security_group.admin_access.id}","${aws_security_group.consul.id}"]
  subnet_id              = "${aws_subnet.subnet_b.id}"

  tags {
    Name = "consul_1"
  }

}

resource "aws_instance" "consul_2" {
  instance_type          = "${var.instance_type}"
  ami                    = "${data.atlas_artifact.consul.metadata_full.region-us-east-1}"
  key_name               = "${aws_key_pair.main.key_name}"

  user_data              = "${data.template_file.consul_update.rendered}"

  vpc_security_group_ids = ["${aws_security_group.default_egress.id}","${aws_security_group.admin_access.id}","${aws_security_group.consul.id}"]
  subnet_id              = "${aws_subnet.subnet_c.id}"

  tags {
    Name = "consul_2"
  }

}

//
// NAT
//
resource "aws_instance" "nat" {
  instance_type          = "${var.instance_type}"
  ami                    = "${var.nat_ami}"
  key_name               = "${aws_key_pair.main.key_name}"

  vpc_security_group_ids = ["${aws_security_group.default_egress.id}","${aws_security_group.admin_access.id}","${aws_security_group.nat.id}"]
  subnet_id              = "${aws_subnet.public.id}"

  source_dest_check = false

  tags {
    Name = "nat"
  }

}
