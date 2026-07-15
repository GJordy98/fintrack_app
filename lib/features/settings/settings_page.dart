import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../core/money/currency.dart';
import '../../core/money/currency_cubit.dart';
import '../../core/premium/premium_cubit.dart';
import '../../core/security/security_service.dart';
import '../../core/theme/theme_cubit.dart';
import '../premium/premium_page.dart';
import '../../data/settings_service.dart';
import '../../data/sync/sync_service.dart';
import '../auth/cubit/auth_cubit.dart';
import '../auth/cubit/auth_state.dart';
import '../auth/ui/login_page.dart';
import '../lock/cubit/app_lock_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        children: [
          const _SectionTitle('Devise'),
          BlocBuilder<CurrencyCubit, String>(
            builder: (context, code) {
              return RadioGroup<String>(
                groupValue: code,
                onChanged: (v) {
                  if (v != null) {
                    context.read<CurrencyCubit>().setCurrency(v);
                  }
                },
                child: Column(
                  children: Currency.all.map((c) {
                    return RadioListTile<String>(
                      value: c.code,
                      title: Text('${c.label} (${c.symbol})'),
                      subtitle: Text(c.decimalDigits == 0
                          ? 'Sans décimales'
                          : '2 décimales'),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'La devise sélectionnée est utilisée partout dans l\'application. '
              'Les montants déjà saisis ne sont pas convertis, seule leur devise '
              'd\'affichage change.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const Divider(),
          const _SectionTitle('Apparence'),
          BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, mode) {
              return RadioGroup<ThemeMode>(
                groupValue: mode,
                onChanged: (v) {
                  if (v != null) context.read<ThemeCubit>().setMode(v);
                },
                child: const Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.system,
                      title: Text('Système'),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      title: Text('Clair'),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      title: Text('Sombre'),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          const _SectionTitle('Sécurité'),
          const _SecuritySection(),
          const Divider(),
          const _SectionTitle('Premium'),
          const _PremiumSection(),
          const Divider(),
          const _SectionTitle('Cloud'),
          const _CloudSection(),
        ],
      ),
    );
  }
}

/// Statut premium + actions (s'abonner, restaurer). En debug, expose un
/// interrupteur de test qui débloque tout localement sans achat.
class _PremiumSection extends StatelessWidget {
  const _PremiumSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PremiumCubit, PremiumState>(
      builder: (context, state) {
        return Column(
          children: [
            ListTile(
              leading: Icon(
                state.isPremium
                    ? Icons.verified
                    : Icons.workspace_premium_outlined,
                color: state.isPremium
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(state.isPremium ? 'Premium actif' : 'Version gratuite'),
              subtitle: Text(state.isPremium
                  ? 'Toutes les fonctionnalités sont débloquées.'
                  : 'Débloque prévisions, récurrentes auto, export et plus.'),
              trailing: state.isPremium ? null : const Icon(Icons.chevron_right),
              onTap: state.isPremium
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PremiumPage(),
                        ),
                      ),
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Restaurer mes achats'),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                await context.read<PremiumCubit>().restore();
                if (context.mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Recherche de tes achats…')),
                  );
                }
              },
            ),
            if (kDebugMode)
              SwitchListTile(
                secondary: const Icon(Icons.bug_report_outlined),
                title: const Text('Premium (test / debug)'),
                subtitle: const Text('Débloque tout localement sans achat'),
                value: sl<SettingsService>().premiumDevOverride,
                onChanged: (v) =>
                    context.read<PremiumCubit>().setDevOverride(v),
              ),
          ],
        );
      },
    );
  }
}

class _CloudSection extends StatefulWidget {
  const _CloudSection();

  @override
  State<_CloudSection> createState() => _CloudSectionState();
}

class _CloudSectionState extends State<_CloudSection> {
  final _sync = sl<SyncService>();
  final _settings = sl<SettingsService>();
  bool _busy = false;

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    final result = await _sync.syncNow();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.success
            ? 'Synchro OK — ${result.pushed} envoyé(s), ${result.pulled} reçu(s)'
            : 'Échec de la synchro : ${result.error}'),
      ),
    );
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text(
            'Tes données restent sur cet appareil. Elles ne seront plus '
            'sauvegardées sur le cloud tant que tu ne te reconnectes pas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<AuthCubit>().signOut();
    }
  }

  /// Boîte de dialogue pour saisir l'URL du serveur (tunnel ngrok du moment).
  Future<void> _editServerUrl() async {
    final controller =
        TextEditingController(text: _settings.serverBaseUrl ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('URL du serveur'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            hintText: 'https://fintrack-backend.onrender.com',
            helperText: 'Laisse vide pour utiliser le serveur par défaut',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''), // réinitialiser
            child: const Text('Par défaut'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, null), // annuler
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (result == null) return; // annulé
    await _settings.setServerBaseUrl(result.isEmpty ? null : result);
    if (mounted) setState(() {});
  }

  Widget _buildServerUrlTile() {
    final custom = _settings.serverBaseUrl;
    return ListTile(
      leading: const Icon(Icons.dns_outlined),
      title: const Text('URL du serveur'),
      subtitle: Text(custom ?? 'Serveur par défaut (Render)'),
      trailing: const Icon(Icons.edit_outlined),
      onTap: _editServerUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildServerUrlTile(),
        const Divider(height: 1),
        BlocBuilder<AuthCubit, AuthState>(
          builder: (context, authState) {
            final user = authState is Authenticated ? authState.user : null;
            return user == null
                ? _buildSignedOut(context)
                : _buildSignedIn(context, user.email ?? 'Compte connecté');
          },
        ),
      ],
    );
  }

  /// Non connecté : proposition de lier ses données à un compte.
  Widget _buildSignedOut(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: const Text('Se connecter pour sauvegarder'),
          subtitle: const Text('E-mail ou Google — pour ne jamais perdre tes données'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const LoginPage()),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Lie tes données à un compte pour les sauvegarder sur le cloud et '
            'les retrouver après une réinstallation ou sur un autre appareil. '
            'L\'application reste entièrement utilisable sans compte.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// Connecté : compte, synchro, déconnexion.
  Widget _buildSignedIn(BuildContext context, String email) {
    final last = _settings.lastSyncAt;
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: const Text('Compte lié'),
          subtitle: Text(email),
        ),
        ListTile(
          leading: const Icon(Icons.cloud_sync_outlined),
          title: const Text('Synchroniser maintenant'),
          subtitle: Text(last == null
              ? 'Jamais synchronisé'
              : 'Dernière synchro : ${last.replaceFirst('T', ' ').split('.').first}'),
          trailing: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right),
          onTap: _busy ? null : _syncNow,
        ),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Se déconnecter',
              style: TextStyle(color: Colors.red)),
          onTap: _signOut,
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'La synchronisation est automatique au démarrage et à chaque retour '
            'dans l\'application. Tu peux aussi la lancer manuellement.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _SecuritySection extends StatefulWidget {
  const _SecuritySection();

  @override
  State<_SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends State<_SecuritySection> {
  final _security = sl<SecurityService>();
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _security.canUseBiometrics().then((v) {
      if (mounted) setState(() => _biometricAvailable = v);
    });
  }

  Future<void> _toggleLock(bool value) async {
    if (value) {
      final pin = await _promptNewPin(context);
      if (pin != null) {
        await _security.setPin(pin);
      }
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Désactiver le verrouillage ?'),
          content: const Text('L\'app ne demandera plus de code PIN.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Désactiver')),
          ],
        ),
      );
      if (ok == true) {
        await _security.disableLock();
        if (mounted) context.read<AppLockCubit>().onLockDisabled();
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.lock_outline),
          title: const Text('Verrouiller l\'app par code PIN'),
          subtitle: const Text('Demandé à l\'ouverture de l\'app'),
          value: _security.isLockEnabled,
          onChanged: _toggleLock,
        ),
        if (_security.isLockEnabled)
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: const Text('Changer le code PIN'),
            onTap: () async {
              final pin = await _promptNewPin(context);
              if (pin != null) await _security.setPin(pin);
            },
          ),
        if (_security.isLockEnabled && _biometricAvailable)
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Déverrouillage biométrique'),
            subtitle: const Text('Empreinte ou reconnaissance faciale'),
            value: _security.isBiometricEnabled,
            onChanged: (v) async {
              await _security.setBiometricEnabled(v);
              if (mounted) setState(() {});
            },
          ),
      ],
    );
  }
}

/// Dialogue de définition d'un code PIN à 4 chiffres (avec confirmation).
Future<String?> _promptNewPin(BuildContext context) {
  final pinCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  String? error;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Définir un code PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration:
                  const InputDecoration(labelText: 'Nouveau code (4 chiffres)'),
            ),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Confirme le code'),
            ),
            if (error != null)
              Text(error!,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final pin = pinCtrl.text.trim();
              if (pin.length != 4) {
                setLocal(() => error = 'Le code doit faire 4 chiffres');
                return;
              }
              if (pin != confirmCtrl.text.trim()) {
                setLocal(() => error = 'Les codes ne correspondent pas');
                return;
              }
              Navigator.pop(ctx, pin);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
