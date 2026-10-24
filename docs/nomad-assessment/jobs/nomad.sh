sudo install -d /opt/nomad /root/.docker
sudo cp -a /etc/nomad.d /etc/nomad.d.before-assessment
sudo tee /etc/nomad.d/nomad.hcl >/dev/null <<'EOF'
name       = "assessment-1"
datacenter = "dc1"
data_dir   = "/opt/nomad"
bind_addr  = "127.0.0.1"

advertise {
  http = "127.0.0.1"
  rpc  = "127.0.0.1"
  serf = "127.0.0.1"
}
server {
  enabled          = true
  bootstrap_expect = 1
}
client {
  enabled           = true
  servers           = ["127.0.0.1:4647"]
  network_interface = "eth0"
  reserved {
    cpu    = 300
    memory = 1024
  }
}
consul {
  address = "127.0.0.1:8500"
}
telemetry {
  collection_interval        = "5s"
  disable_hostname           = true
  prometheus_metrics         = true
  publish_allocation_metrics = true
  publish_node_metrics       = true
}
plugin "docker" {
  config {
    volumes {
      enabled = true
    }
    auth {
      config = "/root/.docker/config.json"
    }
  }
}
EOF
sudo nano /etc/nomad.d/nomad.hcl
sudo install -d /etc/systemd/system/nomad.service.d
sudo tee /etc/systemd/system/nomad.service.d/assessment.conf >/dev/null <<'EOF'
[Unit]
After=docker.service consul.service
Wants=docker.service consul.service

[Service]
User=root
Group=root
ExecStart=
ExecStart=/usr/bin/nomad agent -config=/etc/nomad.d/nomad.hcl
EOF

# An empty Docker auth file is sufficient for public images initially.
sudo sh -c 'test -f /root/.docker/config.json || printf "{}\n" > /root/.docker/config.json'
sudo chmod 600 /root/.docker/config.json
sudo nomad config validate /etc/nomad.d/nomad.hcl
sudo systemctl daemon-reload
sudo systemctl enable --now nomad
sudo systemctl restart nomad
nomad server members
nomad node status
nomad node status -self -verbose