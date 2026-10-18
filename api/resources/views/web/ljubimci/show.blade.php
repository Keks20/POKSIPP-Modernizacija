@extends('web.layout')

@section('naslov', $ljubimac->name)

@php
    $rsd = fn ($iznos) => number_format((float) $iznos, 2, ',', '.') . ' RSD';
    $filteri = [null => 'Sve', 'Aktivnosti' => 'Aktivnosti', 'Hrana' => 'Hrana', 'Ostalo' => 'Ostalo'];
@endphp

@section('sadrzaj')
<a href="{{ route('ljubimci.index') }}" class="text-sitno">← Moji ljubimci</a>

<div class="row g-4 mt-1">
    {{-- Levo: slika i podaci --}}
    <div class="col-lg-4">
        <div class="card kartica p-3">
            @if ($ljubimac->ima_sliku)
                <img src="{{ route('ljubimci.slika', $ljubimac->id) }}?v={{ now()->timestamp }}" alt="{{ $ljubimac->name }}" class="slika-velika">
            @else
                <div class="bez-slike rounded">{{ mb_strtoupper(mb_substr($ljubimac->name, 0, 1)) }}</div>
            @endif

            <form method="post" action="{{ route('ljubimci.postavi-sliku', $ljubimac->id) }}" enctype="multipart/form-data" class="mt-3">
                @csrf
                <label for="slika" class="form-label text-sitno mb-1">{{ $ljubimac->ima_sliku ? 'Promeni sliku' : 'Postavi sliku' }}</label>
                <div class="input-group input-group-sm">
                    <input id="slika" name="slika" type="file" accept="image/jpeg,image/png,image/webp"
                           class="form-control @error('slika') is-invalid @enderror" required>
                    <button class="btn btn-pk">Sačuvaj</button>
                    @error('slika')<div class="invalid-feedback">{{ $message }}</div>@enderror
                </div>
                <div class="form-text">JPEG, PNG ili WebP, najviše 5 MB.</div>
            </form>

            <h1 class="h3 mt-4 mb-1">{{ $ljubimac->name }}</h1>
            <div class="mb-3">@include('web.ljubimci.status', ['ljubimac' => $ljubimac])</div>

            <dl class="row text-sitno mb-0">
                <dt class="col-5 fw-normal text-muted">Vrsta</dt><dd class="col-7">{{ $ljubimac->species }}</dd>
                <dt class="col-5 fw-normal text-muted">Rasa</dt><dd class="col-7">{{ $ljubimac->breed ?: '—' }}</dd>
                <dt class="col-5 fw-normal text-muted">Starost</dt><dd class="col-7">{{ $ljubimac->age ?: '—' }}</dd>
                <dt class="col-5 fw-normal text-muted">Alergije</dt><dd class="col-7">{{ $ljubimac->Alergije ?: '—' }}</dd>
                <dt class="col-5 fw-normal text-muted">Prijem</dt><dd class="col-7">{{ $ljubimac->DatumPrijema?->format('d.m.Y. H:i') ?? '—' }}</dd>
                @if ($ljubimac->DatumOdjave)
                    <dt class="col-5 fw-normal text-muted">Odjava</dt><dd class="col-7">{{ $ljubimac->DatumOdjave->format('d.m.Y. H:i') }}</dd>
                @endif
            </dl>
        </div>
    </div>

    {{-- Desno: racun i dnevnik --}}
    <div class="col-lg-8">
        <div class="card kartica p-3 mb-4">
            <h2 class="h5">Račun za boravak</h2>
            @if (empty($racun['stavke']))
                <p class="text-muted mb-0">Još nema zabeleženih usluga.</p>
            @else
                <div class="table-responsive"><table class="table table-sm align-middle mb-0">
                    <thead><tr><th>Usluga</th><th class="text-end">Puta</th><th class="text-end">Cena</th><th class="text-end">Iznos</th></tr></thead>
                    <tbody>
                    @foreach ($racun['stavke'] as $stavka)
                        <tr>
                            <td>{{ $stavka['usluga'] }}</td>
                            <td class="text-end">{{ $stavka['broj'] }}</td>
                            @if ($stavka['naplacuje_se'])
                                <td class="text-end text-nowrap">{{ $rsd($stavka['cena']) }}</td>
                                <td class="text-end text-nowrap">{{ $rsd($stavka['iznos']) }}</td>
                            @else
                                <td class="text-end text-nowrap">{{ $rsd($stavka['cena']) }}</td>
                                <td class="text-end text-nowrap text-muted">ne naplaćuje se</td>
                            @endif
                        </tr>
                    @endforeach
                    </tbody>
                    <tfoot><tr><th colspan="3">Ukupno</th><th class="text-end text-nowrap">{{ $rsd($racun['ukupno']) }}</th></tr></tfoot>
                </table></div>
            @endif
        </div>

        <div class="card kartica p-3">
            <div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-2">
                <h2 class="h5 mb-0">Dnevnik</h2>
                <ul class="nav nav-pills nav-sm">
                    @foreach ($filteri as $vrednost => $naziv)
                        <li class="nav-item">
                            <a class="nav-link py-1 px-2 text-sitno {{ $kategorija === ($vrednost ?: null) ? 'active' : '' }}"
                               href="{{ route('ljubimci.show', array_filter(['id' => $ljubimac->id, 'kategorija' => $vrednost ?: null])) }}">{{ $naziv }}</a>
                        </li>
                    @endforeach
                </ul>
            </div>

            @forelse ($dnevnik as $zapis)
                <div class="zapis py-2">
                    <div class="d-flex justify-content-between">
                        <strong>{{ $zapis->Vrsta_aktivnosti }}</strong>
                        <span class="text-muted text-sitno">{{ $zapis->VremeOd?->format('d.m.Y. H:i') }}</span>
                    </div>
                    <div class="text-sitno text-muted">
                        {{ $zapis->Kategorija }}
                        @if ($zapis->zaposleni) · {{ $zapis->zaposleni->Ime }} {{ $zapis->zaposleni->Prezime }}@endif
                    </div>
                    <div class="text-sitno mt-1">
                        @if ($zapis->Kategorija === 'Aktivnosti')
                            @if ($zapis->StatusAktivnosti === \App\Models\DnevnaAktivnost::U_TOKU)
                                <span class="badge text-bg-warning">U toku</span>
                            @elseif ($zapis->VremeDo)
                                Do {{ $zapis->VremeDo->format('H:i') }}@if ($zapis->DuzinaTrajanja) ({{ $zapis->DuzinaTrajanja }})@endif
                            @endif
                            @if ($zapis->Ocena) · ocena {{ $zapis->Ocena }}/5 @endif
                            @if ($zapis->ProcenaPonasanja) · {{ $zapis->ProcenaPonasanja }} @endif
                        @elseif ($zapis->Kategorija === 'Hrana')
                            {{ $zapis->VremeObroka }}@if ($zapis->Kolicina) · {{ $zapis->Kolicina }}@endif
                        @else
                            {{ $zapis->StatusOstalo }}
                        @endif
                    </div>
                    @if ($zapis->Komentar)
                        <div class="text-sitno fst-italic mt-1">„{{ $zapis->Komentar }}”</div>
                    @endif
                </div>
            @empty
                <p class="text-muted mb-0">Nema zapisa{{ $kategorija ? ' u ovoj kategoriji' : '' }}.</p>
            @endforelse

            <div class="mt-3">{{ $dnevnik->links() }}</div>
        </div>
    </div>
</div>
@endsection
