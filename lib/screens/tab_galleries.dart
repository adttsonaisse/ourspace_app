import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../data/models/content.dart';
import '../data/photo_store.dart';
import '../data/repos.dart';
import '../theme/kawaii.dart';
import '../widgets/kawaii.dart';

/// Photo piles with real R2/memory thumbnails, counts, and deletes.
class GalleriesTab extends StatefulWidget {
  final String spaceId;
  final PilesRepo pilesRepo;
  final PhotoStore photoStore;
  const GalleriesTab(
      {super.key,
      required this.spaceId,
      required this.pilesRepo,
      required this.photoStore});

  @override
  State<GalleriesTab> createState() => _GalleriesTabState();
}

class _PilesData {
  final List<Pile> piles;
  final Map<String, List<PilePhoto>> photos;
  const _PilesData(this.piles, this.photos);
  int get picCount => photos.values.fold(0, (n, l) => n + l.length);
}

class _GalleriesTabState extends State<GalleriesTab> {
  Future<_PilesData> _load(List<Pile> piles) async {
    final photos = <String, List<PilePhoto>>{};
    await Future.wait(piles.map((p) async {
      try {
        photos[p.id] = await widget.pilesRepo.photos(p.id);
      } catch (_) {
        photos[p.id] = [];
      }
    }));
    return _PilesData(piles, photos);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _removePhoto(PilePhoto ph) async {
    try {
      await widget.pilesRepo.removePhoto(ph.id);
      await widget.photoStore.remove(ph.r2Key);
    } catch (e) {
      _snack(e.toString().replaceFirst('StateError: ', ''));
    }
  }

  Future<void> _removePile(Pile p, List<PilePhoto> shots) async {
    try {
      for (final ph in shots) {
        await widget.photoStore.remove(ph.r2Key);
      }
      await widget.pilesRepo.removePile(p.id);
      _snack('“${p.title}” removed');
    } catch (e) {
      _snack(e.toString().replaceFirst('StateError: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, Kawaii.tabBottom(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KawaiiPageHeader(
            title: 'Photo piles',
            subtitle: 'No feed. Just your piles.',
            icon: Icons.photo_library_rounded,
            bg: Kawaii.sky),
          const SizedBox(height: 10),
          StreamBuilder<List<Pile>>(
            stream: widget.pilesRepo.watch(widget.spaceId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return KawaiiAlert(
                  title: 'Could not load piles',
                  message: snap.error
                      .toString()
                      .replaceFirst('StateError: ', ''),
                  kind: KawaiiAlertKind.danger,
                  actionLabel: 'Retry',
                  onAction: () => setState(() {}),
                );
              }
              final all = snap.data ?? [];
              if (all.isEmpty) {
                return KawaiiCard(
                  color: Kawaii.skySubtle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const KawaiiPill(
                          label: 'no piles yet', color: Colors.white),
                      const SizedBox(height: 10),
                      const Text('Start the first pile',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontFamily: Kawaii.displayFamily,
                              fontSize: 18)),
                      const Text(
                          'Name it, add the moments. Tap + below.',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                );
              }
              return FutureBuilder<_PilesData>(
                future: _load(all),
                builder: (context, psnap) {
                  if (!psnap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child:
                          Center(child: CircularProgressIndicator()),
                    );
                  }
                  final data = psnap.data!;
                  final featured = data.piles.first;
                  final rest = data.piles.skip(1).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        KawaiiPill(
                            label:
                                '${data.piles.length} piles • ${data.picCount} pics',
                            color: Kawaii.sunnySubtle),
                      ]),
                      const SizedBox(height: 12),
                      _featuredCard(featured,
                          data.photos[featured.id] ?? []),
                      if (rest.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        GridView.builder(
                          shrinkWrap: true,
                          physics:
                              const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.92),
                          itemCount: rest.length,
                          itemBuilder: (_, i) => _albumCard(
                              rest[i], data.photos[rest[i].id] ?? []),
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _featuredCard(Pile p, List<PilePhoto> shots) {
    return KawaiiCard(
      color: Kawaii.peach,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const KawaiiPill(
                label: 'featured pile',
                color: Kawaii.sunny,
                icon: Icons.auto_awesome_rounded),
            const Spacer(),
            GestureDetector(
              onTap: () => _removePile(p, shots),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: Kawaii.ink, width: 2.5)),
                child: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: Kawaii.ink),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (shots.isEmpty)
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Kawaii.ink, width: 2.5),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.photo_library_rounded,
                  size: 48, color: Kawaii.ink),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: shots.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: 8),
                itemBuilder: (_, i) => _stripThumb(shots[i]),
              ),
            ),
          const SizedBox(height: 10),
          Text(p.title,
              style: const TextStyle(
                  color: Kawaii.ink,
                  fontWeight: FontWeight.w900,
                  fontFamily: Kawaii.displayFamily,
                  fontSize: 18)),
          Text(
              p.location.isEmpty
                  ? '${shots.length} pics • added together'
                  : '${shots.length} pics • ${p.location}',
              style: TextStyle(
                  color: Kawaii.ink.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
      ),
    );
  }

  Widget _stripThumb(PilePhoto ph) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 120,
            height: 140,
            child: _PhotoImage(
                store: widget.photoStore, r2Key: ph.r2Key),
          ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: GestureDetector(
            onTap: () => _removePhoto(ph),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Kawaii.bubble,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Kawaii.ink, width: 2),
                ),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: Kawaii.ink),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _albumCard(Pile p, List<PilePhoto> shots) {
    return GestureDetector(
      onLongPress: () => _removePile(p, shots),
      child: KawaiiCard(
        color: Colors.white,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Kawaii.sky.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: Kawaii.ink, width: 2.5),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: shots.isEmpty
                    ? const Icon(Icons.photo_library_rounded,
                        size: 40, color: Kawaii.ink)
                    : SizedBox.expand(
                        child: _PhotoImage(
                            store: widget.photoStore,
                            r2Key: shots.first.r2Key),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(p.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14)),
            Text('${shots.length} pics',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// One remote/local photo: memory bytes first, else presigned R2 URL.
class _PhotoImage extends StatelessWidget {
  final PhotoStore store;
  final String r2Key;
  const _PhotoImage({required this.store, required this.r2Key});

  Future<_View> _load() async {
    final b = await store.bytes(r2Key);
    if (b != null) return _View.bytes(b);
    return _View.network(await store.url(r2Key));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_View>(
      future: _load(),
      builder: (context, snap) {
        if (snap.hasData) {
          final v = snap.data!;
          if (v.bytes != null) {
            return Image.memory(v.bytes!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _broken());
          }
          return Image.network(v.url!,
              fit: BoxFit.cover,
              loadingBuilder: (_, w, p) =>
                  p == null ? w : _loading(),
              errorBuilder: (_, _, _) => _broken());
        }
        if (snap.hasError) return _broken();
        return _loading();
      },
    );
  }

  Widget _loading() => Container(
      color: Kawaii.skySubtle,
      alignment: Alignment.center,
      child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 3)));

  Widget _broken() => Container(
      color: Kawaii.skySubtle,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_rounded));
}

class _View {
  final Uint8List? bytes;
  final String? url;
  const _View.bytes(this.bytes) : url = null;
  const _View.network(this.url) : bytes = null;
}
