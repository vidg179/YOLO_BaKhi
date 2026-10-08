import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/detection_result.dart';

class HistoryService {
  static const String _storageKey = 'detection_history_items';

  /// Save a detection snapshot and its metadata to disk and preferences
  Future<HistoryItem?> saveDetection({
    required XFile photoFile,
    required List<Recognition> detections,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final historyDir = Directory('${appDir.path}/history');
      if (!await historyDir.exists()) {
        await historyDir.create(recursive: true);
      }

      final String itemId = DateTime.now().millisecondsSinceEpoch.toString();
      final String targetPath = '${historyDir.path}/snapshot_$itemId.jpg';

      // Copy snapshot file
      await File(photoFile.path).copy(targetPath);

      final newItem = HistoryItem(
        id: itemId,
        imagePath: targetPath,
        timestamp: DateTime.now(),
        detections: detections,
      );

      final prefs = await SharedPreferences.getInstance();
      final List<String> existingJson = prefs.getStringList(_storageKey) ?? [];

      existingJson.add(jsonEncode(newItem.toJson()));
      await prefs.setStringList(_storageKey, existingJson);

      return newItem;
    } catch (e) {
      debugPrint('Error saving history item: $e');
      return null;
    }
  }

  /// Retrieve all history items ordered from newest to oldest
  Future<List<HistoryItem>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> rawJson = prefs.getStringList(_storageKey) ?? [];

      final List<HistoryItem> items = rawJson.map((jsonStr) {
        final Map<String, dynamic> map = jsonDecode(jsonStr);
        return HistoryItem.fromJson(map);
      }).toList();

      // Sort by newest timestamp first
      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return items;
    } catch (e) {
      debugPrint('Error loading history: $e');
      return [];
    }
  }

  /// Delete a single history item by ID
  Future<bool> deleteItem(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> rawJson = prefs.getStringList(_storageKey) ?? [];

      String? targetImagePath;
      final List<String> updatedList = [];

      for (var jsonStr in rawJson) {
        final Map<String, dynamic> map = jsonDecode(jsonStr);
        if (map['id'] == id) {
          targetImagePath = map['imagePath'] as String?;
        } else {
          updatedList.add(jsonStr);
        }
      }

      await prefs.setStringList(_storageKey, updatedList);

      // Delete image file if exists
      if (targetImagePath != null) {
        final file = File(targetImagePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting history item: $e');
      return false;
    }
  }

  /// Clear all stored history items and images
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<HistoryItem> items = await getHistory();

      for (var item in items) {
        final file = File(item.imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      await prefs.remove(_storageKey);
    } catch (e) {
      debugPrint('Error clearing history: $e');
    }
  }
}
