import 'package:flutter/material.dart';

class ErrorInfoWidget extends StatelessWidget {
	final String message;
	final VoidCallback? onRetry;
	const ErrorInfoWidget({super.key, required this.message, this.onRetry});

	@override
	Widget build(BuildContext context) {
		return Column(
			mainAxisSize: MainAxisSize.min,
			children: [
				Text(message),
				if (onRetry != null)
					TextButton(onPressed: onRetry, child: const Text('重试')),
			],
		);
	}
}
