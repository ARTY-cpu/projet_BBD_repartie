#!/bin/bash
set -e

echo "========================================================"
echo "  Configuration FDW - Base de donnees repartie"
echo "  S1: site_casablanca  |  S2: site_rabat"
echo "========================================================"
echo ""

# Attente de site_casablanca
echo "Attente de site_casablanca..."
until PGPASSWORD=postgres psql -h site_casablanca -U postgres -d site_casablanca -c '\q' 2>/dev/null; do
  sleep 2
done
echo "  -> site_casablanca OK"

# Attente de site_rabat
echo "Attente de site_rabat..."
until PGPASSWORD=postgres psql -h site_rabat -U postgres -d site_rabat -c '\q' 2>/dev/null; do
  sleep 2
done
echo "  -> site_rabat OK"

echo ""
echo "--- Configuration FDW sur site_casablanca (S1) ---"
PGPASSWORD=postgres psql -h site_casablanca -U postgres -d site_casablanca -f /setup/fdw_s1.sql
echo "  -> S1 configure"

echo ""
echo "--- Configuration FDW sur site_rabat (S2) ---"
PGPASSWORD=postgres psql -h site_rabat -U postgres -d site_rabat -f /setup/fdw_s2.sql
echo "  -> S2 configure"

echo ""
echo "========================================================"
echo "  Verification rapide"
echo "========================================================"

echo ""
echo "--- Patients globaux depuis S1 ---"
PGPASSWORD=postgres psql -h site_casablanca -U postgres -d site_casablanca \
  -c "SELECT IdPatient, Nom, Prenom, Ville FROM v_Patient ORDER BY IdPatient;"

echo ""
echo "--- Medicaments (jointure verticale) depuis S2 ---"
PGPASSWORD=postgres psql -h site_rabat -U postgres -d site_rabat \
  -c "SELECT IdMedicament, NomMedicament, Forme, PrixUnitaire, Fabricant FROM v_Medicament ORDER BY IdMedicament;"

echo ""
echo "========================================================"
echo "  Configuration terminee !"
echo "========================================================"
echo ""
echo "Pour executer les requetes :"
echo "  docker exec -i site_casablanca psql -U postgres -d site_casablanca < 06_requetes.sql"
echo "  -- ou --"
echo "  psql -h localhost -p 5433 -U postgres -d site_casablanca"
echo "  psql -h localhost -p 5434 -U postgres -d site_rabat"
