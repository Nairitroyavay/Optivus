import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:optivus/models/routine_item.dart';

enum RoutineEventType {
  created,
  edited,
  deleted,
  started,
  completed,
  skipped,
  missed,
  moved,
  rescheduled,
  undone,
}

class RoutineEventRecord {
  final int schemaVersion;
  final String eventId;
  final String ownerUid;
  final String routineItemId;
  final String? occurrenceId;
  final String? occurrenceDateKey;
  final RoutineEventType eventType;
  final String operationKey;
  final String source;
  final DateTime occurredAt;
  final Map<String, dynamic> itemSnapshot;

  RoutineEventRecord({
    this.schemaVersion = 1,
    required this.eventId,
    required this.ownerUid,
    required this.routineItemId,
    this.occurrenceId,
    this.occurrenceDateKey,
    required this.eventType,
    required this.operationKey,
    required this.source,
    required this.occurredAt,
    this.itemSnapshot = const {},
  });

  RoutineEventRecord copyWith({
    int? schemaVersion,
    String? eventId,
    String? ownerUid,
    String? routineItemId,
    String? occurrenceId,
    String? occurrenceDateKey,
    RoutineEventType? eventType,
    String? operationKey,
    String? source,
    DateTime? occurredAt,
    Map<String, dynamic>? itemSnapshot,
  }) {
    return RoutineEventRecord(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      eventId: eventId ?? this.eventId,
      ownerUid: ownerUid ?? this.ownerUid,
      routineItemId: routineItemId ?? this.routineItemId,
      occurrenceId: occurrenceId ?? this.occurrenceId,
      occurrenceDateKey: occurrenceDateKey ?? this.occurrenceDateKey,
      eventType: eventType ?? this.eventType,
      operationKey: operationKey ?? this.operationKey,
      source: source ?? this.source,
      occurredAt: occurredAt ?? this.occurredAt,
      itemSnapshot: itemSnapshot ?? this.itemSnapshot,
    );
  }
}

class RoutineEventFirestoreCodec {
  static Map<String, dynamic> toFirestore(RoutineEventRecord record) {
    if (record.ownerUid.isEmpty) {
      throw const FormatException('ownerUid is required');
    }
    if (record.eventId.isEmpty) {
      throw const FormatException('eventId is required');
    }
    if (record.routineItemId.isEmpty) {
      throw const FormatException('routineItemId is required');
    }
    if (record.operationKey.isEmpty) {
      throw const FormatException('operationKey is required');
    }
    if (record.source.isEmpty) {
      throw const FormatException('source is required');
    }
    if (record.itemSnapshot.isEmpty) {
      throw const FormatException('itemSnapshot is required');
    }
    _validateItemSnapshot(record.itemSnapshot, record.routineItemId);

    return {
      'schemaVersion': record.schemaVersion,
      'eventId': record.eventId,
      'ownerUid': record.ownerUid,
      'routineItemId': record.routineItemId,
      if (record.occurrenceId != null) 'occurrenceId': record.occurrenceId,
      if (record.occurrenceDateKey != null)
        'occurrenceDateKey': record.occurrenceDateKey,
      'eventType': record.eventType.name,
      'operationKey': record.operationKey,
      'source': record.source,
      'occurredAt': Timestamp.fromDate(record.occurredAt.toUtc()),
      'itemSnapshot': record.itemSnapshot,
    };
  }

  /// Parses a [RoutineEventRecord] from a Firestore document ID and its raw
  /// data map. Callers should pass [doc.id] and [doc.data()].
  ///
  /// This overload avoids a dependency on the sealed [DocumentSnapshot] type
  /// so that tests can supply plain maps without subclassing Firebase types.
  static RoutineEventRecord fromFirestore(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final ownerUid = data['ownerUid'] as String?;
    if (ownerUid == null || ownerUid.isEmpty) {
      throw const FormatException('ownerUid is required');
    }

    final routineItemId = data['routineItemId'] as String?;
    if (routineItemId == null || routineItemId.isEmpty) {
      throw const FormatException('routineItemId is required');
    }

    final occurredAtTimestamp = data['occurredAt'] as Timestamp?;
    if (occurredAtTimestamp == null) {
      throw const FormatException('occurredAt is required');
    }

    final eventIdField = data['eventId'] as String?;
    if (eventIdField == null) {
      throw const FormatException('eventId is required');
    }
    if (eventIdField != documentId) {
      throw FormatException(
        'eventId ($eventIdField) does not match document ID ($documentId)',
      );
    }

    final schemaVersion = data['schemaVersion'] as int?;
    if (schemaVersion == null || schemaVersion != 1) {
      throw FormatException('Unsupported event schema version: $schemaVersion');
    }

    final operationKey = data['operationKey'] as String?;
    if (operationKey == null || operationKey.isEmpty) {
      throw const FormatException('operationKey is required');
    }

    final source = data['source'] as String?;
    if (source == null || source.isEmpty) {
      throw const FormatException('source is required');
    }

    if (data['itemSnapshot'] is! Map) {
      throw const FormatException('itemSnapshot must be a map');
    }
    final itemSnapshot = (data['itemSnapshot'] as Map?)
        ?.cast<String, dynamic>();
    if (itemSnapshot == null || itemSnapshot.isEmpty) {
      throw const FormatException('itemSnapshot is required');
    }
    _validateItemSnapshot(itemSnapshot, routineItemId);

    return RoutineEventRecord(
      schemaVersion: schemaVersion,
      eventId: documentId,
      ownerUid: ownerUid,
      routineItemId: routineItemId,
      occurrenceId: data['occurrenceId'] as String?,
      occurrenceDateKey: data['occurrenceDateKey'] as String?,
      eventType: RoutineEventType.values.firstWhere(
        (e) => e.name == data['eventType'],
        orElse: () =>
            throw FormatException('Invalid eventType: ${data['eventType']}'),
      ),
      operationKey: operationKey,
      source: source,
      occurredAt: occurredAtTimestamp.toDate().toUtc(),
      itemSnapshot: itemSnapshot,
    );
  }

  static void _validateItemSnapshot(
    Map<String, dynamic> snapshot,
    String routineItemId,
  ) {
    const allowedKeys = {
      'id',
      'title',
      'startMinute',
      'durationMinutes',
      'blockType',
      'trackerTaskType',
      'hardBlock',
      'onboardingProjectionId',
    };
    const requiredKeys = {
      'id',
      'title',
      'startMinute',
      'durationMinutes',
      'blockType',
      'trackerTaskType',
      'hardBlock',
    };

    final unknownKeys = snapshot.keys.toSet().difference(allowedKeys);
    if (unknownKeys.isNotEmpty) {
      throw FormatException(
        'itemSnapshot contains unsupported fields: ${unknownKeys.join(', ')}',
      );
    }
    final missingKeys = requiredKeys.difference(snapshot.keys.toSet());
    if (missingKeys.isNotEmpty) {
      throw FormatException(
        'itemSnapshot missing required fields: ${missingKeys.join(', ')}',
      );
    }

    final id = snapshot['id'];
    if (id is! String || !_validDocumentId(id) || id != routineItemId) {
      throw const FormatException('itemSnapshot id is invalid');
    }

    final title = snapshot['title'];
    if (title is! String || title.isEmpty || title.length > 200) {
      throw const FormatException('itemSnapshot title is required');
    }

    final startMinute = snapshot['startMinute'];
    if (startMinute is! int || startMinute < 0 || startMinute > 1439) {
      throw const FormatException('itemSnapshot startMinute is invalid');
    }

    final durationMinutes = snapshot['durationMinutes'];
    if (durationMinutes is! int ||
        durationMinutes <= 0 ||
        durationMinutes > 1440) {
      throw const FormatException('itemSnapshot durationMinutes is invalid');
    }

    final blockType = snapshot['blockType'];
    if (blockType is! String ||
        !RoutineBlockType.values.any((value) => value.name == blockType)) {
      throw const FormatException('itemSnapshot blockType is invalid');
    }

    final trackerTaskType = snapshot['trackerTaskType'];
    if (trackerTaskType is! String ||
        !TrackerType.values.any((value) => value.name == trackerTaskType)) {
      throw const FormatException('itemSnapshot trackerTaskType is invalid');
    }

    if (snapshot['hardBlock'] is! bool) {
      throw const FormatException('itemSnapshot hardBlock is required');
    }

    final onboardingProjectionId = snapshot['onboardingProjectionId'];
    if (onboardingProjectionId != null && onboardingProjectionId is! String) {
      throw const FormatException(
        'itemSnapshot onboardingProjectionId is invalid',
      );
    }
  }

  static bool _validDocumentId(String id) {
    final value = id.trim();
    return value.isNotEmpty &&
        value.length <= 128 &&
        !value.contains('/') &&
        value != '.' &&
        value != '..' &&
        value == id;
  }
}
