<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\DnevnaAktivnost;
use App\Models\Ljubimac;
use App\Models\Musterija;
use App\Services\ObracunBoravka;
use App\Services\ObradaSlike;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\View;

/**
 * Stranice vlasnika: moji ljubimci, dnevnik i racun, slika.
 * Sva pravila su ista kao u API-ju (isti modeli i servisi).
 */
class LjubimciController extends Controller
{
    public function index(): View
    {
        $ljubimci = Ljubimac::bezSlike()
            ->vidljiviZa($this->vlasnik())
            // U pansionu prvo, pa odjavljeni; unutar grupe po imenu (kao Delphi)
            ->orderByRaw("CASE WHEN Status = 'Odjavljen' THEN 1 ELSE 0 END")
            ->orderBy('name')
            ->get();

        return view('web.ljubimci.index', ['ljubimci' => $ljubimci]);
    }

    public function show(Request $request, int $id, ObracunBoravka $obracun): View
    {
        $ljubimac = $this->moj($id);

        $kategorija = $request->query('kategorija');
        if (! in_array($kategorija, DnevnaAktivnost::KATEGORIJE, true)) {
            $kategorija = null;
        }

        $dnevnik = $ljubimac->aktivnosti()
            ->with(['zaposleni:Sifra_zaposlenog,Ime,Prezime'])
            ->when($kategorija, fn ($q) => $q->where('Kategorija', $kategorija))
            ->orderByDesc('VremeOd')
            ->orderByDesc('Sifra_aktivnosti')
            ->paginate(20)
            ->withQueryString();

        return view('web.ljubimci.show', [
            'ljubimac' => $ljubimac,
            'dnevnik' => $dnevnik,
            'kategorija' => $kategorija,
            'racun' => $obracun->zaLjubimca($ljubimac),
        ]);
    }

    public function slika(int $id, ObradaSlike $slike): Response
    {
        return $slike->odgovor($this->moj($id));
    }

    public function postaviSliku(Request $request, int $id, ObradaSlike $slike): RedirectResponse
    {
        $ljubimac = $this->moj($id);
        $request->validate(ObradaSlike::pravila(), ObradaSlike::poruke());

        $slike->sacuvaj($ljubimac, $slike->uJpeg($request->file('slika')));

        return redirect()
            ->route('ljubimci.show', $ljubimac->id)
            ->with('poruka', 'Slika je sačuvana. Videće je i osoblje u pansionu.');
    }

    private function vlasnik(): Musterija
    {
        return Auth::guard('vlasnik')->user();
    }

    /** Samo sopstveni ljubimac; tudji = 404, kao u API-ju. */
    private function moj(int $id): Ljubimac
    {
        return Ljubimac::bezSlike()->vidljiviZa($this->vlasnik())->findOrFail($id);
    }
}
