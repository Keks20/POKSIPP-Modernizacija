# Laravel (api/) na Apache-u i PHP-u 8.5 - ista verzija PHP-a kao na tvom racunaru.
# Gradi se iz korena repozitorijuma (docker compose to radi sam):
#   docker compose build app

FROM php:8.5-apache

# PHP ekstenzije koje API i sajt koriste:
#   pdo_mysql - baza, gd + exif - slike ljubimaca, intl - formatiranje, zip - composer
# (OPcache je u PHP-u 8.5 vec ugradjen)
COPY --from=mlocati/php-extension-installer:2 /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions pdo_mysql gd exif intl zip

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Apache: koren sajta je api/public, a .htaccess (Laravel rute) mora da radi
COPY docker/apache.conf /etc/apache2/sites-available/000-default.conf
RUN a2enmod rewrite
COPY docker/php.ini /usr/local/etc/php/conf.d/poksipp.ini

WORKDIR /var/www/poksipp/api

# Prvo samo composer fajlovi: dok se oni ne promene, Docker ne skida pakete ponovo
COPY api/composer.json api/composer.lock ./
RUN composer install --no-interaction --prefer-dist --no-scripts --no-autoloader

# Kod aplikacije i sema baze (testovi je citaju iz ../migracija, kao na tvom racunaru)
COPY api/ ./
COPY migracija/schema_mysql.sql ../migracija/schema_mysql.sql
# Prazan .env: podesavanja dolaze iz docker-compose.yml (promenljive okruzenja imaju prednost),
# ali bez fajla Laravel pri svakom testu prijavi upozorenje da .env ne postoji.
RUN composer dump-autoload --optimize \
    && touch .env \
    && chown -R www-data:www-data storage bootstrap/cache

COPY docker/start.sh /usr/local/bin/poksipp-start
# Ako git na Windows-u pretvori kraj reda u CRLF, skripta ne bi radila
RUN sed -i 's/\r$//' /usr/local/bin/poksipp-start && chmod +x /usr/local/bin/poksipp-start

EXPOSE 80
CMD ["poksipp-start"]
