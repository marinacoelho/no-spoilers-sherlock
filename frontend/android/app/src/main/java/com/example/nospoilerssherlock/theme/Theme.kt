package com.example.nospoilerssherlock.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

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

private val DetectiveLightColorScheme = lightColorScheme(
    primary = Color(0xFF6E5D00),
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFFFFE28B),
    onPrimaryContainer = Color(0xFF221B00),

    secondary = Color(0xFF3B6082),
    onSecondary = Color(0xFFFFFFFF),
    secondaryContainer = Color(0xFFD2E4F9),
    onSecondaryContainer = Color(0xFF001D33),

    tertiary = CitationGreen,
    onTertiary = Color(0xFFFFFFFF),
    tertiaryContainer = Color(0xFFA5F0E4),
    onTertiaryContainer = Color(0xFF00201C),

    background = Color(0xFFFBF8EE),
    onBackground = Color(0xFF1B1B18),

    surface = Color(0xFFFBF8EE),
    onSurface = Color(0xFF1B1B18),
    surfaceVariant = Color(0xFFE7E2D0),
    onSurfaceVariant = Color(0xFF49473A),

    surfaceContainerLowest = Color(0xFFFFFFFF),
    surfaceContainerLow = Color(0xFFF5F2E8),
    surfaceContainer = Color(0xFFEFECE2),
    surfaceContainerHigh = Color(0xFFE9E6DC),
    surfaceContainerHighest = Color(0xFFE3E0D6),

    outline = Color(0xFF7A7768),
    outlineVariant = Color(0xFFC7C7B7)
)

@Composable
fun NoSpoilersSherlockTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit,
) {
    val context = LocalContext.current
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DetectiveDarkColorScheme
        else -> DetectiveLightColorScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
