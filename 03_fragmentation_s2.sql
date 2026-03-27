-- ============================================================
-- SITE S2 - RABAT
-- Script de fragmentation, configuration FDW, vues globales
-- ============================================================
-- Connexion prealable : \c site_rabat
-- ============================================================

-- ============================================================
-- NETTOYAGE
-- ============================================================
DROP TRIGGER IF EXISTS trg_insert_v_patient ON v_patient;
DROP TRIGGER IF EXISTS trg_insert_v_vente ON v_vente;
DROP TRIGGER IF EXISTS trg_insert_v_medicament ON v_medicament;
DROP FUNCTION IF EXISTS fn_insert_patient();
DROP FUNCTION IF EXISTS fn_insert_vente();
DROP FUNCTION IF EXISTS fn_insert_medicament();

DROP VIEW IF EXISTS v_LigneVente CASCADE;
DROP VIEW IF EXISTS v_Vente CASCADE;
DROP VIEW IF EXISTS v_Stock CASCADE;
DROP VIEW IF EXISTS v_LignePrescription CASCADE;
DROP VIEW IF EXISTS v_Prescription CASCADE;
DROP VIEW IF EXISTS v_Consultation CASCADE;
DROP VIEW IF EXISTS v_Medicament CASCADE;
DROP VIEW IF EXISTS v_Medecin CASCADE;
DROP VIEW IF EXISTS v_Patient CASCADE;

DROP FOREIGN TABLE IF EXISTS LigneVente_Casa CASCADE;
DROP FOREIGN TABLE IF EXISTS Vente_Casa CASCADE;
DROP FOREIGN TABLE IF EXISTS Stock_Casa CASCADE;
DROP FOREIGN TABLE IF EXISTS LignePrescription_Casa CASCADE;
DROP FOREIGN TABLE IF EXISTS Prescription_Casa CASCADE;
DROP FOREIGN TABLE IF EXISTS Consultation_Casa CASCADE;
DROP FOREIGN TABLE IF EXISTS Medicament_Base CASCADE;
DROP FOREIGN TABLE IF EXISTS Medecin_Casa CASCADE;
DROP FOREIGN TABLE IF EXISTS Patient_Casa CASCADE;

DROP TABLE IF EXISTS LigneVente CASCADE;
DROP TABLE IF EXISTS Vente CASCADE;
DROP TABLE IF EXISTS Stock CASCADE;
DROP TABLE IF EXISTS LignePrescription CASCADE;
DROP TABLE IF EXISTS Prescription CASCADE;
DROP TABLE IF EXISTS Consultation CASCADE;
DROP TABLE IF EXISTS Medicament_Commercial CASCADE;
DROP TABLE IF EXISTS Medecin CASCADE;
DROP TABLE IF EXISTS Patient CASCADE;

DROP USER MAPPING IF EXISTS FOR CURRENT_USER SERVER site_casablanca;
DROP SERVER IF EXISTS site_casablanca CASCADE;
DROP EXTENSION IF EXISTS postgres_fdw CASCADE;

-- ============================================================
-- 1. TABLES LOCALES (Fragments de Rabat)
-- ============================================================

-- -------------------------------------------------------
-- Fragmentation HORIZONTALE de Patient (Ville = 'Rabat')
-- Critere : sigma(Ville='Rabat')(Patient)
-- -------------------------------------------------------
CREATE TABLE Patient (
    IdPatient       INT             PRIMARY KEY,
    Nom             VARCHAR(50)     NOT NULL,
    Prenom          VARCHAR(50)     NOT NULL,
    DateNaissance   DATE            NOT NULL,
    Sexe            CHAR(1)         NOT NULL CHECK (Sexe IN ('M', 'F')),
    Adresse         VARCHAR(200),
    Ville           VARCHAR(50)     NOT NULL DEFAULT 'Rabat'
                                    CHECK (Ville = 'Rabat'),
    Telephone       VARCHAR(20)
);

-- -------------------------------------------------------
-- Fragmentation HORIZONTALE de Medecin (Ville = 'Rabat')
-- Critere : sigma(Ville='Rabat')(Medecin)
-- -------------------------------------------------------
CREATE TABLE Medecin (
    IdMedecin       INT             PRIMARY KEY,
    NomMedecin      VARCHAR(100)    NOT NULL,
    Specialite      VARCHAR(50)     NOT NULL,
    Ville           VARCHAR(50)     NOT NULL DEFAULT 'Rabat'
                                    CHECK (Ville = 'Rabat'),
    Telephone       VARCHAR(20)
);

-- -------------------------------------------------------
-- Fragmentation horizontale DERIVEE de Consultation
-- Les consultations realisees par les medecins de Rabat
-- sont stockees sur S2.
-- Note : IdPatient sans FK locale car le patient peut venir de Casablanca
-- -------------------------------------------------------
CREATE TABLE Consultation (
    IdConsultation  INT             PRIMARY KEY,
    DateConsultation DATE           NOT NULL,
    Diagnostic      TEXT,
    IdPatient       INT             NOT NULL,
    IdMedecin       INT             NOT NULL REFERENCES Medecin(IdMedecin)
);

-- -------------------------------------------------------
-- Fragmentation derivee de Prescription (suit Consultation)
-- -------------------------------------------------------
CREATE TABLE Prescription (
    IdPrescription  INT             PRIMARY KEY,
    DatePrescription DATE           NOT NULL,
    IdConsultation  INT             NOT NULL UNIQUE
                                    REFERENCES Consultation(IdConsultation)
);

-- -------------------------------------------------------
-- Fragmentation VERTICALE de Medicament : fragment COMMERCIAL
-- Contient les informations commerciales et de fabrication
-- pi(IdMedicament, PrixUnitaire, Fabricant, VilleProduction)(Medicament) -> S2
-- -------------------------------------------------------
CREATE TABLE Medicament_Commercial (
    IdMedicament    INT             PRIMARY KEY,
    PrixUnitaire    DECIMAL(10,2)   NOT NULL,
    Fabricant       VARCHAR(100),
    VilleProduction VARCHAR(50)
);

-- -------------------------------------------------------
-- Fragmentation derivee de LignePrescription
-- -------------------------------------------------------
CREATE TABLE LignePrescription (
    IdPrescription  INT             NOT NULL REFERENCES Prescription(IdPrescription),
    IdMedicament    INT             NOT NULL REFERENCES Medicament_Commercial(IdMedicament),
    Quantite        INT             NOT NULL DEFAULT 1,
    Posologie       VARCHAR(200),
    PRIMARY KEY (IdPrescription, IdMedicament)
);

-- -------------------------------------------------------
-- Fragmentation HORIZONTALE de Stock (Ville = 'Rabat')
-- sigma(Ville='Rabat')(Stock)
-- -------------------------------------------------------
CREATE TABLE Stock (
    IdStock             INT             PRIMARY KEY,
    IdMedicament        INT             NOT NULL REFERENCES Medicament_Commercial(IdMedicament),
    Ville               VARCHAR(50)     NOT NULL DEFAULT 'Rabat'
                                        CHECK (Ville = 'Rabat'),
    QuantiteDisponible  INT             NOT NULL DEFAULT 0,
    SeuilAlerte         INT             NOT NULL DEFAULT 10
);

-- -------------------------------------------------------
-- Fragmentation HORIZONTALE de Vente (Ville = 'Rabat')
-- sigma(Ville='Rabat')(Vente)
-- Note : IdPatient sans FK car le patient peut provenir de Casablanca
-- -------------------------------------------------------
CREATE TABLE Vente (
    IdVente         INT             PRIMARY KEY,
    DateVente       DATE            NOT NULL,
    Ville           VARCHAR(50)     NOT NULL DEFAULT 'Rabat'
                                    CHECK (Ville = 'Rabat'),
    IdPatient       INT             NOT NULL,
    MontantTotal    DECIMAL(10,2)   NOT NULL
);

-- -------------------------------------------------------
-- Fragmentation derivee de LigneVente (suit Vente)
-- -------------------------------------------------------
CREATE TABLE LigneVente (
    IdVente         INT             NOT NULL REFERENCES Vente(IdVente),
    IdMedicament    INT             NOT NULL REFERENCES Medicament_Commercial(IdMedicament),
    Quantite        INT             NOT NULL DEFAULT 1,
    PrixVente       DECIMAL(10,2)   NOT NULL,
    PRIMARY KEY (IdVente, IdMedicament)
);

-- ============================================================
-- 2. CONFIGURATION postgres_fdw (acces au site distant S1)
-- ============================================================

CREATE EXTENSION IF NOT EXISTS postgres_fdw;

CREATE SERVER site_casablanca
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'localhost', port '5432', dbname 'site_casablanca');

-- Adapter user/password selon votre configuration
CREATE USER MAPPING FOR CURRENT_USER
    SERVER site_casablanca
    OPTIONS (user 'postgres', password 'postgres');

-- ============================================================
-- 3. TABLES DISTANTES (acces aux fragments de Casablanca via FDW)
-- ============================================================

CREATE FOREIGN TABLE Patient_Casa (
    IdPatient       INT,
    Nom             VARCHAR(50),
    Prenom          VARCHAR(50),
    DateNaissance   DATE,
    Sexe            CHAR(1),
    Adresse         VARCHAR(200),
    Ville           VARCHAR(50),
    Telephone       VARCHAR(20)
) SERVER site_casablanca OPTIONS (schema_name 'public', table_name 'patient');

CREATE FOREIGN TABLE Medecin_Casa (
    IdMedecin       INT,
    NomMedecin      VARCHAR(100),
    Specialite      VARCHAR(50),
    Ville           VARCHAR(50),
    Telephone       VARCHAR(20)
) SERVER site_casablanca OPTIONS (schema_name 'public', table_name 'medecin');

CREATE FOREIGN TABLE Consultation_Casa (
    IdConsultation  INT,
    DateConsultation DATE,
    Diagnostic      TEXT,
    IdPatient       INT,
    IdMedecin       INT
) SERVER site_casablanca OPTIONS (schema_name 'public', table_name 'consultation');

CREATE FOREIGN TABLE Prescription_Casa (
    IdPrescription  INT,
    DatePrescription DATE,
    IdConsultation  INT
) SERVER site_casablanca OPTIONS (schema_name 'public', table_name 'prescription');

CREATE FOREIGN TABLE LignePrescription_Casa (
    IdPrescription  INT,
    IdMedicament    INT,
    Quantite        INT,
    Posologie       VARCHAR(200)
) SERVER site_casablanca OPTIONS (schema_name 'public', table_name 'ligneprescription');

-- Fragment vertical distant : partie BASE (stockee sur S1)
CREATE FOREIGN TABLE Medicament_Base (
    IdMedicament    INT,
    NomMedicament   VARCHAR(100),
    Forme           VARCHAR(50),
    Dosage          VARCHAR(50)
) SERVER site_casablanca OPTIONS (schema_name 'public', table_name 'medicament_base');

CREATE FOREIGN TABLE Stock_Casa (
    IdStock             INT,
    IdMedicament        INT,
    Ville               VARCHAR(50),
    QuantiteDisponible  INT,
    SeuilAlerte         INT
) SERVER site_casablanca OPTIONS (schema_name 'public', table_name 'stock');

CREATE FOREIGN TABLE Vente_Casa (
    IdVente         INT,
    DateVente       DATE,
    Ville           VARCHAR(50),
    IdPatient       INT,
    MontantTotal    DECIMAL(10,2)
) SERVER site_casablanca OPTIONS (schema_name 'public', table_name 'vente');

CREATE FOREIGN TABLE LigneVente_Casa (
    IdVente         INT,
    IdMedicament    INT,
    Quantite        INT,
    PrixVente       DECIMAL(10,2)
) SERVER site_casablanca OPTIONS (schema_name 'public', table_name 'lignevente');

-- ============================================================
-- 4. VUES GLOBALES (reconstruction du schema global)
-- ============================================================

-- Reconstruction de Patient par UNION des fragments horizontaux
CREATE VIEW v_Patient AS
    SELECT IdPatient, Nom, Prenom, DateNaissance, Sexe, Adresse, Ville, Telephone
    FROM Patient
    UNION ALL
    SELECT IdPatient, Nom, Prenom, DateNaissance, Sexe, Adresse, Ville, Telephone
    FROM Patient_Casa;

-- Reconstruction de Medecin par UNION des fragments horizontaux
CREATE VIEW v_Medecin AS
    SELECT IdMedecin, NomMedecin, Specialite, Ville, Telephone
    FROM Medecin
    UNION ALL
    SELECT IdMedecin, NomMedecin, Specialite, Ville, Telephone
    FROM Medecin_Casa;

-- Reconstruction de Medicament par JOINTURE des fragments verticaux
-- Medicament_Base (distant S1) JOIN Medicament_Commercial (local S2)
CREATE VIEW v_Medicament AS
    SELECT b.IdMedicament, b.NomMedicament, b.Forme, b.Dosage,
           c.PrixUnitaire, c.Fabricant, c.VilleProduction
    FROM Medicament_Base b
    JOIN Medicament_Commercial c ON b.IdMedicament = c.IdMedicament;

-- Reconstruction de Consultation
CREATE VIEW v_Consultation AS
    SELECT IdConsultation, DateConsultation, Diagnostic, IdPatient, IdMedecin
    FROM Consultation
    UNION ALL
    SELECT IdConsultation, DateConsultation, Diagnostic, IdPatient, IdMedecin
    FROM Consultation_Casa;

-- Reconstruction de Prescription
CREATE VIEW v_Prescription AS
    SELECT IdPrescription, DatePrescription, IdConsultation
    FROM Prescription
    UNION ALL
    SELECT IdPrescription, DatePrescription, IdConsultation
    FROM Prescription_Casa;

-- Reconstruction de LignePrescription
CREATE VIEW v_LignePrescription AS
    SELECT IdPrescription, IdMedicament, Quantite, Posologie
    FROM LignePrescription
    UNION ALL
    SELECT IdPrescription, IdMedicament, Quantite, Posologie
    FROM LignePrescription_Casa;

-- Reconstruction de Stock
CREATE VIEW v_Stock AS
    SELECT IdStock, IdMedicament, Ville, QuantiteDisponible, SeuilAlerte
    FROM Stock
    UNION ALL
    SELECT IdStock, IdMedicament, Ville, QuantiteDisponible, SeuilAlerte
    FROM Stock_Casa;

-- Reconstruction de Vente
CREATE VIEW v_Vente AS
    SELECT IdVente, DateVente, Ville, IdPatient, MontantTotal
    FROM Vente
    UNION ALL
    SELECT IdVente, DateVente, Ville, IdPatient, MontantTotal
    FROM Vente_Casa;

-- Reconstruction de LigneVente
CREATE VIEW v_LigneVente AS
    SELECT IdVente, IdMedicament, Quantite, PrixVente
    FROM LigneVente
    UNION ALL
    SELECT IdVente, IdMedicament, Quantite, PrixVente
    FROM LigneVente_Casa;

-- ============================================================
-- 5. MECANISME D'INSERTION TRANSPARENTE (triggers INSTEAD OF)
-- ============================================================

-- -------------------------------------------------------
-- Insertion transparente dans v_Patient
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_insert_patient()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.Ville = 'Rabat' THEN
        INSERT INTO Patient VALUES (NEW.*);
    ELSIF NEW.Ville = 'Casablanca' THEN
        INSERT INTO Patient_Casa VALUES (NEW.*);
    ELSE
        RAISE EXCEPTION 'Ville non geree : %. Valeurs acceptees : Casablanca, Rabat', NEW.Ville;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_insert_v_patient
    INSTEAD OF INSERT ON v_Patient
    FOR EACH ROW EXECUTE FUNCTION fn_insert_patient();

-- -------------------------------------------------------
-- Insertion transparente dans v_Vente
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_insert_vente()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.Ville = 'Rabat' THEN
        INSERT INTO Vente VALUES (NEW.*);
    ELSIF NEW.Ville = 'Casablanca' THEN
        INSERT INTO Vente_Casa VALUES (NEW.*);
    ELSE
        RAISE EXCEPTION 'Ville non geree : %. Valeurs acceptees : Casablanca, Rabat', NEW.Ville;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_insert_v_vente
    INSTEAD OF INSERT ON v_Vente
    FOR EACH ROW EXECUTE FUNCTION fn_insert_vente();

-- -------------------------------------------------------
-- Insertion transparente dans v_Medicament
-- Insere simultanement dans les deux fragments verticaux :
--   Medicament_Commercial (local) et Medicament_Base (distant)
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_insert_medicament()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO Medicament_Commercial (IdMedicament, PrixUnitaire, Fabricant, VilleProduction)
    VALUES (NEW.IdMedicament, NEW.PrixUnitaire, NEW.Fabricant, NEW.VilleProduction);

    INSERT INTO Medicament_Base (IdMedicament, NomMedicament, Forme, Dosage)
    VALUES (NEW.IdMedicament, NEW.NomMedicament, NEW.Forme, NEW.Dosage);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_insert_v_medicament
    INSTEAD OF INSERT ON v_Medicament
    FOR EACH ROW EXECUTE FUNCTION fn_insert_medicament();

-- -------------------------------------------------------
-- Insertion transparente dans v_Stock
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_insert_stock()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.Ville = 'Rabat' THEN
        INSERT INTO Stock VALUES (NEW.*);
    ELSIF NEW.Ville = 'Casablanca' THEN
        INSERT INTO Stock_Casa VALUES (NEW.*);
    ELSE
        RAISE EXCEPTION 'Ville non geree : %', NEW.Ville;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_insert_v_stock
    INSTEAD OF INSERT ON v_Stock
    FOR EACH ROW EXECUTE FUNCTION fn_insert_stock();
