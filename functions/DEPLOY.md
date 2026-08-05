# Деплой push-уведомлений

Код готов, но три шага требуют твоих личных данных (Apple Developer аккаунт,
Firebase CLI) — их не может сделать ассистент за тебя.

## 1. Apple Developer Program — APNs Auth Key

Push-уведомления работают только с платным Apple Developer аккаунтом
(бесплатный/Personal Team это не поддерживает).

1. https://developer.apple.com/account/resources/authkeys/list → "+"
2. Название любое, отметить **Apple Push Notifications service (APNs)**
3. Скачать `.p8` файл (скачивается один раз!), запомнить **Key ID** и
   **Team ID** (виден в правом верхнем углу сайта).

## 2. Firebase Console — привязать ключ

1. https://console.firebase.google.com/project/erassvet-ac160/settings/cloudmessaging
2. Раздел "Apple app configuration" → загрузить `.p8`, вписать Key ID и Team ID.

## 3. Xcode — проверить capability

Открыть проект → таргет `erassvet` → Signing & Capabilities. Должны появиться
"Push Notifications" и "Background Modes → Remote notifications" (уже прописаны
в `erassvet.entitlements` и `project.pbxproj`, Xcode должен подхватить их сам
после `File → Packages → Reset Package Caches`, если SPM закапризничает на новом
пакете FirebaseMessaging).

## 4. Деплой Cloud Function

Из корня проекта (`/Users/khomutyanskiyaleksey/Documents/Projects/eRassvet/erassvet`,
там же где `firebase.json`):

```bash
npm install -g firebase-tools   # если ещё не установлен
firebase login
cd functions && npm install && cd ..
firebase deploy --only functions
```

Проект уже на плане Blaze (Pay as you go) — это обязательное условие для
Cloud Functions, доплата возникает только за фактическое использование.

## Проверка

1. Пересобрать и поставить приложение на **реальный iPhone** (push не работает
   в симуляторе).
2. Войти под одним аккаунтом, разрешить уведомления при системном запросе.
3. С другого аккаунта/устройства написать в чат.
4. Свернуть приложение первого аккаунта — уведомление должно прийти в течение
   нескольких секунд.
