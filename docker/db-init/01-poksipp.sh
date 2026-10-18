#!/bin/bash
# Radi samo pri PRVOM pokretanju baze (kad je volume db-podaci prazan).
# Posle toga baza zivi u volume-u i ova skripta se vise ne pokrece.
#
#   1. test baza poksipp_test (za "php artisan test" u kontejneru)
#   2. sema POKSIPP-a (ista kao za XAMPP: migracija/schema_mysql.sql)
#   3. podaci: tvoj dump iz docker/podaci/*.sql ako postoji, inace demo podaci
set -e

poksipp_sql() {
    mariadb --protocol=socket -uroot -p"${MARIADB_ROOT_PASSWORD}" --default-character-set=utf8mb4 "$@"
}

echo "POKSIPP: test baza i prava za korisnika poksipp"
poksipp_sql <<'SQL'
CREATE DATABASE IF NOT EXISTS poksipp_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON poksipp_test.* TO 'poksipp'@'%';
FLUSH PRIVILEGES;
SQL

echo "POKSIPP: sema"
poksipp_sql poksipp < /poksipp/schema_mysql.sql

shopt -s nullglob
dumpovi=(/podaci/*.sql)
if [ ${#dumpovi[@]} -gt 0 ]; then
    for f in "${dumpovi[@]}"; do
        echo "POKSIPP: uvozim $f"
        poksipp_sql poksipp < "$f"
    done
else
    echo "POKSIPP: nema dump-a u docker/podaci, ubacujem demo podatke"
    poksipp_sql poksipp < /poksipp/demo.sql
fi
shopt -u nullglob
