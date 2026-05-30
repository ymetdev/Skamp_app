import 'package:cloud_firestore/cloud_firestore.dart';

enum StampShape {
  rectangle,
  zigzag,
  serrated,
  perforated,
  rounded,
  ticket,
  wave,
  scalloped;

  String get label {
    switch (this) {
      case StampShape.rectangle:
        return 'Rect';
      case StampShape.zigzag:
        return 'Zigzag';
      case StampShape.serrated:
        return 'Serrated';
      case StampShape.perforated:
        return 'Perf';
      case StampShape.rounded:
        return 'Round';
      case StampShape.ticket:
        return 'Ticket';
      case StampShape.wave:
        return 'Wave';
      case StampShape.scalloped:
        return 'Scallop';
    }
  }
}

class PaperStamp {
  final String id;
  final String ownerId;
  final String imageUrl;
  final String thumbnailUrl;
  final StampShape shape;
  final DateTime capturedAt;
  final String? countryCode;
  final bool isPlaced;
  final String? journalId;
  final String? pageId;
  final double? latitude;
  final double? longitude;

  const PaperStamp({
    required this.id,
    required this.ownerId,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.shape,
    required this.capturedAt,
    this.countryCode,
    this.isPlaced = false,
    this.journalId,
    this.pageId,
    this.latitude,
    this.longitude,
  });

  factory PaperStamp.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final GeoPoint? geo = data['location'] as GeoPoint?;
    return PaperStamp(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? data['imageUrl'] ?? '',
      shape: StampShape.values.firstWhere(
        (s) => s.name == data['shape'],
        orElse: () => StampShape.rectangle,
      ),
      capturedAt: (data['capturedAt'] as Timestamp).toDate(),
      countryCode: data['countryCode'],
      isPlaced: data['isPlaced'] ?? false,
      journalId: data['journalId'],
      pageId: data['pageId'],
      latitude: geo?.latitude,
      longitude: geo?.longitude,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'ownerId': ownerId,
        'imageUrl': imageUrl,
        'thumbnailUrl': thumbnailUrl,
        'shape': shape.name,
        'capturedAt': Timestamp.fromDate(capturedAt),
        if (countryCode != null) 'countryCode': countryCode,
        'isPlaced': isPlaced,
        if (journalId != null) 'journalId': journalId,
        if (pageId != null) 'pageId': pageId,
        if (latitude != null && longitude != null)
          'location': GeoPoint(latitude!, longitude!),
      };

  PaperStamp copyWith({
    bool? isPlaced,
    String? journalId,
    String? pageId,
  }) =>
      PaperStamp(
        id: id,
        ownerId: ownerId,
        imageUrl: imageUrl,
        thumbnailUrl: thumbnailUrl,
        shape: shape,
        capturedAt: capturedAt,
        countryCode: countryCode,
        isPlaced: isPlaced ?? this.isPlaced,
        journalId: journalId ?? this.journalId,
        pageId: pageId ?? this.pageId,
        latitude: latitude,
        longitude: longitude,
      );
}

enum RubberStampType { country, city, achievement }

class RubberStamp {
  final String id;
  final String ownerId;
  final String name;
  final String imageUrl;
  final StampShape shape;
  final RubberStampType type;
  final String? countryCode;
  final String? cityKey;
  final String? achievementKey;
  final DateTime unlockedAt;

  const RubberStamp({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.imageUrl,
    required this.shape,
    required this.type,
    this.countryCode,
    this.cityKey,
    this.achievementKey,
    required this.unlockedAt,
  });

  factory RubberStamp.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RubberStamp(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      name: data['name'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      shape: StampShape.values.firstWhere(
        (s) => s.name == data['shape'],
        orElse: () => StampShape.rectangle,
      ),
      type: RubberStampType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => RubberStampType.achievement,
      ),
      countryCode: data['countryCode'],
      cityKey: data['cityKey'],
      achievementKey: data['achievementKey'],
      unlockedAt: (data['unlockedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'ownerId': ownerId,
        'name': name,
        'imageUrl': imageUrl,
        'shape': shape.name,
        'type': type.name,
        if (countryCode != null) 'countryCode': countryCode,
        if (cityKey != null) 'cityKey': cityKey,
        if (achievementKey != null) 'achievementKey': achievementKey,
        'unlockedAt': Timestamp.fromDate(unlockedAt),
      };
}
