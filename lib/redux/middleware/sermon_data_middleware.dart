// lib/redux/middleware/sermon_data_middleware.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart'; // <<< CORREÇÃO AQUI
import 'package:redux/redux.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/reducers.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _sermonFavoritesKey = 'sermon_favorites';
const String _sermonProgressKey = 'sermon_progress_map';

List<Middleware<AppState>> createSermonDataMiddleware() {
  final firestoreService = FirestoreService();

  return [
    TypedMiddleware<AppState, LoadSermonFavoritesAction>(
        _loadFavorites(firestoreService)),
    TypedMiddleware<AppState, ToggleSermonFavoriteAction>(
        _toggleFavorite(firestoreService)),
    TypedMiddleware<AppState, LoadSermonProgressAction>(_loadProgress()),
    TypedMiddleware<AppState, UpdateSermonProgressAction>(
        _updateProgress(firestoreService)),
  ];
}

// --- FAVORITOS (Firestore) ---

void Function(Store<AppState>, LoadSermonFavoritesAction, NextDispatcher)
    _loadFavorites(FirestoreService fs) {
  return (store, action, next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) return;

    try {
      final userDoc = await fs.getUserDetails(userId);
      final List<dynamic> favoriteIds = userDoc?[_sermonFavoritesKey] ?? [];
      store.dispatch(SermonFavoritesLoadedAction(
          Set<String>.from(favoriteIds.map((e) => e.toString()))));
    } catch (e) {
      print("Erro ao carregar favoritos de sermões: $e");
    }
  };
}

void Function(Store<AppState>, ToggleSermonFavoriteAction, NextDispatcher)
    _toggleFavorite(FirestoreService fs) {
  return (store, action, next) async {
    next(action); // Atualização otimista na UI
    final userId = store.state.userState.userId;
    if (userId == null) return;

    try {
      // Agora FieldValue é reconhecido
      final updateData = {
        _sermonFavoritesKey: action.isFavorite
            ? FieldValue.arrayUnion([action.sermonId])
            : FieldValue.arrayRemove([action.sermonId])
      };
      await fs.updateUserField(
          userId, _sermonFavoritesKey, updateData[_sermonFavoritesKey]!);
    } catch (e) {
      print("Erro ao atualizar favorito no Firestore: $e");
      // Opcional: Reverter o estado otimista em caso de erro
    }
  };
}

// --- PROGRESSO (SharedPreferences) ---

void Function(Store<AppState>, LoadSermonProgressAction, NextDispatcher)
    _loadProgress() {
  return (store, action, next) async {
    next(action);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_sermonProgressKey);
      if (jsonString != null) {
        final Map<String, dynamic> decodedMap = json.decode(jsonString);
        final progressMap = decodedMap.map((key, value) => MapEntry(
            key, SermonProgressData.fromJson(value as Map<String, dynamic>)));
        store.dispatch(SermonProgressLoadedAction(progressMap));
      }
    } catch (e) {
      print("Erro ao carregar progresso de sermões do SharedPreferences: $e");
    }
  };
}

void Function(Store<AppState>, UpdateSermonProgressAction, NextDispatcher)
    _updateProgress(FirestoreService firestoreService) {
  return (store, action, next) async {
    next(action); // Atualiza o estado no Redux

    // Salva no SharedPreferences (lógica existente)
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentProgressMap = store.state.sermonState.sermonProgress;
      final String jsonString = json.encode(currentProgressMap
          .map((key, value) => MapEntry(key, value.toJson())));
      await prefs.setString(_sermonProgressKey, jsonString);
    } catch (e) {
      print("Erro ao salvar progresso de sermões no SharedPreferences: $e");
    }

    // Salva no Firestore (nova lógica)
    final userId = store.state.userState.userId;
    if (userId != null) {
      try {
        await firestoreService.updateUnifiedReadingProgress(
          userId,
          action.sermonId,
          action.progressPercentage,
        );
      } catch (e) {
        print(
            "SermonDataMiddleware: Erro ao salvar progresso unificado para sermão: $e");
      }
    }
  };
}
