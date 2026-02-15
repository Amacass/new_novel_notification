import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_notification/widgets/rating_stars.dart';

void main() {
  Widget buildTestWidget({
    int? rating,
    bool interactive = false,
    ValueChanged<int>? onChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: RatingStars(
          rating: rating,
          interactive: interactive,
          onChanged: onChanged,
        ),
      ),
    );
  }

  group('RatingStars', () {
    testWidgets('shows "未評価" when rating is null and not interactive',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.text('未評価'), findsOneWidget);
    });

    testWidgets('shows 5 star icons when rating is provided', (tester) async {
      await tester.pumpWidget(buildTestWidget(rating: 3));
      expect(find.byIcon(Icons.star), findsNWidgets(3));
      expect(find.byIcon(Icons.star_border), findsNWidgets(2));
    });

    testWidgets('shows all filled stars for rating 5', (tester) async {
      await tester.pumpWidget(buildTestWidget(rating: 5));
      expect(find.byIcon(Icons.star), findsNWidgets(5));
      expect(find.byIcon(Icons.star_border), findsNothing);
    });

    testWidgets('shows all empty stars for rating 0', (tester) async {
      await tester.pumpWidget(buildTestWidget(rating: 0));
      expect(find.byIcon(Icons.star), findsNothing);
      expect(find.byIcon(Icons.star_border), findsNWidgets(5));
    });

    testWidgets('shows 5 stars when interactive with no rating',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(interactive: true));
      expect(find.byIcon(Icons.star_border), findsNWidgets(5));
      expect(find.text('未評価'), findsNothing);
    });

    testWidgets('calls onChanged when interactive star is tapped',
        (tester) async {
      int? tappedValue;
      await tester.pumpWidget(buildTestWidget(
        interactive: true,
        onChanged: (value) => tappedValue = value,
      ));

      // Tap the 3rd star (index 2)
      final stars = find.byType(GestureDetector);
      await tester.tap(stars.at(2));

      expect(tappedValue, 3);
    });
  });
}
