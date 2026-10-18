#!/bin/sh
# Pokrece se pri svakom startu kontejnera "app".
set -e
cd /var/www/poksipp/api

if [ -z "$APP_KEY" ]; then
    echo "GRESKA: APP_KEY nije podesen."
    echo "U folderu api pokreni:  php artisan key:generate --show"
    echo "i upisi rezultat u .env pored docker-compose.yml (APP_KEY=base64:...)."
    exit 1
fi

# Laravelove tabele (migrations, personal_access_tokens). Tabele POKSIPP-a ne dira,
# a ako vec postoje (npr. iz tvog dump-a), ne radi nista.
php artisan migrate --force

exec apache2-foreground
