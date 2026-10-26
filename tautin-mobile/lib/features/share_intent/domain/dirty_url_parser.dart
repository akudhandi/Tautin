/// Output of [DirtyUrlParser.parse]: the first URL plus the leftover
/// promotional text that shared apps (Shopee/Tokopedia/TikTok) prepend.
class ParsedShareInput {
  const ParsedShareInput({required this.cleanUrl, this.rawDescription});

  /// First URL found in the shared text, free of surrounding punctuation.
  final String cleanUrl;

  /// Remaining campaign text without the URL (null when empty).
  final String? rawDescription;

  @override
  String toString() =>
      'ParsedShareInput(url: $cleanUrl, rawDescription: $rawDescription)';
}

/// Extracts the first `http(s)` URL out of dirty share text.
///
/// Per ARCHITECTURE section 6.2 the raw text is NEVER sent to the API as
/// `url`: apps like Shopee prepend promotional sentences that would pollute
/// both the duplicate-detection hash and the AI context. The first URL
/// becomes `cleanUrl` and everything else becomes `raw_description`.
class DirtyUrlParser {
  DirtyUrlParser._();

  /// Regex source: `(https?://[^\s\]>\"'` + backtick + `]+)`
  ///
  /// Equivalent behavior to `(https?:\/\/[^\s\)\]\>\"\'` + backtick + `]+)`:
  /// unescaped `/` and `)` are literals inside a class, so the class simply
  /// excludes whitespace, closing `]`, `)`, `>`, both quote characters and
  /// backticks. Rendered via hex escapes (`\x22`/`\x27`/`\x60`, plus hex
  /// backslash/bracket pairs) so the Dart string delimiters stay clean.
  static final RegExp urlPattern = RegExp(
    "(https?://[^\x5cs\x5c\x5d)>\x22\x27\x60]+)",
  );

  /// Sentence punctuation that commonly clings to shared URLs
  /// (`"buka https://example.com/menu."` — the trailing dot is not part of
  /// the address). Internal dots inside paths/domains are untouched.
  static final RegExp _trailingSentencePunctuation = RegExp(
    r'[.,;:!?\u2026\u3002]+$',
  );

  /// Parses [sharedText], returning null when no usable URL exists.
  static ParsedShareInput? parse(String sharedText) {
    final String trimmed = sharedText.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final RegExpMatch? match = urlPattern.firstMatch(trimmed);
    if (match == null) {
      return null;
    }

    final String rawUrl = match.group(0)!;
    final String cleanUrl =
        rawUrl.replaceFirst(_trailingSentencePunctuation, '');

    // A pinned target must at least have a host (`https://.` and friends
    // collapse to dead matches after punctuation trimming).
    final Uri? uri = Uri.tryParse(cleanUrl);
    if (uri == null || uri.host.isEmpty) {
      return null;
    }

    // Sentence may precede the URL ("Cek ini https://..."), so slice both
    // halves around the raw match before collapsing whitespace.
    final String before = trimmed.substring(0, match.start);
    final String after = trimmed.substring(match.start + rawUrl.length);
    final String joined =
        '$before $after'.replaceAll(RegExp(r'\s+'), ' ').trim();

    return ParsedShareInput(
      cleanUrl: cleanUrl,
      rawDescription: joined.isEmpty ? null : joined,
    );
  }
}
