<?php

namespace Tests\Feature;

use App\Models\Musterija;
use App\Support\Lozinka;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Carbon;
use Tests\Support\PoksippPodaci;
use Tests\TestCase;

class PrijavaTest extends TestCase
{
    use DatabaseTransactions, PoksippPodaci;

    public function test_hes_je_isti_kao_u_delphiju_i_migraciji(): void
    {
        // SHA-256 od 'admin123', isto kao THashSHA2.GetHashString i hashlib.sha256
        $this->assertSame(
            '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9',
            Lozinka::hes('admin123')
        );
    }

    public function test_admin_dobija_token_i_ulogu_admin(): void
    {
        $this->admin();

        $odgovor = $this->postJson('/api/prijava', ['korisnicko_ime' => 'admin', 'lozinka' => 'admin123']);

        $odgovor->assertOk()
            ->assertJsonPath('uloga', 'admin')
            ->assertJsonPath('tip', 'Bearer')
            ->assertJsonPath('korisnik.korisnicko_ime', 'admin')
            ->assertJsonMissingPath('korisnik.Lozinka');
        $this->assertNotEmpty($odgovor->json('token'));
    }

    public function test_korisnicko_ime_ne_razlikuje_velika_i_mala_slova(): void
    {
        $this->zaposleni('Negovatelj', 'osoblje3', 'nikola123');

        $this->postJson('/api/prijava', ['korisnicko_ime' => 'OSOBLJE3', 'lozinka' => 'nikola123'])
            ->assertOk()
            ->assertJsonPath('uloga', 'zaposleni');
    }

    public function test_vlasnik_moze_emailom(): void
    {
        $this->musterija('vlasnik1', 'vlasnik123', 'jovana@primer.rs');

        $this->postJson('/api/prijava', ['korisnicko_ime' => 'jovana@primer.rs', 'lozinka' => 'vlasnik123'])
            ->assertOk()
            ->assertJsonPath('uloga', 'musterija');
    }

    public function test_pogresna_lozinka(): void
    {
        $this->admin();

        $this->postJson('/api/prijava', ['korisnicko_ime' => 'admin', 'lozinka' => 'pogresna'])
            ->assertStatus(401)
            ->assertJsonPath('poruka', 'Pogrešno korisničko ime ili lozinka.');
    }

    public function test_prazna_polja(): void
    {
        $this->postJson('/api/prijava', [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['korisnicko_ime', 'lozinka']);
    }

    public function test_deaktiviran_zaposleni_ne_moze_da_se_prijavi(): void
    {
        $z = $this->zaposleni('Negovatelj', 'jelena', 'jelena123');
        // Ovako Delphi (fraAdmin) gasi zaposlenog koji ima unose
        $z->update(['Uloga' => 'Neaktivan', 'Lozinka' => null, 'Dostupan' => false]);

        $this->postJson('/api/prijava', ['korisnicko_ime' => 'jelena', 'lozinka' => 'jelena123'])
            ->assertStatus(401);
    }

    public function test_token_deaktiviranog_zaposlenog_prestaje_da_vazi(): void
    {
        $z = $this->zaposleni('Negovatelj', 'jelena', 'jelena123');
        $token = $this->postJson('/api/prijava', ['korisnicko_ime' => 'jelena', 'lozinka' => 'jelena123'])
            ->json('token');

        // Admin ga deaktivira u Delphiju, a token je već izdat
        $z->update(['Uloga' => 'Neaktivan', 'Lozinka' => null]);

        $this->withToken($token)->getJson('/api/ja')->assertStatus(401);
    }

    public function test_ja_i_odjava(): void
    {
        $this->musterija();
        $token = $this->postJson('/api/prijava', ['korisnicko_ime' => 'vlasnik1', 'lozinka' => 'vlasnik123'])
            ->json('token');

        $this->withToken($token)->getJson('/api/ja')
            ->assertOk()
            ->assertJsonPath('uloga', 'musterija')
            ->assertJsonPath('korisnik.korisnicko_ime', 'vlasnik1');

        $this->withToken($token)->postJson('/api/odjava')->assertOk();

        // Posle odjave token više ne važi
        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/ja')->assertStatus(401);
    }

    public function test_bez_tokena_401(): void
    {
        $this->getJson('/api/ljubimci')
            ->assertStatus(401)
            ->assertJsonPath('poruka', 'Niste prijavljeni.');

        // I bez zaglavlja Accept: application/json (npr. iz browsera)
        $this->get('/api/ljubimci')
            ->assertStatus(401)
            ->assertJsonPath('poruka', 'Niste prijavljeni.');
    }

    public function test_token_ima_rok_vazenja(): void
    {
        $this->admin();
        Carbon::setTestNow('2026-10-15 08:00:00');

        $this->postJson('/api/prijava', ['korisnicko_ime' => 'admin', 'lozinka' => 'admin123'])
            ->assertJsonPath('istice', '2026-10-15 20:00:00');   // 12 sati

        Carbon::setTestNow();
    }

    public function test_registracija(): void
    {
        $odgovor = $this->postJson('/api/registracija', [
            'korisnicko_ime' => 'marko',
            'email' => 'marko@primer.rs',
            'telefon' => '0601112233',
            'lozinka' => 'marko123',
            'ime' => 'Marko',
            'prezime' => 'Marković',
        ]);

        $odgovor->assertCreated()->assertJsonPath('data.nalog', 'Standard');
        $m = Musterija::where('KorisnickoIme', 'marko')->firstOrFail();
        $this->assertSame(Lozinka::hes('marko123'), $m->Lozinka);

        $this->postJson('/api/prijava', ['korisnicko_ime' => 'marko', 'lozinka' => 'marko123'])
            ->assertOk()
            ->assertJsonPath('uloga', 'musterija');
    }

    public function test_registracija_ne_sme_da_uzme_ime_zaposlenog(): void
    {
        $this->admin();

        $this->postJson('/api/registracija', [
            'korisnicko_ime' => 'Admin',
            'email' => 'novi@primer.rs',
            'telefon' => '060',
            'lozinka' => 'x',
            'ime' => 'A',
            'prezime' => 'B',
        ])->assertStatus(422)
            ->assertJsonPath('errors.korisnicko_ime.0', 'Korisničko ime je već zauzeto.');
    }

    public function test_registracija_email_mora_biti_jedinstven(): void
    {
        $this->musterija('vlasnik1', 'vlasnik123', 'isti@primer.rs');

        $this->postJson('/api/registracija', [
            'korisnicko_ime' => 'drugi',
            'email' => 'ISTI@primer.rs',
            'telefon' => '060',
            'lozinka' => 'x',
            'ime' => 'A',
            'prezime' => 'B',
        ])->assertStatus(422)
            ->assertJsonPath('errors.email.0', 'Nalog sa ovim emailom već postoji.');
    }

    public function test_registracija_obavezna_polja(): void
    {
        $this->postJson('/api/registracija', [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['korisnicko_ime', 'email', 'telefon', 'lozinka', 'ime', 'prezime'])
            ->assertJsonPath('errors.ime.0', 'Polje "ime" je obavezno.');
    }
}
