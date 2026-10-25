<?php

namespace App\Actions\Auth;

use App\Models\User;

class DeleteUserAccountAction
{
    /**
     * Delete user account permanently (cascades to all collections, links, tags, subscriptions).
     */
    public function execute(User $user): void
    {
        $user->tokens()->delete();
        $user->delete();
    }
}
