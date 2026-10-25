<?php

namespace App\Http\Requests\Api\V1;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;

class UpdateCollectionRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'required', 'string', 'max:100'],
            'icon' => ['sometimes', 'nullable', 'string', 'max:50'],
            'color' => ['sometimes', 'nullable', 'string', 'max:20'],
            'is_public' => ['sometimes', 'required', 'boolean'],
            'sort_order' => ['sometimes', 'integer'],
        ];
    }
}
