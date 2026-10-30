import 'package:baseX/Core/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const screen = Size(400, 800);
  const data = MediaQueryData(
    size: screen,
    padding: EdgeInsets.only(top: 40),
    devicePixelRatio: 2,
    textScaler: TextScaler.linear(1.5),
  );

  Future<MediaQueryData> pump(
    WidgetTester tester,
    XDisplayLock lock, {
    void Function()? onTap,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late MediaQueryData seen;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: data,
          child: XDisplayLock(
            lockTextScale: lock.lockTextScale,
            lockDisplaySize: lock.lockDisplaySize,
            zoomFactor: lock.zoomFactor,
            child: Builder(
              builder: (context) {
                seen = MediaQuery.of(context);
                return Align(
                  alignment: Alignment.topLeft,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                onTap: onTap,
                    child: const SizedBox(width: 100, height: 100),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    return seen;
  }

  testWidgets('scales size, padding, pixel ratio and locks text', (
    tester,
  ) async {
    final seen = await pump(
      tester,
      const XDisplayLock(zoomFactor: 1.25, child: SizedBox()),
    );
    expect(seen.size, screen * 1.25);
    expect(seen.padding.top, 40 * 1.25);
    expect(seen.devicePixelRatio, 2 / 1.25);
    expect(seen.textScaler, TextScaler.noScaling);
  });

  testWidgets('tap lands on the scaled child', (tester) async {
    var taps = 0;
    await pump(
      tester,
      const XDisplayLock(zoomFactor: 1.25, child: SizedBox()),
      onTap: () => taps++,
    );
    // child is 100x100 laid out at 1.25x zoom, so it occupies 80x80 real pixels.
    await tester.tapAt(const Offset(70, 70));
    expect(taps, 1);
    await tester.tapAt(const Offset(90, 90));
    expect(taps, 1);
  });

  testWidgets('factor 1 with locks off leaves MediaQuery unchanged', (
    tester,
  ) async {
    final seen = await pump(
      tester,
      const XDisplayLock(
        zoomFactor: 1.0,
        lockTextScale: false,
        lockDisplaySize: false,
        child: SizedBox(),
      ),
    );
    expect(seen, data);
  });

  testWidgets('text lock alone only overrides the text scaler', (tester) async {
    final seen = await pump(
      tester,
      const XDisplayLock(
        zoomFactor: 1.25,
        lockDisplaySize: false,
        child: SizedBox(),
      ),
    );
    expect(seen.size, screen);
    expect(seen.textScaler, TextScaler.noScaling);
  });
}
