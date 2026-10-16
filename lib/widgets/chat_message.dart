import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hub/widgets/widgets.dart';

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;

  final bool chartRequested;
  final String? chartType;

  final List<Map<String, dynamic>> chartRecords;

  final Map<String, dynamic>? chartData;

  final Map<String, dynamic>? chartPeriod;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
    this.chartRequested = false,
    this.chartType,
    this.chartRecords = const [],
    this.chartData,
    this.chartPeriod,
  });

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      return _buildUserMessage();
    }

    return _buildAssistantMessage();
  }

  // ============================================================
  // USER MESSAGE
  // ============================================================

  Widget _buildUserMessage() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xff2563EB), Color(0xff4F46E5)],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.13),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ASSISTANT MESSAGE
  // ============================================================

  Widget _buildAssistantMessage() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --------------------------------------------------------
        // AI ICON
        // --------------------------------------------------------

        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff2563EB), Color(0xff4F46E5)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
        ),

        const SizedBox(width: 9),

        // --------------------------------------------------------
        // MESSAGE + CHART
        // --------------------------------------------------------

        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 760),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: const Color(0xffE8ECF2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildText(),

                // ------------------------------------------------
                // CHART
                // ------------------------------------------------

                if (chartRequested && chartRecords.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  AiChart(
                    chartType: chartType,
                    records: chartRecords,
                    chartData: chartData,
                    chartPeriod: chartPeriod,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MARKDOWN RESPONSE
  // ============================================================

  Widget _buildText() {
    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        // --------------------------------------------------------
        // NORMAL PARAGRAPH
        // --------------------------------------------------------

        p: const TextStyle(
          fontSize: 13,
          height: 1.55,
          color: Color(0xff1F2937),
        ),

        // --------------------------------------------------------
        // HEADINGS
        // --------------------------------------------------------

        h1: const TextStyle(
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w800,
          color: Color(0xff111827),
        ),

        h2: const TextStyle(
          fontSize: 18,
          height: 1.3,
          fontWeight: FontWeight.w800,
          color: Color(0xff111827),
        ),

        h3: const TextStyle(
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w700,
          color: Color(0xff111827),
        ),

        h4: const TextStyle(
          fontSize: 15,
          height: 1.35,
          fontWeight: FontWeight.w700,
          color: Color(0xff111827),
        ),

        // --------------------------------------------------------
        // BOLD TEXT
        // --------------------------------------------------------

        strong: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xff111827),
        ),

        // --------------------------------------------------------
        // EMPHASIZED TEXT
        // --------------------------------------------------------

        em: const TextStyle(
          fontStyle: FontStyle.italic,
          color: Color(0xff374151),
        ),

        // --------------------------------------------------------
        // BULLET LIST
        // --------------------------------------------------------

        listBullet: const TextStyle(
          fontSize: 13,
          height: 1.55,
          color: Color(0xff374151),
        ),

        // --------------------------------------------------------
        // LINKS
        // --------------------------------------------------------

        a: const TextStyle(
          color: Color(0xff2563EB),
          decoration: TextDecoration.underline,
        ),

        // --------------------------------------------------------
        // CODE
        // --------------------------------------------------------

        code: TextStyle(
          fontSize: 12,
          color: const Color(0xff374151),
          backgroundColor: const Color(0xffF3F4F6),
        ),

        // --------------------------------------------------------
        // BLOCKQUOTE
        // --------------------------------------------------------

        blockquote: const TextStyle(
          fontSize: 13,
          height: 1.5,
          color: Color(0xff4B5563),
        ),

        // --------------------------------------------------------
        // TABLE
        // --------------------------------------------------------

        tableBody: const TextStyle(
          fontSize: 12,
          height: 1.4,
          color: Color(0xff374151),
        ),

        tableHead: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xff111827),
        ),

        // --------------------------------------------------------
        // SPACING
        // --------------------------------------------------------

        h1Padding: const EdgeInsets.only(top: 4, bottom: 8),
        h2Padding: const EdgeInsets.only(top: 4, bottom: 7),
        h3Padding: const EdgeInsets.only(top: 3, bottom: 6),
        pPadding: const EdgeInsets.only(bottom: 6),
        listIndent: 18,
      ),
    );
  }
}