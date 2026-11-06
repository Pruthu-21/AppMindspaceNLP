<?php

use App\Http\Controllers\Api\SpiritualPlaceController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| MindSpaceNLP Spiritual Places API Routes
|--------------------------------------------------------------------------
|
| Paste or include this route definition in your routes/api.php file.
| E.g.: require __DIR__ . '/api_spiritual_places.php';
| Or directly copy these routes into routes/api.php.
|
*/

// Public endpoint consumed by MindSpaceNLP Flutter Mobile App
Route::get('/spiritual-places', [SpiritualPlaceController::class, 'index']);
Route::get('/spiritual-places/{id}', [SpiritualPlaceController::class, 'show']);

// Admin endpoints for website web management / dashboard
// If using authentication (Laravel Sanctum / Passport), keep under auth middleware:
Route::prefix('admin')->middleware(['auth:sanctum'])->group(function () {
    Route::post('/spiritual-places', [SpiritualPlaceController::class, 'store']);
    Route::put('/spiritual-places/{id}', [SpiritualPlaceController::class, 'update']);
    Route::delete('/spiritual-places/{id}', [SpiritualPlaceController::class, 'destroy']);
});

// Or if public admin testing is needed temporarily without Sanctum token:
Route::prefix('admin/public')->group(function () {
    Route::post('/spiritual-places', [SpiritualPlaceController::class, 'store']);
    Route::put('/spiritual-places/{id}', [SpiritualPlaceController::class, 'update']);
    Route::delete('/spiritual-places/{id}', [SpiritualPlaceController::class, 'destroy']);
});
