# Étape 1 : build Flutter web
FROM --platform=linux/arm64 ghcr.io/cirruslabs/flutter:stable AS build


WORKDIR /app
COPY fs_front_end/ .

RUN flutter pub get
RUN flutter build web --release
RUN chmod -R a+r /app/build/web

# Étape 2 : serveur web nginx
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
# Ajout de la configuration nginx personnalisée
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
# Copie le script d'entrée
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
CMD ["/entrypoint.sh"]
