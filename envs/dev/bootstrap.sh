#!/bin/bash
set -e
apt-get update -y && apt-get install -y nginx awscli curl
export AWS_DEFAULT_REGION=us-east-1; ENV_NAME="ENV_PLACEHOLDER"
if DB_PASS=$(aws ssm get-parameter --name "/novasphere/${ENV_NAME}/db_password" --with-decryption --query Parameter.Value --output text); then SECRET="OK (lu depuis Parameter Store)"; else DB_PASS=""; SECRET="ECHEC de lecture Parameter Store"; fi
mkdir -p /etc/novasphere && install -m 0600 /dev/null /etc/novasphere/app.conf && echo "DB_PASS=${DB_PASS}" > /etc/novasphere/app.conf
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
echo "<h1>NovaSphere - ${ENV_NAME}</h1><p>Instance : ${INSTANCE_ID}</p><p>Secret : ${SECRET}</p>" > /var/www/html/index.html
systemctl restart nginx
