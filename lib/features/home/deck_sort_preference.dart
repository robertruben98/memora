import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/memora_card.dart';
import '../settings/settings_repository.dart';

enum DeckSortOption {
  alphabetical,
  pendingFirst,
  mostRecent,
}

extension DeckSortOptionX on DeckSortOption {
  String get stringValue {
    switch (this) {
      case DeckSortOption.alphabetical:
        return 'alphabetical';
      case DeckSortOption.pendingFirst:
        return 'pending_first';
      case DeckSortOption.mostRecent:
        return 'most_recent';
    }
  }

  String get label {
    switch (this) {
      case DeckSortOption.alphabetical:
        return 'Alfabetico (A-Z)';
      case DeckSortOption.pendingFirst:
        return 'Pendientes primero';
      case DeckSortOption.mostRecent:
        return 'Mas recientes';
    }
  }

  static DeckSortOption fromString(String? v) {
    switch (v) {
      case 'pending_first':
        return DeckSortOption.pendingFirst;
      case 'most_recent':
        return DeckSortOption.mostRecent;
      case 'alphabetical':
      default:
        return DeckSortOption.alphabetical;
    }
  }
}

String deckSortOptionToString(DeckSortOption o) => o.stringValue;

DeckSortOption deckSortOptionFromString(String? v) =>
    DeckSortOptionX.fromString(v);

String deckSortOptionLabel(DeckSortOption o) => o.label;

/// Ordena en memoria sin mutar la lista original.
List<DeckSummary> sortDecks(List<DeckSummary> decks, DeckSortOption option) {
  final copy = List<DeckSummary>.from(decks);
  switch (option) {
    case DeckSortOption.alphabetical:
      copy.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      break;
    case DeckSortOption.pendingFirst:
      copy.sort((a, b) {
        final byDue = b.dueCount.compareTo(a.dueCount);
        if (byDue != 0) return byDue;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      break;
    case DeckSortOption.mostRecent:
      copy.sort((a, b) {
        if (a.createdAt == 0 && b.createdAt == 0) {
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        }
        return b.createdAt.compareTo(a.createdAt);
      });
      break;
  }
  return copy;
}

class DeckSortNotifier extends StateNotifier<DeckSortOption> {
  final SettingsRepository _repo;

  DeckSortNotifier(this._repo) : super(DeckSortOption.alphabetical) {
    _load();
  }

  Future<void> _load() async {
    final v = await _repo.loadDeckSortOption();
    state = v;
  }

  Future<void> setOption(DeckSortOption o) async {
    state = o;
    await _repo.saveDeckSortOption(o);
  }
}

final deckSortProvider =
    StateNotifierProvider<DeckSortNotifier, DeckSortOption>((ref) {
  return DeckSortNotifier(ref.watch(settingsRepositoryProvider));
});
