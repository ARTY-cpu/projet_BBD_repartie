-- ============================================================
-- DONNEES DU SITE S2 - RABAT
-- A executer sur : site_rabat (apres 03_fragmentation_s2.sql)
-- ============================================================
-- Connexion prealable : \c site_rabat
-- ============================================================

-- ============================================================
-- PATIENTS DE RABAT (6 patients)
-- ============================================================
INSERT INTO Patient (IdPatient, Nom, Prenom, DateNaissance, Sexe, Adresse, Ville, Telephone) VALUES
(7,  'BENKIRANE', 'Omar',   '1983-04-12', 'M', '15 Av Mohammed V, Agdal',          'Rabat', '0667-789012'),
(8,  'SQALLI',    'Houda',  '1991-02-28', 'F', '28 Rue Oukaimeden, Hassan',         'Rabat', '0668-890123'),
(9,  'BERRADA',   'Mehdi',  '1975-08-05', 'M', '5 Bd Al Amir Fal Ould Oumeir, Hay Riad', 'Rabat', '0669-901234'),
(10, 'LAHLOU',    'Salma',  '1993-12-17', 'F', '42 Rue Patrice Lumumba, Ocean',     'Rabat', '0670-012345'),
(11, 'ZOUITEN',   'Rachid', '1980-05-30', 'M', '19 Av Ibn Sina, Souissi',           'Rabat', '0671-123456'),
(12, 'KETTANI',   'Zineb',  '1987-10-14', 'F', '31 Rue Ghandi, Centre Ville',       'Rabat', '0672-234567');

-- ============================================================
-- MEDECINS DE RABAT (3 medecins)
-- ============================================================
INSERT INTO Medecin (IdMedecin, NomMedecin, Specialite, Ville, Telephone) VALUES
(4, 'Dr. OUAZZANI Nora',   'Generaliste',  'Rabat', '0537-444444'),
(5, 'Dr. FILALI Amine',    'Pneumologue',  'Rabat', '0537-555555'),
(6, 'Dr. HAJJI Samira',    'Gynecologue',  'Rabat', '0537-666666');

-- ============================================================
-- MEDICAMENT_COMMERCIAL (fragment vertical : partie commerciale)
-- Les 10 medicaments du catalogue (colonnes commerciales)
-- ============================================================
INSERT INTO Medicament_Commercial (IdMedicament, PrixUnitaire, Fabricant, VilleProduction) VALUES
(1,  15.00, 'Sanofi',  'Casablanca'),
(2,  35.00, 'Pharma5', 'Casablanca'),
(3,  42.00, 'Maphar',  'Casablanca'),
(4,  85.00, 'GSK',     'Rabat'),
(5,  55.00, 'GSK',     'Rabat'),
(6,  28.00, 'Sanofi',  'Casablanca'),
(7,  18.00, 'Cooper',  'Rabat'),
(8,  65.00, 'Pharma5', 'Casablanca'),
(9,  22.00, 'Cooper',  'Rabat'),
(10, 48.00, 'Maphar',  'Casablanca');

-- ============================================================
-- CONSULTATIONS A RABAT (6 consultations, IDs 7-12)
-- ============================================================
INSERT INTO Consultation (IdConsultation, DateConsultation, Diagnostic, IdPatient, IdMedecin) VALUES
(7,  '2025-01-18', 'Bronchite aigue avec toux productive',                   7,  4),
(8,  '2025-01-28', 'Asthme bronchique, crise moderee',                       8,  5),
(9,  '2025-02-12', 'Hypertension arterielle avec surpoids',                  9,  4),
(10, '2025-02-28', 'Suivi gynecologique annuel, bilan normal',               10, 6),
(11, '2025-03-08', 'Pneumonie communautaire non severe',                     11, 5),
(12, '2025-03-20', 'Infection urinaire basse non compliquee',                12, 6);

-- ============================================================
-- PRESCRIPTIONS DE RABAT (6 prescriptions, IDs 7-12)
-- ============================================================
INSERT INTO Prescription (IdPrescription, DatePrescription, IdConsultation) VALUES
(7,  '2025-01-18', 7),
(8,  '2025-01-28', 8),
(9,  '2025-02-12', 9),
(10, '2025-02-28', 10),
(11, '2025-03-08', 11),
(12, '2025-03-20', 12);

-- ============================================================
-- LIGNES DE PRESCRIPTION DE RABAT (9 lignes)
-- ============================================================
INSERT INTO LignePrescription (IdPrescription, IdMedicament, Quantite, Posologie) VALUES
(7,  2, 1, '1 gelule 3 fois par jour pendant 7 jours'),
(7,  9, 1, '10 ml 3 fois par jour pendant 5 jours'),
(8,  5, 1, '2 bouffees en cas de crise, max 8 par jour'),
(9,  8, 1, '1 comprime par jour le matin'),
(9,  6, 1, '1 comprime 2 fois par jour aux repas'),
(10, 2, 1, '1 gelule 2 fois par jour pendant 5 jours'),
(11, 4, 1, '1 comprime 2 fois par jour pendant 8 jours'),
(11, 9, 1, '10 ml 3 fois par jour si fievre'),
(12, 10, 1, '1 comprime 2 fois par jour pendant 7 jours');

-- ============================================================
-- STOCK DE RABAT (10 entrees, IDs 11-20)
-- ============================================================
INSERT INTO Stock (IdStock, IdMedicament, Ville, QuantiteDisponible, SeuilAlerte) VALUES
(11, 1,  'Rabat', 120, 20),
(12, 2,  'Rabat', 60,  15),
(13, 3,  'Rabat', 8,   10),  -- EN DESSOUS du seuil d'alerte
(14, 4,  'Rabat', 75,  10),
(15, 5,  'Rabat', 90,  15),
(16, 6,  'Rabat', 35,  10),
(17, 7,  'Rabat', 100, 10),
(18, 8,  'Rabat', 50,  15),
(19, 9,  'Rabat', 85,  10),
(20, 10, 'Rabat', 30,  10);

-- ============================================================
-- VENTES A RABAT (7 ventes, IDs 10-16)
-- Note : la vente 16 concerne un patient de Casablanca (IdPatient=1)
-- ============================================================
INSERT INTO Vente (IdVente, DateVente, Ville, IdPatient, MontantTotal) VALUES
(10, '2025-01-18', 'Rabat', 7,  57.00),
(11, '2025-01-29', 'Rabat', 8,  55.00),
(12, '2025-02-12', 'Rabat', 9,  93.00),
(13, '2025-03-01', 'Rabat', 10, 35.00),
(14, '2025-03-08', 'Rabat', 11, 107.00),
(15, '2025-03-20', 'Rabat', 12, 48.00),
(16, '2025-04-03', 'Rabat', 1,  22.00);  -- Patient de Casablanca achetant a Rabat

-- ============================================================
-- LIGNES DE VENTE DE RABAT (10 lignes)
-- ============================================================
INSERT INTO LigneVente (IdVente, IdMedicament, Quantite, PrixVente) VALUES
(10, 2,  1, 35.00),   -- 1 x Amoxicilline
(10, 9,  1, 22.00),   -- 1 x Paracetamol            -> Total vente 10 = 57.00
(11, 5,  1, 55.00),   -- 1 x Ventoline = 55.00
(12, 8,  1, 65.00),   -- 1 x Losartan
(12, 6,  1, 28.00),   -- 1 x Metformine              -> Total vente 12 = 93.00
(13, 2,  1, 35.00),   -- 1 x Amoxicilline = 35.00
(14, 4,  1, 85.00),   -- 1 x Augmentin
(14, 9,  1, 22.00),   -- 1 x Paracetamol             -> Total vente 14 = 107.00
(15, 10, 1, 48.00),   -- 1 x Ciprofloxacine = 48.00
(16, 9,  1, 22.00);   -- 1 x Paracetamol = 22.00 (achat du patient de Casablanca)
