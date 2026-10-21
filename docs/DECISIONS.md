# Décisions et hypothèses

Date de référence : 21 octobre 2026.

## D-001 — FIFO et arrondis

- Les sorties consomment les lots par date croissante, puis par identifiant pour rendre l'ordre déterministe.
- Les frais de transport unitaires sont divisés par division entière en FCFA. Le reliquat inférieur à 1 FCFA n'est pas ventilé : il reste comptablement au niveau du lot.
- Lorsqu'une vente traverse plusieurs lots, son coût figé unitaire est la moyenne pondérée entière des allocations. Les allocations détaillées sont conservées pour permettre une annulation exacte.
- La part vendeuse utilise l'arrondi mathématique à l'entier le plus proche.

## D-002 — Part propriétaire

Sur une base « bénéfice », la part propriétaire vaut bénéfice moins part vendeuse. Sur une base « chiffre d'affaires », le rapport affiche la commission vendeuse séparément et conserve le bénéfice brut comme indicateur propriétaire, car soustraire une commission de chiffre d'affaires du chiffre d'affaires ne représente pas un bénéfice.

## D-003 — Stock bas

Le seuil par défaut est de 3 paires, modifiable dans les réglages. Une variante à zéro est incluse dans les alertes.

## D-004 — Sauvegarde

L'archive contient `pasora.sqlite`, `metadata.json` et `photos/`. Une copie locale de sécurité est créée avant restauration. Les sauvegardes Drive sont limitées aux 14 plus récentes dans `appDataFolder`. Une sauvegarde d'un schéma futur est refusée avec un message explicite.

## D-005 — Compte et confidentialité

L'application est mono-utilisateur, sans serveur applicatif. Google Drive est le seul service externe, avec le scope `drive.appdata`. Les vendeuses n'ont ni compte ni accès à l'application.

## D-006 — Modèles immuables

Les entités sont des classes Dart immuables (`final`, constructeurs `const`) écrites manuellement. Ce choix est l'équivalent autorisé de Freezed et évite une génération de code inutile dans le domaine pur.

## D-007 — SQLite

`sqflite` a été retenu à la place de Drift : transactions FIFO explicites, migrations versionnées et faible coût au démarrage. Le compromis est moins de sûreté statique sur les requêtes ; les tests repository compensent ce risque.

## D-008 — Photos

Les images sont redimensionnées à 1 600 px maximum et encodées en JPEG qualité 82 dans le dossier privé. Aucun média n'est exposé dans la galerie.

## D-009 — Rapport image

L'export PNG rasterise uniquement la première page du PDF à 144 dpi, résolution suffisante pour WhatsApp sans consommation mémoire excessive. Le PDF complet reste la source de vérité pour le détail multi-page.

## D-010 — Secret de signature

Le keystore et `key.properties` sont volontairement exclus du dépôt. Une clé locale peut être générée par le script documenté ; le build release refuse silencieusement de prétendre être signé en production et utilise la signature debug seulement lorsqu'aucune clé locale n'est fournie pour les builds de développement.

