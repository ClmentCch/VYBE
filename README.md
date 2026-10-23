# VYBE

VYBE est une plateforme de jeux pour Windows avec un lanceur au style « liquide » et **VYBE Studio**, un éditeur pour créer des jeux en Lua, importer des fichiers Roblox et publier dans l'application.

## Structure

- `vybe-app/` : projet Godot 4 (lanceur VYBE + VYBE Studio, app Windows)
- `api/` : API PHP à déployer sur o2switch, connectée à MySQL

## Mise en place de l'API (o2switch)

1. Dans cPanel, créez une base MySQL et un utilisateur, puis donnez-lui tous les droits sur la base.
2. Importez `api/schema.sql` avec phpMyAdmin.
3. Copiez `api/config.php` en `api/config.local.php` et renseignez les identifiants MySQL. Ne le committez pas.
4. Envoyez le dossier `api/` dans `public_html/` (ou un sous-domaine), en HTTPS.
5. Dans `vybe-app/scripts/api_client.gd`, remplacez `BASE_URL` par l'adresse réelle de `index.php`.

Routes : `register`, `login`, `games`, `save`, `publish`, `catalog`, `play`.

## Lancer le projet

1. Installez [Godot 4.3+](https://godotengine.org/).
2. Ouvrez `vybe-app/project.godot` et appuyez sur F5.

## Export Windows

Projet > Exporter > Ajouter > Windows Desktop, puis Exporter le projet.

## Limites de cette première étape

- Le Studio gère l'éditeur Lua, l'ajout de cubes et la sauvegarde/publication. L'exécution du Lua et l'import `.rbxl`, `.rbxm`, `.rbxlx` ne sont pas encore implémentés.
- Le style « liquide » est une base en `StyleBoxFlat` ; il peut être affiné avec des shaders.
- L'API n'a pas encore été testée sur un serveur PHP réel (PHP n'était pas disponible dans l'environnement de travail).
