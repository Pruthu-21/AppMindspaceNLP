<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SpiritualPlace extends Model
{
    use HasFactory;

    protected $table = 'spiritual_places';

    protected $fillable = [
        'name',
        'region',
        'city',
        'district',
        'latitude',
        'longitude',
        'category',
        'description',
        'high_multiplier',
        'low_multiplier',
        'high_intensity_polygon',
        'low_intensity_polygon',
        'is_published',
        'version',
    ];

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'latitude' => 'float',
        'longitude' => 'float',
        'high_multiplier' => 'float',
        'low_multiplier' => 'float',
        'high_intensity_polygon' => 'array',
        'low_intensity_polygon' => 'array',
        'is_published' => 'boolean',
        'version' => 'integer',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    /**
     * Scope a query to only include published spiritual places.
     */
    public function scopePublished($query)
    {
        return $query->where('is_published', true);
    }
}
