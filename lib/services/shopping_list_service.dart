import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:foodly/models/grocery.dart';
import 'package:logging/logging.dart';

import '../models/grocery.dart';
import '../models/shopping_list.dart';

class ShoppingListService {
  static final log = Logger('ShoppingListService');

  static FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ShoppingListService._();

  static Future<ShoppingList> createShoppingListWithPlanId(
      String planId) async {
    log.finer('Call createShoppingListWithPlanId with $planId');
    final list = new ShoppingList(meals: [], planId: planId);

    final id = new DateTime.now().microsecondsSinceEpoch.toString();
    await _firestore.collection('shoppinglists').doc(id).set(list.toMap());
    list.id = id;

    return list;
  }

  static Future<ShoppingList> getShoppingListByPlanId(String planId) async {
    log.finer('Call getShoppingListByPlanId with $planId');
    final snaps = await _firestore
        .collection('shoppinglists')
        .where('planId', isEqualTo: planId)
        .limit(1)
        .get();

    return ShoppingList.fromMap(snaps.docs.first.id, snaps.docs.first.data());
  }

  static Stream<List<Grocery>> streamShoppingList(String listId) {
    log.finer('Call streamShoppingList with $listId');
    return _firestore
        .collection('shoppinglists')
        .doc(listId)
        .collection('groceries')
        .snapshots()
        .map((event) =>
            event.docs.map((e) => Grocery.fromMap(e.id, e.data())).toList());
  }

  static Future<void> updateGrocery(String listId, Grocery grocery) async {
    log.finer(
        'Call updateGrocery with listId: $listId | Grocery: ${grocery.toMap()}');
    return _firestore
        .collection('shoppinglists')
        .doc(listId)
        .collection('groceries')
        .doc(grocery.id)
        .update(grocery.toMap());
  }

  static Future<void> addGrocery(String listId, Grocery grocery) async {
    log.finer(
        'Call addGrocery with listId: $listId | Grocery: ${grocery.toMap()}');
    return _firestore
        .collection('shoppinglists')
        .doc(listId)
        .collection('groceries')
        .add(grocery.toMap());
  }

  static Future<void> deleteGrocery(String listId, String groceryId) async {
    log.finer(
        'Call deleteGrocery with listId: $listId | groceryId: $groceryId');
    return _firestore
        .collection('shoppinglists')
        .doc(listId)
        .collection('groceries')
        .doc(groceryId)
        .delete();
  }

  static Future<void> deleteAllBoughtGrocery(String listId) async {
    log.finer('Call deleteAllBoughtGrocery with $listId');
    final snaps = await _firestore
        .collection('shoppinglists')
        .doc(listId)
        .collection('groceries')
        .where('bought', isEqualTo: true)
        .get();

    log.finest(
        'deleteAllBoughtGrocery: Query results: ${snaps.docs.toString()}');

    return Future.wait(
        snaps.docs.map((e) => deleteGrocery(listId, e.id)).toList());
  }
}
