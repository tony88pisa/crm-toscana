// lib/models/prospect.dart — v6

enum ProspectStatus {
  nuovo,
  daVisitare,
  visitato,
  interessato,
  proposta,
  chiusoVinto,
  chiusoPerso,
}

enum LeadUrgency { hot, warm, cold, unknown }

extension LeadUrgencyExtension on LeadUrgency {
  String get label => const {
    LeadUrgency.hot: 'Opportunità calda',
    LeadUrgency.warm: 'Decidendo ora',
    LeadUrgency.cold: 'Forse tardi',
    LeadUrgency.unknown: 'Da verificare',
  }[this]!;

  String get emoji => const {
    LeadUrgency.hot: '🟢', LeadUrgency.warm: '🟡',
    LeadUrgency.cold: '🔴', LeadUrgency.unknown: '⚪',
  }[this]!;

  String get description => const {
    LeadUrgency.hot: 'Apre tra più di 1 mese — non ha ancora scelto la cassa!',
    LeadUrgency.warm: 'Apre tra 1-2 settimane — sta decidendo!',
    LeadUrgency.cold: 'Apre tra meno di 1 settimana o già aperto',
    LeadUrgency.unknown: 'Data di apertura non determinata',
  }[this]!;

  int get colorValue => const {
    LeadUrgency.hot: 0xFF2E7D32, LeadUrgency.warm: 0xFFF9A825,
    LeadUrgency.cold: 0xFFC62828, LeadUrgency.unknown: 0xFF78909C,
  }[this]!;

  String get dbValue => name;

  static LeadUrgency fromDb(String? v) {
    switch (v) {
      case 'hot': return LeadUrgency.hot;
      case 'warm': return LeadUrgency.warm;
      case 'cold': return LeadUrgency.cold;
      default: return LeadUrgency.unknown;
    }
  }
}

extension ProspectStatusExtension on ProspectStatus {
  String get label => const {
    ProspectStatus.nuovo: 'Nuovo',
    ProspectStatus.daVisitare: 'Da visitare',
    ProspectStatus.visitato: 'Visitato',
    ProspectStatus.interessato: 'Interessato',
    ProspectStatus.proposta: 'Proposta inviata',
    ProspectStatus.chiusoVinto: 'Cliente acquisito ✓',
    ProspectStatus.chiusoPerso: 'Non interessato',
  }[this]!;

  String get dbValue => const {
    ProspectStatus.nuovo: 'nuovo',
    ProspectStatus.daVisitare: 'da_visitare',
    ProspectStatus.visitato: 'visitato',
    ProspectStatus.interessato: 'interessato',
    ProspectStatus.proposta: 'proposta',
    ProspectStatus.chiusoVinto: 'chiuso_vinto',
    ProspectStatus.chiusoPerso: 'chiuso_perso',
  }[this]!;

  int get colorValue => const {
    ProspectStatus.nuovo: 0xFFE53935,
    ProspectStatus.daVisitare: 0xFFFF6F00,
    ProspectStatus.visitato: 0xFF1565C0,
    ProspectStatus.interessato: 0xFF6A1B9A,
    ProspectStatus.proposta: 0xFF00838F,
    ProspectStatus.chiusoVinto: 0xFF2E7D32,
    ProspectStatus.chiusoPerso: 0xFF757575,
  }[this]!;

  static ProspectStatus fromDb(String v) {
    switch (v) {
      case 'da_visitare': return ProspectStatus.daVisitare;
      case 'visitato': return ProspectStatus.visitato;
      case 'interessato': return ProspectStatus.interessato;
      case 'proposta': return ProspectStatus.proposta;
      case 'chiuso_vinto': return ProspectStatus.chiusoVinto;
      case 'chiuso_perso': return ProspectStatus.chiusoPerso;
      default: return ProspectStatus.nuovo;
    }
  }
}


class ContactLog {
  final int? id;
  final int prospectId;
  final String type; // 'call', 'visit', 'email', 'whatsapp', 'note'
  final String? notes;
  final DateTime createdAt;
  final String? outcome; // 'positive', 'neutral', 'negative'

  const ContactLog({
    this.id, required this.prospectId, required this.type,
    this.notes, required this.createdAt, this.outcome,
  });

  Map<String, dynamic> toMap() => {
    'prospect_id': prospectId, 'type': type, 'notes': notes,
    'created_at': createdAt.toIso8601String(), 'outcome': outcome,
  };

  factory ContactLog.fromMap(Map<String, dynamic> m) => ContactLog(
    id: m['id'], prospectId: m['prospect_id'], type: m['type'],
    notes: m['notes'], createdAt: DateTime.parse(m['created_at']),
    outcome: m['outcome'],
  );

  String get typeEmoji => const {
    'call': '📞', 'visit': '🏠', 'email': '📧',
    'whatsapp': '💬', 'note': '📝',
  }[type] ?? '📋';

  String get typeLabel => const {
    'call': 'Chiamata', 'visit': 'Visita', 'email': 'Email',
    'whatsapp': 'WhatsApp', 'note': 'Nota',
  }[type] ?? tipo;

  String get tipo => type;
}

class Prospect {
  final int? id;
  final String name;
  final String address;
  final String? phone;
  final String? website;
  final double lat, lng;
  final String province;
  ProspectStatus status;
  String? notes;
  final DateTime createdAt;
  DateTime? lastContactAt;
  final String? googlePlaceId;
  final String? businessType;
  final String? source;
  final String? sourceUrl;
  final LeadUrgency urgency;
  final bool verified;
  final DateTime? estimatedOpenDate;
  final int confidenceScore;
  final String? tags;
  final String? vatNumber;
  final String? ownerName;
  final String? email;
  final String? extractedPhone;
  double? distanceMeters;

  Prospect({
    this.id, required this.name, required this.address,
    this.phone, this.website, required this.lat, required this.lng,
    required this.province, this.status = ProspectStatus.nuovo,
    this.notes, DateTime? createdAt, this.lastContactAt,
    this.googlePlaceId, this.businessType, this.source, this.sourceUrl,
    this.urgency = LeadUrgency.unknown, this.verified = false,
    this.estimatedOpenDate, this.confidenceScore = 0,
    this.tags, this.vatNumber, this.ownerName, this.email, this.extractedPhone,
    this.distanceMeters,
  }) : createdAt = createdAt ?? DateTime.now();

  int get daysSinceLastContact {
    if (lastContactAt == null) return -1;
    return DateTime.now().difference(lastContactAt!).inDays;
  }

  bool get needsFollowUp {
    if (status == ProspectStatus.chiusoVinto || status == ProspectStatus.chiusoPerso) return false;
    if (lastContactAt == null && status != ProspectStatus.nuovo) return true;
    return daysSinceLastContact > 3;
  }

  List<String> get tagList => tags?.split(',').where((t) => t.isNotEmpty).toList() ?? [];

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'address': address, 'phone': phone,
    'website': website, 'lat': lat, 'lng': lng, 'province': province,
    'status': status.dbValue, 'notes': notes,
    'created_at': createdAt.toIso8601String(),
    'last_contact_at': lastContactAt?.toIso8601String(),
    'google_place_id': googlePlaceId, 'business_type': businessType,
    'source': source, 'source_url': sourceUrl,
    'urgency': urgency.dbValue, 'verified': verified ? 1 : 0,
    'estimated_open_date': estimatedOpenDate?.toIso8601String(),
    'confidence_score': confidenceScore,
    'tags': tags, 'vat_number': vatNumber,
    'owner_name': ownerName, 'email': email, 'extracted_phone': extractedPhone,
  };

  factory Prospect.fromMap(Map<String, dynamic> m) => Prospect(
    id: m['id'], name: m['name'], address: m['address'],
    phone: m['phone'], website: m['website'],
    lat: m['lat'], lng: m['lng'], province: m['province'],
    status: ProspectStatusExtension.fromDb(m['status'] ?? 'nuovo'),
    notes: m['notes'],
    createdAt: DateTime.parse(m['created_at']),
    lastContactAt: m['last_contact_at'] != null ? DateTime.parse(m['last_contact_at']) : null,
    googlePlaceId: m['google_place_id'], businessType: m['business_type'],
    source: m['source'], sourceUrl: m['source_url'],
    urgency: LeadUrgencyExtension.fromDb(m['urgency']),
    verified: (m['verified'] ?? 0) == 1,
    estimatedOpenDate: m['estimated_open_date'] != null ? DateTime.tryParse(m['estimated_open_date']) : null,
    confidenceScore: m['confidence_score'] ?? 0,
    tags: m['tags'],
    vatNumber: m['vat_number'],
    ownerName: m['owner_name'],
    email: m['email'],
    extractedPhone: m['extracted_phone'],
  );

  Prospect copyWith({
    ProspectStatus? status, String? notes, DateTime? lastContactAt, String? tags, String? vatNumber,
  }) => Prospect(
    id: id, name: name, address: address, phone: phone, website: website,
    lat: lat, lng: lng, province: province,
    status: status ?? this.status, notes: notes ?? this.notes,
    createdAt: createdAt, lastContactAt: lastContactAt ?? this.lastContactAt,
    googlePlaceId: googlePlaceId, businessType: businessType,
    source: source, sourceUrl: sourceUrl, urgency: urgency, verified: verified,
    estimatedOpenDate: estimatedOpenDate, confidenceScore: confidenceScore,
    tags: tags ?? this.tags,
    vatNumber: vatNumber ?? this.vatNumber,
    ownerName: ownerName, email: email, extractedPhone: extractedPhone,
    distanceMeters: distanceMeters,
  );
}
