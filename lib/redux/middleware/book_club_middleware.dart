// lib/redux/middleware/book_club_middleware.dart

import 'package:redux/redux.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/firestore_service.dart';

List<Middleware<AppState>> createBookClubMiddleware() {
  final firestoreService = FirestoreService();
  final firestore = FirebaseFirestore.instance;

  return [
    TypedMiddleware<AppState, ToggleBookClubSubscriptionAction>(
        _toggleSubscription(firestore, firestoreService)),
    TypedMiddleware<AppState, UpdateBookReadingStatusAction>(
        _updateReadingStatus(firestoreService)),
    TypedMiddleware<AppState, ToggleBookClubPostLikeAction>(
        _togglePostLike(firestore)),
    // --- ADICIONADO NOVO MIDDLEWARE ---
    TypedMiddleware<AppState, ToggleBookClubReplyLikeAction>(
        _toggleReplyLike(firestore)),
  ];
}

// --- FUNÇÃO DE LIKE NO POST (Atualizada com Transação) ---
void Function(Store<AppState>, ToggleBookClubPostLikeAction, NextDispatcher)
    _togglePostLike(FirebaseFirestore firestore) {
  return (store, action, next) async {
    next(action);

    final userId = store.state.userState.userId;
    if (userId == null) return;

    try {
      final postRef = firestore
          .collection('bookClubs')
          .doc(action.bookId)
          .collection('posts')
          .doc(action.postId);

      // Usar transação para garantir consistência
      await firestore.runTransaction((transaction) async {
        final postSnapshot = await transaction.get(postRef);
        if (!postSnapshot.exists) return;

        if (action.isLiked) {
          transaction.update(postRef, {
            'likeCount': FieldValue.increment(1),
            'likedBy': FieldValue.arrayUnion([userId]),
          });
        } else {
          transaction.update(postRef, {
            'likeCount': FieldValue.increment(-1),
            'likedBy': FieldValue.arrayRemove([userId]),
          });
        }
      });
      print(
          "BookClubMiddleware: Like/unlike no post '${action.postId}' atualizado no Firestore.");
    } catch (e) {
      print("BookClubMiddleware: ERRO ao dar like no post: $e");
      rethrow; // Relança o erro para a UI poder tratar (reverter o estado)
    }
  };
}

// --- NOVA FUNÇÃO PARA LIKE NA RESPOSTA ---
void Function(Store<AppState>, ToggleBookClubReplyLikeAction, NextDispatcher)
    _toggleReplyLike(FirebaseFirestore firestore) {
  return (store, action, next) async {
    next(action);

    final userId = store.state.userState.userId;
    if (userId == null) return;

    try {
      final replyRef = firestore
          .collection('bookClubs')
          .doc(action.bookId)
          .collection('posts')
          .doc(action.postId)
          .collection('replies')
          .doc(action.replyId);

      await firestore.runTransaction((transaction) async {
        final replySnapshot = await transaction.get(replyRef);
        if (!replySnapshot.exists) return;

        if (action.isLiked) {
          transaction.update(replyRef, {
            'likeCount': FieldValue.increment(1),
            'likedBy': FieldValue.arrayUnion([userId]),
          });
        } else {
          transaction.update(replyRef, {
            'likeCount': FieldValue.increment(-1),
            'likedBy': FieldValue.arrayRemove([userId]),
          });
        }
      });
      print(
          "BookClubMiddleware: Like/unlike na resposta '${action.replyId}' atualizado no Firestore.");
    } catch (e) {
      print("BookClubMiddleware: ERRO ao dar like na resposta: $e");
      rethrow;
    }
  };
}

// Funções _toggleSubscription e _updateReadingStatus permanecem as mesmas
void Function(Store<AppState>, ToggleBookClubSubscriptionAction, NextDispatcher)
    _toggleSubscription(
        FirebaseFirestore firestore, FirestoreService firestoreService) {
  return (store, action, next) async {
    next(action);

    final userId = store.state.userState.userId;
    if (userId == null) return;

    try {
      final userRef = firestore.collection('users').doc(userId);
      final clubRef = firestore.collection('bookClubs').doc(action.bookId);

      final batch = firestore.batch();

      if (action.isSubscribing) {
        batch.update(userRef, {
          'subscribedBookClubs': FieldValue.arrayUnion([action.bookId])
        });
        batch.update(clubRef, {'participantCount': FieldValue.increment(1)});
      } else {
        batch.update(userRef, {
          'subscribedBookClubs': FieldValue.arrayRemove([action.bookId])
        });
        batch.update(clubRef, {'participantCount': FieldValue.increment(-1)});
      }

      await batch.commit();
    } catch (e) {
      print("BookClubMiddleware: ERRO ao atualizar inscrição no clube: $e");
    }
  };
}

void Function(Store<AppState>, UpdateBookReadingStatusAction, NextDispatcher)
    _updateReadingStatus(FirestoreService firestoreService) {
  return (store, action, next) async {
    next(action);

    final userId = store.state.userState.userId;
    if (userId == null) return;

    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(userId);

      await userRef.update({
        'booksRead': FieldValue.arrayRemove([action.bookId]),
        'booksToRead': FieldValue.arrayRemove([action.bookId]),
      });

      if (action.status == BookReadStatus.isRead) {
        await userRef.update({
          'booksRead': FieldValue.arrayUnion([action.bookId])
        });
      } else if (action.status == BookReadStatus.toRead) {
        await userRef.update({
          'booksToRead': FieldValue.arrayUnion([action.bookId])
        });
      }
    } catch (e) {
      print("BookClubMiddleware: ERRO ao atualizar status de leitura: $e");
    }
  };
}
