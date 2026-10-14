<?php

namespace Tests\Feature;

use App\Models\Ljubimac;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\Support\PoksippPodaci;
use Tests\TestCase;

class PrijemOdjavaTest extends TestCase
{
    use DatabaseTransactions, PoksippPodaci;

    private function podaci(array $izmene = []): array
    {
        return $izmene + [
            'ime' => 'Žuća',
            'vrsta' => 'Pas',
            'rasa' => 'Labrador',
            'starost' => '2 godine',
            'alergije' => '',
            'boks' => 'A3',
            'vlasnik' => 'vlasnik1',
        ];
    }

    public function test_prijem_kao_u_delphiju(): void
    {
        Carbon::setTestNow('2026-10-15 08:30:00');
        $vlasnik = $this->musterija('vlasnik1');
        Sanctum::actingAs($this->admin());

        $odgovor = $this->postJson('/api/ljubimci', $this->podaci());

        $odgovor->assertCreated()
            ->assertJsonPath('data.ime', 'Žuća')
            ->assertJsonPath('data.boks', 'Boks A3')              // 'A3' -> 'Boks A3'
            ->assertJsonPath('data.alergije', 'Nema poznatih')    // prazno -> 'Nema poznatih'
            ->assertJsonPath('data.status', 'Aktivan')
            ->assertJsonPath('data.datum_prijema', '2026-10-15 08:30:00')
            ->assertJsonPath('data.vlasnik.id', $vlasnik->Sifra_musterije)
            ->assertJsonPath('poruka', 'Žuća je primljen u pansion (Boks A3).');

        $this->assertDatabaseHas('pets', ['name' => 'Žuća', 'Lokacija' => 'Boks A3', 'Status' => 'Aktivan']);
    }

    public function test_vlasnik_preko_emaila(): void
    {
        $this->musterija('vlasnik1', 'x', 'jovana@primer.rs');
        Sanctum::actingAs($this->admin());

        $this->postJson('/api/ljubimci', $this->podaci(['vlasnik' => 'jovana@primer.rs']))->assertCreated();
    }

    public function test_obavezna_polja(): void
    {
        Sanctum::actingAs($this->admin());

        $this->postJson('/api/ljubimci', ['rasa' => 'x'])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['ime', 'vrsta', 'boks', 'vlasnik']);
    }

    public function test_vlasnik_mora_postojati(): void
    {
        Sanctum::actingAs($this->admin());

        $this->postJson('/api/ljubimci', $this->podaci(['vlasnik' => 'nepostojeci']))
            ->assertStatus(422)
            ->assertJsonValidationErrors(['vlasnik']);
        $this->assertDatabaseMissing('pets', ['name' => 'Žuća']);
    }

    public function test_zauzet_boks(): void
    {
        $vlasnik = $this->musterija('vlasnik1');
        $this->ljubimac($vlasnik, 'Reks', 'Boks A3');
        Sanctum::actingAs($this->admin());

        // 'boks a3' = 'Boks A3' (velika/mala slova se ne razlikuju, kao u Delphiju)
        $this->postJson('/api/ljubimci', $this->podaci(['boks' => 'boks a3']))
            ->assertStatus(422)
            ->assertJsonPath('errors.boks.0', 'boks a3 je zauzet (Reks).');
    }

    public function test_boks_odjavljenog_ljubimca_je_slobodan(): void
    {
        $vlasnik = $this->musterija('vlasnik1');
        // Stari zapis iz SQLite-a: odjavljen, ali boks nije obrisan
        $this->ljubimac($vlasnik, 'Reks', 'Boks A3', ['Status' => Ljubimac::ODJAVLJEN]);
        Sanctum::actingAs($this->admin());

        $this->postJson('/api/ljubimci', $this->podaci())->assertCreated();
    }

    public function test_samo_admin_prima_i_odjavljuje(): void
    {
        $vlasnik = $this->musterija('vlasnik1');
        $reks = $this->ljubimac($vlasnik);

        Sanctum::actingAs($this->zaposleni());
        $this->postJson('/api/ljubimci', $this->podaci())->assertForbidden();
        $this->postJson("/api/ljubimci/{$reks->id}/odjava")->assertForbidden();
        $this->putJson("/api/ljubimci/{$reks->id}", $this->podaci())->assertForbidden();

        Sanctum::actingAs($vlasnik);
        $this->postJson('/api/ljubimci', $this->podaci())->assertForbidden();
    }

    public function test_izmena(): void
    {
        $vlasnik = $this->musterija('vlasnik1');
        $reks = $this->ljubimac($vlasnik, 'Reks', 'Boks A1');
        $this->ljubimac($vlasnik, 'Maca', 'Boks A2');
        Sanctum::actingAs($this->admin());

        // Isti boks koji već ima - dozvoljeno
        $this->putJson("/api/ljubimci/{$reks->id}", $this->podaci(['ime' => 'Reksi', 'boks' => 'A1']))
            ->assertOk()
            ->assertJsonPath('data.ime', 'Reksi')
            ->assertJsonPath('data.boks', 'Boks A1');

        // Boks drugog ljubimca - ne
        $this->putJson("/api/ljubimci/{$reks->id}", $this->podaci(['boks' => 'A2']))
            ->assertStatus(422)
            ->assertJsonPath('errors.boks.0', 'Boks A2 je zauzet (Maca).');

        $this->putJson('/api/ljubimci/999999', $this->podaci())->assertNotFound();
    }

    public function test_odjava_sa_racunom(): void
    {
        Carbon::setTestNow('2026-10-15 18:00:00');
        $vlasnik = $this->musterija('vlasnik1');
        $reks = $this->ljubimac($vlasnik, 'Reks', 'Boks A1');
        $setnja = $this->usluga('Šetnja', '500.00');
        $this->aktivnost($reks, $this->zaposleni(), ['Sifra_usluge' => $setnja->Sifra_usluge]);
        Sanctum::actingAs($this->admin());

        $this->postJson("/api/ljubimci/{$reks->id}/odjava")
            ->assertOk()
            ->assertJsonPath('ljubimac.status', 'Odjavljen')
            ->assertJsonPath('ljubimac.boks', null)
            ->assertJsonPath('ljubimac.datum_odjave', '2026-10-15 18:00:00')
            ->assertJsonPath('racun.ukupno', '500.00');

        $this->assertDatabaseHas('pets', ['id' => $reks->id, 'Status' => 'Odjavljen', 'Lokacija' => '']);

        // Druga odjava: 409, ali se račun i dalje vidi
        $this->postJson("/api/ljubimci/{$reks->id}/odjava")
            ->assertStatus(409)
            ->assertJsonPath('racun.ukupno', '500.00');

        // Odjavljen se ne menja
        $this->putJson("/api/ljubimci/{$reks->id}", $this->podaci())->assertStatus(409);
    }

    public function test_odjava_nije_moguca_dok_je_aktivnost_u_toku(): void
    {
        $vlasnik = $this->musterija('vlasnik1');
        $reks = $this->ljubimac($vlasnik);
        $this->aktivnost($reks, $this->zaposleni(), ['StatusAktivnosti' => 'U toku', 'VremeDo' => null]);
        Sanctum::actingAs($this->admin());

        $this->postJson("/api/ljubimci/{$reks->id}/odjava")
            ->assertStatus(409)
            ->assertJsonPath('poruka', 'Reks ima aktivnost u toku. Odjava je moguća kad se završi.');

        $this->assertDatabaseHas('pets', ['id' => $reks->id, 'Status' => 'Aktivan']);
    }
}
