import 'package:falora/widgets/falora_labeled_form_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps text focus while keyboard insets rebuild the form', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    Widget buildForm(double keyboardInset) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            viewInsets: EdgeInsets.only(bottom: keyboardInset),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: FaloraLabeledFormField(
                label: 'Niyet',
                controller: controller,
                maxLines: 3,
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildForm(0));
    await tester.tap(find.byType(TextFormField));
    await tester.pump();

    final focusedField = tester.widget<EditableText>(find.byType(EditableText));
    expect(focusedField.focusNode.hasFocus, isTrue);
    await tester.enterText(
      find.byType(TextFormField),
      'Niyetimi yazmaya devam ediyorum',
    );

    for (final keyboardInset in <double>[336, 310, 352]) {
      await tester.pumpWidget(buildForm(keyboardInset));
      await tester.pump();
    }

    final rebuiltField = tester.widget<EditableText>(find.byType(EditableText));
    expect(rebuiltField.focusNode, same(focusedField.focusNode));
    expect(rebuiltField.focusNode.hasFocus, isTrue);
    expect(controller.text, 'Niyetimi yazmaya devam ediyorum');
  });
}
