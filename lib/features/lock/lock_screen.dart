import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../core/security/security_service.dart';
import 'cubit/app_lock_cubit.dart';

/// Écran plein écran de déverrouillage par code PIN et/ou biométrie.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _security = sl<SecurityService>();
  String _entered = '';
  bool _error = false;
  bool _checking = false;

  static const int _pinLength = 4;

  @override
  void initState() {
    super.initState();
    // Propose la biométrie automatiquement à l'ouverture si activée.
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    if (!_security.isBiometricEnabled) return;
    if (!await _security.canUseBiometrics()) return;
    final ok = await _security.authenticateBiometric();
    if (ok && mounted) context.read<AppLockCubit>().unlock();
  }

  Future<void> _onDigit(int d) async {
    if (_checking || _entered.length >= _pinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _error = false;
      _entered += '$d';
    });
    if (_entered.length == _pinLength) {
      setState(() => _checking = true);
      final ok = await _security.verifyPin(_entered);
      if (!mounted) return;
      if (ok) {
        context.read<AppLockCubit>().unlock();
      } else {
        HapticFeedback.vibrate();
        setState(() {
          _error = true;
          _entered = '';
          _checking = false;
        });
      }
    }
  }

  void _onDelete() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                Icon(Icons.lock_outline,
                    size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('FinTrack verrouillé',
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  _error ? 'Code incorrect, réessaie' : 'Entre ton code PIN',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _error
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            // Points de progression du PIN.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLength, (i) {
                final filled = i < _entered.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    border: Border.all(color: theme.colorScheme.primary),
                  ),
                );
              }),
            ),
            _Keypad(
              onDigit: _onDigit,
              onDelete: _onDelete,
              onBiometric:
                  _security.isBiometricEnabled ? _tryBiometric : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onDelete,
    this.onBiometric,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onBiometric;

  @override
  Widget build(BuildContext context) {
    Widget key(Widget child, VoidCallback? onTap) {
      return SizedBox(
        width: 84,
        height: 84,
        child: InkWell(
          borderRadius: BorderRadius.circular(42),
          onTap: onTap,
          child: Center(child: child),
        ),
      );
    }

    Widget digit(int d) => key(
          Text('$d', style: Theme.of(context).textTheme.headlineMedium),
          () => onDigit(d),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [digit(1), digit(2), digit(3)]),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [digit(4), digit(5), digit(6)]),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [digit(7), digit(8), digit(9)]),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              onBiometric != null
                  ? key(const Icon(Icons.fingerprint, size: 32), onBiometric)
                  : const SizedBox(width: 84),
              digit(0),
              key(const Icon(Icons.backspace_outlined), onDelete),
            ],
          ),
        ],
      ),
    );
  }
}
