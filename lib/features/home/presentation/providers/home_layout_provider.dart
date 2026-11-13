import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/home_card_id.dart';

const _orderKey = 'home_order';
const _hiddenKey = 'home_hidden';

final homeLayoutProvider =
    NotifierProvider<HomeLayoutNotifier, HomeLayout>(HomeLayoutNotifier.new);

class HomeLayoutNotifier extends Notifier<HomeLayout> {
  @override
  HomeLayout build() {
    _load();
    return HomeLayout.initial();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final byName = HomeCardId.values.asNameMap();
      final saved = (prefs.getStringList(_orderKey) ?? <String>[])
          .map((n) => byName[n])
          .whereType<HomeCardId>()
          .toList();
      final order = [
        ...saved,
        ...HomeCardId.values.where((c) => !saved.contains(c)),
      ];
      final hidden = (prefs.getStringList(_hiddenKey) ?? <String>[])
          .map((n) => byName[n])
          .whereType<HomeCardId>()
          .toSet();
      state = HomeLayout(order: order, hidden: hidden);
    } catch (_) {
      // Keep defaults if local preferences are unavailable.
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_orderKey, state.order.map((c) => c.name).toList());
      await prefs.setStringList(_hiddenKey, state.hidden.map((c) => c.name).toList());
    } catch (_) {}
  }

  void reorder(int oldIndex, int newIndex) {
    final list = [...state.order];
    if (newIndex > oldIndex) newIndex -= 1;
    list.insert(newIndex, list.removeAt(oldIndex));
    state = state.copyWith(order: list);
    _save();
  }

  void toggleVisibility(HomeCardId id) {
    final hidden = {...state.hidden};
    hidden.contains(id) ? hidden.remove(id) : hidden.add(id);
    state = state.copyWith(hidden: hidden);
    _save();
  }
}
