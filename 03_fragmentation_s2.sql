-- Site S2 - Rabat
-- A executer apres connexion : \c site_rabat

-- Nettoyage complet avant re-creation
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


-- -------------------------------------------------------
-- 1. Tables locales - fragments de Rabat
-- -------------------------------------------------------

-- Fragmentation horizontale : sigma(Ville='Rabat')(Patient)
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

-- Fragmentation horizontale : sigma(Ville='Rabat')(Medecin)
CREATE TABLE Medecin (
    IdMedecin       INT             PRIMARY KEY,
    NomMedecin      VARCHAR(100)    NOT NULL,
    Specialite      VARCHAR(50)     NOT NULL,
    Ville           VARCHAR(50)     NOT NULL DEFAULT 'Rabat'
                                    CHECK (Ville = 'Rabat'),
    Telephone       VARCHAR(20)
);

-- Fragmentation horizontale derivee : les consultations suivent le medecin
-- IdPatient sans FK locale car un patient de Casablanca peut consulter ici
CREATE TABLE Consultation (
    IdConsultation  INT             PRIMARY KEY,
    DateConsultation DATE           NOT NULL,
    Diagnostic      TEXT,
    IdPatient       INT             NOT NULL,
    IdMedecin       INT             NOT NULL REFERENCES Medecin(IdMedecin)
);

-- Suit Consultation (meme fragment)
CREATE TABLE Prescription (
    IdPrescription  INT             PRIMARY KEY,
    DatePrescription DATE           NOT NULL,
    IdConsultation  INT             NOT NULL UNIQUE
                                    REFERENCES Consultation(IdConsultation)
);

-- Fragmentation verticale de Medicament : fragment COMMERCIAL (prix, fabricant)
-- pi(IdMedicament, PrixUnitaire, Fabricant, VilleProduction) -> S2
-- La partie pharmaceutique (nom, forme, dosage) est sur S1
CREATE TABLE Medicament_Commercial (
    IdMedicament    INT             PRIMARY KEY,
    PrixUnitaire    DECIMAL(10,2)   NOT NULL,
    Fabricant       VARCHAR(100),
    VilleProduction VARCHAR(50)
);

CREATE TABLE LignePrescription (
    IdPrescription  INT             NOT NULL REFERENCES Prescription(IdPrescription),
    IdMedicament    INT             NOT NULL REFERENCES Medicament_Commercial(IdMedicament),
    Quantite        INT             NOT NULL DEFAULT 1,
    Posologie       VARCHAR(200),
    PRIMARY KEY (IdPrescription, IdMedicament)
);

-- Fragmentation horizontale : sigma(Ville='Rabat')(Stock)
CREATE TABLE Stock (
    IdStock             INT             PRIMARY KEY,
    IdMedicament        INT             NOT NULL REFERENCES Medicament_Commercial(IdMedicament),
    Ville               VARCHAR(50)     NOT NULL DEFAULT 'Rabat'
                                        CHECK (Ville = 'Rabat'),
    QuantiteDisponible  INT             NOT NULL DEFAULT 0,
    SeuilAlerte         INT             NOT NULL DEFAULT 10
);

-- Fragmentation horizontale : sigma(Ville='Rabat')(Vente)
-- IdPatient sans FK car un patient de Casablanca peut acheter a Rabat
CREATE TABLE Vente (
    IdVente         INT             PRIMARY KEY,
    DateVente       DATE            NOT NULL,
    Ville           VARCHAR(50)     NOT NULL DEFAULT 'Rabat'
                                    CHECK (Ville = 'Rabat'),
    IdPatient       INT             NOT NULL,
    MontantTotal    DECIMAL(10,2)   NOT NULL
);

CREATE TABLE LigneVente (
    IdVente         INT             NOT NULL REFERENCES Vente(IdVente),
    IdMedicament    INT             NOT NULL REFERENCES Medicament_Commercial(IdMedicament),
    Quantite        INT             NOT NULL DEFAULT 1,
    PrixVente       DECIMAL(10,2)   NOT NULL,
    PRIMARY KEY (IdVente, IdMedicament)
);


-- -------------------------------------------------------
-- 2. Configuration FDW vers S1 (site_casablanca)
-- -------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS postgres_fdw;

CREATE SERVER site_casablanca
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'localhost', port '5432', dbname 'site_casablanca');

-- Adapter user/password selon votre configuration
CREATE USER MAPPING FOR CURRENT_USER
    SERVER site_casablanca
    OPTIONS (user 'postgres', password 'postgres');


-- -------------------------------------------------------
-- 3. Tables distantes - acces aux fragments de Casablanca via FDW
-- -------------------------------------------------------

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

-- Fragment vertical distant : partie pharmaceutique du medicament (stockee sur S1)
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


-- -------------------------------------------------------
-- 4. Vues globales - reconstruction du schema complet
-- -------------------------------------------------------

-- UNION des deux fragments horizontaux
CREATE VIEW v_Patient AS
    SELECT IdPatient, Nom, Prenom, DateNaissance, Sexe, Adresse, Ville, Telephone
    FROM Patient
    UNION ALL
    SELECT IdPatient, Nom, Prenom, DateNaissance, Sexe, Adresse, Ville, Telephone
    FROM Patient_Casa;

CREATE VIEW v_Medecin AS
    SELECT IdMedecin, NomMedecin, Specialite, Ville, Telephone
    FROM Medecin
    UNION ALL
    SELECT IdMedecin, NomMedecin, Specialite, Ville, Telephone
    FROM Medecin_Casa;

-- Jointure des deux fragments verticaux pour reconstruire Medicament
CREATE VIEW v_Medicament AS
    SELECT b.IdMedicament, b.NomMedicament, b.Forme, b.Dosage,
           c.PrixUnitaire, c.Fabricant, c.VilleProduction
    FROM Medicament_Base b
    JOIN Medicament_Commercial c ON b.IdMedicament = c.IdMedicament;

CREATE VIEW v_Consultation AS
    SELECT IdConsultation, DateConsultation, Diagnostic, IdPatient, IdMedecin
    FROM Consultation
    UNION ALL
    SELECT IdConsultation, DateConsultation, Diagnostic, IdPatient, IdMedecin
    FROM Consultation_Casa;

CREATE VIEW v_Prescription AS
    SELECT IdPrescription, DatePrescription, IdConsultation
    FROM Prescription
    UNION ALL
    SELECT IdPrescription, DatePrescription, IdConsultation
    FROM Prescription_Casa;

CREATE VIEW v_LignePrescription AS
    SELECT IdPrescription, IdMedicament, Quantite, Posologie
    FROM LignePrescription
    UNION ALL
    SELECT IdPrescription, IdMedicament, Quantite, Posologie
    FROM LignePrescription_Casa;

CREATE VIEW v_Stock AS
    SELECT IdStock, IdMedicament, Ville, QuantiteDisponible, SeuilAlerte
    FROM Stock
    UNION ALL
    SELECT IdStock, IdMedicament, Ville, QuantiteDisponible, SeuilAlerte
    FROM Stock_Casa;

CREATE VIEW v_Vente AS
    SELECT IdVente, DateVente, Ville, IdPatient, MontantTotal
    FROM Vente
    UNION ALL
    SELECT IdVente, DateVente, Ville, IdPatient, MontantTotal
    FROM Vente_Casa;

CREATE VIEW v_LigneVente AS
    SELECT IdVente, IdMedicament, Quantite, PrixVente
    FROM LigneVente
    UNION ALL
    SELECT IdVente, IdMedicament, Quantite, PrixVente
    FROM LigneVente_Casa;


-- -------------------------------------------------------
-- 5. Triggers INSTEAD OF pour l'insertion transparente
--    L'utilisateur insere dans la vue, le trigger redirige
--    vers le bon fragment selon la ville
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

-- Pour Medicament : on insere en local (commercial) puis on ecrit sur S1 (base) via FDW
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
