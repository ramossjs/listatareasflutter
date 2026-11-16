# listatareasflutter

A new Flutter project.

## Deploy en Render

Este proyecto se despliega como un servicio web Docker en Render. El
`Dockerfile` compila Flutter Web y Nginx sirve el contenido de `build/web`.

1. Sube este proyecto a un repositorio de GitHub.
2. En Render selecciona **New > Blueprint** y conecta ese repositorio.
3. Render detectará [`render.yaml`](./render.yaml) y creará el servicio.
4. Después del primer despliegue, copia el dominio `*.onrender.com`.
5. En Firebase Console, abre **Authentication > Settings > Authorized
   domains** y agrega ese dominio.

Para comprobar la compilación local:

```bash
flutter build web --release
```

## Compilar iOS con GitHub Actions

El workflow [`build-ios.yml`](./.github/workflows/build-ios.yml) compila la
aplicación en un runner macOS y publica un archivo
`listatareasflutter-unsigned.ipa` como artifact. Se ejecuta desde **Actions >
Build iOS IPA > Run workflow**.

Esta IPA no está firmada y no se puede instalar en un iPhone directamente.
Para instalarla mediante sideloading hay que firmarla con un certificado y un
provisioning profile de Apple, incluso usando una cuenta gratuita. La cuenta
gratuita normalmente limita la instalación a siete días.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
