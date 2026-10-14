<?php

namespace App\Http\Requests;

class PrijavaRequest extends ApiRequest
{
    public function rules(): array
    {
        return [
            // Zaposleni: korisničko ime. Vlasnik: korisničko ime ili email (kao u Delphiju).
            'korisnicko_ime' => ['required', 'string', 'max:100'],
            'lozinka' => ['required', 'string', 'max:255'],
            // Naziv uređaja/klijenta, vidi se u tabeli tokena (npr. "Postman", "web")
            'uredjaj' => ['nullable', 'string', 'max:100'],
        ];
    }

    public function attributes(): array
    {
        return [
            'korisnicko_ime' => 'korisničko ime',
            'lozinka' => 'lozinka',
            'uredjaj' => 'uređaj',
        ];
    }
}
