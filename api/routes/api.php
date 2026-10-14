<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\LjubimacController;
use App\Http\Controllers\Api\SifarnikController;
use Illuminate\Support\Facades\Route;

/*
| POKSIPP API. Sve rute počinju sa /api.
|
| Uloge (middleware 'uloga'):
|   admin      - Uloga 'Admin' u tabeli ZAPOSLENI
|   zaposleni  - ostali zaposleni (Negovatelj, Osoblje...)
|   musterija  - vlasnik ljubimca (tabela MUSTERIJA)
*/

// Javno, sa ograničenjem: najviše 10 pokušaja u minuti sa jedne adrese
Route::middleware('throttle:10,1')->group(function () {
    Route::post('/prijava', [AuthController::class, 'prijava']);
    Route::post('/registracija', [AuthController::class, 'registracija']);
});

// Svi prijavljeni (uloga se proverava i ovde: deaktiviran zaposleni ne prolazi)
Route::middleware(['auth:sanctum', 'uloga'])->group(function () {
    Route::get('/ja', [AuthController::class, 'ja']);
    Route::post('/odjava', [AuthController::class, 'odjava']);

    Route::get('/usluge', [SifarnikController::class, 'usluge']);

    // Vlasnik dobija samo svoje ljubimce; tuđi ljubimac = 404
    Route::get('/ljubimci', [LjubimacController::class, 'index']);
    Route::get('/ljubimci/{id}', [LjubimacController::class, 'show'])->whereNumber('id');
    Route::get('/ljubimci/{id}/dnevnik', [LjubimacController::class, 'dnevnik'])->whereNumber('id');
    Route::get('/ljubimci/{id}/racun', [LjubimacController::class, 'racun'])->whereNumber('id');
    Route::get('/ljubimci/{id}/slika', [LjubimacController::class, 'slika'])->whereNumber('id');
});

// Osoblje (admin i zaposleni)
Route::middleware(['auth:sanctum', 'uloga:admin,zaposleni'])->group(function () {
    Route::get('/resursi', [SifarnikController::class, 'resursi']);
    Route::get('/musterije', [SifarnikController::class, 'musterije']);
});

// Samo admin
Route::middleware(['auth:sanctum', 'uloga:admin'])->group(function () {
    Route::get('/zaposleni', [SifarnikController::class, 'zaposleni']);

    Route::post('/ljubimci', [LjubimacController::class, 'store']);
    Route::put('/ljubimci/{id}', [LjubimacController::class, 'update'])->whereNumber('id');
    Route::post('/ljubimci/{id}/odjava', [LjubimacController::class, 'odjava'])->whereNumber('id');
});
