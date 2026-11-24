import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_finder_app/presentation/home/widgets/home_banner_carousel.dart';

void main() {
  testWidgets('HomeBannerCarousel renders on desktop with arrows beside banner and dots below', (tester) async {
    bool tappedExplore = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 1200,
              height: 450,
              child: HomeBannerCarousel(
                onExploreRooms: () => tappedExplore = true,
              ),
            ),
          ),
        ),
      ),
    );

    // Verify PageView exists
    expect(find.byType(PageView), findsOneWidget);

    // Verify AspectRatio matches 1024 / 341
    final aspectRatioFinder = find.byWidgetPredicate(
      (widget) => widget is AspectRatio && (widget.aspectRatio - 1024.0 / 341.0).abs() < 0.01,
    );
    expect(aspectRatioFinder, findsOneWidget);

    // Verify 5 indicator dots exist
    expect(find.byType(AnimatedContainer), findsNWidgets(5));

    // Verify desktop navigation arrow buttons exist when width >= 768
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

    // Tap right arrow
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();

    // Tap dot indicator to switch page
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    expect(tappedExplore, isFalse);
  });

  testWidgets('HomeBannerCarousel renders on mobile without desktop arrows and maintains aspect ratio', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              height: 200,
              child: HomeBannerCarousel(),
            ),
          ),
        ),
      ),
    );

    // Verify PageView exists
    expect(find.byType(PageView), findsOneWidget);

    // Verify arrows are NOT rendered on mobile
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

    // Verify 5 indicator dots are rendered
    expect(find.byType(AnimatedContainer), findsNWidgets(5));
  });
}
