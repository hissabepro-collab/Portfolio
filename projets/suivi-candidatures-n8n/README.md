# 🎯 Suivi Candidatures Automatique — N8N + Google Apps Script

Système d'automatisation complet pour suivre ses candidatures d'emploi.
Construit par **Hissa Berton** — Marketing & Data Analytics.

---

## 🚀 Ce que ça fait

### Workflow N8N
- Détecte automatiquement les emails de confirmation de candidature (LinkedIn, Indeed, WTTJ, Apec...)
- Extrait : entreprise, poste, plateforme, ville, contrat, contacts RH
- Remplit Google Sheets automatiquement
- Envoie une notification Telegram instantanée

### Google Apps Script
- **Toutes les 30 min** : analyse les réponses recruteurs avec Gemini AI → met à jour le statut (Entretien/Refus/Offre)
- **Tous les soirs à 20h** : rappel des relances du jour sur Telegram
- **Tous les dimanches à 10h** : bilan hebdomadaire complet sur Telegram

---

## 📋 Prérequis

- [N8N](https://n8n.io) installé en local (`npm install -g n8n`)
- Compte Google (Gmail + Google Sheets)
- Bot Telegram (via [@BotFather](https://t.me/botfather))
- Clé API Gemini gratuite ([aistudio.google.com](https://aistudio.google.com))

---

## ⚙️ Installation

### 1. Configurer le workflow N8N

1. Importe `workflow_public.json` dans N8N
2. Remplace les placeholders :
   - `VOTRE_GOOGLE_SHEET_ID` → l'ID de ton Google Sheet
   - `VOTRE_TELEGRAM_CHAT_ID` → ton Chat ID Telegram
3. Connecte tes credentials Gmail, Google Sheets et Telegram

### 2. Créer le Google Sheet

Crée un Sheet nommé **"Suivi Candidatures"** avec un onglet **"Candidatures"** et ces colonnes dans l'ordre :

| Date | Entreprise | Poste | Plateforme | Type de contrat | Ville | Salaire | Secteur | Statut | Relance prévue | Contact RH — Prénom | Contact RH — Nom | Contact RH — Email | Contact Autre — Prénom | Contact Autre — Nom | Contact Autre — Rôle | Contact Autre — Email | Lien offre | Notes |

### 3. Installer Google Apps Script

1. Dans ton Google Sheet → **Extensions** → **Apps Script**
2. Crée deux fichiers :
   - `suivi_candidatures.gs` → colle le contenu de `suivi_candidatures.gs`
   - `detection_reponses.gs` → colle le contenu de `detection_reponses.gs`
3. Remplis les variables de configuration en haut de `suivi_candidatures.gs` :

```javascript
const TELEGRAM_TOKEN = 'VOTRE_TOKEN_TELEGRAM';
const TELEGRAM_CHAT_ID = 'VOTRE_CHAT_ID';
const SHEET_NAME = 'Candidatures';
```

Et dans `detection_reponses.gs` :

```javascript
const GEMINI_API_KEY = 'VOTRE_CLE_GEMINI';
```

4. Lance `installerTriggers()` puis `installerTriggerReponses()` une seule fois

---

## 📁 Structure du projet

```
├── workflow_public.json        # Workflow N8N (sans données sensibles)
├── suivi_candidatures.gs       # Script rappels + stats
├── detection_reponses.gs       # Script détection réponses recruteurs
├── README.md                   # Ce fichier
└── .gitignore                  # Protection des données sensibles
```

---

## 🔒 Sécurité

Ne jamais committer :
- Ton token Telegram
- Ton Chat ID
- Ton Google Sheet ID
- Ta clé API Gemini

---

## 🛠️ Stack technique

- **N8N** — Orchestration workflow
- **Google Sheets** — Base de données CRM
- **Google Apps Script** — Automatisations 24h/24
- **Gemini AI** — Analyse sémantique des emails
- **Telegram Bot API** — Notifications mobiles

---

## 👤 Auteur

**Hissa Berton** — Master Marketing & Data Analytics  
[LinkedIn](https://www.linkedin.com/in/hissa-berton-28bb11236/) | [Portfolio](https://hissabepro-collab.github.io/Portfolio/)