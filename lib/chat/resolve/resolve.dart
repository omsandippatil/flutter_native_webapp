import 'package:flutter/foundation.dart';

import 'package:tapapp/chat/model/model.dart';
import 'package:tapapp/chat/submission/submission.dart';
import 'package:tapapp/core/course/course.dart';

const int kClassroomQuizPointsPerCorrectAnswer = 5;

class FlowNode {
  const FlowNode({
    required this.stepId,
    required this.type,
    this.displayText,
    this.voiceText,
    this.audioId,
    this.nextStep,
    this.nextRule,
    this.autoAdvanceMs,
    this.component,
    this.options = const [],
    this.fallbackGuide,
    this.passthrough = false,
    this.data = const {},
  });

  final String stepId;
  final String type;
  final String? displayText;
  final String? voiceText;
  final String? audioId;
  final String? nextStep;
  final Map<String, dynamic>? nextRule;
  final int? autoAdvanceMs;
  final String? component;
  final List<ChatOption> options;
  final String? fallbackGuide;
  final bool passthrough;
  final Map<String, dynamic> data;

  FlowNode copyWith({
    String? nextStep,
    Map<String, dynamic>? nextRule,
    bool? passthrough,
    Map<String, dynamic>? data,
  }) => FlowNode(
    stepId: stepId,
    type: type,
    displayText: displayText,
    voiceText: voiceText,
    audioId: audioId,
    nextStep: nextStep ?? this.nextStep,
    nextRule: nextRule ?? this.nextRule,
    autoAdvanceMs: autoAdvanceMs,
    component: component,
    options: options,
    fallbackGuide: fallbackGuide,
    passthrough: passthrough ?? this.passthrough,
    data: data ?? this.data,
  );

  factory FlowNode.fromJson(Map<String, dynamic> json) {
    final rawStepId = json['step_id'] ?? json['id'];
    final rawType = json['type'];
    final rawNext = json['next_step'];
    final rawRule = json['next_step_rule'];

    final knownKeys = <String>{
      'step_id',
      'id',
      'type',
      'display_text',
      'voice_text',
      'audio_id',
      'next_step',
      'next_step_rule',
      'on_correct',
      'on_wrong',
      'auto_advance_ms',
      'component',
      'options',
      'opts',
      'fallback_guide',
      'passthrough',
    };

    final data = <String, dynamic>{
      for (final entry in json.entries)
        if (!knownKeys.contains(entry.key)) entry.key: entry.value,
    };

    return FlowNode(
      stepId: rawStepId?.toString() ?? '',
      type: rawType?.toString() ?? 'static',
      displayText: json['display_text'] as String?,
      voiceText: json['voice_text'] as String?,
      audioId: json['audio_id'] as String?,
      nextStep: rawNext is String ? rawNext : null,
      nextRule: rawRule is Map ? Map<String, dynamic>.from(rawRule) : null,
      autoAdvanceMs: (json['auto_advance_ms'] as num?)?.toInt(),
      component: json['component'] as String?,
      options: _parseOptions(json['options'] ?? json['opts']),
      fallbackGuide: json['fallback_guide'] as String?,
      passthrough: json['passthrough'] as bool? ?? false,
      data: data,
    );
  }

  static List<ChatOption> _parseOptions(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map>().map((m) {
        final map = Map<String, dynamic>.from(m);
        return ChatOption(
          key: (map['key'] ?? map['value'])?.toString() ?? '',
          label: map['label']?.toString() ?? '',
          next: (map['next_step'] ?? map['next'])?.toString(),
        );
      }).toList(growable: false);
    }
    if (raw is Map) {
      return raw.entries
          .map(
            (e) => ChatOption(
              key: e.key.toString(),
              label: e.value.toString(),
            ),
          )
          .toList(growable: false);
    }
    return const [];
  }
}

class ResolvedFlowGraph {
  const ResolvedFlowGraph({required this.steps, required this.entryPoints});

  final Map<String, FlowNode> steps;
  final Map<String, String> entryPoints;
}

class FlowResolver {
  FlowResolver._();

  static ResolvedFlowGraph parse(Map<String, dynamic> flowJson) {
    final raw = flowJson['steps'];
    final nodes = <String, FlowNode>{};
    if (raw is List) {
      for (final entry in raw) {
        if (entry is! Map) {
          debugPrint('FlowResolver: skipped non-map step entry');
          continue;
        }
        try {
          final map = Map<String, dynamic>.from(entry);
          final node = _normalize(FlowNode.fromJson(map), map);
          if (node.stepId.isEmpty) {
            debugPrint('FlowResolver: skipped step without step_id or id');
            continue;
          }
          nodes[node.stepId] = node;
        } catch (error) {
          debugPrint('FlowResolver: skipped malformed step ($error)');
        }
      }
    }

    final rawEntryPoints = flowJson['entry_points'];
    final entryPoints = <String, String>{
      if (rawEntryPoints is Map)
        for (final entry in rawEntryPoints.entries)
          entry.key.toString(): entry.value.toString(),
    };

    return ResolvedFlowGraph(steps: nodes, entryPoints: entryPoints);
  }

  static FlowNode? step(Map<String, FlowNode> flow, String stepId) =>
      flow[stepId];

  static FlowNode _normalize(FlowNode node, Map<String, dynamic> raw) {
    var nextStep = node.nextStep;
    var rule = node.nextRule == null ? null : _normalizeRule(node.nextRule!);
    var data = node.data;

    if (node.type == 'action') {
      final success = _target(raw['on_success']);
      if (nextStep == null && rule == null && success != null) {
        nextStep = success;
      }
      final failure = _target(raw['on_failure']);
      if (failure != null) data = {...data, 'on_failure': failure};
    }

    if (rule == null && nextStep == null) {
      if (raw.containsKey('on_correct') || raw.containsKey('on_wrong')) {
        rule = <String, dynamic>{
          'when': 'answer',
          'correct': _target(raw['on_correct']),
          'wrong': _target(raw['on_wrong']),
        };
      } else if (node.options.any((o) => (o.next ?? '').isNotEmpty)) {
        rule = <String, dynamic>{
          'when': 'choice',
          'options': <String, dynamic>{
            for (final option in node.options)
              if ((option.next ?? '').isNotEmpty) option.key: option.next,
          },
        };
      }
    }

    return node.copyWith(nextStep: nextStep, nextRule: rule, data: data);
  }

  static Map<String, dynamic> _normalizeRule(Map<String, dynamic> rule) {
    if (rule.containsKey('when')) return rule;
    if (rule.containsKey('if_more_questions') ||
        rule.containsKey('if_last_question')) {
      return <String, dynamic>{
        'when': 'condition',
        'if': 'more_questions',
        'then': _target(rule['if_more_questions']),
        'otherwise': _target(rule['if_last_question']),
      };
    }
    if (rule.containsKey('if_more_units') ||
        rule.containsKey('if_last_unit')) {
      return <String, dynamic>{
        'when': 'condition',
        'if': 'var:more_units',
        'then': _target(rule['if_more_units']),
        'otherwise': _target(rule['if_last_unit']),
      };
    }
    return rule;
  }

  static String? _target(Object? value) {
    if (value == null) return null;
    if (value is Map) return (value['next_step'] ?? value['next'])?.toString();
    return value.toString();
  }
}

class FlowValidator {
  FlowValidator._();

  static final RegExp _token = RegExp(r'\{\{\s*([a-zA-Z0-9_]+)\s*\}\}');

  static List<String> validate(
    Map<String, FlowNode> flow, {
    required Set<String> entries,
    Set<ChatItemKind> boundKinds = const {},
    Set<String> knownTokens = const {},
    bool checkReachability = true,
  }) {
    final issues = <String>[];

    for (final entry in entries) {
      if (!flow.containsKey(entry)) {
        issues.add('entry step "$entry" not found in flow');
      }
    }

    for (final node in flow.values) {
      _checkTargets(node, flow, issues);
      _checkBinding(node, boundKinds, issues);
      _checkTokens(node, knownTokens, issues);
    }

    if (checkReachability) {
      final reachable = _reachableFrom(entries, flow);
      for (final stepId in flow.keys) {
        if (!reachable.contains(stepId)) {
          issues.add('step "$stepId" is unreachable from entries $entries');
        }
      }
    }

    return issues;
  }

  static void _checkTargets(
    FlowNode node,
    Map<String, FlowNode> flow,
    List<String> issues,
  ) {
    final targets = <String>{};

    final next = node.nextStep;
    if (next != null && next.isNotEmpty) targets.add(next);

    final rule = node.nextRule;
    if (rule != null) {
      _collectRuleTargets(rule).forEach(targets.add);
    }

    for (final option in node.options) {
      final optionNext = option.next;
      if (optionNext != null && optionNext.isNotEmpty) {
        targets.add(optionNext);
      }
    }

    final failure = node.data['on_failure'];
    if (failure is String && failure.isNotEmpty) targets.add(failure);

    for (final target in targets) {
      if (target == 'activity_flow' || target.startsWith('AF-')) continue;
      if (!flow.containsKey(target)) {
        issues.add(
          'step "${node.stepId}" references missing step "$target"',
        );
      }
    }
  }

  static Set<String> _collectRuleTargets(Map<String, dynamic> rule) {
    final targets = <String>{};

    void addIfString(Object? value) {
      if (value is String && value.isNotEmpty) targets.add(value);
    }

    addIfString(rule['correct']);
    addIfString(rule['wrong']);
    addIfString(rule['then']);
    addIfString(rule['otherwise']);
    addIfString(rule['next']);
    addIfString(rule['next_step']);

    final options = rule['options'] ?? rule['map'];
    if (options is Map) {
      for (final value in options.values) {
        addIfString(value);
      }
    }

    return targets;
  }

  static void _checkBinding(
    FlowNode node,
    Set<ChatItemKind> boundKinds,
    List<String> issues,
  ) {
    if (!ChatItemBuilder.needsBinding(node)) return;
    final kind = ChatItemBuilder.kindFor(node);
    if (!boundKinds.contains(kind)) {
      issues.add(
        'step "${node.stepId}" needs a content source binding for '
        '$kind but none is registered',
      );
    }
  }

  static void _checkTokens(
    FlowNode node,
    Set<String> knownTokens,
    List<String> issues,
  ) {
    if (knownTokens.isEmpty) return;
    final text = node.displayText;
    if (text == null || text.isEmpty) return;

    for (final match in _token.allMatches(text)) {
      final token = match.group(1)!;
      if (!knownTokens.contains(token)) {
        issues.add(
          'step "${node.stepId}" uses unknown token "{{$token}}"',
        );
      }
    }
  }

  static Set<String> _reachableFrom(
    Set<String> entries,
    Map<String, FlowNode> flow,
  ) {
    final visited = <String>{};
    final queue = <String>[...entries];

    while (queue.isNotEmpty) {
      final stepId = queue.removeLast();
      if (!visited.add(stepId)) continue;
      final node = flow[stepId];
      if (node == null) continue;

      final next = node.nextStep;
      if (next != null && flow.containsKey(next)) queue.add(next);

      final rule = node.nextRule;
      if (rule != null) {
        for (final target in _collectRuleTargets(rule)) {
          if (flow.containsKey(target)) queue.add(target);
        }
      }

      for (final option in node.options) {
        final optionNext = option.next;
        if (optionNext != null && flow.containsKey(optionNext)) {
          queue.add(optionNext);
        }
      }

      final failure = node.data['on_failure'];
      if (failure is String && flow.containsKey(failure)) {
        queue.add(failure);
      }
    }

    return visited;
  }
}

class TemplateContext {
  TemplateContext({
    required this.studentName,
    required this.unitName,
    required this.courseDisplay,
    this.videoDescription = '',
    this.videoPoints = 0,
    this.submissionPoints = 0,
    this.quizPoints = 0,
    this.quizQuestionCount = 0,
    DateTime? now,
  }) : _now = now;

  final String studentName;
  final String unitName;
  final String courseDisplay;
  final String videoDescription;
  final int videoPoints;
  final int submissionPoints;
  final int quizPoints;
  final int quizQuestionCount;
  final DateTime? _now;

  String get partOfDay {
    final hour = (_now ?? DateTime.now()).hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  Map<String, String> get tokens => {
    'name': studentName,
    'part_of_day': partOfDay,
    'unit_name': unitName,
    'course_display': courseDisplay,
    'video_description': videoDescription,
    'video_points': '$videoPoints',
    'submission_points': '$submissionPoints',
    'quiz_points': '$quizPoints',
    'quiz_question_count': '$quizQuestionCount',
  };
}

class TemplateResolver {
  TemplateResolver._();

  static final RegExp _token = RegExp(r'\{\{\s*([a-zA-Z0-9_]+)\s*\}\}');

  static String fill(
    String template,
    TemplateContext ctx, {
    Map<String, Object?>? extra,
  }) {
    final tokens = <String, String>{};
    extra?.forEach((key, value) {
      if (value is String || value is num || value is bool) {
        tokens[key] = '$value';
      }
    });
    tokens.addAll(ctx.tokens);

    return template.replaceAllMapped(_token, (match) {
      final key = match.group(1)!;
      final value = tokens[key];
      if (value == null) {
        debugPrint('TemplateResolver: unknown token "$key"');
        return match.group(0)!;
      }
      return value;
    });
  }
}

class ChatBindContext {
  const ChatBindContext({required this.id, required this.variables});

  final String id;
  final ChatVariables variables;
}

abstract class ChatContentSource {
  Set<ChatItemKind> get boundKinds;

  Future<ChatItem?> bind(FlowNode node, ChatBindContext ctx);
}

class ChatItemBuilder {
  ChatItemBuilder._();

  static final RegExp _effectTag = RegExp(
    r'\[(confetti)\]\s*',
    caseSensitive: false,
  );

  static final Map<String, ChatItemKind> _componentKinds = {
    'VideoPlayer': ChatItemKind.video,
    'SubmissionCard': ChatItemKind.submission,
    'SubmissionReview': ChatItemKind.submissionReview,
    'SubmissionReward': ChatItemKind.submissionReward,
    'QuizQuestion': ChatItemKind.quiz,
    'QuizCorrectFeedback': ChatItemKind.text,
    'QuizFeedback': ChatItemKind.text,
    'QuizSummary': ChatItemKind.quizSummary,
    'VerticalSelectCard': ChatItemKind.choice,
    'CourseSelectCard': ChatItemKind.choice,
    'ProfileVerifyCard': ChatItemKind.profileVerify,
    'SkillPassportCard': ChatItemKind.scorecard,
  };

  static void registerComponent(String componentName, ChatItemKind kind) {
    _componentKinds[componentName] = kind;
  }

  static ChatItemKind kindFor(FlowNode node) {
    final component = node.component;
    if (component != null && _componentKinds.containsKey(component)) {
      return _componentKinds[component]!;
    }
    if (component == null && node.type == 'static') {
      final mode = _str(node.data['input_mode']);
      if ((mode == 'buttons_only' || mode == 'radio') &&
          node.options.isNotEmpty) {
        return ChatItemKind.choice;
      }
      if (mode == 'form' || mode == 'free_text') return ChatItemKind.form;
    }
    if (node.type == 'action') return ChatItemKind.loading;
    return ChatItemKind.fromLegacyKey(node.type);
  }

  static bool needsBinding(FlowNode node) {
    final kind = kindFor(node);
    return kind == ChatItemKind.video ||
        kind == ChatItemKind.submission ||
        kind == ChatItemKind.quiz ||
        kind == ChatItemKind.choice ||
        kind == ChatItemKind.profileVerify ||
        kind == ChatItemKind.scorecard;
  }

  static bool isPassive(FlowNode node) =>
      kindFor(node) == ChatItemKind.submissionReview;

  static ChatItem fromFlowNode(
    FlowNode node,
    TemplateContext ctx, {
    required String id,
    ChatAudioRef? audio,
    Map<String, Object?> vars = const {},
  }) {
    final kind = kindFor(node);
    final data = node.data;
    final text = _fill(node.displayText, ctx, vars);

    return switch (kind) {
      ChatItemKind.text => _text(node, id, text, audio),
      ChatItemKind.image => ImageItem(
        id: id,
        stepId: node.stepId,
        sender: ChatSender.bot,
        src: _str(data['src']) ?? '',
        caption: text,
        alt: _str(data['alt']),
        audio: audio,
      ),
      ChatItemKind.divider => DividerItem(
        id: id,
        stepId: node.stepId,
        label: text ?? '',
        audio: audio,
      ),
      ChatItemKind.choice => ChoiceItem(
        id: id,
        stepId: node.stepId,
        layout: _str(data['layout']) ?? _layoutFor(node),
        options: node.options,
        text: text,
        audio: audio,
      ),
      ChatItemKind.form => FormItem(
        id: id,
        stepId: node.stepId,
        fields: _formFieldsFor(node),
        text: text,
        audio: audio,
      ),
      ChatItemKind.profileVerify => ProfileVerifyItem(
        id: id,
        stepId: node.stepId,
        fields: _stringMap(data['fields']),
        editable: _bool(data['editable']),
        text: text,
        audio: audio,
      ),
      ChatItemKind.scorecard => ScorecardItem(
        id: id,
        stepId: node.stepId,
        rows: _scoreRows(data['rows']),
        total: _str(data['total']),
        text: text,
        audio: audio,
      ),
      ChatItemKind.checkpoint => checkpoint(
        id: id,
        stepId: node.stepId,
        mode: _str(data['mode']) ?? 'prompt',
        buttonLabel: _str(data['button_label']) ?? 'Continue',
        action: _str(data['action']) ?? 'continue',
        image: _str(data['image']),
        text: text,
        sectionKind: _str(data['section_kind']) ?? 'generic',
        audio: audio,
      ),
      ChatItemKind.quizSummary => quizSummary(
        id: id,
        stepId: node.stepId,
        correct: _int(vars['quizCorrectCount']),
        total: _int(vars['quizTotal']),
        template: node.displayText,
        ctx: ctx,
        vars: vars,
        audio: audio,
      ),
      ChatItemKind.submissionReward => reward(
        id: id,
        stepId: node.stepId,
        studentName: ctx.studentName,
        points: ctx.submissionPoints,
        audio: audio,
      ),
      ChatItemKind.loading => LoadingItem(id: id, stepId: node.stepId),
      _ => error(
        id: id,
        stepId: node.stepId,
        message: text ?? 'Unsupported step: ${node.type}',
        audio: audio,
      ),
    };
  }

  static List<ChatItem> split(
    FlowNode node,
    ChatItem item,
    String Function() nextId,
  ) {
    final raw = node.displayText;
    if (item is! TextItem || raw == null || !raw.contains('|')) return [item];
    final parts = (item.text ?? '')
        .split('|')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length < 2) return [item];
    return [
      for (var i = 0; i < parts.length; i++)
        TextItem(
          id: i == 0 ? item.id : nextId(),
          stepId: item.stepId,
          sender: item.sender,
          text: parts[i],
          audio: i == 0 ? item.audio : null,
          meta: i == 0 ? item.meta : const {},
        ),
    ];
  }

  static CheckpointItem checkpoint({
    required String id,
    required String stepId,
    required String mode,
    required String buttonLabel,
    required String action,
    String? image,
    String? text,
    String sectionKind = 'generic',
    ChatAudioRef? audio,
  }) => CheckpointItem(
    id: id,
    stepId: stepId,
    mode: mode,
    buttonLabel: buttonLabel,
    action: action,
    image: image,
    sectionKind: sectionKind,
    text: text,
    audio: audio,
  );

  static QuizSummaryItem quizSummary({
    required String id,
    required String stepId,
    required int correct,
    required int total,
    String? template,
    TemplateContext? ctx,
    Map<String, Object?> vars = const {},
    ChatAudioRef? audio,
  }) => QuizSummaryItem(
    id: id,
    stepId: stepId,
    correct: correct,
    total: total,
    text: template == null
        ? null
        : (ctx == null
              ? template
              : TemplateResolver.fill(template, ctx, extra: vars)),
    audio: audio,
  );

  static SubmissionReviewItem review({
    required String id,
    required String stepId,
    required Map<String, Object?> payload,
    ChatAudioRef? audio,
  }) => SubmissionReviewItem(
    id: id,
    stepId: stepId,
    score: _intOrNull(payload['score']),
    passed: _bool(payload['passed']),
    feedback: _str(payload['feedback']),
    strengths: _stringList(payload['strengths']),
    improvements: _stringList(payload['improvements']),
    smsText: _str(payload['sms_text']),
    isFinalStep: _bool(payload['is_final_step']),
    text: _str(payload['text']),
    audio: audio,
  );

  static SubmissionRewardItem reward({
    required String id,
    required String stepId,
    required String studentName,
    required int points,
    ChatAudioRef? audio,
  }) => SubmissionRewardItem(
    id: id,
    stepId: stepId,
    studentName: studentName,
    points: points,
    audio: audio,
  );

  static LoadingItem loading({required String id, required String stepId}) =>
      LoadingItem(id: id, stepId: stepId);

  static ErrorItem error({
    required String id,
    required String stepId,
    required String message,
    String? retryAction,
    ChatAudioRef? audio,
  }) => ErrorItem(
    id: id,
    stepId: stepId,
    message: message,
    retryAction: retryAction,
    audio: audio,
  );

  static TextItem _text(
    FlowNode node,
    String id,
    String? text,
    ChatAudioRef? audio,
  ) {
    final stripped = _stripEffects(text ?? '');
    return TextItem(
      id: id,
      stepId: node.stepId,
      sender: ChatSender.bot,
      text: stripped.text,
      audio: audio,
      meta: stripped.effects.isEmpty
          ? const {}
          : <String, Object?>{'effects': stripped.effects},
    );
  }

  static ({String text, List<String> effects}) _stripEffects(String value) {
    final effects = _effectTag
        .allMatches(value)
        .map((m) => m.group(1)!.toLowerCase())
        .toList(growable: false);
    return (text: value.replaceAll(_effectTag, '').trim(), effects: effects);
  }

  static String _layoutFor(FlowNode node) {
    if (node.component != null) return 'cards';
    final mode = _str(node.data['input_mode']);
    if (mode == 'radio') return 'radio';
    if (mode == 'buttons_only' || node.type == 'choice_buttons') {
      return 'buttons';
    }
    return 'cards';
  }

  static List<ChatFormField> _formFieldsFor(FlowNode node) {
    final declared = _formFields(
      node.data['fields'] ?? node.data['form_fields'],
    );
    if (declared.isNotEmpty) return declared;
    if (_str(node.data['input_mode']) != 'free_text') return const [];
    final cache = node.data['cache_fields'];
    final key = cache is List && cache.isNotEmpty
        ? cache.first.toString()
        : 'value';
    return [
      ChatFormField(
        key: key,
        label: 'Your answer',
        type: 'text',
        required: true,
      ),
    ];
  }

  static String? _fill(
    String? template,
    TemplateContext ctx,
    Map<String, Object?> vars,
  ) => template == null
      ? null
      : TemplateResolver.fill(template, ctx, extra: vars).trim();

  static String? _str(Object? value) => value?.toString();

  static bool _bool(Object? value, {bool fallback = false}) =>
      value is bool ? value : fallback;

  static int _int(Object? value) => value is num ? value.toInt() : 0;

  static int? _intOrNull(Object? value) => value is num ? value.toInt() : null;

  static List<String> _stringList(Object? raw) => raw is List
      ? raw.map((e) => e.toString()).toList(growable: false)
      : const [];

  static Map<String, String> _stringMap(Object? raw) => raw is Map
      ? raw.map((k, v) => MapEntry(k.toString(), v.toString()))
      : const {};

  static List<ChatOption> _options(Object? raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map(
            (m) => ChatOption(
              key: _str(m['key']) ?? _str(m['value']) ?? '',
              label: _str(m['label']) ?? '',
              next: _str(m['next_step']) ?? _str(m['next']),
            ),
          )
          .toList(growable: false);
    }
    if (raw is Map) {
      return raw.entries
          .map(
            (e) => ChatOption(
              key: e.key.toString(),
              label: e.value.toString(),
            ),
          )
          .toList(growable: false);
    }
    return const [];
  }

  static List<ChatFormField> _formFields(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (m) => ChatFormField(
            key: _str(m['key']) ?? '',
            label: _str(m['label']) ?? _str(m['key']) ?? '',
            type: _str(m['type']) ?? _str(m['input_mode']) ?? 'text',
            required: _bool(m['required']),
            options: _options(m['options']),
          ),
        )
        .where((field) => field.key.isNotEmpty)
        .toList(growable: false);
  }

  static List<ScoreRow> _scoreRows(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (m) => ScoreRow(
            label: _str(m['label']) ?? '',
            value: _str(m['value']) ?? '',
          ),
        )
        .toList(growable: false);
  }
}

class ContentResolver {
  ContentResolver._();

  static int unitPoints(CourseUnitModel unit) => unit.xp;

  static VideoItem video(
    CourseVideoModel video, {
    required String id,
    required String stepId,
    bool watched = false,
  }) => VideoItem(
    id: id,
    stepId: stepId,
    videoId: '${video.id}',
    title: video.name,
    description: video.description,
    youtubeId: video.youtubeId,
    points: video.points,
    watched: watched,
  );

  static List<QuizItem> quizQuestions(
    CourseQuizModel? quiz, {
    required String idPrefix,
    required String stepId,
  }) {
    if (quiz == null) return const [];
    final valid = <CourseQuizQuestionModel>[];
    for (final q in quiz.questions) {
      if (!_answerKeyValid(q.answerKey, q.options)) {
        debugPrint('ContentResolver: dropped question with invalid answer key');
        continue;
      }
      valid.add(q);
    }

    return [
      for (var i = 0; i < valid.length; i++)
        QuizItem(
          id: '$idPrefix:$i',
          stepId: stepId,
          questionIndex: i,
          totalQuestions: valid.length,
          question: valid[i].question,
          options: orderedOptions(valid[i].options),
          answerKey: valid[i].answerKey,
          hint: valid[i].hint,
          explanation: _nonEmpty(valid[i].explanation),
          points: valid[i].points > 0
              ? valid[i].points
              : kClassroomQuizPointsPerCorrectAnswer,
        ),
    ];
  }

  static SubmissionItem submissionStep(
    CourseAssignmentModel assignment,
    CourseAssignmentStepModel step, {
    required String id,
    required String stepId,
    required int points,
    required int stepNumber,
    required int stepTotal,
  }) => SubmissionItem(
    id: id,
    stepId: stepId,
    assignmentName: assignment.name,
    assignmentDesc: assignment.description,
    guidedText: step.guidedText,
    unguidedText: step.unguidedText,
    subTypes: step.subTypes,
    validCriteria: step.validCriteria,
    submissionKind: SubmissionKindResolver.fromSubTypes(step.subTypes).wireValue,
    points: points,
    stepNumber: stepNumber,
    stepTotal: stepTotal,
  );

  static List<ChatOption> orderedOptions(Map<String, String> opts) {
    final keys = opts.keys.toList()
      ..sort((a, b) {
        final ai = int.tryParse(a);
        final bi = int.tryParse(b);
        if (ai != null && bi != null) return ai.compareTo(bi);
        if (ai != null) return -1;
        if (bi != null) return 1;
        return a.compareTo(b);
      });
    return keys
        .map((k) => ChatOption(key: k, label: opts[k] ?? ''))
        .toList(growable: false);
  }

  static bool _answerKeyValid(String answerKey, Map<String, String> opts) =>
      opts.containsKey(answerKey);

  static String? _nonEmpty(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}