@if ($ljubimac->Status === \App\Models\Ljubimac::ODJAVLJEN)
    <span class="badge text-bg-secondary">Odjavljen</span>
@else
    <span class="badge text-bg-success">{{ $ljubimac->Lokacija !== '' ? $ljubimac->Lokacija : 'U pansionu' }}</span>
@endif
