# Как получить APK через GitHub Actions

1. Создайте пустой репозиторий на GitHub.
2. Загрузите в него содержимое папки `sibsau_planner` (включая скрытую папку `.github`).
3. Откройте вкладку **Actions** и запустите workflow **Build Android APK** (или дождитесь сборки после push в `main`/`master`).
4. После успешной сборки откройте завершённый запуск workflow, внизу раздел **Artifacts** и скачайте `sibsau-planner-release-apk`.
5. Распакуйте скачанный архив — внутри будет `app-release.apk`.

Сборка выполняется в GitHub Actions; локальные Flutter и Android SDK для этого не нужны.
