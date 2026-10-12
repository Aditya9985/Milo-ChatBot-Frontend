import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_models.dart';

class MiloAvatar extends StatefulWidget {
  const MiloAvatar(
      {super.key, this.size = 160, this.mood = CompanionMood.happy});

  final double size;
  final CompanionMood mood;

  @override
  State<MiloAvatar> createState() => _MiloAvatarState();
}

class _MiloAvatarState extends State<MiloAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);
  Timer? _blinkTimer;
  bool _blink = false;

  @override
  void initState() {
    super.initState();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 3600), (_) async {
      if (!mounted) return;
      setState(() => _blink = true);
      await Future<void>.delayed(const Duration(milliseconds: 130));
      if (mounted) setState(() => _blink = false);
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _idle,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -2.5 * _idle.value),
          child: SizedBox.square(
            dimension: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: widget.size * .94,
                  height: widget.size * .94,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xff8fc8ee).withValues(alpha: .12),
                  ),
                ),
                Container(
                  width: widget.size * .72,
                  height: widget.size * .78,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.size * .3),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xffc3e7ff), Color(0xff82b7e1)],
                    ),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x280b5080),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: widget.size * .24,
                  child: Container(
                    width: widget.size * .58,
                    height: widget.size * .37,
                    decoration: BoxDecoration(
                      color: const Color(0xfff8fcff),
                      borderRadius: BorderRadius.circular(widget.size * .2),
                      border: Border.all(color: const Color(0xffd9eaf5)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _eye,
                            SizedBox(width: widget.size * .09),
                            _eye,
                          ],
                        ),
                        SizedBox(height: widget.size * .035),
                        Container(
                          width: widget.size * .15,
                          height: widget.size *
                              (widget.mood == CompanionMood.talking
                                  ? .065
                                  : .025),
                          decoration: BoxDecoration(
                            color: const Color(0xff53758c),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: widget.size * .105,
                  child: Container(
                    width: widget.size * .06,
                    height: widget.size * .12,
                    decoration: BoxDecoration(
                      color: const Color(0xff5e91b8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Positioned(
                  bottom: widget.size * .12,
                  child: Container(
                    width: widget.size * .2,
                    height: widget.size * .035,
                    decoration: BoxDecoration(
                      color: const Color(0xffe9f6ff),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget get _eye => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: widget.size * .055,
        height: _blink ? widget.size * .012 : widget.size * .09,
        decoration: BoxDecoration(
          color: const Color(0xff35536a),
          borderRadius: BorderRadius.circular(20),
        ),
      );
}
