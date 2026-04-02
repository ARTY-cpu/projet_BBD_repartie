-- Requetes reparties - Pharmacies / Cliniques
-- Toutes ces requetes utilisent les vues globales (v_*) et peuvent etre
-- lancees depuis n'importe quel site.


-- R1 : Patients du site de Casablanca
-- Acces direct a la table locale depuis S1 (pas de requete distante)
SELECT IdPatient, Nom, Prenom, DateNaissance, Sexe, Adresse, Ville, Telephone
FROM Patient;

-- Equivalent depuis n'importe quel site :
-- SELECT * FROM v_Patient WHERE Ville = 'Casablanca';


-- R2 : Medicament(s) au prix le plus eleve
-- Requete repartie : jointure verticale entre S1 (Medicament_Base) et S2 (Medicament_Commercial)
SELECT m.IdMedicament, m.NomMedicament, m.Forme, m.Dosage,
       m.PrixUnitaire, m.Fabricant, m.VilleProduction
FROM v_Medicament m
WHERE m.PrixUnitaire = (SELECT MAX(PrixUnitaire) FROM v_Medicament);


-- R3 : Consultations d'un patient avec le nom du medecin
-- Exemple : patient 1 (BENNANI Youssef)
SELECT c.IdConsultation, c.DateConsultation, c.Diagnostic,
       p.Nom AS NomPatient, p.Prenom AS PrenomPatient,
       m.NomMedecin, m.Specialite
FROM v_Consultation c
JOIN v_Patient p ON c.IdPatient = p.IdPatient
JOIN v_Medecin m ON c.IdMedecin = m.IdMedecin
WHERE c.IdPatient = 1;


-- R4 : Medicaments prescrits lors d'une consultation
-- Exemple : consultation 1 (Grippe saisonniere)
SELECT med.IdMedicament, med.NomMedicament, med.Forme, med.Dosage,
       lp.Quantite, lp.Posologie
FROM v_Prescription p
JOIN v_LignePrescription lp ON p.IdPrescription = lp.IdPrescription
JOIN v_Medicament med ON lp.IdMedicament = med.IdMedicament
WHERE p.IdConsultation = 1;


-- R5 : Chiffre d'affaires total par ville
SELECT Ville,
       SUM(MontantTotal) AS ChiffreAffaires,
       COUNT(IdVente) AS NombreVentes
FROM v_Vente
GROUP BY Ville
ORDER BY ChiffreAffaires DESC;


-- R6 : Medicament le plus vendu sur l'ensemble du reseau
SELECT med.IdMedicament, med.NomMedicament,
       SUM(lv.Quantite) AS TotalQuantiteVendue
FROM v_LigneVente lv
JOIN v_Medicament med ON lv.IdMedicament = med.IdMedicament
GROUP BY med.IdMedicament, med.NomMedicament
ORDER BY TotalQuantiteVendue DESC
LIMIT 1;


-- R7 : Medicaments dont le stock est en dessous du seuil d'alerte
SELECT s.IdStock, med.NomMedicament, med.Forme,
       s.Ville, s.QuantiteDisponible, s.SeuilAlerte,
       (s.SeuilAlerte - s.QuantiteDisponible) AS Deficit
FROM v_Stock s
JOIN v_Medicament med ON s.IdMedicament = med.IdMedicament
WHERE s.QuantiteDisponible < s.SeuilAlerte
ORDER BY Deficit DESC;


-- R8 : Nombre de consultations par medecin
SELECT m.IdMedecin, m.NomMedecin, m.Specialite, m.Ville,
       COUNT(c.IdConsultation) AS NbConsultations
FROM v_Medecin m
LEFT JOIN v_Consultation c ON m.IdMedecin = c.IdMedecin
GROUP BY m.IdMedecin, m.NomMedecin, m.Specialite, m.Ville
ORDER BY NbConsultations DESC;


-- R9 : Patients ayant consulte dans une ville et achete dans l'autre
-- La ville de consultation est determinee par la ville du medecin
SELECT DISTINCT p.IdPatient, p.Nom, p.Prenom, p.Ville AS VilleResidence,
       m.Ville AS VilleConsultation,
       v.Ville AS VilleAchat
FROM v_Patient p
JOIN v_Consultation c ON p.IdPatient = c.IdPatient
JOIN v_Medecin m ON c.IdMedecin = m.IdMedecin
JOIN v_Vente v ON p.IdPatient = v.IdPatient
WHERE m.Ville <> v.Ville;


-- R10 : Patients ayant achete au moins un medicament qui figurait dans leur ordonnance
SELECT DISTINCT p.IdPatient, p.Nom, p.Prenom, p.Ville
FROM v_Patient p
JOIN v_Consultation c ON p.IdPatient = c.IdPatient
JOIN v_Prescription pr ON c.IdConsultation = pr.IdConsultation
JOIN v_LignePrescription lp ON pr.IdPrescription = lp.IdPrescription
JOIN v_Vente v ON p.IdPatient = v.IdPatient
JOIN v_LigneVente lv ON v.IdVente = lv.IdVente
WHERE lp.IdMedicament = lv.IdMedicament
ORDER BY p.IdPatient;
