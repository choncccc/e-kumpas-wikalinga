import 'dart:io';

import 'package:ekumpas_wikalinga/features/procedure/bp_procedure_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every BP step has its poster frame', () {
    // The .mp4s are gitignored (rebuilt by tool/build_procedure.py), the
    // posters are committed.
    for (final s in bpProcedureSteps) {
      expect(File(s.poster).existsSync(), isTrue, reason: s.poster);
    }
    expect(bpProcedureSteps.map((s) => s.number), [1, 2, 3, 4, 5, 6, 7, 8, 9]);
  });

  testWidgets('steps through the BP procedure', (tester) async {
    // Phone-sized, so the step buttons are on screen.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: BpProcedureScreen()));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('STEP 1 OF 9'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('STEP 2 OF 9'), findsOneWidget);

    // Jump straight to the last step from the list.
    await tester.scrollUntilVisible(find.text('Remove the cuff'), 200);
    await tester.tap(find.text('Remove the cuff'));
    // Let the list scroll back up to the player.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('STEP 9 OF 9'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });
}
