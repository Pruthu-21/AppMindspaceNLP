<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SpiritualPlace;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class SpiritualPlaceController extends Controller
{
    /**
     * Display a listing of published spiritual places for the mobile app.
     *
     * GET /api/spiritual-places
     */
    public function index(Request $request)
    {
        $query = SpiritualPlace::query();

        // Default: mobile app consumes only published places
        if (!$request->boolean('include_unpublished', false)) {
            $query->published();
        }

        // Optional filter by region or category
        if ($request->filled('region')) {
            $query->where('region', $request->input('region'));
        }

        if ($request->filled('category')) {
            $query->where('category', $request->input('category'));
        }

        $places = $query->orderBy('name', 'asc')->get();

        return response()->json([
            'status' => true,
            'message' => 'Spiritual places retrieved successfully',
            'count' => $places->count(),
            'data' => $places->map(fn($place) => $this->transformPlace($place)),
        ], 200);
    }

    /**
     * Display a specific spiritual place by ID.
     *
     * GET /api/spiritual-places/{id}
     */
    public function show($id)
    {
        $place = SpiritualPlace::find($id);

        if (!$place) {
            return response()->json([
                'status' => false,
                'message' => 'Spiritual place not found',
            ], 404);
        }

        return response()->json([
            'status' => true,
            'message' => 'Spiritual place details retrieved successfully',
            'data' => $this->transformPlace($place),
        ], 200);
    }

    /**
     * Store a newly created spiritual place (Admin / Web Portal).
     *
     * POST /api/admin/spiritual-places
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'region' => 'nullable|string|max:100',
            'city' => 'required|string|max:100',
            'district' => 'required|string|max:100',
            'latitude' => 'required|numeric|between:-90,90',
            'longitude' => 'required|numeric|between:-180,180',
            'category' => 'nullable|string|max:50',
            'description' => 'nullable|string',
            'high_multiplier' => 'nullable|numeric|min:1.0|max:10.0',
            'low_multiplier' => 'nullable|numeric|min:1.0|max:10.0',
            'high_intensity_polygon' => 'nullable',
            'low_intensity_polygon' => 'nullable',
            'is_published' => 'nullable|boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => 'Validation error',
                'errors' => $validator->errors(),
            ], 422);
        }

        $data = $validator->validated();
        $data['version'] = 1;
        $data['region'] = $data['region'] ?? 'Gujarat';
        $data['category'] = $data['category'] ?? 'temple';
        $data['high_multiplier'] = $data['high_multiplier'] ?? 2.0;
        $data['low_multiplier'] = $data['low_multiplier'] ?? 1.5;
        $data['is_published'] = $request->boolean('is_published', true);

        // Normalize polygon input if submitted as stringified JSON
        if (isset($data['high_intensity_polygon']) && is_string($data['high_intensity_polygon'])) {
            $data['high_intensity_polygon'] = json_decode($data['high_intensity_polygon'], true);
        }
        if (isset($data['low_intensity_polygon']) && is_string($data['low_intensity_polygon'])) {
            $data['low_intensity_polygon'] = json_decode($data['low_intensity_polygon'], true);
        }

        $place = SpiritualPlace::create($data);

        return response()->json([
            'status' => true,
            'message' => 'Spiritual place created successfully',
            'data' => $this->transformPlace($place),
        ], 201);
    }

    /**
     * Update an existing spiritual place (Admin / Web Portal).
     *
     * PUT /api/admin/spiritual-places/{id}
     */
    public function update(Request $request, $id)
    {
        $place = SpiritualPlace::find($id);

        if (!$place) {
            return response()->json([
                'status' => false,
                'message' => 'Spiritual place not found',
            ], 404);
        }

        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|required|string|max:255',
            'region' => 'nullable|string|max:100',
            'city' => 'sometimes|required|string|max:100',
            'district' => 'sometimes|required|string|max:100',
            'latitude' => 'sometimes|required|numeric|between:-90,90',
            'longitude' => 'sometimes|required|numeric|between:-180,180',
            'category' => 'nullable|string|max:50',
            'description' => 'nullable|string',
            'high_multiplier' => 'nullable|numeric|min:1.0|max:10.0',
            'low_multiplier' => 'nullable|numeric|min:1.0|max:10.0',
            'high_intensity_polygon' => 'nullable',
            'low_intensity_polygon' => 'nullable',
            'is_published' => 'nullable|boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => 'Validation error',
                'errors' => $validator->errors(),
            ], 422);
        }

        $data = $validator->validated();

        if (array_key_exists('high_intensity_polygon', $data) && is_string($data['high_intensity_polygon'])) {
            $data['high_intensity_polygon'] = json_decode($data['high_intensity_polygon'], true);
        }
        if (array_key_exists('low_intensity_polygon', $data) && is_string($data['low_intensity_polygon'])) {
            $data['low_intensity_polygon'] = json_decode($data['low_intensity_polygon'], true);
        }

        // Increment version on update so client knows data changed
        $data['version'] = ($place->version ?? 1) + 1;

        $place->update($data);

        return response()->json([
            'status' => true,
            'message' => 'Spiritual place updated successfully',
            'data' => $this->transformPlace($place),
        ], 200);
    }

    /**
     * Delete or unpublish a spiritual place.
     *
     * DELETE /api/admin/spiritual-places/{id}
     */
    public function destroy($id)
    {
        $place = SpiritualPlace::find($id);

        if (!$place) {
            return response()->json([
                'status' => false,
                'message' => 'Spiritual place not found',
            ], 404);
        }

        $place->delete();

        return response()->json([
            'status' => true,
            'message' => 'Spiritual place removed successfully',
        ], 200);
    }

    /**
     * Transform model into standard API response compatible with Flutter client.
     */
    protected function transformPlace(SpiritualPlace $place): array
    {
        return [
            'id' => (string) $place->id,
            'name' => $place->name,
            'region' => $place->region,
            'city' => $place->city,
            'district' => $place->district,
            'latitude' => (float) $place->latitude,
            'longitude' => (float) $place->longitude,
            'category' => $place->category,
            'description' => $place->description ?? '',
            'high_multiplier' => (float) ($place->high_multiplier ?? 2.0),
            'low_multiplier' => (float) ($place->low_multiplier ?? 1.5),
            'high_intensity_polygon' => $place->high_intensity_polygon,
            'low_intensity_polygon' => $place->low_intensity_polygon,
            'is_published' => (bool) $place->is_published,
            'version' => (int) ($place->version ?? 1),
            'updated_at' => $place->updated_at ? $place->updated_at->toIso8601String() : null,
        ];
    }
}
