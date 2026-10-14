<?php

namespace App\Http\Resources;

use App\Models\Usluga;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Usluga */
class UslugaResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->Sifra_usluge,
            'naziv' => $this->Naziv,
            'cena' => $this->Cena,
        ];
    }
}
