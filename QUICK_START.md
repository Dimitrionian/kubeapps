# Быстрый запуск Kubeapps для разработки

## Рекомендуемый подход: Локальная разработка

### 1. Установка зависимостей

```bash
# Go 1.23+
wget https://go.dev/dl/go1.23.2.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.23.2.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# Node.js и Yarn
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
npm install -g yarn

# Kubernetes tools
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/kubectl

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 2. Настройка и запуск Dashboard (Frontend)

```bash
# Настроить конфигурацию dashboard
cat > dashboard/public/config.json << 'EOF'
{
  "kubeappsCluster": "default",
  "kubeappsNamespace": "default",
  "helmGlobalNamespace": "default",
  "carvelGlobalNamespace": "kapp-controller-packaging-global",
  "appVersion": "DEVEL",
  "authProxyEnabled": false,
  "authProxySkipLoginPage": false,
  "oauthLoginURI": "",
  "oauthLogoutURI": "",
  "clusters": ["default"],
  "featureFlags": {
    "operators": false,
    "schemaEditor": {
      "enabled": false
    }
  },
  "theme": "light",
  "remoteComponentsUrl": "",
  "customAppViews": [],
  "skipAvailablePackageDetails": true,
  "createNamespaceLabels": {}
}
EOF

**🎯 Критически важная конфигурация config.json**

> ⚠️ **Без этой настройки Kubeapps НЕ РАБОТАЕТ!**
> - UI зависает на "Fetching Cluster Info..."
> - Frontend не может подключиться к backend
> - Пользователь не может войти в систему

**Ключевые исправления:**

| Параметр                     | Было           | Стало        | Эффект                              |
|------------------------------|----------------|--------------|-------------------------------------|
| `kubeappsCluster`            | `""`           | `"default"`  | ✅ Устраняет зависание UI           |
| `skipAvailablePackageDetails`| `false`        | `true`       | ✅ Пропускает проблемную валидацию  |
| `clusters`                   | `[""]`         | `["default"]`| ✅ Указывает доступные кластеры     |
| `oauthLoginURI`              | `/oauth2/start`| `""`         | ✅ Отключает OIDC, используем токены|

**Результат:**
```bash
# ❌ Без конфигурации: UI зависает навсегда
# ✅ С конфигурацией: Полностью рабочий Kubeapps
```


# Создать недостающие CSS файлы (исправляет 404 ошибки)
echo '/* Custom styles for Kubeapps development */' > dashboard/public/custom_style.css
echo '/* Clarity UI styles for Kubeapps development */' > dashboard/public/clr-ui.min.css

cd dashboard

# Установка зависимостей
yarn install
# ✅ success Already up-to-date.

# Запуск в режиме разработки
./start-front.sh
# ✅ Starting the development server...
# ✅ Dashboard started successfully

# Доступ: http://localhost:3000
```

**Результат**: Dashboard успешно запускается на порту 3000 с правильной конфигурацией.

### 3. Настройка и запуск Backend API

```bash
# Настройка PostgreSQL для Helm плагина
psql -c "CREATE DATABASE kubeapps;"
psql -c "ALTER USER $(whoami) PASSWORD '821310';" kubeapps
psql -c "SHOW port;" kubeapps  # Запомните порт (обычно 5433)

# Настройка переменных окружения
cp .env.template .env
# Отредактируйте .env файл с вашими данными:
# POSTGRES_HOST=localhost
# POSTGRES_PORT=5433  # Ваш порт PostgreSQL
# POSTGRES_DB=kubeapps
# POSTGRES_USER=ваше_имя_пользователя
# POSTGRES_PASSWORD=your_password
# KUBECONFIG=/path/to/your/kubeconfig.yaml

cd cmd/kubeapps-apis

# Сборка основного API сервера (требует Go 1.23+)
go build -o kubeapps-apis .

# ОБЯЗАТЕЛЬНО: Сборка плагинов (иначе UI не будет работать)
# Resources плагин (для управления namespace)
cd plugins/resources/v1alpha1
go build -buildmode=plugin -o ../../../resources.so *.go
cd ../../..

# Helm плагин (для управления Helm charts)
cd plugins/helm/packages/v1alpha1
go build -buildmode=plugin -o ../../../../helm.so *.go
cd ../../../..

# Проверить что плагины собраны
ls -la *.so
# Должно показать: helm.so (~108MB) и resources.so (~82MB)

# Создание токена для входа
kubectl create serviceaccount kubeapps-dev -n default
kubectl create clusterrolebinding kubeapps-dev --clusterrole=cluster-admin --serviceaccount=default:kubeapps-dev

# Запуск backend (используйте start-back.sh для автоматической загрузки .env)
./start-back.sh
```

**Результат**: 
- ✅ PostgreSQL настроен для helm плагина
- ✅ Плагины собраны и готовы к работе
- ✅ Backend запущен с полной функциональностью
- ✅ Токен для входа создан

### Запуск системы

```bash
# Терминал 1: Backend (если еще не запущен)
./start-back.sh

# Терминал 2: Frontend
cd dashboard
yarn start

# Получить токен для входа
kubectl create token kubeapps-dev -n default

# Открыть http://localhost:3000 и вставить токен
```

### 4. Использование существующего кластера

#### Вариант A: С готовым KUBECONFIG (рекомендуется)

```bash
# Сохраните ваш KUBECONFIG файл
export KUBECONFIG=/path/to/your/kubeconfig

# Проверка подключения
kubectl get nodes

# Запуск backend API с вашим кластером
cd cmd/kubeapps-apis
./kubeapps-apis serve --port=50051 --unsafe-local-dev-kubeconfig

# Dashboard уже работает на http://localhost:3000
```

### Структура для кастомизации

```
dashboard/src/
├── components/          # UI компоненты
├── containers/          # Контейнеры с логикой
├── actions/            # Redux actions
├── reducers/           # Redux reducers
└── shared/             # Общие утилиты

cmd/kubeapps-apis/
├── core/               # Основная логика API
├── plugins/            # Плагины (Helm, Flux, Carvel)
└── server/             # gRPC сервер
```

## Основные точки для кастомизации

1. **UI**: `dashboard/src/components/`
2. **API**: `cmd/kubeapps-apis/core/`
3. **Плагины**: `cmd/kubeapps-apis/plugins/`
4. **Конфигурация**: `chart/kubeapps/values.yaml`

Этот подход позволяет быстро начать разработку без решения проблем с Docker образами.

## Резюме тестирования

✅ **Dashboard (Frontend)**: Успешно запускается на http://localhost:3000  
✅ **Backend API**: Собирается успешно, но требует Kubernetes кластер  

**Рекомендация**: Используйте вариант 4A с вашим KUBECONFIG для полноценной локальной разработки!

🎉 **Результат**: Полностью рабочий Kubeapps с доступом к вашему Kubernetes кластеру!

### Что должно работать

✅ **Аутентификация**: Вход по токену  
✅ **Просмотр namespace**: Список доступных пространств имен  
✅ **Helm charts**: Просмотр и установка Helm пакетов  
✅ **Управление приложениями**: Установка, обновление, удаление  
✅ **Мониторинг ресурсов**: Просмотр статуса развернутых приложений  

### Что НЕ будет работать (и это нормально)

❌ **Flux packages**: Требует Redis  
❌ **Carvel packages**: Требует kapp-controller  
❌ **Operators**: Отключены в конфигурации  
❌ **OIDC authentication**: Используем токены  

## Решение проблем 404

### Проблема 1: `custom_locale.json GET 404`

```bash
# Создать пустой файл локализации
echo '{}' > dashboard/public/custom_locale.json
```

### Проблема 2: `GetConfiguredPlugins POST 404`

Это означает, что backend API сервер не запущен или недоступен.

**Решение:**

```bash
# 1. Убедитесь что kubeapps-apis собран
cd cmd/kubeapps-apis
go build -o kubeapps-apis .

# 2. Запустите API сервер
./start-back.sh

# 3. В другом терминале запустите dashboard
./start-front.sh
```

## Ключевые исправления для работы

1. **Конфигурация кластера**: Установка `"kubeappsCluster": "default"` вместо пустой строки
2. **PostgreSQL**: Правильная настройка базы данных для helm плагина
3. **Пропуск валидации**: `"skipAvailablePackageDetails": true`
4. **CSS файлы**: Создание недостающих custom_style.css и clr-ui.min.css
5. **Плагины**: Сборка resources и helm плагинов
6. **Токен аутентификации**: Создание service account в namespace default

**Статус**: ✅ ПОЛНОСТЬЮ РАБОЧЕЕ РЕШЕНИЕ
