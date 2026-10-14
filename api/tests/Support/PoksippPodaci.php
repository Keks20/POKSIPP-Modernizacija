<?php

namespace Tests\Support;

use App\Models\DnevnaAktivnost;
use App\Models\Ljubimac;
use App\Models\Musterija;
use App\Models\Usluga;
use App\Models\Zaposleni;
use App\Support\Lozinka;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/** Pravljenje test podataka direktno u tabelama POKSIPP-a. */
trait PoksippPodaci
{
    protected function zaposleni(string $uloga = 'Negovatelj', string $korIme = 'nikola', string $lozinka = 'nikola123'): Zaposleni
    {
        return Zaposleni::create([
            'Ime' => ucfirst($korIme),
            'Prezime' => 'Test',
            'Uloga' => $uloga,
            'KorisnickoIme' => $korIme,
            'Lozinka' => Lozinka::hes($lozinka),
            'Dostupan' => true,
        ]);
    }

    protected function admin(): Zaposleni
    {
        return $this->zaposleni('Admin', 'admin', 'admin123');
    }

    protected function musterija(string $korIme = 'vlasnik1', string $lozinka = 'vlasnik123', ?string $email = null): Musterija
    {
        return Musterija::create([
            'Ime' => 'Jovana',
            'Prezime' => 'Jovanović',
            'Nalog' => 'Standard',
            'Telefon_Hitno' => '0641234567',
            'KorisnickoIme' => $korIme,
            'Lozinka' => Lozinka::hes($lozinka),
            'Email' => $email ?? $korIme.'@primer.rs',
        ]);
    }

    protected function ljubimac(Musterija $vlasnik, string $ime = 'Reks', string $boks = 'Boks A1', array $dodatno = []): Ljubimac
    {
        return Ljubimac::create($dodatno + [
            'name' => $ime,
            'species' => 'Pas',
            'breed' => 'Mešanac',
            'age' => '3 godine',
            'Status' => Ljubimac::AKTIVAN,
            'Sifra_musterije' => $vlasnik->Sifra_musterije,
            'Lokacija' => $boks,
            'Alergije' => 'Nema poznatih',
            'DatumPrijema' => Carbon::parse('2026-10-01 09:00:00'),
        ]);
    }

    protected function usluga(string $naziv, string $cena): Usluga
    {
        return Usluga::create(['Naziv' => $naziv, 'Cena' => $cena]);
    }

    protected function aktivnost(Ljubimac $ljubimac, Zaposleni $zaposleni, array $polja = []): DnevnaAktivnost
    {
        $id = DB::table('DNEVNA_AKTIVNOST')->insertGetId($polja + [
            'Kategorija' => 'Aktivnosti',
            'Vrsta_aktivnosti' => 'Šetnja',
            'VremeOd' => '2026-10-02 10:00:00',
            'VremeDo' => '2026-10-02 10:30:00',
            'StatusAktivnosti' => 'Završeno',
            'Sifra_zaposlenog' => $zaposleni->Sifra_zaposlenog,
            'Sifra_ljubimca' => $ljubimac->id,
        ]);

        return DnevnaAktivnost::findOrFail($id);
    }
}
