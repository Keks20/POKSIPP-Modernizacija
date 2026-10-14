<?php

namespace App\Http\Requests;

/**
 * Izmena podataka ljubimca koji je u pansionu (PUT = šalju se svi podaci).
 * Ista pravila kao kod prijema; vlasnik se ovde ne menja.
 */
class IzmenaLjubimcaRequest extends ApiRequest
{
    use NormalizujeLjubimca;

    public function rules(): array
    {
        return [
            'ime' => ['required', 'string', 'max:50'],
            'vrsta' => ['required', 'string', 'max:50'],
            'rasa' => ['nullable', 'string', 'max:50'],
            'starost' => ['nullable', 'string', 'max:30'],
            'alergije' => ['nullable', 'string', 'max:255'],
            'boks' => ['required', 'string', 'max:50'],
        ];
    }

    public function attributes(): array
    {
        return $this->naziviPolja();
    }
}
