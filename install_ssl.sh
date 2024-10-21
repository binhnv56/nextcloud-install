#!/bin/bash

# Default values for variables
ROOT_PASS=""
BUCKET=""
S3_KEY=""
S3_SECRET_KEY=""

# Function to display usage
usage() {
    echo "Usage: $0 --root_pass=<root_password> --bucket=<bucket_name> --s3_key=<s3_key> --s3_secret_key=<s3_secret_key> --domain=<domain> --email=<email register domain>"
    exit 1
}

# Parse command line arguments
while [ "$1" != "" ]; do
    case $1 in
        --root_pass=*)
            ROOT_PASS="${1#*=}"
            ;;
        --bucket=*)
            BUCKET="${1#*=}"
            ;;
        --s3_key=*)
            S3_KEY="${1#*=}"
            ;;
        --s3_secret_key=*)
            S3_SECRET_KEY="${1#*=}"
            ;;
        --domain=*)
            DOMAIN="${1#*=}"
            ;;
        --email=*)
            EMAIL="${1#*=}"
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
    shift
done

# Check if all required arguments are provided
if [ -z "$ROOT_PASS" ] || [ -z "$BUCKET" ] || [ -z "$S3_KEY" ] || [ -z "$S3_SECRET_KEY" ] || [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo "Error: Missing required arguments"
    usage
fi

mkdir proxy
cat <<EOF > ./proxy/Dockerfile
FROM nginxproxy/nginx-proxy:alpine

COPY uploadsize.conf /etc/nginx/conf.d/uploadsize.conf
EOF

cat <<EOF > ./proxy/uploadsize.conf
client_max_body_size 10G;
proxy_request_buffering off;
EOF

cat <<EOF > docker-compose.yml
version: '2'

volumes:
  nextcloud:
  db:

services:
  db:
    image: mariadb:10.6
    restart: always
    command: --transaction-isolation=READ-COMMITTED --log-bin=binlog --binlog-format=ROW
    volumes:
      - db:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=${ROOT_PASS}
      - MYSQL_PASSWORD=${ROOT_PASS}
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud

  app:
    image: nextcloud:30
    restart: always
    depends_on:
      - db
      - proxy
    volumes:
      - nextcloud:/var/www/html
    environment:
      # DB Config
      - MYSQL_PASSWORD=${ROOT_PASS}
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
      - MYSQL_HOST=db
      # Nextcloud config
      - NEXTCLOUD_ADMIN_USER=admin
      - NEXTCLOUD_ADMIN_PASSWORD=${ROOT_PASS}
      - NEXTCLOUD_TRUSTED_DOMAINS="*"
      # Object config
      - OBJECTSTORE_S3_BUCKET=${BUCKET}
      - OBJECTSTORE_S3_REGION=vn-central-1
      - OBJECTSTORE_S3_HOST=os.viettelcloud.vn
      - OBJECTSTORE_S3_KEY=${S3_KEY}
      - OBJECTSTORE_S3_SECRET=${S3_SECRET_KEY}
      - OBJECTSTORE_S3_AUTOCREATE=true
      - OBJECTSTORE_S3_USEPATH_STYLE=true
      - OBJECTSTORE_S3_SSL=true
      - OBJECTSTORE_S3_LEGACYAUTH=false
      # SSL Config
      - VIRTUAL_HOST=${DOMAIN}
      - LETSENCRYPT_HOST=${DOMAIN}
      - LETSENCRYPT_EMAIL=${EMAIL}
    networks:
      - proxy-tier
      - default

  proxy:
    build: ./proxy
    restart: always
    ports:
      - 80:80
      - 443:443
    labels:
      - "com.github.jrcs.letsencrypt_nginx_proxy_companion.nginx_proxy"
    volumes:
      - certs:/etc/nginx/certs:ro,z
      - vhost.d:/etc/nginx/vhost.d:z
      - html:/usr/share/nginx/html:z
      - dhparam:/etc/nginx/dhparam:z
      - /var/run/docker.sock:/tmp/docker.sock:z,ro
    networks:
      - proxy-tier

  letsencrypt-companion:
    image: nginxproxy/acme-companion
    restart: always
    environment:
      - DEFAULT_EMAIL=
    volumes:
      - certs:/etc/nginx/certs:z
      - acme:/etc/acme.sh:z
      - vhost.d:/etc/nginx/vhost.d:z
      - html:/usr/share/nginx/html:z
      - /var/run/docker.sock:/var/run/docker.sock:z,ro
    networks:
      - proxy-tier
    depends_on:
      - proxy

volumes:
  db:
  nextcloud:
  certs:
  acme:
  vhost.d:
  html:
  dhparam:

networks:
  proxy-tier:
EOF

docker-compose up -d