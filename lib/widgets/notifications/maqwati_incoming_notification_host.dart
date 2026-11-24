import 'dart:async';
import 'package:flutter/material.dart';
import 'maqwati_notifications_sheet.dart';
import 'maqwati_peeking_mascot.dart';

/// Overlay for notifications received while the Flutter app is foregrounded.
/// Provide authenticated server events through [event]. Does not register for
/// push, fabricate arrival, or draw on top of other Android applications.
class MaqwatiIncomingNotificationHost extends StatefulWidget {
  const MaqwatiIncomingNotificationHost({
    super.key,
    required this.child,
    this.event,
    this.onOpen,
  });
  final Widget child;
  final MaqwatiNotificationEvent? event;
  final ValueChanged<MaqwatiNotificationEvent>? onOpen;

  @override
  State<MaqwatiIncomingNotificationHost> createState() =>
      _MaqwatiIncomingNotificationHostState();
}

class _MaqwatiIncomingNotificationHostState
    extends State<MaqwatiIncomingNotificationHost> {
  MaqwatiNotificationEvent? _displayed;
  Timer? _hideTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    // A preloaded list of old notifications must not trigger an arrival pop.
  }

  @override
  void didUpdateWidget(covariant MaqwatiIncomingNotificationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.event;
    if (incoming != null && incoming.id != oldWidget.event?.id) {
      _hideTimer?.cancel();
      _displayed = incoming;
      _visible = true;
      _hideTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Stack(
      children: [
        widget.child,
        if (_displayed != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 6,
            left: 12,
            right: 12,
            child: SafeArea(
              top: false,
              child: AnimatedSlide(
                key: const Key('maqwati_heads_up'),
                offset: _visible ? Offset.zero : const Offset(0, -1.8),
                duration: reduceMotion ? Duration.zero
                    : const Duration(milliseconds: 540),
                curve: Curves.easeOutBack,
                child: Semantics(
                  liveRegion: true,
                  child: Material(
                    elevation: 10,
                    borderRadius: BorderRadius.circular(22),
                    child: MaqwatiArrivalCard(
                      key: ValueKey(_displayed!.id),
                      title: _displayed!.title,
                      message: _displayed!.message,
                      category: _displayed!.category,
                      isNew: !reduceMotion,
                      onTap: widget.onOpen == null ? null : () {
                        widget.onOpen!(_displayed!);
                        setState(() => _visible = false);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
