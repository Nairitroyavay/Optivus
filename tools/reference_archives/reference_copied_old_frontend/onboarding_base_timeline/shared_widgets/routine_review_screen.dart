// REFERENCE COPY ONLY — not imported into app yet.

import 'package:flutter/material.dart';
import 'package:optivus2/models/routine_template_model.dart';
import 'package:optivus2/services/routine_acceptance_guard.dart';
import 'package:optivus2/services/routine_time_formatter.dart';

class RoutineReviewScreen extends StatefulWidget {
  final String title;
  final String routineType;
  final List<Map<String, dynamic>> templates;
  final Future<List<Map<String, dynamic>>> Function()? onRegenerate;
  final Future<void> Function(List<Map<String, dynamic>> templates) onAcceptAll;

  const RoutineReviewScreen({
    super.key,
    required this.title,
    required this.routineType,
    required this.templates,
    required this.onAcceptAll,
    this.onRegenerate,
  });

  @override
  State<RoutineReviewScreen> createState() => _RoutineReviewScreenState();
}

class _RoutineReviewScreenState extends State<RoutineReviewScreen> {
  late List<Map<String, dynamic>> _templates;
  bool _saving = false;
  bool _regenerating = false;
  String? _error;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _templates = widget.templates.map(_normalizeTemplate).toList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _normalizeTemplate(Map<String, dynamic> raw) {
    final template = Map<String, dynamic>.from(raw);
    final startTime = normalizeRoutineTimeOrNull(
      template['startTime'] ?? template['time'],
    );
    final endTime = normalizeRoutineTimeOrNull(template['endTime']);
    final relativeRule = canonicalRelativeTimingRule(
      template['relativeTimingRule'] ?? template['timingRule'],
    );
    template['routineType'] = template['routineType'] ?? widget.routineType;
    template['startTime'] = startTime;
    template['time'] = startTime;
    template['endTime'] =
        endTime ??
        (startTime == null ? null : _endTime(startTime, _durationMinutes()));
    template['repeatRule'] = _repeatRule(template);
    template['relativeTimingRule'] = relativeRule;
    template['timingRule'] =
        relativeRule ?? (startTime == null ? '' : _timingRuleFor(startTime));
    template['weekdayRule'] =
        template['weekdayRule']?.toString().trim().isNotEmpty == true
        ? template['weekdayRule'].toString().trim()
        : template['repeatRule'];
    template['steps'] = _stepsFrom(template['steps'], template['notes']);
    template['warnings'] = _stringList(template['warnings']);
    template['confidence'] = _confidence(template['confidence']);
    template['notes'] = template['notes']?.toString() ?? '';
    template['reminderEnabled'] = template['reminderEnabled'] == true;
    template['isActive'] = template['isActive'] ?? true;
    return RoutineTemplateModel.fromMap(
      template,
      fallbackRoutineType: widget.routineType,
      allowBlankTimes: true,
    ).toMap();
  }

  int _durationMinutes() => widget.routineType == 'skin_care' ? 15 : 5;

  static String _repeatRule(Map<String, dynamic> template) {
    final weekdayRule = template['weekdayRule']?.toString().trim();
    final repeatRule = template['repeatRule']?.toString().trim();
    if (repeatRule != null && repeatRule.isNotEmpty) return repeatRule;
    if (weekdayRule != null && weekdayRule.isNotEmpty) return weekdayRule;
    return 'daily';
  }

  static List<Map<String, dynamic>> _stepsFrom(Object? raw, Object? notes) {
    final values = <String>[];
    if (raw is List) {
      for (final step in raw) {
        if (step is Map) {
          final name =
              step['name']?.toString().trim() ??
              step['title']?.toString().trim() ??
              '';
          if (name.isNotEmpty) values.add(name);
        } else {
          final name = step.toString().trim();
          if (name.isNotEmpty) values.add(name);
        }
      }
    }
    if (values.isEmpty) {
      values.addAll(
        (notes?.toString() ?? '')
            .split(RegExp(r',|\n'))
            .map((step) => step.trim())
            .where((step) => step.isNotEmpty),
      );
    }
    return values.map((name) => {'name': name}).toList();
  }

  static List<String> _stringList(Object? raw) {
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty ? const [] : [value];
  }

  static double _confidence(Object? raw) {
    final value = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0.75;
    return value.clamp(0.0, 1.0).toDouble();
  }

  Future<void> _regenerate() async {
    final callback = widget.onRegenerate;
    if (callback == null) return;
    setState(() {
      _regenerating = true;
      _error = null;
    });
    try {
      final next = await callback();
      if (!mounted) return;
      setState(() => _templates = next.map(_normalizeTemplate).toList());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  Future<void> _acceptAll() async {
    if (_templates.isEmpty || _saving) return;
    final validationMessage = _validateAcceptedTemplates();
    if (validationMessage != null) {
      setState(() => _error = validationMessage);
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      debugPrint('[RoutineReview] accept_start');
      debugPrint('[RoutineReview] accept_templates_count=${_templates.length}');
      await runRoutineAcceptWithTimeout(
        () => widget.onAcceptAll(_templates.map(_normalizeTemplate).toList()),
      );
      debugPrint('[RoutineReview] accept_save_success');
      if (mounted) Navigator.pop(context, true);
    } on RoutineAcceptTimeoutException {
      debugPrint('[RoutineReview] accept_timeout');
      if (!mounted) return;
      setState(() => _error = 'Could not save. Please try again.');
    } catch (e) {
      debugPrint('[RoutineReview] accept_save_failed: $e');
      if (!mounted) return;
      setState(() => _error = 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateAcceptedTemplates() {
    for (final template in _templates) {
      final title = template['title']?.toString().trim();
      if (title == null || title.isEmpty) continue;
      final start = normalizeRoutineTimeOrNull(template['startTime']);
      final end = normalizeRoutineTimeOrNull(template['endTime']);
      if (start == null || end == null) {
        return 'Please set a time for $title before saving.';
      }
    }
    return null;
  }

  void _addTemplate() {
    setState(() {
      _templates.add(
        _normalizeTemplate({
          'templateId':
              '${widget.routineType}_${DateTime.now().microsecondsSinceEpoch}',
          'title': 'New routine block',
          'startTime': '07:30',
          'endTime': '07:45',
          'repeatRule': 'daily',
          'steps': [
            {'name': 'Cleanse'},
          ],
          'notes': '',
          'confidence': 0.75,
          'warnings': const [],
        }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Add',
            onPressed: _addTemplate,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
              children: [
                if (_fallbackWarnings.isNotEmpty) ...[
                  _ImportNotice(warnings: _fallbackWarnings),
                  const SizedBox(height: 12),
                ],
                for (final group in _groupedTemplateIndexes().entries) ...[
                  _GroupHeader(label: group.key),
                  const SizedBox(height: 8),
                  for (final index in group.value) ...[
                    _RoutineReviewCard(
                      key: ValueKey(_templates[index]['templateId'] ?? index),
                      template: _templates[index],
                      onChanged: (next) {
                        setState(
                          () => _templates[index] = _normalizeTemplate(next),
                        );
                      },
                      onRemove: () =>
                          setState(() => _templates.removeAt(index)),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _regenerating ? null : _regenerate,
                    icon: _regenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Regenerate'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _saving || _templates.isEmpty
                        ? null
                        : _acceptAll,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('Accept all'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> get _fallbackWarnings {
    final warnings = <String>{};
    for (final template in _templates) {
      final raw = template['warnings'];
      if (raw is List) {
        for (final item in raw) {
          final text = item.toString().trim();
          if (text.isNotEmpty && text.toLowerCase().contains('fallback')) {
            warnings.add(text);
          }
        }
      }
    }
    return warnings.toList(growable: false);
  }

  Map<String, List<int>> _groupedTemplateIndexes() {
    final groups = <String, List<int>>{};
    for (var i = 0; i < _templates.length; i++) {
      final label = _groupLabel(_templates[i]);
      groups.putIfAbsent(label, () => <int>[]).add(i);
    }
    return groups;
  }

  String _groupLabel(Map<String, dynamic> template) {
    final repeat = template['repeatRule']?.toString().toLowerCase() ?? '';
    if (repeat.startsWith('weekly:') && widget.routineType == 'skin_care') {
      return 'Weekly rotation';
    }
    final rule = canonicalRelativeTimingRule(
      template['relativeTimingRule'] ?? template['timingRule'],
    );
    switch (rule) {
      case 'morning':
      case 'after_breakfast':
        return 'Morning';
      case 'after_lunch':
      case 'afternoon':
        return 'Afternoon';
      case 'after_dinner':
      case 'evening':
        return 'Evening';
      case 'night':
      case 'before_sleep':
        return 'Night';
      default:
        final start = routineMinutesFromTime(template['startTime']);
        if (start == null) return 'Needs time';
        final hour = start ~/ 60;
        if (hour < 12) return 'Morning';
        if (hour < 17) return 'Afternoon';
        if (hour < 21) return 'Evening';
        return 'Night';
    }
  }
}

class _ImportNotice extends StatelessWidget {
  final List<String> warnings;

  const _ImportNotice({required this.warnings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF92400E)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Local fallback draft — AI preview failed. You can retry.',
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;

  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF334155),
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _RoutineReviewCard extends StatelessWidget {
  final Map<String, dynamic> template;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onRemove;

  const _RoutineReviewCard({
    super.key,
    required this.template,
    required this.onChanged,
    required this.onRemove,
  });

  void _set(String key, Object? value) {
    onChanged({...template, key: value});
  }

  @override
  Widget build(BuildContext context) {
    final warnings = _warningsText(template['warnings']);
    final steps = (template['steps'] as List? ?? const [])
        .map((step) => step is Map ? step['name'] : step)
        .map((step) => step?.toString().trim() ?? '')
        .where((step) => step.isNotEmpty)
        .join(', ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: template['title']?.toString() ?? '',
                  decoration: const InputDecoration(labelText: 'Title'),
                  onChanged: (value) => _set('title', value),
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: template['startTime']?.toString() ?? '',
                  decoration: InputDecoration(
                    labelText: 'Time',
                    helperText: _timeHelper(template),
                  ),
                  onChanged: (value) {
                    final time = normalizeRoutineTimeOrNull(value);
                    onChanged({...template, 'time': time, 'startTime': time});
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: template['endTime']?.toString() ?? '',
                  decoration: const InputDecoration(labelText: 'End'),
                  onChanged: (value) {
                    _set('endTime', normalizeRoutineTimeOrNull(value));
                  },
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: template['timingRule']?.toString() ?? '',
                  decoration: const InputDecoration(labelText: 'Timing rule'),
                  onChanged: (value) => _set('timingRule', value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue:
                      template['weekdayRule']?.toString() ??
                      template['repeatRule']?.toString() ??
                      '',
                  decoration: const InputDecoration(labelText: 'Weekday rule'),
                  onChanged: (value) {
                    onChanged({
                      ...template,
                      'weekdayRule': value,
                      'repeatRule': value,
                    });
                  },
                ),
              ),
            ],
          ),
          TextFormField(
            initialValue: steps,
            decoration: const InputDecoration(labelText: 'Steps'),
            minLines: 1,
            maxLines: 3,
            onChanged: (value) {
              _set(
                'steps',
                value
                    .split(RegExp(r',|\n'))
                    .map((step) => step.trim())
                    .where((step) => step.isNotEmpty)
                    .map((name) => {'name': name})
                    .toList(),
              );
            },
          ),
          TextFormField(
            initialValue: template['notes']?.toString() ?? '',
            decoration: const InputDecoration(labelText: 'Notes'),
            onChanged: (value) => _set('notes', value),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.verified_outlined,
                label:
                    'Confidence ${(((template['confidence'] as num?)?.toDouble() ?? 0.75) * 100).round()}%',
              ),
              if (warnings.isNotEmpty &&
                  !warnings.toLowerCase().contains('fallback'))
                _MetaChip(
                  icon: Icons.warning_amber_rounded,
                  label: warnings,
                  color: const Color(0xFF92400E),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _warningsText(Object? raw) {
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .join(', ');
    }
    return raw?.toString().trim() ?? '';
  }

  static String? _timeHelper(Map<String, dynamic> template) {
    final rule = canonicalRelativeTimingRule(
      template['relativeTimingRule'] ?? template['timingRule'],
    );
    if (rule == null) return null;
    final label = relativeTimingRuleLabel(rule);
    final resolved = normalizeRoutineTimeOrNull(template['resolvedStart']);
    if (resolved != null) return '$label - $resolved';
    if (relativeRuleRequiresAnchor(rule)) {
      final anchor = label
          .replaceFirst('After ', '')
          .replaceFirst('Before ', '');
      return '$label - set $anchor time or choose time manually';
    }
    return label;
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.label,
    this.color = const Color(0xFF334155),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _endTime(String startTime, int durationMinutes) {
  final parts = startTime.split(':');
  final hour = int.tryParse(parts.first) ?? 7;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final start = DateTime(2026, 1, 1, hour, minute);
  final end = start.add(Duration(minutes: durationMinutes));
  return '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
}

String _timingRuleFor(String time) {
  final hour = int.tryParse(time.split(':').first) ?? 7;
  if (hour < 12) return 'morning';
  if (hour < 17) return 'afternoon';
  return 'night';
}
