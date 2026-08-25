import 'package:cookbuk/domain/shopping_knowledge.dart';

abstract interface class ShoppingKnowledgeRepository {
  Future<List<ShoppingStore>> getStores();

  Future<ShoppingStore> addStore(String name);

  Future<ShoppingStore> updateStore({
    required String id,
    String? name,
    bool? isActive,
  });

  Future<void> deleteStore(String id);

  Future<List<ShoppingKnowledgeItem>> getItems();

  Future<ShoppingKnowledgeItem> addItem({
    required String name,
    String? storeId,
  });

  Future<ShoppingKnowledgeItem> updateItem({
    required String id,
    String? name,
    String? storeId,
  });

  Future<void> deleteItem(String id);

  Future<List<ManualShoppingItem>> getManualItems({
    required DateTime weekStart,
  });

  Future<List<ManualShoppingItem>> addManualItem({
    required DateTime weekStart,
    required String name,
    String quantityLabel = '',
    String? storeId,
    bool rememberStore = false,
  });

  Future<List<ManualShoppingItem>> updateManualItem({
    required String id,
    String? name,
    String? quantityLabel,
    String? storeId,
    bool rememberStore = false,
  });

  Future<void> deleteManualItem(String id);
}
