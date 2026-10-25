<?php

namespace App\Http\Requests\Api\V1;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;

class UpdateLinkRequest extends FormRequest
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
            'collection_id' => ['nullable', 'integer', 'exists:collections,id'],
            'title' => ['nullable', 'string', 'max:255'],
            'user_notes' => ['nullable', 'string'],
            'is_pinned' => ['nullable', 'boolean'],
            'is_read' => ['nullable', 'boolean'],
            'remind_at' => ['nullable', 'date'],
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
            'collection_id.exists' => 'Koleksi yang dipilih tidak ditemukan.',
            'title.max' => 'Judul tautan maksimal 255 karakter.',
            'remind_at.date' => 'Format tanggal dan waktu pengingat tidak valid.',
        ];
    }
}
