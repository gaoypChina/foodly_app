import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodly/models/foodly_user.dart';
import 'package:foodly/models/meal.dart';

import '../models/plan.dart';

/// Provides the active plan object.
final planProvider = StateProvider<Plan>((ref) => null);

/// Provides the active foodly user object.
final userProvider = StateProvider<FoodlyUser>((ref) => null);

/// Provides the active plan object.
final allMealsProvider = StateProvider<List<Meal>>((ref) => []);
