<?php

namespace App\Support;

/**
 * Lozinke u POKSIPP bazi su SHA-256 heš (64 heks znaka, mala slova).
 *
 * Isto kao HesLozinke() u Delphiju (THashSHA2.GetHashString) i kao
 * migracija/zajednicko.py. Sve tri strane moraju da daju isti heš,
 * inače se korisnik napravljen u jednoj aplikaciji ne bi mogao
 * prijaviti u drugoj.
 *
 * Delphi pre heširanja skida razmake sa početka i kraja (Trim),
 * pa to radimo i ovde.
 */
class Lozinka
{
    public static function hes(string $lozinka): string
    {
        return hash('sha256', trim($lozinka));
    }

    public static function proveri(string $unos, ?string $sacuvanHes): bool
    {
        // NULL lozinka = deaktiviran nalog (Delphi tako gasi zaposlenog)
        if ($sacuvanHes === null || $sacuvanHes === '') {
            return false;
        }

        return hash_equals(strtolower($sacuvanHes), self::hes($unos));
    }
}
