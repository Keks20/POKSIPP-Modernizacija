<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Pušta zahtev samo korisnicima sa navedenim ulogama.
 * Upotreba u rutama: ->middleware('uloga:admin') ili 'uloga:admin,zaposleni'.
 *
 * Uloge: admin, zaposleni, musterija.
 *
 * Uloga se čita iz baze pri SVAKOM zahtevu, ne iz tokena. Delphi aplikacija
 * deaktivira zaposlenog ('Neaktivan', lozinka NULL), a za tokene ne zna,
 * pa bi token deaktiviranog zaposlenog inače i dalje radio.
 */
class ProveraUloge
{
    public function handle(Request $request, Closure $next, string ...$uloge): Response
    {
        $korisnik = $request->user();

        if ($korisnik === null) {
            return response()->json(['poruka' => 'Niste prijavljeni.'], 401);
        }

        if (! $korisnik->jeAktivan()) {
            $korisnik->currentAccessToken()?->delete();

            return response()->json(['poruka' => 'Nalog je deaktiviran.'], 401);
        }

        if ($uloge !== [] && ! in_array($korisnik->uloga(), $uloge, true)) {
            return response()->json(['poruka' => 'Nemate pravo pristupa.'], 403);
        }

        return $next($request);
    }
}
