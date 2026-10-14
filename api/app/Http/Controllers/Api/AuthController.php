<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\PrijavaRequest;
use App\Http\Requests\RegistracijaRequest;
use App\Http\Resources\MusterijaResource;
use App\Http\Resources\ZaposleniResource;
use App\Models\Musterija;
use App\Models\Zaposleni;
use App\Support\Lozinka;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AuthController extends Controller
{
    /**
     * Prijava. Isti redosled kao fraLogin.pas:
     *  1. ZAPOSLENI po korisničkom imenu -> uloga admin ili zaposleni;
     *  2. MUSTERIJA po korisničkom imenu ili emailu -> uloga musterija.
     * Vraća Sanctum token koji se šalje u zaglavlju: Authorization: Bearer <token>.
     */
    public function prijava(PrijavaRequest $request): JsonResponse
    {
        $unos = $request->string('korisnicko_ime')->toString();
        $lozinka = $request->string('lozinka')->toString();
        $uredjaj = $request->input('uredjaj') ?: 'api';

        $korisnik = Zaposleni::where('KorisnickoIme', $unos)->first();
        if ($korisnik === null || ! Lozinka::proveri($lozinka, $korisnik->Lozinka)) {
            $korisnik = Musterija::where('KorisnickoIme', $unos)
                ->orWhere('Email', $unos)
                ->get()
                ->first(fn (Musterija $m) => Lozinka::proveri($lozinka, $m->Lozinka));
        }

        if ($korisnik === null || ! $korisnik->jeAktivan()) {
            return response()->json(['poruka' => 'Pogrešno korisničko ime ili lozinka.'], 401);
        }

        // Rok važenja se upisuje u sam token (kolona expires_at), vidi config/sanctum.php
        $minuta = config('sanctum.expiration');
        $token = $korisnik->createToken(
            $uredjaj,
            [$korisnik->uloga()],
            $minuta ? now()->addMinutes($minuta) : null,
        );

        return response()->json([
            'token' => $token->plainTextToken,
            'tip' => 'Bearer',
            'uloga' => $korisnik->uloga(),
            'istice' => $token->accessToken->expires_at?->format('Y-m-d H:i:s'),
            'korisnik' => $this->korisnikResource($korisnik),
        ]);
    }

    /** Registracija vlasnika (fraRegister.pas). Nalog je 'Standard', lozinka se čuva kao heš. */
    public function registracija(RegistracijaRequest $request): JsonResponse
    {
        $podaci = $request->validated();

        $musterija = Musterija::create([
            'KorisnickoIme' => $podaci['korisnicko_ime'],
            'Lozinka' => Lozinka::hes($podaci['lozinka']),
            'Telefon_Hitno' => $podaci['telefon'],
            'Email' => $podaci['email'],
            'Ime' => $podaci['ime'],
            'Prezime' => $podaci['prezime'],
            'Nalog' => 'Standard',
        ]);

        return (new MusterijaResource($musterija))
            ->additional(['poruka' => 'Uspešna registracija. Možete se prijaviti.'])
            ->response()
            ->setStatusCode(201);
    }

    /** Odjava: briše samo token kojim je poslat zahtev (ostali uređaji ostaju prijavljeni). */
    public function odjava(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()?->delete();

        return response()->json(['poruka' => 'Odjavljeni ste.']);
    }

    /** Ko je prijavljen. */
    public function ja(Request $request): JsonResponse
    {
        $korisnik = $request->user();

        return response()->json([
            'uloga' => $korisnik->uloga(),
            'korisnik' => $this->korisnikResource($korisnik),
        ]);
    }

    private function korisnikResource(Zaposleni|Musterija $korisnik): ZaposleniResource|MusterijaResource
    {
        return $korisnik instanceof Zaposleni
            ? new ZaposleniResource($korisnik)
            : new MusterijaResource($korisnik);
    }
}
