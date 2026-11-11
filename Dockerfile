FROM ghcr.io/cirruslabs/flutter:3.47.7 AS build

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter --version && dart --version && flutter pub get

COPY . .
RUN flutter build web --release

FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 10000
