<!doctype html>
<html lang="sr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>@yield('naslov', 'Moji ljubimci') · POKSIPP</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet"
          integrity="sha384-QWTKZyjpPEjISv5WaRU9OFeRpok6YctnYmDr5pNlyT2bRjXh0JMhjY6hW+ALEwIH" crossorigin="anonymous">
    <style>
        :root {
            --pk-zelena: #1f6f5c;
            --pk-zelena-tamna: #17594a;
            --pk-krem: #f6f3ec;
            --pk-tekst: #2b2a27;
        }
        body { background: var(--pk-krem); color: var(--pk-tekst); }
        .navbar { background: var(--pk-zelena); }
        .navbar-brand small { opacity: .75; font-weight: 400; }
        .btn-pk { background: var(--pk-zelena); border-color: var(--pk-zelena); color: #fff; }
        .btn-pk:hover, .btn-pk:focus { background: var(--pk-zelena-tamna); border-color: var(--pk-zelena-tamna); color: #fff; }
        a { color: var(--pk-zelena); }
        .nav-pills .nav-link { color: var(--pk-zelena); }
        .nav-pills .nav-link.active { background: var(--pk-zelena); }
        .page-link { color: var(--pk-zelena); }
        .active > .page-link, .page-link.active { background: var(--pk-zelena); border-color: var(--pk-zelena); }
        .form-control:focus { border-color: #7fb3a6; box-shadow: 0 0 0 .2rem rgba(31,111,92,.2); }
        .kartica { border: 0; border-radius: 14px; box-shadow: 0 1px 3px rgba(0,0,0,.08); }
        .slika-ljubimca { aspect-ratio: 4 / 3; object-fit: cover; width: 100%; border-radius: 14px 14px 0 0; background: #e7e2d6; }
        .slika-velika { aspect-ratio: 4 / 3; object-fit: cover; width: 100%; border-radius: 14px; background: #e7e2d6; }
        .bez-slike { aspect-ratio: 4 / 3; display: flex; align-items: center; justify-content: center;
                     font-size: 3rem; font-weight: 600; color: #a39c8b; background: #e7e2d6; }
        .zapis + .zapis { border-top: 1px solid #ece7dc; }
        .text-sitno { font-size: .875rem; }
    </style>
</head>
<body>
<nav class="navbar navbar-dark mb-4">
    <div class="container">
        <a class="navbar-brand fw-semibold" href="{{ route('ljubimci.index') }}">
            POKSIPP <small>· pansion za ljubimce</small>
        </a>
        @auth('vlasnik')
            <div class="d-flex align-items-center gap-3">
                <span class="text-white text-sitno d-none d-sm-inline">
                    {{ auth('vlasnik')->user()->Ime }} {{ auth('vlasnik')->user()->Prezime }}
                </span>
                <form method="post" action="{{ route('odjava') }}">
                    @csrf
                    <button class="btn btn-sm btn-outline-light">Odjava</button>
                </form>
            </div>
        @endauth
    </div>
</nav>

<main class="container pb-5">
    @if (session('poruka'))
        <div class="alert alert-success">{{ session('poruka') }}</div>
    @endif

    @yield('sadrzaj')
</main>
</body>
</html>
