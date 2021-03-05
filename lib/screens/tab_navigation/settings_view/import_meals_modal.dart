import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodly/models/plan.dart';
import 'package:foodly/providers/state_providers.dart';
import 'package:foodly/services/meal_service.dart';
import 'package:foodly/services/plan_service.dart';
import 'package:foodly/widgets/small_circular_progress_indicator.dart';

import '../../../constants.dart';

class ImportMealsModal extends StatelessWidget {
  final List<String> planIds;

  ImportMealsModal(this.planIds);

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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: kPadding),
              child: Text(
                'GERICHTE IMPORTIEREN',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          FutureBuilder<List<Plan>>(
            future: PlanService.getPlansByIds(planIds),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data.length,
                  itemBuilder: (context, index) =>
                      CopyPlanMealsTile(snapshot.data[index]),
                );
              } else {
                return SizedBox(
                  height: 200,
                  child: Center(
                    child: SmallCircularProgressIndicator(),
                  ),
                );
              }
            },
          ),
          SizedBox(
            height: kPadding * 2 + MediaQuery.of(context).viewInsets.bottom,
          ),
        ],
      ),
    );
  }
}

class CopyPlanMealsTile extends StatefulWidget {
  final Plan plan;

  CopyPlanMealsTile(this.plan);

  @override
  _CopyPlanMealsTileState createState() => _CopyPlanMealsTileState();
}

class _CopyPlanMealsTileState extends State<CopyPlanMealsTile> {
  CopyButtonState _buttonState = CopyButtonState.NORMAL;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(EvaIcons.minusOutline),
      title: Text(widget.plan.name),
      trailing: IconButton(
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buttonState == CopyButtonState.NORMAL
              ? Icon(EvaIcons.copyOutline, key: UniqueKey())
              : _buttonState == CopyButtonState.LOADING
                  ? SmallCircularProgressIndicator(key: UniqueKey())
                  : Icon(
                      EvaIcons.checkmark,
                      key: UniqueKey(),
                      color: Colors.green,
                    ),
        ),
        onPressed: () => _copyMeals(
          context.read(planProvider).state.id,
        ),
      ),
    );
  }

  void _copyMeals(String currentPlanId) async {
    setState(() {
      _buttonState = CopyButtonState.LOADING;
    });

    final copiedMeals = await MealService.getAllMeals(widget.plan.id);
    await MealService.addMeals(currentPlanId, copiedMeals);

    setState(() {
      _buttonState = CopyButtonState.DONE;
    });
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _buttonState = CopyButtonState.NORMAL;
    });
  }
}

enum CopyButtonState { NORMAL, LOADING, DONE }
