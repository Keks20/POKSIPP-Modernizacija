<?php

namespace App\Http\Requests;

use Illuminate\Support\Str;

/**
 * Pretvaranja koja Delphi radi pre upisa ljubimca (fraAdmin.pas):
 *  - 'A3' -> 'Boks A3' (ako unos već ne počinje sa 'Boks');
 *  - prazne alergije -> 'Nema poznatih'.
 * Radi se pre validacije, da bi se dužina proveravala na vrednosti koja se upisuje.
 */
trait NormalizujeLjubimca
{
    protected function prepareForValidation(): void
    {
        $boks = is_string($this->input('boks')) ? trim($this->input('boks')) : $this->input('boks');
        if (is_string($boks) && $boks !== '' && ! Str::startsWith(Str::lower($boks), 'boks')) {
            $boks = 'Boks '.$boks;
        }

        $alergije = $this->input('alergije');
        if ($alergije === null || (is_string($alergije) && trim($alergije) === '')) {
            $alergije = 'Nema poznatih';
        }

        $this->merge(['boks' => $boks, 'alergije' => $alergije]);
    }

    protected function naziviPolja(): array
    {
        return [
            'ime' => 'ime',
            'vrsta' => 'vrsta',
            'rasa' => 'rasa',
            'starost' => 'starost',
            'alergije' => 'alergije',
            'boks' => 'boks',
        ];
    }
}
