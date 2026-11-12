import 'package:flutter/material.dart';

import '../data/legal_content.dart';
import '../theme/app_theme.dart';

class LegalScreen extends StatelessWidget {
  final bool privacy;
  const LegalScreen({super.key, this.privacy = true});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.canvas(context),
    appBar: AppBar(title: Text(privacy ? 'Privacy policy' : 'Terms of use')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SelectableText(
            privacy ? LegalContent.privacy : LegalContent.terms,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    ),
  );
}
