/*===========================================================================================================
  PROJET  : Analyse de la Sur- et Sous-Sollicitation Client
  AUTEUR  : [Votre nom]
  DATE    : 2026
  OBJECTIF: Etudier les patterns de sollicitation commerciale pour segmenter la clientele
            et piloter la pression marketing de maniere data-driven.
            Le projet vise a identifier les clients sous-touches et sur-sollicites,
            a en dresser un portrait socio-demographique et comportemental,
            et a evaluer leur niveau d'equipement bancaire.

  ENVIRONNEMENT : SAS OnDemand for Academics (SAS Studio)

  TABLES EN ENTREE (CSV a importer) :
    - PERIMETRE_SOLL     : Perimetre des clients sollicites avec typologies et compteurs de comm
    - SC_DATAMART_PART   : Data mart partenaire (CSP, segment, revenus, DAV...)
    - TA_BASMKG_PARTENAIRE : Base marketing individuelle (coordonnees, joignabilite, CSP...)
    - SYNTH_PART_QUOTD   : Synthese partenaire quotidienne (optin/optout email)
    - EQUIPEMENT         : Table pre-calculee d'equipement produit par partenaire

  STRUCTURE DU CODE :
    IMPORTS   : Chargement des 5 CSV dans la bibliotheque WORK
    PARTIE 1  : Classement des clients par nombre et type de sollicitations
    PARTIE 2  : Etude approfondie de la classe des comm directes (0-12)
    PARTIE 3  : Macro reutilisable d'analyse par segment de sollicitation
    PARTIE 4  : Analyses globales, graphiques comparatifs, focus epargne/assurance

  NOTE : La table EQUIPEMENT est directement importee depuis le CSV pre-calcule
         (resultat d'une extraction DWH). Elle ne necessite pas de reconstruction SQL.
===========================================================================================================*/


/*===========================================================================================================
  SECTION 0 - CONFIGURATION DES CHEMINS D'ACCES
  --> Adapter le chemin ci-dessous a votre espace personnel SAS OnDemand for Academics.
      Dans SAS Studio, allez dans "Fichiers et dossiers" (volet gauche), faites un clic droit
      sur votre dossier cible, et choisissez "Copier le chemin" pour obtenir le chemin exact.
      Exemple typique : /home/u12345678/mon_projet/
===========================================================================================================*/

%let chemin_csv = /home/u64481905/;


/*===========================================================================================================
  SECTION 1 - IMPORT DES TABLES CSV DANS LA BIBLIOTHEQUE WORK
  Chaque fichier CSV doit etre depose dans le dossier indique par &chemin_csv.
  La procedure PROC IMPORT detecte automatiquement le separateur virgule (DBMS=CSV).
  GETNAMES=YES recupere les noms de colonnes depuis la premiere ligne du fichier.
===========================================================================================================*/

/* --- Import PERIMETRE_SOLL ---
   Contient : typologies de contact (digital/intrusif), compteurs de sollicitations
   par canal et flag de joignabilite */
proc import
    datafile="&chemin_csv.PERIMETRE_SOLL.csv"
    out=WORK.PERIMETRE_SOLL
    dbms=csv
    replace;
    getnames=yes;
    guessingrows=200;
run;

/* --- Import SC_DATAMART_PART ---
   Contient : CSP, segment EMACO, note scoring (MIRE/Funivers),
   DAV actifs, mouvements crediteurs, soldes moyens */
proc import
    datafile="&chemin_csv.SC_DATAMART_PART.csv"
    out=WORK.SC_DATAMART_PART
    dbms=csv
    replace;
    getnames=yes;
    guessingrows=200;
run;

/* --- Import TA_BASMKG_PARTENAIRE ---
   Contient : donnees individuelles de la base marketing (civilite, age, LIBPCS,
   email, telephone, rattachement agence/secteur, joignabilite, flags refractaires) */
proc import
    datafile="&chemin_csv.TA_BASMKG_PARTENAIRE.csv"
    out=WORK.TA_BASMKG_PARTENAIRE
    dbms=csv
    replace;
    getnames=yes;
    guessingrows=200;
run;

/* --- Import SYNTH_PART_QUOTD ---
   Contient : synthese quotidienne partenaire, notamment le statut optin/optout/neutre
   sur les communications electroniques (MLS) utilise pour filtrer la cible finale */
proc import
    datafile="&chemin_csv.SYNTH_PART_QUOTD.csv"
    out=WORK.SYNTH_PART_QUOTD
    dbms=csv
    replace;
    getnames=yes;
    guessingrows=200;
run;

/* --- Import EQUIPEMENT ---
   Resultat pre-calcule de l'extraction DWH : une ligne par (partenaire x famille produit).
   Contient : ID_PART, nb_edc (nb equipements), CD_FAM_PROD_10 (famille produit RGP10001 a RGP10006).
   Cette table est directement utilisee telle quelle dans la partie 7 sans recalcul. */
proc import
    datafile="&chemin_csv.EQUIPEMENT.csv"
    out=WORK.EQUIPEMENT
    dbms=csv
    replace;
    getnames=yes;
    guessingrows=200;
run;

/* --- Construction de la table MTT (data mart partenaire reduit) ---
   On renomme idpart_calcule en ID_PART pour la coherence avec les autres tables.
   On selectionne uniquement les variables utiles a l'analyse comportementale et scoring. */
proc sql;
    create table WORK.mtt as
    select
         idpart_calcule
        ,LI_CSP
        ,li_seg_emaco
        ,top_pays_lgt_fr
        ,note_mire
        ,note_Funivers
        ,TOP_CLI_PORTEF
        ,NB_DAV_ACTIF
        ,MT_MVT_CRDTR_DMLI_DAV_12M
        ,SLD_MOY_MENSUEL_DAV_12M
    from WORK.SC_DATAMART_PART
    ;
quit;


/*===========================================================================================================
  PARTIE 1 - CLASSIFICATION DES CLIENTS PAR NIVEAU DE SOLLICITATION
  On cree des classes de clients (1 a 6) selon le nombre de communications recues
  sur 4 axes : globales, comm directes, comm directes commerciales, commerciales.
  Objectif : identifier la repartition de la pression commerciale sur notre portefeuille.
===========================================================================================================*/



DATA work.clients_classes_1;
    set WORK.PERIMETRE_SOLL (Keep=IDPART_CALCULE TP_DIGITAL TP_DIGITAL_2 TP_INTRUSIF TP_INTRUSIF_2 PK_NO_CONTACT NB_SOLLICITATION);
    if      NB_SOLLICITATION = 0                         then classe = 1;
    else if NB_SOLLICITATION >= 1 and NB_SOLLICITATION <= 6            then classe = 2;
    else if NB_SOLLICITATION >= 7 and NB_SOLLICITATION <= 12           then classe = 3;
    else if NB_SOLLICITATION >= 13 and NB_SOLLICITATION <= 24           then classe = 4;
    else if NB_SOLLICITATION >= 25 and NB_SOLLICITATION <= 36           then classe = 5;
    else if NB_SOLLICITATION > 36                        then classe = 6;
    else classe = .;
run;

proc sort data=work.clients_classes_1; by classe; run;


PROC SQL;
    CREATE TABLE WORK.NB_CLASSE_1 AS
    SELECT
         classe
        ,Count(*) as nb_personnes
        ,CALCULATED nb_personnes / (SELECT COUNT(*) FROM work.clients_classes_1) AS pct FORMAT=percent8.2
    FROM WORK.CLIENTS_CLASSES_1
    GROUP BY classe
    ;
quit;



DATA work.clients_classes_2;
    set WORK.PERIMETRE_SOLL (Keep=IDPART_CALCULE TP_DIGITAL TP_DIGITAL_2 TP_INTRUSIF TP_INTRUSIF_2 PK_NO_CONTACT NB_COMM_DIRECTE);
    if      NB_COMM_DIRECTE = 0                          then classe = 1;
    else if NB_COMM_DIRECTE >= 1 and NB_COMM_DIRECTE <= 6             then classe = 2;
    else if NB_COMM_DIRECTE >= 7 and NB_COMM_DIRECTE <= 12            then classe = 3;
    else if NB_COMM_DIRECTE >= 13 and NB_COMM_DIRECTE <= 24            then classe = 4;
    else if NB_COMM_DIRECTE >= 25 and NB_COMM_DIRECTE <= 36            then classe = 5;
    else if NB_COMM_DIRECTE > 36                         then classe = 6;
    else classe = .;
run;

proc sort data=work.clients_classes_2; by classe; run;

PROC SQL;
    CREATE TABLE WORK.NB_CLASSE_2 AS
    SELECT
         classe
        ,Count(*) as nb_personnes
        ,CALCULATED nb_personnes / (SELECT COUNT(*) FROM work.clients_classes_2) AS pct FORMAT=percent8.2
    FROM WORK.CLIENTS_CLASSES_2
    GROUP BY classe
    ;
quit;



DATA work.clients_classes_3;
    set WORK.PERIMETRE_SOLL (Keep=IDPART_CALCULE TP_DIGITAL TP_DIGITAL_2 TP_INTRUSIF TP_INTRUSIF_2 PK_NO_CONTACT NB_DIRECT_COMMERCIAL);
    if      NB_DIRECT_COMMERCIAL = 0                     then classe = 1;
    else if NB_DIRECT_COMMERCIAL >= 1 and NB_DIRECT_COMMERCIAL <= 6        then classe = 2;
    else if NB_DIRECT_COMMERCIAL >= 7 and NB_DIRECT_COMMERCIAL <= 12       then classe = 3;
    else if NB_DIRECT_COMMERCIAL >= 13 and NB_DIRECT_COMMERCIAL <= 24       then classe = 4;
    else if NB_DIRECT_COMMERCIAL >= 25 and NB_DIRECT_COMMERCIAL <= 36       then classe = 5;
    else if NB_DIRECT_COMMERCIAL > 36                    then classe = 6;
    else classe = .;
run;

proc sort data=work.clients_classes_3; by classe; run;

PROC SQL;
    CREATE TABLE WORK.NB_CLASSE_3 AS
    SELECT
         classe
        ,Count(*) as nb_personnes
        ,CALCULATED nb_personnes / (SELECT COUNT(*) FROM work.clients_classes_3) AS pct FORMAT=percent8.2
    FROM WORK.CLIENTS_CLASSES_3
    GROUP BY classe
    ;
quit;



DATA work.clients_classes_4;
    set WORK.PERIMETRE_SOLL (Keep=IDPART_CALCULE TP_DIGITAL TP_DIGITAL_2 TP_INTRUSIF TP_INTRUSIF_2 PK_NO_CONTACT NB_COMMERCIAL);
    if      NB_COMMERCIAL = 0                            then classe = 1;
    else if NB_COMMERCIAL >= 1 and NB_COMMERCIAL <= 6               then classe = 2;
    else if NB_COMMERCIAL >= 7 and NB_COMMERCIAL <= 12              then classe = 3;
    else if NB_COMMERCIAL >= 13 and NB_COMMERCIAL <= 24              then classe = 4;
    else if NB_COMMERCIAL >= 25 and NB_COMMERCIAL <= 36              then classe = 5;
    else if NB_COMMERCIAL > 36                           then classe = 6;
    else classe = .;
run;

proc sort data=work.clients_classes_4; by classe; run;

PROC SQL;
    CREATE TABLE WORK.NB_CLASSE_4 AS
    SELECT
         classe
        ,Count(*) as nb_personnes
        ,CALCULATED nb_personnes / (SELECT COUNT(*) FROM work.clients_classes_4) AS pct FORMAT=percent8.2
    FROM WORK.CLIENTS_CLASSES_4
    GROUP BY classe
    ;
quit;


/* --- ANALYSE PONCTUELLE : Refonte comm commerciales avec echelle simplifiee ---
   Demande ad hoc pour une lecture plus operationnelle : 4 classes uniquement
   (Aucune / 1 comm / 2-3 comm / Plus de 3 comm) */
DATA work.clients_classes_4_PONCTUEL;
    set WORK.PERIMETRE_SOLL (Keep=IDPART_CALCULE TP_DIGITAL TP_DIGITAL_2 TP_INTRUSIF TP_INTRUSIF_2 PK_NO_CONTACT NB_COMMERCIAL);
    if      NB_COMMERCIAL = 0   then classe = 1;
    else if NB_COMMERCIAL = 1   then classe = 2;
    else if NB_COMMERCIAL <= 3  then classe = 3;
    else if NB_COMMERCIAL > 3   then classe = 4;
    else classe = .;
run;

proc sort data=work.clients_classes_4_PONCTUEL; by classe; run;

PROC SQL;
    CREATE TABLE WORK.NB_CLASSE_4_PONCTUEL AS
    SELECT
         classe
        ,Count(*) as nb_personnes
        ,CALCULATED nb_personnes / (SELECT COUNT(*) FROM work.clients_classes_4_PONCTUEL) AS pct FORMAT=percent8.2
    FROM WORK.CLIENTS_CLASSES_4_PONCTUEL
    GROUP BY classe
    ;
quit;


PROC SQL;
    CREATE TABLE WORK.FINAL_V1_PONCTUEL AS
    SELECT
        case
            when classe=1 then "0 Sollicitation"
            when classe=2 then "1 Sollicitation"
            when classe=3 then "2 a 3 Sollicitations"
            when classe=4 then "Plus de 3 sollicitations"
            else ""
        end as classe length=25
        ,nb_personnes
        ,pct
    FROM WORK.NB_CLASSE_4_PONCTUEL
    ;
quit;


PROC TRANSPOSE data=WORK.FINAL_V1_PONCTUEL out=WORK.FINAL_V2_PONCTUEL (drop=_name_);
    id classe;
    var PCT;
run;



/* --- CONSOLIDATION DES 4 AXES DE SOLLICITATION EN TABLE LONGUE ---
   Objectif : preparer un tableau comparatif des 4 types de comm dans un meme graphique */
DATA work.kpi_long;
    length kpi $25;
    set
        work.nb_classe_1 (in=a)
        work.nb_classe_2 (in=b)
        work.nb_classe_3 (in=c)
        work.nb_classe_4 (in=d)
    ;
    if      a then kpi = "COMM GLOBALES";
    else if b then kpi = "COMM DIRECTES";
    else if c then kpi = "COMM DIR. COMMERCIALES";
    else if d then kpi = "COMM COMMERCIALES";
run;

proc sort data=work.kpi_long; by kpi; run;


PROC SQL;
    CREATE TABLE WORK.FINAL_V1 AS
    SELECT
        case
            when classe=1 then "0"
            when classe=2 then "1-6"
            when classe=3 then "7-12"
            when classe=4 then "13-24"
            when classe=5 then "25-36"
            when classe=6 then "36+"
            else ""
        end as echelle length=10
        ,kpi
        ,pct
    FROM work.kpi_long
    ;
quit;


PROC TRANSPOSE data=WORK.FINAL_V1 out=WORK.FINAL_V2 (drop=_name_);
    by kpi;
    id echelle;
    var PCT;
run;

/* --- GRAPHIQUE : Histogrammes de sollicitation par type de communication ---
   On retransforme FINAL_V1 en format long directement pour eviter les name literals
   (colonnes nommees '0', '1-6'... incompatibles avec PROC TRANSPOSE dans SAS ODA) */
PROC SORT data=WORK.FINAL_V1; by kpi; run;


DATA WORK.Graph_Com;
    set WORK.FINAL_V1;
    rename echelle=classe;
run;

PROC SORT data=WORK.Graph_Com; by KPI; run;

ODS GRAPHICS / RESET WIDTH=800px HEIGHT=500px;
PROC SGPLOT data=WORK.Graph_Com;
    by kpi;
    Title "Repartition de la pression commerciale par type de communication";
    vbarparm category=classe response=pct / datalabel;
    YAXIS label="Pourcentage";
    XAXIS label="Classe de sollicitation";
run;
title;


/*===========================================================================================================
  PARTIE 2 - ANALYSE APPROFONDIE DU SEGMENT COMM DIRECTES (0-12 communications)
  On cible les clients ayant recu entre 0 et 12 communications directes,
  c'est-a-dire le cur de notre enjeu : les sous-sollicites et les moderement sollicites.
  On les enrichit avec les donnees marketing, comportementales et l'optin email.
===========================================================================================================*/

/* --- TABLE REFERENCE EMAILABILITE ---
   Construction d'une table pour analyser la part d'emails valides/invalides dans la cible.
   Utile pour evaluer la joignabilite digitale reelle de notre population d'interet.
   Condition : filtre sur 0-12 comm directes */
PROC SQL;
    CREATE TABLE WORK.TABLE_R_EMAIL AS
    SELECT
         a.*
        ,b.NOMPART, b.CIVILITE, b.PRENOM, b.NOM, b.AGE, b.DTCREA
        ,b.IDCLI_CALCULE, b.IDCLI, b.Avec_Contrat, b.idtcc, b.CTPART, b.ctgppe, b.leader
        ,b.CPTE_BOREAL, b.CPTE_DE, b.IDMARC, b.LIBMARC, b.IDSECO, b.LIBSECO
        ,b.IDSSGMA, b.LIBSSGMA, b.DIRCO_GEST_PARTEN, b.LIBDIRCO_GEST_PARTEN
        ,b.SECTEUR_GEST_PARTEN, b.LIBSECTEUR_GEST_PARTEN, b.AGP_GEST_PARTEN, b.LIBAGP_GEST_PARTEN
        ,b.PDV_GEST_PARTEN, b.LIBPDV_GEST_PARTEN, b.IDRESPPDV_GEST, b.RESPPDV_GEST
        ,b.SALARIE, b.CDPCSP, b.LIBPCS, b.CDACTIVITE, b.LIBACTIVITE, b.NOSIRE
        ,b.N1PRETS, b.M1PRETS, b.M2HABITA, b.M2CONSO, b.IDPORT
        ,b.IDESPTF_CC, b.LIBESPTF_CC, b.e_messagerie
        ,b.DIRCO_PTF_CC, b.LIBDIRCO_PTF_CC, b.SECTEUR_PTF_CC, b.LIBSECTEUR_PTF_CC
        ,b.AGP_PTF_CC, b.LIBAGP_PTF_CC, b.PDV_PTF_CC, b.LIBPDV_PTF_CC
        ,b.IDRESPPDV, b.RESPPDV, b.EXCLU_LUC, b.SITPART, b.BALE2
        ,b.REFRAC_COURRIER, b.REFRAC_EMAIL, b.OPTOUT_EMAIL
        ,b.REFRAC_TELPRINCIPAL, b.REFRAC_TELPROF, b.REFRAC_TELPOR
        ,b.REFRAC_SMS, b.OPTOUT_SMS, b.RCO, b.RCX, b.EXCLUSSIEGE
        ,b.TELPRINCIPAL, b.INVALID_TELPRINCIPAL, b.TELPRO, b.INVALID_TELPRO
        ,b.TELPORT, b.INVALID_TELPORT, b.EMAIL, b.INVALID_EMAIL
        ,b.OBLIGBDF, b.DECEDE, b.INCAPABLE, b.NONRESIDENTFISCAL
        ,b.TELPRINCIPAL_ETR, b.TELPRO_ETR, b.TELPORT_ETR, b.PIEGE
        ,b.Avec_Contrat_Fdc, b.Avec_Contrat_Tous, b.Note, b.Top_Retail_Corporate
        ,b.BREXIT, b.BLOCTEL, b.REFRCTR_TS_CNX
        ,c.LI_CSP, c.li_seg_emaco, c.top_pays_lgt_fr
        ,c.note_mire, c.note_Funivers, c.TOP_CLI_PORTEF
        ,c.NB_DAV_ACTIF, c.MT_MVT_CRDTR_DMLI_DAV_12M, c.SLD_MOY_MENSUEL_DAV_12M
        ,case when c.MT_MVT_CRDTR_DMLI_DAV_12M <= 0 then 1 else 0 end as top_rev_nul

    FROM WORK.CLIENTS_CLASSES_2      as a
    LEFT JOIN WORK.TA_BASMKG_PARTENAIRE as b ON a.IDPART_CALCULE = b.IDPART_CALCULE
    LEFT JOIN WORK.mtt               as c ON b.IDPART_CALCULE = c.idpart_calcule
    WHERE a.NB_COMM_DIRECTE between 0 AND 12
    ;
quit;

/* --- TABLE REFERENCE JOIGNABILITE ---
   On filtre les emails invalides pour ne conserver que les clients joignables par email.
   Cette table sera la base de tous les calculs de profiling socio-demographique. */
PROC SQL;
    CREATE TABLE WORK.TABLE_R AS
    SELECT
         a.*
        ,b.NOMPART, b.CIVILITE, b.PRENOM, b.NOM, b.AGE, b.DTCREA
        ,b.IDCLI_CALCULE, b.IDCLI, b.Avec_Contrat, b.idtcc, b.CTPART, b.ctgppe, b.leader
        ,b.CPTE_BOREAL, b.CPTE_DE, b.IDMARC, b.LIBMARC, b.IDSECO, b.LIBSECO
        ,b.IDSSGMA, b.LIBSSGMA, b.DIRCO_GEST_PARTEN, b.LIBDIRCO_GEST_PARTEN
        ,b.SECTEUR_GEST_PARTEN, b.LIBSECTEUR_GEST_PARTEN, b.AGP_GEST_PARTEN, b.LIBAGP_GEST_PARTEN
        ,b.PDV_GEST_PARTEN, b.LIBPDV_GEST_PARTEN, b.IDRESPPDV_GEST, b.RESPPDV_GEST
        ,b.SALARIE, b.CDPCSP, b.LIBPCS, b.CDACTIVITE, b.LIBACTIVITE, b.NOSIRE
        ,b.N1PRETS, b.M1PRETS, b.M2HABITA, b.M2CONSO, b.IDPORT
        ,b.IDESPTF_CC, b.LIBESPTF_CC, b.e_messagerie
        ,b.DIRCO_PTF_CC, b.LIBDIRCO_PTF_CC, b.SECTEUR_PTF_CC, b.LIBSECTEUR_PTF_CC
        ,b.AGP_PTF_CC, b.LIBAGP_PTF_CC, b.PDV_PTF_CC, b.LIBPDV_PTF_CC
        ,b.IDRESPPDV, b.RESPPDV, b.EXCLU_LUC, b.SITPART, b.BALE2
        ,b.REFRAC_COURRIER, b.REFRAC_EMAIL, b.OPTOUT_EMAIL
        ,b.REFRAC_TELPRINCIPAL, b.REFRAC_TELPROF, b.REFRAC_TELPOR
        ,b.REFRAC_SMS, b.OPTOUT_SMS, b.RCO, b.RCX, b.EXCLUSSIEGE
        ,b.TELPRINCIPAL, b.INVALID_TELPRINCIPAL, b.TELPRO, b.INVALID_TELPRO
        ,b.TELPORT, b.INVALID_TELPORT, b.EMAIL, b.INVALID_EMAIL
        ,b.OBLIGBDF, b.DECEDE, b.INCAPABLE, b.NONRESIDENTFISCAL
        ,b.TELPRINCIPAL_ETR, b.TELPRO_ETR, b.TELPORT_ETR, b.PIEGE
        ,b.Avec_Contrat_Fdc, b.Avec_Contrat_Tous, b.Note, b.Top_Retail_Corporate
        ,b.BREXIT, b.BLOCTEL, b.REFRCTR_TS_CNX
        ,c.LI_CSP, c.li_seg_emaco, c.top_pays_lgt_fr
        ,c.note_mire, c.note_Funivers, c.TOP_CLI_PORTEF
        ,c.NB_DAV_ACTIF, c.MT_MVT_CRDTR_DMLI_DAV_12M, c.SLD_MOY_MENSUEL_DAV_12M
        ,case when c.MT_MVT_CRDTR_DMLI_DAV_12M <= 0 then 1 else 0 end as top_rev_nul
    FROM WORK.CLIENTS_CLASSES_2      as a
    LEFT JOIN WORK.TA_BASMKG_PARTENAIRE as b ON a.IDPART_CALCULE = b.IDPART_CALCULE
    LEFT JOIN WORK.mtt               as c ON b.IDPART_CALCULE = c.idpart_calcule
    WHERE a.NB_COMM_DIRECTE between 0 AND 12
      AND (INVALID_EMAIL = 0 OR INVALID_EMAIL IS NULL)
    ;
quit;

/* --- RECUPERATION DU STATUT OPTIN/OPTOUT EMAIL (NEUTRE = '0') ---
   On va chercher dans la synthese partenaire quotidienne le statut de consentement email.
   Seuls les clients "neutres" (CD_OPTIN_OPTOUT_MLS = 0) peuvent etre contactes
   sans contrainte particuliere dans notre dispositif. */
PROC SQL;
    CREATE TABLE WORK.OPTIN_NEUTRE AS
    SELECT
         t1.ID_PART
        ,t1.CD_OPTIN_OPTOUT_MLS
    FROM WORK.SYNTH_PART_QUOTD t1
    WHERE t1.ID_PART in (select IDPART_CALCULE from WORK.TABLE_R)
    ;
quit;

/* --- TABLE REFERENCE FINALE ---
   Croisement avec le statut optin : on retient uniquement les clients neutres.
   C'est la table socle de toute l'analyse de profiling. */
PROC SQL;
    CREATE TABLE WORK.TABLE_REFERENCE AS
    SELECT
         a.*
        ,b.CD_OPTIN_OPTOUT_MLS
    FROM WORK.TABLE_R      as a
    LEFT JOIN WORK.OPTIN_NEUTRE as b ON a.IDPART_CALCULE = b.ID_PART
    WHERE b.CD_OPTIN_OPTOUT_MLS = 0
    ;
quit;


/* --- ANALYSE AGE (hors macro - premiere exploration) ---
   Construction des tranches d'age pour avoir une premiere lecture demographique */
PROC SQL;
    CREATE TABLE WORK.AGE_INIT as
    SELECT
        case
            when age between 18 and 30 then "18-30"
            when age between 31 and 45 then "31-45"
            when age between 46 and 60 then "46-60"
            when age between 60 and 75 then "60-75"
            when age > 75              then "75+"
            else ""
        end as tranche_age length=10
    FROM WORK.TABLE_REFERENCE
    GROUP BY tranche_age
    ORDER BY tranche_age
    ;
quit;


PROC SQL;
    CREATE TABLE WORK.tableau_age_init as
    SELECT
         tranche_age
        ,count(*)                                                AS nb_personnes
        ,count(*) / (SELECT COUNT(*) FROM WORK.AGE_INIT)        AS pct FORMAT=percent8.2
    from WORK.AGE_INIT
    GROUP BY tranche_age
    ORDER BY tranche_age
    ;
quit;


proc univariate data=WORK.TABLE_REFERENCE;
    title "Statistiques descriptives - AGE - Cible comm directes 0-12";
    var AGE;
run;
title;


proc univariate data=WORK.TABLE_REFERENCE;
    title "Statistiques descriptives - MOUVEMENTS CREDITEURS - Cible comm directes 0-12";
    var MT_MVT_CRDTR_DMLI_DAV_12M;
run;
title;


proc sql;
    create table WORK.rev_init as
    select
         top_rev_nul
        ,count(distinct IDPART_CALCULE)                                        as nb_pp
        ,count(distinct IDPART_CALCULE) / (SELECT COUNT(*) FROM WORK.TABLE_REFERENCE) as pct FORMAT=percent8.2
    from WORK.TABLE_REFERENCE
    where LIBPCS not in ('ELEVES-ETUDIANTS','SS ACT.-60A-SF RETRA','SS ACT.+60A-SF RETRA')
    group by top_rev_nul
    ;
quit;

proc transpose data=WORK.rev_init out=WORK.tr_rev_init (drop=_name_);
    id top_rev_nul; var nb_pp;
run;


/*===========================================================================================================
  PARTIE 3 - MACRO D'ANALYSE PAR SEGMENT DE SOLLICITATION
  Cette macro permet de relancer l'analyse complete pour n'importe quelle tranche
  de NB_COMM_DIRECTE sans dupliquer le code. Elle produit l'ensemble des KPIs
  (age, revenus, CSP, segment, DAV, note univers de besoin, equipement produit)
  et les graphiques associes pour le segment souhaite.

  PARAMETRES :
    condition : condition WHERE filtrant la tranche (ex : NB_COMM_DIRECTE between 1 and 6)
    libele    : label pour les titres de graphiques (ex : 1-6)
===========================================================================================================*/

%macro ANALYSE_SEGMENT(condition=, libele=);
/* ================================================
   MACRO : ANALYSE PAR TRANCHE DE COMM DIRECTES
   Parametre condition : filtre WHERE a appliquer
   Parametre libele    : label affiche dans les titres
   ================================================ */

/* --- CONSTRUCTION DE LA TABLE DE REFERENCE POUR LE SEGMENT ---
   On reconstruit la table enrichie pour le segment cible.
   On filtre les emails invalides pour garantir la joignabilite digitale. */
PROC SQL;
    CREATE TABLE WORK.TABLE_R AS
    SELECT
         a.*
        ,b.NOMPART, b.CIVILITE, b.PRENOM, b.NOM, b.AGE, b.DTCREA
        ,b.IDCLI_CALCULE, b.IDCLI, b.Avec_Contrat, b.idtcc, b.CTPART, b.ctgppe, b.leader
        ,b.CPTE_BOREAL, b.CPTE_DE, b.IDMARC, b.LIBMARC, b.IDSECO, b.LIBSECO
        ,b.IDSSGMA, b.LIBSSGMA, b.DIRCO_GEST_PARTEN, b.LIBDIRCO_GEST_PARTEN
        ,b.SECTEUR_GEST_PARTEN, b.LIBSECTEUR_GEST_PARTEN, b.AGP_GEST_PARTEN, b.LIBAGP_GEST_PARTEN
        ,b.PDV_GEST_PARTEN, b.LIBPDV_GEST_PARTEN, b.IDRESPPDV_GEST, b.RESPPDV_GEST
        ,b.SALARIE, b.CDPCSP, b.LIBPCS, b.CDACTIVITE, b.LIBACTIVITE, b.NOSIRE
        ,b.N1PRETS, b.M1PRETS, b.M2HABITA, b.M2CONSO, b.IDPORT
        ,b.IDESPTF_CC, b.LIBESPTF_CC, b.e_messagerie
        ,b.DIRCO_PTF_CC, b.LIBDIRCO_PTF_CC, b.SECTEUR_PTF_CC, b.LIBSECTEUR_PTF_CC
        ,b.AGP_PTF_CC, b.LIBAGP_PTF_CC, b.PDV_PTF_CC, b.LIBPDV_PTF_CC
        ,b.IDRESPPDV, b.RESPPDV, b.EXCLU_LUC, b.SITPART, b.BALE2
        ,b.REFRAC_COURRIER, b.REFRAC_EMAIL, b.OPTOUT_EMAIL
        ,b.REFRAC_TELPRINCIPAL, b.REFRAC_TELPROF, b.REFRAC_TELPOR
        ,b.REFRAC_SMS, b.OPTOUT_SMS, b.RCO, b.RCX, b.EXCLUSSIEGE
        ,b.TELPRINCIPAL, b.INVALID_TELPRINCIPAL, b.TELPRO, b.INVALID_TELPRO
        ,b.TELPORT, b.INVALID_TELPORT, b.EMAIL, b.INVALID_EMAIL
        ,b.OBLIGBDF, b.DECEDE, b.INCAPABLE, b.NONRESIDENTFISCAL
        ,b.TELPRINCIPAL_ETR, b.TELPRO_ETR, b.TELPORT_ETR, b.PIEGE
        ,b.Avec_Contrat_Fdc, b.Avec_Contrat_Tous, b.Note, b.Top_Retail_Corporate
        ,b.BREXIT, b.BLOCTEL, b.REFRCTR_TS_CNX
        ,c.LI_CSP, c.li_seg_emaco, c.top_pays_lgt_fr
        ,c.note_mire, c.note_Funivers, c.TOP_CLI_PORTEF
        ,c.NB_DAV_ACTIF, c.MT_MVT_CRDTR_DMLI_DAV_12M, c.SLD_MOY_MENSUEL_DAV_12M
        ,case when c.MT_MVT_CRDTR_DMLI_DAV_12M <= 0 then 1 else 0 end as top_rev_nul
    FROM WORK.CLIENTS_CLASSES_2      as a
    LEFT JOIN WORK.TA_BASMKG_PARTENAIRE as b ON a.IDPART_CALCULE = b.IDPART_CALCULE
    LEFT JOIN WORK.mtt               as c ON b.IDPART_CALCULE = c.idpart_calcule
    WHERE &condition.
      AND (INVALID_EMAIL = 0 OR INVALID_EMAIL IS NULL)
    ;
quit;

/* --- TABLE EMAILABILITE (pour information, sans filtre email) ---
   Permet de comparer la part de joignables vs non-joignables dans le segment */
PROC SQL;
    CREATE TABLE WORK.TABLE_R_EMAIL AS
    SELECT
         a.*
        ,b.NOMPART, b.CIVILITE, b.PRENOM, b.NOM, b.AGE, b.DTCREA
        ,b.IDCLI_CALCULE, b.IDCLI, b.Avec_Contrat, b.idtcc, b.CTPART, b.ctgppe, b.leader
        ,b.CPTE_BOREAL, b.CPTE_DE, b.IDMARC, b.LIBMARC, b.IDSECO, b.LIBSECO
        ,b.IDSSGMA, b.LIBSSGMA, b.DIRCO_GEST_PARTEN, b.LIBDIRCO_GEST_PARTEN
        ,b.SECTEUR_GEST_PARTEN, b.LIBSECTEUR_GEST_PARTEN, b.AGP_GEST_PARTEN, b.LIBAGP_GEST_PARTEN
        ,b.PDV_GEST_PARTEN, b.LIBPDV_GEST_PARTEN, b.IDRESPPDV_GEST, b.RESPPDV_GEST
        ,b.SALARIE, b.CDPCSP, b.LIBPCS, b.CDACTIVITE, b.LIBACTIVITE, b.NOSIRE
        ,b.N1PRETS, b.M1PRETS, b.M2HABITA, b.M2CONSO, b.IDPORT
        ,b.IDESPTF_CC, b.LIBESPTF_CC, b.e_messagerie
        ,b.DIRCO_PTF_CC, b.LIBDIRCO_PTF_CC, b.SECTEUR_PTF_CC, b.LIBSECTEUR_PTF_CC
        ,b.AGP_PTF_CC, b.LIBAGP_PTF_CC, b.PDV_PTF_CC, b.LIBPDV_PTF_CC
        ,b.IDRESPPDV, b.RESPPDV, b.EXCLU_LUC, b.SITPART, b.BALE2
        ,b.REFRAC_COURRIER, b.REFRAC_EMAIL, b.OPTOUT_EMAIL
        ,b.REFRAC_TELPRINCIPAL, b.REFRAC_TELPROF, b.REFRAC_TELPOR
        ,b.REFRAC_SMS, b.OPTOUT_SMS, b.RCO, b.RCX, b.EXCLUSSIEGE
        ,b.TELPRINCIPAL, b.INVALID_TELPRINCIPAL, b.TELPRO, b.INVALID_TELPRO
        ,b.TELPORT, b.INVALID_TELPORT, b.EMAIL, b.INVALID_EMAIL
        ,b.OBLIGBDF, b.DECEDE, b.INCAPABLE, b.NONRESIDENTFISCAL
        ,b.TELPRINCIPAL_ETR, b.TELPRO_ETR, b.TELPORT_ETR, b.PIEGE
        ,b.Avec_Contrat_Fdc, b.Avec_Contrat_Tous, b.Note, b.Top_Retail_Corporate
        ,b.BREXIT, b.BLOCTEL, b.REFRCTR_TS_CNX
        ,c.LI_CSP, c.li_seg_emaco, c.top_pays_lgt_fr
        ,c.note_mire, c.note_Funivers, c.TOP_CLI_PORTEF
        ,c.NB_DAV_ACTIF, c.MT_MVT_CRDTR_DMLI_DAV_12M, c.SLD_MOY_MENSUEL_DAV_12M
        ,case when c.MT_MVT_CRDTR_DMLI_DAV_12M <= 0 then 1 else 0 end as top_rev_nul
    FROM WORK.CLIENTS_CLASSES_2      as a
    LEFT JOIN WORK.TA_BASMKG_PARTENAIRE as b ON a.IDPART_CALCULE = b.IDPART_CALCULE
    LEFT JOIN WORK.mtt               as c ON b.IDPART_CALCULE = c.idpart_calcule
    WHERE &condition.
    ;
quit;

/* --- RECUPERATION OPTIN/OPTOUT POUR LE SEGMENT ---
   On extrait le statut consentement email depuis la synthese quotidienne */
PROC SQL;
    CREATE TABLE WORK.OPTIN_NEUTRE AS
    SELECT
         t1.ID_PART
        ,t1.CD_OPTIN_OPTOUT_MLS
    FROM WORK.SYNTH_PART_QUOTD t1
    WHERE t1.ID_PART in (select IDPART_CALCULE from WORK.TABLE_R)
    ;
quit;


PROC SQL;
    CREATE TABLE WORK.TABLE_REFERENCE AS
    SELECT
         a.*
        ,b.CD_OPTIN_OPTOUT_MLS
    FROM WORK.TABLE_R      as a
    LEFT JOIN WORK.OPTIN_NEUTRE as b ON a.IDPART_CALCULE = b.ID_PART
    WHERE b.CD_OPTIN_OPTOUT_MLS = 0
    ;
quit;


/* --- 1. AGE ---
   Repartition de la clientele par tranche d'age pour le segment analyse */
proc sql;
    CREATE TABLE WORK.AGE as
    SELECT
        case
            when age between 18 and 30 then '18-30'
            when age between 31 and 45 then '31-45'
            when age between 46 and 60 then '46-60'
            when age between 60 and 75 then '60-75'
            when age > 75              then '75+'
            else ''
        end as tranche_age length=10
    FROM WORK.TABLE_REFERENCE
    GROUP BY tranche_age
    ORDER BY tranche_age
    ;
quit;

proc sql;
    CREATE TABLE WORK.tableau_age as
    SELECT
         tranche_age
        ,count(1) / (SELECT count(1) FROM WORK.AGE) as pct format=percent8.2
    from WORK.AGE
    GROUP BY tranche_age
    ORDER BY tranche_age
    ;
quit;

ODS GRAPHICS / RESET WIDTH=800px HEIGHT=500px;
PROC SGPLOT data=WORK.tableau_age;
    Title "NB SOLLICITATION &libele. - REPARTITION PAR TRANCHE D'AGE";
    vbarparm category=tranche_age response=pct / datalabel;
    YAXIS label="Pourcentage";
    XAXIS label="Tranche d'age";
run;
title;

proc univariate data=WORK.TABLE_REFERENCE;
    title "NB SOLLICITATION &libele. - STATISTIQUES AGE";
    var AGE;
run;
title;


/* --- 2. REVENUS (mouvements crediteurs DAV 12 mois) ---
   Analyse de l'activite financiere : clients avec ou sans mouvement crediteur.
   On exclut les profils sans activite economique attendue (etudiants, inactifs). */
proc sql;
    create table WORK.rev as
    select
         top_rev_nul
        ,count(1)                                                          as nb_pp
        ,count(1) / (SELECT count(1) FROM WORK.TABLE_REFERENCE)           as pct format=percent8.2
    from WORK.TABLE_REFERENCE
    where LIBPCS not in ('ELEVES-ETUDIANTS','SS ACT.-60A-SF RETRA','SS ACT.+60A-SF RETRA')
    group by top_rev_nul
    ;
quit;

proc transpose data=WORK.rev out=WORK.tr_rev (drop=_name_);
    id top_rev_nul; var nb_pp;
run;

ODS GRAPHICS / RESET WIDTH=800px HEIGHT=500px;
PROC SGPLOT data=WORK.rev;
    Title "NB SOLLICITATION &libele. - MOUVEMENT CREDITEUR (OUI/NON)";
    vbarparm category=top_rev_nul response=pct / datalabel;
    YAXIS label="Pourcentage";
    XAXIS label="Mouvement crediteur 12 mois (0=Oui / 1=Non)";
run;
title;

proc univariate data=WORK.TABLE_REFERENCE;
    title "NB SOLLICITATION &libele. - STATISTIQUES MOUVEMENTS CREDITEURS";
    var MT_MVT_CRDTR_DMLI_DAV_12M;
run;
title;


/* --- 3. CSP - CATEGORIE SOCIO-PROFESSIONNELLE ---
   Distribution des CSP dans le segment : permet d'identifier si les sous-sollicites
   sont concentres sur des profils specifiques (retraites, cadres, etudiants...) */
proc sql;
    create table WORK.CSP as
    select
         LIBPCS
        ,count(1)                                                          as nb_pp
        ,count(1) / (SELECT count(1) FROM WORK.TABLE_REFERENCE)           as pct format=percent8.2
    from WORK.TABLE_REFERENCE
    GROUP BY LIBPCS
    ;
quit;

proc sort data=WORK.CSP; by LIBPCS; run;

proc transpose data=WORK.CSP out=WORK.tr_CSP (drop=_name_);
    id LIBPCS; var nb_pp;
run;

ODS GRAPHICS / RESET WIDTH=800px HEIGHT=500px;
PROC SGPLOT data=WORK.CSP;
    Title "NB SOLLICITATION &libele. - DISTRIBUTION CSP";
    vbarparm category=LIBPCS response=pct / datalabel;
    YAXIS label="Pourcentage";
    XAXIS label="Categorie Socio-Professionnelle";
run;
title;


/* --- 4. SEGMENT MARKETING (EMACO) ---
   La segmentation EMACO permet d'identifier si les sous-sollicites sont plutot
   grand public, intermediaires ou haut de gamme - enjeu business majeur */
proc sql;
    create table WORK.seg as
    select
         li_seg_emaco
        ,count(1)                                                          as nb_pp
        ,count(1) / (SELECT count(1) FROM WORK.TABLE_REFERENCE)           as pct format=percent8.2
    from WORK.TABLE_REFERENCE
    group by li_seg_emaco
    ;
quit;

proc sort data=WORK.seg; by li_seg_emaco; run;

proc transpose data=WORK.seg out=WORK.tr_seg (drop=_name_);
    ID li_seg_emaco; var nb_pp;
run;

ODS GRAPHICS / RESET WIDTH=800px HEIGHT=500px;
PROC SGPLOT data=WORK.seg;
    Title "NB SOLLICITATION &libele. - REPARTITION PAR SEGMENT EMACO";
    vbarparm category=li_seg_emaco response=pct / datalabel;
    YAXIS label="Pourcentage";
    XAXIS label="Segment client EMACO";
run;
title;


/* --- 5. DAV ACTIFS (Comptes courants) ---
   On verifie si les clients du segment possedent un ou plusieurs comptes courants actifs.
   La multi-detention DAV est rare mais peut indiquer un profil specifique (chef d'entreprise...) */
proc sql;
    create table WORK.dav as
    select
         NB_DAV_ACTIF
        ,count(1)                                                          as nb_pp
        ,count(1) / (SELECT count(1) FROM WORK.TABLE_REFERENCE)           as pct format=percent8.2
    from WORK.TABLE_REFERENCE
    group by NB_DAV_ACTIF
    ;
quit;

proc sort data=WORK.dav; by NB_DAV_ACTIF; run;

proc transpose data=WORK.dav out=WORK.tr_dav (drop=_name_);
    ID NB_DAV_ACTIF; var nb_pp;
run;

ODS GRAPHICS / RESET WIDTH=800px HEIGHT=500px;
PROC SGPLOT data=WORK.dav;
    Title "NB SOLLICITATION &libele. - NOMBRE DE DAV ACTIFS";
    vbarparm category=NB_DAV_ACTIF response=pct / datalabel;
    YAXIS label="Pourcentage";
    XAXIS label="Nombre de comptes courants actifs";
run;
title;


/* --- 6. UNIVERS DE BESOIN (Note Funivers) ---
   La note Funivers est une variable continue (score decimal 0-50).
   On la decouppe en 5 tranches pour obtenir un graphique lisible.
   Plus la note est elevee, plus le client est multi-equipe. */
proc sql;
    create table WORK.UB as
    select
        case
            when note_Funivers < 10               then "0-10  (Faible)"
            when note_Funivers >= 10 and note_Funivers < 20 then "10-20 (Bas)"
            when note_Funivers >= 20 and note_Funivers < 30 then "20-30 (Moyen)"
            when note_Funivers >= 30 and note_Funivers < 40 then "30-40 (Eleve)"
            when note_Funivers >= 40              then "40-50 (Tres eleve)"
            else "Non renseigne"
        end as tranche_funivers length=20
        ,count(1)                                                          as nb_pp
        ,count(1) / (SELECT count(1) FROM WORK.TABLE_REFERENCE)           as pct format=percent8.2
    from WORK.TABLE_REFERENCE
    group by tranche_funivers
    ;
quit;

proc sort data=WORK.ub; by tranche_funivers; run;

proc transpose data=WORK.ub out=WORK.tr_ub (drop=_name_);
    id tranche_funivers; var nb_pp;
run;

ODS GRAPHICS / RESET WIDTH=800px HEIGHT=500px;
PROC SGPLOT data=WORK.UB;
    Title "NB SOLLICITATION &libele. - NOTE UNIVERS DE BESOIN (tranches)";
    vbarparm category=tranche_funivers response=pct / datalabel;
    YAXIS label="Pourcentage";
    XAXIS label="Tranche note Funivers";
run;
title;


/* --- 7. EQUIPEMENT PRODUIT ---
   On croise TABLE_REFERENCE avec la table EQUIPEMENT (pre-calculee) pour savoir
   quels produits bancaires sont deja detenus par les clients du segment.
   Familles : RGP10001=Depot / RGP10002=Epargne / RGP10003=Credit
              RGP10005=Assurance / RGP10006=Services
   Cette information est cle pour identifier les opportunites de cross-sell */


proc sql;
    create table WORK.EQUIPEMENT_2 as
    select distinct
         a.*
        ,max(case when cd_fam_prod_10 = "RGP10001" then 1 else 0 end) as top_depot

        ,max(case when cd_fam_prod_10 = "RGP10002" then 1 else 0 end) as top_epargne

        ,max(case when cd_fam_prod_10 = "RGP10003" then 1 else 0 end) as top_cred

        ,max(case when cd_fam_prod_10 = "RGP10005" then 1 else 0 end) as top_ass

        ,max(case when cd_fam_prod_10 = "RGP10006" then 1 else 0 end) as top_serv

    from WORK.TABLE_REFERENCE a
        left join WORK.EQUIPEMENT b on a.IDPART_CALCULE = b.ID_PART
    GROUP BY IDPART_CALCULE
    ;
quit;


proc freq data=WORK.EQUIPEMENT_2;
    title "NB SOLLICITATION &libele. - TAUX DE DETENTION PAR PRODUIT";
    table top_depot top_epargne top_cred top_ass top_serv;
run;
title;

/* --- Analyse equipement pour les clients avec un DAV actif (NB_DAV_ACTIF=1) ---
   On cible les detenteurs d'un seul compte courant pour evaluer leur multi-equipement */
proc sort data=WORK.EQUIPEMENT_2; by idpart_calcule; run;

proc transpose data=WORK.EQUIPEMENT_2
    out=WORK.DAV_1_v0 name=produit;
    where NB_DAV_ACTIF=1;
    BY idpart_calcule;
    var top_depot top_epargne top_cred top_ass top_serv;
run;


Title "NB SOLLICITATION &libele. - DAV ACTIF=1 - EQUIPEMENT";
Proc freq data=WORK.DAV_1_V0;
    tables produit*col1 / nocol nopercent out=WORK.DAV_1_V1 outpct;
run;

DATA WORK.DAV_1_V1;
    SET WORK.DAV_1_V1;
    LABEL col1="Detention produit";
run;

ODS GRAPHICS / RESET WIDTH=1200px HEIGHT=500px;
PROC SGPLOT data=WORK.DAV_1_V1;
    Title "NB SOLLICITATION &libele. - CLIENTS AVEC DAV ACTIF - EQUIPEMENT PRODUIT";
    vbar produit / response=pct_row
        group=col1
        groupdisplay=cluster
        clusterwidth=0.5
        datalabel;
    styleattrs datacolors=(cxCCCCCC cx2ECC71);
    YAXIS label="Pourcentage";
    XAXIS label="Produit" fitpolicy=rotate;
run;
title;

/* --- Analyse equipement pour les clients sans DAV actif ou sans compte depot ---
   On identifie les produits detenus par les clients sans compte courant actif :
   potentiellement des clients dorman ts ou a faible engagement */
proc transpose data=WORK.EQUIPEMENT_2
    out=WORK.DAV_depot_0_v0 name=produit;
    where (NB_DAV_ACTIF=0 or top_depot=0);
    BY idpart_calcule;
    var top_epargne top_cred top_ass top_serv;
run;

Title "NB SOLLICITATION &libele. - DAV NON ACTIFS & NON DETENTEURS - EQUIPEMENT";
Proc freq data=WORK.DAV_depot_0_v0;
    tables produit*col1 / nocol nopercent out=WORK.DAV_depot_0_v1 outpct;
run;

DATA WORK.DAV_depot_0_v1;
    SET WORK.DAV_depot_0_v1;
    LABEL col1="Detention produit";
run;

ODS GRAPHICS / RESET WIDTH=1200px HEIGHT=500px;
PROC SGPLOT data=WORK.DAV_depot_0_v1;
    Title "NB SOLLICITATION &libele. - CLIENTS SANS DAV ACTIF - EQUIPEMENT PRODUIT";
    vbar produit / response=pct_row
        group=col1
        groupdisplay=cluster
        clusterwidth=0.5
        datalabel;
    styleattrs datacolors=(cxCCCCCC cx2ECC71);
    YAXIS label="Pourcentage";
    XAXIS label="Produit" fitpolicy=rotate;
run;
title;


/* --- TABLEAU FINAL DE SYNTHESE DU SEGMENT ---
   Recapitulatif des variables cles pour chaque client du segment.
   Sert de base pour des exports ou analyses complementaires. */
proc sql;
    create table WORK.tableau_final as
    select
         a.IDPART_CALCULE
        ,a.NB_COMM_DIRECTE
        ,a.AGE
        ,a.MT_MVT_CRDTR_DMLI_DAV_12M
        ,a.NB_DAV_ACTIF
        ,a.LIBPCS
        ,a.li_seg_emaco
        ,a.note_Funivers
        ,a.top_rev_nul
    from WORK.TABLE_REFERENCE as a
    ORDER BY NB_COMM_DIRECTE
    ;
quit;

%mend ANALYSE_SEGMENT;


/*===========================================================================================================
  LANCEMENT DE LA MACRO PAR SEGMENT
  Chaque appel macro produit l'ensemble des analyses et graphiques pour une tranche.
  Commenter/decommenter les tranches selon le besoin du moment.
===========================================================================================================*/


%ANALYSE_SEGMENT(
    condition = NB_COMM_DIRECTE = 0,
    libele    = 0
);


%ANALYSE_SEGMENT(
    condition = NB_COMM_DIRECTE between 1 and 6,
    libele    = %str(1-6)
);


%ANALYSE_SEGMENT(
    condition = NB_COMM_DIRECTE between 7 and 12,
    libele    = %str(7-12)
);


%ANALYSE_SEGMENT(
    condition = NB_COMM_DIRECTE between 0 and 12,
    libele    = %str(0-12)
);


%ANALYSE_SEGMENT(
    condition = NB_COMM_DIRECTE between 0 and 24,
    libele    = %str(0-24)
);


%ANALYSE_SEGMENT(
    condition = NB_COMM_DIRECTE between 13 and 24,
    libele    = %str(13-24)
);


%ANALYSE_SEGMENT(
    condition = NB_COMM_DIRECTE between 25 and 36,
    libele    = %str(25-36)
);


%ANALYSE_SEGMENT(
    condition = %str(NB_COMM_DIRECTE ge 37),
    libele    = %str(>36)
);


/*===========================================================================================================
  PARTIE 4 - ANALYSES GLOBALES ET GRAPHIQUES COMPARATIFS
  Analyses complementaires : repartition epargne/assurance par age,
  comptage des sous-sollicites, graphique comparatif, verifications equipement.
===========================================================================================================*/

/* NOTE : Les tables EQUIPEMENT_2 et TABLE_REFERENCE utilisees ici correspondent
   au dernier appel de macro execute ci-dessus.
   Si vous souhaitez des analyses globales toutes tranches confondues,
   relancez %ANALYSE_SEGMENT avec condition=NB_COMM_DIRECTE between 0 and 12 avant. */

/* --- ANALYSE PONCTUELLE : Epargne & Assurance par tranche d'age ---
   Focus sur les clients sans DAV actif ou sans depot : qui possede de l'epargne
   et de l'assurance parmi les moins sollicites ? Enjeu de cross-sell fort. */
proc sql;
    create table WORK.EPA_ASS as
    select distinct
         a.idpart_calcule
        ,a.top_epargne
        ,a.top_ass
        ,a.age
        ,case
            when a.age between 18 and 30 then "18-30"
            when a.age between 31 and 45 then "31-45"
            when a.age between 46 and 60 then "46-60"
            when a.age between 61 and 75 then "61-75"
            when a.age > 75              then "75+"
            else ""
        end as tranche_age length=10
    from WORK.EQUIPEMENT_2 as a
    left join WORK.TABLE_REFERENCE as b on a.idpart_calcule = b.idpart_calcule
    where b.NB_COMM_DIRECTE between 0 and 12
      AND (a.NB_DAV_ACTIF = 0 OR a.top_depot = 0)
    ;
quit;


proc sort data=WORK.EPA_ASS; by idpart_calcule tranche_age age; run;

proc transpose data=WORK.EPA_ASS
    out=WORK.EPA_ASS_LONG (rename=(col1=valeur _name_=produit));
    by idpart_calcule tranche_age age;
    var top_epargne top_ass;
run;

DATA WORK.EPA_ASS_LONG;
    SET WORK.EPA_ASS_LONG;
    IF valeur = 1;
run;


PROC MEANS DATA=WORK.EPA_ASS_LONG;
    class produit;
    var age;
run;


proc freq data=WORK.EPA_ASS_LONG noprint;
    tables produit*valeur*tranche_age / out=WORK.EPA_ASS_FREQ outpct;
run;


proc sgpanel data=WORK.EPA_ASS_FREQ;
    Title "CIBLE 0-12 COMM DIRECTES - Repartition par age - Epargne & Assurance";
    panelby produit / columns=2;
    styleattrs datacolors=(cx2ECC71);
    vbar tranche_age / response=pct_row
        group=valeur
        groupdisplay=cluster
        datalabel;
    colaxis label="Tranche d'age";
    rowaxis label="Pourcentage";
run;
title;


/* --- COMPTAGE GLOBAL DES SOUS-SOLLICITES ---
   Quantification de la population cible principale :
   clients ayant recu moins de 12 communications directes sur la periode */
PROC SQL;
    CREATE TABLE WORK.NB_CLI_SOUS_SOLLICITE AS
    SELECT *
    FROM WORK.CLIENTS_CLASSES_2
    WHERE NB_COMM_DIRECTE < 12
    ;
QUIT;


/* --- GRAPHIQUE COMPARATIF : SOUS-SOLLICITES vs BIEN-SOLLICITES ---
   Vue macro permettant de mesurer le poids relatif des sous-sollicites
   vs les clients recevant 12 communications ou plus */
proc sql;
    create table WORK.graph_com as
    select
        case
            when NB_COMM_DIRECTE < 12  then 'Moins de 12 comm'
            when NB_COMM_DIRECTE >= 12 then '12 comm et plus'
        end as classe_com
        ,count(*)                                                              as nb_clients
        ,count(*) / (SELECT count(*) FROM WORK.CLIENTS_CLASSES_2)             as pct format=percent8.2
    from WORK.CLIENTS_CLASSES_2
    group by classe_com
    ;
quit;

ODS GRAPHICS / RESET WIDTH=800px HEIGHT=500px;
PROC SGPLOT data=WORK.graph_com;
    Title "Repartition des clients selon la pression de sollicitation directe";
    vbarparm category=classe_com response=pct /
        datalabel datalabelattrs=(size=12);
    YAXIS label="Pourcentage";
    XAXIS label="Classe de sollicitation";
run;
title;


/* --- EXPORT DES RESULTATS (optionnel) ---
   Decommenter et adapter le chemin pour exporter les tables en CSV.
   Utile pour retravailler les donnees sous Excel ou les partager.

%let chemin_export = /home/u12345678/mon_projet/exports/;

proc export data=WORK.FINAL_V2
    outfile="&chemin_export.Repartition_sollicitation.csv"
    dbms=csv replace;
run;

proc export data=WORK.tableau_final
    outfile="&chemin_export.Tableau_final_segment.csv"
    dbms=csv replace;
run;
*/

/*===========================================================================================================
  FIN DU PROGRAMME
  Projet : Analyse de la sur- et sous-sollicitation client - Marketing Data-Driven
===========================================================================================================*/
