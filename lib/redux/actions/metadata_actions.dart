// lib/redux/actions/metadata_actions.dart
class LoadBibleSectionCountsAction {}

class BibleSectionCountsLoadedAction {
  final Map<String, dynamic> sectionCounts; // O conteúdo do seu JSON
  BibleSectionCountsLoadedAction(this.sectionCounts);
}

class BibleSectionCountsFailureAction {
  final String error;
  BibleSectionCountsFailureAction(this.error);
}
