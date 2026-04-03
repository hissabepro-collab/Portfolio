// ============================================================
// DÉTECTION RÉPONSES RECRUTEURS — Hissa Berton
// Analyse les emails avec Gemini et met à jour le Sheet
// NB: TELEGRAM_TOKEN, TELEGRAM_CHAT_ID, SHEET_NAME 
// sont déjà déclarés dans suivi_candidatures.gs
// ============================================================

const GEMINI_API_KEY = 'AIzaSyAGGRSB66D5yR7cIgK3U0WuIHaJdE_aMww';

// Colonnes Sheet (index 0)
const COL_ENTREPRISE_R = 1;
const COL_POSTE_R = 2;
const COL_STATUT_R = 8;

// ============================================================
// Analyser l'email avec Gemini
// ============================================================
function analyserAvecGemini(sujet, corps) {
  const prompt = 'Tu analyses des emails de réponse à des candidatures emploi. Réponds UNIQUEMENT par un mot parmi : Entretien, Refus, Offre, Autre\n\n- Entretien : le recruteur propose un entretien, appel, visio\n- Refus : candidature refusée, sans suite, profil ne correspond pas\n- Offre : proposition de contrat, embauche confirmée\n- Autre : accusé de réception, demande info, ou email non lié\n\nSujet : ' + sujet + '\n\nCorps : ' + corps.substring(0, 1000) + '\n\nRéponds uniquement : Entretien, Refus, Offre, ou Autre';

  const url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=' + GEMINI_API_KEY;
  
  try {
    const response = UrlFetchApp.fetch(url, {
      method: 'post',
      contentType: 'application/json',
      payload: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { temperature: 0, maxOutputTokens: 10 }
      }),
      muteHttpExceptions: true
    });

    const result = JSON.parse(response.getContentText());
    const text = result.candidates[0].content.parts[0].text.trim();
    
    if (text.includes('Entretien')) return 'Entretien';
    if (text.includes('Refus')) return 'Refus';
    if (text.includes('Offre')) return 'Offre';
    return 'Autre';
  } catch(e) {
    Logger.log('Erreur Gemini: ' + e.toString());
    return 'Autre';
  }
}

// ============================================================
// Trouver la ligne dans le Sheet
// ============================================================
function trouverLigneEntreprise(sheet, expediteur, sujet) {
  const data = sheet.getDataRange().getValues();
  const domain = (expediteur.match(/@([\w.-]+)/) || ['',''])[1].toLowerCase();
  
  let bestMatch = -1;
  let bestScore = 0;
  
  for (let i = 1; i < data.length; i++) {
    const row = data[i];
    const entreprise = (row[COL_ENTREPRISE_R] || '').toLowerCase();
    const statut = (row[COL_STATUT_R] || '').toString().trim();
    
    if (statut === 'Refus' || statut === 'Offre') continue;
    if (!entreprise || entreprise === '— a completer') continue;
    
    let score = 0;
    const mots = entreprise.split(' ').filter(m => m.length > 3);
    mots.forEach(mot => {
      if (domain.includes(mot)) score += 3;
      if (sujet.toLowerCase().includes(mot)) score += 2;
      if (expediteur.toLowerCase().includes(mot)) score += 2;
    });
    
    if (score > bestScore) {
      bestScore = score;
      bestMatch = i + 1;
    }
  }
  
  return bestScore >= 2 ? bestMatch : -1;
}

// ============================================================
// Fonction principale — toutes les 30 minutes
// ============================================================
function detecterReponsesRecruteurs() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET_NAME);
  
  const threads = GmailApp.search('is:unread newer_than:1d -from:linkedin -from:indeed -from:welcometothejungle -from:apec -from:noreply -from:no-reply');
  
  if (threads.length === 0) return;
  
  threads.forEach(function(thread) {
    const messages = thread.getMessages();
    const msg = messages[messages.length - 1];
    
    const sujet = msg.getSubject() || '';
    const corps = msg.getPlainBody() || '';
    const expediteur = msg.getFrom() || '';
    
    if (corps.length < 50) return;
    
    const statut = analyserAvecGemini(sujet, corps);
    if (statut === 'Autre') return;
    
    const ligne = trouverLigneEntreprise(sheet, expediteur, sujet);
    
    if (ligne === -1) {
      sendTelegram('📬 *Réponse recruteur détectée !*\n\n📧 De : ' + expediteur + '\n📋 Sujet : ' + sujet + '\n🎯 Statut : *' + statut + '*\n\n⚠️ Entreprise non trouvée dans le Sheet.\nMets à jour manuellement !');
      return;
    }
    
    const data = sheet.getDataRange().getValues();
    const row = data[ligne - 1];
    const entreprise = row[COL_ENTREPRISE_R];
    const poste = row[COL_POSTE_R];
    const ancienStatut = (row[COL_STATUT_R] || '').toString();
    
    if (ancienStatut === 'Offre') return;
    
    sheet.getRange(ligne, COL_STATUT_R + 1).setValue(statut);
    
    const emoji = statut === 'Entretien' ? '🎉' : statut === 'Refus' ? '😔' : '🏆';
    sendTelegram(emoji + ' *Réponse recruteur !*\n\n🏢 *' + entreprise + '*\n💼 ' + poste + '\n\n📊 Statut → *' + statut + '*\n📧 De : ' + expediteur);
    
    thread.markRead();
  });
}

// ============================================================
// Installer le trigger — UNE SEULE FOIS
// ============================================================
function installerTriggerReponses() {
  ScriptApp.getProjectTriggers().forEach(function(t) {
    if (t.getHandlerFunction() === 'detecterReponsesRecruteurs') {
      ScriptApp.deleteTrigger(t);
    }
  });
  
  ScriptApp.newTrigger('detecterReponsesRecruteurs')
    .timeBased()
    .everyMinutes(30)
    .create();
    
  Logger.log('✅ Trigger installé — toutes les 30 minutes');
}
