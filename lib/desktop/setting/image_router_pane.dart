import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../icons/lucide_adapter.dart' as lucide;
import '../../l10n/app_localizations.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/widgets/ios_switch.dart';

class DesktopImageRouterPane extends StatelessWidget {
  const DesktopImageRouterPane({super.key});
  // Keep one small viewport worth of logs visible while preserving full history
  // in SettingsProvider (_maxImageRouterLogs).
  static const int _maxDisplayedLogs = 24;

  String _strategyLabel(BuildContext context, ImageRouterStrategy strategy) {
    final l10n = AppLocalizations.of(context)!;
    switch (strategy) {
      case ImageRouterStrategy.priority:
        return l10n.multiKeyPageStrategyPriority;
      case ImageRouterStrategy.roundRobin:
        return l10n.multiKeyPageStrategyRoundRobin;
      case ImageRouterStrategy.weighted:
        return l10n.multiKeyPageStrategyRandom;
    }
  }

  String _healthLabel(
    BuildContext context,
    ImageRouterChannelHealth health,
    bool enabled,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (!enabled) return l10n.providersPageDisabledStatus;
    switch (health) {
      case ImageRouterChannelHealth.connected:
        return l10n.searchServicesPageConnectedStatus;
      case ImageRouterChannelHealth.failed:
        return l10n.searchServicesPageFailedStatus;
      case ImageRouterChannelHealth.disabled:
        return l10n.providersPageDisabledStatus;
      case ImageRouterChannelHealth.notTested:
        return l10n.searchServicesPageNotTestedStatus;
    }
  }

  Color _healthColor(
    BuildContext context,
    ImageRouterChannelHealth health,
    bool enabled,
  ) {
    final cs = Theme.of(context).colorScheme;
    if (!enabled) return cs.onSurface.withValues(alpha: 0.55);
    switch (health) {
      case ImageRouterChannelHealth.connected:
        return Colors.green;
      case ImageRouterChannelHealth.failed:
        return cs.error;
      case ImageRouterChannelHealth.disabled:
        return cs.onSurface.withValues(alpha: 0.55);
      case ImageRouterChannelHealth.notTested:
        return cs.tertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();

    final channels = settings.imageRouterChannels.entries.toList()
      ..sort((a, b) => b.value.weight.compareTo(a.value.weight));

    return Container(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            children: [
              SizedBox(
                height: 36,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.modelDetailSheetImageMode,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _card(
                context,
                child: Column(
                  children: [
                    _row(
                      context,
                      icon: lucide.Lucide.Settings,
                      label: l10n.providerDetailPageEnabledTitle,
                      trailing: IosSwitch(
                        value: settings.imageRouterEnabled,
                        onChanged: (v) {
                          context.read<SettingsProvider>().setImageRouterEnabled(
                            v,
                          );
                        },
                      ),
                    ),
                    _divider(context),
                    _row(
                      context,
                      icon: lucide.Lucide.Settings2,
                      label: l10n.multiKeyPageStrategyTitle,
                      trailing: _StrategyDropdown(
                        value: settings.imageRouterStrategy,
                        labelBuilder: (s) => _strategyLabel(context, s),
                        onSelected: (s) {
                          context
                              .read<SettingsProvider>()
                              .setImageRouterStrategy(s);
                        },
                      ),
                    ),
                    _divider(context),
                    _row(
                      context,
                      icon: lucide.Lucide.HeartPulse,
                      label: l10n.providerDetailPageTestButton,
                      trailing: FilledButton.tonal(
                        onPressed: () {
                          context
                              .read<SettingsProvider>()
                              .runImageRouterHealthCheck();
                        },
                        child: Text(l10n.providerDetailPageTestButton),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                      child: Text(
                        l10n.settingsPageProviders,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                    if (channels.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        child: Text(
                          l10n.multiKeyPageNoKeys,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      )
                    else
                      for (int i = 0; i < channels.length; i++) ...[
                        _ChannelTile(
                          providerKey: channels[i].key,
                          config: channels[i].value,
                          statusLabel: _healthLabel(
                            context,
                            channels[i].value.health,
                            channels[i].value.enabled,
                          ),
                          statusColor: _healthColor(
                            context,
                            channels[i].value.health,
                            channels[i].value.enabled,
                          ),
                        ),
                        if (i != channels.length - 1) _divider(context),
                      ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.logViewerTitle,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface.withValues(alpha: 0.92),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              context.read<SettingsProvider>().clearImageRouterLogs();
                            },
                            child: Text(l10n.providerDetailPageDeleteButton),
                          ),
                        ],
                      ),
                    ),
                    if (settings.imageRouterLogs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Text(
                          l10n.searchServicesPageNotTestedStatus,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.72),
                          ),
                        ),
                      )
                    else
                      for (final line in settings.imageRouterLogs.take(_maxDisplayedLogs))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
                          child: Text(
                            line,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.72),
                            ),
                          ),
                        ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.10),
        ),
      ),
      child: child,
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.16),
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Widget trailing,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurface.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.92)),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _StrategyDropdown extends StatelessWidget {
  const _StrategyDropdown({
    required this.value,
    required this.labelBuilder,
    required this.onSelected,
  });

  final ImageRouterStrategy value;
  final String Function(ImageRouterStrategy) labelBuilder;
  final ValueChanged<ImageRouterStrategy> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ImageRouterStrategy>(
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final strategy in const <ImageRouterStrategy>[
          ImageRouterStrategy.weighted,
          ImageRouterStrategy.roundRobin,
          ImageRouterStrategy.priority,
        ])
          PopupMenuItem<ImageRouterStrategy>(
            value: strategy,
            child: Text(labelBuilder(strategy)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
        ),
        child: Text(
          labelBuilder(value),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.providerKey,
    required this.config,
    required this.statusLabel,
    required this.statusColor,
  });

  final String providerKey;
  final ImageRouterChannelConfig config;
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = context.read<SettingsProvider>();
    final cfg = settings.getProviderConfig(providerKey, defaultName: providerKey);
    final displayName = cfg.name.isNotEmpty ? cfg.name : providerKey;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.95),
                  ),
                ),
              ),
              Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              IosSwitch(
                value: config.enabled,
                onChanged: (v) {
                  context
                      .read<SettingsProvider>()
                      .setImageRouterChannelEnabled(providerKey, v);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Slider(
                  min: 1,
                  max: 100,
                  divisions: 99,
                  value: config.weight.toDouble(),
                  onChanged: config.enabled
                      ? (v) {
                          context
                              .read<SettingsProvider>()
                              .setImageRouterChannelWeight(
                                providerKey,
                                v.round(),
                              );
                        }
                      : null,
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${config.weight}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
