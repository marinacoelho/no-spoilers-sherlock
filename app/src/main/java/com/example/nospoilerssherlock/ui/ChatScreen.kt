package com.example.nospoilerssherlock.ui

import android.graphics.Bitmap
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.RestartAlt
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.ZoomIn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.nospoilerssherlock.data.models.ChatMessage
import com.example.nospoilerssherlock.data.models.MessageSender
import com.mikepenz.markdown.m3.Markdown
import com.mikepenz.markdown.m3.markdownColor

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(
    viewModel: ChatViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    var inputText by remember { mutableStateOf("") }
    var showBookBottomSheet by remember { mutableStateOf(false) }
    var previewImage by remember { mutableStateOf<Pair<Bitmap, String?>?>(null) }
    val sheetState = rememberModalBottomSheetState()
    val listState = rememberLazyListState()
    val scrollBehavior = TopAppBarDefaults.enterAlwaysScrollBehavior()

    LaunchedEffect(uiState.messages.size) {
        if (uiState.messages.isNotEmpty()) {
            listState.animateScrollToItem(uiState.messages.size - 1)
        }
    }

    Scaffold(
        modifier = Modifier.nestedScroll(scrollBehavior.nestedScrollConnection),
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        topBar = {
            TopAppBar(
                title = {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(end = 12.dp)
                    ) {
                        Text(
                            text = "No Spoilers, Sherlock",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Spacer(modifier = Modifier.height(2.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            FilterChip(
                                selected = true,
                                onClick = { showBookBottomSheet = true },
                                label = {
                                    Text(
                                        text = uiState.selectedBook?.title ?: "Select Book",
                                        style = MaterialTheme.typography.labelMedium,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                },
                                leadingIcon = {
                                    Icon(
                                        imageVector = Icons.AutoMirrored.Filled.MenuBook,
                                        contentDescription = null,
                                        modifier = Modifier.size(14.dp)
                                    )
                                },
                                trailingIcon = {
                                    Icon(
                                        imageVector = Icons.Default.ArrowDropDown,
                                        contentDescription = null,
                                        modifier = Modifier.size(16.dp)
                                    )
                                },
                                border = null,
                                colors = FilterChipDefaults.filterChipColors(
                                    selectedContainerColor = MaterialTheme.colorScheme.surfaceContainerHighest,
                                    selectedLabelColor = MaterialTheme.colorScheme.onSurfaceVariant,
                                    selectedLeadingIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                                    selectedTrailingIconColor = MaterialTheme.colorScheme.onSurfaceVariant
                                ),
                                modifier = Modifier.height(28.dp)
                            )

                            AiStatusBadge(onDeviceStatus = uiState.onDeviceStatus)
                        }
                    }
                },
                actions = {},
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
                    scrolledContainerColor = MaterialTheme.colorScheme.surfaceContainer
                ),
                scrollBehavior = scrollBehavior
            )
        },
        containerColor = MaterialTheme.colorScheme.background
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = paddingValues.calculateTopPadding())
        ) {
            Box(modifier = Modifier.weight(1f)) {
                if (uiState.messages.isEmpty()) {
                    EmptyChatHero(
                        selectedBookTitle = uiState.selectedBook?.title ?: "Sherlock Holmes",
                        onPromptSelected = { inputText = it }
                    )
                } else {
                    LazyColumn(
                        state = listState,
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(horizontal = 16.dp, vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(14.dp)
                    ) {
                        items(uiState.messages, key = { it.id }) { message ->
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .animateItem()
                            ) {
                                ModernMessageBubble(
                                    message = message,
                                    onVisualizeScene = { query, chapter ->
                                        viewModel.visualizeScene(query, chapter)
                                    },
                                    onImageClick = { bitmap, caption ->
                                        previewImage = Pair(bitmap, caption)
                                    }
                                )
                            }
                        }
                    }
                }
            }

            AnimatedVisibility(
                visible = uiState.isLoading,
                enter = fadeIn() + slideInVertically { it / 2 },
                exit = fadeOut() + slideOutVertically { it / 2 }
            ) {
                SherlockInvestigatingIndicator(
                    statusMessage = uiState.statusMessage ?: "Sherlock is deducing clues..."
                )
            }

            QuickPromptSuggestions(
                selectedBookId = uiState.selectedBook?.id,
                onPromptClicked = { inputText = it }
            )

            ChatInputBar(
                text = inputText,
                onTextChange = { inputText = it },
                onSend = {
                    if (inputText.isNotBlank()) {
                        viewModel.sendMessage(inputText)
                        inputText = ""
                    }
                }
            )
        }
    }

    if (showBookBottomSheet) {
        ModalBottomSheet(
            onDismissRequest = { showBookBottomSheet = false },
            sheetState = sheetState,
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 32.dp)
            ) {
                Text(
                    text = "Select Novel",
                    style = MaterialTheme.typography.titleLarge,
                    color = MaterialTheme.colorScheme.onSurface,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(horizontal = 24.dp)
                )
                Text(
                    text = "Choose the Sherlock Holmes mystery you are currently reading",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 24.dp, vertical = 4.dp)
                )

                Spacer(modifier = Modifier.height(8.dp))

                uiState.books.forEach { book ->
                    val isSelected = book.id == uiState.selectedBook?.id
                    ListItem(
                        headlineContent = {
                            Text(
                                text = book.title,
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.SemiBold
                            )
                        },
                        supportingContent = {
                            Text(
                                text = "${book.author} • ${book.totalChapters} Chapters",
                                style = MaterialTheme.typography.bodySmall
                            )
                        },
                        leadingContent = {
                            Surface(
                                shape = CircleShape,
                                color = if (isSelected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceContainerHighest,
                                modifier = Modifier.size(40.dp)
                            ) {
                                Box(contentAlignment = Alignment.Center) {
                                    Icon(
                                        imageVector = Icons.AutoMirrored.Filled.MenuBook,
                                        contentDescription = null,
                                        tint = if (isSelected) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.size(20.dp)
                                    )
                                }
                            }
                        },
                        trailingContent = {
                            if (isSelected) {
                                Icon(
                                    imageVector = Icons.Default.Check,
                                    contentDescription = "Selected",
                                    tint = MaterialTheme.colorScheme.primary
                                )
                            }
                        },
                        colors = ListItemDefaults.colors(
                            containerColor = if (isSelected) MaterialTheme.colorScheme.surfaceContainerHigh else Color.Transparent
                        ),
                        modifier = Modifier.clickable {
                            viewModel.selectBook(book)
                            showBookBottomSheet = false
                        }
                    )
                }
            }
        }
    }

    previewImage?.let { (bitmap, caption) ->
        ZoomableImageDialog(
            bitmap = bitmap,
            caption = caption,
            onDismiss = { previewImage = null }
        )
    }
}

@Composable
private fun AiStatusBadge(onDeviceStatus: String?) {
    val isReady = onDeviceStatus?.contains("Ready", ignoreCase = true) == true
    val isDownloading = onDeviceStatus?.contains("Downloading", ignoreCase = true) == true

    Surface(
        shape = CircleShape,
        color = when {
            isReady -> MaterialTheme.colorScheme.tertiaryContainer
            isDownloading -> MaterialTheme.colorScheme.secondaryContainer
            else -> MaterialTheme.colorScheme.surfaceContainerHighest
        }
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            when {
                isReady -> {
                    Icon(
                        imageVector = Icons.Default.Bolt,
                        contentDescription = "On-Device",
                        tint = MaterialTheme.colorScheme.onTertiaryContainer,
                        modifier = Modifier.size(14.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = "On-Device",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onTertiaryContainer,
                        fontWeight = FontWeight.SemiBold
                    )
                }
                isDownloading -> {
                    CircularProgressIndicator(
                        modifier = Modifier.size(10.dp),
                        strokeWidth = 2.dp,
                        color = MaterialTheme.colorScheme.onSecondaryContainer
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = "Downloading...",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSecondaryContainer,
                        fontWeight = FontWeight.SemiBold
                    )
                }
                else -> {
                    Icon(
                        imageVector = Icons.Default.Cloud,
                        contentDescription = "Cloud AI",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(14.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = "Cloud AI",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontWeight = FontWeight.Medium
                    )
                }
            }
        }
    }
}

@Composable
private fun EmptyChatHero(
    selectedBookTitle: String,
    onPromptSelected: (String) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Surface(
            shape = CircleShape,
            color = MaterialTheme.colorScheme.primaryContainer,
            modifier = Modifier.size(72.dp)
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon(
                    imageVector = Icons.Default.Psychology,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onPrimaryContainer,
                    modifier = Modifier.size(40.dp)
                )
            }
        }
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "The Game is Afoot",
            style = MaterialTheme.typography.titleLarge,
            color = MaterialTheme.colorScheme.onSurface,
            fontWeight = FontWeight.Bold
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "Ask questions as you read through $selectedBookTitle. Sherlock guarantees zero spoilers for upcoming chapters!",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 16.dp)
        )
        Spacer(modifier = Modifier.height(24.dp))

        Column(
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            listOf(
                "🎨 Visualize the crime scene at Lauriston Gardens in Chapter 3",
                "In Chapter 3, who was found dead at Lauriston Gardens?",
                "In Chapter 5, what clue did the wedding ring provide?",
                "Who is Inspector Lestrade, and what is his theory?"
            ).forEach { prompt ->
                OutlinedCard(
                    onClick = { onPromptSelected(prompt) },
                    shape = MaterialTheme.shapes.medium,
                    colors = CardDefaults.outlinedCardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceContainer
                    ),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.Search,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Text(
                            text = prompt,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun ModernMessageBubble(
    message: ChatMessage,
    modifier: Modifier = Modifier,
    onVisualizeScene: ((String, Int?) -> Unit)? = null,
    onImageClick: ((Bitmap, String?) -> Unit)? = null
) {
    val isUser = message.sender == MessageSender.USER
    val isSystem = message.sender == MessageSender.SYSTEM

    val alignment = if (isUser) Alignment.End else Alignment.Start

    val bubbleColor = when {
        isUser -> MaterialTheme.colorScheme.primaryContainer
        isSystem -> MaterialTheme.colorScheme.surfaceContainer
        else -> MaterialTheme.colorScheme.surfaceContainerHigh
    }

    val bubbleShape = RoundedCornerShape(
        topStart = 20.dp,
        topEnd = 20.dp,
        bottomStart = if (isUser) 20.dp else 4.dp,
        bottomEnd = if (isUser) 4.dp else 20.dp
    )

    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = alignment
    ) {
        Row(
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start,
            modifier = Modifier.fillMaxWidth()
        ) {
            if (!isUser) {
                Surface(
                    shape = CircleShape,
                    color = MaterialTheme.colorScheme.surfaceContainerHighest,
                    modifier = Modifier.size(32.dp)
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            imageVector = if (message.isSceneVisualization) Icons.Default.Palette else Icons.Default.AutoAwesome,
                            contentDescription = "Sherlock AI",
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
                Spacer(modifier = Modifier.width(8.dp))
            }

            Surface(
                color = bubbleColor,
                shape = bubbleShape,
                modifier = Modifier.fillMaxWidth(0.85f)
            ) {
                Column(modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp)) {
                    if (message.imageBitmap != null) {
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(bottom = 8.dp)
                                .clickable {
                                    onImageClick?.invoke(message.imageBitmap, message.text)
                                }
                        ) {
                            Column {
                                Box {
                                    Image(
                                        bitmap = message.imageBitmap.asImageBitmap(),
                                        contentDescription = "Scene Illustration (Tap to Zoom)",
                                        contentScale = ContentScale.FillWidth,
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clip(RoundedCornerShape(topStart = 12.dp, topEnd = 12.dp))
                                    )
                                    Surface(
                                        color = Color.Black.copy(alpha = 0.65f),
                                        shape = RoundedCornerShape(8.dp),
                                        modifier = Modifier
                                            .align(Alignment.TopEnd)
                                            .padding(8.dp)
                                    ) {
                                        Row(
                                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp),
                                            verticalAlignment = Alignment.CenterVertically
                                        ) {
                                            Icon(
                                                imageVector = Icons.Default.ZoomIn,
                                                contentDescription = "Zoom",
                                                tint = Color.White,
                                                modifier = Modifier.size(13.dp)
                                            )
                                            Spacer(modifier = Modifier.width(3.dp))
                                            Text(
                                                text = "Examine",
                                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                                                color = Color.White,
                                                fontWeight = FontWeight.Medium
                                            )
                                        }
                                    }
                                }
                                Row(
                                    modifier = Modifier
                                        .background(MaterialTheme.colorScheme.surfaceContainerHighest.copy(alpha = 0.7f))
                                        .fillMaxWidth()
                                        .padding(horizontal = 10.dp, vertical = 5.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.Palette,
                                        contentDescription = null,
                                        modifier = Modifier.size(12.dp),
                                        tint = MaterialTheme.colorScheme.primary
                                    )
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text(
                                        text = "Sidney Paget Victorian Style • Nano Banana AI",
                                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        fontWeight = FontWeight.SemiBold
                                    )
                                }
                            }
                        }
                    }

                    if (message.text.isNotBlank()) {
                        Markdown(
                            content = message.text,
                            colors = markdownColor(
                                text = if (isUser) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurface
                            ),
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }
            }
        }

        if (!isUser && !message.isSceneVisualization && message.text != "..." && message.extractedChapter != null) {
            Spacer(modifier = Modifier.height(4.dp))
            Surface(
                onClick = {
                    val promptText = "Visualize the scene from Chapter ${message.extractedChapter}"
                    onVisualizeScene?.invoke(promptText, message.extractedChapter)
                },
                shape = RoundedCornerShape(16.dp),
                color = MaterialTheme.colorScheme.surfaceContainerHigh,
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                modifier = Modifier.padding(start = 40.dp)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.Palette,
                        contentDescription = "Visualize Scene",
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(13.dp)
                    )
                    Spacer(modifier = Modifier.width(5.dp))
                    Text(
                        text = "Visualize Scene (Ch. ${message.extractedChapter})",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }
    }
}

@Composable
private fun SherlockInvestigatingIndicator(statusMessage: String) {
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val alpha by infiniteTransition.animateFloat(
        initialValue = 0.4f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 800),
            repeatMode = RepeatMode.Reverse
        ),
        label = "alpha"
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Surface(
            color = MaterialTheme.colorScheme.surfaceContainerHigh,
            shape = CircleShape
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                CircularProgressIndicator(
                    modifier = Modifier.size(14.dp),
                    color = MaterialTheme.colorScheme.primary,
                    strokeWidth = 2.dp
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = statusMessage,
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.alpha(alpha)
                )
            }
        }
    }
}

@Composable
private fun QuickPromptSuggestions(
    selectedBookId: String?,
    onPromptClicked: (String) -> Unit
) {
    val prompts = when (selectedBookId) {
        "sign_of_the_four" -> listOf(
            "🎨 Visualize Chapter 4 crime scene",
            "In Chapter 2, who is Miss Morstan?",
            "In Chapter 4, who was found dead?",
            "What clue was left behind?"
        )
        else -> listOf(
            "🎨 Visualize Lauriston Gardens in Chapter 3",
            "In Chapter 3, who died?",
            "In Chapter 5, what clue was found?",
            "Who is Inspector Lestrade?"
        )
    }

    LazyRow(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(prompts) { chipText ->
            SuggestionChip(
                onClick = { onPromptClicked(chipText) },
                label = { Text(chipText, style = MaterialTheme.typography.labelMedium) },
                icon = {
                    Icon(
                        imageVector = Icons.Default.Search,
                        contentDescription = null,
                        modifier = Modifier.size(14.dp),
                        tint = MaterialTheme.colorScheme.primary
                    )
                },
                colors = SuggestionChipDefaults.suggestionChipColors(
                    containerColor = MaterialTheme.colorScheme.surfaceContainer,
                    labelColor = MaterialTheme.colorScheme.onSurface
                ),
                border = SuggestionChipDefaults.suggestionChipBorder(
                    enabled = true,
                    borderColor = MaterialTheme.colorScheme.outlineVariant
                )
            )
        }
    }
}

@Composable
private fun ChatInputBar(
    text: String,
    onTextChange: (String) -> Unit,
    onSend: () -> Unit
) {
    Surface(
        color = MaterialTheme.colorScheme.surfaceContainer,
        tonalElevation = 6.dp,
        modifier = Modifier
            .fillMaxWidth()
            .windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Bottom))
    ) {
        Row(
            modifier = Modifier
                .padding(horizontal = 12.dp, vertical = 8.dp)
                .fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = text,
                onValueChange = onTextChange,
                placeholder = {
                    Text(
                        text = "Ask Sherlock (e.g. 'In chapter 3...')",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                    )
                },
                modifier = Modifier.weight(1f),
                shape = RoundedCornerShape(26.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedContainerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                    unfocusedContainerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                    focusedBorderColor = MaterialTheme.colorScheme.primary,
                    unfocusedBorderColor = Color.Transparent,
                    focusedTextColor = MaterialTheme.colorScheme.onSurface,
                    unfocusedTextColor = MaterialTheme.colorScheme.onSurface
                ),
                maxLines = 3
            )
            Spacer(modifier = Modifier.width(8.dp))
            FilledIconButton(
                onClick = onSend,
                enabled = text.isNotBlank(),
                modifier = Modifier.size(48.dp),
                colors = IconButtonDefaults.filledIconButtonColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                    disabledContainerColor = MaterialTheme.colorScheme.surfaceContainerHighest,
                    disabledContentColor = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.38f)
                )
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.Send,
                    contentDescription = "Send",
                    modifier = Modifier.size(20.dp)
                )
            }
        }
    }
}

@Composable
fun ZoomableImageDialog(
    bitmap: Bitmap,
    caption: String?,
    onDismiss: () -> Unit
) {
    var scale by remember { mutableFloatStateOf(1f) }
    var offset by remember { mutableStateOf(Offset.Zero) }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(
            usePlatformDefaultWidth = false
        )
    ) {
        Surface(
            color = Color.Black.copy(alpha = 0.94f),
            modifier = Modifier.fillMaxSize()
        ) {
            Box(modifier = Modifier.fillMaxSize()) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .pointerInput(Unit) {
                            detectTransformGestures { _, pan, zoom, _ ->
                                scale = (scale * zoom).coerceIn(1f, 5f)
                                if (scale > 1f) {
                                    val maxOffsetX = (size.width * (scale - 1f)) / 2f
                                    val maxOffsetY = (size.height * (scale - 1f)) / 2f
                                    offset = Offset(
                                        x = (offset.x + pan.x).coerceIn(-maxOffsetX, maxOffsetX),
                                        y = (offset.y + pan.y).coerceIn(-maxOffsetY, maxOffsetY)
                                    )
                                } else {
                                    offset = Offset.Zero
                                }
                            }
                        }
                        .pointerInput(Unit) {
                            detectTapGestures(
                                onDoubleTap = {
                                    if (scale > 1f) {
                                        scale = 1f
                                        offset = Offset.Zero
                                    } else {
                                        scale = 2.5f
                                    }
                                }
                            )
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Image(
                        bitmap = bitmap.asImageBitmap(),
                        contentDescription = "Zoomed Scene Illustration",
                        contentScale = ContentScale.Fit,
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(16.dp)
                            .graphicsLayer {
                                scaleX = scale
                                scaleY = scale
                                translationX = offset.x
                                translationY = offset.y
                            }
                    )
                }

                Surface(
                    color = Color.Black.copy(alpha = 0.6f),
                    modifier = Modifier
                        .fillMaxWidth()
                        .align(Alignment.TopCenter)
                        .statusBarsPadding()
                ) {
                    Row(
                        modifier = Modifier
                            .padding(horizontal = 16.dp, vertical = 12.dp)
                            .fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "🔍 Scene Investigation",
                                style = MaterialTheme.typography.titleMedium,
                                color = Color.White,
                                fontWeight = FontWeight.Bold
                            )
                            Text(
                                text = "Pinch to zoom • Double-tap to toggle zoom • Drag to pan",
                                style = MaterialTheme.typography.bodySmall,
                                color = Color.LightGray
                            )
                        }

                        if (scale > 1f) {
                            IconButton(onClick = {
                                scale = 1f
                                offset = Offset.Zero
                            }) {
                                Icon(
                                    imageVector = Icons.Default.RestartAlt,
                                    contentDescription = "Reset Zoom",
                                    tint = Color.White
                                )
                            }
                        }

                        IconButton(onClick = onDismiss) {
                            Icon(
                                imageVector = Icons.Default.Close,
                                contentDescription = "Close",
                                tint = Color.White
                            )
                        }
                    }
                }

                Surface(
                    color = Color.Black.copy(alpha = 0.7f),
                    modifier = Modifier
                        .fillMaxWidth()
                        .align(Alignment.BottomCenter)
                        .navigationBarsPadding()
                ) {
                    Column(
                        modifier = Modifier
                            .padding(horizontal = 20.dp, vertical = 12.dp)
                            .fillMaxWidth(),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = "Zoom: ${"%.1f".format(scale)}x",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.primaryContainer,
                            fontWeight = FontWeight.SemiBold
                        )
                        if (!caption.isNullOrBlank()) {
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = caption.take(120),
                                style = MaterialTheme.typography.bodySmall,
                                color = Color.LightGray,
                                maxLines = 2,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                }
            }
        }
    }
}
