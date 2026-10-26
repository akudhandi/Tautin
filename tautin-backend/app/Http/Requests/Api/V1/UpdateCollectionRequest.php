<?php

namespace App\Http\Requests\Api\V1;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

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
        $slugRules = ['sometimes', 'required', 'string', 'alpha_dash', 'min:3', 'max:100'];

        $slugCollectionId = $this->route('id');
        $uniqueSlug = Rule::unique('collections', 'slug');
        if ($slugCollectionId !== null) {
            $uniqueSlug = $uniqueSlug->ignore($slugCollectionId);
        }
        $slugRules[] = $uniqueSlug;

        return [
            'name' => ['sometimes', 'required', 'string', 'max:100'],
            'icon' => ['sometimes', 'nullable', 'string', 'max:50'],
            'color' => ['sometimes', 'nullable', 'string', 'max:20'],
            'is_public' => ['sometimes', 'required', 'boolean'],
            'sort_order' => ['sometimes', 'integer'],
            // Pro-only custom public URL slug; uniqueness is asserted against
            // the globally unique `collections.slug` column.
            'slug' => $slugRules,
        ];
    }

    /**
     * Get custom messages for validator errors.
     *
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'slug.alpha_dash' => 'Slug hanya boleh memuat huruf, angka, tanda hubung, dan underscore.',
            'slug.min' => 'Slug minimal 3 karakter.',
            'slug.max' => 'Slug maksimal 100 karakter.',
            'slug.unique' => 'Slug sudah dipakai koleksi lain. Pilih slug lain.',
        ];
    }
}
