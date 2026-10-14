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
 *  - stavke su poređane po nazivu usluge.
 *
 * Iznosi se računaju u parama (celi brojevi), da nema grešaka u zaokruživanju.
 */
class ObracunBoravka
{
    /**
     * @return array{stavke: list<array{usluga: string, broj: int, cena: string, iznos: string}>, ukupno: string}
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
