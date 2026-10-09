import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/roommate_post_model.dart';
import '../../auth/providers/auth_provider.dart';

enum HostDashboardSort {
  newest,
  mostInterested,
  priceAscending,
  priceDescending,
}

class HostDashboardFilterOptions {
  const HostDashboardFilterOptions({
    this.locations = const [],
    this.requirements = const [],
  });

  final List<String> locations;
  final List<String> requirements;
}

final hostAmenitiesProvider =
    StreamProvider.autoDispose<List<Map<String, String>>>((ref) {
      if (Firebase.apps.isEmpty) return Stream.value(const []);
      return FirebaseFirestore.instance.collection('amenities').snapshots().map(
        (snapshot) {
          return snapshot.docs
              .map((doc) {
                final data = doc.data();
                final name =
                    (data['name'] ??
                            data['ten'] ??
                            data['label'] ??
                            data['tenTienIch'] ??
                            '')
                        .toString()
                        .trim();
                return {'id': doc.id, 'name': name};
              })
              .where((item) => item['name']!.isNotEmpty)
              .toList();
        },
      );
    });

class HostDashboardFilter {
  const HostDashboardFilter({
    this.locations = const [],
    this.requirements = const [],
    this.minPrice,
    this.maxPrice,
    this.sort = HostDashboardSort.newest,
    this.searchQuery = '',
  });

  final List<String> locations;
  final List<String> requirements;
  final double? minPrice;
  final double? maxPrice;
  final HostDashboardSort sort;
  final String searchQuery;

  HostDashboardFilter copyWith({
    List<String>? locations,
    List<String>? requirements,
    double? minPrice,
    double? maxPrice,
    HostDashboardSort? sort,
    String? searchQuery,
    bool clearPrice = false,
  }) {
    return HostDashboardFilter(
      locations: locations ?? this.locations,
      requirements: requirements ?? this.requirements,
      minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
      sort: sort ?? this.sort,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HostDashboardFilter &&
          listEquals(locations, other.locations) &&
          listEquals(requirements, other.requirements) &&
          minPrice == other.minPrice &&
          maxPrice == other.maxPrice &&
          sort == other.sort &&
          searchQuery == other.searchQuery;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(locations),
    Object.hashAll(requirements),
    minPrice,
    maxPrice,
    sort,
    searchQuery,
  );
}

final hostDashboardPostsProvider = StreamProvider.autoDispose
    .family<List<RoommatePostModel>, HostDashboardFilter>((ref, filter) {
      // Preview/test mode has no Firebase app. Returning an empty stream keeps
      // the screen usable without inventing records that could be mistaken for
      // production data.
      if (Firebase.apps.isEmpty) return Stream.value(const []);

      final currentHostId = ref.watch(currentUserProvider)?.uid ?? '';
      // Bảng tin chủ trọ chỉ hiển thị phòng/bài đăng công khai của chủ trọ khác.
      return FirebaseFirestore.instance.collection('posts').snapshots().map((
        snapshot,
      ) {
        final posts = <RoommatePostModel>[];
        for (final document in snapshot.docs) {
          try {
            final post = RoommatePostModel.fromFirestore(document);
            if (post.status != 'deleted' &&
                post.status != 'closed' &&
                post.authorId != currentHostId) {
              posts.add(post);
            }
          } catch (error, stackTrace) {
            debugPrint(
              'Không đọc được bài đăng ${document.id}: $error\n$stackTrace',
            );
          }
        }
        final query = filter.searchQuery.trim().toLowerCase();
        final selectedLocations = filter.locations
            .map((location) => location.trim().toLowerCase())
            .where((location) => location.isNotEmpty)
            .toList();
        final selectedRequirements = filter.requirements
            .map((requirement) => requirement.trim().toLowerCase())
            .where((requirement) => requirement.isNotEmpty)
            .toList();

        final filtered = posts.where((post) {
          if (post.status == 'deleted' || post.status == 'unavailable') {
            return false;
          }

          final searchable = [
            post.title,
            post.description,
            post.authorName,
            post.authorOccupation,
            post.address,
            post.district,
            ...post.purposeTags,
            ...post.habits,
          ].join(' ').toLowerCase();
          if (query.isNotEmpty && !searchable.contains(query)) return false;

          if (selectedLocations.isNotEmpty) {
            final location = '${post.city} ${post.district} ${post.address}'
                .toLowerCase();
            if (!selectedLocations.any(location.contains)) return false;
          }

          final price = post.pricePerPerson > 0
              ? post.pricePerPerson
              : post.budgetMax;
          if (filter.minPrice != null && price < filter.minPrice!) {
            return false;
          }
          if (filter.maxPrice != null && price > filter.maxPrice!) {
            return false;
          }

          if (selectedRequirements.isNotEmpty) {
            final requirements = [
              ...post.purposeTags,
              ...post.habits,
            ].join(' ').toLowerCase();
            if (!selectedRequirements.any(requirements.contains)) {
              return false;
            }
          }

          return true;
        }).toList();

        filtered.sort((left, right) {
          switch (filter.sort) {
            case HostDashboardSort.mostInterested:
              final interest = right.interestedCount.compareTo(
                left.interestedCount,
              );
              return interest != 0
                  ? interest
                  : right.createdAt.compareTo(left.createdAt);
            case HostDashboardSort.priceAscending:
              return _price(left).compareTo(_price(right));
            case HostDashboardSort.priceDescending:
              return _price(right).compareTo(_price(left));
            case HostDashboardSort.newest:
              return right.createdAt.compareTo(left.createdAt);
          }
        });
        return filtered;
      });
    });

double _price(RoommatePostModel post) =>
    post.pricePerPerson > 0 ? post.pricePerPerson : post.budgetMax;

final hostDashboardFilterOptionsProvider =
    StreamProvider.autoDispose<HostDashboardFilterOptions>((ref) {
      if (Firebase.apps.isEmpty) {
        return Stream.value(const HostDashboardFilterOptions());
      }

      return FirebaseFirestore.instance.collection('posts').snapshots().map((
        snapshot,
      ) {
        final locations = <String>{};
        final requirements = <String>{};
        for (final document in snapshot.docs) {
          final data = document.data();
          final city =
              (data['city'] ??
                      data['thanhPho'] ??
                      data['province'] ??
                      data['tinhThanh'] ??
                      '')
                  .toString()
                  .trim();
          final district =
              (data['district'] ??
                      data['quanHuyen'] ??
                      data['khuVuc'] ??
                      data['diaDiem'] ??
                      '')
                  .toString()
                  .trim();
          if (city.isNotEmpty) locations.add(city);
          if (district.isNotEmpty) locations.add(district);

          for (final key in const ['amenities', 'tienIch']) {
            final values = data[key];
            if (values is List) {
              requirements.addAll(
                values
                    .map((value) => value.toString().trim())
                    .where((value) => value.isNotEmpty),
              );
            }
          }
        }
        final sortedLocations = locations.toList()..sort();
        final sortedRequirements = requirements.toList()..sort();
        return HostDashboardFilterOptions(
          locations: sortedLocations,
          requirements: sortedRequirements,
        );
      });
    });
