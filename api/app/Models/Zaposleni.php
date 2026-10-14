<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;

/**
 * Tabela ZAPOSLENI iz Delphi aplikacije (osoblje i administrator).
 *
 * Model radi nad POSTOJEĆOM tabelom: naziv tabele, primarni ključ i
 * kolone su isti kao u Delphiju, a Laravel ne očekuje created_at/updated_at.
 */
class Zaposleni extends Authenticatable
{
    use HasApiTokens;

    protected $table = 'ZAPOSLENI';

    protected $primaryKey = 'Sifra_zaposlenog';

    public $timestamps = false;

    protected $fillable = ['Ime', 'Prezime', 'Uloga', 'KorisnickoIme', 'Lozinka', 'Dostupan'];

    // Heš lozinke nikad ne ide u JSON odgovor
    protected $hidden = ['Lozinka'];

    protected function casts(): array
    {
        return [
            'Dostupan' => 'boolean',
        ];
    }

    public function getAuthPassword(): ?string
    {
        return $this->Lozinka;
    }

    /** Uloga za API: admin ili zaposleni (Delphi: 'Admin' -> ADMIN, ostalo -> ZAPOSLENI). */
    public function uloga(): string
    {
        return strcasecmp($this->Uloga ?? '', 'Admin') === 0 ? 'admin' : 'zaposleni';
    }

    /** Delphi deaktivira zaposlenog postavljanjem uloge 'Neaktivan' i brisanjem lozinke. */
    public function jeAktivan(): bool
    {
        return strcasecmp($this->Uloga ?? '', 'Neaktivan') !== 0 && $this->Lozinka !== null;
    }

    public function aktivnosti(): HasMany
    {
        return $this->hasMany(DnevnaAktivnost::class, 'Sifra_zaposlenog', 'Sifra_zaposlenog');
    }
}
