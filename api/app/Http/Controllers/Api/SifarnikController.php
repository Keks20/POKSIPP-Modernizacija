<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\MusterijaResource;
use App\Http\Resources\ResursResource;
use App\Http\Resources\UslugaResource;
use App\Http\Resources\ZaposleniResource;
use App\Models\Musterija;
use App\Models\Resurs;
use App\Models\Usluga;
use App\Models\Zaposleni;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/** Spiskovi za čitanje: cenovnik, magacin, zaposleni, vlasnici. */
class SifarnikController extends Controller
{
    /** Cenovnik usluga (svi prijavljeni). */
    public function usluge(): AnonymousResourceCollection
    {
        return UslugaResource::collection(Usluga::orderBy('Naziv')->get());
    }

    /** Stanje magacina (osoblje). */
    public function resursi(): AnonymousResourceCollection
    {
        return ResursResource::collection(Resurs::orderBy('Tip_Resursa')->get());
    }

    /** Zaposleni bez administratora, kao spisak u fraAdmin.pas (samo admin). */
    public function zaposleni(): AnonymousResourceCollection
    {
        return ZaposleniResource::collection(
            Zaposleni::where('Uloga', '<>', 'Admin')->orderBy('Ime')->orderBy('Prezime')->get()
        );
    }

    /** Registrovani vlasnici (osoblje), npr. za izbor vlasnika pri prijemu. */
    public function musterije(): AnonymousResourceCollection
    {
        return MusterijaResource::collection(
            Musterija::orderBy('Prezime')->orderBy('Ime')->get()
        );
    }
}
