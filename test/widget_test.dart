import 'package:entre_nos/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Renderiza la pantalla inicial de ENTRE NOS', (tester) async {
    await tester.pumpWidget(const EntreNosApp());
    await tester.pump();

    expect(find.text('ENTRE NOS'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}