import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/notifications/notification_scheduler.dart';
import '../../core/notifications/notification_service.dart';
import '../../data/settings_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _settings = sl<SettingsService>();
  final _service = sl<NotificationService>();
  final _scheduler = sl<NotificationScheduler>();

  late bool _dailyEnabled;
  late TimeOfDay _dailyTime;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _dailyEnabled = _settings.dailyReminderEnabled;
    _dailyTime = TimeOfDay(
      hour: _settings.dailyReminderHour,
      minute: _settings.dailyReminderMinute,
    );
    _refreshPending();
  }

  Future<void> _refreshPending() async {
    final pending = await _service.pending();
    if (mounted) setState(() => _pendingCount = pending.length);
  }

  Future<void> _toggleDaily(bool value) async {
    if (value) await _service.requestPermission();
    await _settings.setDailyReminderEnabled(value);
    setState(() => _dailyEnabled = value);
    await _scheduler.syncAll();
    await _refreshPending();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _dailyTime);
    if (picked != null) {
      await _settings.setDailyReminderTime(picked.hour, picked.minute);
      setState(() => _dailyTime = picked);
      await _scheduler.syncAll();
      await _refreshPending();
    }
  }

  Future<void> _sendTest() async {
    final granted = await _service.requestPermission();
    await _service.showNow(
      id: 999999,
      title: 'FinTrack — test',
      body: 'Les notifications fonctionnent bien 🎉',
    );
    if (mounted && !granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Notifications désactivées dans les réglages système Android.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Rappel de saisie quotidien'),
            subtitle: const Text(
                'Un rappel chaque jour pour noter tes dépenses et revenus'),
            value: _dailyEnabled,
            onChanged: _toggleDaily,
          ),
          ListTile(
            enabled: _dailyEnabled,
            leading: const Icon(Icons.schedule),
            title: const Text('Heure du rappel'),
            trailing: Text(_dailyTime.format(context)),
            onTap: _dailyEnabled ? _pickTime : null,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Rappels automatiques'),
          ),
          const ListTile(
            leading: Icon(Icons.groups_outlined),
            dense: true,
            title: Text('Jours de cotisation et de perception'),
            subtitle: Text('Programmés depuis tes tontines'),
          ),
          const ListTile(
            leading: Icon(Icons.receipt_long_outlined),
            dense: true,
            title: Text('Échéances de remboursement'),
            subtitle: Text('Programmées depuis tes dettes'),
          ),
          const ListTile(
            leading: Icon(Icons.pie_chart_outline),
            dense: true,
            title: Text('Dépassement de budget'),
            subtitle: Text('Alerte immédiate quand une enveloppe est dépassée'),
          ),
          const ListTile(
            leading: Icon(Icons.flag_outlined),
            dense: true,
            title: Text('Objectifs d\'épargne'),
            subtitle: Text('Rappel mensuel si tu as des objectifs en cours'),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '$_pendingCount rappel(s) actuellement programmé(s).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.tonalIcon(
              onPressed: _sendTest,
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Envoyer une notification test'),
            ),
          ),
        ],
      ),
    );
  }
}
