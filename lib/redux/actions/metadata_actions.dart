// lib/redux/actions/metadata_actions.dart
import 'package:septima_biblia/models/bible_saga_model.dart';

class LoadBibleSectionCountsAction {}

class BibleSectionCountsLoadedAction {
  final Map<String, dynamic> sectionCounts;
  BibleSectionCountsLoadedAction(this.sectionCounts);
}

class BibleSectionCountsFailureAction {
  final String error;
  BibleSectionCountsFailureAction(this.error);
}

// ==========================================================
// <<< AÇÕES PARA AS SAGAS BÍBLICAS >>>
// ==========================================================

class LoadBibleSagasAction {}

class BibleSagasLoadedAction {
  final List<BibleSaga> sagas;
  BibleSagasLoadedAction(this.sagas);
}

class BibleSagasFailedAction {
  final String error;
  BibleSagasFailedAction(this.error);
}
