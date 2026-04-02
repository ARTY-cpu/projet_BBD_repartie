-- Donnees du site S1 - Casablanca
-- A executer sur site_casablanca apres 02_fragmentation_s1.sql

-- 6 patients de Casablanca
INSERT INTO Patient (IdPatient, Nom, Prenom, DateNaissance, Sexe, Adresse, Ville, Telephone) VALUES
(1,  'BENNANI',  'Youssef', '1985-03-15', 'M', '12 Rue Hassan II, Maarif',          'Casablanca', '0661-123456'),
(2,  'ALAOUI',   'Fatima',  '1990-07-22', 'F', '45 Bd Zerktouni, Gauthier',          'Casablanca', '0662-234567'),
(3,  'TAZI',     'Ahmed',   '1978-11-03', 'M', '8 Rue Ibn Batouta, Ain Diab',        'Casablanca', '0663-345678'),
(4,  'CHRAIBI',  'Amina',   '1995-01-10', 'F', '23 Av des FAR, Centre Ville',        'Casablanca', '0664-456789'),
(5,  'IDRISSI',  'Karim',   '1982-06-18', 'M', '67 Rue Abou Bakr Seddiq, Bourgogne', 'Casablanca', '0665-567890'),
(6,  'FASSI',    'Nadia',   '1988-09-25', 'F', '34 Bd Moulay Youssef, Racine',       'Casablanca', '0666-678901');

-- 3 medecins de Casablanca
INSERT INTO Medecin (IdMedecin, NomMedecin, Specialite, Ville, Telephone) VALUES
(1, 'Dr. BELKADI Hassan',   'Generaliste',  'Casablanca', '0522-111111'),
(2, 'Dr. MANSOURI Leila',   'Cardiologue',  'Casablanca', '0522-222222'),
(3, 'Dr. RAMI Said',        'Dermatologue', 'Casablanca', '0522-333333');

-- Fragment vertical BASE : infos pharmaceutiques des 10 medicaments du catalogue
INSERT INTO Medicament_Base (IdMedicament, NomMedicament, Forme, Dosage) VALUES
(1,  'Doliprane',       'Comprime',    '1000mg'),
(2,  'Amoxicilline',    'Gelule',      '500mg'),
(3,  'Omeprazole',      'Gelule',      '20mg'),
(4,  'Augmentin',       'Comprime',    '1g'),
(5,  'Ventoline',       'Inhalateur',  '100mcg'),
(6,  'Metformine',      'Comprime',    '850mg'),
(7,  'Ibuprofene',      'Comprime',    '400mg'),
(8,  'Losartan',        'Comprime',    '50mg'),
(9,  'Paracetamol',     'Sirop',       '120mg/5ml'),
(10, 'Ciprofloxacine',  'Comprime',    '500mg');

-- 6 consultations a Casablanca (IDs 1-6)
INSERT INTO Consultation (IdConsultation, DateConsultation, Diagnostic, IdPatient, IdMedecin) VALUES
(1, '2025-01-15', 'Grippe saisonniere avec fievre et courbatures',          1, 1),
(2, '2025-01-20', 'Hypertension arterielle stade 1',                        2, 2),
(3, '2025-02-10', 'Dermatite de contact, reaction allergique cutanee',       3, 3),
(4, '2025-02-25', 'Angine bacterienne confirmee par test rapide',            4, 1),
(5, '2025-03-05', 'Arythmie cardiaque, suivi cardiologique necessaire',      5, 2),
(6, '2025-03-15', 'Acne severe de grade III',                               6, 3);

-- 6 prescriptions (IDs 1-6, une par consultation)
INSERT INTO Prescription (IdPrescription, DatePrescription, IdConsultation) VALUES
(1, '2025-01-15', 1),
(2, '2025-01-20', 2),
(3, '2025-02-10', 3),
(4, '2025-02-25', 4),
(5, '2025-03-05', 5),
(6, '2025-03-15', 6);

-- 8 lignes de prescription
INSERT INTO LignePrescription (IdPrescription, IdMedicament, Quantite, Posologie) VALUES
(1, 1, 2, '1 comprime 3 fois par jour pendant 5 jours'),
(1, 2, 1, '1 gelule 2 fois par jour pendant 7 jours'),
(2, 8, 1, '1 comprime par jour le matin'),
(3, 7, 1, '1 comprime 2 fois par jour pendant 5 jours'),
(4, 2, 1, '1 gelule 3 fois par jour pendant 7 jours'),
(4, 1, 1, '1 comprime si douleur, max 3 par jour'),
(5, 8, 1, '1 comprime par jour le matin a jeun'),
(6, 10, 1, '1 comprime 2 fois par jour pendant 10 jours');

-- Stock de Casablanca (IDs 1-10)
-- IdStock 5 et 7 sont sous le seuil d'alerte
INSERT INTO Stock (IdStock, IdMedicament, Ville, QuantiteDisponible, SeuilAlerte) VALUES
(1,  1,  'Casablanca', 150, 20),
(2,  2,  'Casablanca', 80,  15),
(3,  3,  'Casablanca', 95,  10),
(4,  4,  'Casablanca', 40,  10),
(5,  5,  'Casablanca', 3,   5),
(6,  6,  'Casablanca', 60,  10),
(7,  7,  'Casablanca', 5,   10),
(8,  8,  'Casablanca', 70,  15),
(9,  9,  'Casablanca', 45,  10),
(10, 10, 'Casablanca', 55,  10);

-- 9 ventes a Casablanca (IDs 1-9)
-- La vente 9 est un patient de Rabat (IdPatient=7) qui achete a Casablanca
INSERT INTO Vente (IdVente, DateVente, Ville, IdPatient, MontantTotal) VALUES
(1, '2025-01-15', 'Casablanca', 1, 65.00),
(2, '2025-01-21', 'Casablanca', 2, 65.00),
(3, '2025-02-10', 'Casablanca', 3, 18.00),
(4, '2025-02-25', 'Casablanca', 4, 50.00),
(5, '2025-03-05', 'Casablanca', 5, 93.00),
(6, '2025-03-15', 'Casablanca', 6, 48.00),
(7, '2025-03-20', 'Casablanca', 1, 35.00),
(8, '2025-04-01', 'Casablanca', 3, 42.00),
(9, '2025-04-02', 'Casablanca', 7, 18.00);

-- 12 lignes de vente
INSERT INTO LigneVente (IdVente, IdMedicament, Quantite, PrixVente) VALUES
(1, 1,  2, 15.00),   -- 2 x Doliprane = 30.00
(1, 2,  1, 35.00),   -- 1 x Amoxicilline = 35.00  -> Total = 65.00
(2, 8,  1, 65.00),
(3, 7,  1, 18.00),
(4, 2,  1, 35.00),
(4, 1,  1, 15.00),   -- Total = 50.00
(5, 8,  1, 65.00),
(5, 6,  1, 28.00),   -- Total = 93.00
(6, 10, 1, 48.00),
(7, 2,  1, 35.00),
(8, 3,  1, 42.00),
(9, 7,  1, 18.00);   -- achat du patient de Rabat a Casablanca
