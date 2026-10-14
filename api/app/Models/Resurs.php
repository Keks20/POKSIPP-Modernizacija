<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/** Tabela RESURS: magacin. Jedinica je u nazivu u zagradi, npr. 'Suva hrana (g)'. */
class Resurs extends Model
{
    protected $table = 'RESURS';

    protected $primaryKey = 'Sifra_resursa';

    public $timestamps = false;

    protected $fillable = ['Tip_Resursa', 'Trenutno_u_Magacinu', 'Kolicina_Nivo'];

    protected function casts(): array
    {
        return [
            'Trenutno_u_Magacinu' => 'decimal:3',
            'Kolicina_Nivo' => 'decimal:3',
        ];
    }

    /** Isto kao JedinicaResursa() u Delphiju: tekst u poslednjoj zagradi, malim slovima. */
    public function jedinica(): string
    {
        $otvorena = strrpos($this->Tip_Resursa, '(');
        $zatvorena = strrpos($this->Tip_Resursa, ')');
        if ($otvorena === false || $zatvorena === false || $zatvorena < $otvorena) {
            return '';
        }

        return mb_strtolower(trim(substr($this->Tip_Resursa, $otvorena + 1, $zatvorena - $otvorena - 1)));
    }

    public function ispodMinimuma(): bool
    {
        return bccomp((string) $this->Trenutno_u_Magacinu, (string) $this->Kolicina_Nivo, 3) < 0;
    }

    public function aktivnosti(): HasMany
    {
        return $this->hasMany(DnevnaAktivnost::class, 'Sifra_resursa', 'Sifra_resursa');
    }
}
