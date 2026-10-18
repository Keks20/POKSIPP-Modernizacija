# docker/podaci

Ovde ide dump tvoje baze ako hoćeš da Docker baza krene sa pravim podacima umesto demo podataka.
Fajlovi `*.sql` iz ovog foldera **ne idu na GitHub** (imaju imena, telefone i heševe lozinki).

Dump iz XAMPP baze (MySQL u XAMPP-u mora da radi), iz korena repozitorijuma:

```
D:\xamppp\mysql\bin\mysqldump.exe -uroot --default-character-set=utf8mb4 --hex-blob --result-file=docker\podaci\poksipp.sql poksipp
```

`--result-file` umesto `>`: PowerShell sa `>` snima fajl kao UTF-16, a MariaDB takav fajl ne može da uveze.

Uvozi se samo pri prvom pokretanju Docker baze. Da bi se uvezao ponovo, obriši bazu u Docker-u:
`docker compose down -v`, pa `docker compose up -d`.
