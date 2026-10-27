// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Yuz';

  @override
  String get splashTagline => 'Красота, обработанная на вашем устройстве';

  @override
  String get actionNext => 'Далее';

  @override
  String get actionSkip => 'Пропустить';

  @override
  String get actionGetStarted => 'Начать';

  @override
  String get actionContinue => 'Продолжить';

  @override
  String get actionRetry => 'Повторить';

  @override
  String get actionOpenSettings => 'Открыть настройки';

  @override
  String get actionClose => 'Закрыть';

  @override
  String get actionSave => 'Сохранить';

  @override
  String get actionCancel => 'Отмена';

  @override
  String get actionDelete => 'Удалить';

  @override
  String get onboardingTitle1 => 'Бьюти-камера в реальном времени';

  @override
  String get onboardingBody1 => 'Естественное сглаживание кожи с сохранением текстуры — прямо на GPU.';

  @override
  String get onboardingTitle2 => 'Приватность по умолчанию';

  @override
  String get onboardingBody2 =>
      'Эффекты камеры работают полностью на телефоне. Для локальных функций ничего не загружается.';

  @override
  String get onboardingTitle3 => 'Ваш образ, ваши пресеты';

  @override
  String get onboardingBody3 => 'Настраивайте каждый эффект от 0 до 100 и сохраняйте любимые комбинации.';

  @override
  String get permissionTitle => 'Доступ к камере';

  @override
  String get permissionBody => 'Yuz нужна камера для живого бьюти-превью и съёмки. Кадры не покидают устройство.';

  @override
  String get permissionGrant => 'Разрешить камеру';

  @override
  String get permissionDenied => 'Доступ к камере отклонён. Функции камеры недоступны, пока вы его не разрешите.';

  @override
  String get permissionPermanentlyDenied => 'Доступ к камере заблокирован. Включите его для Yuz в настройках системы.';

  @override
  String get homeGreeting => 'Создайте свой образ';

  @override
  String get homeSectionCamera => 'Камера';

  @override
  String get homeSectionEditing => 'Редактирование';

  @override
  String get homeSectionAi => 'AI-студия';

  @override
  String get homeSectionAccount => 'Аккаунт';

  @override
  String get featureBeautyCamera => 'Бьюти-камера';

  @override
  String get featureBeautyCameraSubtitle => 'Живое сглаживание кожи';

  @override
  String get featurePhotoEditor => 'Фоторедактор';

  @override
  String get featureVideoEditor => 'Видеоредактор';

  @override
  String get featureAiPhotoshoot => 'AI-фотосессия';

  @override
  String get featureAiHairstyle => 'AI-причёска';

  @override
  String get featureAiMakeup => 'AI-макияж';

  @override
  String get featureAiBackground => 'AI-фон';

  @override
  String get featureTemplates => 'Шаблоны';

  @override
  String get featureProjects => 'Проекты';

  @override
  String get featurePremium => 'Premium';

  @override
  String get featureCredits => 'Кредиты';

  @override
  String get featureProfile => 'Профиль';

  @override
  String get featureSettings => 'Настройки';

  @override
  String get featureHelp => 'Помощь';

  @override
  String get statusImplemented => 'Готово';

  @override
  String get statusPartial => 'Превью';

  @override
  String get statusNotStarted => 'В планах';

  @override
  String get featureUnavailableTitle => 'Пока недоступно';

  @override
  String featureUnavailableBody(String feature, int phase) {
    return '«$feature» запланировано на этап разработки $phase. В эту сборку не входит.';
  }

  @override
  String get beautyPanelTitle => 'Бьюти';

  @override
  String get beautySkinSmoothing => 'Сглаживание';

  @override
  String get beautyTexturePreservation => 'Текстура';

  @override
  String get beautySkinBrightening => 'Сияние';

  @override
  String get beautyReset => 'Сброс';

  @override
  String get beautyUndo => 'Отменить';

  @override
  String get beautySavePreset => 'Сохранить пресет';

  @override
  String get beautyPresetNameHint => 'Название пресета';

  @override
  String get beautyPresets => 'Пресеты';

  @override
  String get beautyPresetNatural => 'Натуральный';

  @override
  String get beautyPresetSoft => 'Мягкий';

  @override
  String get beautyPresetGlow => 'Сияние';

  @override
  String beautyPresetSaved(String name) {
    return 'Пресет «$name» сохранён';
  }

  @override
  String get cameraSwitch => 'Сменить камеру';

  @override
  String get cameraCapture => 'Сделать фото';

  @override
  String get cameraTimer => 'Таймер';

  @override
  String get cameraTimerOff => 'Таймер выкл.';

  @override
  String cameraTimerSeconds(int seconds) {
    return '$seconds с';
  }

  @override
  String get cameraFlash => 'Вспышка';

  @override
  String get cameraFlashOff => 'Вспышка выкл.';

  @override
  String get cameraFlashAuto => 'Вспышка авто';

  @override
  String get cameraFlashOn => 'Вспышка вкл.';

  @override
  String get cameraFlashTorch => 'Фонарик';

  @override
  String get cameraZoom => 'Зум';

  @override
  String get cameraExposure => 'Экспозиция';

  @override
  String get cameraNoFace => 'Лицо не найдено';

  @override
  String cameraFacesDetected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count лица',
      many: '$count лиц',
      few: '$count лица',
      one: '1 лицо',
    );
    return '$_temp0';
  }

  @override
  String get cameraTrackingUnavailable => 'Трекинг лица недоступен — только по тону кожи';

  @override
  String get cameraStarting => 'Запуск камеры…';

  @override
  String cameraMeasuredFps(String fps, String gpu, String detector) {
    return '$fps FPS · GPU $gpu мс · лицо $detector мс';
  }

  @override
  String get cameraPhotoSaved => 'Фото сохранено';

  @override
  String get errorPermissionDenied => 'Требуется разрешение на камеру.';

  @override
  String get errorCameraUnavailable => 'Камера сейчас недоступна на этом устройстве.';

  @override
  String get errorCameraInUse => 'Камера занята другим приложением.';

  @override
  String get errorCameraDisconnected => 'Камера отключилась.';

  @override
  String get errorGpu => 'GPU этого устройства не смог запустить бьюти-движок.';

  @override
  String get errorCaptureFailed => 'Не удалось сохранить фото.';

  @override
  String get errorThermal => 'Телефон перегрелся — трекинг лица приостановлен.';

  @override
  String get errorUnknown => 'Что-то пошло не так.';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get settingsLanguageSystem => 'Как в системе';

  @override
  String get settingsPerformanceOverlay => 'Показывать измеренную производительность';

  @override
  String get settingsPerformanceOverlaySubtitle => 'FPS, время GPU и трекинга лица, измеренные на устройстве';

  @override
  String get settingsPrivacy => 'Конфиденциальность';

  @override
  String get settingsAbout => 'О приложении';

  @override
  String settingsVersion(String version) {
    return 'Версия $version';
  }

  @override
  String get settingsResetOnboarding => 'Показать знакомство снова';

  @override
  String get languageUzbek => 'Oʻzbekcha';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageEnglish => 'English';

  @override
  String get privacyTitle => 'Конфиденциальность';

  @override
  String get privacyOnDeviceTitle => 'Обработка на устройстве';

  @override
  String get privacyOnDeviceBody =>
      'Живые эффекты камеры, сглаживание кожи и трекинг лица работают на телефоне. Эти функции никогда не отправляют изображения на сервер.';

  @override
  String get privacyStorageTitle => 'Что хранится';

  @override
  String get privacyStorageBody =>
      'Снятые фото сохраняются в приватном хранилище приложения. Настройки и бьюти-пресеты хранятся локально.';

  @override
  String get privacyCloudTitle => 'Облачные AI-функции';

  @override
  String get privacyCloudBody =>
      'Будущие облачные AI-функции запросят явное согласие перед загрузкой любого фото — и только для ваших фото или людей, давших согласие.';

  @override
  String get privacyDeletionTitle => 'Удаление данных';

  @override
  String get privacyDeletionBody => 'Удаление приложения стирает все локальные фото, пресеты и настройки.';
}
