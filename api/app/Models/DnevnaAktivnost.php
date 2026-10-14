<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Tabela DNEVNA_AKTIVNOST: dnevnik boravka. Kategorija je
 * 'Aktivnosti', 'Hrana' ili 'Ostalo' (ista tabela za sva tri ekrana u Delphiju).
 */
class DnevnaAktivnost extends Model
{
    public const KATEGORIJE = ['Aktivnosti', 'Hrana', 'Ostalo'];

    public const U_TOKU = 'U toku';

    protected $table = 'DNEVNA_AKTIVNOST';

    protected $primaryKey = 'Sifra_aktivnosti';

    public $timestamps = false;

    protected function casts(): array
    {
        return [
            'VremeOd' => 'datetime',
            'VremeDo' => 'datetime',
            'Ocena' => 'integer',
            'Kolicina_Utroska' => 'decimal:3',
        ];
    }

    public function ljubimac(): BelongsTo
    {
        return $this->belongsTo(Ljubimac::class, 'Sifra_ljubimca', 'id');
    }

    public function zaposleni(): BelongsTo
    {
        return $this->belongsTo(Zaposleni::class, 'Sifra_zaposlenog', 'Sifra_zaposlenog');
    }

    public function usluga(): BelongsTo
    {
        return $this->belongsTo(Usluga::class, 'Sifra_usluge', 'Sifra_usluge');
    }

    public function resurs(): BelongsTo
    {
        return $this->belongsTo(Resurs::class, 'Sifra_resursa', 'Sifra_resursa');
    }
}
