data "template_file" "consul_update_aws" {
  template = "${file("${module.shared.path}/consul/userdata/consul_update.sh.tpl")}"

  vars {
    region                  = "${var.aws_region}"
    atlas_token             = "${var.atlas_token}"
    atlas_username          = "${var.atlas_username}"
    atlas_environment       = "${var.atlas_environment}"
    consul_bootstrap_expect = "${var.aws_servers}"
    instance_address_url    = "http://169.254.169.254/2014-02-25/meta-data/local-ipv4"
  }

  depends_on = ["aws_vpn_gateway.vpn"] // give the VPN some time to connect
}

data "template_file" "pqs_aws" {
  template = "${file("${module.shared.path}/consul/userdata/pqs.sh.tpl")}"
}

//
// Consul & Nomad Servers
//
resource "aws_instance" "server" {
  count         = "${var.aws_servers}"
  instance_type = "${var.aws_instance_type}"
  ami           = "${var.aws_source_ami}"
  key_name      = "${aws_key_pair.main.key_name}"
  subnet_id     = "${aws_subnet.subnet_a.id}"

  vpc_security_group_ids = [
    "${aws_security_group.default_egress.id}",
    "${aws_security_group.admin_access.id}",
    "${aws_security_group.internal_access.id}",
  ]

  tags {
    Name = "${var.atlas_environment}-nomad-server-${count.index + 1}"
  }

  connection {
    user     = "ubuntu"
    key_file = "${module.shared.private_key_path}"
  }

  provisioner "file" {
    source      = "${module.shared.path}/consul/consul.d/consul_server.json"
    destination = "/tmp/consul.json.tmp"
  }

  provisioner "file" {
    source      = "${module.shared.path}/consul/init/consul.conf"
    destination = "/tmp/consul.conf"
  }

  provisioner "remote-exec" {
    scripts = [
      "${module.shared.path}/nomad/installers/nomad_install.sh",
      "${module.shared.path}/consul/installers/consul_install.sh",
      "${module.shared.path}/consul/installers/consul_conf_install.sh",
      "${module.shared.path}/consul/installers/dnsmasq_install.sh",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "${data.template_file.consul_update_aws.rendered}",
      "${data.template_file.pqs_aws.rendered}",
    ]
  }

  provisioner "remote-exec" {
    inline = <<CMD
cat > /tmp/nomad.hcl <<EOF
data_dir     = "/opt/nomad/data"
enable_debug = true
bind_addr    = "0.0.0.0"
region       = "${var.aws_region}"
datacenter   = "${var.aws_region}"
log_level    = "DEBUG"

advertise {
  http = "${self.private_ip}:4646"
  rpc  = "${self.private_ip}:4647"
  serf = "${self.private_ip}:4648"
}

consul {
  server_auto_join =  true
  client_auto_join =  true
}

atlas {
  infrastructure = "${var.atlas_username}/${var.atlas_environment}"
  token          = "${var.atlas_token}"
}

addresses {
  rpc  = "${self.private_ip}"
  serf = "${self.private_ip}"
}

server {
  enabled          = true
  bootstrap_expect = ${var.aws_servers}
}
EOF
CMD
  }

  provisioner "file" {
    source      = "${module.shared.path}/nomad/init/nomad.conf"
    destination = "/tmp/nomad.conf"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/nomad.hcl  /etc/nomad.d/",
      "sudo mv /tmp/nomad.conf /etc/init/",
      "sudo service nomad start || sudo service nomad restart",
      "sudo sed -i -- 's/listen-address=127.0.0.1/listen-address=0.0.0.0/g' /etc/dnsmasq.d/consul",
      "sudo service dnsmasq restart",
    ]
  }
}

//
// Nomad & Consul Clients
//
resource "aws_instance" "nomad_client" {
  count         = "${var.aws_nomad_clients}"
  instance_type = "${var.aws_instance_type}"
  ami           = "${var.aws_source_ami}"
  key_name      = "${aws_key_pair.main.key_name}"
  subnet_id     = "${aws_subnet.subnet_a.id}"

  vpc_security_group_ids = [
    "${aws_security_group.default_egress.id}",
    "${aws_security_group.admin_access.id}",
    "${aws_security_group.internal_access.id}",
  ]

  tags {
    Name = "${var.atlas_environment}-nomad-client-${count.index + 1}"
  }

  connection {
    user     = "ubuntu"
    key_file = "${module.shared.private_key_path}"
  }

  provisioner "file" {
    source      = "${module.shared.path}/consul/consul.d/consul_client.json"
    destination = "/tmp/consul.json.tmp"
  }

  provisioner "file" {
    source      = "${module.shared.path}/consul/init/consul.conf"
    destination = "/tmp/consul.conf"
  }

  provisioner "remote-exec" {
    scripts = [
      "${module.shared.path}/nomad/installers/docker_install.sh",
      "${module.shared.path}/nomad/installers/nomad_install.sh",
      "${module.shared.path}/consul/installers/consul_install.sh",
      "${module.shared.path}/consul/installers/consul_conf_install.sh",
      "${module.shared.path}/consul/installers/dnsmasq_install.sh",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "${data.template_file.consul_update_aws.rendered}",
    ]
  }

  provisioner "remote-exec" {
    inline = <<CMD
cat > /tmp/nomad.hcl <<EOF
data_dir     = "/opt/nomad/data"
enable_debug = true
bind_addr    = "0.0.0.0"
region       = "${var.aws_region}"
datacenter   = "${var.aws_region}"
log_level    = "DEBUG"

advertise {
  http = "${self.private_ip}:4646"
  rpc  = "${self.private_ip}:4647"
  serf = "${self.private_ip}:4648"
}

consul {
  server_auto_join =  true
  client_auto_join =  true
}

atlas {
  infrastructure = "${var.atlas_username}/${var.atlas_environment}"
  token          = "${var.atlas_token}"
}

client {
  enabled    = true

  options {
    "docker.cleanup.image"   = "0"
    "driver.raw_exec.enable" = "1"
  }

  meta {
    region = "${var.aws_region}"
  }
}
EOF
CMD
  }

  provisioner "file" {
    source      = "${module.shared.path}/nomad/init/nomad.conf"
    destination = "/tmp/nomad.conf"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/nomad.hcl  /etc/nomad.d/",
      "sudo mv /tmp/nomad.conf /etc/init/",
      "sudo service nomad start || sudo service nomad restart",
    ]
  }
}
