<?php

namespace App\Http\Resources;

use App\Models\Resurs;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Resurs */
class ResursResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->Sifra_resursa,
            'naziv' => $this->Tip_Resursa,
            'jedinica' => $this->jedinica(),
            'na_stanju' => $this->Trenutno_u_Magacinu,
            'minimum' => $this->Kolicina_Nivo,
            'ispod_minimuma' => $this->ispodMinimuma(),
        ];
    }
}
