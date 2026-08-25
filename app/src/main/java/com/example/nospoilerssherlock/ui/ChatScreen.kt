package com.example.nospoilerssherlock.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.nospoilerssherlock.data.models.ChatMessage
import com.example.nospoilerssherlock.data.models.MessageSender
import com.example.nospoilerssherlock.theme.*
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(
    viewModel: ChatViewModel = androidx.lifecycle.viewmodel.compose.viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    var inputText by remember { mutableStateOf("") }
    var showBookDropdown by remember { mutableStateOf(false) }
    val listState = rememberLazyListState()
    val coroutineScope = rememberCoroutineScope()

    LaunchedEffect(uiState.messages.size) {
        if (uiState.messages.isNotEmpty()) {
            listState.animateScrollToItem(uiState.messages.size - 1)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("🕵️ No Spoilers, Sherlock", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = VictorianGold)
                        }
                        Text(
                            text = uiState.selectedBook?.title ?: "Select Book",
                            fontSize = 12.sp,
                            color = ParchmentCream.copy(alpha = 0.7f)
                        )
                    }
                },
                actions = {
                    // Book Selection Dropdown
                    Box {
                        IconButton(onClick = { showBookDropdown = true }) {
                            Icon(Icons.Default.MenuBook, contentDescription = "Select Book", tint = VictorianGold)
                        }
                        DropdownMenu(
                            expanded = showBookDropdown,
                            onDismissRequest = { showBookDropdown = false }
                        ) {
                            uiState.books.forEach { book ->
                                DropdownMenuItem(
                                    text = { Text(book.title) },
                                    onClick = {
                                        viewModel.selectBook(book)
                                        showBookDropdown = false
                                    }
                                )
                            }
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = DetectiveNavyMedium
                )
            )
        },
        containerColor = DetectiveNavyDark
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            // Spoiler Guard Status Banner
            Surface(
                color = DetectiveNavyMedium,
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.Lock,
                        contentDescription = "Spoiler Lock",
                        tint = VictorianGold,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "Spoiler Guard Active • Chapter context automatically detected from prompt",
                        fontSize = 12.sp,
                        color = ParchmentCream.copy(alpha = 0.8f)
                    )
                }
            }

            // Chat Messages List
            LazyColumn(
                state = listState,
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(uiState.messages) { message ->
                    MessageBubble(message = message)
                }
            }

            // Status indicator when processing
            AnimatedVisibility(visible = uiState.isLoading) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(16.dp),
                        color = VictorianGold,
                        strokeWidth = 2.dp
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = uiState.statusMessage ?: "Sherlock is investigating...",
                        fontSize = 12.sp,
                        color = VictorianGold
                    )
                }
            }

            // Quick Prompt Suggestions
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                listOf("In Chapter 3, who died?", "In Chapter 5, what clue was found?", "Who is Lestrade?").forEach { chipText ->
                    FilterChip(
                        selected = false,
                        onClick = { inputText = chipText },
                        label = { Text(chipText, fontSize = 11.sp) },
                        colors = FilterChipDefaults.filterChipColors(
                            containerColor = DetectiveNavyMedium,
                            labelColor = ParchmentCream
                        )
                    )
                }
            }

            // Input Bar
            Surface(
                color = DetectiveNavyMedium,
                tonalElevation = 4.dp,
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .padding(12.dp)
                        .fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    OutlinedTextField(
                        value = inputText,
                        onValueChange = { inputText = it },
                        placeholder = { Text("Ask about your book (e.g. 'In chapter 3...')", fontSize = 14.sp, color = ParchmentCream.copy(alpha = 0.5f)) },
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(24.dp),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedContainerColor = DetectiveNavyDark,
                            unfocusedContainerColor = DetectiveNavyDark,
                            focusedBorderColor = VictorianGold,
                            unfocusedBorderColor = DetectiveNavyLight,
                            focusedTextColor = ParchmentCream,
                            unfocusedTextColor = ParchmentCream
                        ),
                        maxLines = 3
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    IconButton(
                        onClick = {
                            if (inputText.isNotBlank()) {
                                viewModel.sendMessage(inputText)
                                inputText = ""
                            }
                        },
                        modifier = Modifier
                            .size(48.dp)
                            .background(VictorianGold, shape = CircleShape)
                    ) {
                        Icon(
                            Icons.AutoMirrored.Filled.Send,
                            contentDescription = "Send",
                            tint = DetectiveNavyDark
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun MessageBubble(message: ChatMessage) {
    val isUser = message.sender == MessageSender.USER
    val isSystem = message.sender == MessageSender.SYSTEM

    val alignment = when {
        isUser -> Alignment.End
        else -> Alignment.Start
    }

    val bubbleColor = when {
        isUser -> DetectiveNavyLight
        isSystem -> DetectiveNavyMedium
        else -> DetectiveNavyMedium
    }

    val textColor = ParchmentCream

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = alignment
    ) {
        if (message.extractedChapter != null) {
            Surface(
                color = VictorianGold.copy(alpha = 0.15f),
                shape = RoundedCornerShape(8.dp),
                modifier = Modifier.padding(bottom = 4.dp)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.Lock,
                        contentDescription = "Chapter Bound",
                        tint = VictorianGold,
                        modifier = Modifier.size(12.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = "Chapter ${message.extractedChapter} Context",
                        fontSize = 10.sp,
                        color = VictorianGold,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }

        Surface(
            color = bubbleColor,
            shape = RoundedCornerShape(
                topStart = 16.dp,
                topEnd = 16.dp,
                bottomStart = if (isUser) 16.dp else 4.dp,
                bottomEnd = if (isUser) 4.dp else 16.dp
            ),
            modifier = Modifier.widthIn(max = 300.dp)
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Text(
                    text = message.text,
                    color = textColor,
                    fontSize = 14.sp
                )

                if (message.citedChapters.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(6.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        message.citedChapters.forEach { chNum ->
                            Surface(
                                color = CitationGreen.copy(alpha = 0.2f),
                                shape = RoundedCornerShape(4.dp)
                            ) {
                                Text(
                                    text = "Ch $chNum",
                                    fontSize = 9.sp,
                                    color = CitationGreen,
                                    modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp),
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
