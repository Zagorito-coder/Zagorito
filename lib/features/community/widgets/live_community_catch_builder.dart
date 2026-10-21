import 'package:flutter/widgets.dart';
import 'package:spots_app/features/community/models/community_catch.dart';

/// Keeps an open detail sheet on the same live data as the community feed.
/// The initial item is only used while waiting for the first stream event.
class LiveCommunityCatchBuilder extends StatelessWidget {
  const LiveCommunityCatchBuilder({
    super.key,
    required this.initialItem,
    required this.stream,
    required this.builder,
  });

  final CommunityCatch initialItem;
  final Stream<List<CommunityCatch>> stream;
  final Widget Function(BuildContext, CommunityCatch?) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CommunityCatch>>(
      stream: stream,
      initialData: [initialItem],
      builder: (context, snapshot) {
        if (snapshot.hasError) return builder(context, null);
        for (final item in snapshot.data ?? const <CommunityCatch>[]) {
          if (item.id == initialItem.id) return builder(context, item);
        }
        return builder(context, null);
      },
    );
  }
}
