import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

enum CameraPermissionState { granted, denied, permanentlyDenied, restricted }

/// Thin seam over permission_handler so flows are testable without a device.
class CameraPermissionService {
  const CameraPermissionService();

  Future<CameraPermissionState> status() async => _map(await Permission.camera.status);

  Future<CameraPermissionState> request() async => _map(await Permission.camera.request());

  Future<bool> openSystemSettings() => openAppSettings();

  static CameraPermissionState _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return CameraPermissionState.granted;
    if (status.isPermanentlyDenied) return CameraPermissionState.permanentlyDenied;
    if (status.isRestricted) return CameraPermissionState.restricted;
    return CameraPermissionState.denied;
  }
}

final cameraPermissionServiceProvider = Provider<CameraPermissionService>((ref) => const CameraPermissionService());
