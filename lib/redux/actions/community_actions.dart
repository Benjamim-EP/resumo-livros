// lib/redux/actions/community_actions.dart

class SearchCommunityPostsAction {
  final String query;
  SearchCommunityPostsAction(this.query);
}

class SearchCommunityPostsSuccessAction {
  final List<Map<String, dynamic>> results;
  SearchCommunityPostsSuccessAction(this.results);
}

class SearchCommunityPostsFailureAction {
  final String error;
  SearchCommunityPostsFailureAction(this.error);
}

class ClearCommunitySearchResultsAction {}
