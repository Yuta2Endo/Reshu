# СибГУ Планер

Новое приложение вместо reshu 0.1.1: расписание и новости СибГУ с офлайн-режимом, напоминаниями о парах, темами и избранными группами. Написано с нуля, код и ресурсы старого приложения не используются.

## Сборка

```bash
flutter create --org ru.example --project-name sibsau_planner --platforms=android tmp_app
cp -r tmp_app/android ./android && rm -rf tmp_app
flutter pub get
flutter run            # проверка на телефоне
flutter build apk --release
```

## Что добавить в Android-проект (один раз)

1. `android/app/src/main/AndroidManifest.xml`, внутри `<manifest>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```
и внутри `<application>`:
```xml
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
```
2. `android/app/build.gradle(.kts)`: в `compileOptions` включить `isCoreLibraryDesugaringEnabled = true` (в Groovy: `coreLibraryDesugaringEnabled true`) и добавить зависимость `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`.

## Что не проверено

Среда, где писался код, без интернета и без Flutter, поэтому проект не собирался и не запускался.
- `lib/sources.dart`: адреса и разбор сайта расписания написаны наугад. Если после выбора группы пишет «не удалось разобрать страницу», поправьте `PalladaSource` и `parseTimetable()`. Демо-расписание работает без сайта.
- Напоминания планируются на 14 дней вперёд при каждом обновлении расписания. После перезагрузки телефона откройте приложение один раз.
- Виджет на главный экран пока не сделан (нужен нативный код Kotlin). Вместо него карточка «Следующая пара» в приложении.
