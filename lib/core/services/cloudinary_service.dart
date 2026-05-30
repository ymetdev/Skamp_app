import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// unsigned upload — cloud name และ preset ไม่ใช่ secret
const _cloudName = 'dg3ctv3km';
const _uploadPreset = 'skamp_upload';

enum CloudinaryFolder {
  stamps,
  journals,
  avatars,
}

extension CloudinaryFolderPath on CloudinaryFolder {
  String get path {
    switch (this) {
      case CloudinaryFolder.stamps:
        return 'skamp/stamps';
      case CloudinaryFolder.journals:
        return 'skamp/journals';
      case CloudinaryFolder.avatars:
        return 'skamp/avatars';
    }
  }
}

class CloudinaryService {
  final CloudinaryPublic _cloudinary;

  CloudinaryService()
      : _cloudinary = CloudinaryPublic(
          _cloudName,
          _uploadPreset,
          cache: false,
        );

  /// Upload รูปจาก File (ถ่ายจากกล้อง)
  Future<String> uploadFile(
    File file, {
    required CloudinaryFolder folder,
    String? publicId,
  }) async {
    final response = await _cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        file.path,
        folder: folder.path,
        publicId: publicId,
        resourceType: CloudinaryResourceType.Image,
      ),
    );
    return response.secureUrl;
  }

  /// Upload รูปจาก bytes (เช่น render ของ journal page)
  Future<String> uploadBytes(
    List<int> bytes,
    String filename, {
    required CloudinaryFolder folder,
    String? publicId,
  }) async {
    final response = await _cloudinary.uploadFile(
      CloudinaryFile.fromBytesData(
        bytes,
        identifier: filename,
        folder: folder.path,
        publicId: publicId,
        resourceType: CloudinaryResourceType.Image,
      ),
    );
    return response.secureUrl;
  }

  /// สร้าง URL พร้อม transform (resize, quality)
  String transformUrl(
    String originalUrl, {
    int? width,
    int? height,
    int quality = 80,
  }) {
    final transforms = [
      if (width != null) 'w_$width',
      if (height != null) 'h_$height',
      'q_$quality',
      'f_auto',
    ].join(',');

    return originalUrl.replaceFirst('/upload/', '/upload/$transforms/');
  }

  /// Thumbnail URL — crop to stamp aspect ratio (22:30) from center
  String thumbnailUrl(String originalUrl, {int size = 300}) {
    final h = (size / (22 / 30)).round(); // height = width / kStampAspect
    final transforms = 'w_$size,h_$h,c_fill,g_center,q_70,f_auto';
    return originalUrl.replaceFirst('/upload/', '/upload/$transforms/');
  }
}

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  return CloudinaryService();
});
