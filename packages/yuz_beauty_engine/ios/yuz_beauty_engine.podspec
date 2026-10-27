Pod::Spec.new do |s|
  s.name             = 'yuz_beauty_engine'
  s.version          = '0.1.0'
  s.summary          = 'Real-time beauty camera engine (AVFoundation + Metal + MediaPipe) for Flutter.'
  s.description      = <<-DESC
Renders camera frames through Metal beauty kernels into a FlutterTexture and
tracks faces with MediaPipe Face Landmarker.
                       DESC
  s.homepage         = 'https://github.com/doniyorbek2000/yuz'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Yuz' => 'engineering@yuz.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.swift'
  s.dependency 'Flutter'
  # Pinned: verified on CocoaPods trunk (cdn.cocoapods.org) on 2026-10-27.
  s.dependency 'MediaPipeTasksVision', '1.0.0'
  s.platform = :ios, '15.0'
  s.static_framework = true
  s.frameworks = 'AVFoundation', 'CoreImage', 'CoreVideo', 'Metal'
  s.resource_bundles = {
    'YuzBeautyEngineResources' => ['Resources/face_landmarker.task'],
    'yuz_beauty_engine_privacy' => ['Resources/PrivacyInfo.xcprivacy'],
  }

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
