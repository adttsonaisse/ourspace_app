// Slim offline banner. Stream is injectable so tests feed it directly;
// prod defaults to connectivity_plus.
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../theme/kawaii.dart';

class OfflineBanner extends StatelessWidget {
  final Stream<List<ConnectivityResult>>? stream;
  const OfflineBanner({super.key, this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: stream ?? Connectivity().onConnectivityChanged,
      initialData: const [ConnectivityResult.wifi],
      builder: (context, snap) {
        final data = snap.data ?? const [ConnectivityResult.wifi];
        final offline =
            data.isEmpty || data.contains(ConnectivityResult.none);
        if (!offline) return const SizedBox.shrink();
        return Semantics(
          liveRegion: true,
          label: 'No connection',
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Kawaii.sunny,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Kawaii.edgeOf(context), width: 2.5),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded,
                    size: 18, color: Kawaii.ink),
                SizedBox(width: 8),
                Text('No connection — changes won’t sync',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Kawaii.ink)),
              ],
            ),
          ),
        );
      },
    );
  }
}
