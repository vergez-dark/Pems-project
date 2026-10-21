# Design system Pasora

## Intention

Une interface de terrain chaleureuse, nette et rassurante. Le vert forêt évoque la stabilité financière ; le vert citron signale l'action et la progression sans reprendre les codes génériques d'une application bancaire.

## Couleurs

| Rôle | Clair | Usage |
|---|---|---|
| Primaire | `#12372A` | actions, en-têtes, chiffres clés |
| Secondaire | `#536500` | filtres et sélections |
| Accent | `#D9E76C` | détail de marque, emphase contrôlée |
| Fond | `#F7F5EF` | toile chaude, réduction de l'éblouissement |
| Texte | `#15221C` | contenu principal |
| Profit | `#17834D` | résultat positif |
| Perte | `#BA3A31` | résultat négatif et erreur |
| Alerte | `#E09A22` | stock bas, attention |

Le thème sombre est dérivé par Material 3 avec surface `#111A16`. Les couleurs sémantiques ne sont jamais le seul vecteur d'information : elles sont accompagnées d'un libellé ou d'une icône.

## Typographie

- Police Inter embarquée (400, 500, 700, 800) : aucune latence réseau et rendu cohérent hors connexion.
- Titres 22–32 sp, graisse 800/900 et approche légèrement resserrée.
- Corps 14–16 sp, interligne 1,4 à 1,5.
- Montants : chiffres tabulaires lorsque le moteur le permet, jamais en taille inférieure à 16 sp sur les cartes clés.

## Grille

- Base : 4 dp.
- Marges écran : 20–24 dp.
- Espacements usuels : 8, 12, 16, 20, 24, 32 dp.
- Rayons : champs 16 dp, cartes 20 dp, panneaux héro 24–28 dp.
- Cibles tactiles : 48 dp minimum ; boutons principaux 52 dp.

## Composants

- **Hero financier** : fond forêt, bénéfice 30–32 sp, deux indicateurs secondaires.
- **Metric card** : icône, montant, libellé ; profit/perte explicite.
- **Form sheet** : bottom sheet plein écran si clavier, poignée, calcul en direct, action pleine largeur.
- **Empty state** : pictogramme circulaire, titre, explication, une action.
- **Error state** : message concret et bouton « Réessayer ».
- **Loading state** : blocs skeleton sans saut de mise en page.
- **Navigation** : 4 destinations stables ; les actions métier sont des FAB contextuels.

## Accessibilité

- Contraste visé WCAG AA : texte normal ≥ 4,5:1, grand texte ≥ 3:1.
- Aucun texte important sur l'accent citron sans couleur forêt.
- Mise à l'échelle du texte laissée au système.
- Infobulles sur les boutons d'icône et libellés explicites dans les formulaires.
- Erreurs annoncées en SnackBar et visibles près des champs lorsque possible.
- Les gestes essentiels ont une alternative par bouton ; aucune dépendance au balayage.

## Mouvement

Transitions Material natives de 200–300 ms. Les indicateurs d'onboarding s'animent en 220 ms. Pas d'animation décorative continue afin de préserver batterie et fluidité sur appareils d'entrée de gamme.

