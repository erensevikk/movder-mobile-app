import 'package:flutter/material.dart';

import '../base/base_view_model.dart';

mixin ViewModelBindingMixin<T extends StatefulWidget, VM extends BaseViewModel>
    on State<T> {
  late final VM viewModel = createViewModel();
  VoidCallback? _listener;

  VM createViewModel();

  Widget buildWithViewModel(BuildContext context, VM viewModel);

  void onViewModelReady(VM viewModel) {}

  @override
  void initState() {
    super.initState();
    _listener = () {
      if (mounted) {
        setState(() {});
      }
    };
    viewModel.addListener(_listener!);
    onViewModelReady(viewModel);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        viewModel.initialize();
      }
    });
  }

  @override
  void dispose() {
    if (_listener != null) {
      viewModel.removeListener(_listener!);
    }
    viewModel.disposeViewModel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildWithViewModel(context, viewModel);
}
