package com.example.vaultguard.tier

/**
 * Entitlements ("feature flags") returned by backend at login/refresh (planned).
 * For now this is stored locally as a placeholder until backend is implemented.
 */
data class UserEntitlements(
    val isLiteMode: Boolean,
    val isAngelActivated: Boolean,
    val isRevolutionActivated: Boolean,
) {
    companion object {
        fun fromTier(tier: UserTier): UserEntitlements {
            return when (tier) {
                UserTier.LITE -> UserEntitlements(
                    isLiteMode = true,
                    isAngelActivated = false,
                    isRevolutionActivated = false,
                )

                UserTier.ANGEL -> UserEntitlements(
                    isLiteMode = false,
                    isAngelActivated = true,
                    isRevolutionActivated = false,
                )

                UserTier.REVOLUTION -> UserEntitlements(
                    isLiteMode = false,
                    isAngelActivated = true,
                    isRevolutionActivated = true,
                )
            }
        }
    }
}

