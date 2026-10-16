import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hub/services/services.dart';
import 'package:hub/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────
//  Design tokens
// ─────────────────────────────────────────────────────────────
const Color _kPrimary = Color(0xff2563EB);
const Color _kSecondary = Color(0xff4F46E5);
const Color _kAccent = Color(0xff22D3EE);
const Color _kBg = Color(0xffF7F9FC);
const Color _kBorder = Color(0xffE8ECF2);
const Color _kInk = Color(0xff0F172A);
const Color _kMuted = Color(0xff94A3B8);

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  final List<ChatMessage> _messages = [];

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isTyping = false;
  bool _hasText = false;
  bool _showScrollButton = false;

  String? userFirstName;
  String? userID;

  bool isLoadingUser = true;

  final List<_ChatPrompt> _prompts = [
    _ChatPrompt(
      title: 'Revenue',
      subtitle: 'Analyze rental revenue',
      icon: Icons.payments_outlined,
      color: Colors.green,
      prompt: 'Generate a revenue report for my apartments.',
    ),
    _ChatPrompt(
      title: 'Occupancy',
      subtitle: 'View occupancy performance',
      icon: Icons.apartment_outlined,
      color: Colors.blue,
      prompt: 'Create a report on the occupancy rate of my properties.',
    ),
    _ChatPrompt(
      title: 'Outstanding',
      subtitle: 'Identify unpaid rent',
      icon: Icons.receipt_long_outlined,
      color: Colors.orange,
      prompt: 'Show me a report of outstanding rent across my properties.',
    ),
    _ChatPrompt(
      title: 'Maintenance',
      subtitle: 'Review maintenance issues',
      icon: Icons.build_outlined,
      color: Colors.red,
      prompt: 'Give me a summary of the current maintenance issues.',
    ),
    _ChatPrompt(
      title: 'Performance',
      subtitle: 'Compare properties',
      icon: Icons.analytics_outlined,
      color: Colors.purple,
      prompt: 'Compare the performance of my properties.',
    ),
    _ChatPrompt(
      title: 'Tenants',
      subtitle: 'Analyze your tenants',
      icon: Icons.people_outline,
      color: Colors.teal,
      prompt: 'Give me an analysis of my tenants and occupancy.',
    ),
  ];

  // ── Lifecycle ──────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    _scrollController.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _scrollController.removeListener(_onScroll);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final has = _textController.text.trim().isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
    }
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final show = _scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 140;
    if (show != _showScrollButton) {
      setState(() => _showScrollButton = show);
    }
  }

  Future<void> _init() async {
    await _loadUserData();

    userID = await getUserId();

    if (mounted) {
      setState(() {});
    }
  }

  Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return prefs.getString('user_id') ??
          prefs.getString('userId') ??
          prefs.getString('id');
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final fullName = prefs.getString('name');

      if (fullName != null && fullName.trim().isNotEmpty) {
        userFirstName = fullName.trim().split(' ').first;
      } else {
        userFirstName = prefs.getString('first_name') ??
            prefs.getString('firstName') ??
            'there';
      }

      if (mounted) {
        setState(() {
          isLoadingUser = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          userFirstName = 'there';
          isLoadingUser = false;
        });
      }
    }
  }

  // ── Sending ────────────────────────────────────────────────
  Future<void> _sendMessage() async {
    final text = _textController.text.trim();

    if (text.isEmpty || _isTyping) return;

    await _sendPrompt(text);
  }

  Future<void> _sendPrompt(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isTyping) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _messages.add(ChatMessage(text: trimmed, isUser: true));
      _textController.clear();
      _hasText = false;
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      final result = await ChatbotService.sendMessage(
        userId: userID,
        message: trimmed,
      );

      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            text: result.reply,
            isUser: false,
            chartRequested: result.chartRequested,
            chartType: result.chartType,
            chartData: result.chartData,
            chartRecords: result.chartRecords,
            chartPeriod: result.chartPeriod,
          ),
        );

        _isTyping = false;
      });

      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isTyping = false;

        _messages.add(
          const ChatMessage(
            text:
            'Sorry, I couldn’t process your request right now. Please try again.',
            isUser: false,
          ),
        );
      });

      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _newChat() {
    if (_messages.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Start a new chat?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Your current conversation will be cleared.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);

                setState(() {
                  _messages.clear();
                  _isTyping = false;
                });
              },
              child: const Text('New Chat'),
            ),
          ],
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _messages.isEmpty
                        ? _buildWelcomeView()
                        : _buildConversation(),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: AnimatedSlide(
                      offset: _showScrollButton
                          ? Offset.zero
                          : const Offset(0, 0.5),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: AnimatedOpacity(
                        opacity: _showScrollButton ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: IgnorePointer(
                          ignoring: !_showScrollButton,
                          child: _ScrollToBottomButton(
                            onTap: _scrollToBottom,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.black87,
      titleSpacing: 16,
      toolbarHeight: 66,
      shape: const Border(
        bottom: BorderSide(color: _kBorder),
      ),
      title: Row(
        children: [
          const _PulsingLogo(
            size: 40,
            borderRadius: 13,
            iconSize: 20,
          ),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Kejahub AI',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const _LiveDot(size: 6.5),
                  const SizedBox(width: 6),
                  Text(
                    'Property Manager',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'New chat',
          onPressed: _newChat,
          icon: const Icon(
            Icons.add_comment_outlined,
            size: 21,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ── Welcome ────────────────────────────────────────────────
  Widget _buildWelcomeView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth > 900 ? 80.0 : 20.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            34,
            horizontalPadding,
            25,
          ),
          child: Column(
            children: [
              _FadeSlideIn(
                child: const _PulsingLogo(
                  size: 78,
                  borderRadius: 26,
                  iconSize: 36,
                ),
              ),
              const SizedBox(height: 22),
              _FadeSlideIn(
                delay: const Duration(milliseconds: 70),
                child: Text(
                  'Hello ${isLoadingUser ? '' : (userFirstName ?? 'there')} 👋',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.5,
                    color: _kInk,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _FadeSlideIn(
                delay: const Duration(milliseconds: 120),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Text(
                    'Your intelligent property management assistant. '
                        'Ask questions about revenue, tenants, rent, occupancy and maintenance.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _FadeSlideIn(
                delay: const Duration(milliseconds: 170),
                child: Row(
                  children: [
                    const Text(
                      'Try asking',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '6 suggestions',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildPromptGrid(),
              const SizedBox(height: 24),
              _FadeSlideIn(
                delay: const Duration(milliseconds: 320),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xffEFF6FF), Color(0xffF5F3FF)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xffDBEAFE)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: [
                            BoxShadow(
                              color: _kPrimary.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lightbulb_outline,
                          color: _kPrimary,
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'You can also ask for charts and comparisons, such as '
                              '"Show my collections for the last 6 months."',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.45,
                            color: Color(0xff1E40AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPromptGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _prompts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 3 : 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: isWide ? 2.5 : 1.55,
          ),
          itemBuilder: (context, index) {
            return _FadeSlideIn(
              delay: Duration(milliseconds: 200 + (index * 45)),
              child: _buildPromptCard(_prompts[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildPromptCard(_ChatPrompt prompt) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _sendPrompt(prompt.prompt),
        borderRadius: BorderRadius.circular(16),
        splashColor: prompt.color.withValues(alpha: 0.10),
        highlightColor: prompt.color.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                color: _kInk.withValues(alpha: 0.03),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      prompt.color.withValues(alpha: 0.20),
                      prompt.color.withValues(alpha: 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  prompt.icon,
                  color: prompt.color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      prompt.title,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      prompt.subtitle,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 11,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Conversation ───────────────────────────────────────────
  Widget _buildConversation() {
    final itemCount = _messages.length + (_isTyping ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 22),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= _messages.length) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: _FadeSlideIn(child: _ThinkingBubble()),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _FadeSlideIn(child: _messages[index]),
        );
      },
    );
  }

  // ── Composer ───────────────────────────────────────────────
  Widget _buildComposer() {
    final canSend = _hasText && !_isTyping;
    final focused = _focusNode.hasFocus;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: _kBorder)),
        boxShadow: [
          BoxShadow(
            color: _kInk.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(maxWidth: 900),
            padding: const EdgeInsets.only(left: 16, right: 6),
            decoration: BoxDecoration(
              color: const Color(0xffF5F7FA),
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: focused
                    ? _kPrimary.withValues(alpha: 0.45)
                    : const Color(0xffE2E8F0),
                width: focused ? 1.4 : 1,
              ),
              boxShadow: focused
                  ? [
                BoxShadow(
                  color: _kPrimary.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ]
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    enabled: !_isTyping,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 13, color: _kInk),
                    decoration: InputDecoration(
                      hintText: _isTyping
                          ? 'Kejahub AI is responding…'
                          : 'Ask about your properties...',
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: _kMuted,
                      ),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 5),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: GestureDetector(
                    onTap: canSend ? _sendMessage : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: canSend
                            ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_kPrimary, _kSecondary],
                        )
                            : null,
                        color: canSend ? null : const Color(0xffE2E8F0),
                        shape: BoxShape.circle,
                        boxShadow: canSend
                            ? [
                          BoxShadow(
                            color: _kSecondary.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ]
                            : null,
                      ),
                      child: AnimatedScale(
                        scale: canSend ? 1 : 0.92,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          color: canSend
                              ? Colors.white
                              : Colors.grey.shade400,
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'AI can make mistakes. Verify important information.',
            style: TextStyle(
              fontSize: 9,
              color: Color(0xffA1A9B5),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Scroll-to-bottom pill
// ─────────────────────────────────────────────────────────────
class _ScrollToBottomButton extends StatelessWidget {
  const _ScrollToBottomButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                color: _kInk.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: Color(0xff475569),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  "AI is thinking" bubble
// ─────────────────────────────────────────────────────────────
class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble> {
  static const List<String> _statuses = [
    'Analyzing your portfolio',
    'Crunching the numbers',
    'Reviewing your properties',
    'Preparing your report',
  ];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2400), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _statuses.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _RotatingOrb(size: 32),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(6),
                ),
                border: Border.all(color: _kBorder),
                boxShadow: [
                  BoxShadow(
                    color: _kInk.withValues(alpha: 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _TypingDots(),
                  const SizedBox(width: 12),
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 380),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.4),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        _statuses[_index],
                        key: ValueKey<int>(_index),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Rotating gradient orb (AI avatar while thinking)
// ─────────────────────────────────────────────────────────────
class _RotatingOrb extends StatefulWidget {
  const _RotatingOrb({this.size = 32});

  final double size;

  @override
  State<_RotatingOrb> createState() => _RotatingOrbState();
}

class _RotatingOrbState extends State<_RotatingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // soft glow
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _kSecondary.withValues(alpha: 0.28),
                  blurRadius: 14,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          ),
          // spinning sweep gradient ring
          RotationTransition(
            turns: _controller,
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    _kPrimary,
                    _kSecondary,
                    _kAccent,
                    _kPrimary,
                  ],
                ),
              ),
            ),
          ),
          // inner disc
          Container(
            width: size - 5,
            height: size - 5,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          Icon(
            Icons.auto_awesome,
            size: size * 0.42,
            color: _kSecondary,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Bouncing typing dots
// ─────────────────────────────────────────────────────────────
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_controller.value + i * 0.18) % 1.0;
            final bounce = math.sin(t * math.pi).clamp(0.0, 1.0);

            return Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 4),
              child: Opacity(
                opacity: 0.45 + (0.55 * bounce),
                child: Transform.translate(
                  offset: Offset(0, -3.4 * bounce),
                  child: Container(
                    width: 6.5,
                    height: 6.5,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_kPrimary, _kSecondary],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Pulsing gradient logo
// ─────────────────────────────────────────────────────────────
class _PulsingLogo extends StatefulWidget {
  const _PulsingLogo({
    required this.size,
    this.borderRadius,
    this.iconSize,
  });

  final double size;
  final double? borderRadius;
  final double? iconSize;

  @override
  State<_PulsingLogo> createState() => _PulsingLogoState();
}

class _PulsingLogoState extends State<_PulsingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  late final Animation<double> _pulse = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? widget.size * 0.3;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final v = _pulse.value;

        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kPrimary, _kSecondary],
            ),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: _kSecondary.withValues(alpha: 0.16 + (0.22 * v)),
                blurRadius: 18 + (16 * v),
                spreadRadius: 0.5 + (1.5 * v),
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Icon(
        Icons.auto_awesome,
        color: Colors.white,
        size: widget.iconSize ?? widget.size * 0.46,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Live "online" pulsing dot
// ─────────────────────────────────────────────────────────────
class _LiveDot extends StatefulWidget {
  const _LiveDot({
    this.size = 7,
    this.color = const Color(0xff22C55E),
  });

  final double size;
  final Color color;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;

        return SizedBox(
          width: widget.size * 1.9,
          height: widget.size * 1.9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - t) * 0.45,
                child: Container(
                  width: widget.size + (widget.size * 0.9 * t),
                  height: widget.size + (widget.size * 0.9 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                  ),
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Entrance animation helper
// ─────────────────────────────────────────────────────────────
class _FadeSlideIn extends StatefulWidget {
  const _FadeSlideIn({
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.16),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _fade = curved;
    _slide = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(curved);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Prompt model
// ─────────────────────────────────────────────────────────────
class _ChatPrompt {
  final String title;
  final String subtitle;
  final String prompt;
  final IconData icon;
  final Color color;

  const _ChatPrompt({
    required this.title,
    required this.subtitle,
    required this.prompt,
    required this.icon,
    required this.color,
  });
}