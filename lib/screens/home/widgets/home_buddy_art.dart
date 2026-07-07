import 'package:flutter/material.dart';

import '../../../models/activity_models.dart';

class HomeBuddyArt extends StatelessWidget {
  final LearningStage stage;
  final double maxHeight;

  const HomeBuddyArt({super.key, required this.stage, this.maxHeight = 360});

  @override
  Widget build(BuildContext context) {
    final asset = switch (stage) {
      LearningStage.startActivity => 'assets/home-screen/home_page_img1.png',
      LearningStage.sendProject => 'assets/home-screen/home_page_img2.png',
      LearningStage.quizPending => 'assets/home-screen/home_page_img2.png',
      LearningStage.completed => 'assets/home-screen/sussess_celebrate.png',
    };

    return Image.asset(
      asset,
      height: maxHeight,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => SizedBox(
        height: maxHeight,
        child: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Color(0xFFB9BBC8),
          ),
        ),
      ),
    );
  }
}
