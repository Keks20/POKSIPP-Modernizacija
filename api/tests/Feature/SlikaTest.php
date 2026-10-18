<?php

namespace Tests\Feature;

use App\Models\Ljubimac;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Http\UploadedFile;
use Laravel\Sanctum\Sanctum;
use Tests\Support\PoksippPodaci;
use Tests\TestCase;

class SlikaTest extends TestCase
{
    use DatabaseTransactions, PoksippPodaci;

    /** JPEG zadatih dimenzija, po zelji sa EXIF orijentacijom (kao fotografija sa telefona). */
    private function jpeg(int $sirina, int $visina, ?int $orijentacija = null): string
    {
        $slika = imagecreatetruecolor($sirina, $visina);
        imagefill($slika, 0, 0, imagecolorallocate($slika, 200, 60, 60));
        ob_start();
        imagejpeg($slika);
        $bajtovi = (string) ob_get_clean();

        if ($orijentacija === null) {
            return $bajtovi;
        }

        // APP1 Exif: TIFF zaglavlje (big-endian) + jedan IFD unos 0x0112 Orientation
        $tiff = "MM\x00\x2A\x00\x00\x00\x08"
            ."\x00\x01"
            ."\x01\x12\x00\x03\x00\x00\x00\x01".pack('n', $orijentacija)."\x00\x00"
            ."\x00\x00\x00\x00";
        $app1 = "Exif\x00\x00".$tiff;

        return "\xFF\xD8\xFF\xE1".pack('n', strlen($app1) + 2).$app1.substr($bajtovi, 2);
    }

    private function sacuvanaSlika(Ljubimac $ljubimac): string
    {
        return (string) Ljubimac::whereKey($ljubimac->id)->value('image_blob');
    }

    public function test_vlasnik_postavlja_sliku_koja_se_smanjuje_na_800px(): void
    {
        $vlasnik = $this->musterija();
        $reks = $this->ljubimac($vlasnik);
        Sanctum::actingAs($vlasnik);

        $fajl = UploadedFile::fake()->createWithContent('reks.jpg', $this->jpeg(2000, 1500));

        $this->post("/api/ljubimci/{$reks->id}/slika", ['slika' => $fajl], ['Accept' => 'application/json'])
            ->assertOk()
            ->assertJsonPath('poruka', 'Slika je sačuvana.');

        $info = getimagesizefromstring($this->sacuvanaSlika($reks));
        $this->assertSame([800, 600], [$info[0], $info[1]]);
        $this->assertSame('image/jpeg', $info['mime']);

        $this->get("/api/ljubimci/{$reks->id}/slika")
            ->assertOk()
            ->assertHeader('Content-Type', 'image/jpeg');

        $this->getJson("/api/ljubimci/{$reks->id}")->assertJsonPath('data.ima_sliku', true);
    }

    public function test_fotografija_sa_telefona_se_ispravlja_i_gubi_exif(): void
    {
        $vlasnik = $this->musterija();
        $reks = $this->ljubimac($vlasnik);
        Sanctum::actingAs($vlasnik);

        // Polegnuta 40x20 sa oznakom "okreni za 90 stepeni" (Orientation = 6)
        $fajl = UploadedFile::fake()->createWithContent('telefon.jpg', $this->jpeg(40, 20, 6));
        $this->post("/api/ljubimci/{$reks->id}/slika", ['slika' => $fajl], ['Accept' => 'application/json'])
            ->assertOk();

        $sacuvana = $this->sacuvanaSlika($reks);
        $info = getimagesizefromstring($sacuvana);
        $this->assertSame([20, 40], [$info[0], $info[1]]);
        $this->assertStringNotContainsString('Exif', $sacuvana);
    }

    public function test_png_sa_providnoscu_postaje_jpeg(): void
    {
        $vlasnik = $this->musterija();
        $reks = $this->ljubimac($vlasnik);
        Sanctum::actingAs($vlasnik);

        $png = imagecreatetruecolor(30, 30);
        imagesavealpha($png, true);
        imagefill($png, 0, 0, imagecolorallocatealpha($png, 0, 0, 0, 127));
        ob_start();
        imagepng($png);
        $fajl = UploadedFile::fake()->createWithContent('providna.png', (string) ob_get_clean());

        $this->post("/api/ljubimci/{$reks->id}/slika", ['slika' => $fajl], ['Accept' => 'application/json'])
            ->assertOk();

        $slika = imagecreatefromstring($this->sacuvanaSlika($reks));
        $boja = imagecolorsforindex($slika, imagecolorat($slika, 15, 15));
        $this->assertGreaterThan(240, $boja['red']);   // bela pozadina, ne crna
    }

    public function test_tekst_preimenovan_u_jpg_se_odbija(): void
    {
        $vlasnik = $this->musterija();
        $reks = $this->ljubimac($vlasnik);
        Sanctum::actingAs($vlasnik);

        $fajl = UploadedFile::fake()->createWithContent('virus.jpg', '<?php echo "nije slika";');

        $this->post("/api/ljubimci/{$reks->id}/slika", ['slika' => $fajl], ['Accept' => 'application/json'])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['slika']);
        $this->assertSame('', $this->sacuvanaSlika($reks));
    }

    public function test_prevelik_fajl_se_odbija(): void
    {
        $vlasnik = $this->musterija();
        $reks = $this->ljubimac($vlasnik);
        Sanctum::actingAs($vlasnik);

        $fajl = UploadedFile::fake()->image('ogromna.jpg', 100, 100)->size(6000);

        $this->post("/api/ljubimci/{$reks->id}/slika", ['slika' => $fajl], ['Accept' => 'application/json'])
            ->assertStatus(422)
            ->assertJsonPath('errors.slika.0', 'Slika može imati najviše 5 MB.');
    }

    public function test_ko_sme_da_postavi_sliku(): void
    {
        $jovana = $this->musterija('jovana');
        $petar = $this->musterija('petar');
        $reks = $this->ljubimac($jovana);
        $slika = fn () => ['slika' => UploadedFile::fake()->createWithContent('r.jpg', $this->jpeg(50, 50))];
        $h = ['Accept' => 'application/json'];

        // Tudji vlasnik: 404 (ne sme ni da sazna da ljubimac postoji)
        Sanctum::actingAs($petar);
        $this->post("/api/ljubimci/{$reks->id}/slika", $slika(), $h)->assertNotFound();

        // Negovatelj: 403
        Sanctum::actingAs($this->zaposleni());
        $this->post("/api/ljubimci/{$reks->id}/slika", $slika(), $h)->assertForbidden();

        // Admin: moze
        Sanctum::actingAs($this->admin());
        $this->post("/api/ljubimci/{$reks->id}/slika", $slika(), $h)->assertOk();
    }
}
