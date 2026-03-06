#syntax=docker/dockerfile:1

# ============================================
# BASE STAGE
# ============================================
FROM dunglas/frankenphp:php8.4-alpine AS base

WORKDIR /app

# System dependencies
RUN apk add --no-cache \
    acl \
    bash \
    icu-libs \
    libpq \
    libzip \
    libpng \
    libjpeg-turbo \
    freetype \
    postgresql-dev \
    && apk add --no-cache --virtual .build-deps \
    $PHPIZE_DEPS \
    icu-dev \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    pdo_pgsql \
    pgsql \
    intl \
    zip \
    gd \
    opcache \
    bcmath \
    && apk del .build-deps

# PHP config
COPY docker/frankenphp/conf.d/app.ini $PHP_INI_DIR/conf.d/zz-app.ini

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

ENV COMPOSER_ALLOW_SUPERUSER=1
ENV APP_RUNTIME=Runtime\FrankenPhpSymfony\Runtime

# ============================================
# DEV STAGE
# ============================================
FROM base AS dev

RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS linux-headers \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && apk del .build-deps

COPY docker/frankenphp/conf.d/app.dev.ini $PHP_INI_DIR/conf.d/zz-app-dev.ini

ENV APP_ENV=dev
ENV XDEBUG_MODE=off

COPY Caddyfile /etc/caddy/Caddyfile

ENTRYPOINT ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]

# ============================================
# PROD STAGE
# ============================================
FROM base AS prod

COPY docker/frankenphp/conf.d/app.prod.ini $PHP_INI_DIR/conf.d/zz-app-prod.ini

ENV APP_ENV=prod
ENV APP_DEBUG=0

# Copy application
COPY composer.json composer.lock symfony.lock ./
RUN composer install --no-dev --no-scripts --prefer-dist --no-progress

COPY . .

RUN composer dump-autoload --classmap-authoritative \
    && php bin/console cache:warmup --env=prod \
    && php bin/console asset-map:compile --env=prod \
    && php bin/console tailwind:build --minify --env=prod \
    && chown -R www-data:www-data var/

COPY Caddyfile.prod /etc/caddy/Caddyfile

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
