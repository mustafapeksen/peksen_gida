import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, required this.fallbackLocation});

  final String fallbackLocation;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Geri',
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(fallbackLocation);
        }
      },
    );
  }
}
