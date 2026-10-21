# Configuration Google Drive

PeMS Store fonctionne hors connexion sans configuration Google. Pour la sauvegarde cloud, l'application demande uniquement `https://www.googleapis.com/auth/drive.appdata` : les archives sont invisibles dans le Drive ordinaire et accessibles seulement par PeMS Store.

## 1. Créer le projet

1. Ouvrir la [Google Cloud Console](https://console.cloud.google.com/).
2. Créer un projet, par exemple `PeMS Store Production`.
3. Dans **API et services → Bibliothèque**, rechercher **Google Drive API** puis cliquer **Activer**.

## 2. Écran de consentement

1. Ouvrir **Google Auth Platform → Branding**.
2. Nom de l'application : `PeMS Store` ; renseigner l'adresse d'assistance et le logo carré.
3. Choisir **Externe** si l'application n'est pas limitée à une organisation Workspace.
4. Ajouter le scope `drive.appdata` uniquement.
5. En mode test, ajouter les comptes Google autorisés. Pour une diffusion publique, publier l'écran de consentement selon les demandes de Google.

## 3. Empreintes SHA-1

Empreinte debug :

```bash
keytool -list -v -alias androiddebugkey \
  -keystore ~/.android/debug.keystore -storepass android -keypass android
```

Empreinte release (après création de la clé) :

```bash
keytool -list -v -alias pasora \
  -keystore android/app/pasora-release.jks
```

Copier la valeur **SHA1** de chaque commande.

## 4. Identifiants OAuth Android

Créer deux identifiants **OAuth client ID → Android** :

| Variante | Package | SHA-1 |
|---|---|---|
| Debug | `com.mamaariege.pasora` | empreinte debug |
| Release | `com.mamaariege.pasora` | empreinte release |

Le plugin `google_sign_in` découvre la configuration Android par package + signature ; aucun secret client ne doit être embarqué. Si Firebase est utilisé pour centraliser les identifiants, télécharger `google-services.json` dans `android/app/` et activer le plugin Google Services ; ce chemin est facultatif pour l'authentification native par empreinte.

## 5. Vérification

1. Installer un APK signé avec la clé dont le SHA-1 est enregistré.
2. Ouvrir **Réglages → Sauvegarde et restauration → Drive**.
3. Choisir le compte, accepter le scope privé.
4. Vérifier que l'historique affiche l'état **Drive**.
5. Installer l'application sur un autre téléphone, choisir **Restaurer mes données** et le même compte.

Erreurs habituelles : `ApiException: 10` signifie presque toujours package ou SHA-1 incorrect ; un écran de connexion fermé immédiatement indique souvent que le compte n'est pas utilisateur de test ; une sauvegarde locale continue de fonctionner même si Drive est absent.

