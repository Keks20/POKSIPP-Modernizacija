<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use PDO;
use RuntimeException;

/**
 * Testovi rade nad MySQL bazom 'poksipp_test' (phpunit.xml), NIKAD nad 'poksipp'.
 *
 * Pri prvom testu baza se pravi od iste šeme koju koristi migracija
 * (../migracija/schema_mysql.sql) - tako testovi proveravaju pravu šemu,
 * a ne neku posebnu verziju za testove. Posle toga svaki test radi u
 * transakciji koja se na kraju poništava (DatabaseTransactions).
 */
abstract class TestCase extends BaseTestCase
{
    private static bool $semaSpremna = false;

    protected function setUpTraits()
    {
        // Šema se pravi PRE nego što DatabaseTransactions otvori transakciju,
        // jer CREATE/DROP TABLE u MySQL-u sami potvrđuju (commit) transakciju.
        if (! self::$semaSpremna) {
            $this->pripremiTestBazu();
            self::$semaSpremna = true;
        }

        return parent::setUpTraits();
    }

    private function pripremiTestBazu(): void
    {
        $konekcija = config('database.default');
        $cfg = config("database.connections.$konekcija");

        if (($cfg['driver'] ?? '') !== 'mysql' && ($cfg['driver'] ?? '') !== 'mariadb') {
            throw new RuntimeException('Testovi traže MySQL/MariaDB (vidi phpunit.xml).');
        }
        if (! str_ends_with($cfg['database'], '_test')) {
            throw new RuntimeException(
                "Testovi brišu tabele, pa baza mora da se zove *_test (sada: {$cfg['database']})."
            );
        }

        $pdo = new PDO(
            "mysql:host={$cfg['host']};port={$cfg['port']}",
            $cfg['username'],
            $cfg['password'] ?? '',
        );
        $pdo->exec("CREATE DATABASE IF NOT EXISTS `{$cfg['database']}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
        DB::purge($konekcija);

        $sema = base_path('../migracija/schema_mysql.sql');
        if (! is_file($sema)) {
            throw new RuntimeException("Nema šeme: $sema");
        }

        // 1. Laravelove tabele (personal_access_tokens) iz database/migrations.
        //    migrate:fresh prvo briše SVE tabele u test bazi.
        Artisan::call('migrate:fresh', ['--force' => true]);

        // 2. Tabele POKSIPP-a iz šeme migracije
        foreach (self::naredbe(file_get_contents($sema)) as $naredba) {
            DB::unprepared($naredba);
        }
    }

    /** Ista podela kao izvrsi_semu() u migrate.py: komentari van, deli se po ';' na kraju reda. */
    private static function naredbe(string $sql): array
    {
        $sql = str_replace("\r\n", "\n", $sql);
        $linije = array_filter(explode("\n", $sql), fn ($l) => ! str_starts_with(trim($l), '--'));

        return array_values(array_filter(array_map(
            fn ($n) => rtrim(trim($n), ';'),
            explode(";\n", implode("\n", $linije))
        )));
    }
}
