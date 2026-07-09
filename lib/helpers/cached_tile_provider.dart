
// lib/helpers/cached_tile_provider.dart
//
// Caches OSM tiles to disk (via cached_network_image) so the map doesn't
// re-hit tile.openstreetmap.org every time. Works on flutter_map v6 / v7.
//
// pubspec.yaml -> dependencies:
//   cached_network_image: ^3.3.1
//
// NOTE: If you're on flutter_map v8+, disk caching is already built in and you
// can skip this file entirely (just use the default TileLayer). This provider
// is here so caching works regardless of your flutter_map version.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

class CachedTileProvider extends TileProvider {
  CachedTileProvider({super.headers});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      headers: headers,
    );
  }
}