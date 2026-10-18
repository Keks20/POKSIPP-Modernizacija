<?php

use App\Http\Controllers\Web\LjubimciController;
use App\Http\Controllers\Web\PrijavaController;
use Illuminate\Support\Facades\Route;

/*
| Web stranica za vlasnike ljubimaca (Faza 4). Ista baza i ista pravila kao
| Delphi aplikacija i API: vlasnik vidi samo svoje ljubimce.
*/

Route::redirect('/', '/moji-ljubimci');

Route::middleware('guest:vlasnik')->group(function () {
    Route::get('/prijava', [PrijavaController::class, 'forma'])->name('prijava');
    Route::post('/prijava', [PrijavaController::class, 'prijava'])->middleware('throttle:10,1');
});

Route::middleware('auth:vlasnik')->group(function () {
    Route::post('/odjava', [PrijavaController::class, 'odjava'])->name('odjava');

    Route::get('/moji-ljubimci', [LjubimciController::class, 'index'])->name('ljubimci.index');
    Route::get('/moji-ljubimci/{id}', [LjubimciController::class, 'show'])->whereNumber('id')->name('ljubimci.show');
    Route::get('/moji-ljubimci/{id}/slika', [LjubimciController::class, 'slika'])->whereNumber('id')->name('ljubimci.slika');
    Route::post('/moji-ljubimci/{id}/slika', [LjubimciController::class, 'postaviSliku'])->whereNumber('id')->name('ljubimci.postavi-sliku');
});
