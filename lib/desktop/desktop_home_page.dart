import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'desktop_nav_rail.dart';
import 'desktop_chat_page.dart';
import 'window_title_bar.dart';
import 'desktop_settings_page.dart';
import 'desktop_translate_page.dart';
import '../features/settings/pages/storage_space_page.dart';
import '../l10n/app_localizations.dart';
import '../core/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:async';
import 'hotkeys/hotkey_event_bus.dart';
import 'hotkeys/chat_action_bus.dart';

/// Desktop home screen: left compact rail + main content.
/// Phase 1 focuses on structure and platform-appropriate interactions/hover.
class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({
    super.key,
    this.initialTabIndex,
    this.initialProviderKey,
  });

  final int? initialTabIndex; // 0=Chat,1=Translate,2=Storage,3=Settings
  final String? initialProviderKey;

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

class _DesktopHomePageState extends State<DesktopHomePage> {
  static const int _chatTabIndex = 0;
  static const int _translateTabIndex = 1;
  static const int _storageTabIndex = 2;
  static const int _settingsTabIndex = 3;

  int _tabIndex = 0; // 0=Chat, 1=Translate, 2=Storage, 3=Settings
  bool _storageVisited = false;
  bool _globalSearchActive = false;
  StreamSubscription<HotkeyAction>? _hotkeySub;
  StreamSubscription<ChatAction>? _chatActionSub;

  @override
  void initState() {
    super.initState();
    if (widget.initialTabIndex != null) {
      _tabIndex = widget.initialTabIndex!.clamp(0, 3);
    }
    _storageVisited = _tabIndex == _storageTabIndex;
    // 初始进入时如果就是聊天页，则聚焦聊天输入框
    if (_tabIndex == _chatTabIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ChatActionBus.instance.fire(ChatAction.focusInput);
      });
    }
    // Listen to global hotkey actions affecting the main tabs/window
    _hotkeySub = HotkeyEventBus.instance.stream.listen((action) async {
      switch (action) {
        case HotkeyAction.openSettings:
          if (mounted) {
            setState(() {
              _tabIndex = _settingsTabIndex;
              _globalSearchActive = false;
            });
            ChatActionBus.instance.fire(ChatAction.exitGlobalSearch);
          }
          break;
        case HotkeyAction.closeWindow:
          try {
            await windowManager.close();
          } catch (_) {}
          break;
        case HotkeyAction.toggleAppVisibility:
          try {
            final visible = await windowManager.isVisible();
            final minimized = await windowManager.isMinimized();
            final focused = await windowManager.isFocused();

            // 优先级：
            // 1. 如果窗口不可见或最小化，则显示并聚焦
            // 2. 如果窗口可见但未聚焦，则聚焦
            // 3. 如果窗口可见且已聚焦，则隐藏
            if (!visible || minimized) {
              await windowManager.show();
              await windowManager.focus();
              // 如果当前是聊天页，显示窗口时聚焦输入框
              if (_tabIndex == _chatTabIndex) {
                ChatActionBus.instance.fire(ChatAction.focusInput);
              }
            } else if (!focused) {
              await windowManager.focus();
              // 如果当前是聊天页，聚焦窗口时也聚焦输入框
              if (_tabIndex == _chatTabIndex) {
                ChatActionBus.instance.fire(ChatAction.focusInput);
              }
            } else {
              await windowManager.hide();
            }
          } catch (_) {}
          break;
        case HotkeyAction.newTopic:
          if (_tabIndex == _chatTabIndex) {
            ChatActionBus.instance.fire(ChatAction.newTopic);
          }
          break;
        case HotkeyAction.switchModel:
          if (_tabIndex == _chatTabIndex) {
            ChatActionBus.instance.fire(ChatAction.switchModel);
          }
          break;
        case HotkeyAction.toggleLeftPanelAssistants:
          if (_tabIndex == _chatTabIndex) {
            ChatActionBus.instance.fire(ChatAction.toggleLeftPanelAssistants);
          }
          break;
        case HotkeyAction.toggleLeftPanelTopics:
          if (_tabIndex == _chatTabIndex) {
            ChatActionBus.instance.fire(ChatAction.toggleLeftPanelTopics);
          }
          break;
      }
    });

    _chatActionSub = ChatActionBus.instance.stream.listen((action) {
      if (!mounted) return;
      switch (action) {
        case ChatAction.enterGlobalSearch:
          setState(() {
            _tabIndex = 0;
            _globalSearchActive = true;
          });
          break;
        case ChatAction.exitGlobalSearch:
          setState(() {
            _globalSearchActive = false;
          });
          break;
        default:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Ensure a reasonable min size to avoid overflow on aggressive resize.
    const minWidth = 960.0;
    const minHeight = 640.0;

    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    final pureImageMode = context.watch<SettingsProvider>().pureImageMode;
    final activeTabIndex =
        (pureImageMode &&
            (_tabIndex == _translateTabIndex ||
                _tabIndex == _storageTabIndex))
        ? _chatTabIndex
        : _tabIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final needsWidthPad = w < minWidth;
        final needsHeightPad = h < minHeight;

        Widget body = Row(
          children: [
            DesktopNavRail(
              activeIndex: activeTabIndex,
              globalSearchActive: _globalSearchActive,
              pureImageMode: pureImageMode,
              onTapChat: () {
                setState(() {
                  _tabIndex = _chatTabIndex;
                  _globalSearchActive = false;
                });
                ChatActionBus.instance.fire(ChatAction.exitGlobalSearch);
                // 切换到聊天页时聚焦输入框
                ChatActionBus.instance.fire(ChatAction.focusInput);
              },
              onTapGlobalSearch: () {
                setState(() {
                  _tabIndex = _chatTabIndex;
                  _globalSearchActive = true;
                });
                ChatActionBus.instance.fire(ChatAction.enterGlobalSearch);
              },
              onTapTranslate: () {
                setState(() {
                  _tabIndex = _translateTabIndex;
                  _globalSearchActive = false;
                });
                ChatActionBus.instance.fire(ChatAction.exitGlobalSearch);
              },
              onTapStorage: () => setState(() {
                _tabIndex = _storageTabIndex;
                _globalSearchActive = false;
                _storageVisited = true;
                ChatActionBus.instance.fire(ChatAction.exitGlobalSearch);
              }),
              onTapSettings: () {
                setState(() {
                  _tabIndex = _settingsTabIndex;
                  _globalSearchActive = false;
                });
                ChatActionBus.instance.fire(ChatAction.exitGlobalSearch);
              },
            ),
            Expanded(
              // Keep all pages alive so ongoing chat streams are not canceled
              // when switching tabs (Chat/Translate/Settings) on desktop.
              child: IndexedStack(
                index: activeTabIndex,
                children: [
                  // Chat page remains mounted
                  const DesktopChatPage(),
                  // Translate page remains mounted
                  const DesktopTranslatePage(key: ValueKey('translate_page')),
                  _storageVisited
                      ? const StorageSpacePage(
                          key: ValueKey('storage_space_page'),
                          embedded: true,
                        )
                      : const SizedBox.shrink(),
                  DesktopSettingsPage(
                    key: const ValueKey('settings_page'),
                    initialProviderKey: widget.initialProviderKey,
                  ),
                ],
              ),
            ),
          ],
        );

        // Wrap with Windows custom title bar when on Windows platform.
        final content = isWindows
            ? Column(
                children: [
                  WindowTitleBar(
                    leftChildren: [
                      SizedBox(width: DesktopNavRail.width / 2 - 8 - 6 - 12),
                      const _TitleBarLeading(),
                    ],
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        body,
                        // Inject the lazily-built settings page into the IndexedStack when needed
                        // to pass initialProviderKey without dropping chat state.
                        if (_tabIndex == _settingsTabIndex)
                          const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ],
              )
            : body;

        // if (!needsWidthPad && !needsHeightPad) return content;

        // Center a constrained area if window is smaller than our minimum
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: minWidth,
              minHeight: minHeight,
            ),
            child: SizedBox(
              width: needsWidthPad ? minWidth : w,
              height: needsHeightPad ? minHeight : h,
              child: content,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    try {
      _hotkeySub?.cancel();
    } catch (_) {}
    try {
      _chatActionSub?.cancel();
    } catch (_) {}
    super.dispose();
  }
}

// No extra router/shim; we import DesktopSettingsPage directly above.

class _TitleBarLeading extends StatelessWidget {
  const _TitleBarLeading();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // App icon
        Image.asset(
          'assets/icons/kelivo.png',
          width: 16,
          height: 16,
          filterQuality: FilterQuality.medium,
        ),
        const SizedBox(width: 8),
        // App name
        Text(
          l10n.aboutPageAppName,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withValues(alpha: 0.8),
            // Avoid accidental underline when not under a Material ancestor in edge cases
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
