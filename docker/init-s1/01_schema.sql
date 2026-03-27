-- ============================================================
-- SITE S1 - CASABLANCA : Tables locales
-- Execute automatiquement au demarrage du conteneur
-- ============================================================

CREATE TABLE Patient (
    IdPatient       INT             PRIMARY KEY,
    Nom             VARCHAR(50)     NOT NULL,
    Prenom          VARCHAR(50)     NOT NULL,
    DateNaissance   DATE            NOT NULL,
    Sexe            CHAR(1)         NOT NULL CHECK (Sexe IN ('M', 'F')),
    Adresse         VARCHAR(200),
    Ville           VARCHAR(50)     NOT NULL DEFAULT 'Casablanca'
                                    CHECK (Ville = 'Casablanca'),
    Telephone       VARCHAR(20)
);

CREATE TABLE Medecin (
    IdMedecin       INT             PRIMARY KEY,
    NomMedecin      VARCHAR(100)    NOT NULL,
    Specialite      VARCHAR(50)     NOT NULL,
    Ville           VARCHAR(50)     NOT NULL DEFAULT 'Casablanca'
                                    CHECK (Ville = 'Casablanca'),
    Telephone       VARCHAR(20)
);

CREATE TABLE Consultation (
    IdConsultation  INT             PRIMARY KEY,
    DateConsultation DATE           NOT NULL,
    Diagnostic      TEXT,
    IdPatient       INT             NOT NULL,
    IdMedecin       INT             NOT NULL REFERENCES Medecin(IdMedecin)
);

CREATE TABLE Prescription (
    IdPrescription  INT             PRIMARY KEY,
    DatePrescription DATE           NOT NULL,
    IdConsultation  INT             NOT NULL UNIQUE
                                    REFERENCES Consultation(IdConsultation)
);

CREATE TABLE Medicament_Base (
    IdMedicament    INT             PRIMARY KEY,
    NomMedicament   VARCHAR(100)    NOT NULL,
    Forme           VARCHAR(50)     NOT NULL,
    Dosage          VARCHAR(50)
);

CREATE TABLE LignePrescription (
    IdPrescription  INT             NOT NULL REFERENCES Prescription(IdPrescription),
    IdMedicament    INT             NOT NULL REFERENCES Medicament_Base(IdMedicament),
    Quantite        INT             NOT NULL DEFAULT 1,
    Posologie       VARCHAR(200),
    PRIMARY KEY (IdPrescription, IdMedicament)
);

CREATE TABLE Stock (
    IdStock             INT             PRIMARY KEY,
    IdMedicament        INT             NOT NULL REFERENCES Medicament_Base(IdMedicament),
    Ville               VARCHAR(50)     NOT NULL DEFAULT 'Casablanca'
                                        CHECK (Ville = 'Casablanca'),
    QuantiteDisponible  INT             NOT NULL DEFAULT 0,
    SeuilAlerte         INT             NOT NULL DEFAULT 10
);

CREATE TABLE Vente (
    IdVente         INT             PRIMARY KEY,
    DateVente       DATE            NOT NULL,
    Ville           VARCHAR(50)     NOT NULL DEFAULT 'Casablanca'
                                    CHECK (Ville = 'Casablanca'),
    IdPatient       INT             NOT NULL,
    MontantTotal    DECIMAL(10,2)   NOT NULL
);

CREATE TABLE LigneVente (
    IdVente         INT             NOT NULL REFERENCES Vente(IdVente),
    IdMedicament    INT             NOT NULL REFERENCES Medicament_Base(IdMedicament),
    Quantite        INT             NOT NULL DEFAULT 1,
    PrixVente       DECIMAL(10,2)   NOT NULL,
    PRIMARY KEY (IdVente, IdMedicament)
);
