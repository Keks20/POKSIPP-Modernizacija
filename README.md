# POKSIPP: modernizing a legacy Delphi app

POKSIPP is a desktop app for a pet boarding house, written in Delphi 12 (FireMonkey) on a local SQLite file.
This repository takes it, step by step, to a shared MySQL database with a REST API and a web page for pet owners,
while the Delphi app keeps working.

**Read the case study: [CASE_STUDY.md](CASE_STUDY.md)**

| Before | After |
| --- | --- |
| ![Old activity form](docs/case-study/02-staro-unos-aktivnosti.png) | ![New activity form](docs/case-study/03-novo-unos-aktivnosti-meni.png) |

## What is where

| Folder | What it is |
| --- | --- |
| [`Delphi/`](Delphi) | the desktop app (Delphi 12 FMX + FireDAC), now on MySQL over TLS, Win64 |
| [`migracija/`](migracija) | Python migration from SQLite to MySQL, with a checksum check (`migrate.py`, `verify.py`) |
| [`api/`](api) | Laravel 13 REST API and the owner web page, 49 automated tests |
| [`docker/`](docker), `docker-compose.yml` | web page, API and MariaDB with demo data in one command |
| [`docs/case-study/`](docs/case-study) | screenshots used in the case study |

The guides inside the folders are written in Serbian.

## Try it

With Docker Desktop running, follow [`docker/README.md`](docker/README.md): copy one settings file, then

```
docker compose up -d --build
```

Open http://localhost:8080 and log in as `vlasnik1` / `pass123`. All data in the demo database is invented.

## Background

POKSIPP started as my part of a team project for the course *Poznavanje poslovnih procesa* (Business processes)
at ASSŠ (Akademija strukovnih studija Šumadija, Academy of applied studies Šumadija, Serbia).
The process I covered was *managing products and production*: the activities and services a pet receives in the boarding house.

The original course documents are kept as they were: `Predlog resenjaPPPoksi.pdf` (process analysis), `Faze razvoja.pdf`
(development plan), `POKSI.fig` and [`Figma.md`](Figma.md) (UI design) and `UPUTSTVO.docx` (user guide for the original SQLite version).

Tools for moving even older data (dBase/Clipper `.dbf`, Microsoft Access) into MySQL are in a separate repository:
[StariFormati](https://github.com/Keks20/StariFormati).
