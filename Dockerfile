# Utilise une image de base avec Flutter préinstallé
FROM cirrusci/flutter:stable

# Définit le répertoire de travail
WORKDIR /app

# Copie le fichier pubspec pour installer les dépendances au préalable
COPY pubspec.* ./

# Installe les dépendances sans exécuter l'application
RUN flutter pub get

# Copie le reste des fichiers du projet dans le conteneur
COPY ./src /src

WORKDIR /src
# Expose le port 3000 pour l'application Flutter web (modifiez selon votre configuration)
EXPOSE 3000

# Commande pour lancer l'application Flutter en mode développement pour recharger automatiquement le code
# CMD ["flutter", "run", "-d", "web-server", "--web-port", "3000", "--web-renderer", "html"]
