-- ============================================================
-- SITE S1 - CASABLANCA
-- Script de fragmentation, configuration FDW, vues globales
-- ============================================================
-- Connexion prealable : \c site_casablanca
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

DROP FOREIGN TABLE IF EXISTS LigneVente_Rabat CASCADE;
DROP FOREIGN TABLE IF EXISTS Vente_Rabat CASCADE;
DROP FOREIGN TABLE IF EXISTS Stock_Rabat CASCADE;
DROP FOREIGN TABLE IF EXISTS LignePrescription_Rabat CASCADE;
DROP FOREIGN TABLE IF EXISTS Prescription_Rabat CASCADE;
DROP FOREIGN TABLE IF EXISTS Consultation_Rabat CASCADE;
DROP FOREIGN TABLE IF EXISTS Medicament_Commercial CASCADE;
DROP FOREIGN TABLE IF EXISTS Medecin_Rabat CASCADE;
DROP FOREIGN TABLE IF EXISTS Patient_Rabat CASCADE;

DROP TABLE IF EXISTS LigneVente CASCADE;
DROP TABLE IF EXISTS Vente CASCADE;
DROP TABLE IF EXISTS Stock CASCADE;
DROP TABLE IF EXISTS LignePrescription CASCADE;
DROP TABLE IF EXISTS Prescription CASCADE;
DROP TABLE IF EXISTS Consultation CASCADE;
DROP TABLE IF EXISTS Medicament_Base CASCADE;
DROP TABLE IF EXISTS Medecin CASCADE;
DROP TABLE IF EXISTS Patient CASCADE;

DROP USER MAPPING IF EXISTS FOR CURRENT_USER SERVER site_rabat;
DROP SERVER IF EXISTS site_rabat CASCADE;
DROP EXTENSION IF EXISTS postgres_fdw CASCADE;

-- ============================================================
-- 1. TABLES LOCALES (Fragments de Casablanca)
-- ============================================================

-- -------------------------------------------------------
-- Fragmentation HORIZONTALE de Patient (Ville = 'Casablanca')
-- Critere : sigma(Ville='Casablanca')(Patient)
-- -------------------------------------------------------
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

-- -------------------------------------------------------
-- Fragmentation HORIZONTALE de Medecin (Ville = 'Casablanca')
-- Critere : sigma(Ville='Casablanca')(Medecin)
-- -------------------------------------------------------
CREATE TABLE Medecin (
    IdMedecin       INT             PRIMARY KEY,
    NomMedecin      VARCHAR(100)    NOT NULL,
    Specialite      VARCHAR(50)     NOT NULL,
    Ville           VARCHAR(50)     NOT NULL DEFAULT 'Casablanca'
                                    CHECK (Ville = 'Casablanca'),
    Telephone       VARCHAR(20)
);

-- -------------------------------------------------------
-- Fragmentation horizontale DERIVEE de Consultation
-- Les consultations realisees par les medecins de Casablanca
-- sont stockees sur S1.
-- Note : IdPatient sans FK locale car le patient peut venir de Rabat
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
-- Fragmentation VERTICALE de Medicament : fragment BASE
-- Contient les informations pharmaceutiques (identification)
-- pi(IdMedicament, NomMedicament, Forme, Dosage)(Medicament) -> S1
-- -------------------------------------------------------
CREATE TABLE Medicament_Base (
    IdMedicament    INT             PRIMARY KEY,
    NomMedicament   VARCHAR(100)    NOT NULL,
    Forme           VARCHAR(50)     NOT NULL,
    Dosage          VARCHAR(50)
);

-- -------------------------------------------------------
-- Fragmentation derivee de LignePrescription
-- -------------------------------------------------------
CREATE TABLE LignePrescription (
    IdPrescription  INT             NOT NULL REFERENCES Prescription(IdPrescription),
    IdMedicament    INT             NOT NULL REFERENCES Medicament_Base(IdMedicament),
    Quantite        INT             NOT NULL DEFAULT 1,
    Posologie       VARCHAR(200),
    PRIMARY KEY (IdPrescription, IdMedicament)
);

-- -------------------------------------------------------
-- Fragmentation HORIZONTALE de Stock (Ville = 'Casablanca')
-- sigma(Ville='Casablanca')(Stock)
-- -------------------------------------------------------
CREATE TABLE Stock (
    IdStock             INT             PRIMARY KEY,
    IdMedicament        INT             NOT NULL REFERENCES Medicament_Base(IdMedicament),
    Ville               VARCHAR(50)     NOT NULL DEFAULT 'Casablanca'
                                        CHECK (Ville = 'Casablanca'),
    QuantiteDisponible  INT             NOT NULL DEFAULT 0,
    SeuilAlerte         INT             NOT NULL DEFAULT 10
);

-- -------------------------------------------------------
-- Fragmentation HORIZONTALE de Vente (Ville = 'Casablanca')
-- sigma(Ville='Casablanca')(Vente)
-- Note : IdPatient sans FK car le patient peut provenir de Rabat
-- -------------------------------------------------------
CREATE TABLE Vente (
    IdVente         INT             PRIMARY KEY,
    DateVente       DATE            NOT NULL,
    Ville           VARCHAR(50)     NOT NULL DEFAULT 'Casablanca'
                                    CHECK (Ville = 'Casablanca'),
    IdPatient       INT             NOT NULL,
    MontantTotal    DECIMAL(10,2)   NOT NULL
);

-- -------------------------------------------------------
-- Fragmentation derivee de LigneVente (suit Vente)
-- -------------------------------------------------------
CREATE TABLE LigneVente (
    IdVente         INT             NOT NULL REFERENCES Vente(IdVente),
    IdMedicament    INT             NOT NULL REFERENCES Medicament_Base(IdMedicament),
    Quantite        INT             NOT NULL DEFAULT 1,
    PrixVente       DECIMAL(10,2)   NOT NULL,
    PRIMARY KEY (IdVente, IdMedicament)
);

-- ============================================================
-- 2. CONFIGURATION postgres_fdw (acces au site distant S2)
-- ============================================================

CREATE EXTENSION IF NOT EXISTS postgres_fdw;

CREATE SERVER site_rabat
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'localhost', port '5432', dbname 'site_rabat');

-- Adapter user/password selon votre configuration
CREATE USER MAPPING FOR CURRENT_USER
    SERVER site_rabat
    OPTIONS (user 'postgres', password 'postgres');

-- ============================================================
-- 3. TABLES DISTANTES (acces aux fragments de Rabat via FDW)
-- ============================================================

CREATE FOREIGN TABLE Patient_Rabat (
    IdPatient       INT,
    Nom             VARCHAR(50),
    Prenom          VARCHAR(50),
    DateNaissance   DATE,
    Sexe            CHAR(1),
    Adresse         VARCHAR(200),
    Ville           VARCHAR(50),
    Telephone       VARCHAR(20)
) SERVER site_rabat OPTIONS (schema_name 'public', table_name 'patient');

CREATE FOREIGN TABLE Medecin_Rabat (
    IdMedecin       INT,
    NomMedecin      VARCHAR(100),
    Specialite      VARCHAR(50),
    Ville           VARCHAR(50),
    Telephone       VARCHAR(20)
) SERVER site_rabat OPTIONS (schema_name 'public', table_name 'medecin');

CREATE FOREIGN TABLE Consultation_Rabat (
    IdConsultation  INT,
    DateConsultation DATE,
    Diagnostic      TEXT,
    IdPatient       INT,
    IdMedecin       INT
) SERVER site_rabat OPTIONS (schema_name 'public', table_name 'consultation');

CREATE FOREIGN TABLE Prescription_Rabat (
    IdPrescription  INT,
    DatePrescription DATE,
    IdConsultation  INT
) SERVER site_rabat OPTIONS (schema_name 'public', table_name 'prescription');

CREATE FOREIGN TABLE LignePrescription_Rabat (
    IdPrescription  INT,
    IdMedicament    INT,
    Quantite        INT,
    Posologie       VARCHAR(200)
) SERVER site_rabat OPTIONS (schema_name 'public', table_name 'ligneprescription');

-- Fragment vertical distant : partie COMMERCIALE (stockee sur S2)
CREATE FOREIGN TABLE Medicament_Commercial (
    IdMedicament    INT,
    PrixUnitaire    DECIMAL(10,2),
    Fabricant       VARCHAR(100),
    VilleProduction VARCHAR(50)
) SERVER site_rabat OPTIONS (schema_name 'public', table_name 'medicament_commercial');

CREATE FOREIGN TABLE Stock_Rabat (
    IdStock             INT,
    IdMedicament        INT,
    Ville               VARCHAR(50),
    QuantiteDisponible  INT,
    SeuilAlerte         INT
) SERVER site_rabat OPTIONS (schema_name 'public', table_name 'stock');

CREATE FOREIGN TABLE Vente_Rabat (
    IdVente         INT,
    DateVente       DATE,
    Ville           VARCHAR(50),
    IdPatient       INT,
    MontantTotal    DECIMAL(10,2)
) SERVER site_rabat OPTIONS (schema_name 'public', table_name 'vente');

CREATE FOREIGN TABLE LigneVente_Rabat (
    IdVente         INT,
    IdMedicament    INT,
    Quantite        INT,
    PrixVente       DECIMAL(10,2)
) SERVER site_rabat OPTIONS (schema_name 'public', table_name 'lignevente');

-- ============================================================
-- 4. VUES GLOBALES (reconstruction du schema global)
-- ============================================================

-- Reconstruction de Patient par UNION des fragments horizontaux
CREATE VIEW v_Patient AS
    SELECT IdPatient, Nom, Prenom, DateNaissance, Sexe, Adresse, Ville, Telephone
    FROM Patient
    UNION ALL
    SELECT IdPatient, Nom, Prenom, DateNaissance, Sexe, Adresse, Ville, Telephone
    FROM Patient_Rabat;

-- Reconstruction de Medecin par UNION des fragments horizontaux
CREATE VIEW v_Medecin AS
    SELECT IdMedecin, NomMedecin, Specialite, Ville, Telephone
    FROM Medecin
    UNION ALL
    SELECT IdMedecin, NomMedecin, Specialite, Ville, Telephone
    FROM Medecin_Rabat;

-- Reconstruction de Medicament par JOINTURE des fragments verticaux
-- Medicament_Base (local S1) JOIN Medicament_Commercial (distant S2)
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
    FROM Consultation_Rabat;

-- Reconstruction de Prescription
CREATE VIEW v_Prescription AS
    SELECT IdPrescription, DatePrescription, IdConsultation
    FROM Prescription
    UNION ALL
    SELECT IdPrescription, DatePrescription, IdConsultation
    FROM Prescription_Rabat;

-- Reconstruction de LignePrescription
CREATE VIEW v_LignePrescription AS
    SELECT IdPrescription, IdMedicament, Quantite, Posologie
    FROM LignePrescription
    UNION ALL
    SELECT IdPrescription, IdMedicament, Quantite, Posologie
    FROM LignePrescription_Rabat;

-- Reconstruction de Stock
CREATE VIEW v_Stock AS
    SELECT IdStock, IdMedicament, Ville, QuantiteDisponible, SeuilAlerte
    FROM Stock
    UNION ALL
    SELECT IdStock, IdMedicament, Ville, QuantiteDisponible, SeuilAlerte
    FROM Stock_Rabat;

-- Reconstruction de Vente
CREATE VIEW v_Vente AS
    SELECT IdVente, DateVente, Ville, IdPatient, MontantTotal
    FROM Vente
    UNION ALL
    SELECT IdVente, DateVente, Ville, IdPatient, MontantTotal
    FROM Vente_Rabat;

-- Reconstruction de LigneVente
CREATE VIEW v_LigneVente AS
    SELECT IdVente, IdMedicament, Quantite, PrixVente
    FROM LigneVente
    UNION ALL
    SELECT IdVente, IdMedicament, Quantite, PrixVente
    FROM LigneVente_Rabat;

-- ============================================================
-- 5. MECANISME D'INSERTION TRANSPARENTE (triggers INSTEAD OF)
-- ============================================================

-- -------------------------------------------------------
-- Insertion transparente dans v_Patient
-- Redirige automatiquement vers le bon fragment selon la Ville
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_insert_patient()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.Ville = 'Casablanca' THEN
        INSERT INTO Patient VALUES (NEW.*);
    ELSIF NEW.Ville = 'Rabat' THEN
        INSERT INTO Patient_Rabat VALUES (NEW.*);
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
    IF NEW.Ville = 'Casablanca' THEN
        INSERT INTO Vente VALUES (NEW.*);
    ELSIF NEW.Ville = 'Rabat' THEN
        INSERT INTO Vente_Rabat VALUES (NEW.*);
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
--   Medicament_Base (local) et Medicament_Commercial (distant)
-- -------------------------------------------------------
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

CREATE TRIGGER trg_insert_v_medicament
    INSTEAD OF INSERT ON v_Medicament
    FOR EACH ROW EXECUTE FUNCTION fn_insert_medicament();

-- -------------------------------------------------------
-- Insertion transparente dans v_Stock
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_insert_stock()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.Ville = 'Casablanca' THEN
        INSERT INTO Stock VALUES (NEW.*);
    ELSIF NEW.Ville = 'Rabat' THEN
        INSERT INTO Stock_Rabat VALUES (NEW.*);
    ELSE
        RAISE EXCEPTION 'Ville non geree : %', NEW.Ville;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_insert_v_stock
    INSTEAD OF INSERT ON v_Stock
    FOR EACH ROW EXECUTE FUNCTION fn_insert_stock();
