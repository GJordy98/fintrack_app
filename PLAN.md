# FinTrack — Plan d'implémentation

> Basé sur `Nouveau Microsoft Word Document.docx` (spécification complète).
> Toolchain cible : Flutter 3.41.9 / Dart 3.11.5 (stable).
> Principe directeur : **local-first (Hive)** → l'app est 100 % utilisable hors-ligne ;
> le backend Django n'arrive que pour la sauvegarde/sync (premium).

---

## Phase 0 — Fondations du projet Flutter

**Objectif :** un squelette qui compile, avec l'architecture BLoC et toutes les dépendances.

1. `flutter create` du projet (`org` + package name pour le Play Store, ex : `com.edoctortim.fintrack`).
2. Dépendances `pubspec.yaml` :
   - État : `flutter_bloc`, `equatable`, `get_it` (injection), `bloc_concurrency`
   - Local : `hive`, `hive_flutter`, `path_provider`
   - UI/graphes : `fl_chart`, `lottie`, `intl`
   - Notifs : `flutter_local_notifications`, `timezone`
   - Utilitaires : `uuid`, `image_picker` (photo de reçu), `freezed`/`json_serializable` (build_runner)
   - Sécurité : `local_auth` (biométrie), `flutter_secure_storage` (PIN)
3. Arborescence par *feature* (Clean-ish + BLoC) :
   ```
   lib/
     core/        (theme, di, router, constants, utils, formatters FCFA)
     data/        (hive models + adapters, repositories locaux)
     features/
       transactions/   (bloc, ui, widgets)
       budget/
       goals/
       forecast/
       stats/
       settings/
     app.dart  main.dart
   ```
4. Thème clair + **mode sombre**, devise **FCFA** par défaut, routing (`go_router` ou Navigator 2).
5. Initialisation Hive dans `main()` + enregistrement des adapters.

**Livrable :** l'app démarre sur un écran d'accueil vide avec navigation entre les 5 onglets.

---

## Phase 1 — Modèle de données (Hive)

**Objectif :** modèles alignés avec le futur schéma Django (mêmes champs, mêmes IDs UUID pour la sync).

Entités Hive (avec `@HiveType`) :
- **Account** — id, nom, type (espèces / Mobile Money / banque), solde initial, devise
- **Category** — id, nom, icône, couleur, type (revenu/dépense), isCustom
- **Transaction** — id, montant, type, categoryId, accountId, note, date, photoPath?, récurrenceId?
- **RecurringRule** — id, montant, catégorie, compte, fréquence, prochaine échéance
- **Budget** — id, categoryId, mois (YYYY-MM), montant alloué, report/reset
- **Goal** — id, nom, montant cible, montant actuel, date cible?, icône, priorité, statut
- **GoalStatusHistory** — id, goalId, statut (atteint/en cours/manqué), date (pour rejouer le feedback 3.6 même après réinstallation)

Chaque entité porte `updatedAt` + `syncStatus` (local / synced / dirty) pour préparer la sync.

**Livrable :** repositories locaux CRUD + tests unitaires sur les adapters.

---

## Phase 2 — Transactions + Budget (cœur quotidien)

**Transactions (module 3.1)**
- Saisie rapide (bottom sheet : montant, catégorie, compte, note, date)
- Photo de justificatif optionnelle (`image_picker`, stockée localement)
- Catégories prédéfinies (seed) + personnalisées (icône/couleur)
- Transactions récurrentes générées automatiquement au lancement (moteur `RecurringRule`)
- Multi-comptes : soldes séparés + solde consolidé
- Liste + recherche/filtres (période, catégorie, compte, montant)

**Budget (module 3.2)**
- Enveloppes par catégorie et par mois
- Barre de progression **vert → orange → rouge** (seuils configurables)
- Alertes de seuil (branchées sur les notifications en Phase 4)
- Report ou remise à zéro du reste en fin de mois
- Comparaison mois par mois

**Livrable :** on peut saisir des transactions, voir les soldes, définir des budgets et suivre leur consommation, entièrement hors-ligne.

---

## Phase 3 — Objectifs + Moteur de prévision

**Objectifs (module 3.3)**
- Création : nom, montant cible, date cible optionnelle, icône
- Enveloppe virtuelle alimentée par versements manuels/auto
- Calcul du **versement mensuel nécessaire** pour tenir la date
- Objectifs multiples avec priorisation
- **Détection de résultat** à la date cible / sur demande → statut (atteint / en cours / manqué) → déclenche le module Feedback (Phase 5)

**Prévisions (module 3.4) — moteur Dart pur, isolé et testable**
- Projection = solde actuel + revenus récurrents + perceptions de tontine attendues − dépenses récurrentes − cotisations engagées − échéances de dettes − moyenne des dépenses variables (fenêtre glissante 3/6 mois)
- Courbe de projection du solde (1/3/6/12 mois) via `fl_chart`
- **Simulateur d'achat** : montant → date d'atteignabilité (en tenant compte des objectifs engagés)
- Simulation d'impact d'une dépense ponctuelle sur les objectifs

> Le moteur de prévision est écrit **sans dépendance à l'UI** (`core/forecast_engine.dart`) et couvert par des tests unitaires. C'est la décision « calcul 100 % local » du doc (§6).

**Livrable :** objectifs suivis, versement mensuel calculé, courbe de prévision + simulateur d'achat fonctionnels.

---

## Phase 3bis — Cotisations (tontines / njangi) & Dettes

**Objectif :** deux réalités financières très concrètes que la saisie « transaction simple » ne couvre pas bien. Modules 100 % locaux (Hive), branchés sur les notifications (Phase 4) et les prévisions (Phase 3).

### Cotisations / épargne collective (tontine, njangi)
- Création d'une **cotisation** : nom, montant par échéance, fréquence (hebdo / bi-mensuel / mensuel / jours précis), nombre de membres (optionnel), date de début.
- Deux types de jours gérés distinctement :
  - **Jours de cotisation** (« je verse ») → sortie d'argent programmée, rappel avant échéance.
  - **Jours de perception** (« je bouffe la cotisation » — mon tour / le pot) → entrée d'argent programmée, avec le montant attendu.
- Calendrier des échéances : liste des prochaines dates cotise/perçoit, statut (à venir / payé / manqué).
- **Solde net de la tontine** : total cotisé − total perçu, pour savoir où l'utilisateur en est dans le cycle.
- Impact automatique sur les **prévisions** (Phase 3) : les jours de cotisation = dépenses récurrentes engagées ; les jours de perception = revenus attendus, pris en compte dans le simulateur d'achat.
- Génération auto d'une transaction (dépense ou revenu) à chaque échéance validée, rattachée au compte choisi.

### Dettes (je dois / on me doit)
- Création d'une **dette** : sens (je dois / on me doit), créancier ou débiteur (nom libre), montant initial, motif, date de contraction.
- **Plan de remboursement librement défini par l'utilisateur** : échéances à dates choisies (une, plusieurs, ou récurrentes), chacune avec son montant.
- Suivi : montant remboursé, **reste à payer**, prochaine échéance, retard éventuel.
- Chaque remboursement saisi = transaction rattachée (dépense si « je dois », revenu si « on me doit »).
- Intégration prévisions : le reste à payer et les échéances futures pèsent dans la projection de solde et le simulateur d'achat (« en tenant compte des dettes engagées »).
- Notifications : rappel avant chaque échéance de remboursement (Phase 4).

**Nouvelles entités Hive** (à ajouter au modèle de la Phase 1) :
- **Contribution** (tontine) — id, nom, montantParEcheance, fréquence, joursCotisation, joursPerception, montantAttenduPerception, accountId, dateDebut, statut
- **ContributionEvent** — id, contributionId, date, sens (cotise / perçoit), montant, statut (à venir / fait / manqué), transactionId?
- **Debt** — id, sens (je dois / on me doit), contrepartie, montantInitial, motif, dateContraction, resteAPayer, statut
- **DebtRepayment** — id, debtId, dateEcheance, montant, statut (prévu / payé / en retard), transactionId?

**Livrable :** gestion complète des tontines (cotise/bouffe) et des dettes à remboursement libre, avec échéancier, rappels et impact sur les prévisions.

---

## Phase 4 — Notifications locales

Module 3.7, via `flutter_local_notifications` + `timezone` :
- Rappel de saisie quotidienne si aucune transaction du jour
- Alerte de dépassement de budget (branchée sur Phase 2)
- Rappel de contribution à un objectif
- Notification « objectif atteignable dans X mois » (recalcul)
- Rappel avant prélèvement récurrent
- **Rappel de jour de cotisation** (tontine) et **rappel de jour de perception** (« ton tour approche »)
- **Rappel d'échéance de remboursement de dette**
- Déclenchement du feedback (Phase 5) au changement de statut d'objectif

**Livrable :** notifications programmées + gestion des permissions Android 13+ (POST_NOTIFICATIONS).

---

## Phase 5 — Feedback animé (succès / échec) — Lottie

Module 3.6, moment clé d'engagement :
- **Objectif atteint** → célébration plein écran (confettis, scale-up), message personnalisé (nom + montant). Affiché à l'ouverture après détection.
- **Objectif manqué** → animation douce, palette apaisante, message non culpabilisant + proposition d'ajuster date/montant.
- Court (3–5 s), *tap to skip*, **rejouable** depuis l'historique des objectifs (d'où `GoalStatusHistory`).

**Livrable :** deux écrans Lottie déclenchés par les événements du bloc Goals.

---

## Phase 6 — Statistiques & exports

Module 3.5 :
- Répartition des dépenses par catégorie (camembert `fl_chart`)
- Évolution revenus vs dépenses
- Taux d'épargne mensuel
- Comparaisons mois/année précédents
- **Export CSV / PDF** (`csv`, `pdf`/`printing`)

---

## Phase 7 — Sécurité & paramètres

Module 3.8 :
- Verrouillage **PIN + biométrie** (`local_auth`, `flutter_secure_storage`) — donnée financière sensible
- Devise extensible (FCFA par défaut)
- Mode sombre (déjà posé en Phase 0)
- Export/import de données locales

---

## Phase 8 — Backend Django (sauvegarde cloud / premium)

**Objectif :** source de vérité pour la *récupération de compte*, jamais bloquant.
- Django REST Framework + PostgreSQL
- Auth **JWT** (cohérent eDoctor/ClariDoc)
- Endpoints : users, accounts, transactions, budgets, goals, goal_status_history, contributions, contribution_events, debts, debt_repayments
- Endpoint optionnel de prévision serveur (historisation / recalculs lourds)
- **Aucune route touchant à l'argent réel** — uniquement gestion de l'abonnement
- Sync en arrière-plan côté Flutter (`syncStatus` dirty → push/pull, résolution de conflit *last-write-wins* en v1)
- Déploiement Render / Railway

---

## Phase 9 — Abonnement (freemium)

Module 2.2 :
- `in_app_purchase` (Google Play Billing) côté Flutter
- Vérification serveur des reçus (Google Play Developer API) côté Django
- RTDN (Real-time Developer Notifications) pour renouvellements/annulations
- Gating : sync cloud + multi-appareil + export illimité + IA future = **premium**

---

## Phase 10 — Publication Play Store

- Icône, splash, captures, politique de confidentialité (données financières locales)
- Signing (keystore), `flutter build appbundle`
- Fiche Play Console, test interne → production

---

## Points à trancher (repris du doc §7)
- [ ] Prix exact de l'abonnement premium
- [ ] Fonctionnalités IA précises (premium)
- [ ] Règles de résolution de conflits de sync (v1 : last-write-wins ?)
- [ ] Moyens de paiement locaux (carte / Mobile Money) réellement offerts par Play Billing au Cameroun

## Suggestion de séquencement du MVP livrable
**Phases 0 → 1 → 2 → 3 → 3bis → 4 → 5** donnent une app autonome, hors-ligne, publiable et déjà « émotionnellement » complète.
Backend (8), abonnement (9) et stats/export (6) viennent ensuite sans bloquer le lancement.
