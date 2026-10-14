<?php

namespace App\Http\Resources;

use App\Models\Ljubimac;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Ljubimac u JSON-u. Ključevi su na srpskom, nezavisno od naziva kolona
 * u bazi (name, species...), pa se baza kasnije može preimenovati bez
 * promene API-ja.
 *
 * @mixin Ljubimac
 */
class LjubimacResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'ime' => $this->name,
            'vrsta' => $this->species,
            'rasa' => $this->breed,
            'starost' => $this->age,
            'alergije' => $this->Alergije,
            'boks' => $this->Lokacija !== '' ? $this->Lokacija : null,
            'status' => $this->Status,
            'datum_prijema' => $this->DatumPrijema?->format('Y-m-d H:i:s'),
            'datum_odjave' => $this->DatumOdjave?->format('Y-m-d H:i:s'),
            'ima_sliku' => (bool) $this->ima_sliku,
            'vlasnik' => new MusterijaResource($this->whenLoaded('vlasnik')),
        ];
    }
}
