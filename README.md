# Base de Donnees Repartie - Pharmacies / Cliniques

Projet BDR simulant deux sites PostgreSQL (Casablanca & Rabat) avec `postgres_fdw`.

## Lancement avec Docker

```bash
docker compose up -d
```

Cela demarre les deux bases et configure automatiquement les liaisons FDW, les vues globales et les donnees de test.

Verifier que le setup est termine :

```bash
docker logs bdr_setup
```

## Connexion aux bases

```bash
# Site Casablanca (S1)
psql -h localhost -p 5433 -U postgres -d site_casablanca

# Site Rabat (S2)
psql -h localhost -p 5434 -U postgres -d site_rabat
```

Mot de passe : `postgres`

## Executer les requetes

```bash
psql -h localhost -p 5433 -U postgres -d site_casablanca -f 06_requetes.sql
```

## Arret

```bash
docker compose down -v
```

## Sans Docker (PostgreSQL local)

```bash
psql -U postgres -c "CREATE DATABASE site_casablanca;"
psql -U postgres -c "CREATE DATABASE site_rabat;"
psql -U postgres -d site_casablanca -f 02_fragmentation_s1.sql
psql -U postgres -d site_rabat     -f 03_fragmentation_s2.sql
psql -U postgres -d site_casablanca -f 04_donnees_s1.sql
psql -U postgres -d site_rabat     -f 05_donnees_s2.sql
psql -U postgres -d site_casablanca -f 06_requetes.sql
```

> Adapter `user`/`password` dans les scripts 02 et 03 si necessaire.
