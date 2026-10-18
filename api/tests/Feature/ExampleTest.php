<?php

namespace Tests\Feature;

use Tests\TestCase;

class ExampleTest extends TestCase
{
    public function test_pocetna_vodi_na_prijavu(): void
    {
        $this->get('/')->assertRedirect('/moji-ljubimci');
        $this->get('/moji-ljubimci')->assertRedirect('/prijava');
        $this->get('/prijava')->assertOk()->assertSee('Prijava');
    }
}
