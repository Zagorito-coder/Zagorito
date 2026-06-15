// ============================================================
//  community_page.dart — Page Communauté
// ============================================================

import 'package:flutter/material.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/theme_controller.dart';
import 'package:spots_app/l10n/app_localizations.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final tc = ThemeColors.of(context);
        return Scaffold(
          backgroundColor: tc.background,
          body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: tc.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        context.tr('drawer.title'),
                        style: TextStyle(
                          color: tc.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        context.tr('community.title'),
                      style: AppTextStyles.headlineLarge(context).copyWith(fontSize: 32),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  },
);
  }
}
