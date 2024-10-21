#cloud-config
package_update: true
packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - software-properties-common
runcmd:
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  - add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  - apt-get update
  - apt-get install -y docker-ce docker-compose
  - systemctl start docker
  - systemctl enable docker
  - curl -sSL https://raw.githubusercontent.com/binhnv56/nextcloud-install/refs/heads/main/install_ssl.sh | bash -s -- --root_pass=<root_password> --bucket=<bucket_name> --s3_key=<s3_key> --s3_secret_key=<s3_secret_key> --domain=<domain> --email=<email>
