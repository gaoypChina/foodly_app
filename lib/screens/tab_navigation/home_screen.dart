import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:version/version.dart';

import '../../app_router.gr.dart';
import '../../services/authentication_service.dart';
import '../../services/settings_service.dart';
import '../../services/version_service.dart';
import '../../widgets/new_version_modal.dart';
import '../../widgets/small_circular_progress_indicator.dart';
import 'tab_navigation_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Logger _log = Logger('HomeScreen');
  late StreamSubscription<User?> _authStream;

  late bool _isLoading;
  User? _currentUser;

  @override
  void initState() {
    _isLoading = true;
    _authStream = AuthenticationService.authenticationStream().listen((user) {
      setStateIfMounted(() {
        _currentUser = user;
        _isLoading = false;
      });
    });
    _checkForNewFeaturesNotification();
    super.initState();
  }

  @override
  void dispose() {
    _authStream.cancel();
    super.dispose();
  }

  void setStateIfMounted(void Function() f) {
    if (mounted) {
      setState(f);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: SmallCircularProgressIndicator()),
      );
    } else if (_currentUser != null) {
      return const TabNavigationView();
    } else if (SettingsService.isFirstUsage) {
      AutoRouter.of(context).replace(OnboardingScreenRoute());
      return const Scaffold();
    } else {
      AutoRouter.of(context).replace(const AuthenticationScreenRoute());
      return const Scaffold();
    }
  }

  void _checkForNewFeaturesNotification() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final String? lastCheckedVersionString = VersionService.lastCheckedVersion;

    _log.fine(
        '_checkForNewFeaturesNotification() with currentVersion: ${packageInfo.version} and lastcheckedversion: $lastCheckedVersionString');

    if (lastCheckedVersionString == null) {
      VersionService.lastCheckedVersion = packageInfo.version;
      return;
    }

    final Version currentVersion = Version.parse(packageInfo.version);
    final Version lastCheckedVersion = Version.parse(lastCheckedVersionString);

    if (lastCheckedVersion >= currentVersion) {
      return;
    }
    if (!mounted) {
      return;
    }
    NewVersionModal.open(context);
  }
}
