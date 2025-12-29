import 'package:flutter/material.dart';

/// Widget to display text with highlighted @mentions
class MentionText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? mentionStyle;

  const MentionText({
    super.key,
    required this.text,
    this.style,
    this.mentionStyle,
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle = style ?? TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color);
    final highlightStyle = mentionStyle ?? TextStyle(
      color: Colors.blue,
      fontWeight: FontWeight.bold,
    );

    // Parse text and find @mentions
    final mentionRegex = RegExp(r'@\w+');
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in mentionRegex.allMatches(text)) {
      // Add text before mention
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: defaultStyle));
      }
      // Add highlighted mention
      spans.add(TextSpan(text: match.group(0), style: highlightStyle));
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
