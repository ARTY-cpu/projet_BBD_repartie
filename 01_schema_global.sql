-- Schema global conceptuel - avant fragmentation
-- S1 = Casablanca, S2 = Rabat
--
-- Pour creer les bases (en superutilisateur) :
--   CREATE DATABASE site_casablanca;
--   CREATE DATABASE site_rabat;

-- Nettoyage si re-execution
DROP TABLE IF EXISTS LigneVente CASCADE;
DROP TABLE IF EXISTS LignePrescription CASCADE;
DROP TABLE IF EXISTS Vente CASCADE;
DROP TABLE IF EXISTS Stock CASCADE;
DROP TABLE IF EXISTS Prescription CASCADE;
DROP TABLE IF EXISTS Consultation CASCADE;
DROP TABLE IF EXISTS Medicament CASCADE;
DROP TABLE IF EXISTS Medecin CASCADE;
DROP TABLE IF EXISTS Patient CASCADE;

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

CREATE TABLE Medecin (
    IdMedecin       INT             PRIMARY KEY,
    NomMedecin      VARCHAR(100)    NOT NULL,
    Specialite      VARCHAR(50)     NOT NULL,
    Ville           VARCHAR(50)     NOT NULL,
    Telephone       VARCHAR(20)
);

-- IdPatient sans FK ici car dans la version repartie un patient peut consulter
-- un medecin dans l'autre ville (acces via FDW)
CREATE TABLE Consultation (
    IdConsultation  INT             PRIMARY KEY,
    DateConsultation DATE           NOT NULL,
    Diagnostic      TEXT,
    IdPatient       INT             NOT NULL REFERENCES Patient(IdPatient),
    IdMedecin       INT             NOT NULL REFERENCES Medecin(IdMedecin)
);

-- 1 consultation = au plus 1 prescription (UNIQUE sur IdConsultation)
CREATE TABLE Prescription (
    IdPrescription  INT             PRIMARY KEY,
    DatePrescription DATE           NOT NULL,
    IdConsultation  INT             NOT NULL UNIQUE
                                    REFERENCES Consultation(IdConsultation)
);

-- Dans la version repartie, cette table sera fragmentee verticalement :
--   Medicament_Base (S1) pour les infos pharma, Medicament_Commercial (S2) pour le prix/fabricant
CREATE TABLE Medicament (
    IdMedicament    INT             PRIMARY KEY,
    NomMedicament   VARCHAR(100)    NOT NULL,
    Forme           VARCHAR(50)     NOT NULL,
    Dosage          VARCHAR(50),
    PrixUnitaire    DECIMAL(10,2)   NOT NULL,
    Fabricant       VARCHAR(100),
    VilleProduction VARCHAR(50)
);

CREATE TABLE LignePrescription (
    IdPrescription  INT             NOT NULL REFERENCES Prescription(IdPrescription),
    IdMedicament    INT             NOT NULL REFERENCES Medicament(IdMedicament),
    Quantite        INT             NOT NULL DEFAULT 1,
    Posologie       VARCHAR(200),
    PRIMARY KEY (IdPrescription, IdMedicament)
);

-- Pas de UNIQUE(IdMedicament, Ville) dans la version repartie car chaque site
-- ne stocke que sa propre ville
CREATE TABLE Stock (
    IdStock             INT             PRIMARY KEY,
    IdMedicament        INT             NOT NULL REFERENCES Medicament(IdMedicament),
    Ville               VARCHAR(50)     NOT NULL,
    QuantiteDisponible  INT             NOT NULL DEFAULT 0,
    SeuilAlerte         INT             NOT NULL DEFAULT 10,
    UNIQUE (IdMedicament, Ville)
);

CREATE TABLE Vente (
    IdVente         INT             PRIMARY KEY,
    DateVente       DATE            NOT NULL,
    Ville           VARCHAR(50)     NOT NULL,
    IdPatient       INT             NOT NULL REFERENCES Patient(IdPatient),
    MontantTotal    DECIMAL(10,2)   NOT NULL
);

CREATE TABLE LigneVente (
    IdVente         INT             NOT NULL REFERENCES Vente(IdVente),
    IdMedicament    INT             NOT NULL REFERENCES Medicament(IdMedicament),
    Quantite        INT             NOT NULL DEFAULT 1,
    PrixVente       DECIMAL(10,2)   NOT NULL,
    PRIMARY KEY (IdVente, IdMedicament)
);
