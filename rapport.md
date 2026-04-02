# Conception et implementation d'une base de donnees repartie pour la gestion d'une chaine de pharmacies / cliniques sur deux villes

<br/><br/><br/><br/>

<div align="center">

**EFREI Paris**

**Annee universitaire 2025 - 2026**

<br/>

### Projet de Base de Donnees Reparties

<br/>

**Filiere** : LSI2 - ING2

**Module** : Base de Donnees Reparties

**Enseignante** : Mme Marwa HARZI

<br/><br/>

**Membres du groupe :**

| Nom | Prenom |
|-----|--------|
| TOURE | Mehedi |
| CHETOUANI | Adil |
| CHARPENTREAU | Alexis |
| MAGNETTE | Arthur |

<br/>

**Date de remise** : Avril 2026

</div>

<div style="page-break-after: always;"></div>

---

## Table des matieres

1. [Introduction](#1-introduction)
2. [Etude prealable et justification de l'architecture repartie](#2-etude-prealable-et-justification-de-larchitecture-repartie)
3. [Conception du schema global](#3-conception-du-schema-global)
4. [Strategie de fragmentation](#4-strategie-de-fragmentation)
5. [Strategie d'allocation des fragments sur les sites](#5-strategie-dallocation-des-fragments-sur-les-sites)
6. [Implementation technique sous PostgreSQL](#6-implementation-technique-sous-postgresql)
7. [Jeu de donnees](#7-jeu-de-donnees)
8. [Requetes reparties](#8-requetes-reparties)
9. [Analyse critique](#9-analyse-critique)
10. [Conclusion](#10-conclusion)
11. [Annexes](#11-annexes)

<div style="page-break-after: always;"></div>

---

## 1. Introduction

### 1.1 Contexte general

Dans le cadre du module de Bases de Donnees Reparties, ce projet vise a concevoir et implementer une base de donnees distribuee pour une entreprise de sante privee. Cette entreprise possede des structures reparties sur deux villes marocaines : **Casablanca** (Site S1) et **Rabat** (Site S2).

L'entreprise exploite dans chaque ville :

- Une **clinique** avec du personnel medical (medecins de differentes specialites)
- Une **pharmacie partenaire** gerant un stock local de medicaments
- Des **patients** enregistres localement
- Des activites de **consultations medicales**, de **prescriptions** et de **ventes** de medicaments

### 1.2 Problematique

La problematique centrale de ce projet est la suivante : comment organiser les donnees d'une entreprise multi-sites de maniere a garantir a la fois une **gestion locale performante** des donnees propres a chaque ville, et un **acces global transparent** a l'ensemble des informations du reseau ?

Cette problematique s'inscrit pleinement dans les objectifs des bases de donnees reparties tels que definis dans le chapitre 4 du cours : performance, autonomie locale, extensibilite, egalite entre sites et transparence vis-a-vis de la repartition.

### 1.3 Demarche adoptee

Nous avons suivi une approche de **conception descendante** (top-down design) en trois etapes :

1. **Schema global** : definition d'un schema relationnel conceptuel unifie representant l'ensemble des donnees de l'entreprise.
2. **Fragmentation** : decomposition du schema global en fragments (horizontaux et verticaux) selon les besoins fonctionnels de chaque site.
3. **Allocation** : repartition physique des fragments sur les deux sites PostgreSQL, avec mise en place de l'acces distant via `postgres_fdw`.

### 1.4 Technologies utilisees

- **PostgreSQL 16** : systeme de gestion de base de donnees relationnelle
- **postgres_fdw** : extension PostgreSQL pour l'acces aux donnees distantes (Foreign Data Wrapper)
- **Docker Compose** : orchestration de deux conteneurs PostgreSQL simulant les deux sites
- **SQL** : langage de definition, manipulation et interrogation des donnees

<div style="page-break-after: always;"></div>

---

## 2. Etude prealable et justification de l'architecture repartie

### 2.1 Pourquoi une architecture centralisee n'est pas ideale

Dans le contexte d'une entreprise de sante possedant des structures a Casablanca et Rabat, une architecture centralisee (base unique sur un seul serveur) presente plusieurs inconvenients majeurs :

**Point unique de defaillance (Single Point of Failure)** : si le serveur central tombe en panne, les deux villes perdent l'acces aux donnees simultanement. Pour une activite medicale, cette indisponibilite peut avoir des consequences graves : impossibilite de consulter les dossiers patients en urgence, impossibilite de verifier les prescriptions en cours, et arret complet des ventes en pharmacie.

**Goulet d'etranglement reseau** : toutes les requetes de la ville distante doivent transiter par le reseau pour atteindre le serveur central. Supposons que le serveur soit a Casablanca : chaque operation effectuee a Rabat (enregistrement d'une vente, consultation d'un dossier patient, verification du stock) subit la latence reseau. Pour des operations frequentes et critiques en temps reel (encaissement en pharmacie, consultation medicale), cette latence n'est pas acceptable.

**Absence d'autonomie locale** : chaque site depend entierement du serveur central et de la liaison reseau. En cas de coupure reseau entre Casablanca et Rabat, le site distant perd totalement l'acces a ses propres donnees, meme si celles-ci sont purement locales (patients de la ville, stock local).

**Surcharge du serveur central** : un seul serveur doit supporter la charge combinee des deux villes, ce qui limite les performances et la capacite de montee en charge.

**Non-respect du principe de localite** : les donnees d'un site sont majoritairement utilisees par ce meme site. Centraliser ces donnees a distance va a l'encontre du principe de localite des references, qui est au coeur de l'optimisation des BDR.

### 2.2 Pourquoi une architecture repartie est pertinente

L'architecture repartie repond directement a chacun des problemes identifies :

**Autonomie locale** : chaque ville peut travailler sur ses propres donnees (patients locaux, stocks locaux, ventes locales) de maniere independante. Un medecin a Casablanca accede directement au dossier de son patient sans solliciter le site de Rabat.

**Performance par localite** : les acces aux donnees locales sont directs, sans latence reseau. On estime qu'environ 80% des operations quotidiennes d'un site sont purement locales (consultation de dossiers patients du site, enregistrement des ventes locales, gestion du stock local).

**Disponibilite amelioree** : si un site est indisponible (panne serveur, maintenance, coupure reseau), l'autre site peut continuer a fonctionner sur ses donnees locales. Le fonctionnement n'est que partiellement degrade.

**Extensibilite** : l'ajout d'un nouveau site (par exemple une troisieme ville comme Marrakech) est facilite par l'architecture modulaire. Il suffit d'ajouter un nouveau noeud et de configurer les liaisons FDW.

**Reduction du trafic reseau** : seules les requetes necessitant des donnees distantes (reporting consolide, requetes cross-site) generent du trafic inter-sites. Les operations courantes restent locales.

### 2.3 Donnees principalement utilisees a Casablanca (S1)

Les donnees suivantes sont principalement accedees par le site de Casablanca :

- **Patients de Casablanca** : dossiers medicaux, coordonnees, historique des consultations
- **Medecins de Casablanca** : 3 medecins (generaliste, cardiologue, dermatologue)
- **Consultations realisees a Casablanca** : diagnostics poses par les medecins de la clinique de Casablanca
- **Prescriptions de Casablanca** : ordonnances emises lors des consultations locales
- **Stock de la pharmacie de Casablanca** : quantites disponibles des 10 medicaments du catalogue
- **Ventes de la pharmacie de Casablanca** : transactions realisees localement

### 2.4 Donnees principalement utilisees a Rabat (S2)

Symetriquement, le site de Rabat utilise principalement :

- **Patients de Rabat** : 6 patients enregistres localement
- **Medecins de Rabat** : 3 medecins (generaliste, pneumologue, gynecologue)
- **Consultations realisees a Rabat** : diagnostics des consultations locales
- **Prescriptions de Rabat** : ordonnances des consultations de Rabat
- **Stock de la pharmacie de Rabat** : gestion locale des quantites
- **Ventes de la pharmacie de Rabat** : transactions locales

### 2.5 Donnees devant rester accessibles globalement

Certaines donnees doivent pouvoir etre consultees depuis les deux sites :

- **Catalogue des medicaments** : la table Medicament est referencee par les deux sites pour les prescriptions, les ventes et la gestion des stocks. Tout medecin ou pharmacien doit pouvoir consulter les informations d'un medicament, quel que soit son site.

- **Liste complete des patients** : un patient de Casablanca peut se rendre a la pharmacie de Rabat pour acheter un medicament, ou consulter un specialiste a Rabat. Le systeme doit pouvoir identifier ce patient depuis n'importe quel site.

- **Donnees financieres consolidees** : la direction de l'entreprise a besoin du chiffre d'affaires global et par ville pour le pilotage de l'activite.

- **Statistiques medicales** : nombre de consultations par medecin, medicaments les plus prescrits et vendus a l'echelle du reseau. Ces indicateurs necessitent une vision transversale.

### 2.6 Gains attendus de l'architecture repartie

| Critere | Architecture centralisee | Architecture repartie | Gain |
|---------|------------------------|-----------------------|------|
| **Performance locale** | Latence reseau pour le site distant | Acces direct aux donnees locales | ~80% des requetes sans latence |
| **Autonomie** | Dependance totale au serveur central | Chaque site fonctionne independamment | Continuite en cas de coupure |
| **Trafic reseau** | Toutes les requetes transitent par le reseau | Seules les requetes globales | Reduction de ~80% du trafic |
| **Disponibilite** | Panne centrale = arret total | Panne d'un site = fonctionnement degrade | Pas d'arret complet |
| **Montee en charge** | Limitee a un seul serveur | Repartie sur les deux serveurs | Capacite doublee |

<div style="page-break-after: always;"></div>

---

## 3. Conception du schema global

### 3.1 Presentation du schema relationnel global

Le schema global comprend **9 tables** organisees autour de trois axes fonctionnels :

- **Axe medical** : Patient, Medecin, Consultation, Prescription, LignePrescription
- **Axe pharmaceutique** : Medicament, Stock
- **Axe commercial** : Vente, LigneVente

### 3.2 Description detaillee des tables

#### Table Patient

Contient les informations personnelles et les coordonnees de chaque patient enregistre dans le reseau.

| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| **IdPatient** | INT | PRIMARY KEY | Identifiant unique du patient |
| Nom | VARCHAR(50) | NOT NULL | Nom de famille |
| Prenom | VARCHAR(50) | NOT NULL | Prenom |
| DateNaissance | DATE | NOT NULL | Date de naissance |
| Sexe | CHAR(1) | CHECK ('M','F') | Sexe du patient |
| Adresse | VARCHAR(200) | | Adresse postale |
| Ville | VARCHAR(50) | NOT NULL | Ville de residence (critere de fragmentation) |
| Telephone | VARCHAR(20) | | Numero de telephone |

#### Table Medecin

Contient les informations des medecins exercant dans les cliniques du reseau.

| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| **IdMedecin** | INT | PRIMARY KEY | Identifiant unique du medecin |
| NomMedecin | VARCHAR(100) | NOT NULL | Nom complet du medecin |
| Specialite | VARCHAR(50) | NOT NULL | Specialite medicale |
| Ville | VARCHAR(50) | NOT NULL | Ville d'exercice (critere de fragmentation) |
| Telephone | VARCHAR(20) | | Telephone professionnel |

#### Table Consultation

Enregistre chaque consultation medicale entre un patient et un medecin.

| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| **IdConsultation** | INT | PRIMARY KEY | Identifiant unique |
| DateConsultation | DATE | NOT NULL | Date de la consultation |
| Diagnostic | TEXT | | Diagnostic medical pose |
| IdPatient | INT | FK -> Patient | Patient concerne |
| IdMedecin | INT | FK -> Medecin | Medecin traitant |

#### Table Prescription

Represente une ordonnance emise a la suite d'une consultation. Relation 1:1 avec Consultation.

| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| **IdPrescription** | INT | PRIMARY KEY | Identifiant unique |
| DatePrescription | DATE | NOT NULL | Date de l'ordonnance |
| IdConsultation | INT | FK -> Consultation, UNIQUE | Consultation associee |

#### Table Medicament

Catalogue complet des medicaments disponibles dans le reseau de pharmacies.

| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| **IdMedicament** | INT | PRIMARY KEY | Identifiant unique |
| NomMedicament | VARCHAR(100) | NOT NULL | Denomination commune ou commerciale |
| Forme | VARCHAR(50) | NOT NULL | Forme galenique (comprime, gelule, sirop...) |
| Dosage | VARCHAR(50) | | Dosage du principe actif |
| PrixUnitaire | DECIMAL(10,2) | NOT NULL | Prix unitaire en DH |
| Fabricant | VARCHAR(100) | | Laboratoire fabricant |
| VilleProduction | VARCHAR(50) | | Ville du site de production |

#### Table LignePrescription

Detail des medicaments prescrits dans chaque ordonnance (relation N:N entre Prescription et Medicament).

| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| **IdPrescription** | INT | PK composite, FK -> Prescription | Ordonnance concernee |
| **IdMedicament** | INT | PK composite, FK -> Medicament | Medicament prescrit |
| Quantite | INT | NOT NULL, DEFAULT 1 | Nombre de boites |
| Posologie | VARCHAR(200) | | Instructions de prise |

#### Table Stock

Suivi du stock de medicaments pour chaque pharmacie du reseau.

| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| **IdStock** | INT | PRIMARY KEY | Identifiant unique |
| IdMedicament | INT | FK -> Medicament | Medicament en stock |
| Ville | VARCHAR(50) | NOT NULL | Pharmacie concernee |
| QuantiteDisponible | INT | NOT NULL | Quantite en stock |
| SeuilAlerte | INT | NOT NULL | Seuil de reapprovisionnement |

#### Table Vente

Enregistre chaque vente realisee dans une pharmacie du reseau.

| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| **IdVente** | INT | PRIMARY KEY | Identifiant unique |
| DateVente | DATE | NOT NULL | Date de la transaction |
| Ville | VARCHAR(50) | NOT NULL | Pharmacie de vente |
| IdPatient | INT | FK -> Patient | Client acheteur |
| MontantTotal | DECIMAL(10,2) | NOT NULL | Montant total de la vente |

#### Table LigneVente

Detail des medicaments vendus lors de chaque transaction (relation N:N entre Vente et Medicament).

| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| **IdVente** | INT | PK composite, FK -> Vente | Vente concernee |
| **IdMedicament** | INT | PK composite, FK -> Medicament | Medicament vendu |
| Quantite | INT | NOT NULL, DEFAULT 1 | Quantite vendue |
| PrixVente | DECIMAL(10,2) | NOT NULL | Prix de vente effectif |

### 3.3 Schema relationnel formel

Les cles primaires sont soulignees, les cles etrangeres sont precedees du symbole #.

```
Patient       (__IdPatient__, Nom, Prenom, DateNaissance, Sexe, Adresse, Ville, Telephone)
Medecin       (__IdMedecin__, NomMedecin, Specialite, Ville, Telephone)
Consultation  (__IdConsultation__, DateConsultation, Diagnostic, #IdPatient, #IdMedecin)
Prescription  (__IdPrescription__, DatePrescription, #IdConsultation)
LignePrescription (__#IdPrescription, #IdMedicament__, Quantite, Posologie)
Medicament    (__IdMedicament__, NomMedicament, Forme, Dosage, PrixUnitaire, Fabricant, VilleProduction)
Stock         (__IdStock__, #IdMedicament, Ville, QuantiteDisponible, SeuilAlerte)
Vente         (__IdVente__, DateVente, Ville, #IdPatient, MontantTotal)
LigneVente    (__#IdVente, #IdMedicament__, Quantite, PrixVente)
```

### 3.4 Dependances fonctionnelles et cardinalites

Les principales dependances fonctionnelles et cardinalites sont :

- Un patient peut avoir **plusieurs consultations** (1:N)
- Un medecin peut realiser **plusieurs consultations** (1:N)
- Une consultation donne lieu a **au plus une prescription** (1:1)
- Une prescription peut contenir **plusieurs lignes** de medicaments (1:N)
- Un medicament peut figurer dans **plusieurs prescriptions** et **plusieurs ventes** (N:N)
- Chaque medicament a **un stock par ville** (contrainte UNIQUE sur IdMedicament + Ville)
- Une vente peut contenir **plusieurs lignes** de medicaments (1:N)

*[Capture d'ecran : diagramme entite-association du schema global]*

<div style="page-break-after: always;"></div>

---

## 4. Strategie de fragmentation

La fragmentation consiste a decomposer les tables du schema global en sous-ensembles appeles **fragments**, qui seront ensuite repartis sur les differents sites. Nous avons applique deux types de fragmentation : **horizontale** et **verticale**.

### 4.1 Fragmentation horizontale

La fragmentation horizontale divise les tuples (lignes) d'une table en sous-ensembles selon un critere de selection. Dans notre contexte, le critere principal est l'attribut **Ville**, qui determine naturellement l'appartenance d'un enregistrement a un site.

#### Schema H1 - Fragmentation de Patient par Ville

**Definition formelle :**
```
Patient_Casa  = sigma(Ville = 'Casablanca')(Patient)  -> alloue a S1
Patient_Rabat = sigma(Ville = 'Rabat')(Patient)        -> alloue a S2
```

**Justification fonctionnelle** : les patients sont principalement geres par la clinique et la pharmacie de leur ville de residence. Les consultations, prescriptions et dossiers medicaux sont consultes localement dans la grande majorite des cas (~90%). Cette fragmentation garantit que les donnees les plus accedees localement sont stockees directement sur le site local, evitant ainsi des acces distants frequents.

**Proprietes :**
- **Completude** : Patient_Casa UNION Patient_Rabat = Patient (tous les tuples sont couverts)
- **Disjonction** : Patient_Casa INTERSECT Patient_Rabat = {} (un patient appartient a une seule ville)
- **Reconstruction** : Patient = Patient_Casa UNION ALL Patient_Rabat

#### Schema H2 - Fragmentation de Vente par Ville

**Definition formelle :**
```
Vente_Casa  = sigma(Ville = 'Casablanca')(Vente)  -> alloue a S1
Vente_Rabat = sigma(Ville = 'Rabat')(Vente)        -> alloue a S2
```

**Justification fonctionnelle** : les ventes sont realisees dans une pharmacie specifique identifiee par sa ville. Chaque pharmacie a besoin d'un acces rapide et exclusif a ses propres ventes pour les operations quotidiennes : encaissement, suivi des transactions, reporting local, et gestion du chiffre d'affaires.

Il est important de noter qu'un patient de Rabat peut acheter un medicament a la pharmacie de Casablanca. Dans ce cas, la vente est stockee sur S1 (site de la pharmacie), meme si le patient est enregistre sur S2.

**Proprietes :**
- **Completude** : Vente_Casa UNION Vente_Rabat = Vente
- **Disjonction** : Vente_Casa INTERSECT Vente_Rabat = {}
- **Reconstruction** : Vente = Vente_Casa UNION ALL Vente_Rabat

#### Autres fragmentations horizontales appliquees

Le meme principe est applique aux tables suivantes :

| Table | Critere | Fragment S1 | Fragment S2 |
|-------|---------|-------------|-------------|
| **Medecin** | Ville | Medecins de Casablanca | Medecins de Rabat |
| **Stock** | Ville | Stock pharmacie Casa | Stock pharmacie Rabat |
| **Consultation** | Ville du medecin (derivee) | Consultations Casa | Consultations Rabat |
| **Prescription** | Suit Consultation (derivee) | Prescriptions Casa | Prescriptions Rabat |
| **LignePrescription** | Suit Prescription (derivee) | Lignes presc. Casa | Lignes presc. Rabat |
| **LigneVente** | Suit Vente (derivee) | Lignes vente Casa | Lignes vente Rabat |

Les fragmentations de Consultation, Prescription, LignePrescription et LigneVente sont dites **derivees** car elles decoulent de la fragmentation de leur table parente par lien de cle etrangere.

### 4.2 Fragmentation verticale

La fragmentation verticale divise les colonnes (attributs) d'une table en sous-ensembles, chacun contenant obligatoirement la **cle primaire** pour permettre la reconstruction par jointure.

#### Schema V1 - Fragmentation verticale de Medicament

**Definition formelle :**
```
Medicament_Base       = pi(IdMedicament, NomMedicament, Forme, Dosage)(Medicament)             -> S1
Medicament_Commercial = pi(IdMedicament, PrixUnitaire, Fabricant, VilleProduction)(Medicament)  -> S2
```

**Justification fonctionnelle** :

Cette fragmentation separe les colonnes en deux groupes correspondant a deux profils d'utilisation distincts :

- Le fragment **Medicament_Base** regroupe les informations **pharmaceutiques** : le nom du medicament, sa forme galenique (comprime, gelule, sirop...) et son dosage. Ces informations sont principalement utilisees par le **personnel medical** lors des consultations et des prescriptions. Elles sont stockees sur **S1 (Casablanca)**.

- Le fragment **Medicament_Commercial** regroupe les informations **commerciales** : le prix unitaire, le fabricant et la ville de production. Ces informations sont principalement utilisees par le **personnel de pharmacie** pour les ventes, la facturation et le reporting financier. Elles sont stockees sur **S2 (Rabat)**.

**Proprietes :**
- **Completude** : Medicament_Base JOIN Medicament_Commercial = Medicament (toutes les colonnes sont couvertes)
- **Reconstruction** : jointure naturelle sur IdMedicament (la cle primaire est presente dans les deux fragments)

Cette fragmentation est **reellement distribuee** : les deux fragments sont physiquement stockes sur des sites differents. La reconstruction du Medicament complet necessite une jointure distante via `postgres_fdw`.

#### Schema V2 - Fragmentation mixte de Patient (horizontale + verticale)

Apres la fragmentation horizontale par Ville, nous definissons une fragmentation verticale applicable a chaque fragment horizontal :

**Definition formelle :**
```
Patient_Identite = pi(IdPatient, Nom, Prenom, DateNaissance, Sexe, Ville)(Patient)
Patient_Contact  = pi(IdPatient, Adresse, Telephone)(Patient)
```

**Justification fonctionnelle** :

- **Patient_Identite** contient les donnees medicales essentielles utilisees par les medecins lors des consultations : identite du patient, age (calcule a partir de la date de naissance), sexe. Ces informations sont consultees a chaque acte medical.

- **Patient_Contact** contient les donnees administratives utilisees par le secretariat medical et la pharmacie pour les rappels de rendez-vous, les notifications et la facturation.

Cette combinaison d'une fragmentation horizontale suivie d'une fragmentation verticale constitue une **fragmentation mixte** (ou hybride). Dans notre implementation, les deux fragments verticaux sont co-localises sur le meme site pour eviter des jointures distantes systematiques sur une table tres frequemment accedee.

<div style="page-break-after: always;"></div>

---

## 5. Strategie d'allocation des fragments sur les sites

### 5.1 Principes d'allocation retenus

L'allocation des fragments suit quatre principes directeurs :

1. **Localite des donnees** : chaque fragment est alloue au site qui l'utilise le plus frequemment, conformement au principe de proximite des references.

2. **Pas de replication** : chaque fragment n'existe physiquement que sur un seul site. Ce choix simplifie la gestion de la coherence (pas de protocole de mise a jour repliquee) au prix d'une moindre disponibilite.

3. **Acces distant par FDW** : les donnees non locales sont rendues accessibles via des tables etrangeres (Foreign Data Wrapper), creant une illusion de base unifiee.

4. **Transparence par vues globales** : des vues `UNION ALL` (fragmentation horizontale) ou `JOIN` (fragmentation verticale) reconstituent le schema global pour l'utilisateur final.

### 5.2 Tableau d'allocation complet

| Fragment | Site S1 (Casablanca) | Site S2 (Rabat) | Type de fragmentation |
|----------|:-------------------:|:---------------:|----------------------|
| Patient (Ville='Casablanca') | **LOCAL** | Distant (FDW) | Horizontale |
| Patient (Ville='Rabat') | Distant (FDW) | **LOCAL** | Horizontale |
| Medecin (Ville='Casablanca') | **LOCAL** | Distant (FDW) | Horizontale |
| Medecin (Ville='Rabat') | Distant (FDW) | **LOCAL** | Horizontale |
| Consultation (medecins Casa) | **LOCAL** | Distant (FDW) | Derivee |
| Consultation (medecins Rabat) | Distant (FDW) | **LOCAL** | Derivee |
| Prescription (consult. Casa) | **LOCAL** | Distant (FDW) | Derivee |
| Prescription (consult. Rabat) | Distant (FDW) | **LOCAL** | Derivee |
| LignePrescription (Casa) | **LOCAL** | Distant (FDW) | Derivee |
| LignePrescription (Rabat) | Distant (FDW) | **LOCAL** | Derivee |
| **Medicament_Base** | **LOCAL** | Distant (FDW) | **Verticale** |
| **Medicament_Commercial** | Distant (FDW) | **LOCAL** | **Verticale** |
| Stock (Ville='Casablanca') | **LOCAL** | Distant (FDW) | Horizontale |
| Stock (Ville='Rabat') | Distant (FDW) | **LOCAL** | Horizontale |
| Vente (Ville='Casablanca') | **LOCAL** | Distant (FDW) | Horizontale |
| Vente (Ville='Rabat') | Distant (FDW) | **LOCAL** | Horizontale |
| LigneVente (ventes Casa) | **LOCAL** | Distant (FDW) | Derivee |
| LigneVente (ventes Rabat) | Distant (FDW) | **LOCAL** | Derivee |

### 5.3 Schema d'architecture

```
+------------------------------+         +------------------------------+
|    SITE S1 - CASABLANCA      |         |    SITE S2 - RABAT           |
|    (site_casablanca)         |         |    (site_rabat)              |
|                              |         |                              |
|  Tables locales :            |         |  Tables locales :            |
|  - Patient (Casa)            |  FDW    |  - Patient (Rabat)           |
|  - Medecin (Casa)            | <-----> |  - Medecin (Rabat)           |
|  - Consultation (Casa)       |         |  - Consultation (Rabat)      |
|  - Prescription (Casa)       |         |  - Prescription (Rabat)      |
|  - LignePrescription (Casa)  |         |  - LignePrescription (Rabat) |
|  - Medicament_Base           |         |  - Medicament_Commercial     |
|  - Stock (Casa)              |         |  - Stock (Rabat)             |
|  - Vente (Casa)              |         |  - Vente (Rabat)             |
|  - LigneVente (Casa)         |         |  - LigneVente (Rabat)        |
|                              |         |                              |
|  Vues globales : v_Patient,  |         |  Vues globales : v_Patient,  |
|  v_Medecin, v_Medicament,    |         |  v_Medecin, v_Medicament,    |
|  v_Consultation, ...         |         |  v_Consultation, ...         |
+------------------------------+         +------------------------------+
```

<div style="page-break-after: always;"></div>

---

## 6. Implementation technique sous PostgreSQL

### 6.1 Architecture technique

L'implementation simule deux sites sur une meme machine a l'aide de **Docker Compose**. Deux conteneurs PostgreSQL 16 representent les deux sites :

| Service | Base de donnees | Port expose | Role |
|---------|----------------|-------------|------|
| `site_casablanca` | site_casablanca | 5433 | Site S1 |
| `site_rabat` | site_rabat | 5434 | Site S2 |

Un troisieme conteneur (`setup`) s'execute une seule fois apres le demarrage des deux bases pour configurer les liaisons FDW entre les sites.

### 6.2 Extension postgres_fdw

L'extension **postgres_fdw** (Foreign Data Wrapper) est le mecanisme natif de PostgreSQL pour acceder a des tables situees dans une base de donnees distante. Sur chaque site, nous configurons :

1. **L'extension** elle-meme :
```sql
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
```

2. **Le serveur distant** (pointant vers l'autre site) :
```sql
-- Sur S1 : declaration du serveur S2
CREATE SERVER site_rabat
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'site_rabat', port '5432', dbname 'site_rabat');
```

3. **Le mapping utilisateur** (credentials pour la connexion distante) :
```sql
CREATE USER MAPPING FOR postgres
    SERVER site_rabat
    OPTIONS (user 'postgres', password 'postgres');
```

### 6.3 Tables etrangeres (Foreign Tables)

Chaque site declare des **tables etrangeres** pointant vers les fragments stockes sur l'autre site. Ces tables etrangeres sont utilisees comme si elles etaient locales dans les requetes SQL.

Exemple sur S1, pour acceder aux patients de Rabat :
```sql
CREATE FOREIGN TABLE Patient_Rabat (
    IdPatient INT, Nom VARCHAR(50), Prenom VARCHAR(50),
    DateNaissance DATE, Sexe CHAR(1), Adresse VARCHAR(200),
    Ville VARCHAR(50), Telephone VARCHAR(20)
) SERVER site_rabat OPTIONS (schema_name 'public', table_name 'patient');
```

De la meme maniere, le fragment vertical distant est declare. Sur S1, Medicament_Commercial est une table etrangere pointant vers S2 :
```sql
CREATE FOREIGN TABLE Medicament_Commercial (
    IdMedicament INT, PrixUnitaire DECIMAL(10,2),
    Fabricant VARCHAR(100), VilleProduction VARCHAR(50)
) SERVER site_rabat OPTIONS (schema_name 'public', table_name 'medicament_commercial');
```

### 6.4 Vues globales

Les vues globales reconstituent le schema conceptuel de maniere transparente pour l'utilisateur final.

**Pour les tables fragmentees horizontalement** - reconstruction par `UNION ALL` :
```sql
CREATE VIEW v_Patient AS
    SELECT IdPatient, Nom, Prenom, DateNaissance, Sexe, Adresse, Ville, Telephone
    FROM Patient            -- fragment local (Casablanca)
    UNION ALL
    SELECT IdPatient, Nom, Prenom, DateNaissance, Sexe, Adresse, Ville, Telephone
    FROM Patient_Rabat;     -- fragment distant (Rabat via FDW)
```

**Pour la table fragmentee verticalement** - reconstruction par `JOIN` :
```sql
CREATE VIEW v_Medicament AS
    SELECT b.IdMedicament, b.NomMedicament, b.Forme, b.Dosage,
           c.PrixUnitaire, c.Fabricant, c.VilleProduction
    FROM Medicament_Base b
    JOIN Medicament_Commercial c ON b.IdMedicament = c.IdMedicament;
```

### 6.5 Mecanisme d'insertion transparente

Des triggers **INSTEAD OF** sur les vues globales permettent une insertion transparente. L'utilisateur insere dans la vue globale et le systeme redirige automatiquement vers le bon fragment.

**Insertion dans v_Patient** (fragmentation horizontale) :
```sql
CREATE OR REPLACE FUNCTION fn_insert_patient()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.Ville = 'Casablanca' THEN
        INSERT INTO Patient VALUES (NEW.*);         -- insertion locale
    ELSIF NEW.Ville = 'Rabat' THEN
        INSERT INTO Patient_Rabat VALUES (NEW.*);   -- insertion distante via FDW
    ELSE
        RAISE EXCEPTION 'Ville non geree : %', NEW.Ville;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_insert_v_patient
    INSTEAD OF INSERT ON v_Patient
    FOR EACH ROW EXECUTE FUNCTION fn_insert_patient();
```

**Insertion dans v_Medicament** (fragmentation verticale) :
```sql
CREATE OR REPLACE FUNCTION fn_insert_medicament()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO Medicament_Base (IdMedicament, NomMedicament, Forme, Dosage)
    VALUES (NEW.IdMedicament, NEW.NomMedicament, NEW.Forme, NEW.Dosage);
    INSERT INTO Medicament_Commercial (IdMedicament, PrixUnitaire, Fabricant, VilleProduction)
    VALUES (NEW.IdMedicament, NEW.PrixUnitaire, NEW.Fabricant, NEW.VilleProduction);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

Cette fonction insere simultanement dans les deux fragments verticaux : l'un local, l'autre distant via FDW. L'utilisateur n'a pas conscience de la distribution.

### 6.6 Contraintes d'integrite en contexte reparti

| Type de contrainte | Applicable ? | Exemple |
|-------------------|:----------:|---------|
| Cle primaire (locale) | Oui | `Patient.IdPatient PRIMARY KEY` sur chaque site |
| Cle etrangere (locale) | Oui | `Consultation.IdMedecin -> Medecin.IdMedecin` |
| Cle etrangere (cross-site) | **Non** | `Vente.IdPatient -> Patient.IdPatient` quand le patient est sur un autre site |
| CHECK (locale) | Oui | `CHECK (Ville = 'Casablanca')` pour garantir la regle de fragmentation |
| UNIQUE (locale) | Oui | Fonctionne au sein de chaque fragment |

L'impossibilite d'appliquer des cles etrangeres cross-site est une **limitation structurelle** de `postgres_fdw`. La coherence referentielle inter-sites repose sur la discipline applicative.

*[Captures d'ecran de l'execution des scripts de creation]*

<div style="page-break-after: always;"></div>

---

## 7. Jeu de donnees

### 7.1 Resume quantitatif

| Table | Casablanca (S1) | Rabat (S2) | Total |
|-------|:--------------:|:----------:|:-----:|
| Patient | 6 | 6 | **12** |
| Medecin | 3 | 3 | **6** |
| Consultation | 6 | 6 | **12** |
| Prescription | 6 | 6 | **12** |
| LignePrescription | 8 | 9 | **17** |
| Medicament_Base | 10 | *(distant)* | **10** |
| Medicament_Commercial | *(distant)* | 10 | **10** |
| Stock | 10 | 10 | **20** |
| Vente | 9 | 7 | **16** |
| LigneVente | 12 | 10 | **22** |

### 7.2 Donnees des patients

**Casablanca (IdPatient 1-6) :**

| Id | Nom | Prenom | Naissance | Sexe | Ville |
|----|-----|--------|-----------|:----:|-------|
| 1 | BENNANI | Youssef | 1985-03-15 | M | Casablanca |
| 2 | ALAOUI | Fatima | 1990-07-22 | F | Casablanca |
| 3 | TAZI | Ahmed | 1978-11-03 | M | Casablanca |
| 4 | CHRAIBI | Amina | 1995-01-10 | F | Casablanca |
| 5 | IDRISSI | Karim | 1982-06-18 | M | Casablanca |
| 6 | FASSI | Nadia | 1988-09-25 | F | Casablanca |

**Rabat (IdPatient 7-12) :**

| Id | Nom | Prenom | Naissance | Sexe | Ville |
|----|-----|--------|-----------|:----:|-------|
| 7 | BENKIRANE | Omar | 1983-04-12 | M | Rabat |
| 8 | SQALLI | Houda | 1991-02-28 | F | Rabat |
| 9 | BERRADA | Mehdi | 1975-08-05 | M | Rabat |
| 10 | LAHLOU | Salma | 1993-12-17 | F | Rabat |
| 11 | ZOUITEN | Rachid | 1980-05-30 | M | Rabat |
| 12 | KETTANI | Zineb | 1987-10-14 | F | Rabat |

### 7.3 Donnees des medecins

| Id | Nom | Specialite | Ville |
|----|-----|-----------|-------|
| 1 | Dr. BELKADI Hassan | Generaliste | Casablanca |
| 2 | Dr. MANSOURI Leila | Cardiologue | Casablanca |
| 3 | Dr. RAMI Said | Dermatologue | Casablanca |
| 4 | Dr. OUAZZANI Nora | Generaliste | Rabat |
| 5 | Dr. FILALI Amine | Pneumologue | Rabat |
| 6 | Dr. HAJJI Samira | Gynecologue | Rabat |

### 7.4 Catalogue des medicaments

| Id | Nom | Forme | Dosage | Prix (DH) | Fabricant | Production |
|----|-----|-------|--------|:---------:|-----------|-----------|
| 1 | Doliprane | Comprime | 1000mg | 15.00 | Sanofi | Casablanca |
| 2 | Amoxicilline | Gelule | 500mg | 35.00 | Pharma5 | Casablanca |
| 3 | Omeprazole | Gelule | 20mg | 42.00 | Maphar | Casablanca |
| 4 | Augmentin | Comprime | 1g | 85.00 | GSK | Rabat |
| 5 | Ventoline | Inhalateur | 100mcg | 55.00 | GSK | Rabat |
| 6 | Metformine | Comprime | 850mg | 28.00 | Sanofi | Casablanca |
| 7 | Ibuprofene | Comprime | 400mg | 18.00 | Cooper | Rabat |
| 8 | Losartan | Comprime | 50mg | 65.00 | Pharma5 | Casablanca |
| 9 | Paracetamol | Sirop | 120mg/5ml | 22.00 | Cooper | Rabat |
| 10 | Ciprofloxacine | Comprime | 500mg | 48.00 | Maphar | Casablanca |

*Rappel : les colonnes Id/Nom/Forme/Dosage sont dans **Medicament_Base** (S1), et les colonnes Id/Prix/Fabricant/Production sont dans **Medicament_Commercial** (S2).*

### 7.5 Particularites du jeu de donnees

- **Ventes cross-site** : le patient 7 (Rabat) effectue un achat a la pharmacie de Casablanca (vente 9 sur S1). Le patient 1 (Casablanca) effectue un achat a Rabat (vente 16 sur S2). Ces cas permettent de tester la requete 9.

- **Stocks en alerte** : trois entrees de stock sont en dessous du seuil d'alerte pour tester la requete 7 :
  - Ventoline a Casablanca : 3 unites (seuil : 5)
  - Ibuprofene a Casablanca : 5 unites (seuil : 10)
  - Omeprazole a Rabat : 8 unites (seuil : 10)

- **Coherence referentielle** : toutes les contraintes sont respectees. Un patient existe toujours avant sa consultation, une consultation avant sa prescription, et les medicaments references dans les lignes existent dans le catalogue.

<div style="page-break-after: always;"></div>

---

## 8. Requetes reparties

Les 10 requetes ci-dessous sont implementees dans le fichier `06_requetes.sql`. Elles utilisent les vues globales (`v_*`) et peuvent etre executees indifferemment depuis S1 ou S2, sauf precision contraire.

### Requete 1 - Patients du site de Casablanca

**Site d'execution optimal** : S1 (acces local uniquement)

```sql
SELECT IdPatient, Nom, Prenom, DateNaissance, Sexe, Adresse, Ville, Telephone
FROM Patient;
```

Cette requete accede directement a la table locale `Patient` sur S1, sans solliciter le site distant. C'est l'illustration du gain de performance de la fragmentation horizontale.

### Requete 2 - Medicaments au prix unitaire maximal

**Site d'execution** : S1 ou S2 (requete repartie, jointure verticale)

```sql
SELECT m.IdMedicament, m.NomMedicament, m.Forme, m.Dosage,
       m.PrixUnitaire, m.Fabricant, m.VilleProduction
FROM v_Medicament m
WHERE m.PrixUnitaire = (SELECT MAX(PrixUnitaire) FROM v_Medicament);
```

**Resultat attendu** : Augmentin (85.00 DH). Cette requete implique une jointure distante entre les deux fragments verticaux du medicament.

### Requete 3 - Consultations d'un patient donne avec le nom du medecin

**Site d'execution** : S1 ou S2 (requete repartie)

```sql
SELECT c.IdConsultation, c.DateConsultation, c.Diagnostic,
       p.Nom AS NomPatient, p.Prenom AS PrenomPatient,
       m.NomMedecin, m.Specialite
FROM v_Consultation c
JOIN v_Patient p ON c.IdPatient = p.IdPatient
JOIN v_Medecin m ON c.IdMedecin = m.IdMedecin
WHERE c.IdPatient = 1;
```

### Requete 4 - Medicaments prescrits lors d'une consultation donnee

**Site d'execution** : S1 ou S2 (requete repartie)

```sql
SELECT med.IdMedicament, med.NomMedicament, med.Forme, med.Dosage,
       lp.Quantite, lp.Posologie
FROM v_Prescription p
JOIN v_LignePrescription lp ON p.IdPrescription = lp.IdPrescription
JOIN v_Medicament med ON lp.IdMedicament = med.IdMedicament
WHERE p.IdConsultation = 1;
```

**Resultat attendu** : Doliprane 1000mg (x2) et Amoxicilline 500mg (x1).

### Requete 5 - Chiffre d'affaires total par ville

**Site d'execution** : S1 ou S2 (agregation repartie)

```sql
SELECT Ville, SUM(MontantTotal) AS ChiffreAffaires, COUNT(IdVente) AS NombreVentes
FROM v_Vente
GROUP BY Ville
ORDER BY ChiffreAffaires DESC;
```

**Resultat attendu** : Casablanca ~434 DH (9 ventes), Rabat ~417 DH (7 ventes).

### Requete 6 - Medicament le plus vendu sur l'ensemble du reseau

**Site d'execution** : S1 ou S2 (requete repartie)

```sql
SELECT med.IdMedicament, med.NomMedicament, SUM(lv.Quantite) AS TotalQuantiteVendue
FROM v_LigneVente lv
JOIN v_Medicament med ON lv.IdMedicament = med.IdMedicament
GROUP BY med.IdMedicament, med.NomMedicament
ORDER BY TotalQuantiteVendue DESC
LIMIT 1;
```

**Resultat attendu** : Amoxicilline avec 5 unites vendues au total (les deux sites confondus).

### Requete 7 - Medicaments dont le stock est inferieur au seuil d'alerte

**Site d'execution** : S1 ou S2 (requete repartie)

```sql
SELECT s.IdStock, med.NomMedicament, med.Forme,
       s.Ville, s.QuantiteDisponible, s.SeuilAlerte,
       (s.SeuilAlerte - s.QuantiteDisponible) AS Deficit
FROM v_Stock s
JOIN v_Medicament med ON s.IdMedicament = med.IdMedicament
WHERE s.QuantiteDisponible < s.SeuilAlerte
ORDER BY Deficit DESC;
```

**Resultat attendu** : Ibuprofene (Casa, deficit 5), Ventoline (Casa, deficit 2), Omeprazole (Rabat, deficit 2).

### Requete 8 - Nombre total de consultations par medecin

**Site d'execution** : S1 ou S2 (requete repartie)

```sql
SELECT m.IdMedecin, m.NomMedecin, m.Specialite, m.Ville,
       COUNT(c.IdConsultation) AS NbConsultations
FROM v_Medecin m
LEFT JOIN v_Consultation c ON m.IdMedecin = c.IdMedecin
GROUP BY m.IdMedecin, m.NomMedecin, m.Specialite, m.Ville
ORDER BY NbConsultations DESC;
```

**Resultat attendu** : chaque medecin a realise 2 consultations.

### Requete 9 - Patients ayant consulte dans une ville et achete dans l'autre

**Site d'execution** : S1 ou S2 (requete repartie cross-site)

```sql
SELECT DISTINCT p.IdPatient, p.Nom, p.Prenom, p.Ville AS VilleResidence,
       m.Ville AS VilleConsultation, v.Ville AS VilleAchat
FROM v_Patient p
JOIN v_Consultation c ON p.IdPatient = c.IdPatient
JOIN v_Medecin m ON c.IdMedecin = m.IdMedecin
JOIN v_Vente v ON p.IdPatient = v.IdPatient
WHERE m.Ville <> v.Ville;
```

**Resultat attendu** : Patient 1 (BENNANI, consultation a Casa, achat a Rabat) et Patient 7 (BENKIRANE, consultation a Rabat, achat a Casa).

### Requete 10 - Patients ayant achete un medicament prescrit

**Site d'execution** : S1 ou S2 (requete repartie cross-site)

```sql
SELECT DISTINCT p.IdPatient, p.Nom, p.Prenom, p.Ville
FROM v_Patient p
JOIN v_Consultation c ON p.IdPatient = c.IdPatient
JOIN v_Prescription pr ON c.IdConsultation = pr.IdConsultation
JOIN v_LignePrescription lp ON pr.IdPrescription = lp.IdPrescription
JOIN v_Vente v ON p.IdPatient = v.IdPatient
JOIN v_LigneVente lv ON v.IdVente = lv.IdVente
WHERE lp.IdMedicament = lv.IdMedicament
ORDER BY p.IdPatient;
```

Cette requete croise les tables de prescriptions et de ventes pour trouver les patients ayant achete au moins un medicament qui figurait dans leur ordonnance. Elle implique 6 jointures a travers les vues globales.

*[Captures d'ecran des resultats de chaque requete]*

<div style="page-break-after: always;"></div>

---

## 9. Analyse critique

### 9.1 Avantages de notre solution

**Transparence d'acces** : grace aux vues globales et aux triggers d'insertion, l'utilisateur final manipule les donnees comme si elles etaient centralisees dans une seule base. Il n'a pas besoin de connaitre la localisation physique des donnees. Cette transparence est l'un des objectifs fondamentaux des BDR (cf. chapitre 4).

**Performance locale** : les operations courantes (consultation de dossier patient, enregistrement de vente, verification de stock) accedent uniquement aux donnees locales. La requete 1 illustre parfaitement ce gain : lister les patients de Casablanca depuis S1 n'implique aucun acces distant.

**Autonomie des sites** : chaque site gere ses propres donnees de maniere independante. Un administrateur local peut effectuer des sauvegardes ou de la maintenance sans impacter l'autre site. Cette autonomie est cruciale pour une entreprise multi-sites.

**Coherence de la fragmentation** : les contraintes `CHECK` sur la colonne Ville garantissent que chaque fragment respecte sa regle de fragmentation. Une tentative d'insertion d'un patient avec `Ville = 'Casablanca'` directement dans la table Patient de S2 sera rejetee par la base de donnees.

**Extensibilite du modele** : l'architecture peut etre etendue a de nouveaux sites grace a sa conception modulaire. L'ajout d'un site S3 (Marrakech) ne necessite pas de modification des sites existants, uniquement l'ajout de nouvelles liaisons FDW et l'extension des vues.

**Fragmentation verticale pertinente** : la separation du catalogue de medicaments en informations pharmaceutiques (Medicament_Base) et commerciales (Medicament_Commercial) correspond a une realite metier. Les medecins n'ont pas besoin du prix, et les pharmaciens n'ont pas besoin du dosage detaille lors des ventes.

### 9.2 Points faibles et limitations

**Absence de replication** : aucune donnee n'est repliquee entre les sites. Si un site tombe en panne, ses donnees locales deviennent inaccessibles, et les vues globales de l'autre site retournent des erreurs pour toute requete impliquant des tables distantes.

**Contraintes d'integrite cross-site** : les cles etrangeres ne peuvent pas etre appliquees entre deux bases distinctes avec `postgres_fdw`. Par exemple, rien n'empeche techniquement d'inserer une vente referencant un `IdPatient` inexistant sur l'autre site. La coherence referentielle inter-sites repose entierement sur la logique applicative.

**Performances des requetes globales** : les requetes utilisant les vues globales (UNION ALL + tables distantes) necessitent des acces reseau. La requete 10 par exemple, avec ses 6 jointures a travers des vues globales, peut etre couteuse en termes de transfert de donnees. L'optimiseur de PostgreSQL a des capacites limitees pour optimiser les requetes impliquant des tables etrangeres.

**Absence de transactions distribuees** : `postgres_fdw` ne supporte pas nativement le protocole **2PC** (Two-Phase Commit). L'insertion dans `v_Medicament` (qui ecrit simultanement sur S1 et S2) n'est pas atomique au sens strict. Si l'insertion dans Medicament_Base reussit mais que celle dans Medicament_Commercial echoue (panne reseau), les donnees seront dans un etat incoherent.

**Coordination des identifiants** : les cles primaires doivent etre coordonnees entre les sites pour eviter les collisions. Nous avons utilise des plages d'IDs disjointes (patients 1-6 sur S1, 7-12 sur S2), mais ce mecanisme est manuel et fragile a long terme. Une solution plus robuste utiliserait des sequences coordonnees ou des UUIDs.

### 9.3 Que se passerait-il si un site devenait indisponible ?

Prenons le scenario ou le **site S2 (Rabat)** devient indisponible :

**Impact sur les operations locales de S1** : les tables locales de Casablanca restent pleinement fonctionnelles. Les patients, medecins, consultations, stocks et ventes de Casablanca sont accessibles normalement. Les requetes purement locales (requete 1) continuent de fonctionner.

**Impact sur les vues globales de S1** : toute requete accedant a une table etrangere hebergee sur S2 (Patient_Rabat, Vente_Rabat, Medicament_Commercial, etc.) echoue avec une erreur de connexion. Les vues globales deviennent inutilisables pour toutes les requetes necessitant des donnees de Rabat.

**Impact critique sur v_Medicament** : cette vue est systematiquement impactee car elle joint Medicament_Base (local sur S1) avec Medicament_Commercial (distant sur S2). Sans S2, aucune information complete sur les medicaments n'est disponible depuis S1. Cela bloque les ventes et les prescriptions qui necessitent le prix ou le nom complet du medicament.

**Solutions envisageables** :
- **Replication du catalogue de medicaments** : repliquer Medicament_Base et Medicament_Commercial sur les deux sites. Cela eliminerait la dependance inter-sites pour cette table critique.
- **Mecanisme de fallback** : creer des vues avec gestion d'erreur qui retournent les donnees locales meme si le site distant est indisponible.
- **Haute disponibilite** : utiliser des outils comme **pgpool-II** ou **Patroni** pour mettre en place un basculement automatique (failover).

### 9.4 Que changerait l'ajout d'un troisieme site ?

L'ajout d'un site S3 (par exemple **Marrakech**) impliquerait les changements suivants :

**1. Nouvelle base de donnees** : creation de `site_marrakech` avec les memes tables locales fragmentees, incluant la contrainte `CHECK (Ville = 'Marrakech')`.

**2. Connexions FDW supplementaires** : chaque site doit maintenant se connecter aux deux autres. Le nombre de connexions FDW passe de 2 (S1<->S2) a 6 (S1<->S2, S1<->S3, S2<->S3). De maniere generale, pour *n* sites, il faut *n*(n-1)* connexions unidirectionnelles, soit une croissance en O(n^2).

**3. Extension des vues globales** :
```sql
CREATE VIEW v_Patient AS
    SELECT * FROM Patient              -- local
    UNION ALL
    SELECT * FROM Patient_Rabat        -- distant S2
    UNION ALL
    SELECT * FROM Patient_Marrakech;   -- distant S3
```

**4. Modification des triggers d'insertion** : les fonctions d'insertion transparente doivent gerer une troisieme ville dans la clause conditionnelle.

**5. Reorganisation de la fragmentation verticale** : le catalogue de medicaments etant reparti entre S1 et S2, l'ajout d'un S3 pose la question de l'acces au catalogue depuis ce nouveau site. Une solution serait de **repliquer** le catalogue complet sur chaque site, transformant la fragmentation verticale en replication.

**6. Complexite de gestion accrue** : la maintenance, la coordination des identifiants et la gestion des pannes deviennent plus complexes. A partir de 3 sites et plus, une solution de middleware de type **Citus** (extension PostgreSQL pour le sharding distribue) ou **pgpool-II** serait recommandee pour gerer automatiquement le routage et la coordination.

<div style="page-break-after: always;"></div>

---

## 10. Conclusion

Ce projet nous a permis de mettre en pratique les concepts fondamentaux des bases de donnees reparties, de la conception theorique a l'implementation technique.

La **conception descendante** (schema global -> fragmentation -> allocation) a guide notre demarche de maniere structuree et methodique. Partir d'un schema global unifie de 9 tables, puis le decomposer en fragments distribues sur deux sites, nous a permis de comprendre concretement les enjeux de la repartition des donnees.

La **fragmentation horizontale** par ville s'est revelee naturelle et tres efficace pour les tables comportant un attribut de localisation geographique (Patient, Medecin, Stock, Vente). Elle correspond parfaitement au besoin d'autonomie locale de chaque site.

La **fragmentation verticale** du catalogue de medicaments illustre un cas d'usage plus subtil : la separation des preoccupations entre donnees pharmaceutiques et donnees commerciales, avec une reconstruction transparente par jointure entre les deux sites.

L'extension **postgres_fdw** s'est montree suffisante pour simuler un environnement reparti, offrant une transparence d'acces grace aux vues globales et aux triggers d'insertion. L'utilisation de Docker Compose pour simuler deux instances PostgreSQL independantes a permis de reproduire de maniere realiste un environnement multi-sites.

Les **limites identifiees** (absence de 2PC, pas de replication native, impossibilite des FK cross-site, performances des jointures distantes) correspondent aux defis reels des bases de donnees reparties tels que presentes dans le chapitre 4 du cours. Ces limites montrent que la mise en oeuvre d'une BDR necessite des compromis entre performance, coherence et disponibilite, conformement au theoreme CAP.

En conclusion, cette implementation demontre qu'une base de donnees repartie offre des avantages significatifs en termes de performance locale, d'autonomie des sites et de transparence d'acces, au prix d'une complexite de gestion accrue en matiere de coherence transactionnelle et de tolerance aux pannes.

<div style="page-break-after: always;"></div>

---

## 11. Annexes

### Annexe A - Scripts SQL fournis

| Fichier | Description |
|---------|------------|
| `01_schema_global.sql` | Schema conceptuel global de reference (9 tables avec PKs et FKs) |
| `02_fragmentation_s1.sql` | Creation des fragments, FDW, vues et triggers sur S1 (Casablanca) |
| `03_fragmentation_s2.sql` | Creation des fragments, FDW, vues et triggers sur S2 (Rabat) |
| `04_donnees_s1.sql` | Jeu de donnees pour le site S1 |
| `05_donnees_s2.sql` | Jeu de donnees pour le site S2 |
| `06_requetes.sql` | 10 requetes reparties avec site d'execution indique |

### Annexe B - Deploiement avec Docker Compose

Le projet inclut un fichier `docker-compose.yml` permettant de deployer automatiquement les deux sites :

```bash
# Demarrage des deux sites + configuration automatique
docker compose up -d

# Connexion au site Casablanca
psql -h localhost -p 5433 -U postgres -d site_casablanca

# Connexion au site Rabat
psql -h localhost -p 5434 -U postgres -d site_rabat

# Execution des requetes depuis S1
psql -h localhost -p 5433 -U postgres -d site_casablanca -f 06_requetes.sql

# Arret et nettoyage
docker compose down -v
```

### Annexe C - Deploiement sans Docker (PostgreSQL local)

```bash
# 1. Creer les bases de donnees
psql -U postgres -c "CREATE DATABASE site_casablanca;"
psql -U postgres -c "CREATE DATABASE site_rabat;"

# 2. Creer les structures sur chaque site
psql -U postgres -d site_casablanca -f 02_fragmentation_s1.sql
psql -U postgres -d site_rabat     -f 03_fragmentation_s2.sql

# 3. Inserer les donnees
psql -U postgres -d site_casablanca -f 04_donnees_s1.sql
psql -U postgres -d site_rabat     -f 05_donnees_s2.sql

# 4. Executer les requetes
psql -U postgres -d site_casablanca -f 06_requetes.sql
```
