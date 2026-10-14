<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/** Tabela USLUGA: cenovnik. */
class Usluga extends Model
{
    protected $table = 'USLUGA';

    protected $primaryKey = 'Sifra_usluge';

    public $timestamps = false;

    protected $fillable = ['Naziv', 'Cena'];

    protected function casts(): array
    {
        return [
            'Cena' => 'decimal:2',
        ];
    }

    public function aktivnosti(): HasMany
    {
        return $this->hasMany(DnevnaAktivnost::class, 'Sifra_usluge', 'Sifra_usluge');
    }
}
