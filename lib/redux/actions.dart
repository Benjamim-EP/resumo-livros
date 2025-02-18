// redux/actions.dart
// Define as ações para carregar livros e alterar a página
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

class SaveUserFeaturesAction {
  final Map<String, dynamic> features;

  SaveUserFeaturesAction(this.features);
}

class UserFeaturesLoadedAction {
  final Map<String, dynamic> features;

  UserFeaturesLoadedAction(this.features);
}

// embeddings e vector search

class EmbedAndSearchFeaturesAction {
  final Map<String, String> features;

  EmbedAndSearchFeaturesAction(this.features);
}

class EmbedAndSearchSuccessAction {
  final List<Map<String, dynamic>> recommendations;

  EmbedAndSearchSuccessAction(this.recommendations);
}

class EmbedAndSearchFailureAction {
  final String error;

  EmbedAndSearchFailureAction(this.error);
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

class FetchTribeTopicsAction {
  final Map<String, dynamic> features;

  FetchTribeTopicsAction(this.features);
}

class FetchTribeTopicsSuccessAction {
  final Map<String, List<Map<String, dynamic>>> topicsByFeature;
  FetchTribeTopicsSuccessAction(this.topicsByFeature);
}

class FetchTribeTopicsFailureAction {
  final String error;
  FetchTribeTopicsFailureAction(this.error);
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
