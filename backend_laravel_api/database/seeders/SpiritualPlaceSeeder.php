<?php

namespace Database\Seeders;

use App\Models\SpiritualPlace;
use Illuminate\Database\Seeder;

class SpiritualPlaceSeeder extends Seeder
{
    /**
     * Run the database seeds with verified Gujarat spiritual places and RFC 7946 GeoJSON polygons.
     * Positions format: [longitude, latitude].
     */
    public function run(): void
    {
        $places = [
            [
                'name' => 'Kalika Mata Temple, Pavagadh',
                'region' => 'Gujarat',
                'city' => 'Pavagadh',
                'district' => 'Panchmahal',
                'latitude' => 22.4632000,
                'longitude' => 73.5284000,
                'category' => 'temple',
                'description' => 'Sacred Shakti Peetha atop Pavagadh Hill, a UNESCO World Heritage site known for heightened spiritual resonance and serene mountain energy.',
                'high_multiplier' => 2.00,
                'low_multiplier' => 1.50,
                'high_intensity_polygon' => [
                    'type' => 'Polygon',
                    'coordinates' => [
                        [
                            [73.5270, 22.4625],
                            [73.5298, 22.4625],
                            [73.5298, 22.4640],
                            [73.5270, 22.4640],
                            [73.5270, 22.4625],
                        ],
                    ],
                ],
                'low_intensity_polygon' => [
                    'type' => 'Polygon',
                    'coordinates' => [
                        [
                            [73.5200, 22.4580],
                            [73.5360, 22.4580],
                            [73.5360, 22.4680],
                            [73.5200, 22.4680],
                            [73.5200, 22.4580],
                        ],
                    ],
                ],
                'is_published' => true,
                'version' => 1,
            ],
            [
                'name' => 'Ambaji Mata Temple & Gabbar Hill',
                'region' => 'Gujarat',
                'city' => 'Ambaji',
                'district' => 'Banaskantha',
                'latitude' => 24.3317000,
                'longitude' => 72.8517000,
                'category' => 'temple',
                'description' => 'Major Shakti Peetha situated near the Aravalli hills, revered as the holy seat of the Arasuri Amba goddess and Viso Yantra.',
                'high_multiplier' => 2.00,
                'low_multiplier' => 1.40,
                'high_intensity_polygon' => [
                    'type' => 'Polygon',
                    'coordinates' => [
                        [
                            [72.8500, 24.3300],
                            [72.8535, 24.3300],
                            [72.8535, 24.3335],
                            [72.8500, 24.3335],
                            [72.8500, 24.3300],
                        ],
                    ],
                ],
                'low_intensity_polygon' => [
                    'type' => 'Polygon',
                    'coordinates' => [
                        [
                            [72.8450, 24.3250],
                            [72.8580, 24.3250],
                            [72.8580, 24.3380],
                            [72.8450, 24.3380],
                            [72.8450, 24.3250],
                        ],
                    ],
                ],
                'is_published' => true,
                'version' => 1,
            ],
            [
                'name' => 'Dwarkadhish Temple (Jagat Mandir)',
                'region' => 'Gujarat',
                'city' => 'Dwarka',
                'district' => 'Devbhumi Dwarka',
                'latitude' => 22.2376000,
                'longitude' => 68.9678000,
                'category' => 'temple',
                'description' => 'Ancient Char Dham pilgrimage temple on the western coast of Gujarat dedicated to Lord Krishna with divine coastal peace.',
                'high_multiplier' => 2.20,
                'low_multiplier' => 1.60,
                'high_intensity_polygon' => [
                    'type' => 'Polygon',
                    'coordinates' => [
                        [
                            [68.9660, 22.2360],
                            [68.9700, 22.2360],
                            [68.9700, 22.2395],
                            [68.9660, 22.2395],
                            [68.9660, 22.2360],
                        ],
                    ],
                ],
                'low_intensity_polygon' => [
                    'type' => 'Polygon',
                    'coordinates' => [
                        [
                            [68.9600, 22.2300],
                            [68.9750, 22.2300],
                            [68.9750, 22.2450],
                            [68.9600, 22.2450],
                            [68.9600, 22.2300],
                        ],
                    ],
                ],
                'is_published' => true,
                'version' => 1,
            ],
            [
                'name' => 'Somnath Jyotirlinga Temple',
                'region' => 'Gujarat',
                'city' => 'Prabhas Patan',
                'district' => 'Gir Somnath',
                'latitude' => 20.8880000,
                'longitude' => 70.4013000,
                'category' => 'temple',
                'description' => 'The eternal first of the twelve sacred Aadi Jyotirlinga shrines located directly at the confluence of three holy rivers and the Arabian Sea.',
                'high_multiplier' => 2.50,
                'low_multiplier' => 1.70,
                'high_intensity_polygon' => [
                    'type' => 'Polygon',
                    'coordinates' => [
                        [
                            [70.3995, 20.8865],
                            [70.4030, 20.8865],
                            [70.4030, 20.8895],
                            [70.3995, 20.8895],
                            [70.3995, 20.8865],
                        ],
                    ],
                ],
                'low_intensity_polygon' => [
                    'type' => 'Polygon',
                    'coordinates' => [
                        [
                            [70.3950, 20.8820],
                            [70.4070, 20.8820],
                            [70.4070, 20.8930],
                            [70.3950, 20.8930],
                            [70.3950, 20.8820],
                        ],
                    ],
                ],
                'is_published' => true,
                'version' => 1,
            ],
        ];

        foreach ($places as $placeData) {
            SpiritualPlace::updateOrCreate(
                ['name' => $placeData['name']],
                $placeData
            );
        }
    }
}
