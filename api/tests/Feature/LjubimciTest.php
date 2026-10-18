<?php

namespace Tests\Feature;

use App\Models\Ljubimac;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Laravel\Sanctum\Sanctum;
use Tests\Support\PoksippPodaci;
use Tests\TestCase;

class LjubimciTest extends TestCase
{
    use DatabaseTransactions, PoksippPodaci;

    public function test_vlasnik_vidi_samo_svoje_ljubimce(): void
    {
        $jovana = $this->musterija('jovana');
        $petar = $this->musterija('petar');
        $this->ljubimac($jovana, 'Reks', 'Boks A1');
        $this->ljubimac($petar, 'Maca', 'Boks A2');

        Sanctum::actingAs($jovana);

        $this->getJson('/api/ljubimci')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.ime', 'Reks');
    }

    public function test_tudji_ljubimac_je_404_za_vlasnika(): void
    {
        $jovana = $this->musterija('jovana');
        $petar = $this->musterija('petar');
        $maca = $this->ljubimac($petar, 'Maca', 'Boks A2');

        Sanctum::actingAs($jovana);

        $this->getJson("/api/ljubimci/{$maca->id}")->assertNotFound();
        $this->getJson("/api/ljubimci/{$maca->id}/dnevnik")->assertNotFound();
        $this->getJson("/api/ljubimci/{$maca->id}/racun")->assertNotFound();
    }

    public function test_osoblje_vidi_sve_sa_vlasnikom_i_filter_statusa(): void
    {
        $jovana = $this->musterija('jovana');
        $this->ljubimac($jovana, 'Reks', 'Boks A1');
        $this->ljubimac($jovana, 'Bobi', '', ['Status' => Ljubimac::ODJAVLJEN]);

        Sanctum::actingAs($this->zaposleni());

        $this->getJson('/api/ljubimci')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.ime', 'Bobi')            // po imenu, kao Delphi
            ->assertJsonPath('data.0.boks', null)              // odjavljen = prazan boks
            ->assertJsonPath('data.1.vlasnik.korisnicko_ime', 'jovana')
            ->assertJsonMissingPath('data.0.image_blob');

        $this->getJson('/api/ljubimci?status=Aktivan')->assertJsonCount(1, 'data');
        $this->getJson('/api/ljubimci?status=Nesto')->assertStatus(422);
    }

    public function test_dnevnik_po_kategoriji_najnovije_prvo(): void
    {
        $jovana = $this->musterija('jovana');
        $reks = $this->ljubimac($jovana);
        $nikola = $this->zaposleni();
        $this->aktivnost($reks, $nikola, ['VremeOd' => '2026-10-02 10:00:00', 'Ocena' => 5]);
        $this->aktivnost($reks, $nikola, ['VremeOd' => '2026-10-03 10:00:00', 'Vrsta_aktivnosti' => 'Igra']);
        $this->aktivnost($reks, $nikola, [
            'Kategorija' => 'Hrana', 'Vrsta_aktivnosti' => 'Suva hrana', 'VremeOd' => '2026-10-02 08:00:00',
            'VremeDo' => null, 'StatusAktivnosti' => null, 'Kolicina' => '280g', 'VremeObroka' => 'Doručak',
        ]);

        Sanctum::actingAs($jovana);

        $this->getJson("/api/ljubimci/{$reks->id}/dnevnik?kategorija=Aktivnosti")
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.vrsta', 'Igra')
            ->assertJsonPath('data.1.ocena', 5)
            ->assertJsonPath('data.1.zaposleni', 'Nikola Test')
            ->assertJsonMissingPath('data.0.kolicina');

        $this->getJson("/api/ljubimci/{$reks->id}/dnevnik?kategorija=Hrana")
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.kolicina', '280g')
            ->assertJsonPath('data.0.obrok', 'Doručak');

        $this->getJson("/api/ljubimci/{$reks->id}/dnevnik")->assertJsonCount(3, 'data');
        $this->getJson("/api/ljubimci/{$reks->id}/dnevnik?kategorija=Setnja")->assertStatus(422);
    }

    public function test_racun_kao_u_delphiju(): void
    {
        $jovana = $this->musterija('jovana');
        $reks = $this->ljubimac($jovana); // primljen 2026-10-01 09:00
        $nikola = $this->zaposleni();
        $setnja = $this->usluga('Šetnja', '500.00');
        $kupanje = $this->usluga('Kupanje', '800.50');

        $this->aktivnost($reks, $nikola, ['Sifra_usluge' => $setnja->Sifra_usluge, 'VremeOd' => '2026-10-02 10:00:00']);
        $this->aktivnost($reks, $nikola, ['Sifra_usluge' => $setnja->Sifra_usluge, 'VremeOd' => '2026-10-03 10:00:00']);
        $this->aktivnost($reks, $nikola, ['Sifra_usluge' => $kupanje->Sifra_usluge, 'VremeOd' => '2026-10-03 12:00:00']);
        // Bez usluge (Druga aktivnost) - vidi se na računu, ali se ne naplaćuje
        $this->aktivnost($reks, $nikola, ['Vrsta_aktivnosti' => 'Trening poslušnosti', 'VremeOd' => '2026-10-03 15:00:00']);
        // Hrana bez usluge nije stavka računa
        $this->aktivnost($reks, $nikola, ['Kategorija' => 'Hrana', 'Vrsta_aktivnosti' => 'Suva hrana (g)', 'VremeOd' => '2026-10-03 08:00:00']);
        // Pre prijema (raniji boravak) - ne ulazi u ovaj račun
        $this->aktivnost($reks, $nikola, ['Sifra_usluge' => $setnja->Sifra_usluge, 'VremeOd' => '2026-09-20 10:00:00']);

        Sanctum::actingAs($jovana);

        $this->getJson("/api/ljubimci/{$reks->id}/racun")
            ->assertOk()
            ->assertJsonPath('ukupno', '1800.50')
            ->assertJsonPath('stavke.0.usluga', 'Kupanje')
            ->assertJsonPath('stavke.0.iznos', '800.50')
            ->assertJsonPath('stavke.1.usluga', 'Šetnja')
            ->assertJsonPath('stavke.1.broj', 2)
            ->assertJsonPath('stavke.1.iznos', '1000.00')
            ->assertJsonPath('stavke.1.naplacuje_se', true)
            ->assertJsonPath('stavke.2.usluga', 'Trening poslušnosti')
            ->assertJsonPath('stavke.2.broj', 1)
            ->assertJsonPath('stavke.2.iznos', '0.00')
            ->assertJsonPath('stavke.2.naplacuje_se', false)
            ->assertJsonCount(3, 'stavke')
            ->assertJsonPath('valuta', 'RSD');
    }

    public function test_sifarnici_po_ulogama(): void
    {
        $this->usluga('Šetnja', '500.00');
        $vlasnik = $this->musterija();
        $nikola = $this->zaposleni();
        $admin = $this->admin();

        Sanctum::actingAs($vlasnik);
        $this->getJson('/api/usluge')->assertOk()->assertJsonPath('data.0.cena', '500.00');
        $this->getJson('/api/resursi')->assertForbidden();
        $this->getJson('/api/zaposleni')->assertForbidden();

        Sanctum::actingAs($nikola);
        $this->getJson('/api/resursi')->assertOk();
        $this->getJson('/api/musterije')->assertOk()->assertJsonPath('data.0.korisnicko_ime', 'vlasnik1');
        $this->getJson('/api/zaposleni')->assertForbidden();

        Sanctum::actingAs($admin);
        $this->getJson('/api/zaposleni')
            ->assertOk()
            ->assertJsonCount(1, 'data')                       // bez admina, kao u Delphiju
            ->assertJsonPath('data.0.korisnicko_ime', 'nikola');
    }
}
