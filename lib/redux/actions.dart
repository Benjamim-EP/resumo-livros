// redux/actions.dart
// Define as ações para carregar livros e alterar a página
import 'package:septima_biblia/redux/reducers.dart';

class LoadBooksAction {
  final int page;
  LoadBooksAction(this.page);
}

class BooksLoadedByTagAction {
  final String tag;
  final List<Map<String, String>> books;

  BooksLoadedByTagAction(this.tag, this.books);
}

class BooksLoadedAction {
  final List<String> books;
  final bool hasMore;

  BooksLoadedAction(this.books, {this.hasMore = true});
}

// Ação para carregar os detalhes de um livro
class LoadBookDetailsAction {
  final String bookId;

  LoadBookDetailsAction(this.bookId);
}

class BookDetailsLoadedAction {
  final String bookId;
  final Map<String, dynamic> bookDetails;

  BookDetailsLoadedAction(this.bookId, this.bookDetails);
}

// Ação para carregar os detalhes de um autor
class LoadAuthorDetailsAction {
  final String authorId;

  LoadAuthorDetailsAction(this.authorId);
}

class AuthorDetailsLoadedAction {
  final String authorId;
  final Map<String, dynamic> authorDetails;

  AuthorDetailsLoadedAction(this.authorId, this.authorDetails);
}

class AuthorBooksLoadedAction {
  final String authorId;
  final List<Map<String, dynamic>> books;

  AuthorBooksLoadedAction(this.authorId, this.books);
}

// Ação para quando o usuário faz login com sucesso
class UserLoggedInAction {
  final String userId;
  final String email;
  final String nome;

  UserLoggedInAction({
    required this.userId,
    required this.email,
    required this.nome,
  });
}

class UpdateUserUidAction {
  final String uid;

  UpdateUserUidAction(this.uid);
}

class LoadUserStatsAction {}

class UserStatsLoadedAction {
  final Map<String, dynamic> stats;

  UserStatsLoadedAction(this.stats);
}

// Ação para quando o usuário faz logout
class UserLoggedOutAction {}

class LoadTagsAction {}

class TagsLoadedAction {
  final List<String> tags;

  TagsLoadedAction(this.tags);
}

class LoadAuthorsAction {}

class AuthorsLoadedAction {
  final List<Map<String, dynamic>> authors;

  AuthorsLoadedAction(this.authors);
}

// Tópicos

class LoadTopicContentAction {
  final String topicId;

  LoadTopicContentAction(this.topicId);
}

class TopicContentLoadedAction {
  final String topicId;
  final String content;
  final String titulo;
  final String bookId;
  final String capituloId;
  final String chapterName;
  final int? chapterIndex;

  TopicContentLoadedAction(
    this.topicId,
    this.content,
    this.titulo,
    this.bookId,
    this.capituloId,
    this.chapterName,
    this.chapterIndex,
  );
}

class LoadSimilarTopicsAction {
  final String topicId;
  LoadSimilarTopicsAction(this.topicId);
}

class SimilarTopicsLoadedAction {
  final String topicId;
  final List<Map<String, dynamic>> similarTopics;

  SimilarTopicsLoadedAction(this.topicId, this.similarTopics);
}

class TopicMetadatasLoadedAction {
  final String topicId;
  final Map<String, dynamic> topicMetadata;

  TopicMetadatasLoadedAction(this.topicId, this.topicMetadata);
}

// Ação para salvar um tópico em uma coleção
class SaveTopicToCollectionAction {
  final String collectionName;
  final String topicId;

  SaveTopicToCollectionAction(this.collectionName, this.topicId);
}

class LoadTopicsAction {
  final List<String> topicIds;

  LoadTopicsAction(this.topicIds);
}

class TopicsLoadedAction {
  final List<Map<String, dynamic>> topics;

  TopicsLoadedAction(this.topics);
}

// Ação para carregar as coleções de tópicos do usuário
class LoadUserTopicCollectionsAction {}

// Ação para atualizar as coleções no estado após salvar ou carregar
class UserTopicCollectionsLoadedAction {
  final Map<String, List<String>> topicSaves;

  UserTopicCollectionsLoadedAction(this.topicSaves);
}

class LoadUserCollectionsAction {}

class UserCollectionsLoadedAction {
  final Map<String, List<String>> topicSaves;

  UserCollectionsLoadedAction(this.topicSaves);
}

class CheckFirstLoginAction {
  final String userId;

  CheckFirstLoginAction(this.userId);
}

class FirstLoginSuccessAction {
  final bool isFirstLogin;

  FirstLoginSuccessAction(this.isFirstLogin);
}

class FirstLoginFailureAction {
  final String error;

  FirstLoginFailureAction(this.error);
}

class StartBookProgressAction {
  final String bookId;
  StartBookProgressAction(this.bookId);
}

class MarkTopicAsReadAction {
  final String bookId;
  final String topicId;
  final String chapterId; // Novo parâmetro

  MarkTopicAsReadAction(this.bookId, this.topicId, this.chapterId);
}

class LoadBooksInProgressAction {}

class BooksInProgressLoadedAction {
  final List<Map<String, dynamic>> books;

  BooksInProgressLoadedAction(this.books);
}

class UpdateUserFieldAction {
  final String field;
  final String value;

  UpdateUserFieldAction(this.field, this.value);
}

class LoadUserDetailsAction {}

class UserDetailsLoadedAction {
  final Map<String, dynamic> userDetails;

  UserDetailsLoadedAction(this.userDetails);
}

class LoadUserPremiumStatusAction {}

class UserPremiumStatusLoadedAction {
  final Map<String, dynamic> premiumStatus;

  UserPremiumStatusLoadedAction(this.premiumStatus);
}

class SearchByQueryAction {
  final String query;

  SearchByQueryAction({required this.query});
}

class SearchSuccessAction {
  final List<Map<String, dynamic>> topics;

  SearchSuccessAction(this.topics);
}

class SearchFailureAction {
  final String error;

  SearchFailureAction(this.error);
}

// Ação para iniciar o carregamento
class LoadTopicsByFeatureAction {}

// Ação para concluir o carregamento
class TopicsByFeatureLoadedAction {
  final Map<String, List<Map<String, dynamic>>> topicsByFeature;

  TopicsByFeatureLoadedAction(this.topicsByFeature);
}

class LoadTopicsContentUserSavesAction {}

class LoadTopicsContentUserSavesSuccessAction {
  final Map<String, List<Map<String, dynamic>>> topicsByCollection;

  LoadTopicsContentUserSavesSuccessAction(this.topicsByCollection);
}

class LoadTopicsContentUserSavesFailureAction {
  final String error;

  LoadTopicsContentUserSavesFailureAction(this.error);
}

class LoadBooksUserProgressAction {}

class LoadBooksUserProgressSuccessAction {
  final List<Map<String, dynamic>> books;

  LoadBooksUserProgressSuccessAction(this.books);
}

class LoadBooksUserProgressFailureAction {
  final String error;

  LoadBooksUserProgressFailureAction(this.error);
}

class LoadBooksDetailsAction {}

class LoadBooksDetailsSuccessAction {
  final List<Map<String, dynamic>> bookDetails;

  LoadBooksDetailsSuccessAction(this.bookDetails);
}

class LoadBooksDetailsFailureAction {
  final String error;

  LoadBooksDetailsFailureAction(this.error);
}

class ClearAuthorDetailsAction {}

class AddTopicToRouteAction {
  final String topicId;

  AddTopicToRouteAction(this.topicId);
}

class ClearRouteAction {}

// Carregar Rotas
class LoadUserRoutesAction {}

class UserRoutesLoadedAction {
  final List<Map<String, dynamic>> routes;

  UserRoutesLoadedAction(this.routes);
}

class UserRoutesLoadFailedAction {
  final String error;

  UserRoutesLoadFailedAction(this.error);
}

class DeleteTopicCollectionAction {
  final String collectionName;

  DeleteTopicCollectionAction(this.collectionName);
}

class DeleteSingleTopicFromCollectionAction {
  final String collectionName;
  final String topicId;

  DeleteSingleTopicFromCollectionAction(this.collectionName, this.topicId);
}

class UserVerseCollectionsUpdatedAction {
  final Map<String, List<Map<String, dynamic>>> verseSaves;

  UserVerseCollectionsUpdatedAction(this.verseSaves);
}

class SaveVerseToCollectionAction {
  final String collectionName;
  final String verseId; // Exemplo: "bibleverses-gn-7-3"

  SaveVerseToCollectionAction(this.collectionName, this.verseId);
}

class LoadWeeklyRecommendationsAction {}

class WeeklyRecommendationsLoadedAction {
  final List<Map<String, dynamic>> books;
  WeeklyRecommendationsLoadedAction(this.books);
}

class CheckBookProgressAction {
  final String bookId;
  CheckBookProgressAction(this.bookId);
}

class LoadBookProgressSuccessAction {
  final String bookId;
  final List<String> readTopics;
  LoadBookProgressSuccessAction(this.bookId, this.readTopics);
}

class LoadBookProgressFailureAction {
  final String error;
  LoadBookProgressFailureAction(this.error);
}

class LoadUserDiariesAction {}

class LoadUserDiariesSuccessAction {
  final List<Map<String, dynamic>> diaries;
  LoadUserDiariesSuccessAction(this.diaries);
}

class LoadUserDiariesFailureAction {
  final String error;
  LoadUserDiariesFailureAction(this.error);
}

class AddDiaryEntryAction {
  final String title;
  final String content;

  AddDiaryEntryAction(this.title, this.content);
}

class MarkBookAsReadingAction {
  final String bookId;
  MarkBookAsReadingAction(this.bookId);
}

// chat actions
class SendMessageAction {
  final String userMessage;
  SendMessageAction(this.userMessage);
}

class SendMessageSuccessAction {
  final String botResponse;
  SendMessageSuccessAction(this.botResponse);
}

class SendMessageFailureAction {
  final String error;
  SendMessageFailureAction(this.error);
}

// Highlight Actions
class LoadUserHighlightsAction {}

class UserHighlightsLoadedAction {
  final Map<String, Map<String, dynamic>> highlights; // <<< TIPO ATUALIZADO
  UserHighlightsLoadedAction(this.highlights);
}

class ToggleHighlightAction {
  final String verseId;
  final String? colorHex;
  // >>> NOVO PARÂMETRO <<<
  final List<String>? tags;

  ToggleHighlightAction(this.verseId, {this.colorHex, this.tags});
}

// Disparada pela UI para carregar todas as tags do usuário
class LoadUserTagsAction {}

// Despachada pelo middleware após carregar as tags do Firestore
class UserTagsLoadedAction {
  final List<String> tags;
  UserTagsLoadedAction(this.tags);
}

// Ação interna do middleware para garantir que uma tag exista no Firestore
class EnsureUserTagExistsAction {
  final String tagName;
  EnsureUserTagExistsAction(this.tagName);
}

class AddCommentHighlightAction {
  // Esta já recebe um Map, então só precisamos garantir que o Map contenha o campo 'tags'
  final Map<String, dynamic> commentHighlightData;
  AddCommentHighlightAction(this.commentHighlightData);
}

// Note Actions
class LoadUserNotesAction {}

class UserNotesLoadedAction {
  // ANTES: final Map<String, String> notes;
  // DEPOIS:
  final List<Map<String, dynamic>> notes; // Agora é uma lista de mapas
  UserNotesLoadedAction(this.notes);
}

class SaveNoteAction {
  final String verseId;
  final String text;
  SaveNoteAction(this.verseId, this.text);
}

class DeleteNoteAction {
  final String verseId;
  DeleteNoteAction(this.verseId);
}

class SetInitialBibleLocationAction {
  final String? bookAbbrev;
  final int? chapter;
  // REMOVIDO: final String? sectionIdToScrollTo;

  SetInitialBibleLocationAction(this.bookAbbrev,
      this.chapter /* REMOVIDO: , {this.sectionIdToScrollTo} */);
}

class RecordReadingHistoryAction {
  final String bookAbbrev;
  final int chapter;
  // final String bookName; // Adicione se o middleware for usar

  RecordReadingHistoryAction(
      this.bookAbbrev, this.chapter /*, {required this.bookName}*/);
}

class LoadReadingHistoryAction {}

class ReadingHistoryLoadedAction {
  final List<Map<String, dynamic>> history;
  ReadingHistoryLoadedAction(this.history);
}

// Ação para atualizar o último local lido no estado Redux
// (Pode ser disparada pelo middleware após salvar no Firestore)
class UpdateLastReadLocationAction {
  final String bookAbbrev;
  final int chapter;
  UpdateLastReadLocationAction(this.bookAbbrev, this.chapter);
}

class LoadUserCommentHighlightsAction {}

class UserCommentHighlightsLoadedAction {
  final List<Map<String, dynamic>> commentHighlights;
  UserCommentHighlightsLoadedAction(this.commentHighlights);
}

class RemoveCommentHighlightAction {
  final String commentHighlightId;
  RemoveCommentHighlightAction(this.commentHighlightId);
}

class RequestBottomNavChangeAction {
  final int index;
  RequestBottomNavChangeAction(this.index);
}

class ClearTargetBottomNavAction {}

// Ações para o Tema
class SetThemeAction {
  final AppThemeOption themeOption;
  SetThemeAction(this.themeOption);
}

// Ação para ser despachada na inicialização para carregar o tema salvo
class LoadSavedThemeAction {}

class RequestRewardedAdAction {}

// Despachada pelo middleware após o usuário assistir ao anúncio com sucesso e a recompensa ser concedida
class RewardedAdWatchedAction {
  final int coinsAwarded; // Quantidade de moedas efetivamente adicionadas
  final DateTime adWatchTime; // Momento em que o anúncio foi assistido

  RewardedAdWatchedAction(this.coinsAwarded, this.adWatchTime);
}

class UpdateRewardedAdControlDataAction {
  final DateTime lastAdWatchTime;
  final int adsWatchedToday;

  UpdateRewardedAdControlDataAction({
    required this.lastAdWatchTime,
    required this.adsWatchedToday,
  });
}

class LoadAdLimitDataAction {}

class AdLimitDataLoadedAction {
  final DateTime? firstAdTimestamp;
  final int adsInWindowCount;
  AdLimitDataLoadedAction(
      {this.firstAdTimestamp, required this.adsInWindowCount});
}

class UpdateAdWindowStatsAction {
  final DateTime? firstAdTimestamp; // Pode ser null para resetar a janela
  final int adsInWindowCount;
  UpdateAdWindowStatsAction(
      {this.firstAdTimestamp, required this.adsInWindowCount});
}

class UpdateUserCoinsAction {
  // NOVO
  final int newCoinAmount;
  UpdateUserCoinsAction(this.newCoinAmount);
}

class UserEnteredGuestModeAction {
  // <<< INÍCIO DA MUDANÇA: Adiciona parâmetros opcionais >>>
  final int? initialCoins;
  final int? initialAdsToday;
  final DateTime? initialLastAdTime;

  UserEnteredGuestModeAction({
    this.initialCoins,
    this.initialAdsToday,
    this.initialLastAdTime,
  });
  // <<< FIM DA MUDANÇA >>>
}

class UserExitedGuestModeAction {} // Ou use UserLoggedOutAction se fizer sentido

