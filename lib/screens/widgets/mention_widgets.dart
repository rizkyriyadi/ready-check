import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Widget to display text with highlighted @mentions (supports multi-word with underscore)
/// e.g., @rizky_riyadi will be highlighted and tappable
class MentionText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? mentionStyle;
  final Function(String name)? onMentionTap;

  const MentionText({
    super.key,
    required this.text,
    this.style,
    this.mentionStyle,
    this.onMentionTap,
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle = style ?? TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color);
    final highlightStyle = mentionStyle ?? const TextStyle(
      color: Colors.blue,
      fontWeight: FontWeight.bold,
    );

    // Parse text and find @mentions (supports underscores for multi-word names)
    // Format: @name_with_underscores
    final mentionRegex = RegExp(r'@[\w_]+');
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in mentionRegex.allMatches(text)) {
      // Add text before mention
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: defaultStyle));
      }
      
      // Get mention text and convert underscores back to spaces for display
      final mentionRaw = match.group(0)!;
      final mentionDisplay = mentionRaw.replaceAll('_', ' ');
      
      // Add highlighted mention (tappable if callback provided)
      if (onMentionTap != null) {
        spans.add(TextSpan(
          text: mentionDisplay,
          style: highlightStyle.copyWith(decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              // Extract name without @ and with spaces
              final name = mentionRaw.substring(1).replaceAll('_', ' ');
              onMentionTap!(name);
            },
        ));
      } else {
        spans.add(TextSpan(text: mentionDisplay, style: highlightStyle));
      }
      
      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: defaultStyle));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

/// Mention suggestion overlay
class MentionSuggestionOverlay extends StatelessWidget {
  final List<Map<String, dynamic>> suggestions;
  final Function(String name) onSelect;

  const MentionSuggestionOverlay({
    super.key,
    required this.suggestions,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final user = suggestions[index];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundImage: user['photoUrl'] != null && user['photoUrl'].isNotEmpty
                  ? NetworkImage(user['photoUrl'])
                  : null,
              child: user['photoUrl'] == null || user['photoUrl'].isEmpty
                  ? const Icon(Icons.person, size: 16)
                  : null,
            ),
            title: Text(user['displayName'] ?? 'Unknown'),
            onTap: () => onSelect(user['displayName'] ?? 'User'),
          );
        },
      ),
    );
  }
}
