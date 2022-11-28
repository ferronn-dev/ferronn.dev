set -e
IMAGE=gcr.io/www-ferronn-dev/nginx
docker build --platform linux/amd64 -t $IMAGE .
docker push $IMAGE
gcloud --project=www-ferronn-dev run deploy nginx \
    --platform=managed \
    --region=us-central1 \
    --image=$IMAGE
