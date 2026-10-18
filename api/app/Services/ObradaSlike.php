<?php

namespace App\Services;

use App\Models\Ljubimac;
use Illuminate\Http\Response;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use PDO;

/**
 * Slika ljubimca koju postavlja vlasnik (web) ili admin (API).
 *
 * Slika se ne cuva onakva kakva je stigla, vec se ponovo kodira:
 *  - orijentacija sa telefona se ispravi (EXIF), pa slika nije polegla;
 *  - smanji se na najvise 800 px po duzoj strani (telefon: ~4 MB -> ~100 KB);
 *  - snimi se kao JPEG bez metapodataka, pa nestaju i GPS koordinate;
 *  - fajl koji se samo predstavlja kao slika ne prolazi (GD mora da ga otvori).
 *
 * Mala slika je vazna i zbog MySQL-a: XAMPP podrazumevano ne prima upit
 * veci od 1 MB (max_allowed_packet), a Delphi cita sve slike u listi.
 */
class ObradaSlike
{
    public const MAKS_STRANICA = 800;

    public const KVALITET = 82;

    /** Pravila validacije, zajednicka za API i web. Velicina u KB. */
    public static function pravila(): array
    {
        return [
            'slika' => [
                'required', 'file', 'image', 'mimes:jpeg,png,webp', 'max:5120',
                // Zastita od "bombe": mali fajl sa ogromnim dimenzijama koji pojede memoriju.
                // 6000 x 6000 = 36 MP, oko 150 MB u memoriji (php.ini: memory_limit = 256M).
                'dimensions:max_width=6000,max_height=6000',
            ],
        ];
    }

    public static function poruke(): array
    {
        return [
            'slika.required' => 'Izaberite sliku.',
            'slika.file' => 'Slika nije poslata kako treba.',
            'slika.image' => 'Fajl mora biti slika (JPEG, PNG ili WebP).',
            'slika.mimes' => 'Dozvoljeni su samo JPEG, PNG i WebP.',
            'slika.max' => 'Slika može imati najviše 5 MB.',
            'slika.dimensions' => 'Slika je prevelika (najviše 6000 × 6000 piksela).',
            'slika.uploaded' => 'Slika nije otpremljena (verovatno je veca od dozvoljenog).',
        ];
    }

    /** Vraca JPEG bajtove spremne za upis u bazu. */
    public function uJpeg(UploadedFile $fajl): string
    {
        $putanja = $fajl->getRealPath();
        $original = @imagecreatefromstring((string) file_get_contents($putanja));
        if ($original === false) {
            throw ValidationException::withMessages(['slika' => 'Fajl nije ispravna slika.']);
        }

        $original = $this->ispraviOrijentaciju($original, $putanja);

        $sirina = imagesx($original);
        $visina = imagesy($original);
        $faktor = min(1, self::MAKS_STRANICA / max($sirina, $visina));
        $novaSirina = max(1, (int) round($sirina * $faktor));
        $novaVisina = max(1, (int) round($visina * $faktor));

        // Bela pozadina: providni delovi PNG-a inace postaju crni u JPEG-u
        $platno = imagecreatetruecolor($novaSirina, $novaVisina);
        imagefill($platno, 0, 0, imagecolorallocate($platno, 255, 255, 255));
        imagecopyresampled($platno, $original, 0, 0, 0, 0, $novaSirina, $novaVisina, $sirina, $visina);

        ob_start();
        imagejpeg($platno, null, self::KVALITET);
        $jpeg = (string) ob_get_clean();

        imagedestroy($original);
        imagedestroy($platno);

        return $jpeg;
    }

    /** Upisuje sliku kao binarni podatak (PARAM_LOB, bez pretvaranja kodnog rasporeda). */
    public function sacuvaj(Ljubimac $ljubimac, string $jpeg): void
    {
        $upit = DB::connection()->getPdo()->prepare('UPDATE pets SET image_blob = ? WHERE id = ?');
        $upit->bindValue(1, $jpeg, PDO::PARAM_LOB);
        $upit->bindValue(2, $ljubimac->id, PDO::PARAM_INT);
        $upit->execute();
    }

    /**
     * Slika kao HTTP odgovor (API i web koriste isti). Stare slike iz Delphija
     * mogu biti PNG, pa se tip odredjuje iz sadrzaja.
     */
    public function odgovor(Ljubimac $ljubimac): Response
    {
        $slika = Ljubimac::whereKey($ljubimac->id)->value('image_blob');
        abort_if($slika === null || $slika === '', 404, 'Ljubimac nema sliku.');

        $tip = (new \finfo(FILEINFO_MIME_TYPE))->buffer($slika) ?: 'application/octet-stream';

        return response($slika, 200, [
            'Content-Type' => $tip,
            // Slika se menja, pa browser mora da proveri da li ima novu
            'Cache-Control' => 'private, no-cache',
        ]);
    }

    /** Telefon cuva sliku "polegnutu" i u EXIF upise kako je treba okrenuti. */
    private function ispraviOrijentaciju(\GdImage $slika, string $putanja): \GdImage
    {
        if (! function_exists('exif_read_data')) {
            return $slika;
        }

        $exif = @exif_read_data($putanja);
        $ugao = match ((int) ($exif['Orientation'] ?? 1)) {
            3 => 180,
            6 => 270,   // imagerotate okrece suprotno od kazaljke: 270 = 90 u smeru kazaljke
            8 => 90,
            default => 0,
        };

        if ($ugao === 0) {
            return $slika;
        }

        $okrenuta = imagerotate($slika, $ugao, 0);
        if ($okrenuta === false) {
            return $slika;
        }
        imagedestroy($slika);

        return $okrenuta;
    }
}
