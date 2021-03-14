import 'package:auto_route/auto_route.dart';
import 'package:auto_route/auto_route_annotations.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodly/providers/state_providers.dart';
import 'package:foodly/screens/meal_create/chefkoch_import_modal.dart';
import 'package:foodly/screens/meal_create/edit_ingredients.dart';
import 'package:foodly/services/authentication_service.dart';
import 'package:foodly/widgets/full_screen_loader.dart';
import 'package:foodly/widgets/main_appbar.dart';

import '../../constants.dart';
import '../../models/meal.dart';
import '../../services/meal_service.dart';
import '../../utils/main_snackbar.dart';
import '../../widgets/main_button.dart';
import '../../widgets/main_text_field.dart';
import '../../widgets/markdown_editor.dart';
import '../../widgets/progress_button.dart';
import 'edit_list_content.dart';

class MealCreateScreen extends StatefulWidget {
  final String id;

  const MealCreateScreen({
    @PathParam() this.id,
  });

  @override
  _MealCreateScreenState createState() => _MealCreateScreenState();
}

class _MealCreateScreenState extends State<MealCreateScreen> {
  bool _isLoadingMeal;
  bool _isCreatingMeal;

  Meal _meal = new Meal();
  TextEditingController _titleController;
  TextEditingController _urlController;
  TextEditingController _sourceController;
  TextEditingController _durationController;
  TextEditingController _instructionsController;

  ButtonState _buttonState;

  ScrollController _scrollController;

  @override
  void initState() {
    if (widget.id == 'create') {
      _isLoadingMeal = false;
      _isCreatingMeal = true;
      _titleController = new TextEditingController();
      _urlController = new TextEditingController();
      _sourceController = new TextEditingController();
      _durationController = new TextEditingController();
      _instructionsController = new TextEditingController();
      _meal.ingredients = [];
    } else {
      _isLoadingMeal = true;
      _isCreatingMeal = false;
      MealService.getMealById(widget.id).then((meal) {
        _meal = meal;
        _titleController = new TextEditingController(text: meal.name);
        _urlController = new TextEditingController(text: meal.imageUrl);
        _sourceController = new TextEditingController(text: meal.source);
        _durationController =
            new TextEditingController(text: meal.duration.toString());
        _instructionsController =
            new TextEditingController(text: meal.instruction);
        _meal.ingredients = _meal.ingredients ?? [];

        setState(() {
          _isLoadingMeal = false;
        });
      });
    }

    _buttonState = ButtonState.normal;
    _scrollController = new ScrollController();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _meal.planId = context.read(planProvider).state.id;
    final fullWidth = MediaQuery.of(context).size.width > 699
        ? 700
        : MediaQuery.of(context).size.width * 0.8;

    return Scaffold(
      appBar: MainAppBar(
        text: _isCreatingMeal ? 'Gericht erstellen' : 'Gericht bearbeiten',
        scrollController: _scrollController,
        actions: [
          IconButton(
            icon: Icon(
              EvaIcons.downloadOutline,
              color: Theme.of(context).textTheme.bodyText1.color,
            ),
            onPressed: () => _openChefkochImport(),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Center(
                child: Container(
                  width: fullWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      MainTextField(
                        controller: _titleController,
                        title: 'Name',
                      ),
                      Divider(),
                      _isLoadingMeal
                          ? EditIngredients(
                              key: UniqueKey(),
                              content: [],
                              onChanged: null,
                              title: 'Zutaten:',
                            )
                          : EditIngredients(
                              content: _meal.ingredients ?? [],
                              onChanged: (results) {
                                setState(() {
                                  _meal.ingredients = results;
                                });
                              },
                              title: 'Zutaten:',
                            ),
                      Divider(),
                      Container(
                        width: double.infinity,
                        child: Text(
                          'Anleitung',
                          style: Theme.of(context).textTheme.bodyText1,
                        ),
                      ),
                      _isLoadingMeal
                          ? MarkdownEditor(
                              key: UniqueKey(),
                              onChange: null,
                              initialValue: '',
                            )
                          : MarkdownEditor(
                              textEditingController: _instructionsController,
                            ),
                      Divider(),
                      MainTextField(
                        controller: _urlController,
                        title: 'Link zum Bild',
                        placeholder: 'https://image.food.com/cake.jpg',
                      ),
                      Row(
                        children: [
                          Flexible(
                            flex: 2,
                            child: MainTextField(
                              controller: _sourceController,
                              title: 'Quelle',
                              placeholder: 'Chefkoch',
                            ),
                          ),
                          SizedBox(width: kPadding / 2),
                          Flexible(
                            flex: 1,
                            child: MainTextField(
                              controller: _durationController,
                              title: 'Dauer (min)',
                              placeholder: '10',
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      Divider(),
                      EditListContent(
                        content: _meal.tags,
                        onChanged: (list) => _meal.tags = list,
                        title: 'Kategorien:',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: kPadding),
                        child: MainButton(
                          text: 'Speichern',
                          onTap: _createMeal,
                          isProgress: true,
                          buttonState: _buttonState,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _isLoadingMeal ? FullScreenLoader() : SizedBox(),
        ],
      ),
    );
  }

  Future<void> _createMeal() async {
    setState(() {
      _buttonState = ButtonState.inProgress;
    });

    _meal.name = _titleController.text;
    _meal.imageUrl = _urlController.text;
    _meal.source = _sourceController.text;
    _meal.duration = int.tryParse(_durationController.text) ?? 0;
    _meal.instruction = _instructionsController.text;
    _meal.createdBy = _isCreatingMeal
        ? AuthenticationService.currentUser.uid
        : _meal.createdBy;

    if (_formIsValid()) {
      try {
        final newMeal = _isCreatingMeal
            ? await MealService.createMeal(_meal)
            : await MealService.updateMeal(_meal);
        _buttonState = ButtonState.normal;
        ExtendedNavigator.root.pop(newMeal);
      } catch (e) {
        print(e);
        MainSnackbar(
          message:
              'Es ist ein Fehler aufgetreten. Prüfe deine Internetverbindung oder versuche es später erneut.',
          isError: true,
        ).show(context);
        _buttonState = ButtonState.error;
      }
    } else {
      MainSnackbar(
        message: 'Bitte vergib einen Namen und mindestens eine Zutat.',
        isError: true,
      ).show(context);
      _buttonState = ButtonState.error;
    }

    // update button state
    setState(() {});
  }

  bool _formIsValid() {
    return _titleController.text.isNotEmpty && _meal.ingredients.isNotEmpty;
  }

  void _openChefkochImport() async {
    final result = await showModalBottomSheet<Meal>(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(10.0),
        ),
      ),
      isScrollControlled: true,
      context: context,
      builder: (_) => ChefkochImportModal(),
    );

    if (result != null) {
      setState(() {
        _titleController.text = result.name;
        _urlController.text = result.imageUrl;
        _sourceController.text = result.source;
        _durationController.text = result.duration.toString();
        _instructionsController.text = result.instruction;
        _meal.ingredients = result.ingredients ?? [];

        _meal.tags = result.tags;
      });
    }
  }
}
