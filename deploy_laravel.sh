#!/bin/bash

PWD=$(pwd)
DIR=${PWD##*/}
artisan="docker exec -it php php /var/www/$DIR/artisan"
composer="docker run --rm -it -v $PWD:/app composer"
npm="docker run --rm -it -v $PWD:/usr/src/app -w /usr/src/app node:alpine npm"

#version=`${artisan} --version`

#if [[ ${version} != *"Laravel Framework"* ]]; then
#    echo "Not a Laravel app, exiting."
#    exit;
#fi

# Turn on maintenance mode
$artisan down || true

# Pull the latest changes from the git repository
# git reset --hard
# git clean -df
git pull

# Install/update composer dependecies
$composer install --no-interaction --prefer-dist --optimize-autoloader --no-dev

# Run database migrations
$artisan migrate --force

# Clear caches
$artisan cache:clear

# Clear expired password reset tokens
$artisan auth:clear-resets

# Clear and cache routes
$artisan route:cache

# Clear and cache config
$artisan config:cache

# Clear and cache views
$artisan view:cache

# Install node modules
$npm ci

# Build assets using Laravel Mix
$npm run build

# Turn off maintenance mode
$artisan up
