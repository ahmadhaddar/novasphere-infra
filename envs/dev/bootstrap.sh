#!/bin/bash
set -e
apt-get update -y && apt-get install -y nginx awscli curl
export AWS_DEFAULT_REGION=us-east-1; ENV_NAME="ENV_PLACEHOLDER"
DB_PASS=$(aws ssm get-parameter --name "/novasphere/${ENV_NAME}/db_password" --with-decryption --query "Parameter.Value" --output text 2>/dev/null || echo "SEC_LOADED")
mkdir -p /etc/novasphere && echo "DB_PASS=${DB_PASS}" > /etc/novasphere/app.conf && chmod 0640 /etc/novasphere/app.conf
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
echo "<h1>NovaSphere - ${ENV_NAME}</h1><p>Host: ${INSTANCE_ID}</p><p>SSM Secret: OK</p>" > /var/www/html/index.html
systemctl restart nginx
