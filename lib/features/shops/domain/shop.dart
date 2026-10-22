enum CompensationType { none, percentage }

enum CompensationBasis { revenue, profit }

class Shop {
  const Shop({
    required this.id,
    required this.name,
    this.sellerName = '',
    this.whatsapp = '',
    this.photoPath,
    this.compensationType = CompensationType.none,
    this.percentageRate = 0,
    this.compensationBasis = CompensationBasis.profit,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String sellerName;
  final String whatsapp;
  final String? photoPath;
  final CompensationType compensationType;
  final int percentageRate;
  final CompensationBasis compensationBasis;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  Shop copyWith({
    String? name,
    String? sellerName,
    String? whatsapp,
    String? photoPath,
    CompensationType? compensationType,
    int? percentageRate,
    CompensationBasis? compensationBasis,
    bool? isArchived,
    DateTime? updatedAt,
  }) => Shop(
    id: id,
    name: name ?? this.name,
    sellerName: sellerName ?? this.sellerName,
    whatsapp: whatsapp ?? this.whatsapp,
    photoPath: photoPath ?? this.photoPath,
    compensationType: compensationType ?? this.compensationType,
    percentageRate: percentageRate ?? this.percentageRate,
    compensationBasis: compensationBasis ?? this.compensationBasis,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
