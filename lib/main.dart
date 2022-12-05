import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'app_router.gr.dart';
import 'constants.dart';
import 'models/foodly_user.dart';
import 'models/link_metadata.dart';
import 'models/plan.dart';
import 'providers/data_provider.dart';
import 'providers/state_providers.dart';
import 'services/app_review_service.dart';
import 'services/authentication_service.dart';
import 'services/foodly_user_service.dart';
import 'services/image_cache_service.dart';
import 'services/in_app_purchase_service.dart';
import 'services/link_metadata_service.dart';
import 'services/lunix_api_service.dart';
import 'services/plan_service.dart';
import 'services/settings_service.dart';
import 'services/shopping_list_service.dart';
import 'services/version_service.dart';
import 'utils/basic_utils.dart';
import 'widgets/disposable_widget.dart';

Future<void> _configureFirebase() async {
  await Firebase.initializeApp();
  if (foundation.kDebugMode) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
  } else {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    await FirebaseAppCheck.instance.activate();
    final packageInfo = await PackageInfo.fromPlatform();
    await Future.wait([
      FirebaseAnalytics.instance
          .setDefaultEventParameters({'version': packageInfo.version}),
      FirebaseCrashlytics.instance.setCustomKey('version', packageInfo.version),
      FirebaseCrashlytics.instance
          .setCustomKey('buildNumber', packageInfo.buildNumber),
    ]);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await _configureFirebase();
  await initializeHive();
  runZonedGuarded<void>(
    () {
      runApp(
        ProviderScope(
          child: EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('de')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: const FoodlyApp(),
          ),
        ),
      );
    },
    (error, stack) => FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      fatal: true,
    ),
  );
}

Future<void> initializeHive() async {
  final dir = await getApplicationDocumentsDirectory();
  Hive.init(dir.path);
  Hive.registerAdapter(LinkMetadataAdapter());
  await Future.wait<dynamic>([
    SettingsService.initialize(),
    LinkMetadataService.initialize(),
    VersionService.initialize(),
    ImageCacheService.initialize(),
    AppReviewService.initialize(),
    PlanService.initialize(),
    InAppPurchaseService.initialize(),
  ]);
}

class FoodlyApp extends ConsumerStatefulWidget {
  const FoodlyApp({foundation.Key? key}) : super(key: key);

  @override
  _FoodlyAppState createState() => _FoodlyAppState();
}

class _FoodlyAppState extends ConsumerState<FoodlyApp> with DisposableWidget {
  final Logger _log = Logger('FoodlyApp');

  final _appRouter = AppRouter();

  @override
  void initState() {
    _initializeLogger();
    _listenForShareIntent();
    super.initState();
    InAppPurchaseService.setRef(ref);
    SettingsService.setRef(ref);
  }

  @override
  void dispose() {
    cancelSubscriptions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthenticationService.authenticationStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active ||
            snapshot.connectionState == ConnectionState.done) {
          _loadActivePlan().then((_) {
            _loadActiveShoppingList();
            _loadGroceryGroups();
          });
          _loadActiveUser();
          return Consumer(
            builder: (context, ref, _) {
              final plan = ref.watch(planProvider);
              _log.finer('PlanProvider Update: ${plan?.id}');

              return MaterialApp.router(
                routerDelegate: _appRouter.delegate(),
                routeInformationParser: _appRouter.defaultRouteParser(),
                debugShowCheckedModeBanner: false,
                themeMode: ThemeMode.light,
                localizationsDelegates: [
                  ...context.localizationDelegates,
                  const LocaleNamesLocalizationsDelegate(),
                ],
                supportedLocales: context.supportedLocales,
                locale: context.locale,
              );
            },
          );
        } else {
          return const MaterialApp(home: Scaffold());
        }
      },
    );
  }

  Future<void> _loadActivePlan() async {
    final currentPlan = ref.read(planProvider);
    if (currentPlan == null) {
      final String? planId = await PlanService.getCurrentPlanId();

      if (planId != null && planId.isNotEmpty) {
        final Plan? newPlan = await PlanService.getPlanById(planId);
        if (!mounted) {
          return;
        }
        ref.read(planProvider.notifier).state = newPlan;
      }
    }

    BasicUtils.afterBuild(
      () => ref.read(initialPlanLoadingProvider.notifier).state = false,
    );
  }

  Future<void> _loadActiveUser() async {
    final firebaseUser = AuthenticationService.currentUser;
    if (firebaseUser != null) {
      FirebaseCrashlytics.instance.setUserIdentifier(firebaseUser.uid);
      final FoodlyUser? user =
          await FoodlyUserService.getUserById(firebaseUser.uid);
      if (!mounted || user == null) {
        return;
      }
      ref.read(userProvider.notifier).state = user;
      await InAppPurchaseService.setUserId(user.id!);
      if (user.isPremium != null && user.isPremium!) {
        ref.read(InAppPurchaseService.$userIsSubscribed.notifier).state = true;
      }
    } else {
      FirebaseCrashlytics.instance.setUserIdentifier('');
      BasicUtils.afterBuild(() => ref.read(userProvider.notifier).state = null);
    }

    BasicUtils.afterBuild(
      () => ref.read(initialUserLoadingProvider.notifier).state = false,
    );
  }

  Future<void> _loadActiveShoppingList() async {
    final planId = ref.read(planProvider)?.id;
    if (planId == null) {
      return;
    }
    final shoppingList = await ShoppingListService.getShoppingListByPlanId(
      planId,
    );
    ref.read(shoppingListIdProvider.notifier).state = shoppingList.id;
  }

  Future<void> _loadGroceryGroups() async {
    final langCode = context.locale.languageCode;
    final groups = await LunixApiService.getGroceryGroups(langCode);
    ref.read(dataGroceryGroupsProvider.notifier).state = groups;
  }

  void _initializeLogger() {
    if (foundation.kDebugMode) {
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen((record) {
        // ignore: avoid_print
        print('${record.level.name}: ${record.loggerName}: ${record.message}');
        if (record.error != null) {
          // ignore: avoid_print
          print(record.error);
        }
      }).canceledBy(this);
    } else {
      Logger.root.level = Level.ALL;
      Logger.root.onRecord
          .where((record) => record.level >= Level.SEVERE)
          .listen((record) {
        final message =
            '${record.loggerName} (${record.level.name}): ${record.message}';
        FirebaseCrashlytics.instance.recordError(
          message,
          record.stackTrace,
          reason: record.error,
        );
      }).canceledBy(this);
    }
  }

  void _listenForShareIntent() {
    // For sharing or opening urls/text coming from outside the app while the app is in the memory
    ReceiveSharingIntent.getTextStream()
        .listen(_handleReceivedMealShare,
            onError: (dynamic err) =>
                _log.severe('ERR in ReceiveSharingIntent.getTextStream()', err))
        .canceledBy(this);

    // For sharing or opening urls/text coming from outside the app while the app is closed
    ReceiveSharingIntent.getInitialText().then(_handleReceivedMealShare);
  }

  void _handleReceivedMealShare(String? value) {
    if (AuthenticationService.currentUser == null || value == null) {
      return;
    }

    if (value.startsWith(kChefkochShareEndpoint)) {
      _appRouter
          .navigate(MealCreateScreenRoute(id: Uri.encodeComponent(value)));
    } else if (value.contains(kChefkochShareEndpoint)) {
      final startIndex = value.indexOf(kChefkochShareEndpoint);
      final extractedLink =
          value.substring(startIndex, value.length).split(' ')[0];
      _appRouter.navigate(
          MealCreateScreenRoute(id: Uri.encodeComponent(extractedLink)));
    }
  }
}

class ScrollBehaviorModified extends ScrollBehavior {
  const ScrollBehaviorModified();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.android:
        return const BouncingScrollPhysics();
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return const ClampingScrollPhysics();
    }
  }
}
