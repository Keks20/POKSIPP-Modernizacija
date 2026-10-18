<?php

namespace Tests\Feature;

use App\Models\Ljubimac;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Http\UploadedFile;
use Tests\Support\PoksippPodaci;
use Tests\TestCase;

class WebTest extends TestCase
{
    use DatabaseTransactions, PoksippPodaci;

    public function test_prijava_istim_nalogom_kao_u_delphiju(): void
    {
        $this->musterija('vlasnik1', 'pass123');

        $this->post('/prijava', ['korisnicko_ime' => 'vlasnik1', 'lozinka' => 'pass123'])
            ->assertRedirect('/moji-ljubimci');
        $this->assertAuthenticated('vlasnik');
    }

    public function test_prijava_emailom(): void
    {
        $this->musterija('vlasnik1', 'pass123', 'jovana@primer.rs');

        $this->post('/prijava', ['korisnicko_ime' => 'jovana@primer.rs', 'lozinka' => 'pass123'])
            ->assertRedirect('/moji-ljubimci');
    }

    public function test_pogresna_lozinka(): void
    {
        $this->musterija('vlasnik1', 'pass123');

        $this->from('/prijava')
            ->post('/prijava', ['korisnicko_ime' => 'vlasnik1', 'lozinka' => 'pogresna'])
            ->assertRedirect('/prijava')
            ->assertSessionHasErrors(['korisnicko_ime' => 'Pogrešno korisničko ime ili lozinka.']);
        $this->assertGuest('vlasnik');
    }

    public function test_zaposleni_se_ne_prijavljuje_na_web_vlasnika(): void
    {
        $this->admin();

        $this->post('/prijava', ['korisnicko_ime' => 'admin', 'lozinka' => 'admin123'])
            ->assertSessionHasErrors('korisnicko_ime');
        $this->assertGuest('vlasnik');
    }

    public function test_vlasnik_vidi_samo_svoje_ljubimce(): void
    {
        $jovana = $this->musterija('jovana');
        $petar = $this->musterija('petar');
        $this->ljubimac($jovana, 'Reks', 'Boks A1');
        $maca = $this->ljubimac($petar, 'Maca', 'Boks A2');

        $this->actingAs($jovana, 'vlasnik')
            ->get('/moji-ljubimci')
            ->assertOk()
            ->assertSee('Reks')
            ->assertSee('Boks A1')
            ->assertDontSee('Maca');

        $this->actingAs($jovana, 'vlasnik')->get("/moji-ljubimci/{$maca->id}")->assertNotFound();
        $this->actingAs($jovana, 'vlasnik')->get("/moji-ljubimci/{$maca->id}/slika")->assertNotFound();
    }

    public function test_detalji_dnevnik_i_racun(): void
    {
        $vlasnik = $this->musterija();
        $reks = $this->ljubimac($vlasnik);
        $nikola = $this->zaposleni();
        $setnja = $this->usluga('Šetnja', '1500.00');
        $this->aktivnost($reks, $nikola, ['Sifra_usluge' => $setnja->Sifra_usluge, 'Komentar' => 'Bio je veoma dobar']);
        $this->aktivnost($reks, $nikola, [
            'Kategorija' => 'Hrana', 'Vrsta_aktivnosti' => 'Suva hrana', 'VremeDo' => null,
            'StatusAktivnosti' => null, 'Kolicina' => '280g', 'VremeObroka' => 'Doručak',
        ]);

        $this->actingAs($vlasnik, 'vlasnik')
            ->get("/moji-ljubimci/{$reks->id}")
            ->assertOk()
            ->assertSee('Račun za boravak')
            ->assertSee('1.500,00 RSD')
            ->assertSee('Bio je veoma dobar')
            ->assertSee('Nikola Test')
            ->assertSee('280g');

        $this->actingAs($vlasnik, 'vlasnik')
            ->get("/moji-ljubimci/{$reks->id}?kategorija=Hrana")
            ->assertOk()
            ->assertSee('280g')
            ->assertDontSee('Bio je veoma dobar');
    }

    public function test_postavljanje_slike_preko_forme(): void
    {
        $vlasnik = $this->musterija();
        $reks = $this->ljubimac($vlasnik);

        $this->actingAs($vlasnik, 'vlasnik')
            ->post("/moji-ljubimci/{$reks->id}/slika", ['slika' => UploadedFile::fake()->image('reks.png', 1600, 1200)])
            ->assertRedirect("/moji-ljubimci/{$reks->id}")
            ->assertSessionHas('poruka');

        $info = getimagesizefromstring((string) Ljubimac::whereKey($reks->id)->value('image_blob'));
        $this->assertSame([800, 600, 'image/jpeg'], [$info[0], $info[1], $info['mime']]);

        $this->actingAs($vlasnik, 'vlasnik')
            ->get("/moji-ljubimci/{$reks->id}/slika")
            ->assertOk()
            ->assertHeader('Content-Type', 'image/jpeg');
    }

    public function test_pogresan_fajl_vraca_poruku_u_formi(): void
    {
        $vlasnik = $this->musterija();
        $reks = $this->ljubimac($vlasnik);

        $this->actingAs($vlasnik, 'vlasnik')
            ->from("/moji-ljubimci/{$reks->id}")
            ->post("/moji-ljubimci/{$reks->id}/slika", ['slika' => UploadedFile::fake()->create('dokument.pdf', 10, 'application/pdf')])
            ->assertRedirect("/moji-ljubimci/{$reks->id}")
            ->assertSessionHasErrors('slika');
    }

    public function test_odjava(): void
    {
        $vlasnik = $this->musterija();

        $this->actingAs($vlasnik, 'vlasnik')->post('/odjava')->assertRedirect('/prijava');
        $this->assertGuest('vlasnik');
    }

    public function test_forme_imaju_csrf_token(): void
    {
        // Laravel odbija POST bez ovog tokena (zastita od CSRF napada);
        // u testovima je provera iskljucena, pa proveravamo da ga forme salju.
        $vlasnik = $this->musterija();
        $reks = $this->ljubimac($vlasnik);

        $this->get('/prijava')->assertSee('name="_token"', false);
        $this->actingAs($vlasnik, 'vlasnik')
            ->get("/moji-ljubimci/{$reks->id}")
            ->assertSee('name="_token"', false);
    }
}
