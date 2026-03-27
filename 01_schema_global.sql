-- ============================================================
-- SCHEMA GLOBAL CONCEPTUEL
-- Base de donnees repartie pour la gestion d'une chaine
-- de pharmacies / cliniques sur deux villes
-- ============================================================
-- Sites : S1 (Casablanca) et S2 (Rabat)
--
-- Ce script definit le schema relationnel global unifie,
-- avant toute fragmentation ou allocation.
-- Il sert de reference pour la conception descendante.
-- ============================================================

-- PREREQUIS : Creer les deux bases de donnees (en tant que superutilisateur)
-- CREATE DATABASE site_casablanca;
-- CREATE DATABASE site_rabat;

-- ============================================================
-- Nettoyage (si re-execution)
-- ============================================================
DROP TABLE IF EXISTS LigneVente CASCADE;
DROP TABLE IF EXISTS LignePrescription CASCADE;
DROP TABLE IF EXISTS Vente CASCADE;
DROP TABLE IF EXISTS Stock CASCADE;
DROP TABLE IF EXISTS Prescription CASCADE;
DROP TABLE IF EXISTS Consultation CASCADE;
DROP TABLE IF EXISTS Medicament CASCADE;
DROP TABLE IF EXISTS Medecin CASCADE;
DROP TABLE IF EXISTS Patient CASCADE;

-- ============================================================
-- TABLE : Patient
-- Cle primaire : IdPatient
-- ============================================================
CREATE TABLE Patient (
    IdPatient       INT             PRIMARY KEY,
    Nom             VARCHAR(50)     NOT NULL,
    Prenom          VARCHAR(50)     NOT NULL,
    DateNaissance   DATE            NOT NULL,
    Sexe            CHAR(1)         NOT NULL CHECK (Sexe IN ('M', 'F')),
    Adresse         VARCHAR(200),
    Ville           VARCHAR(50)     NOT NULL,
    Telephone       VARCHAR(20)
);

-- ============================================================
-- TABLE : Medecin
-- Cle primaire : IdMedecin
-- ============================================================
CREATE TABLE Medecin (
    IdMedecin       INT             PRIMARY KEY,
    NomMedecin      VARCHAR(100)    NOT NULL,
    Specialite      VARCHAR(50)     NOT NULL,
    Ville           VARCHAR(50)     NOT NULL,
    Telephone       VARCHAR(20)
);

-- ============================================================
-- TABLE : Consultation
-- Cle primaire : IdConsultation
-- Cles etrangeres : IdPatient -> Patient, IdMedecin -> Medecin
-- ============================================================
CREATE TABLE Consultation (
    IdConsultation  INT             PRIMARY KEY,
    DateConsultation DATE           NOT NULL,
    Diagnostic      TEXT,
    IdPatient       INT             NOT NULL REFERENCES Patient(IdPatient),
    IdMedecin       INT             NOT NULL REFERENCES Medecin(IdMedecin)
);

-- ============================================================
-- TABLE : Prescription
-- Cle primaire : IdPrescription
-- Cle etrangere : IdConsultation -> Consultation (relation 1:1)
-- ============================================================
CREATE TABLE Prescription (
    IdPrescription  INT             PRIMARY KEY,
    DatePrescription DATE           NOT NULL,
    IdConsultation  INT             NOT NULL UNIQUE
                                    REFERENCES Consultation(IdConsultation)
);

-- ============================================================
-- TABLE : Medicament
-- Cle primaire : IdMedicament
-- ============================================================
CREATE TABLE Medicament (
    IdMedicament    INT             PRIMARY KEY,
    NomMedicament   VARCHAR(100)    NOT NULL,
    Forme           VARCHAR(50)     NOT NULL,
    Dosage          VARCHAR(50),
    PrixUnitaire    DECIMAL(10,2)   NOT NULL,
    Fabricant       VARCHAR(100),
    VilleProduction VARCHAR(50)
);

-- ============================================================
-- TABLE : LignePrescription
-- Cle primaire composee : (IdPrescription, IdMedicament)
-- Cles etrangeres : IdPrescription -> Prescription,
--                   IdMedicament   -> Medicament
-- ============================================================
CREATE TABLE LignePrescription (
    IdPrescription  INT             NOT NULL REFERENCES Prescription(IdPrescription),
    IdMedicament    INT             NOT NULL REFERENCES Medicament(IdMedicament),
    Quantite        INT             NOT NULL DEFAULT 1,
    Posologie       VARCHAR(200),
    PRIMARY KEY (IdPrescription, IdMedicament)
);

-- ============================================================
-- TABLE : Stock
-- Cle primaire : IdStock
-- Cle etrangere : IdMedicament -> Medicament
-- Contrainte d'unicite : (IdMedicament, Ville)
-- ============================================================
CREATE TABLE Stock (
    IdStock             INT             PRIMARY KEY,
    IdMedicament        INT             NOT NULL REFERENCES Medicament(IdMedicament),
    Ville               VARCHAR(50)     NOT NULL,
    QuantiteDisponible  INT             NOT NULL DEFAULT 0,
    SeuilAlerte         INT             NOT NULL DEFAULT 10,
    UNIQUE (IdMedicament, Ville)
);

-- ============================================================
-- TABLE : Vente
-- Cle primaire : IdVente
-- Cle etrangere : IdPatient -> Patient
-- ============================================================
CREATE TABLE Vente (
    IdVente         INT             PRIMARY KEY,
    DateVente       DATE            NOT NULL,
    Ville           VARCHAR(50)     NOT NULL,
    IdPatient       INT             NOT NULL REFERENCES Patient(IdPatient),
    MontantTotal    DECIMAL(10,2)   NOT NULL
);

-- ============================================================
-- TABLE : LigneVente
-- Cle primaire composee : (IdVente, IdMedicament)
-- Cles etrangeres : IdVente -> Vente, IdMedicament -> Medicament
-- ============================================================
CREATE TABLE LigneVente (
    IdVente         INT             NOT NULL REFERENCES Vente(IdVente),
    IdMedicament    INT             NOT NULL REFERENCES Medicament(IdMedicament),
    Quantite        INT             NOT NULL DEFAULT 1,
    PrixVente       DECIMAL(10,2)   NOT NULL,
    PRIMARY KEY (IdVente, IdMedicament)
);
