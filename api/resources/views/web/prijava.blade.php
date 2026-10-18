@extends('web.layout')

@section('naslov', 'Prijava')

@section('sadrzaj')
<div class="row justify-content-center">
    <div class="col-sm-9 col-md-6 col-lg-4">
        <div class="card kartica p-4">
            <h1 class="h4 mb-1">Prijava</h1>
            <p class="text-muted text-sitno mb-4">Isti nalog kao u aplikaciji pansiona.</p>

            <form method="post" action="{{ route('prijava') }}" novalidate>
                @csrf
                <div class="mb-3">
                    <label for="korisnicko_ime" class="form-label">Korisničko ime ili email</label>
                    <input id="korisnicko_ime" name="korisnicko_ime" value="{{ old('korisnicko_ime') }}"
                           class="form-control @error('korisnicko_ime') is-invalid @enderror"
                           autocomplete="username" autofocus required>
                    @error('korisnicko_ime')<div class="invalid-feedback">{{ $message }}</div>@enderror
                </div>
                <div class="mb-4">
                    <label for="lozinka" class="form-label">Lozinka</label>
                    <input id="lozinka" name="lozinka" type="password"
                           class="form-control @error('lozinka') is-invalid @enderror"
                           autocomplete="current-password" required>
                    @error('lozinka')<div class="invalid-feedback">{{ $message }}</div>@enderror
                </div>
                <button class="btn btn-pk w-100">Prijavi se</button>
            </form>
        </div>
    </div>
</div>
@endsection
