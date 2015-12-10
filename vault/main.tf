resource "digitalocean_droplet" "server" {
  image = "${var.image}"
  count = "${var.count}"
  name = "${var.role}-${var.region}-${count.index}"
  region = "${var.region}"
  size = "${var.size}"
  ssh_keys = ["${var.ssh_key_id}"]

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get upgrade -y",
      "apt-get install -y unzip"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "cd /tmp",
      # consul client
      "wget https://releases.hashicorp.com/consul/0.6.0/consul_0.6.0_linux_amd64.zip",
      "unzip consul_0.6.0_linux_amd64.zip -d /usr/local/bin",
      "chmod +x /usr/local/bin/consul",
      "rm /tmp/consul_0.6.0_linux_amd64.zip",

      # vault server
      "wget https://releases.hashicorp.com/vault/0.4.0/vault_0.4.0_linux_amd64.zip",
      "unzip vault_0.4.0_linux_amd64.zip -d /usr/local/bin",
      "chmod +x /usr/local/bin/vault",
      "setcap cap_ipc_lock=+ep $(readlink -f /usr/local/bin/vault)",
      "rm /tmp/vault_0.4.0_linux_amd64.zip"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "useradd -ms /bin/bash vault",
      "mkdir /var/consul",
      "chown vault:vault /var/consul",
      "mkdir -p /etc/vault",
      "chmod a+w /etc/vault",
      "mkdir -p /etc/consul",
      "chmod a+w /etc/consul"
    ]
  }

  provisioner "file" {
    source = "${path.module}/conf/vault-server.tpl"
    destination = "/etc/vault/config.json"
  }

  # Would much rather 'template_file' be a provisioner instead of a resource.
  # This terrible hack is used to avoid a cycle
  provisioner "remote-exec" {
    inline = [
      "echo '${replace(template_file.consul.rendered, "ADDR", self.ipv4_address)}' > /etc/consul/config.json"
    ]
  }

  provisioner "file" {
    source = "${var.ca_file}"
    destination = "/etc/consul/ca.pem"
  }

  provisioner "file" {
    source = "${var.consul_cert_file}"
    destination = "/etc/consul/cert.pem"
  }

  provisioner "file" {
    source = "${var.consul_key_file}"
    destination = "/etc/consul/key.pem"
  }

  provisioner "file" {
    source = "${var.vault_cert_file}"
    destination = "/etc/vault/cert.pem"
  }

  provisioner "file" {
    source = "${var.vault_key_file}"
    destination = "/etc/vault/key.pem"
  }

  provisioner "file" {
    source = "${path.module}/conf/upstart-consul.conf"
    destination = "/etc/init/consul.conf"
  }

  provisioner "file" {
    source = "${path.module}/conf/upstart-vault.conf"
    destination = "/etc/init/vault.conf"
  }

  provisioner "remote-exec" {
    inline = "sudo start consul || sudo restart consul"
  }

  provisioner "remote-exec" {
    inline = "sudo start vault || sudo restart vault"
  }
}


resource "template_file" "consul" {
  template = "${file("${path.module}/conf/consul-client.tpl")}"

  vars {
    encrypt = "${var.consul_encrypt_key}"
    dc = "${var.region}"
    consul_address = "${var.consul_address}"
  }
}
