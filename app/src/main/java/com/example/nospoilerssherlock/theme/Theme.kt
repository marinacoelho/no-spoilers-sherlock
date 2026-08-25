package com.example.nospoilerssherlock.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable

private val DetectiveDarkColorScheme = darkColorScheme(
    primary = VictorianGold,
    onPrimary = DetectiveNavyDark,
    secondary = VictorianGoldLight,
    onSecondary = DetectiveNavyDark,
    background = DetectiveNavyDark,
    onBackground = ParchmentCream,
    surface = DetectiveNavyMedium,
    onSurface = ParchmentCream
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
