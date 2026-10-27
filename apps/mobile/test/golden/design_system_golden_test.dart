import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuz_mobile/core/theme/app_tokens.dart';
import 'package:yuz_mobile/core/widgets/brand_mark.dart';
import 'package:yuz_mobile/core/widgets/status_badge.dart';
import 'package:yuz_mobile/features/catalog/feature_catalog.dart';
import 'package:yuz_mobile/features/home/home_screen.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('design system components', (tester) async {
    tester.view.physicalSize = const Size(400, 300) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedApp(
        const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BrandMark(size: 56),
                SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    StatusBadge(status: FeatureStatus.implemented),
                    SizedBox(width: AppSpacing.xs),
                    StatusBadge(status: FeatureStatus.partial),
                    SizedBox(width: AppSpacing.xs),
                    StatusBadge(status: FeatureStatus.notStarted),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 112,
                  child: Row(
                    children: [
                      Expanded(child: FeatureTile(feature: AppFeature.settings)),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(child: FeatureTile(feature: AppFeature.aiPhotoshoot)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/design_system.png'));
  });
}
