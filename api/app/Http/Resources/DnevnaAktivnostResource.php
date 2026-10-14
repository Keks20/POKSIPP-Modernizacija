<?php

namespace App\Http\Resources;

use App\Models\DnevnaAktivnost;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Jedan zapis iz dnevnika. Polja koja ne pripadaju kategoriji se izostavljaju
 * (npr. količina hrane kod šetnje), isto kao što ih Delphi ne prikazuje.
 *
 * @mixin DnevnaAktivnost
 */
class DnevnaAktivnostResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $kategorija = $this->Kategorija;

        return [
            'id' => $this->Sifra_aktivnosti,
            'kategorija' => $kategorija,
            'vrsta' => $this->Vrsta_aktivnosti,
            'vreme_od' => $this->VremeOd?->format('Y-m-d H:i:s'),
            'komentar' => $this->Komentar,
            'zaposleni' => $this->whenLoaded('zaposleni', fn () => $this->zaposleni
                ? trim($this->zaposleni->Ime.' '.$this->zaposleni->Prezime)
                : null),
            'usluga' => $this->whenLoaded('usluga', fn () => $this->usluga?->Naziv),

            // Aktivnosti (šetnja, igra...)
            $this->mergeWhen($kategorija === 'Aktivnosti', fn () => [
                'vreme_do' => $this->VremeDo?->format('Y-m-d H:i:s'),
                'trajanje' => $this->DuzinaTrajanja,
                'status' => $this->StatusAktivnosti,
                'ocena' => $this->Ocena,
                'ponasanje' => $this->ProcenaPonasanja,
            ]),

            // Hrana
            $this->mergeWhen($kategorija === 'Hrana', fn () => [
                'obrok' => $this->VremeObroka,
                'kolicina' => $this->Kolicina,
            ]),

            // Ostalo (kupanje, pregled...)
            $this->mergeWhen($kategorija === 'Ostalo', fn () => [
                'stanje' => $this->StatusOstalo,
            ]),
        ];
    }
}
