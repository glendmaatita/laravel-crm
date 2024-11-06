FROM php:8.3-apache-bookworm as base

RUN apt-get update && apt-get install -y libxml2-dev libzip-dev libpng-dev zlib1g-dev libwebp-dev libpq-dev

FROM base as composer_deps
# install composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
# RUN php -r "if (hash_file('sha384', 'composer-setup.php') === '55ce33d7678c5a611085589f1f3ddf8b3c52d662cd01d4ba75c0ee0459970c2200a51f492d557530c71c15d8dba01eae') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
RUN php composer-setup.php
RUN php -r "unlink('composer-setup.php');"
RUN mv composer.phar /usr/local/bin/composer

FROM composer_deps as php_deps
# install php dependencies
RUN pecl install redis
RUN docker-php-ext-install calendar xml gettext gd zip pdo pdo_mysql mysqli opcache
RUN docker-php-ext-enable redis
RUN docker-php-ext-configure gd

# install imagick
RUN apt-get update && apt-get install -y libmagickwand-dev --no-install-recommends && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/src/php/ext/imagick; \
    curl -fsSL https://github.com/Imagick/imagick/archive/06116aa24b76edaf6b1693198f79e6c295eda8a9.tar.gz | tar xvz -C "/usr/src/php/ext/imagick" --strip 1; \
    docker-php-ext-install imagick;

FROM php_deps as deployment
COPY . .

RUN composer install

RUN a2enmod rewrite

# set vhost
COPY ./docker/vhost.conf /etc/apache2/sites-available/000-default.conf
RUN chown -R www-data:www-data /var/www/html

# set max upload
COPY ./docker/upload.ini /usr/local/etc/php/conf.d/upload.ini

ADD start.sh /start.sh
RUN chmod 777 /start.sh

ENTRYPOINT ["/start.sh"]
