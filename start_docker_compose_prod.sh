#!/bin/bash
set -e  # Exit on error

# Check if AWS_ACCOUNT_ID is set
if [ -z "$AWS_ACCOUNT_ID" ]; then
  echo "ERROR: AWS_ACCOUNT_ID environment variable is not set"
  exit 1
fi

# Define ECR repository URL
ECR_URL="${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"
BRAINROT_IMAGE="$ECR_URL/brainrot:latest"
RVC_IMAGE="$ECR_URL/rvc:latest"

echo "ECR URL: $ECR_URL"
echo "Brainrot Image: $BRAINROT_IMAGE"
echo "RVC Image: $RVC_IMAGE"

# Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "$ECR_URL"

# Stop and remove any existing containers
echo "Stopping any existing containers..."
docker-compose down || true

# Clean up old images
echo "Cleaning up old images..."
docker system prune -a -f --volumes

# Pull latest images
echo "Pulling latest images..."
docker pull "$BRAINROT_IMAGE"
docker pull "$RVC_IMAGE"

# Create necessary directories
echo "Creating shared directories..."
mkdir -p shared_data

# Set permissions
chmod -R 777 shared_data

# Create docker-compose.yml file
echo "Creating docker-compose.yml file..."
cat > docker-compose.yml << EOL
version: '3.8'

services:
  brainrot:
    image: ${BRAINROT_IMAGE}
    container_name: brainrot-container
    ports:
      - "3000:3000"
    volumes:
      - ./shared_data:/app/brainrot/shared_data
    environment:
      - MODE=production
      - RVC_SERVICE_URL=http://rvc:5555
    depends_on:
      - rvc

  rvc:
    image: ${RVC_IMAGE}
    container_name: rvc-container
    ports:
      - "5555:5555"
    volumes:
      - ./shared_data:/app/shared_data
    environment:
      - MODE=production
      - SHARED_DIR=/app/shared_data
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
EOL

# Start containers with docker-compose
echo "Starting containers with docker-compose..."
docker-compose up -d

echo "Deployment complete!" 