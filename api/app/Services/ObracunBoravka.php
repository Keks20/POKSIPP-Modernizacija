<?php

namespace App\Services;

use App\Models\Ljubimac;
use Illuminate\Support\Facades\DB;

/**
 * Račun za boravak ljubimca: isto pravilo kao ObracunBoravka() u Delphiju (uUserStore.pas).
 *
 *  - broji se svaka zabeležena aktivnost koja ima uslugu;
 *  - samo aktivnosti od datuma prijema (ako prijem nije zabeležen, sve);
 *  - cena je TRENUTNA cena iz cenovnika (Delphi radi isto);
 *  - stavke su poređane po nazivu usluge;
 *  - aktivnosti bez usluge ("Druga aktivnost" u Delphiju, npr. trening poslušnosti)
 *    takođe se navode, po nazivu, ali sa iznosom 0 i oznakom da se ne naplaćuju.
 *
 * Iznosi se računaju u parama (celi brojevi), da nema grešaka u zaokruživanju.
 */
class ObracunBoravka
{
    /**
     * @return array{stavke: list<array{usluga: string, broj: int, cena: string, iznos: string, naplacuje_se: bool}>, ukupno: string}
     */
    public function zaLjubimca(Ljubimac $ljubimac): array
    {
        $redovi = DB::table('DNEVNA_AKTIVNOST as da')
            ->join('USLUGA as u', 'u.Sifra_usluge', '=', 'da.Sifra_usluge')
            ->join('pets as p', 'p.id', '=', 'da.Sifra_ljubimca')
            ->where('da.Sifra_ljubimca', $ljubimac->id)
            ->where(function ($q) {
                $q->whereNull('p.DatumPrijema')
                    ->orWhereColumn('da.VremeOd', '>=', 'p.DatumPrijema');
            })
            ->groupBy('u.Sifra_usluge', 'u.Naziv', 'u.Cena')
            ->orderBy('u.Naziv')
            ->select('u.Naziv', 'u.Cena', DB::raw('COUNT(*) AS Broj'))
            ->get();

        $stavke = [];
        $ukupnoPara = 0;
        foreach ($redovi as $red) {
            $cenaPara = self::uPare((string) $red->Cena);
            $broj = (int) $red->Broj;
            $iznosPara = $cenaPara * $broj;
            $ukupnoPara += $iznosPara;

            $stavke[] = [
                'usluga' => $red->Naziv,
                'broj' => $broj,
                'cena' => self::uDinare($cenaPara),
                'iznos' => self::uDinare($iznosPara),
                'naplacuje_se' => true,
            ];
        }

        // Aktivnosti van cenovnika: vide se na računu, ali ne ulaze u ukupan iznos.
        // Samo kategorija Aktivnosti; hrana i ostalo bez usluge su potrošnja, ne usluga.
        $besplatne = DB::table('DNEVNA_AKTIVNOST as da')
            ->join('pets as p', 'p.id', '=', 'da.Sifra_ljubimca')
            ->where('da.Sifra_ljubimca', $ljubimac->id)
            ->where('da.Kategorija', 'Aktivnosti')
            ->whereNull('da.Sifra_usluge')
            ->where(function ($q) {
                $q->whereNull('p.DatumPrijema')
                    ->orWhereColumn('da.VremeOd', '>=', 'p.DatumPrijema');
            })
            ->groupBy('da.Vrsta_aktivnosti')
            ->orderBy('da.Vrsta_aktivnosti')
            ->select('da.Vrsta_aktivnosti', DB::raw('COUNT(*) AS Broj'))
            ->get();

        foreach ($besplatne as $red) {
            $stavke[] = [
                'usluga' => $red->Vrsta_aktivnosti,
                'broj' => (int) $red->Broj,
                'cena' => self::uDinare(0),
                'iznos' => self::uDinare(0),
                'naplacuje_se' => false,
            ];
        }

        return ['stavke' => $stavke, 'ukupno' => self::uDinare($ukupnoPara)];
    }

    private static function uPare(string $iznos): int
    {
        return (int) round(((float) $iznos) * 100);
    }

    private static function uDinare(int $pare): string
    {
        return number_format($pare / 100, 2, '.', '');
    }
}
