import 'package:cloud_firestore/cloud_firestore.dart';
import 'stamp_model.dart';

enum PaperStyle { blank, lined, graph, dotted }

class PlacedStamp {
  final String id;
  final String stampId;
  final bool isRubber;
  final String imageUrl;
  final StampShape shape;
  final double x;
  final double y;
  final double scale;

  const PlacedStamp({
    required this.id,
    required this.stampId,
    required this.isRubber,
    required this.imageUrl,
    required this.shape,
    required this.x,
    required this.y,
    this.scale = 1.0,
  });

  factory PlacedStamp.fromMap(Map<String, dynamic> map) => PlacedStamp(
        id: map['id'] as String? ?? '',
        stampId: map['stampId'] as String? ?? '',
        isRubber: map['isRubber'] as bool? ?? false,
        imageUrl: map['imageUrl'] as String? ?? '',
        shape: StampShape.values.firstWhere(
          (s) => s.name == map['shape'],
          orElse: () => StampShape.rectangle,
        ),
        x: (map['x'] as num?)?.toDouble() ?? 0.5,
        y: (map['y'] as num?)?.toDouble() ?? 0.5,
        scale: (map['scale'] as num?)?.toDouble() ?? 1.0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'stampId': stampId,
        'isRubber': isRubber,
        'imageUrl': imageUrl,
        'shape': shape.name,
        'x': x,
        'y': y,
        'scale': scale,
      };

  PlacedStamp copyWith({double? x, double? y, double? scale}) => PlacedStamp(
        id: id,
        stampId: stampId,
        isRubber: isRubber,
        imageUrl: imageUrl,
        shape: shape,
        x: x ?? this.x,
        y: y ?? this.y,
        scale: scale ?? this.scale,
      );
}

class JournalPage {
  final String id;
  final String journalId;
  final int pageNumber;
  final DateTime createdAt;
  final List<PlacedStamp> stamps;

  const JournalPage({
    required this.id,
    required this.journalId,
    required this.pageNumber,
    required this.createdAt,
    this.stamps = const [],
  });

  factory JournalPage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final stampsRaw = (data['stamps'] as List<dynamic>?) ?? [];
    return JournalPage(
      id: doc.id,
      journalId: data['journalId'] as String? ?? '',
      pageNumber: (data['pageNumber'] as num?)?.toInt() ?? 1,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      stamps: stampsRaw
          .cast<Map<String, dynamic>>()
          .map(PlacedStamp.fromMap)
          .toList(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'journalId': journalId,
        'pageNumber': pageNumber,
        'createdAt': Timestamp.fromDate(createdAt),
        'stamps': stamps.map((s) => s.toMap()).toList(),
      };

  JournalPage copyWith({List<PlacedStamp>? stamps}) => JournalPage(
        id: id,
        journalId: journalId,
        pageNumber: pageNumber,
        createdAt: createdAt,
        stamps: stamps ?? this.stamps,
      );
}

class Journal {
  final String id;
  final String ownerId;
  final String title;
  final PaperStyle paperStyle;
  final String coverColor;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int pageCount;

  const Journal({
    required this.id,
    required this.ownerId,
    required this.title,
    this.paperStyle = PaperStyle.blank,
    this.coverColor = 'cream',
    required this.createdAt,
    required this.updatedAt,
    this.pageCount = 0,
  });

  factory Journal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Journal(
      id: doc.id,
      ownerId: data['ownerId'] as String? ?? '',
      title: data['title'] as String? ?? 'Untitled',
      paperStyle: PaperStyle.values.firstWhere(
        (s) => s.name == data['paperStyle'],
        orElse: () => PaperStyle.blank,
      ),
      coverColor: data['coverColor'] as String? ?? 'cream',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pageCount: (data['pageCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'ownerId': ownerId,
        'title': title,
        'paperStyle': paperStyle.name,
        'coverColor': coverColor,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'pageCount': pageCount,
      };
}
