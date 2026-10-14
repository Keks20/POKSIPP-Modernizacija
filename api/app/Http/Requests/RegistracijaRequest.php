<?php

namespace App\Http\Requests;

use Closure;
use Illuminate\Support\Facades\DB;

/**
 * Registracija vlasnika: ista pravila kao fraRegister.pas.
 *  - sva polja su obavezna;
 *  - korisničko ime mora biti slobodno i kod vlasnika I kod zaposlenih;
 *  - email mora biti jedinstven.
 * Dodato u odnosu na Delphi: format emaila i dužine polja (MySQL kolone imaju ograničenja).
 */
class RegistracijaRequest extends ApiRequest
{
    public function rules(): array
    {
        return [
            'korisnicko_ime' => ['required', 'string', 'max:50', $this->slobodnoKorisnickoIme(...)],
            'email' => ['required', 'string', 'email', 'max:100', $this->slobodanEmail(...)],
            'telefon' => ['required', 'string', 'max:20'],
            'lozinka' => ['required', 'string', 'max:255'],
            'ime' => ['required', 'string', 'max:50'],
            'prezime' => ['required', 'string', 'max:50'],
        ];
    }

    public function attributes(): array
    {
        return [
            'korisnicko_ime' => 'korisničko ime',
            'email' => 'email',
            'telefon' => 'telefon',
            'lozinka' => 'lozinka',
            'ime' => 'ime',
            'prezime' => 'prezime',
        ];
    }

    private function slobodnoKorisnickoIme(string $polje, mixed $vrednost, Closure $greska): void
    {
        // Kolacija baze (utf8mb4_unicode_ci) ne razlikuje velika i mala slova: admin = Admin
        $zauzeto = DB::table('MUSTERIJA')->where('KorisnickoIme', $vrednost)->exists()
            || DB::table('ZAPOSLENI')->where('KorisnickoIme', $vrednost)->exists();

        if ($zauzeto) {
            $greska('Korisničko ime je već zauzeto.');
        }
    }

    private function slobodanEmail(string $polje, mixed $vrednost, Closure $greska): void
    {
        if (DB::table('MUSTERIJA')->where('Email', $vrednost)->exists()) {
            $greska('Nalog sa ovim emailom već postoji.');
        }
    }
}
