# Design system PeMS Store

## Intention

« Soft Luxury Commerce » : une interface mobile professionnelle, élégante et
calme, avec des surfaces claires, des bordures fines et une hiérarchie dense
mais lisible pour une utilisation quotidienne en boutique.

## Couleurs

| Rôle | Clair | Usage |
|---|---|---|
| Primaire | `#7C535D` | sélection, icônes actives, contraste |
| Conteneur primaire | `#E8B4C0` | actions principales et badges |
| Fond | `#FFF8F8` | toile chaude |
| Carte | `#FFFFFF` | contenu et formulaires |
| Texte | `#332A2D` | contenu principal |
| Texte secondaire | `#8B8385` | métadonnées |
| Bordure | `#F0E3E6` | séparation légère |
| Accent | `#D4AF72` | accent champagne ponctuel |
| Succès | `#34A853` | stock disponible et réussite |
| Erreur | `#EA4335` | rupture et erreur |

Le thème sombre utilise une surface espresso et conserve les rôles
sémantiques. La couleur n’est jamais l’unique information.

## Typographie et grille

- Police Inter embarquée, poids 400, 500, 700 et 800.
- Titres 18–30 sp, corps 12–16 sp.
- Grille de 4 dp ; espacements usuels 8, 12, 16, 20 et 24 dp.
- Cartes 18 dp, boutons 14 dp, champs 12 dp.
- Cibles tactiles d’au moins 48 dp.

## Composants

- En-tête de marque compact avec symbole PeMS Store.
- Navigation stable à cinq destinations : Accueil, Boutiques, Stock, Ventes,
  Rapports.
- Cartes métriques avec libellé, valeur réelle et détail de période.
- Badges arrondis pour les statuts de stock et de boutique.
- Formulaires en dialogue ou feuille basse avec validation et état occupé.
- États chargement, vide et erreur communs.

## Accessibilité

Les textes importants visent WCAG AA. Les erreurs sont affichées près du champ
ou dans une SnackBar. Les actions disposent de libellés/infobulles et les
montants financiers ne sont jamais réduits au point de devenir illisibles.
