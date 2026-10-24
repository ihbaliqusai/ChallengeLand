import 'package:firebase_storage/firebase_storage.dart';

import '../core/constants/app_config.dart';

class StorageService {
  StorageService({FirebaseStorage? storage}) : _storage = storage;

  final FirebaseStorage? _storage;
  FirebaseStorage get _bucket => _storage ?? FirebaseStorage.instance;

  Future<String?> getQuestionMediaUrl(String path) async {
    if (AppConfig.useMockData || path.trim().isEmpty) return null;
    return _bucket.ref(path).getDownloadURL();
  }

  Future<void> prepareFutureMediaUpload() async {
    // TODO: Add moderated media upload flow for image/audio/video questions.
  }
}
