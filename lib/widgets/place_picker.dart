import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/kawaii.dart';
import 'kawaii.dart';

/// Free map place picker (OpenStreetMap + Nominatim, no API key).
/// Returns the place's **main title** as a String via Navigator.pop.
class PlacePickerPage extends StatefulWidget {
  final String initialQuery;
  const PlacePickerPage({super.key, this.initialQuery = ''});

  @override
  State<PlacePickerPage> createState() => _PlacePickerPageState();
}

class _PlaceResult {
  final LatLng point;
  final String title;
  final String address;
  const _PlaceResult(this.point, this.title, this.address);
}

String _mainTitle(Map<String, dynamic> j) {
  final name = ((j['name'] ?? '') as String).trim();
  if (name.isNotEmpty) return name;
  final display = ((j['display_name'] ?? '') as String).trim();
  if (display.isEmpty) return 'Pinned place';
  return display.split(',').first.trim();
}

String _addressOf(Map<String, dynamic> j) =>
    ((j['display_name'] ?? '') as String).trim();

class _PlacePickerPageState extends State<PlacePickerPage> {
  static const _defaultCenter = LatLng(-6.2, 106.816666);
  final _mapCtrl = MapController();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  LatLng? _selected;
  String? _title;
  String? _address;
  List<_PlaceResult> _results = [];
  bool _searching = false;
  bool _resolving = false;
  bool _locating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.initialQuery;
    _locateMe(moveIfFound: true, silent: true);
    if (widget.initialQuery.trim().isNotEmpty) {
      _search(widget.initialQuery.trim());
    }
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Map<String, String> get _nominatimHeaders => const {
        'User-Agent': 'ourspace/2.0 (couple-date-planner)',
        'Accept': 'application/json',
      };

  Future<void> _locateMe(
      {bool moveIfFound = true, bool silent = false}) async {
    if (_locating) return;
    setState(() {
      _locating = true;
      if (!silent) _error = null;
    });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (!silent && mounted) {
          setState(() =>
              _error = 'Location permission denied — search or tap the map.');
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      final me = LatLng(pos.latitude, pos.longitude);
      if (moveIfFound) {
        try {
          _mapCtrl.move(me, 15);
        } catch (_) {}
      }
      await _reverse(me, moveCamera: false);
    } catch (_) {
      if (!silent && mounted) {
        setState(() =>
            _error = 'Could not get your location — search or tap the map.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    if (query.isEmpty || _searching) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '5',
      });
      final res = await http
          .get(uri, headers: _nominatimHeaders)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) throw StateError('search ${res.statusCode}');
      final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _results = list.map((j) {
          final lat = double.tryParse('${j['lat']}') ?? 0;
          final lon = double.tryParse('${j['lon']}') ?? 0;
          return _PlaceResult(
            LatLng(lat, lon),
            _mainTitle(j),
            _addressOf(j),
          );
        }).toList();
        if (_results.isEmpty) _error = 'No places found — try another keyword.';
      });
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Search failed (offline?) — tap the map to pin manually.');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _reverse(LatLng p, {bool moveCamera = true}) async {
    if (_resolving) return;
    setState(() {
      _resolving = true;
      _error = null;
    });
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '${p.latitude}',
        'lon': '${p.longitude}',
        'format': 'jsonv2',
      });
      final res = await http
          .get(uri, headers: _nominatimHeaders)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) throw StateError('reverse ${res.statusCode}');
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _selected = p;
        _title = _mainTitle(j);
        _address = _addressOf(j);
        _results = [];
      });
      if (moveCamera) {
        try {
          _mapCtrl.move(p, _mapCtrl.camera.zoom);
        } catch (_) {}
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selected = p;
        _title = 'Pinned place';
        _address =
            '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
        _error = 'No name found for this pin — you can still use it.';
      });
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _chooseResult(_PlaceResult r) {
    setState(() {
      _selected = r.point;
      _title = r.title;
      _address = r.address;
      _results = [];
      _searchFocus.unfocus();
    });
    try {
      _mapCtrl.move(r.point, 16);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final edge = Kawaii.edgeOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick a place',
            style: TextStyle(
                fontFamily: Kawaii.displayFamily,
                fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Use my location',
            onPressed: _locating ? null : () => _locateMe(),
            icon: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Icon(Icons.my_location_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _search,
                      decoration: InputDecoration(
                        hintText: 'Search e.g. Riverside park…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5)),
                              )
                            : (_searchCtrl.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear',
                                    onPressed: () => setState(() {
                                      _searchCtrl.clear();
                                      _results = [];
                                    }),
                                    icon: const Icon(
                                        Icons.close_rounded, size: 18),
                                  )),
                        filled: true,
                        fillColor: Kawaii.cardOf(context),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              Kawaii.radiusInput),
                          borderSide: BorderSide(
                              color: edge,
                              width: Kawaii.paperBorderW),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              Kawaii.radiusInput),
                          borderSide: BorderSide(
                              color: edge,
                              width: Kawaii.paperBorderW),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              Kawaii.radiusInput),
                          borderSide:
                              BorderSide(color: edge, width: 3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  KawaiiIconButton(
                    icon: Icons.search_rounded,
                    label: 'Search places',
                    onTap: () => _search(_searchCtrl.text),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.info_rounded, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_error!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                      Kawaii.radiusCard),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: edge,
                          width: Kawaii.paperBorderW),
                      borderRadius: BorderRadius.circular(
                          Kawaii.radiusCard),
                    ),
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapCtrl,
                          options: MapOptions(
                            initialCenter: _defaultCenter,
                            initialZoom: 12,
                            onTap: (_, p) => _reverse(p),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.ourspace.app',
                            ),
                            if (_selected != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _selected!,
                                    width: 48,
                                    height: 48,
                                    child: const Icon(
                                      Icons.location_on_rounded,
                                      size: 44,
                                      color: Kawaii.bubble,
                                      shadows: [
                                        Shadow(
                                            blurRadius: 4,
                                            color: Colors.black38)
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            RichAttributionWidget(
                              attributions: [
                                TextSourceAttribution(
                                  '© OpenStreetMap',
                                  onTap: () => launchUrl(
                                    Uri.parse(
                                        'https://www.openstreetmap.org/copyright'),
                                    mode: LaunchMode
                                        .externalApplication,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_results.isNotEmpty)
                          Positioned(
                            top: 8,
                            left: 8,
                            right: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Kawaii.cardOf(context),
                                borderRadius:
                                    BorderRadius.circular(14),
                                border: Border.all(
                                    color: edge, width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                      blurRadius: 8,
                                      color: Colors.black26)
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0;
                                      i < _results.length;
                                      i++)
                                    InkWell(
                                      onTap: () => _chooseResult(
                                          _results[i]),
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10),
                                        child: Row(
                                          children: [
                                            const Icon(
                                                Icons.place_outlined,
                                                size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                children: [
                                                  Text(
                                                    _results[i]
                                                        .title,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow
                                                            .ellipsis,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight
                                                                .w800),
                                                  ),
                                                  Text(
                                                    _results[i]
                                                        .address,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow
                                                            .ellipsis,
                                                    style: Theme.of(
                                                            context)
                                                        .textTheme
                                                        .bodySmall,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        if (_resolving)
                          const Positioned(
                            top: 8,
                            right: 8,
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child:
                                        CircularProgressIndicator(
                                            strokeWidth: 2.5)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: KawaiiCard(
                sticker: false,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const KawaiiIcon(
                            icon: Icons.place_rounded,
                            bg: Kawaii.sunny,
                            size: 40,
                            iconSize: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                _title ?? 'Tap the map or search',
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily:
                                      Kawaii.displayFamily,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: Kawaii.ink,
                                ),
                              ),
                              if ((_address ?? '').isNotEmpty)
                                Text(
                                  _address!,
                                  maxLines: 2,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    KawaiiButton(
                      label: 'Use this place',
                      icon: Icons.check_rounded,
                      color: KawaiiBtnColor.sunny,
                      onTap: (_title == null ||
                              _title!.trim().isEmpty)
                          ? null
                          : () => Navigator.of(context)
                              .pop(_title!.trim()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
