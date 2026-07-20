import 'package:flutter/material.dart';

abstract class ViewEffect {
  const ViewEffect();
}

class ShowSnackbarEffect extends ViewEffect {
  const ShowSnackbarEffect({
    required this.message,
    this.backgroundColor,
  });

  final String message;
  final Color? backgroundColor;
}

class NavigateToEffect extends ViewEffect {
  const NavigateToEffect({
    required this.pageBuilder,
    this.replace = false,
    this.clearStack = false,
    this.onPopped,
  });

  final WidgetBuilder pageBuilder;
  final bool replace;
  final bool clearStack;
  final ValueChanged<Object?>? onPopped;
}

class PopEffect extends ViewEffect {
  const PopEffect([this.result]);

  final Object? result;
}

class ShowDialogEffect extends ViewEffect {
  const ShowDialogEffect({
    required this.builder,
    this.barrierDismissible = true,
  });

  final WidgetBuilder builder;
  final bool barrierDismissible;
}

class OpenBottomSheetEffect extends ViewEffect {
  const OpenBottomSheetEffect({
    required this.builder,
    this.isScrollControlled = false,
  });

  final WidgetBuilder builder;
  final bool isScrollControlled;
}
