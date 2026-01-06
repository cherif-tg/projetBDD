-- Database: stationBDD

--DROP DATABASE IF EXISTS "stationBDD";

-- station_service_db.sql
-- Schéma nettoyé et aligné avec ProjetBDD/StationService/app.py

-- NOTE: importer ce fichier dans une base PostgreSQL (ex : stationBDD)

-- Suppression des anciennes tables (si présentes)
DROP TABLE IF EXISTS paiements CASCADE;
DROP TABLE IF EXISTS lignes_factures CASCADE;
DROP TABLE IF EXISTS factures CASCADE;
DROP TABLE IF EXISTS lignes_devis CASCADE;
DROP TABLE IF EXISTS devis CASCADE;
DROP TABLE IF EXISTS services CASCADE;
DROP TABLE IF EXISTS clients CASCADE;
DROP TABLE IF EXISTS utilisateur CASCADE;

-- TABLE : utilisateur (singulier, utilisé en FK dans l'app)
CREATE TABLE utilisateur (
    id_utilisateur SERIAL PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    prenom VARCHAR(100),
    email VARCHAR(150) UNIQUE,
    mot_de_passe_hash VARCHAR(255),
    role VARCHAR(30) DEFAULT 'EMPLOYE',
    actif BOOLEAN NOT NULL DEFAULT TRUE,
    date_creation TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_utilisateur_email ON utilisateur(email);

-- TABLE : clients
CREATE TABLE clients (
    id_client SERIAL PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    prenom VARCHAR(100),
    telephone VARCHAR(30),
    email VARCHAR(150),
    adresse TEXT,
    ville VARCHAR(100),
    code_postal VARCHAR(20),
    immatriculation_vehicule VARCHAR(50),
    modele_vehicule VARCHAR(150),
    type_client VARCHAR(50) DEFAULT 'particulier',
    actif BOOLEAN NOT NULL DEFAULT TRUE,
    date_creation TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_clients_nom ON clients(nom);
CREATE INDEX idx_clients_telephone ON clients(telephone);

-- TABLE : services
CREATE TABLE services (
    id_service SERIAL PRIMARY KEY,
    code_service VARCHAR(50) NOT NULL UNIQUE,
    libelle VARCHAR(200) NOT NULL,
    description TEXT,
    prix_unitaire_ht NUMERIC(12,2) NOT NULL DEFAULT 0,
    taux_tva NUMERIC(5,2) NOT NULL DEFAULT 20,
    unite_mesure VARCHAR(50) DEFAULT 'unit',
    categorie VARCHAR(100),
    actif BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE INDEX idx_services_code ON services(code_service);
CREATE INDEX idx_services_categorie ON services(categorie);

-- TABLE : devis
CREATE TABLE devis (
    id_devis SERIAL PRIMARY KEY,
    numero_devis VARCHAR(30) UNIQUE,
    date_emission DATE NOT NULL DEFAULT CURRENT_DATE,
    date_validite DATE,
    id_client INTEGER REFERENCES clients(id_client) ON DELETE RESTRICT,
    montant_ht NUMERIC(12,2) DEFAULT 0,
    montant_tva NUMERIC(12,2) DEFAULT 0,
    montant_ttc NUMERIC(12,2) DEFAULT 0,
    statut VARCHAR(30) DEFAULT 'EN_ATTENTE',
    observations TEXT,
    id_utilisateur INTEGER REFERENCES utilisateur(id_utilisateur) ON DELETE RESTRICT,
    date_creation TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- TABLE : lignes_devis
CREATE TABLE lignes_devis (
    id_ligne_devis SERIAL PRIMARY KEY,
    id_devis INTEGER NOT NULL REFERENCES devis(id_devis) ON DELETE CASCADE,
    id_service INTEGER NOT NULL REFERENCES services(id_service) ON DELETE RESTRICT,
    quantite NUMERIC(12,3) NOT NULL CHECK (quantite > 0),
    prix_unitaire_ht NUMERIC(12,2) NOT NULL CHECK (prix_unitaire_ht >= 0),
    taux_tva NUMERIC(5,2) NOT NULL CHECK (taux_tva >= 0),
    montant_ht NUMERIC(12,2) DEFAULT 0,
    montant_tva NUMERIC(12,2) DEFAULT 0,
    montant_ttc NUMERIC(12,2) DEFAULT 0
);

-- TABLE : factures (alignée sur app.py)
CREATE TABLE factures (
    id_facture SERIAL PRIMARY KEY,
    numero_facture VARCHAR(30) UNIQUE,
    date_facture DATE NOT NULL DEFAULT CURRENT_DATE,
    date_echeance DATE,
    id_client INTEGER NOT NULL REFERENCES clients(id_client) ON DELETE RESTRICT,
    id_devis INTEGER REFERENCES devis(id_devis) ON DELETE RESTRICT,
    montant_ht NUMERIC(12,2) DEFAULT 0,
    montant_tva NUMERIC(12,2) DEFAULT 0,
    montant_ttc NUMERIC(12,2) DEFAULT 0,
    montant_paye NUMERIC(12,2) DEFAULT 0,
    solde_restant NUMERIC(12,2) DEFAULT 0,
    statut VARCHAR(30) DEFAULT 'IMPAYEE',
    observations TEXT,
    id_utilisateur INTEGER REFERENCES utilisateur(id_utilisateur) ON DELETE RESTRICT,
    date_creation TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    date_modification TIMESTAMP
);
CREATE INDEX idx_factures_numero ON factures(numero_facture);
CREATE INDEX idx_factures_client ON factures(id_client);

-- TABLE : lignes_factures (alignée sur app.py)
CREATE TABLE lignes_factures (
    id_ligne_facture SERIAL PRIMARY KEY,
    id_facture INTEGER NOT NULL REFERENCES factures(id_facture) ON DELETE CASCADE,
    id_service INTEGER NOT NULL REFERENCES services(id_service),
    quantite NUMERIC(12,3) NOT NULL CHECK (quantite > 0),
    prix_unitaire_ht NUMERIC(12,2) NOT NULL CHECK (prix_unitaire_ht >= 0),
    taux_tva NUMERIC(5,2) NOT NULL CHECK (taux_tva >= 0),
    montant_ht NUMERIC(12,2) DEFAULT 0,
    montant_tva NUMERIC(12,2) DEFAULT 0,
    montant_ttc NUMERIC(12,2) DEFAULT 0
);
CREATE INDEX idx_lignes_factures_facture ON lignes_factures(id_facture);

-- TABLE : paiements (pluriel, attendu par app.py)
CREATE TABLE paiements (
    id_paiement SERIAL PRIMARY KEY,
    id_facture INTEGER NOT NULL REFERENCES factures(id_facture) ON DELETE RESTRICT,
    date_paiement DATE NOT NULL DEFAULT CURRENT_DATE,
    montant NUMERIC(12,2) NOT NULL CHECK (montant > 0),
    mode_paiement VARCHAR(30) NOT NULL,
    reference_paiement VARCHAR(100),
    observations TEXT,
    id_utilisateur INTEGER REFERENCES utilisateur(id_utilisateur) ON DELETE RESTRICT,
    date_creation TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_paiements_facture ON paiements(id_facture);
CREATE INDEX idx_paiements_date ON paiements(date_paiement DESC);

-- VUES utiles (simplifiées)
CREATE OR REPLACE VIEW v_historique_client AS
SELECT
    c.id_client,
    c.nom || ' ' || COALESCE(c.prenom, '') AS nom_complet,
    'DEVIS' AS type_document,
    d.numero_devis AS numero_document,
    d.date_emission,
    d.montant_ttc,
    d.statut,
    NULL::NUMERIC AS solde_restant
FROM clients c
JOIN devis d ON c.id_client = d.id_client
UNION ALL
SELECT
    c.id_client,
    c.nom || ' ' || COALESCE(c.prenom, '') AS nom_complet,
    'FACTURE' AS type_document,
    f.numero_facture AS numero_document,
    f.date_facture,
    f.montant_ttc,
    f.statut,
    f.solde_restant
FROM clients c
JOIN factures f ON c.id_client = f.id_client
ORDER BY date_facture DESC;

CREATE OR REPLACE VIEW v_factures_impayees AS
SELECT
    f.id_facture,
    f.numero_facture,
    f.date_facture,
    f.date_echeance,
    c.nom || ' ' || COALESCE(c.prenom, '') AS nom_client,
    c.telephone,
    f.montant_ttc,
    f.montant_paye,
    f.solde_restant,
    f.statut,
    CASE WHEN f.date_echeance < CURRENT_DATE THEN 'EN_RETARD' ELSE 'A_JOUR' END AS etat_echeance
FROM factures f
JOIN clients c ON f.id_client = c.id_client
WHERE f.statut IN ('IMPAYEE', 'PARTIELLEMENT_PAYEE')
ORDER BY f.date_echeance ASC;

-- FONCTIONS ET TRIGGERS
-- Génération numéro facture (FACyyyy######)
CREATE OR REPLACE FUNCTION generer_numero_facture()
RETURNS TRIGGER AS $$
DECLARE
    annee TEXT;
    compteur INTEGER;
    nouveau_numero TEXT;
BEGIN
    annee := TO_CHAR(CURRENT_DATE, 'YYYY');
    SELECT COALESCE(MAX(CAST(SUBSTRING(numero_facture FROM '(\\d+)$') AS INTEGER)), 0) + 1
    INTO compteur
    FROM factures
    WHERE numero_facture LIKE 'FAC' || annee || '%';

    nouveau_numero := 'FAC' || annee || LPAD(compteur::TEXT, 6, '0');
    NEW.numero_facture := nouveau_numero;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_generer_numero_facture
BEFORE INSERT ON factures
FOR EACH ROW
WHEN (NEW.numero_facture IS NULL OR NEW.numero_facture = '')
EXECUTE FUNCTION generer_numero_facture();

-- Calcul montants ligne facture
CREATE OR REPLACE FUNCTION calculer_montants_ligne_facture()
RETURNS TRIGGER AS $$
BEGIN
    NEW.montant_ht := ROUND(NEW.quantite * NEW.prix_unitaire_ht::numeric, 2);
    NEW.montant_tva := ROUND(NEW.montant_ht * (NEW.taux_tva / 100.0), 2);
    NEW.montant_ttc := ROUND(NEW.montant_ht + NEW.montant_tva, 2);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_calculer_montants_ligne_facture
BEFORE INSERT OR UPDATE ON lignes_factures
FOR EACH ROW
EXECUTE FUNCTION calculer_montants_ligne_facture();

-- Mise à jour totaux facture après modification des lignes
CREATE OR REPLACE FUNCTION maj_totaux_facture()
RETURNS TRIGGER AS $$
DECLARE
    v_id_facture INTEGER := COALESCE(NEW.id_facture, OLD.id_facture);
BEGIN
    UPDATE factures
    SET montant_ht = (SELECT COALESCE(SUM(montant_ht),0) FROM lignes_factures WHERE id_facture = v_id_facture),
        montant_tva = (SELECT COALESCE(SUM(montant_tva),0) FROM lignes_factures WHERE id_facture = v_id_facture),
        montant_ttc = (SELECT COALESCE(SUM(montant_ttc),0) FROM lignes_factures WHERE id_facture = v_id_facture),
        solde_restant = (SELECT COALESCE(SUM(montant_ttc),0) FROM lignes_factures WHERE id_facture = v_id_facture) - COALESCE((SELECT montant_paye FROM factures WHERE id_facture = v_id_facture),0),
        date_modification = CURRENT_TIMESTAMP
    WHERE id_facture = v_id_facture;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_maj_totaux_facture
AFTER INSERT OR UPDATE OR DELETE ON lignes_factures
FOR EACH ROW
EXECUTE FUNCTION maj_totaux_facture();

-- Mise à jour statut facture après paiement
CREATE OR REPLACE FUNCTION maj_statut_facture_paiement()
RETURNS TRIGGER AS $$
DECLARE
    v_id_facture INTEGER := COALESCE(NEW.id_facture, OLD.id_facture);
    v_montant_ttc NUMERIC(12,2);
    v_montant_paye NUMERIC(12,2);
    v_solde NUMERIC(12,2);
BEGIN
    SELECT montant_ttc, COALESCE((SELECT SUM(montant) FROM paiements p WHERE p.id_facture = f.id_facture), 0)
    INTO v_montant_ttc, v_montant_paye
    FROM factures f
    WHERE f.id_facture = v_id_facture;

    v_solde := COALESCE(v_montant_ttc,0) - COALESCE(v_montant_paye,0);

    UPDATE factures
    SET montant_paye = COALESCE(v_montant_paye,0),
        solde_restant = COALESCE(v_solde,0),
        statut = CASE
            WHEN COALESCE(v_solde,0) = 0 THEN 'PAYEE'
            WHEN COALESCE(v_solde,0) > 0 AND COALESCE(v_montant_paye,0) > 0 THEN 'PARTIELLEMENT_PAYEE'
            ELSE 'IMPAYEE'
        END
    WHERE id_facture = v_id_facture;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_maj_statut_facture_paiement
AFTER INSERT OR UPDATE OR DELETE ON paiements
FOR EACH ROW
EXECUTE FUNCTION maj_statut_facture_paiement();

-- DONNEES DE TEST (exemples cohérents avec noms de colonnes)
INSERT INTO utilisateur (nom, prenom, email, mot_de_passe_hash, role)
VALUES ('ADMIN','Gerant','gerant@station.tg', NULL, 'GERANT');

INSERT INTO clients (nom, prenom, telephone, email, ville, immatriculation_vehicule, modele_vehicule)
VALUES
('AGBODJAN','Edem','90123456','edemagbodjan@email.tg','Lome','TG-1234-AA','Toyota Corolla 2018'),
('KOUASSI','Ama','91234567','amakouassi@email.tg','Lome','TG-5678-BB','Honda Civic 2020');

INSERT INTO services (code_service, libelle, prix_unitaire_ht, taux_tva, unite_mesure, categorie)
VALUES
('CARB-ESS','Essence Super',650.00,20,'litre','Carburant'),
('CARB-GAZ','Gasoil',580.00,20,'litre','Carburant'),
('MAINT-VID','Vidange complete',25000.00,20,'unit','Entretien');

-- Fin du script
