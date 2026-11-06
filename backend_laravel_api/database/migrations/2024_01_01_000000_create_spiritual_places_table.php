<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('spiritual_places', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('region')->default('Gujarat');
            $table->string('city');
            $table->string('district');
            $table->decimal('latitude', 10, 7);
            $table->decimal('longitude', 10, 7);
            $table->string('category')->default('temple');
            $table->text('description')->nullable();
            
            // Configurable multipliers for meditation / energy visualization
            $table->decimal('high_multiplier', 4, 2)->default(2.00);
            $table->decimal('low_multiplier', 4, 2)->default(1.50);
            
            // Exact RFC 7946 GeoJSON Polygons (Coordinates: [longitude, latitude])
            $table->json('high_intensity_polygon')->nullable();
            $table->json('low_intensity_polygon')->nullable();
            
            // Publishing and synchronization flags
            $table->boolean('is_published')->default(true)->index();
            $table->unsignedInteger('version')->default(1);
            
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('spiritual_places');
    }
};
