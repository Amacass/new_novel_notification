import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_notification/models/novel.dart';
import 'package:novel_notification/widgets/site_badge.dart';

void main() {
  Widget buildTestWidget(NovelSite site) {
    return MaterialApp(
      home: Scaffold(body: SiteBadge(site: site)),
    );
  }

  group('SiteBadge', () {
    testWidgets('displays N for narou', (tester) async {
      await tester.pumpWidget(buildTestWidget(NovelSite.narou));
      expect(find.text('N'), findsOneWidget);
    });

    testWidgets('displays H for hameln', (tester) async {
      await tester.pumpWidget(buildTestWidget(NovelSite.hameln));
      expect(find.text('H'), findsOneWidget);
    });

    testWidgets('displays A for arcadia', (tester) async {
      await tester.pumpWidget(buildTestWidget(NovelSite.arcadia));
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('uses green color for narou', (tester) async {
      await tester.pumpWidget(buildTestWidget(NovelSite.narou));
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.green);
    });

    testWidgets('uses blue color for hameln', (tester) async {
      await tester.pumpWidget(buildTestWidget(NovelSite.hameln));
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.blue);
    });

    testWidgets('uses orange color for arcadia', (tester) async {
      await tester.pumpWidget(buildTestWidget(NovelSite.arcadia));
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.orange);
    });
  });
}
