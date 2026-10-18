<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Musterija;
use App\Support\Lozinka;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\View;

/**
 * Prijava vlasnika na web stranicu. Isti nalog kao u Delphiju: korisnicko ime
 * ili email + lozinka (SHA-256 hes, kao fraLogin.pas). Zaposleni koriste Delphi.
 */
class PrijavaController extends Controller
{
    public function forma(): View
    {
        return view('web.prijava');
    }

    public function prijava(Request $request): RedirectResponse
    {
        $podaci = $request->validate([
            'korisnicko_ime' => ['required', 'string', 'max:100'],
            'lozinka' => ['required', 'string', 'max:255'],
        ], [
            'korisnicko_ime.required' => 'Unesite korisničko ime ili email.',
            'lozinka.required' => 'Unesite lozinku.',
        ]);

        $vlasnik = Musterija::where('KorisnickoIme', $podaci['korisnicko_ime'])
            ->orWhere('Email', $podaci['korisnicko_ime'])
            ->get()
            ->first(fn (Musterija $m) => Lozinka::proveri($podaci['lozinka'], $m->Lozinka));

        if ($vlasnik === null) {
            return back()
                ->withErrors(['korisnicko_ime' => 'Pogrešno korisničko ime ili lozinka.'])
                ->onlyInput('korisnicko_ime');
        }

        Auth::guard('vlasnik')->login($vlasnik);
        // Nova sesija posle prijave: zastita od preuzimanja sesije (session fixation)
        $request->session()->regenerate();

        return redirect()->intended(route('ljubimci.index'));
    }

    public function odjava(Request $request): RedirectResponse
    {
        Auth::guard('vlasnik')->logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('prijava')->with('poruka', 'Odjavljeni ste.');
    }
}
