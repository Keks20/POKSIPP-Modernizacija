<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Zajednička osnova za validaciju: poruke na srpskom.
 * Ko sme da pozove rutu proverava middleware 'uloga', ne authorize().
 */
abstract class ApiRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function messages(): array
    {
        // Ključ '*.pravilo' važi za sva polja. Bez '*.' bi ključ 'email' značio
        // "SVE greške polja email" i pregazio bi i poruku o zauzetom emailu.
        return [
            '*.required' => 'Polje ":attribute" je obavezno.',
            '*.string' => 'Polje ":attribute" mora biti tekst.',
            '*.max' => 'Polje ":attribute" može imati najviše :max znakova.',
            '*.min' => 'Polje ":attribute" mora imati bar :min znakova.',
            '*.email' => 'Polje ":attribute" mora biti ispravna email adresa.',
        ];
    }
}
