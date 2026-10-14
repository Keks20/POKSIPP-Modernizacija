<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Tabela pets. Naziv (i engleske kolone name, species...) ostaje kao u Delphiju,
 * jer Delphi i dalje radi nad ovom tabelom. Preimenovanje ide tek kad Delphi
 * prestane da je koristi.
 */
class Ljubimac extends Model
{
    public const AKTIVAN = 'Aktivan';

    public const ODJAVLJEN = 'Odjavljen';

    protected $table = 'pets';

    protected $primaryKey = 'id';

    public $timestamps = false;

    protected $fillable = [
        'name', 'species', 'breed', 'age', 'Status', 'Sifra_musterije',
        'Lokacija', 'Alergije', 'DatumPrijema', 'DatumOdjave',
    ];

    // Slika je binarni podatak (MEDIUMBLOB) i ne može u JSON
    protected $hidden = ['image_blob'];

    protected function casts(): array
    {
        return [
            'DatumPrijema' => 'datetime',
            'DatumOdjave' => 'datetime',
        ];
    }

    public function vlasnik(): BelongsTo
    {
        return $this->belongsTo(Musterija::class, 'Sifra_musterije', 'Sifra_musterije');
    }

    public function aktivnosti(): HasMany
    {
        return $this->hasMany(DnevnaAktivnost::class, 'Sifra_ljubimca', 'id');
    }

    public function jeOdjavljen(): bool
    {
        return $this->Status === self::ODJAVLJEN;
    }

    /**
     * Sve kolone osim slike (MEDIUMBLOB, do 16 MB), plus kolona ima_sliku.
     * Slika se šalje posebnom rutom /ljubimci/{id}/slika.
     */
    public function scopeBezSlike(Builder $upit): Builder
    {
        return $upit->select([
            'id', 'name', 'species', 'breed', 'age', 'Status', 'Sifra_musterije',
            'Lokacija', 'Alergije', 'DatumPrijema', 'DatumOdjave',
        ])->selectRaw('(image_blob IS NOT NULL) AS ima_sliku');
    }

    /** Ljubimci koje korisnik sme da vidi: vlasnik samo svoje, osoblje sve. */
    public function scopeVidljiviZa(Builder $upit, Zaposleni|Musterija $korisnik): Builder
    {
        if ($korisnik instanceof Musterija) {
            $upit->where('Sifra_musterije', $korisnik->Sifra_musterije);
        }

        return $upit;
    }
}
