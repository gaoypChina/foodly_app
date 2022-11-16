import 'package:auto_size_text/auto_size_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants.dart';
import '../models/grocery.dart';
import '../models/ingredient.dart';
import '../models/meal.dart';
import '../providers/state_providers.dart';
import '../services/meal_service.dart';
import '../services/shopping_list_service.dart';
import '../utils/basic_utils.dart';
import '../utils/convert_util.dart';
import 'main_button.dart';
import 'progress_button.dart';
import 'small_circular_progress_indicator.dart';

class AddToShoppingListModal extends ConsumerStatefulWidget {
  final String? mealId;
  final Meal? meal;

  const AddToShoppingListModal({
    this.mealId,
    this.meal,
    Key? key,
  })  : assert(mealId != null || meal != null),
        super(key: key);

  @override
  _AddToShoppingListModalState createState() => _AddToShoppingListModalState();
}

class _AddToShoppingListModalState
    extends ConsumerState<AddToShoppingListModal> {
  final AutoDisposeStateProvider<ButtonState> _$buttonState =
      AutoDisposeStateProvider((_) => ButtonState.normal);
  final AutoDisposeStateProvider<bool> _$loadingData =
      AutoDisposeStateProvider((_) => false);

  List<IngredientState>? _ingredientStates;

  @override
  void initState() {
    super.initState();
    if (_isMealValid()) {
      _ingredientStates = _getIngredientStates(widget.meal!);
    } else {
      BasicUtils.afterBuild(() => ref.read(_$loadingData.state).state = true);
      MealService.getMealById(widget.mealId!).then((value) {
        if (value != null) {
          _ingredientStates = _getIngredientStates(value);
          ref.read(_$loadingData.state).state = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width > 599
        ? 580.0
        : MediaQuery.of(context).size.width * 0.8;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: (MediaQuery.of(context).size.width - width) / 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: kPadding / 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'add'.tr().toUpperCase(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: _close,
                icon: const Icon(EvaIcons.close),
              ),
            ],
          ),
          const SizedBox(height: kPadding / 2),
          if (_isMealValid())
            _buildIngredientCheckList()
          else
            Consumer(builder: (context, ref, _) {
              final loadState = ref.watch(_$loadingData);
              if (loadState) {
                return _buildSingleChildWrapper(
                  context: context,
                  child: const SmallCircularProgressIndicator(),
                );
              } else if (_ingredientStates != null &&
                  _ingredientStates!.isNotEmpty) {
                return _buildIngredientCheckList();
              }
              return _buildSingleChildWrapper(
                context: context,
                child: Text('try_again_later'.tr()),
              );
            }),
          Consumer(
            builder: (context, ref, _) => MainButton(
              height: 40.0,
              onTap: _addToShoppingList,
              text: 'add'.tr(),
              isProgress: true,
              buttonState: ref.watch(_$buttonState),
            ),
          ),
          const SizedBox(height: kPadding),
        ],
      ),
    );
  }

  Widget _buildSingleChildWrapper({
    required BuildContext context,
    required Widget child,
  }) {
    final height = MediaQuery.of(context).size.height > 200
        ? 200.0
        : MediaQuery.of(context).size.height * 0.4;
    return SizedBox(
      height: height,
      child: Center(child: child),
    );
  }

  Widget _buildIngredientCheckList() {
    if (_ingredientStates == null) {
      return const SizedBox();
    }
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _ingredientStates!.length,
      itemBuilder: (context, index) {
        return Consumer(
          builder: (context, ref, _) {
            final isChecked = ref.watch(_ingredientStates![index].$isChecked);
            final ingredient = _ingredientStates![index].ingredient;
            return CheckboxListTile(
              value: isChecked,
              onChanged: (value) => ref
                  .read(_ingredientStates![index].$isChecked.state)
                  .state = value ?? true,
              title: AutoSizeText(ingredient.name ?? ''),
              subtitle: Text(
                ConvertUtil.amountToString(ingredient.amount, ingredient.unit),
              ),
            );
          },
        );
      },
    );
  }

  void _close() {
    Navigator.pop(context);
  }

  bool _isMealValid() {
    return widget.meal != null &&
        widget.meal!.ingredients != null &&
        widget.meal!.ingredients!.isNotEmpty;
  }

  List<IngredientState> _getIngredientStates(Meal meal) {
    return meal.ingredients!
        .map((ingredient) => IngredientState(
              ingredient: ingredient,
              $isChecked: AutoDisposeStateProvider<bool>((ref) => true),
            ))
        .toList();
  }

  Future<void> _addToShoppingList() async {
    ref.read(_$buttonState.state).state = ButtonState.inProgress;
    final planId = ref.read(planProvider)!.id!;
    final shoppingList =
        await ShoppingListService.getShoppingListByPlanId(planId);
    final ingredientsToAdd = _ingredientStates!
        .where((state) => ref.read(state.$isChecked))
        .map((state) => state.ingredient)
        .toList();

    final addFutures = ingredientsToAdd.map(
      (e) => ShoppingListService.addGrocery(
        shoppingList.id!,
        Grocery(
          name: e.name,
          amount: e.amount,
          unit: e.unit,
          group: e.productGroup,
          lastBoughtEdited: DateTime.now(),
        ),
      ),
    );

    await Future.wait(addFutures);
    ref.read(_$buttonState.state).state = ButtonState.normal;
    _close();
  }
}

class IngredientState {
  final Ingredient ingredient;
  AutoDisposeStateProvider<bool> $isChecked;

  IngredientState({
    required this.ingredient,
    required this.$isChecked,
  });
}
