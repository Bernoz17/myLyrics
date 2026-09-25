import 'dart:convert';
import 'package:http/http.dart' as http;

class SupabaseWidgetState {
  final int phraseId;
  final String testo;
  final String titolo;
  final String artista;
  final String bgColor;
  final String textColor;
  final String fontStyle;
  final DateTime? updatedAt;

  const SupabaseWidgetState({
    required this.phraseId,
    required this.testo,
    required this.titolo,
    required this.artista,
    required this.bgColor,
    required this.textColor,
    required this.fontStyle,
    this.updatedAt,
  });

  factory SupabaseWidgetState.fromJson(Map<String, dynamic> json) {
    return SupabaseWidgetState(
      phraseId: (json['phrase_id'] as num?)?.toInt() ?? 0,
      testo: json['testo']?.toString() ?? '',
      titolo: json['titolo']?.toString() ?? '',
      artista: json['artista']?.toString() ?? '',
      bgColor: json['bg_color']?.toString() ?? '000000',
      textColor: json['text_color']?.toString() ?? 'FFFFFF',
      fontStyle: json['font_style']?.toString() ?? 'default',
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.tryParse(json['updated_at'].toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': 1,
        'phrase_id': phraseId,
        'testo': testo,
        'titolo': titolo,
        'artista': artista,
        'bg_color': bgColor,
        'text_color': textColor,
        'font_style': fontStyle,
        'updated_at': updatedAt?.toUtc().toIso8601String() ??
            DateTime.now().toUtc().toIso8601String(),
      };
}

class SupabaseWidgetService {
  SupabaseWidgetService._();
  static final instance = SupabaseWidgetService._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  bool get isConfigured =>
      url.startsWith('https://') && publishableKey.isNotEmpty;

  Uri get _uri => Uri.parse(
        '${url.replaceAll(RegExp(r'/$'), '')}/rest/v1/mylyrics_widget_state',
      );

  Map<String, String> get _headers => {
        'apikey': publishableKey,
        'Authorization': 'Bearer $publishableKey',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  void _checkConfig() {
    if (!isConfigured) {
      throw const SupabaseWidgetException(
        'Supabase non configurato. Imposta SUPABASE_URL e '
        'SUPABASE_PUBLISHABLE_KEY in Codemagic.',
      );
    }
  }

  Future<SupabaseWidgetState?> getState() async {
    _checkConfig();

    final uri = _uri.replace(queryParameters: {
      'select':
          'id,phrase_id,testo,titolo,artista,bg_color,text_color,font_style,updated_at',
      'id': 'eq.1',
      'limit': '1',
    });

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw SupabaseWidgetException(
        'Supabase ${response.statusCode}: ${response.body}',
      );
    }

    final rows = jsonDecode(response.body) as List<dynamic>;
    if (rows.isEmpty) return null;

    return SupabaseWidgetState.fromJson(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }

  Future<SupabaseWidgetState> upsert(SupabaseWidgetState state) async {
    _checkConfig();

    final response = await http.post(
      _uri,
      headers: {
        ..._headers,
        'Prefer': 'resolution=merge-duplicates,return=representation',
      },
      body: jsonEncode(state.toJson()),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw SupabaseWidgetException(
        'Supabase ${response.statusCode}: ${response.body}',
      );
    }

    final rows = jsonDecode(response.body) as List<dynamic>;
    if (rows.isEmpty) return state;

    return SupabaseWidgetState.fromJson(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }

  Future<SupabaseWidgetState> setPhrase(
    Map<String, dynamic> phrase, {
    SupabaseWidgetState? existing,
  }) {
    return upsert(
      SupabaseWidgetState(
        phraseId: (phrase['id'] as num?)?.toInt() ?? 0,
        testo: phrase['testo']?.toString() ?? '',
        titolo: phrase['titolo']?.toString() ?? '',
        artista: phrase['artista']?.toString() ?? '',
        bgColor: existing?.bgColor ?? '000000',
        textColor: existing?.textColor ?? 'FFFFFF',
        fontStyle: existing?.fontStyle ?? 'default',
      ),
    );
  }

  Future<SupabaseWidgetState> setStyle({
    required String bgColor,
    required String textColor,
    required String fontStyle,
    SupabaseWidgetState? existing,
  }) {
    return upsert(
      SupabaseWidgetState(
        phraseId: existing?.phraseId ?? 0,
        testo: existing?.testo ?? '',
        titolo: existing?.titolo ?? '',
        artista: existing?.artista ?? '',
        bgColor: bgColor,
        textColor: textColor,
        fontStyle: fontStyle,
      ),
    );
  }
}

class SupabaseWidgetException implements Exception {
  final String message;
  const SupabaseWidgetException(this.message);

  @override
  String toString() => message;
}
