<?php

namespace App\Providers;

use App\Models\Musterija;
use App\Models\Zaposleni;
use Illuminate\Database\Eloquent\Relations\Relation;
use Illuminate\Pagination\Paginator;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // U tabeli personal_access_tokens piše 'zaposleni' ili 'musterija'
        // umesto punog imena PHP klase (App\\Models\\...).
        // Stranice dnevnika na web stranici koriste Bootstrap
        Paginator::useBootstrapFive();

        Relation::enforceMorphMap([
            'zaposleni' => Zaposleni::class,
            'musterija' => Musterija::class,
        ]);
    }
}
