-- ============================================================
-- SITE S2 - RABAT : Configuration FDW, tables distantes,
-- vues globales et insertion transparente
-- ============================================================

-- ============================================================
-- 1. CONFIGURATION postgres_fdw -> site_casablanca
-- ============================================================
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

CREATE SERVER site_casablanca
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'site_casablanca', port '5432', dbname 'site_casablanca');

CREATE USER MAPPING FOR postgres
    SERVER site_casablanca
    OPTIONS (user 'postgres', password 'postgres');

-- ============================================================
-- 2. TABLES DISTANTES (fragments de Casablanca)
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
-- 3. VUES GLOBALES
-- ============================================================
CREATE VIEW v_Patient AS
    SELECT IdPatient, Nom, Prenom, DateNaissance, Sexe, Adresse, Ville, Telephone FROM Patient
    UNION ALL
    SELECT IdPatient, Nom, Prenom, DateNaissance, Sexe, Adresse, Ville, Telephone FROM Patient_Casa;

CREATE VIEW v_Medecin AS
    SELECT IdMedecin, NomMedecin, Specialite, Ville, Telephone FROM Medecin
    UNION ALL
    SELECT IdMedecin, NomMedecin, Specialite, Ville, Telephone FROM Medecin_Casa;

CREATE VIEW v_Medicament AS
    SELECT b.IdMedicament, b.NomMedicament, b.Forme, b.Dosage,
           c.PrixUnitaire, c.Fabricant, c.VilleProduction
    FROM Medicament_Base b
    JOIN Medicament_Commercial c ON b.IdMedicament = c.IdMedicament;

CREATE VIEW v_Consultation AS
    SELECT IdConsultation, DateConsultation, Diagnostic, IdPatient, IdMedecin FROM Consultation
    UNION ALL
    SELECT IdConsultation, DateConsultation, Diagnostic, IdPatient, IdMedecin FROM Consultation_Casa;

CREATE VIEW v_Prescription AS
    SELECT IdPrescription, DatePrescription, IdConsultation FROM Prescription
    UNION ALL
    SELECT IdPrescription, DatePrescription, IdConsultation FROM Prescription_Casa;

CREATE VIEW v_LignePrescription AS
    SELECT IdPrescription, IdMedicament, Quantite, Posologie FROM LignePrescription
    UNION ALL
    SELECT IdPrescription, IdMedicament, Quantite, Posologie FROM LignePrescription_Casa;

CREATE VIEW v_Stock AS
    SELECT IdStock, IdMedicament, Ville, QuantiteDisponible, SeuilAlerte FROM Stock
    UNION ALL
    SELECT IdStock, IdMedicament, Ville, QuantiteDisponible, SeuilAlerte FROM Stock_Casa;

CREATE VIEW v_Vente AS
    SELECT IdVente, DateVente, Ville, IdPatient, MontantTotal FROM Vente
    UNION ALL
    SELECT IdVente, DateVente, Ville, IdPatient, MontantTotal FROM Vente_Casa;

CREATE VIEW v_LigneVente AS
    SELECT IdVente, IdMedicament, Quantite, PrixVente FROM LigneVente
    UNION ALL
    SELECT IdVente, IdMedicament, Quantite, PrixVente FROM LigneVente_Casa;

-- ============================================================
-- 4. INSERTION TRANSPARENTE
-- ============================================================
CREATE OR REPLACE FUNCTION fn_insert_patient()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.Ville = 'Rabat' THEN
        INSERT INTO Patient VALUES (NEW.*);
    ELSIF NEW.Ville = 'Casablanca' THEN
        INSERT INTO Patient_Casa VALUES (NEW.*);
    ELSE
        RAISE EXCEPTION 'Ville non geree : %', NEW.Ville;
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
        RAISE EXCEPTION 'Ville non geree : %', NEW.Ville;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_insert_v_vente
    INSTEAD OF INSERT ON v_Vente
    FOR EACH ROW EXECUTE FUNCTION fn_insert_vente();

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
