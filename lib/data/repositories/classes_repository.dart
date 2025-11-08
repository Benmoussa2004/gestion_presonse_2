import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/class_model.dart';
import '../api/api_client.dart';

class ClassesRepository {
  const ClassesRepository();

  Future<String> createClass(ClassModel model) async {
    final http.Response res = await ApiClient.post('/classes', model.toMap());
    if (res.statusCode >= 400) {
      throw StateError('API createClass failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['id'] ?? data['_id'] ?? '') as String;
  }

  Future<void> updateClass(ClassModel model) async {
    final res = await ApiClient.put('/classes/${model.id}', model.toMap());
    if (res.statusCode >= 400) {
      throw StateError('API updateClass failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> deleteClass(String id) async {
    final res = await ApiClient.delete('/classes/$id');
    if (res.statusCode >= 400) {
      throw StateError('API deleteClass failed: ${res.statusCode} ${res.body}');
    }
  }

  Stream<List<ClassModel>> watchAllClasses() async* {
    Future<List<ClassModel>> fetch() async {
      final res = await ApiClient.get('/classes');
      if (res.statusCode >= 400) throw StateError('API watchAllClasses failed: ${res.statusCode}');
      final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      return list.map((m) => ClassModel.fromMap((m['id'] ?? m['_id'] ?? '').toString(), m)).toList();
    }
    yield await fetch();
    yield* Stream<int>.periodic(const Duration(seconds: 6), (i) => i).asyncMap((_) => fetch());
  }

  Stream<List<ClassModel>> watchClassesForTeacher(String teacherId) async* {
    Future<List<ClassModel>> fetch() async {
      final res = await ApiClient.get('/classes', query: {'teacherId': teacherId});
      if (res.statusCode >= 400) throw StateError('API watchClassesForTeacher failed: ${res.statusCode}');
      final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      return list.map((m) => ClassModel.fromMap((m['id'] ?? m['_id'] ?? '').toString(), m)).toList();
    }
    yield await fetch();
    yield* Stream<int>.periodic(const Duration(seconds: 6), (i) => i).asyncMap((_) => fetch());
  }

  Stream<List<ClassModel>> watchClassesForStudent(String studentId) async* {
    Future<List<ClassModel>> fetch() async {
      final res = await ApiClient.get('/classes', query: {'studentId': studentId});
      if (res.statusCode >= 400) throw StateError('API watchClassesForStudent failed: ${res.statusCode}');
      final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      return list.map((m) => ClassModel.fromMap((m['id'] ?? m['_id'] ?? '').toString(), m)).toList();
    }
    yield await fetch();
    yield* Stream<int>.periodic(const Duration(seconds: 6), (i) => i).asyncMap((_) => fetch());
  }
}
