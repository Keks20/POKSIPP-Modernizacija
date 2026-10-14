<?php

namespace App\Http\Resources;

use App\Models\Musterija;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Musterija */
class MusterijaResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->Sifra_musterije,
            'ime' => $this->Ime,
            'prezime' => $this->Prezime,
            'korisnicko_ime' => $this->KorisnickoIme,
            'email' => $this->Email,
            'telefon' => $this->Telefon_Hitno,
            'nalog' => $this->Nalog,
        ];
    }
}
