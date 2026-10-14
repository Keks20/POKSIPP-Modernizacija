<?php

namespace App\Http\Resources;

use App\Models\Zaposleni;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Zaposleni */
class ZaposleniResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->Sifra_zaposlenog,
            'ime' => $this->Ime,
            'prezime' => $this->Prezime,
            'uloga' => $this->Uloga,
            'korisnicko_ime' => $this->KorisnickoIme,
            'dostupan' => $this->Dostupan,
        ];
    }
}
