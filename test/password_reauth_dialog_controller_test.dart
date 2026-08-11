import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Same lifecycle as profile_screen._ReauthPasswordDialog.
class _TestReauthDialog extends StatefulWidget {
  const _TestReauthDialog();

  @override
  State<_TestReauthDialog> createState() => _TestReauthDialogState();
}

class _TestReauthDialogState extends State<_TestReauthDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kimlik Doğrulama'),
      content: TextFormField(controller: _controller),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Devam Et'),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('Kimlik Doğrulama dialog controller survives open/submit/close',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showDialog<String>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const _TestReauthDialog(),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Kimlik Doğrulama'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextFormField), 'secret');
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();
    expect(find.text('Kimlik Doğrulama'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
