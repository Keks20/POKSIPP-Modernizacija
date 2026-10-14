<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;

/**
 * Tabela MUSTERIJA: vlasnici ljubimaca. Prijavljuju se korisničkim imenom ili emailom.
 */
class Musterija extends Authenticatable
{
    use HasApiTokens;

    protected $table = 'MUSTERIJA';

    protected $primaryKey = 'Sifra_musterije';

    public $timestamps = false;

    protected $fillable = ['Ime', 'Prezime', 'Nalog', 'Telefon_Hitno', 'KorisnickoIme', 'Lozinka', 'Email'];

    protected $hidden = ['Lozinka'];

    public function getAuthPassword(): ?string
    {
        return $this->Lozinka;
    }

    public function uloga(): string
    {
        return 'musterija';
    }

    public function jeAktivan(): bool
    {
        return true;
    }

    public function ljubimci(): HasMany
    {
        return $this->hasMany(Ljubimac::class, 'Sifra_musterije', 'Sifra_musterije');
    }
}
