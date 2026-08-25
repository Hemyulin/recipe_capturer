class ShoppingStore {
  const ShoppingStore({
    required this.id,
    required this.name,
    this.isActive = true,
  });

  final String id;
  final String name;
  final bool isActive;

  factory ShoppingStore.fromJson(Map<String, dynamic> json) {
    return ShoppingStore(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class ShoppingKnowledgeItem {
  const ShoppingKnowledgeItem({
    required this.id,
    required this.name,
    required this.normalizedName,
    this.storeId,
    this.storeName,
  });

  final String id;
  final String name;
  final String normalizedName;
  final String? storeId;
  final String? storeName;

  factory ShoppingKnowledgeItem.fromJson(Map<String, dynamic> json) {
    return ShoppingKnowledgeItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      normalizedName: json['normalizedName'] as String? ?? '',
      storeId: json['storeId'] as String?,
      storeName: json['storeName'] as String?,
    );
  }
}

class ManualShoppingItem {
  const ManualShoppingItem({
    required this.id,
    required this.weekStart,
    required this.name,
    required this.normalizedName,
    this.quantityLabel = '',
    this.storeId,
    this.storeName,
  });

  final String id;
  final String weekStart;
  final String name;
  final String normalizedName;
  final String quantityLabel;
  final String? storeId;
  final String? storeName;

  factory ManualShoppingItem.fromJson(Map<String, dynamic> json) {
    return ManualShoppingItem(
      id: json['id'] as String? ?? '',
      weekStart: json['weekStart'] as String? ?? '',
      name: json['name'] as String? ?? '',
      normalizedName: json['normalizedName'] as String? ?? '',
      quantityLabel: json['quantityLabel'] as String? ?? '',
      storeId: json['storeId'] as String?,
      storeName: json['storeName'] as String?,
    );
  }
}
