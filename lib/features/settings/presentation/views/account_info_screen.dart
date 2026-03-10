import 'package:flutter/material.dart';

import '../../../../core/base/base_state.dart';
import '../../../../core/mixins/view_effect_listener_mixin.dart';
import '../../../../core/mixins/view_model_binding_mixin.dart';
import '../../../../core/utils/turkish_cities.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../view_models/account_info_view_model.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen>
    with
        ViewModelBindingMixin<AccountInfoScreen, AccountInfoViewModel>,
        ViewEffectListenerMixin<AccountInfoScreen, AccountInfoViewModel> {
  @override
  AccountInfoViewModel createViewModel() => AccountInfoViewModel();

  @override
  Widget buildWithViewModel(BuildContext context, AccountInfoViewModel vm) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text(
          'Kisisel Bilgiler',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: switch (vm.status) {
        ViewStatus.loading => const LoadingView(),
        ViewStatus.error => ErrorView(
            message: vm.errorMessage ?? 'Profil bilgileri alinamadi.',
            onRetry: vm.initialize,
          ),
        _ => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _FieldLabel(text: 'Kullanici Adi'),
                _InputField(
                  initialValue: vm.username,
                  icon: Icons.person_outline,
                  hint: 'Kullanici adi',
                  errorText: vm.usernameError,
                  onChanged: vm.updateUsername,
                ),
                const SizedBox(height: 20),
                const _FieldLabel(text: 'E-posta'),
                _InputField(
                  initialValue: vm.email,
                  icon: Icons.email_outlined,
                  hint: 'E-posta adresi',
                  keyboardType: TextInputType.emailAddress,
                  errorText: vm.emailError,
                  onChanged: vm.updateEmail,
                ),
                const SizedBox(height: 20),
                const _FieldLabel(text: 'Sehir'),
                _CityPicker(vm: vm),
                if (vm.cityError != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    vm.cityError!,
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: vm.isLoading ? null : vm.save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: vm.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Degisiklikleri Kaydet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
      },
    );
  }
}

class _CityPicker extends StatelessWidget {
  const _CityPicker({required this.vm});

  final AccountInfoViewModel vm;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final selected = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: const Color(0xFF1E1E1E),
          builder: (context) => SafeArea(
            child: ListView(
              children: turkishCities
                  .map(
                    (city) => ListTile(
                      title: Text(
                        city,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () => Navigator.of(context).pop(city),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
        if (selected != null) {
          vm.updateCity(selected);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          prefixIcon:
              const Icon(Icons.location_city_outlined, color: Colors.white54),
          suffixIcon:
              const Icon(Icons.arrow_drop_down_rounded, color: Colors.white54),
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        child: Text(
          vm.city ?? 'Sehir Sec',
          style: TextStyle(
            color: vm.city == null ? Colors.white24 : Colors.white,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InputField extends StatefulWidget {
  const _InputField({
    required this.initialValue,
    required this.icon,
    required this.hint,
    required this.onChanged,
    this.keyboardType,
    this.errorText,
  });

  final String initialValue;
  final IconData icon;
  final String hint;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final String? errorText;

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void didUpdateWidget(covariant _InputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: Icon(widget.icon, color: Colors.white54),
        errorText: widget.errorText,
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
