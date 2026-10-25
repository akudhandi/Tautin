<?php

namespace App\Http\Requests\Api\V1;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;

class RestorePurchasesRequest extends FormRequest
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
            'purchases' => ['required', 'array', 'min:1'],
            'purchases.*.product_id' => ['required', 'string'],
            'purchases.*.purchase_token' => ['required', 'string'],
            'purchases.*.order_id' => ['nullable', 'string'],
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
            'purchases.required' => 'Daftar struk pembelian wajib disertakan untuk restore.',
            'purchases.min' => 'Setidaknya sertakan satu token pembelian untuk restore.',
            'purchases.*.product_id.required' => 'ID Produk Google Play wajib ada pada setiap item.',
            'purchases.*.purchase_token.required' => 'Token pembelian wajib ada pada setiap item.',
        ];
    }
}
