<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\IzmenaLjubimcaRequest;
use App\Http\Requests\PrijemLjubimcaRequest;
use App\Http\Resources\DnevnaAktivnostResource;
use App\Http\Resources\LjubimacResource;
use App\Models\DnevnaAktivnost;
use App\Models\Ljubimac;
use App\Models\Musterija;
use App\Models\Zaposleni;
use App\Services\ObracunBoravka;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class LjubimacController extends Controller
{
    public function __construct(private readonly ObracunBoravka $obracun) {}

    /**
     * Spisak ljubimaca. Vlasnik vidi samo svoje, osoblje sve
     * (isto pravilo kao popravljeni upit u fraDnevnikMusterije.pas).
     * Filter: ?status=Aktivan ili ?status=Odjavljen
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $request->validate([
            'status' => ['nullable', Rule::in([Ljubimac::AKTIVAN, Ljubimac::ODJAVLJEN])],
        ], ['status.in' => 'Status može biti Aktivan ili Odjavljen.']);

        $korisnik = $request->user();

        $ljubimci = Ljubimac::bezSlike()
            ->vidljiviZa($korisnik)
            ->when($request->filled('status'), fn ($q) => $q->where('Status', $request->input('status')))
            ->when($korisnik instanceof Zaposleni, fn ($q) => $q->with('vlasnik'))
            ->orderBy('name')
            ->get();

        return LjubimacResource::collection($ljubimci);
    }

    public function show(Request $request, int $id): LjubimacResource
    {
        $ljubimac = $this->vidljiv($request, $id);
        $ljubimac->load('vlasnik');

        return new LjubimacResource($ljubimac);
    }

    /**
     * Prijem u pansion (samo admin): rectPrimiLjubimcaClick u fraAdmin.pas.
     *  - vlasnik mora već biti registrovan (korisničko ime ili email);
     *  - boks ne sme biti zauzet ljubimcem koji je još u pansionu;
     *  - status 'Aktivan', datum prijema = sada.
     * Provera i upis su u jednoj transakciji, pa dva admina ne mogu istovremeno
     * da smeste dva ljubimca u isti boks.
     */
    public function store(PrijemLjubimcaRequest $request): JsonResponse
    {
        $podaci = $request->validated();

        $ljubimac = DB::transaction(function () use ($podaci) {
            $vlasnik = Musterija::where('KorisnickoIme', $podaci['vlasnik'])
                ->orWhere('Email', $podaci['vlasnik'])
                ->first();
            if ($vlasnik === null) {
                throw ValidationException::withMessages([
                    'vlasnik' => 'Vlasnik "'.$podaci['vlasnik'].'" ne postoji. Vlasnik prvo treba da se registruje.',
                ]);
            }

            $this->proveriBoks($podaci['boks']);

            return Ljubimac::create([
                'name' => $podaci['ime'],
                'species' => $podaci['vrsta'],
                'breed' => $podaci['rasa'] ?? '',
                'age' => $podaci['starost'] ?? '',
                'Alergije' => $podaci['alergije'],
                'Lokacija' => $podaci['boks'],
                'Status' => Ljubimac::AKTIVAN,
                'Sifra_musterije' => $vlasnik->Sifra_musterije,
                'DatumPrijema' => now(),
            ]);
        });

        $ljubimac->load('vlasnik');

        return (new LjubimacResource($ljubimac))
            ->additional(['poruka' => $ljubimac->name.' je primljen u pansion ('.$ljubimac->Lokacija.').'])
            ->response()
            ->setStatusCode(201);
    }

    /** Izmena podataka ljubimca koji je u pansionu (samo admin). */
    public function update(IzmenaLjubimcaRequest $request, int $id): JsonResponse|LjubimacResource
    {
        $podaci = $request->validated();

        $ljubimac = DB::transaction(function () use ($podaci, $id) {
            $ljubimac = Ljubimac::bezSlike()->lockForUpdate()->findOrFail($id);
            if ($ljubimac->jeOdjavljen()) {
                return null;
            }

            $this->proveriBoks($podaci['boks'], $ljubimac->id);

            $ljubimac->update([
                'name' => $podaci['ime'],
                'species' => $podaci['vrsta'],
                'breed' => $podaci['rasa'] ?? '',
                'age' => $podaci['starost'] ?? '',
                'Alergije' => $podaci['alergije'],
                'Lokacija' => $podaci['boks'],
            ]);

            return $ljubimac;
        });

        if ($ljubimac === null) {
            return response()->json(['poruka' => 'Odjavljen ljubimac se ne može menjati.'], 409);
        }

        return new LjubimacResource($ljubimac->load('vlasnik'));
    }

    /**
     * Odjava iz pansiona (samo admin): rectOdjaviLjubimcaClick u fraAdmin.pas.
     *  - ne može ako ima aktivnost 'U toku';
     *  - boks se oslobađa, ljubimac ostaje u bazi radi istorije i računa;
     *  - odgovor sadrži račun.
     */
    public function odjava(int $id): JsonResponse
    {
        return DB::transaction(function () use ($id) {
            $ljubimac = Ljubimac::bezSlike()->lockForUpdate()->findOrFail($id);

            if ($ljubimac->jeOdjavljen()) {
                return response()->json([
                    'poruka' => $ljubimac->name.' je već odjavljen.',
                    'racun' => $this->obracun->zaLjubimca($ljubimac),
                ], 409);
            }

            $uToku = $ljubimac->aktivnosti()->where('StatusAktivnosti', DnevnaAktivnost::U_TOKU)->exists();
            if ($uToku) {
                return response()->json([
                    'poruka' => $ljubimac->name.' ima aktivnost u toku. Odjava je moguća kad se završi.',
                ], 409);
            }

            $ljubimac->update([
                'Status' => Ljubimac::ODJAVLJEN,
                'DatumOdjave' => now(),
                'Lokacija' => '',
            ]);

            return response()->json([
                'poruka' => $ljubimac->name.' je odjavljen.',
                'ljubimac' => new LjubimacResource($ljubimac),
                'racun' => $this->obracun->zaLjubimca($ljubimac),
            ]);
        });
    }

    /**
     * Dnevnik boravka, najnovije prvo, 50 po strani.
     * Filter: ?kategorija=Aktivnosti | Hrana | Ostalo
     */
    public function dnevnik(Request $request, int $id): AnonymousResourceCollection
    {
        $request->validate([
            'kategorija' => ['nullable', Rule::in(DnevnaAktivnost::KATEGORIJE)],
        ], ['kategorija.in' => 'Kategorija može biti Aktivnosti, Hrana ili Ostalo.']);

        $ljubimac = $this->vidljiv($request, $id);

        $zapisi = $ljubimac->aktivnosti()
            ->with(['zaposleni:Sifra_zaposlenog,Ime,Prezime', 'usluga:Sifra_usluge,Naziv'])
            ->when($request->filled('kategorija'), fn ($q) => $q->where('Kategorija', $request->input('kategorija')))
            ->orderByDesc('VremeOd')
            ->orderByDesc('Sifra_aktivnosti')
            ->paginate(50)
            ->withQueryString();

        return DnevnaAktivnostResource::collection($zapisi);
    }

    /** Račun za boravak (ObracunBoravka u uUserStore.pas). */
    public function racun(Request $request, int $id): JsonResponse
    {
        $ljubimac = $this->vidljiv($request, $id);

        return response()->json([
            'ljubimac' => ['id' => $ljubimac->id, 'ime' => $ljubimac->name],
            'od' => $ljubimac->DatumPrijema?->format('Y-m-d H:i:s'),
            ...$this->obracun->zaLjubimca($ljubimac),
            'valuta' => 'RSD',
        ]);
    }

    /** Slika ljubimca, kako je sačuvana u Delphiju (image_blob). */
    public function slika(Request $request, int $id): Response
    {
        $this->vidljiv($request, $id);

        $slika = Ljubimac::whereKey($id)->value('image_blob');
        abort_if($slika === null || $slika === '', 404, 'Ljubimac nema sliku.');

        $tip = (new \finfo(FILEINFO_MIME_TYPE))->buffer($slika) ?: 'application/octet-stream';

        return response($slika, 200, ['Content-Type' => $tip]);
    }

    /** Ljubimac koga prijavljeni korisnik sme da vidi; tuđi ljubimac = 404 (ne odaje da postoji). */
    private function vidljiv(Request $request, int $id): Ljubimac
    {
        return Ljubimac::bezSlike()->vidljiviZa($request->user())->findOrFail($id);
    }

    /** Boks ne sme biti zauzet drugim ljubimcem koji je još u pansionu. */
    private function proveriBoks(string $boks, ?int $osimLjubimca = null): void
    {
        $zauzeo = Ljubimac::where('Lokacija', $boks)
            ->where('Status', '<>', Ljubimac::ODJAVLJEN)
            ->when($osimLjubimca !== null, fn ($q) => $q->whereKeyNot($osimLjubimca))
            ->lockForUpdate()
            ->first(['id', 'name']);

        if ($zauzeo !== null) {
            throw ValidationException::withMessages([
                'boks' => $boks.' je zauzet ('.$zauzeo->name.').',
            ]);
        }
    }
}
