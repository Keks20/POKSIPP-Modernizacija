@extends('web.layout')

@section('naslov', 'Moji ljubimci')

@section('sadrzaj')
<h1 class="h3 mb-4">Moji ljubimci</h1>

@if ($ljubimci->isEmpty())
    <div class="card kartica p-4 text-center text-muted">
        Još nemate ljubimce u pansionu. Kad ih primimo, pojaviće se ovde.
    </div>
@else
    <div class="row g-4">
        @foreach ($ljubimci as $ljubimac)
            <div class="col-sm-6 col-lg-4">
                <a href="{{ route('ljubimci.show', $ljubimac->id) }}" class="text-reset text-decoration-none">
                    <div class="card kartica h-100">
                        @if ($ljubimac->ima_sliku)
                            <img src="{{ route('ljubimci.slika', $ljubimac->id) }}" alt="{{ $ljubimac->name }}" class="slika-ljubimca">
                        @else
                            <div class="bez-slike rounded-top">{{ mb_strtoupper(mb_substr($ljubimac->name, 0, 1)) }}</div>
                        @endif
                        <div class="card-body">
                            <div class="d-flex justify-content-between align-items-start">
                                <h2 class="h5 mb-1">{{ $ljubimac->name }}</h2>
                                @include('web.ljubimci.status', ['ljubimac' => $ljubimac])
                            </div>
                            <div class="text-muted text-sitno">
                                {{ $ljubimac->species }}@if ($ljubimac->breed) · {{ $ljubimac->breed }}@endif
                            </div>
                            @if ($ljubimac->DatumPrijema)
                                <div class="text-muted text-sitno mt-2">Primljen {{ $ljubimac->DatumPrijema->format('d.m.Y.') }}</div>
                            @endif
                        </div>
                    </div>
                </a>
            </div>
        @endforeach
    </div>
@endif
@endsection
