-- ============================================================
-- REQUETES REPARTIES
-- Base de donnees repartie - Pharmacies / Cliniques
-- ============================================================
-- Ces requetes utilisent les vues globales (v_*) definies
-- dans les scripts de fragmentation.
-- Elles peuvent etre executees depuis n'importe quel site.
-- Le site d'execution optimal est indique pour chaque requete.
-- ============================================================


-- ============================================================
-- REQUETE 1 : Afficher les patients du site de Casablanca
-- Site d'execution : S1 (Casablanca) - acces LOCAL uniquement
-- ============================================================
-- Depuis S1, acces direct a la table locale (pas de requete distante) :
SELECT IdPatient, Nom, Prenom, DateNaissance, Sexe, Adresse, Ville, Telephone
FROM Patient;

-- Equivalent via la vue globale (depuis n'importe quel site) :
-- SELECT * FROM v_Patient WHERE Ville = 'Casablanca';


-- ============================================================
-- REQUETE 2 : Afficher les medicaments dont le prix unitaire est maximal
-- Site d'execution : S1 ou S2 - requete repartie (jointure verticale)
-- ============================================================
SELECT m.IdMedicament, m.NomMedicament, m.Forme, m.Dosage,
       m.PrixUnitaire, m.Fabricant, m.VilleProduction
FROM v_Medicament m
WHERE m.PrixUnitaire = (SELECT MAX(PrixUnitaire) FROM v_Medicament);


-- ============================================================
-- REQUETE 3 : Afficher les consultations d'un patient donne
--             avec le nom du medecin
-- Site d'execution : S1 ou S2 - requete repartie
-- Exemple : Patient IdPatient = 1 (BENNANI Youssef, Casablanca)
-- ============================================================
SELECT c.IdConsultation, c.DateConsultation, c.Diagnostic,
       p.Nom AS NomPatient, p.Prenom AS PrenomPatient,
       m.NomMedecin, m.Specialite
FROM v_Consultation c
JOIN v_Patient p ON c.IdPatient = p.IdPatient
JOIN v_Medecin m ON c.IdMedecin = m.IdMedecin
WHERE c.IdPatient = 1;


-- ============================================================
-- REQUETE 4 : Afficher tous les medicaments prescrits lors
--             d'une consultation donnee
-- Site d'execution : S1 ou S2 - requete repartie
-- Exemple : Consultation IdConsultation = 1 (Grippe saisonniere)
-- ============================================================
SELECT med.IdMedicament, med.NomMedicament, med.Forme, med.Dosage,
       lp.Quantite, lp.Posologie
FROM v_Prescription p
JOIN v_LignePrescription lp ON p.IdPrescription = lp.IdPrescription
JOIN v_Medicament med ON lp.IdMedicament = med.IdMedicament
WHERE p.IdConsultation = 1;


-- ============================================================
-- REQUETE 5 : Afficher le chiffre d'affaires total par ville
-- Site d'execution : S1 ou S2 - requete repartie (agregation globale)
-- ============================================================
SELECT Ville,
       SUM(MontantTotal) AS ChiffreAffaires,
       COUNT(IdVente) AS NombreVentes
FROM v_Vente
GROUP BY Ville
ORDER BY ChiffreAffaires DESC;


-- ============================================================
-- REQUETE 6 : Afficher le medicament le plus vendu sur
--             l'ensemble du reseau
-- Site d'execution : S1 ou S2 - requete repartie
-- ============================================================
SELECT med.IdMedicament, med.NomMedicament,
       SUM(lv.Quantite) AS TotalQuantiteVendue
FROM v_LigneVente lv
JOIN v_Medicament med ON lv.IdMedicament = med.IdMedicament
GROUP BY med.IdMedicament, med.NomMedicament
ORDER BY TotalQuantiteVendue DESC
LIMIT 1;


-- ============================================================
-- REQUETE 7 : Afficher les medicaments dont le stock est
--             inferieur au seuil d'alerte
-- Site d'execution : S1 ou S2 - requete repartie
-- ============================================================
SELECT s.IdStock, med.NomMedicament, med.Forme,
       s.Ville, s.QuantiteDisponible, s.SeuilAlerte,
       (s.SeuilAlerte - s.QuantiteDisponible) AS Deficit
FROM v_Stock s
JOIN v_Medicament med ON s.IdMedicament = med.IdMedicament
WHERE s.QuantiteDisponible < s.SeuilAlerte
ORDER BY Deficit DESC;


-- ============================================================
-- REQUETE 8 : Afficher, pour chaque medecin, le nombre total
--             de consultations realisees
-- Site d'execution : S1 ou S2 - requete repartie
-- ============================================================
SELECT m.IdMedecin, m.NomMedecin, m.Specialite, m.Ville,
       COUNT(c.IdConsultation) AS NbConsultations
FROM v_Medecin m
LEFT JOIN v_Consultation c ON m.IdMedecin = c.IdMedecin
GROUP BY m.IdMedecin, m.NomMedecin, m.Specialite, m.Ville
ORDER BY NbConsultations DESC;


-- ============================================================
-- REQUETE 9 : Afficher les patients ayant effectue une
--             consultation dans une ville et un achat dans l'autre
-- Site d'execution : S1 ou S2 - requete repartie (cross-site)
-- ============================================================
-- La ville de consultation est determinee par la ville du medecin.
-- La ville d'achat est le champ Ville de la table Vente.
SELECT DISTINCT p.IdPatient, p.Nom, p.Prenom, p.Ville AS VilleResidence,
       m.Ville AS VilleConsultation,
       v.Ville AS VilleAchat
FROM v_Patient p
JOIN v_Consultation c ON p.IdPatient = c.IdPatient
JOIN v_Medecin m ON c.IdMedecin = m.IdMedecin
JOIN v_Vente v ON p.IdPatient = v.IdPatient
WHERE m.Ville <> v.Ville;


-- ============================================================
-- REQUETE 10 : Afficher les patients ayant achete au moins un
--              medicament qui figurait dans leur prescription
-- Site d'execution : S1 ou S2 - requete repartie (cross-site)
-- ============================================================
SELECT DISTINCT p.IdPatient, p.Nom, p.Prenom, p.Ville
FROM v_Patient p
-- Jointure vers les prescriptions du patient
JOIN v_Consultation c ON p.IdPatient = c.IdPatient
JOIN v_Prescription pr ON c.IdConsultation = pr.IdConsultation
JOIN v_LignePrescription lp ON pr.IdPrescription = lp.IdPrescription
-- Jointure vers les achats du patient
JOIN v_Vente v ON p.IdPatient = v.IdPatient
JOIN v_LigneVente lv ON v.IdVente = lv.IdVente
-- Le meme medicament est prescrit ET achete
WHERE lp.IdMedicament = lv.IdMedicament
ORDER BY p.IdPatient;
