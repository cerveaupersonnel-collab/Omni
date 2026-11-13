import 'package:flutter/material.dart';

import '../../features/home/domain/home_card_id.dart';

class FeatureScaffold extends StatelessWidget {
  const FeatureScaffold({
    super.key,
    required this.card,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottom,
  });

  final HomeCardId card;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Hero(tag: 'card-icon-${card.name}', child: Icon(card.icon, color: theme.colorScheme.primary)),
            const SizedBox(width: 10),
            Flexible(child: Text(card.title, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: actions,
        bottom: bottom,
      ),
      floatingActionButton: floatingActionButton,
      body: SafeArea(child: body),
    );
  }
}
