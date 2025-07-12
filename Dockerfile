# PHP-FPM image for Magento 2
FROM php:8.2-fpm

# Install required system packages and PHP extensions
RUN apt-get update \
    && apt-get install -y \
        libfreetype6-dev libjpeg62-turbo-dev libpng-dev libonig-dev libzip-dev zip unzip libxml2-dev libicu-dev libxslt1-dev libcurl4-openssl-dev pkg-config \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo_mysql mbstring zip exif pcntl bcmath opcache gd soap curl ftp intl xsl sockets \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && rm -rf /var/lib/apt/lists/*

# Install Composer globally
RUN curl -sS https://getcomposer.org/installer | php \
    && chmod +x composer.phar \
    && mv composer.phar /usr/local/bin/composer

# Create Composer config directory for www-data
RUN mkdir -p /var/www/.composer \
    && chown -R www-data:www-data /var/www/.composer

# Set working directory and user
WORKDIR /var/www/html
USER www-data
