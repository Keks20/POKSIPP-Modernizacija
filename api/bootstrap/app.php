<?php

use App\Http\Middleware\ProveraUloge;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Symfony\Component\HttpKernel\Exception\HttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'uloga' => ProveraUloge::class,
        ]);

        // Neprijavljen korisnik: API dobija 401 JSON, a web stranica ide na prijavu.
        $middleware->redirectGuestsTo(fn (Request $request) => $request->is('api/*') ? null : route('prijava'));
        // Vec prijavljen vlasnik koji otvori /prijava ide na svoje ljubimce
        $middleware->redirectUsersTo(fn () => route('ljubimci.index'));
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );

        // Greške API-ja na srpskom, u obliku {"poruka": "..."}.
        // (Laravel bi za 404 napisao i ime PHP modela, a to klijentu ne treba.)
        $exceptions->render(function (AuthenticationException $e, Request $request) {
            if ($request->is('api/*')) {
                return response()->json(['poruka' => 'Niste prijavljeni.'], 401);
            }
        });
        $exceptions->render(function (NotFoundHttpException $e, Request $request) {
            if ($request->is('api/*')) {
                $poruka = $e->getPrevious() === null && $e->getMessage() !== '' && ! str_starts_with($e->getMessage(), 'The route')
                    ? $e->getMessage()
                    : 'Nije pronađeno.';

                return response()->json(['poruka' => $poruka], 404);
            }
        });
        $exceptions->render(function (HttpException $e, Request $request) {
            if ($request->is('api/*') && $e->getStatusCode() === 429) {
                return response()->json(['poruka' => 'Previše pokušaja. Sačekajte minut pa probajte ponovo.'], 429);
            }
        });
    })->create();
