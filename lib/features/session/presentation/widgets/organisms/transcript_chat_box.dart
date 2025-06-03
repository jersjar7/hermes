// lib/features/session/presentation/widgets/organisms/transcript_chat_box.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/core/hermes_engine/state/hermes_status.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/hermes_icons.dart';
import 'package:hermes/core/presentation/constants/durations.dart';
import 'package:hermes/core/presentation/widgets/animations/fade_in_widget.dart';
import 'package:hermes/core/presentation/widgets/animations/pulse_animation.dart';

/// Enhanced chat-like transcript box that displays speaker's speech in real-time.
/// Features elegant empty states and smooth animations with responsive sizing.
class TranscriptChatBox extends ConsumerStatefulWidget {
  const TranscriptChatBox({super.key});

  @override
  ConsumerState<TranscriptChatBox> createState() => _TranscriptChatBoxState();
}

class _TranscriptChatBoxState extends ConsumerState<TranscriptChatBox> {
  final ScrollController _scrollController = ScrollController();
  final List<TranscriptMessage> _messages = [];
  String? _lastProcessedTranscript;
  String? _currentPartialTranscript;
  bool _userHasScrolledUp = false;
  bool _showScrollToBottomButton = false;
  bool _hasEverSpoken = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final isAtBottom =
        _scrollController.offset >=
        _scrollController.position.maxScrollExtent - 50;

    setState(() {
      _userHasScrolledUp = !isAtBottom;
      _showScrollToBottomButton = !isAtBottom && _messages.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(hermesControllerProvider);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive sizes based on available space
        final sizes = _calculateResponsiveSizes(constraints, context);

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(HermesSpacing.md),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: sessionState.when(
            data: (state) {
              _updateTranscripts(state);

              return Column(
                children: [
                  // Header with dynamic status
                  _buildHeader(context, theme, state, sizes),

                  // Messages area - always visible
                  Expanded(
                    child: Stack(
                      children: [
                        _buildMessagesArea(context, theme, state, sizes),
                        if (_showScrollToBottomButton)
                          _buildScrollToBottomButton(context, theme, sizes),
                      ],
                    ),
                  ),

                  // Current speaking indicator
                  _buildCurrentSpeechIndicator(context, theme, state, sizes),
                ],
              );
            },
            loading: () => _buildLoadingState(context, theme, sizes),
            error: (error, _) => _buildErrorState(context, theme, error, sizes),
          ),
        );
      },
    );
  }

  /// Calculate responsive sizes based on screen dimensions and available space
  _ResponsiveSizes _calculateResponsiveSizes(
    BoxConstraints constraints,
    BuildContext context,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final availableWidth = constraints.maxWidth;
    final availableHeight = constraints.maxHeight;

    // Base sizes for different screen categories
    final isSmallScreen = screenWidth < 360 || screenHeight < 600;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 768;
    final isLargeScreen = screenWidth >= 768;

    // Calculate scale factor based on available space
    final widthScale = (availableWidth / 320).clamp(0.8, 1.5);
    final heightScale = (availableHeight / 400).clamp(0.8, 1.5);
    final scale = (widthScale + heightScale) / 2;

    return _ResponsiveSizes(
      // Header sizes
      headerIconSize: isSmallScreen ? 18 * scale : 20 * scale,

      // Status indicator sizes
      statusDotSize: isSmallScreen ? 5 * scale : 6 * scale,
      statusFontSize: isSmallScreen ? 9 * scale : 10 * scale,

      // Empty state sizes
      emptyStateIconContainerSize:
          isSmallScreen
              ? 48 * scale
              : (isMediumScreen ? 56 * scale : 64 * scale),
      emptyStateIconSize:
          isSmallScreen
              ? 22 * scale
              : (isMediumScreen ? 26 * scale : 28 * scale),

      // Message bubble sizes
      avatarSize:
          isSmallScreen
              ? 28 * scale
              : (isMediumScreen ? 30 * scale : 32 * scale),
      avatarIconSize:
          isSmallScreen
              ? 14 * scale
              : (isMediumScreen ? 15 * scale : 16 * scale),

      // Current speech indicator
      speechDotSize: isSmallScreen ? 6 * scale : 8 * scale,

      // Floating action button
      fabSize: isSmallScreen ? 40 * scale : 48 * scale,

      // Scale factor for general use
      scale: scale,

      // Screen category flags
      isSmallScreen: isSmallScreen,
      isMediumScreen: isMediumScreen,
      isLargeScreen: isLargeScreen,
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    state,
    _ResponsiveSizes sizes,
  ) {
    final isListening = state.status == HermesStatus.listening;
    final isTranslating = state.status == HermesStatus.translating;
    final hasActivity = isListening || isTranslating || _messages.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(HermesSpacing.md * sizes.scale),
      decoration: BoxDecoration(
        color:
            hasActivity
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.1)
                : null,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(HermesSpacing.md),
        ),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Dynamic icon with subtle animation
          PulseAnimation(
            animate: isListening,
            minScale: 0.95,
            maxScale: 1.05,
            child: Icon(
              _getHeaderIcon(state.status),
              size: sizes.headerIconSize,
              color:
                  hasActivity
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
            ),
          ),
          SizedBox(width: HermesSpacing.sm * sizes.scale),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getHeaderTitle(state.status, _hasEverSpoken),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color:
                        hasActivity
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize:
                        (theme.textTheme.titleSmall?.fontSize ?? 14) *
                        sizes.scale,
                  ),
                ),
                Text(
                  _getHeaderSubtitle(state.status, _hasEverSpoken),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontSize:
                        (theme.textTheme.bodySmall?.fontSize ?? 12) *
                        sizes.scale,
                  ),
                ),
              ],
            ),
          ),

          // Status indicator
          _buildStatusIndicator(context, theme, state, sizes),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(
    BuildContext context,
    ThemeData theme,
    state,
    _ResponsiveSizes sizes,
  ) {
    final isListening = state.status == HermesStatus.listening;

    if (_messages.isNotEmpty) {
      // Show message count
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: HermesSpacing.sm * sizes.scale,
          vertical: HermesSpacing.xs * sizes.scale,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12 * sizes.scale),
        ),
        child: Text(
          '${_messages.length}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
            fontSize:
                (theme.textTheme.labelSmall?.fontSize ?? 11) * sizes.scale,
          ),
        ),
      );
    } else if (isListening) {
      // Show live indicator
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: HermesSpacing.sm * sizes.scale,
          vertical: HermesSpacing.xs * sizes.scale,
        ),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12 * sizes.scale),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulseAnimation(
              animate: true,
              child: Container(
                width: sizes.statusDotSize,
                height: sizes.statusDotSize,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SizedBox(width: 4 * sizes.scale),
            Text(
              'LIVE',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.greenAccent.shade700,
                fontWeight: FontWeight.w800,
                fontSize: sizes.statusFontSize,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMessagesArea(
    BuildContext context,
    ThemeData theme,
    state,
    _ResponsiveSizes sizes,
  ) {
    if (_messages.isEmpty) {
      return _buildEmptyState(context, theme, state, sizes);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(HermesSpacing.sm * sizes.scale),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isLatest = index == _messages.length - 1;

        return FadeInWidget(
          duration: HermesDurations.fast,
          slideFrom: const Offset(0, 0.2),
          child: _buildMessageBubble(context, theme, message, isLatest, sizes),
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ThemeData theme,
    state,
    _ResponsiveSizes sizes,
  ) {
    final isReady =
        state.status == HermesStatus.listening ||
        state.status == HermesStatus.buffering;
    final isListening = state.status == HermesStatus.listening;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(HermesSpacing.xl * sizes.scale),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Elegant microphone icon
            Container(
              width: sizes.emptyStateIconContainerSize,
              height: sizes.emptyStateIconContainerSize,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.2,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                isListening ? HermesIcons.listening : HermesIcons.microphone,
                size: sizes.emptyStateIconSize,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),

            SizedBox(height: HermesSpacing.lg * sizes.scale),

            Text(
              _getEmptyStateTitle(state.status, _hasEverSpoken),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                fontSize:
                    (theme.textTheme.titleMedium?.fontSize ?? 16) * sizes.scale,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: HermesSpacing.sm * sizes.scale),

            Text(
              _getEmptyStateSubtitle(state.status, _hasEverSpoken),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
                height: 1.4,
                fontSize:
                    (theme.textTheme.bodyMedium?.fontSize ?? 14) * sizes.scale,
              ),
              textAlign: TextAlign.center,
            ),

            // Subtle speaking tips for new sessions
            if (!_hasEverSpoken && isReady) ...[
              SizedBox(height: HermesSpacing.xl * sizes.scale),
              _buildSpeakingTips(theme, sizes),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSpeakingTips(ThemeData theme, _ResponsiveSizes sizes) {
    return Container(
      padding: EdgeInsets.all(HermesSpacing.md * sizes.scale),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(HermesSpacing.sm * sizes.scale),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 16 * sizes.scale,
                color: theme.colorScheme.outline,
              ),
              SizedBox(width: HermesSpacing.xs * sizes.scale),
              Text(
                'Speaking Tips',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.outline,
                  fontSize:
                      (theme.textTheme.labelMedium?.fontSize ?? 12) *
                      sizes.scale,
                ),
              ),
            ],
          ),
          SizedBox(height: HermesSpacing.sm * sizes.scale),
          ...[
            'Speak clearly at a normal pace',
            'Pause briefly between sentences',
            'Keep device 6-12 inches away',
          ].map((tip) => _buildTip(tip, theme, sizes)),
        ],
      ),
    );
  }

  Widget _buildTip(String text, ThemeData theme, _ResponsiveSizes sizes) {
    return Padding(
      padding: EdgeInsets.only(top: HermesSpacing.xs * sizes.scale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3 * sizes.scale,
            height: 3 * sizes.scale,
            margin: EdgeInsets.only(top: 8 * sizes.scale),
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: HermesSpacing.sm * sizes.scale),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontSize:
                    (theme.textTheme.bodySmall?.fontSize ?? 12) * sizes.scale,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    ThemeData theme,
    TranscriptMessage message,
    bool isLatest,
    _ResponsiveSizes sizes,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: HermesSpacing.sm * sizes.scale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: sizes.avatarSize,
            height: sizes.avatarSize,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              HermesIcons.microphone,
              size: sizes.avatarIconSize,
              color: theme.colorScheme.primary,
            ),
          ),

          SizedBox(width: HermesSpacing.sm * sizes.scale),

          // Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Message bubble
                Container(
                  padding: EdgeInsets.all(HermesSpacing.md * sizes.scale),
                  decoration: BoxDecoration(
                    color:
                        isLatest
                            ? theme.colorScheme.primaryContainer.withValues(
                              alpha: 0.2,
                            )
                            : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4 * sizes.scale),
                      topRight: Radius.circular(HermesSpacing.md * sizes.scale),
                      bottomLeft: Radius.circular(
                        HermesSpacing.md * sizes.scale,
                      ),
                      bottomRight: Radius.circular(
                        HermesSpacing.md * sizes.scale,
                      ),
                    ),
                    border:
                        isLatest
                            ? Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.2,
                              ),
                              width: 1,
                            )
                            : null,
                  ),
                  child: Text(
                    message.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          isLatest
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                      fontWeight:
                          isLatest ? FontWeight.w500 : FontWeight.normal,
                      height: 1.4,
                      fontSize:
                          (theme.textTheme.bodyMedium?.fontSize ?? 14) *
                          sizes.scale,
                    ),
                  ),
                ),

                SizedBox(height: HermesSpacing.xs * sizes.scale),

                // Timestamp
                Text(
                  _formatTimestamp(message.timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontSize:
                        (theme.textTheme.bodySmall?.fontSize ?? 12) *
                        sizes.scale,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSpeechIndicator(
    BuildContext context,
    ThemeData theme,
    state,
    _ResponsiveSizes sizes,
  ) {
    final isListening = state.status == HermesStatus.listening;
    final isTranslating = state.status == HermesStatus.translating;
    final hasCurrentSpeech =
        _currentPartialTranscript != null &&
        _currentPartialTranscript!.isNotEmpty;

    if (!isListening && !isTranslating && !hasCurrentSpeech) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: HermesDurations.fast,
      padding: EdgeInsets.all(HermesSpacing.md * sizes.scale),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(HermesSpacing.md),
        ),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Live indicator
          PulseAnimation(
            animate: isListening,
            child: Container(
              width: sizes.speechDotSize,
              height: sizes.speechDotSize,
              decoration: BoxDecoration(
                color: isListening ? Colors.red : Colors.amber,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: HermesSpacing.sm * sizes.scale),

          // Status text
          Text(
            isListening ? 'Listening: ' : 'Processing: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize:
                  (theme.textTheme.bodySmall?.fontSize ?? 12) * sizes.scale,
            ),
          ),

          // Current text or placeholder
          Expanded(
            child:
                hasCurrentSpeech
                    ? ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 60 * sizes.scale),
                      child: SingleChildScrollView(
                        child: Text(
                          _currentPartialTranscript!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontStyle: FontStyle.italic,
                            fontSize:
                                (theme.textTheme.bodyMedium?.fontSize ?? 14) *
                                sizes.scale,
                          ),
                        ),
                      ),
                    )
                    : Text(
                      isListening
                          ? 'Start speaking...'
                          : 'Converting to text...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                        fontStyle: FontStyle.italic,
                        fontSize:
                            (theme.textTheme.bodyMedium?.fontSize ?? 14) *
                            sizes.scale,
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollToBottomButton(
    BuildContext context,
    ThemeData theme,
    _ResponsiveSizes sizes,
  ) {
    return Positioned(
      bottom: HermesSpacing.md * sizes.scale,
      right: HermesSpacing.md * sizes.scale,
      child: SizedBox(
        width: sizes.fabSize,
        height: sizes.fabSize,
        child: FloatingActionButton(
          onPressed: _scrollToBottom,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          elevation: 2,
          mini: true,
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: (sizes.fabSize * 0.6).clamp(16, 24),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(
    BuildContext context,
    ThemeData theme,
    _ResponsiveSizes sizes,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24 * sizes.scale,
            height: 24 * sizes.scale,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(height: HermesSpacing.md * sizes.scale),
          Text(
            'Initializing transcript...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
              fontSize:
                  (theme.textTheme.bodyMedium?.fontSize ?? 14) * sizes.scale,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    ThemeData theme,
    Object error,
    _ResponsiveSizes sizes,
  ) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(HermesSpacing.lg * sizes.scale),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48 * sizes.scale,
              color: theme.colorScheme.error,
            ),
            SizedBox(height: HermesSpacing.md * sizes.scale),
            Text(
              'Transcript Unavailable',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
                fontSize:
                    (theme.textTheme.titleMedium?.fontSize ?? 16) * sizes.scale,
              ),
            ),
            SizedBox(height: HermesSpacing.xs * sizes.scale),
            Text(
              'Unable to display speech transcript',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
                fontSize:
                    (theme.textTheme.bodyMedium?.fontSize ?? 14) * sizes.scale,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // [Rest of the existing methods remain the same...]
  void _updateTranscripts(state) {
    final currentTranscript = state.lastTranscript;
    final isListening = state.status == HermesStatus.listening;
    final isTranslating = state.status == HermesStatus.translating;

    // Track if user has ever spoken
    if (currentTranscript != null && currentTranscript.isNotEmpty) {
      _hasEverSpoken = true;
    }

    // Handle partial transcripts (during listening)
    if (isListening &&
        currentTranscript != null &&
        currentTranscript.isNotEmpty) {
      setState(() {
        _currentPartialTranscript = currentTranscript;
      });
    }
    // Handle final transcripts - catch both translating and non-listening states
    else if (currentTranscript != null &&
        currentTranscript.isNotEmpty &&
        currentTranscript != _lastProcessedTranscript &&
        (isTranslating || !isListening)) {
      setState(() {
        _messages.add(
          TranscriptMessage(text: currentTranscript, timestamp: DateTime.now()),
        );

        _currentPartialTranscript = null;

        // Keep only last 50 messages
        if (_messages.length > 50) {
          _messages.removeAt(0);
        }
      });

      _lastProcessedTranscript = currentTranscript;

      // Auto-scroll if user hasn't manually scrolled
      if (!_userHasScrolledUp) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    }
    // Clear partial transcript when not listening or translating
    else if (!isListening && !isTranslating) {
      setState(() {
        _currentPartialTranscript = null;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: HermesDurations.fast,
        curve: Curves.easeOut,
      );
    }
  }

  IconData _getHeaderIcon(HermesStatus status) {
    switch (status) {
      case HermesStatus.listening:
        return HermesIcons.listening;
      case HermesStatus.translating:
        return HermesIcons.translating;
      default:
        return HermesIcons.microphone;
    }
  }

  String _getHeaderTitle(HermesStatus status, bool hasEverSpoken) {
    switch (status) {
      case HermesStatus.listening:
        return 'Listening';
      case HermesStatus.translating:
        return 'Processing Speech';
      case HermesStatus.buffering:
        return hasEverSpoken ? 'Speech History' : 'Speech Transcript';
      default:
        return hasEverSpoken ? 'Speech History' : 'Ready to Listen';
    }
  }

  String _getHeaderSubtitle(HermesStatus status, bool hasEverSpoken) {
    switch (status) {
      case HermesStatus.listening:
        return 'Your speech appears here in real-time';
      case HermesStatus.translating:
        return 'Converting speech to text...';
      case HermesStatus.buffering:
        return hasEverSpoken
            ? 'Your recent speech messages'
            : 'Start speaking to see your words here';
      default:
        return hasEverSpoken
            ? 'Your speech messages from this session'
            : 'Start speaking when you\'re ready';
    }
  }

  String _getEmptyStateTitle(HermesStatus status, bool hasEverSpoken) {
    if (hasEverSpoken) {
      return 'No recent messages';
    }

    switch (status) {
      case HermesStatus.listening:
        return 'Start speaking';
      case HermesStatus.buffering:
        return 'Ready to listen';
      default:
        return 'Welcome to your session';
    }
  }

  String _getEmptyStateSubtitle(HermesStatus status, bool hasEverSpoken) {
    if (hasEverSpoken) {
      return 'Your speech messages will appear here when you start talking';
    }

    switch (status) {
      case HermesStatus.listening:
        return 'Your words will appear here as you speak';
      case HermesStatus.buffering:
        return 'Getting ready to capture your speech';
      default:
        return 'Your speech will be displayed here as you talk, creating a real-time transcript for this session';
    }
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 10) {
      return 'Just now';
    } else if (difference.inMinutes < 1) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// Data model for transcript messages
class TranscriptMessage {
  final String text;
  final DateTime timestamp;

  const TranscriptMessage({required this.text, required this.timestamp});
}

/// Responsive sizing configuration
class _ResponsiveSizes {
  final double headerIconSize;
  final double statusDotSize;
  final double statusFontSize;
  final double emptyStateIconContainerSize;
  final double emptyStateIconSize;
  final double avatarSize;
  final double avatarIconSize;
  final double speechDotSize;
  final double fabSize;
  final double scale;
  final bool isSmallScreen;
  final bool isMediumScreen;
  final bool isLargeScreen;

  const _ResponsiveSizes({
    required this.headerIconSize,
    required this.statusDotSize,
    required this.statusFontSize,
    required this.emptyStateIconContainerSize,
    required this.emptyStateIconSize,
    required this.avatarSize,
    required this.avatarIconSize,
    required this.speechDotSize,
    required this.fabSize,
    required this.scale,
    required this.isSmallScreen,
    required this.isMediumScreen,
    required this.isLargeScreen,
  });
}
