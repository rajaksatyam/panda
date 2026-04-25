#!/bin/bash

# Configuration
SERVER_IP="SERVER IP ADDRESS"
KEY_FILE="KEY PROVIDED EC2"
APP_DIR="/home/ubuntu/app"
APP_NAME="panda-api"
echo "🚀 Starting deployment to $SERVER_IP..."

# 1. Build locally
echo "📦 Building project..."
npm run build

# 2. Package files
echo "📦 Packaging files..."
zip -r deploy.zip dist scripts package.json package-lock.json

# 3. Create app directory and transfer files
echo "🚚 Transferring files to server..."
ssh -i $KEY_FILE -o StrictHostKeyChecking=no ubuntu@$SERVER_IP "mkdir -p $APP_DIR"
scp -i $KEY_FILE deploy.zip ubuntu@$SERVER_IP:$APP_DIR/

# 4. Extract and Install on server
echo "🛠️ Extracting and installing dependencies on server..."
ssh -i $KEY_FILE ubuntu@$SERVER_IP << 'EOF'
  # Wait for user-data or other apt processes to finish
  while fuser /var/lib/dpkg/lock >/dev/null 2>&1 ; do
      echo "Waiting for other software managers to finish..."
      sleep 5
  done
  sudo apt-get update && sudo apt-get install -y unzip

  cd /home/ubuntu/app
  unzip -o deploy.zip
  npm install --production
  # Fetch secrets
  npm run secrets
  
  # Setup Nginx
  sudo tee /etc/nginx/sites-available/default << 'NGINX_CONF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
NGINX_CONF
  sudo systemctl restart nginx

  # Setup PM2 to stay alive
  pm2 list | grep $APP_NAME && pm2 restart $APP_NAME || pm2 start dist/index.js --name $APP_NAME
  pm2 save
EOF

echo "✅ Deployment complete!"
rm deploy.zip
