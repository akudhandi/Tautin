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
        Schema::create('tags', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('name', 50);
            $table->timestamp('created_at')->useCurrent();

            $table->unique(['user_id', 'name'], 'uq_tags_user_name');
        });

        Schema::create('link_tag', function (Blueprint $table) {
            $table->foreignId('link_id')->constrained('links')->cascadeOnDelete();
            $table->foreignId('tag_id')->constrained('tags')->cascadeOnDelete();
            $table->primary(['link_id', 'tag_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('link_tag');
        Schema::dropIfExists('tags');
    }
};
