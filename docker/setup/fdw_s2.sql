-- Site S2 - Rabat : FDW, tables distantes, vues globales, triggers

-- 1. Extension et serveur distant
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

CREATE SERVER IF NOT EXISTS site_casablanca
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'site_casablanca', port '5432', dbname 'site_casablanca');

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_user_mappings
        WHERE srvname = 'site_casablanca' AND usename = 'postgres'
    ) THEN
        CREATE USER MAPPING FOR postgres
            SERVER site_casablanca
            OPTIONS (user 'postgres', password 'postgres');
    END IF;
END $$;

-- 2. Tables distantes (fragments de Casablanca)
CREATE FOREIGN TABLE IF NOT EXISTS Patient_Casa (
    IdPatient       INT,
    Nom             VARCHAR(50),
    Prenom          VARCHAR(50),
    DateNaissance   DATE,
    Sexe            CHAR(1),
    Adresse         VARCHAR(200),
    Ville           VARCHAR(50),
    Telephone       VARCHAR(20)
) SERVER site_casablanca OPTIONS (schema_name 'public', table_name 'patient');

CREATE FOREIGN TABLE IF NOT EXISTS Medecin_Casa (
    IdMedecin       INT,
    NomMedecin      VARCHAR(100),
    Specialite      VARCHAR(50),
    Ville           VARCHAR(50),
    Telephone       VARCHAR(20)
) SERVER site_casablanca OPTIONS (schema_name 'public', table_name 'medecin');

CREATE FOREIGN TABLE IF NOT EXISTS Consultation_Casa (
    IdConsultation  INT,
    DateConsultation DATE,
    Diagnostic      TEXT,
    IdPatient       INT,
    IdMedecin       INT
) SERVER site_casablanca OPTIONS (schema_name 'public', table_name 'consultation');

CREATE FOREIGN TABLE IF NOT EXISTS Prescription_Casa (
    IdPrescription  INT,
    DatePrescription DATE,
    IdConsultation  INT
) SERVER site_casablanca OPTIONS (schema_name 'public', table_name 'prescription');

CREATE FOREIGN TABLE IF NOT EXISTS LignePrescription_Casa (
    IdPrescription  INT,
    IdMedicament    INT,
    Quantite        INT,
    Posologie       VARCHAR(200)
) SERVER site_casablanca OPTIONS (schema_name 'public', table_name 'ligneprescription');

CREATE FOREIGN TABLE IF NOT EXISTS Medicament_Base (
    IdMedicament    INT,
    NomMedicament   VARCHAR(100),
    Forme           VARCHAR(50),
    Dosage          VARCHAR(50)
) SERVER site_casablanca OPTIONS (schema_name 'public', table_name 'medicament_base');

CREATE FOREIGN TABLE IF NOT EXISTS Stock_Casa (
    IdStock             INT,
    IdMedicament        INT,
    Ville               VARCHAR(50),
    QuantiteDisponible  INT,
    SeuilAlerte         INT
) SERVER site_casablanca OPTIONS (schema_name 'public', table_name 'stock');

CREATE FOREIGN TABLE IF NOT EXISTS Vente_Casa (
    IdVente         INT,
    DateVente       DATE,
    Ville           VARCHAR(50),
    IdPatient       INT,
    MontantTotal    DECIMAL(10,2)
) SERVER site_casablanca OPTIONS (schema_name 'public', table_name 'vente');

CREATE FOREIGN TABLE IF NOT EXISTS LigneVente_Casa (
    IdVente         INT,
    IdMedicament    INT,
    Quantite        INT,
    PrixVente       DECIMAL(10,2)
) SERVER site_casablanca OPTIONS (schema_name 'public', table_name 'lignevente');

-- 3. Vues globales
CREATE OR REPLACE VIEW v_Patient AS
    SELECT IdPatient, Nom, Prenom, DateNaissance, Sexe, Adresse, Ville, Telephone FROM Patient
    UNION ALL
    SELECT IdPatient, Nom, Prenom, DateNaissance, Sexe, Adresse, Ville, Telephone FROM Patient_Casa;

CREATE OR REPLACE VIEW v_Medecin AS
    SELECT IdMedecin, NomMedecin, Specialite, Ville, Telephone FROM Medecin
    UNION ALL
    SELECT IdMedecin, NomMedecin, Specialite, Ville, Telephone FROM Medecin_Casa;

CREATE OR REPLACE VIEW v_Medicament AS
    SELECT b.IdMedicament, b.NomMedicament, b.Forme, b.Dosage,
           c.PrixUnitaire, c.Fabricant, c.VilleProduction
    FROM Medicament_Base b
    JOIN Medicament_Commercial c ON b.IdMedicament = c.IdMedicament;

CREATE OR REPLACE VIEW v_Consultation AS
    SELECT IdConsultation, DateConsultation, Diagnostic, IdPatient, IdMedecin FROM Consultation
    UNION ALL
    SELECT IdConsultation, DateConsultation, Diagnostic, IdPatient, IdMedecin FROM Consultation_Casa;

CREATE OR REPLACE VIEW v_Prescription AS
    SELECT IdPrescription, DatePrescription, IdConsultation FROM Prescription
    UNION ALL
    SELECT IdPrescription, DatePrescription, IdConsultation FROM Prescription_Casa;

CREATE OR REPLACE VIEW v_LignePrescription AS
    SELECT IdPrescription, IdMedicament, Quantite, Posologie FROM LignePrescription
    UNION ALL
    SELECT IdPrescription, IdMedicament, Quantite, Posologie FROM LignePrescription_Casa;

CREATE OR REPLACE VIEW v_Stock AS
    SELECT IdStock, IdMedicament, Ville, QuantiteDisponible, SeuilAlerte FROM Stock
    UNION ALL
    SELECT IdStock, IdMedicament, Ville, QuantiteDisponible, SeuilAlerte FROM Stock_Casa;

CREATE OR REPLACE VIEW v_Vente AS
    SELECT IdVente, DateVente, Ville, IdPatient, MontantTotal FROM Vente
    UNION ALL
    SELECT IdVente, DateVente, Ville, IdPatient, MontantTotal FROM Vente_Casa;

CREATE OR REPLACE VIEW v_LigneVente AS
    SELECT IdVente, IdMedicament, Quantite, PrixVente FROM LigneVente
    UNION ALL
    SELECT IdVente, IdMedicament, Quantite, PrixVente FROM LigneVente_Casa;

-- 4. Triggers d'insertion transparente
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

DROP TRIGGER IF EXISTS trg_insert_v_patient ON v_Patient;
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

DROP TRIGGER IF EXISTS trg_insert_v_vente ON v_Vente;
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

DROP TRIGGER IF EXISTS trg_insert_v_medicament ON v_Medicament;
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

DROP TRIGGER IF EXISTS trg_insert_v_stock ON v_Stock;
CREATE TRIGGER trg_insert_v_stock
    INSTEAD OF INSERT ON v_Stock
    FOR EACH ROW EXECUTE FUNCTION fn_insert_stock();
