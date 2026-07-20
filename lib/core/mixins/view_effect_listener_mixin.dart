import 'dart:async';

import 'package:flutter/material.dart';

import '../base/base_view_model.dart';
import '../base/view_effect.dart';
import 'view_model_binding_mixin.dart';

mixin ViewEffectListenerMixin<T extends StatefulWidget,
    VM extends BaseViewModel> on State<T>, ViewModelBindingMixin<T, VM> {
  StreamSubscription<ViewEffect>? _effectsSubscription;

  @override
  void initState() {
    super.initState();
    _effectsSubscription = viewModel.effects.listen((effect) async {
      if (!mounted) return;

      if (effect is ShowSnackbarEffect) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(effect.message),
            backgroundColor: effect.backgroundColor,
          ),
        );
        return;
      }

      if (effect is NavigateToEffect) {
        final route = MaterialPageRoute<Object?>(builder: effect.pageBuilder);
        Object? poppedResult;
        if (effect.clearStack) {
          await Navigator.of(context).pushAndRemoveUntil(route, (_) => false);
          return;
        }
        if (effect.replace) {
          await Navigator.of(context).pushReplacement(route);
          return;
        }
        poppedResult = await Navigator.of(context).push<Object?>(route);
        effect.onPopped?.call(poppedResult);
        return;
      }

      if (effect is PopEffect) {
        Navigator.of(context).pop(effect.result);
        return;
      }

      if (effect is ShowDialogEffect) {
        await showDialog<void>(
          context: context,
          barrierDismissible: effect.barrierDismissible,
          builder: effect.builder,
        );
        return;
      }

      if (effect is OpenBottomSheetEffect) {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: effect.isScrollControlled,
          builder: effect.builder,
        );
      }
    });
  }

  @override
  void dispose() {
    _effectsSubscription?.cancel();
    super.dispose();
  }
}
