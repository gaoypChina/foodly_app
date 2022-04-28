import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../utils/basic_utils.dart';
import 'skeleton_container.dart';

class FoodlyNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit boxFit;

  const FoodlyNetworkImage(this.imageUrl,
      {this.boxFit = BoxFit.cover, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BasicUtils.isStorageMealImage(imageUrl)
        ? FutureBuilder<String>(
            future: StorageService.getMealImageUrl(imageUrl),
            builder: (context, snapshot) {
              return snapshot.data != null && snapshot.data!.isNotEmpty
                  ? _buildCachedNetworkImage(snapshot.data!)
                  : const SkeletonContainer(
                      width: double.infinity,
                      height: double.infinity,
                    );
            },
          )
        : _buildCachedNetworkImage(imageUrl);
  }

  CachedNetworkImage _buildCachedNetworkImage(String url) {
    url = url.replaceFirst('http://', 'https://');
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => const SkeletonContainer(
        width: double.infinity,
        height: double.infinity,
      ),
      errorWidget: (_, __, dynamic ___) => Image.asset(
        'assets/images/food_fallback.png',
      ),
      // cacheManager: HiveCacheManager(box: ImageCacheService.box)
    );
  }
}
