# MindSpaceNLP — Spiritual Places Laravel API Deployment Guide

This package provides the complete, production-ready Laravel API for the **Spiritual Places & Dynamic Polygon Geofencing** feature used by the MindSpaceNLP mobile app.

---

## 📁 Package Files & Destination Paths

| File in this folder | Target Path in your Laravel Project |
| :--- | :--- |
| `database/migrations/2024_01_01_000000_create_spiritual_places_table.php` | `database/migrations/2024_01_01_000000_create_spiritual_places_table.php` |
| `app/Models/SpiritualPlace.php` | `app/Models/SpiritualPlace.php` |
| `app/Http/Controllers/Api/SpiritualPlaceController.php` | `app/Http/Controllers/Api/SpiritualPlaceController.php` |
| `database/seeders/SpiritualPlaceSeeder.php` | `database/seeders/SpiritualPlaceSeeder.php` |
| `routes/api_spiritual_places.php` | Include into `routes/api.php` |
| `spiritual_places_dump.sql` | Direct MySQL/phpMyAdmin import (optional alternative to artisan) |

---

## 🚀 Quick Deployment (3 Steps)

### Step 1: Copy Files to Your Laravel Application
Copy the files from `backend_laravel_api/` into your Laravel root directory:
```bash
cp backend_laravel_api/app/Models/SpiritualPlace.php <your-laravel-root>/app/Models/
cp backend_laravel_api/app/Http/Controllers/Api/SpiritualPlaceController.php <your-laravel-root>/app/Http/Controllers/Api/
cp backend_laravel_api/database/migrations/* <your-laravel-root>/database/migrations/
cp backend_laravel_api/database/seeders/* <your-laravel-root>/database/seeders/
```

### Step 2: Add Routes to `routes/api.php`
Open your `routes/api.php` and add:

```php
use App\Http\Controllers\Api\SpiritualPlaceController;

// Public endpoint consumed by MindSpaceNLP Flutter app
Route::get('/spiritual-places', [SpiritualPlaceController::class, 'index']);
Route::get('/spiritual-places/{id}', [SpiritualPlaceController::class, 'show']);

// Admin management endpoints
Route::prefix('admin')->middleware(['auth:sanctum'])->group(function () {
    Route::post('/spiritual-places', [SpiritualPlaceController::class, 'store']);
    Route::put('/spiritual-places/{id}', [SpiritualPlaceController::class, 'update']);
    Route::delete('/spiritual-places/{id}', [SpiritualPlaceController::class, 'destroy']);
});
```

### Step 3: Run Migrations and Seeders

#### Option A: Via Artisan (Standard Laravel)
```bash
php artisan migrate
php artisan db:seed --class=SpiritualPlaceSeeder
```

#### Option B: Via Direct SQL Import (cPanel / phpMyAdmin)
If your production server uses phpMyAdmin or direct MySQL without terminal access:
1. Open phpMyAdmin or MySQL client.
2. Select your application database.
3. Import `spiritual_places_dump.sql`.

---

## 🔍 Verification

Test your endpoint:
```bash
curl -X GET https://mindspacenlp.com/api/spiritual-places
```

**Expected JSON Response:**
```json
{
  "status": true,
  "message": "Spiritual places retrieved successfully",
  "count": 4,
  "data": [
    {
      "id": "1",
      "name": "Kalika Mata Temple, Pavagadh",
      "region": "Gujarat",
      "city": "Pavagadh",
      "district": "Panchmahal",
      "latitude": 22.4632,
      "longitude": 73.5284,
      "category": "temple",
      "description": "Sacred Shakti Peetha atop Pavagadh Hill...",
      "high_multiplier": 2.0,
      "low_multiplier": 1.5,
      "high_intensity_polygon": {
        "type": "Polygon",
        "coordinates": [
          [
            [73.5270, 22.4625],
            [73.5298, 22.4625],
            [73.5298, 22.4640],
            [73.5270, 22.4640],
            [73.5270, 22.4625]
          ]
        ]
      },
      "low_intensity_polygon": {
        "type": "Polygon",
        "coordinates": [
          [
            [73.5200, 22.4580],
            [73.5360, 22.4580],
            [73.5360, 22.4680],
            [73.5200, 22.4680],
            [73.5200, 22.4580]
          ]
        ]
      },
      "is_published": true,
      "version": 1,
      "updated_at": "2026-10-11T11:20:00.000000Z"
    }
  ]
}
```

---

## 🌐 Dynamic Geofencing Polygon Rules (RFC 7946)

When creating or editing polygon boundaries on the website admin dashboard:
1. **Coordinate Format**: Coordinates MUST follow RFC 7946 format: `[longitude, latitude]`. (e.g. `[73.5270, 22.4625]`).
2. **Closed Ring**: The first position and the last position in each coordinate array must be identical to close the boundary polygon.
3. **Inner vs Outer Zone**:
   - `high_intensity_polygon`: Defines the core inner sanctum / peak zone.
   - `low_intensity_polygon`: Defines the surrounding sacred hill / perimeter zone.
4. **Publishing**: Set `is_published = 1` for a place to appear in mobile apps.
5. **Versioning**: Updating a place via `SpiritualPlaceController::update` automatically increments the `version` number, alerting mobile clients to refresh cached polygons during periodic or pull-to-refresh sync.
