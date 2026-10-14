<?php

namespace App\Http\Requests;

/**
 * Prijem ljubimca u pansion: ista pravila kao rectPrimiLjubimcaClick u fraAdmin.pas.
 *  - ime, vrsta, boks i vlasnik su obavezni;
 *  - boks se zapisuje kao 'Boks X' (unos 'A3' postaje 'Boks A3');
 *  - prazne alergije postaju 'Nema poznatih'.
 * Da li vlasnik postoji i da li je boks slobodan proverava kontroler,
 * u istoj transakciji u kojoj upisuje ljubimca.
 */
class PrijemLjubimcaRequest extends ApiRequest
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
            // Korisničko ime ili email vlasnika (vlasnik mora već biti registrovan)
            'vlasnik' => ['required', 'string', 'max:100'],
        ];
    }

    public function attributes(): array
    {
        return $this->naziviPolja() + ['vlasnik' => 'vlasnik'];
    }
}
