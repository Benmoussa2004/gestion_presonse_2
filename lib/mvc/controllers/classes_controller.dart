import '../../data/models/class_model.dart';
import '../../data/repositories/classes_repository.dart';

class ClassesController {
  final ClassesRepository _classes;
  const ClassesController(this._classes);

  Stream<List<ClassModel>> watchAll() => _classes.watchAllClasses();
  Stream<List<ClassModel>> watchForTeacher(String teacherId) =>
      _classes.watchClassesForTeacher(teacherId);
  Stream<List<ClassModel>> watchForStudent(String studentId) =>
      _classes.watchClassesForStudent(studentId);

  Future<String> create(ClassModel model) => _classes.createClass(model);
  Future<void> update(ClassModel model) => _classes.updateClass(model);
  Future<void> remove(String id) => _classes.deleteClass(id);
}

