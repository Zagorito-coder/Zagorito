import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthenticatedSpotPhoto extends StatefulWidget {
  const AuthenticatedSpotPhoto({
    super.key,
    required this.url,
    required this.placeholder,
    this.fit = BoxFit.cover,
  });

  final String url;
  final BoxFit fit;
  final Widget placeholder;

  @override
  State<AuthenticatedSpotPhoto> createState() => _AuthenticatedSpotPhotoState();
}

class _AuthenticatedSpotPhotoState extends State<AuthenticatedSpotPhoto> {
  late Future<String?> _token;

  @override
  void initState() {
    super.initState();
    _token = FirebaseAuth.instance.currentUser?.getIdToken() ??
        Future<String?>.value();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedSpotPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _token = FirebaseAuth.instance.currentUser?.getIdToken() ??
          Future<String?>.value();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _token,
      builder: (context, snapshot) {
        final token = snapshot.data;
        if (token == null || token.isEmpty) return widget.placeholder;
        return Image.network(
          widget.url,
          fit: widget.fit,
          headers: {'Authorization': 'Bearer $token'},
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (frame != null || wasSynchronouslyLoaded) return child;
            return Stack(
              fit: StackFit.expand,
              children: [widget.placeholder, child],
            );
          },
          errorBuilder: (_, __, ___) => widget.placeholder,
        );
      },
    );
  }
}
