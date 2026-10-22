import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, TextInputAction;
import 'package:hub/services/services.dart';
import 'package:hub/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────
const Color _kPrimary = Color(0xff2563EB);
const Color _kSecondary = Color(0xff4F46E5);
const Color _kAccent = Color(0xff22D3EE);
const Color _kBg = Color(0xffF7F9FC);
const Color _kBorder = Color(0xffE8ECF2);
const Color _kInk = Color(0xff0F172A);
const Color _kMuted = Color(0xff94A3B8);
const Color _kTabTrack = Color(0xffF1F5F9);

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  static const List<String> _kMonthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final List<ChatMessage> _messages = [];

  final TextEditingController _textController = TextEditingController();
  final TextEditingController _faqSearchController = TextEditingController();

  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isTyping = false;
  bool _hasText = false;
  bool _showScrollButton = false;

// FAQ state
  List<AssistantFaq> _faqs = [];
  bool _isLoadingFaqs = false;
  bool _showFaqs = false;
  String? _faqError;
  String _faqSearchQuery = '';
  int? _expandedFaqId;

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

  // ───────────────────────────────────────────────────────────
  // Lifecycle
  // ───────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _textController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    _scrollController.addListener(_onScroll);
    _faqSearchController.addListener(_onFaqSearchChanged);

    _init();
    _loadFaqs();
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _scrollController.removeListener(_onScroll);
    _faqSearchController.removeListener(_onFaqSearchChanged);

    _textController.dispose();
    _faqSearchController.dispose();
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

    final show =
        _scrollController.position.pixels <
            _scrollController.position.maxScrollExtent - 140;

    if (show != _showScrollButton) {
      setState(() => _showScrollButton = show);
    }
  }

  void _onFaqSearchChanged() {
    if (!mounted) return;

    setState(() {
      _faqSearchQuery = _faqSearchController.text.trim();
    });
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
        userFirstName =
            prefs.getString('first_name') ??
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

  // ───────────────────────────────────────────────────────────
  // Current month label
  // ───────────────────────────────────────────────────────────
  String get _currentMonthLabel {
    final now = DateTime.now();
    return '${_kMonthNames[now.month - 1]} ${now.year}';
  }

  /// Turns "Generate a report." → "Generate a report for October 2026."
  String _withCurrentMonth(String basePrompt) {
    final trimmed = basePrompt.trimRight();
    final body = trimmed.endsWith('.')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    return '$body for $_currentMonthLabel.';
  }

  // ───────────────────────────────────────────────────────────
  // FAQ loading
  // ───────────────────────────────────────────────────────────
  Future<void> _loadFaqs() async {
    if (_isLoadingFaqs) return;

    if (mounted) {
      setState(() {
        _isLoadingFaqs = true;
        _faqError = null;
      });
    }

    try {
      final faqs = await ChatbotService.getFaqs();

      // debugPrint('Kejahub FAQs loaded: ${faqs.length}');

      if (!mounted) return;

      setState(() {
        _faqs = faqs;
        _isLoadingFaqs = false;
        _faqError = faqs.isEmpty
            ? 'The server returned no usable FAQs.'
            : null;

        // Clear the expanded item if it no longer exists.
        if (_expandedFaqId != null &&
            !faqs.any((faq) => faq.id == _expandedFaqId)) {
          _expandedFaqId = null;
        }
      });
    } catch (e, stackTrace) {
      // debugPrint('Failed to load Kejahub FAQs: $e');
      // debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _isLoadingFaqs = false;
        _faqError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<AssistantFaq> get _filteredFaqs {
    final query = _faqSearchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _faqs;
    }

    return _faqs.where((faq) {
      final category = faq.category ?? '';

      return faq.question.toLowerCase().contains(query) ||
          faq.answer.toLowerCase().contains(query) ||
          category.toLowerCase().contains(query);
    }).toList();
  }

  // ───────────────────────────────────────────────────────────
  // Tab switching
  // ───────────────────────────────────────────────────────────
  void _selectChatTab() {
    if (!_showFaqs) return;

    FocusScope.of(context).unfocus();
    setState(() => _showFaqs = false);
  }

  void _selectFaqTab() {
    if (_showFaqs) return;

    FocusScope.of(context).unfocus();
    setState(() => _showFaqs = true);

    if (_faqs.isEmpty && !_isLoadingFaqs) {
      _loadFaqs();
    }
  }

  // ───────────────────────────────────────────────────────────
  // Sending messages
  // ───────────────────────────────────────────────────────────
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
      _showFaqs = false;
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

  // ───────────────────────────────────────────────────────────
  // New chat
  // ───────────────────────────────────────────────────────────
  void _newChat() {
    if (_messages.isEmpty && !_showFaqs) return;

    if (_isTyping) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Start a new chat?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Your current conversation will be cleared.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
                _startNewChat();
              },
              child: const Text('New Chat'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startNewChat() async {
    try {
      await ChatbotService.startNewConversation();
    } catch (_) {
      // Clear the local chat even if resetting the conversation ID fails.
    }

    if (!mounted) return;

    setState(() {
      _messages.clear();
      _isTyping = false;
      _showFaqs = false;
      _showScrollButton = false;
    });

    _textController.clear();
    _hasText = false;

    _scrollToBottom();
  }

  // ───────────────────────────────────────────────────────────
  // Build
  // ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final showScrollBtn = _showScrollButton && !_showFaqs;

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
                    child: _showFaqs
                        ? _buildFaqView()
                        : _messages.isEmpty
                        ? _buildWelcomeView()
                        : _buildConversation(),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: AnimatedSlide(
                      offset: showScrollBtn
                          ? Offset.zero
                          : const Offset(0, 0.5),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: AnimatedOpacity(
                        opacity: showScrollBtn ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: IgnorePointer(
                          ignoring: !showScrollBtn,
                          child: _ScrollToBottomButton(onTap: _scrollToBottom),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!_showFaqs) _buildComposer(),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // App bar (with side-by-side Chat / FAQ tabs)
  // ───────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.black87,
      titleSpacing: 16,
      toolbarHeight: 66,
      shape: const Border(bottom: BorderSide(color: _kBorder)),
      title: Row(
        children: [
          const _PulsingLogo(size: 40, borderRadius: 13, iconSize: 20),
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
                    _showFaqs ? 'Help Centre' : 'Property Manager',
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
          icon: const Icon(Icons.add_comment_outlined, size: 21),
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: _buildTabSwitcher(),
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: _kTabTrack,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabItem(
              label: 'Chat',
              icon: Icons.chat_bubble_outline_rounded,
              selected: !_showFaqs,
              onTap: _selectChatTab,
            ),
          ),
          Expanded(
            child: _buildTabItem(
              label: 'FAQ',
              icon: Icons.quiz_outlined,
              selected: _showFaqs,
              onTap: _selectFaqTab,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        height: 40,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          // Selected tab: solid blue background.
          // Unselected tab: transparent.
          color: selected ? _kPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
            BoxShadow(
              color: _kPrimary.withValues(alpha: 0.30),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : _kMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? Colors.white : _kMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // FAQ view
  // ───────────────────────────────────────────────────────────
  Widget _buildFaqView() {
    final filteredFaqs = _filteredFaqs;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth > 900 ? 70.0 : 16.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            24,
            horizontalPadding,
            28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_kPrimary, _kSecondary],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.help_outline_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Frequently asked questions',
                              style: TextStyle(
                                color: _kInk,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Find answers about managing your properties.',
                              style: TextStyle(color: _kMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh FAQs',
                        onPressed: _isLoadingFaqs ? null : _loadFaqs,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // FAQ search
                  TextField(
                    controller: _faqSearchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search questions or topics...',
                      hintStyle: const TextStyle(fontSize: 12, color: _kMuted),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: _kMuted,
                      ),
                      suffixIcon: _faqSearchQuery.isNotEmpty
                          ? IconButton(
                        tooltip: 'Clear search',
                        onPressed: _faqSearchController.clear,
                        icon: const Icon(Icons.close_rounded, size: 18),
                      )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(
                          color: _kPrimary,
                          width: 1.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_isLoadingFaqs && _faqs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 70),
                      child: Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              color: _kPrimary,
                              strokeWidth: 2.5,
                            ),
                            SizedBox(height: 14),
                            Text(
                              'Loading frequently asked questions...',
                              style: TextStyle(color: _kMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_faqError != null && _faqs.isEmpty)
                    _buildFaqMessage(
                      icon: Icons.cloud_off_outlined,
                      message: _faqError!,
                      actionLabel: 'Try again',
                      onAction: _loadFaqs,
                    )
                  else if (filteredFaqs.isEmpty)
                      _buildFaqMessage(
                        icon: Icons.search_off_rounded,
                        message: _faqs.isEmpty
                            ? 'No FAQs have been configured yet.'
                            : 'No questions match your search.',
                        actionLabel: _faqs.isEmpty ? 'Refresh' : 'Clear search',
                        onAction: _faqs.isEmpty
                            ? _loadFaqs
                            : _faqSearchController.clear,
                      )
                    else ...[
                        Row(
                          children: [
                            const Text(
                              'Browse answers',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _kInk,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${filteredFaqs.length} '
                                  '${filteredFaqs.length == 1 ? 'question' : 'questions'}',
                              style: const TextStyle(fontSize: 10, color: _kMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...filteredFaqs.map(_buildFaqCard),
                      ],

                  const SizedBox(height: 14),
                  _buildAskAiCard(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFaqCard(AssistantFaq faq) {
    final expanded = _expandedFaqId == faq.id;
    final category = faq.category?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: expanded
                ? _kPrimary.withValues(alpha: 0.35)
                : _kBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: _kInk.withValues(alpha: 0.025),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  if (expanded) {
                    _expandedFaqId = null;
                  } else {
                    _expandedFaqId = faq.id;
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xffEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.question_mark_rounded,
                        color: _kPrimary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (category.isNotEmpty) ...[
                            Text(
                              category.toUpperCase(),
                              style: const TextStyle(
                                color: _kPrimary,
                                fontSize: 9,
                                letterSpacing: 0.7,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                          ],
                          Text(
                            faq.question,
                            style: const TextStyle(
                              color: _kInk,
                              fontSize: 12.5,
                              height: 1.45,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _kMuted,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(
                width: double.infinity,
              ),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(
                      height: 1,
                      color: _kBorder,
                    ),
                    const SizedBox(height: 13),
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        faq.answer,
                        style: const TextStyle(
                          color: Color(0xff475569),
                          fontSize: 12,
                          height: 1.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: _isTyping
                            ? null
                            : () => _sendPrompt(faq.question),
                        icon: const Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                        ),
                        label: const Text('Ask Kejahub AI'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kPrimary,
                          side: const BorderSide(
                            color: Color(0xffBFDBFE),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqMessage({
    required IconData icon,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: _kMuted, size: 35),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xff64748B),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildAskAiCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
          const Icon(Icons.auto_awesome_rounded, color: _kPrimary, size: 23),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need more help?',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Ask Kejahub AI about your own properties, '
                      'tenants, rent collections or maintenance.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: Color(0xff475569),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Ask Kejahub AI',
            onPressed: () {
              setState(() {
                _showFaqs = false;
              });

              FocusScope.of(context).requestFocus(_focusNode);
            },
            icon: const Icon(Icons.chat_rounded, color: _kPrimary),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // Welcome
  // ───────────────────────────────────────────────────────────
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
        // Tapping a suggestion now appends the current month.
        onTap: () => _sendPrompt(_withCurrentMonth(prompt.prompt)),
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
                child: Icon(prompt.icon, color: prompt.color, size: 18),
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

  // ───────────────────────────────────────────────────────────
  // Conversation
  // ───────────────────────────────────────────────────────────
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

  // ───────────────────────────────────────────────────────────
  // Composer
  // ───────────────────────────────────────────────────────────
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
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(
                        LogicalKeyboardKey.enter,
                        includeRepeats: false,
                      ): _sendMessage,
                      const SingleActivator(
                        LogicalKeyboardKey.numpadEnter,
                        includeRepeats: false,
                      ): _sendMessage,
                    },
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      enabled: !_isTyping,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
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
                          color: canSend ? Colors.white : Colors.grey.shade400,
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
            style: TextStyle(fontSize: 9, color: Color(0xffA1A9B5)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Scroll-to-bottom pill
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
// AI thinking bubble
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

      setState(() {
        _index = (_index + 1) % _statuses.length;
      });
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
// Rotating gradient orb
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
          RotationTransition(
            turns: _controller,
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [_kPrimary, _kSecondary, _kAccent, _kPrimary],
                ),
              ),
            ),
          ),
          Container(
            width: size - 5,
            height: size - 5,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          Icon(Icons.auto_awesome, size: size * 0.42, color: _kSecondary),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Bouncing typing dots
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
// Pulsing gradient logo
// ─────────────────────────────────────────────────────────────
class _PulsingLogo extends StatefulWidget {
  const _PulsingLogo({required this.size, this.borderRadius, this.iconSize});

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
// Live online pulsing dot
// ─────────────────────────────────────────────────────────────
class _LiveDot extends StatefulWidget {
  const _LiveDot({this.size = 7, this.color = const Color(0xff22C55E)});

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
// Entrance animation helper
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
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Prompt model
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