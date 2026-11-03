import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/app_error.dart';

Uint8List compressFoodImage(Uint8List bytes) {
  if (bytes.length > 10 * 1024 * 1024) throw const AppError('image-too-large');
  final decoder = img.findDecoderForData(bytes);
  if (decoder is! img.JpegDecoder &&
      decoder is! img.PngDecoder &&
      decoder is! img.WebPDecoder) {
    throw const AppError('invalid-image');
  }
  final info = decoder?.startDecode(bytes);
  if (info == null ||
      info.width * info.height > 16000000 ||
      info.numFrames > 1) {
    throw const AppError('image-too-large');
  }
  final decoded = decoder!.decode(bytes);
  if (decoded == null) throw const AppError('invalid-image');
  final oriented = img.bakeOrientation(decoded);
  final resized = img.copyResize(
    oriented,
    width: oriented.width >= oriented.height
        ? oriented.width.clamp(1, 1280)
        : null,
    height: oriented.height > oriented.width
        ? oriented.height.clamp(1, 1280)
        : null,
  );
  final output = Uint8List.fromList(img.encodeJpg(resized, quality: 78));
  if (output.length > 2 * 1024 * 1024) throw const AppError('image-too-large');
  return output;
}

final foodImageServiceProvider = Provider((ref) => FoodImageService());

class FoodImageService {
  final picker = ImagePicker();
  Future<Uint8List?> pick(ImageSource source) async {
    final file = await picker.pickImage(source: source);
    if (file == null) return null;
    if (await file.length() > 10 * 1024 * 1024) {
      throw const AppError('image-too-large');
    }
    return compute(compressFoodImage, await file.readAsBytes());
  }

  Future<Uint8List?> recover() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final result = await picker.retrieveLostData();
    if (result.exception != null) throw const AppError('invalid-image');
    if (result.files?.isNotEmpty != true) return null;
    return compute(compressFoodImage, await result.files!.first.readAsBytes());
  }
}
