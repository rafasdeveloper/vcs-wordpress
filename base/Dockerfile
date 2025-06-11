# Base Image UBUNTU 24.04
FROM ubuntu:24.04

LABEL mantainer="Rafael <rafael@booug.com>"

# Working directory as root
USER root
WORKDIR "/root"

# No prompts please
ENV DEBIAN_FRONTEND=noninteractive

# Fixes some weird terminal issues such as broken clear / CTRL+L
ENV TERM=linux

# Set PHP Version
ENV PHP_VERSION=8.4

# Perform php Installations
COPY ./docker-dependencies.sh /root/docker-dependencies.sh
RUN chmod +x "/root/docker-dependencies.sh"
RUN /root/docker-dependencies.sh
RUN rm -rf /root/docker-dependencies.sh

## Wordpress Conf
COPY ./wordpress/wp-config-docker.php /tmp/wp-config-docker.php

# Perform wp Installations
COPY ./docker-wordpress.sh /root/docker-wordpress.sh
RUN chmod +x "/root/docker-wordpress.sh"
RUN /root/docker-wordpress.sh
RUN rm -rf /root/docker-wordpress.sh

# Copying neccessary files

## NGINX Conf
COPY ./nginx/app.conf /etc/nginx/conf.d/app.conf

## PHP Conf
COPY ./php/php-fpm.conf /etc/php/8.4/fpm/php-fpm.conf

## Supervisor
COPY ./supervisord/supervisord.conf /etc/supervisord.conf

## Docker scripts
COPY docker-git-sync.sh /usr/local/bin/docker-git-sync.sh
RUN chmod +x "/usr/local/bin/docker-git-sync.sh"

COPY docker-git-clone.sh /usr/local/bin/docker-git-clone.sh
RUN chmod +x "/usr/local/bin/docker-git-clone.sh"

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x "/usr/local/bin/docker-entrypoint.sh"

WORKDIR "/var/www/html"

ENTRYPOINT docker-entrypoint.sh