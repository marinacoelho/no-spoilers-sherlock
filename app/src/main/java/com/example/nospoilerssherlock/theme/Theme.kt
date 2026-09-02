package com.example.nospoilerssherlock.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val DetectiveDarkColorScheme = darkColorScheme(
    primary = VictorianGold,
    onPrimary = Color(0xFF1F1600),
    primaryContainer = Color(0xFF4D3C00),
    onPrimaryContainer = VictorianGoldLight,

    secondary = Color(0xFF8EAFCE),
    onSecondary = Color(0xFF002A45),
    secondaryContainer = Color(0xFF253B55),
    onSecondaryContainer = Color(0xFFD2E4F9),

    tertiary = CitationGreen,
    onTertiary = Color(0xFF003731),
    tertiaryContainer = Color(0xFF134E48),
    onTertiaryContainer = Color(0xFF86F2DF),

    background = DetectiveNavyDark,
    onBackground = ParchmentCream,

    surface = Color(0xFF0D1424),
    onSurface = ParchmentCream,
    surfaceVariant = DetectiveNavyMedium,
    onSurfaceVariant = Color(0xFFCBD5E1),

    surfaceContainerLowest = Color(0xFF070B14),
    surfaceContainerLow = Color(0xFF0F182B),
    surfaceContainer = DetectiveNavyMedium,
    surfaceContainerHigh = Color(0xFF253356),
    surfaceContainerHighest = Color(0xFF2F406A),

    outline = Color(0xFF52627E),
    outlineVariant = Color(0xFF333F54)
)

@Composable
fun NoSpoilersSherlockTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = DetectiveDarkColorScheme,
        typography = Typography,
        content = content
    )
}
