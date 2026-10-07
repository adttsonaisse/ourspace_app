import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../data/backend_errors.dart';
import '../data/models/content.dart';
import '../data/photo_store.dart';
import '../data/repos.dart';
import '../data/storage_maintenance.dart';
import '../theme/kawaii.dart';
import '../widgets/kawaii.dart';
import '../widgets/kawaii_deco.dart';

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
  final Map<String, List<PilePhoto>> _photoCache = {};

  Future<_PilesData> _syncPhotos(List<Pile> piles) async {
    final ids = {for (final p in piles) p.id};
    _photoCache.removeWhere((k, _) => !ids.contains(k));
    for (final p in piles) {
      if (!_photoCache.containsKey(p.id)) {
        try {
          _photoCache[p.id] = await widget.pilesRepo.photos(p.id);
        } catch (_) {
          _photoCache[p.id] = [];
        }
      }
    }
    return _PilesData(piles, Map.of(_photoCache));
  }

  void _snack(String msg, {KawaiiAlertKind kind = KawaiiAlertKind.info}) {
    if (!mounted) return;
    showKawaiiToast(context, msg, kind: kind);
  }

  Future<void> _removePhoto(PilePhoto ph) async {
    final ok = await confirmKawaii(
      context,
      title: 'Delete this photo?',
      message: 'It will be removed from the pile for both of you.',
      confirmLabel: 'Delete photo',
    );
    if (!ok) return;
    try {
      await widget.pilesRepo.removePhoto(ph.id);
      await widget.photoStore.remove(ph.r2Key);
      await photoCache.removeFile(ph.r2Key);
    } catch (e) {
      _snack(userMessage(e), kind: KawaiiAlertKind.danger);
      return;
    }
    if (!mounted) return;
    setState(() => _photoCache.remove(ph.pileId));
  }

  Future<void> _removePile(Pile p, List<PilePhoto> shots) async {
    final ok = await confirmKawaii(
      context,
      title: 'Delete “${p.title}”?',
      message: 'This pile and its ${shots.length} photo(s) will be deleted.',
      confirmLabel: 'Delete pile',
    );
    if (!ok) return;
    try {
      for (final ph in shots) {
        await widget.photoStore.remove(ph.r2Key);
        await photoCache.removeFile(ph.r2Key);
      }
      await widget.pilesRepo.removePile(p.id);
      if (!mounted) return;
      setState(() => _photoCache.remove(p.id));
      _snack('“${p.title}” removed', kind: KawaiiAlertKind.success);
    } catch (e) {
      _snack(userMessage(e), kind: KawaiiAlertKind.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, Kawaii.tabBottom(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  message: userMessage(snap.error!),
                  kind: KawaiiAlertKind.danger,
                  actionLabel: 'Retry',
                  onAction: () => setState(() {}),
                );
              }
              final all = snap.data ?? [];
              if (all.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KawaiiTabHeaderRow(
                      pill: 'sticker pile',
                      pillIcon: Icons.photo_library_rounded,
                      pillColor: Kawaii.sunnySubtle,
                    ),
                    const SizedBox(height: 12),
                    const KawaiiEmpty(
                      title: 'Start the first pile',
                      message: 'Name it, add the moments. Tap + below.',
                      stickerIcon: Icons.photo_library_rounded,
                      stickerBg: Kawaii.sky,
                    ),
                  ],
                );
              }
              return FutureBuilder<_PilesData>(
                future: _syncPhotos(all),
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
                      const KawaiiTabHeaderRow(
                        pill: 'sticker pile',
                        pillIcon: Icons.photo_library_rounded,
                        pillColor: Kawaii.sunnySubtle,
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        KawaiiPill(
                            label:
                                '${data.piles.length} piles • ${data.picCount} pics',
                            color: Kawaii.sunnySubtle),
                        const Spacer(),
                        const KawaiiSparkle(size: 18),
                      ]),
                      const SizedBox(height: 4),
                      const KawaiiDotDivider(count: 10),
                      const SizedBox(height: 12),
                      _featuredCard(featured,
                          data.photos[featured.id] ?? []),
                      if (rest.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const KawaiiSectionTitle('All piles',
                            trailing: KawaiiDoodles()),
                        GridView.builder(
                          shrinkWrap: true,
                          physics:
                              const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.72),
                          itemCount: rest.length,
                          itemBuilder: (_, i) => _albumCard(
                              rest[i], data.photos[rest[i].id] ?? [], i),
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
      padding: EdgeInsets.zero,
      child: KawaiiPolkaBg(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const KawaiiPill(
                    label: 'featured pile',
                    color: Kawaii.sunny,
                    icon: Icons.auto_awesome_rounded),
                const Spacer(),
                const KawaiiSparkle(size: 20, color: Colors.white),
                KawaiiIconButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete pile',
                  fill: Colors.white,
                  size: 40,
                  onTap: () => _removePile(p, shots),
                ),
              ]),
              const SizedBox(height: 8),
              const Row(
                children: [
                  KawaiiDoodles(),
                  Spacer(),
                ],
              ),
              const SizedBox(height: 12),
          if (shots.isEmpty)
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Kawaii.ink, width: Kawaii.paperBorderW),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.photo_library_rounded,
                    size: 44, color: Kawaii.ink),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Kawaii.ink, width: Kawaii.paperBorderW),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _PhotoImage(
                        store: widget.photoStore,
                        r2Key: shots.first.r2Key),
                  ),
                ),
                if (shots.length > 1) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: shots.length - 1,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: 8),
                      itemBuilder: (_, i) =>
                          _stripThumb(shots[i + 1], w: 68, h: 72),
                    ),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 12),
          Text(p.title,
              style: const TextStyle(
                  fontFamily: Kawaii.displayFamily,
                  color: Kawaii.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 18)),
          Text(
              p.location.isEmpty
                  ? '${shots.length} pics • added together'
                  : '${shots.length} pics • ${p.location}',
              style: TextStyle(
                  fontFamily: Kawaii.displayFamily,
                  color: Kawaii.ink.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stripThumb(PilePhoto ph, {double w = 120, double h = 140}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: w,
            height: h,
            child: _PhotoImage(
                store: widget.photoStore, r2Key: ph.r2Key),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: () => _removePhoto(ph),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Kawaii.bubble,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Kawaii.ink, width: 1.5),
                ),
                child: const Icon(Icons.close_rounded,
                    size: 12, color: Kawaii.ink),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _albumCard(Pile p, List<PilePhoto> shots, int index) {
    return GestureDetector(
      onLongPress: () => _removePile(p, shots),
      child: KawaiiCard(
        sticker: false,
        color: Kawaii.cardOf(context),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Transform.rotate(
                  angle: kawaiiDecoTilt(index),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: kawaiiDecoPick(index).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Kawaii.edgeOf(context),
                            width: Kawaii.paperBorderW),
                      ),
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.center,
                      child: shots.isEmpty
                          ? Icon(Icons.photo_library_rounded,
                              size: 36, color: Kawaii.textOf(context))
                          : SizedBox.expand(
                              child: _PhotoImage(
                                  store: widget.photoStore,
                                  r2Key: shots.first.r2Key),
                            ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -8,
                  left: -4,
                  child: KawaiiPill(
                    label: '${shots.length}',
                    color: kawaiiDecoPick(index),
                    icon: Icons.photo_library_rounded,
                  ),
                ),
                if (index == 0)
                  const Positioned(
                    top: -10,
                    right: -6,
                    child: KawaiiSparkle(size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(p.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: Kawaii.displayFamily,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
            Text('${shots.length} pics',
                style: TextStyle(
                    fontFamily: Kawaii.displayFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Kawaii.mutedOf(context))),
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
          // Bounded disk cache keyed by r2Key (not the rotating presigned
          // URL) so repeat views hit cache instead of re-downloading
          // full-res originals until storage balloons.
          return CachedNetworkImage(
            imageUrl: v.url!,
            cacheKey: r2Key,
            cacheManager: photoCache,
            fit: BoxFit.cover,
            placeholder: (_, _) => _loading(),
            errorWidget: (_, _, _) => _broken(),
          );
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
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5)));

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
