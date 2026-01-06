-- ============================================
-- SYSTÈME DE FACTURATION - STATION-SERVICE
-- Base de données PostgreSQL
-- ============================================

-- Création de la base de données
CREATE DATABASE station_service_db
    WITH 
    ENCODING = 'UTF8'
    LC_COLLATE = 'French_France.1252'
    LC_CTYPE = 'French_France.1252';

-- Se connecter à la base
\c station_service_db;

-- ============================================
-- TABLE : clients
-- ============================================
CREATE TABLE clients (
    id_client SERIAL PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    prenom VARCHAR(100),
    telephone VARCHAR(20),
    email VARCHAR(150),
    adresse TEXT,
    type_client VARCHAR(20) CHECK (type_client IN ('particulier', 'entreprise')) DEFAULT 'particulier',
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    actif BOOLEAN DEFAULT TRUE,
);

CREATE INDEX idx_clients_nom ON clients(nom);
CREATE INDEX idx_clients_telephone ON clients(telephone);

-- ============================================
-- TABLE : services
-- ============================================
CREATE TABLE services (
    id_service SERIAL PRIMARY KEY,
    code_service VARCHAR(20) UNIQUE NOT NULL,
    libelle VARCHAR(200) NOT NULL,
    description TEXT,
    prix_unitaire_ht NUMERIC(10,2) NOT NULL CHECK (prix_unitaire_ht >= 0),
    taux_tva NUMERIC(5,2) NOT NULL DEFAULT 20.00 CHECK (taux_tva >= 0),
    categorie VARCHAR(50) NOT NULL,
    unite_mesure VARCHAR(20) DEFAULT 'unité',
    actif BOOLEAN DEFAULT TRUE,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_services_categorie ON services(categorie);
CREATE INDEX idx_services_code ON services(code_service);

-- ============================================
-- TABLE : devis
-- ============================================
CREATE TABLE devis (
    id_devis SERIAL PRIMARY KEY,
    numero_devis VARCHAR(20) UNIQUE NOT NULL,
    id_client INTEGER NOT NULL REFERENCES clients(id_client),
    date_devis DATE NOT NULL DEFAULT CURRENT_DATE,
    date_validite DATE NOT NULL,
    montant_ht NUMERIC(10,2) DEFAULT 0 CHECK (montant_ht >= 0),
    montant_tva NUMERIC(10,2) DEFAULT 0 CHECK (montant_tva >= 0),
    montant_ttc NUMERIC(10,2) DEFAULT 0 CHECK (montant_ttc >= 0),
    statut VARCHAR(20) CHECK (statut IN ('EN_ATTENTE', 'ACCEPTE', 'REFUSE', 'EXPIRE')) DEFAULT 'EN_ATTENTE',
    observations TEXT,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_modification TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_devis_client ON devis(id_client);
CREATE INDEX idx_devis_date ON devis(date_devis);
CREATE INDEX idx_devis_statut ON devis(statut);

-- ============================================
-- TABLE : lignes_devis
-- ============================================
CREATE TABLE lignes_devis (
    id_ligne_devis SERIAL PRIMARY KEY,
    id_devis INTEGER NOT NULL REFERENCES devis(id_devis) ON DELETE CASCADE,
    id_service INTEGER NOT NULL REFERENCES services(id_service),
    quantite NUMERIC(10,3) NOT NULL CHECK (quantite > 0),
    prix_unitaire_ht NUMERIC(10,2) NOT NULL CHECK (prix_unitaire_ht >= 0),
    taux_tva NUMERIC(5,2) NOT NULL CHECK (taux_tva >= 0),
    montant_ht NUMERIC(10,2) NOT NULL CHECK (montant_ht >= 0),
    montant_tva NUMERIC(10,2) NOT NULL CHECK (montant_tva >= 0),
    montant_ttc NUMERIC(10,2) NOT NULL CHECK (montant_ttc >= 0),
    CONSTRAINT fk_devis FOREIGN KEY (id_devis) REFERENCES devis(id_devis) ON DELETE CASCADE
);

CREATE INDEX idx_lignes_devis_devis ON lignes_devis(id_devis);

-- ============================================
-- TABLE : factures
-- ============================================
CREATE TABLE factures (
    id_facture SERIAL PRIMARY KEY,
    numero_facture VARCHAR(20) UNIQUE NOT NULL,
    id_client INTEGER NOT NULL REFERENCES clients(id_client),
    id_devis INTEGER REFERENCES devis(id_devis),
    date_facture DATE NOT NULL DEFAULT CURRENT_DATE,
    date_echeance DATE NOT NULL,
    montant_ht NUMERIC(10,2) DEFAULT 0 CHECK (montant_ht >= 0),
    montant_tva NUMERIC(10,2) DEFAULT 0 CHECK (montant_tva >= 0),
    montant_ttc NUMERIC(10,2) DEFAULT 0 CHECK (montant_ttc >= 0),
    montant_paye NUMERIC(10,2) DEFAULT 0 CHECK (montant_paye >= 0),
    solde_restant NUMERIC(10,2) DEFAULT 0,
    statut VARCHAR(30) CHECK (statut IN ('IMPAYEE', 'PARTIELLEMENT_PAYEE', 'PAYEE', 'ANNULEE')) DEFAULT 'IMPAYEE',
    observations TEXT,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_modification TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_solde CHECK (solde_restant >= 0)
);

CREATE INDEX idx_factures_client ON factures(id_client);
CREATE INDEX idx_factures_date ON factures(date_facture);
CREATE INDEX idx_factures_statut ON factures(statut);
CREATE INDEX idx_factures_devis ON factures(id_devis);

-- ============================================
-- TABLE : lignes_factures
-- ============================================
CREATE TABLE lignes_factures (
    id_ligne_facture SERIAL PRIMARY KEY,
    id_facture INTEGER NOT NULL REFERENCES factures(id_facture) ON DELETE CASCADE,
    id_service INTEGER NOT NULL REFERENCES services(id_service),
    quantite NUMERIC(10,3) NOT NULL CHECK (quantite > 0),
    prix_unitaire_ht NUMERIC(10,2) NOT NULL CHECK (prix_unitaire_ht >= 0),
    taux_tva NUMERIC(5,2) NOT NULL CHECK (taux_tva >= 0),
    montant_ht NUMERIC(10,2) NOT NULL CHECK (montant_ht >= 0),
    montant_tva NUMERIC(10,2) NOT NULL CHECK (montant_tva >= 0),
    montant_ttc NUMERIC(10,2) NOT NULL CHECK (montant_ttc >= 0)
);

CREATE INDEX idx_lignes_factures_facture ON lignes_factures(id_facture);

-- ============================================
-- TABLE : paiements
-- ============================================
CREATE TABLE paiements (
    id_paiement SERIAL PRIMARY KEY,
    id_facture INTEGER NOT NULL REFERENCES factures(id_facture),
    date_paiement DATE NOT NULL DEFAULT CURRENT_DATE,
    montant NUMERIC(10,2) NOT NULL CHECK (montant > 0),
    mode_paiement VARCHAR(20) CHECK (mode_paiement IN ('especes', 'carte', 'cheque', 'virement', 'mobile')) NOT NULL,
    reference_paiement VARCHAR(100),
    observations TEXT,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_paiements_facture ON paiements(id_facture);
CREATE INDEX idx_paiements_date ON paiements(date_paiement);

-- ============================================
-- FONCTIONS ET TRIGGERS
-- ============================================

-- Fonction de génération numéro devis
CREATE OR REPLACE FUNCTION generer_numero_devis()
RETURNS TRIGGER AS $$
DECLARE
    annee VARCHAR(4);
    compteur INTEGER;
    nouveau_numero VARCHAR(20);
BEGIN
    annee := TO_CHAR(CURRENT_DATE, 'YYYY');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(numero_devis FROM 5) AS INTEGER)), 0) + 1
    INTO compteur
    FROM devis
    WHERE numero_devis LIKE 'DEV' || annee || '%';
    
    nouveau_numero := 'DEV' || annee || LPAD(compteur::TEXT, 6, '0');
    NEW.numero_devis := nouveau_numero;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_numero_devis
BEFORE INSERT ON devis
FOR EACH ROW
WHEN (NEW.numero_devis IS NULL OR NEW.numero_devis = '')
EXECUTE FUNCTION generer_numero_devis();

-- Fonction de génération numéro facture
CREATE OR REPLACE FUNCTION generer_numero_facture()
RETURNS TRIGGER AS $$
DECLARE
    annee VARCHAR(4);
    compteur INTEGER;
    nouveau_numero VARCHAR(20);
BEGIN
    annee := TO_CHAR(CURRENT_DATE, 'YYYY');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(numero_facture FROM 5) AS INTEGER)), 0) + 1
    INTO compteur
    FROM factures
    WHERE numero_facture LIKE 'FAC' || annee || '%';
    
    nouveau_numero := 'FAC' || annee || LPAD(compteur::TEXT, 6, '0');
    NEW.numero_facture := nouveau_numero;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_numero_facture
BEFORE INSERT ON factures
FOR EACH ROW
WHEN (NEW.numero_facture IS NULL OR NEW.numero_facture = '')
EXECUTE FUNCTION generer_numero_facture();

-- Fonction de calcul montants devis
CREATE OR REPLACE FUNCTION calculer_montants_devis()
RETURNS TRIGGER AS $$
BEGIN
    NEW.montant_ht := NEW.quantite * NEW.prix_unitaire_ht;
    NEW.montant_tva := NEW.montant_ht * (NEW.taux_tva / 100);
    NEW.montant_ttc := NEW.montant_ht + NEW.montant_tva;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_calcul_ligne_devis
BEFORE INSERT OR UPDATE ON lignes_devis
FOR EACH ROW
EXECUTE FUNCTION calculer_montants_devis();

-- Fonction de calcul montants facture
CREATE OR REPLACE FUNCTION calculer_montants_facture()
RETURNS TRIGGER AS $$
BEGIN
    NEW.montant_ht := NEW.quantite * NEW.prix_unitaire_ht;
    NEW.montant_tva := NEW.montant_ht * (NEW.taux_tva / 100);
    NEW.montant_ttc := NEW.montant_ht + NEW.montant_tva;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_calcul_ligne_facture
BEFORE INSERT OR UPDATE ON lignes_factures
FOR EACH ROW
EXECUTE FUNCTION calculer_montants_facture();

-- Fonction de mise à jour totaux devis
CREATE OR REPLACE FUNCTION maj_totaux_devis()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE devis
    SET montant_ht = (SELECT COALESCE(SUM(montant_ht), 0) FROM lignes_devis WHERE id_devis = COALESCE(NEW.id_devis, OLD.id_devis)),
        montant_tva = (SELECT COALESCE(SUM(montant_tva), 0) FROM lignes_devis WHERE id_devis = COALESCE(NEW.id_devis, OLD.id_devis)),
        montant_ttc = (SELECT COALESCE(SUM(montant_ttc), 0) FROM lignes_devis WHERE id_devis = COALESCE(NEW.id_devis, OLD.id_devis)),
        date_modification = CURRENT_TIMESTAMP
    WHERE id_devis = COALESCE(NEW.id_devis, OLD.id_devis);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_maj_totaux_devis
AFTER INSERT OR UPDATE OR DELETE ON lignes_devis
FOR EACH ROW
EXECUTE FUNCTION maj_totaux_devis();

-- Fonction de mise à jour totaux facture
CREATE OR REPLACE FUNCTION maj_totaux_facture()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE factures
    SET montant_ht = (SELECT COALESCE(SUM(montant_ht), 0) FROM lignes_factures WHERE id_facture = COALESCE(NEW.id_facture, OLD.id_facture)),
        montant_tva = (SELECT COALESCE(SUM(montant_tva), 0) FROM lignes_factures WHERE id_facture = COALESCE(NEW.id_facture, OLD.id_facture)),
        montant_ttc = (SELECT COALESCE(SUM(montant_ttc), 0) FROM lignes_factures WHERE id_facture = COALESCE(NEW.id_facture, OLD.id_facture)),
        solde_restant = montant_ttc - montant_paye,
        date_modification = CURRENT_TIMESTAMP
    WHERE id_facture = COALESCE(NEW.id_facture, OLD.id_facture);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_maj_totaux_facture
AFTER INSERT OR UPDATE OR DELETE ON lignes_factures
FOR EACH ROW
EXECUTE FUNCTION maj_totaux_facture();

-- Fonction de mise à jour statut facture après paiement
CREATE OR REPLACE FUNCTION maj_statut_facture()
RETURNS TRIGGER AS $$
DECLARE
    total_paye NUMERIC(10,2);
    montant_total NUMERIC(10,2);
BEGIN
    SELECT COALESCE(SUM(montant), 0) INTO total_paye
    FROM paiements
    WHERE id_facture = NEW.id_facture;
    
    SELECT montant_ttc INTO montant_total
    FROM factures
    WHERE id_facture = NEW.id_facture;
    
    UPDATE factures
    SET montant_paye = total_paye,
        solde_restant = montant_total - total_paye,
        statut = CASE
            WHEN total_paye = 0 THEN 'IMPAYEE'
            WHEN total_paye < montant_total THEN 'PARTIELLEMENT_PAYEE'
            WHEN total_paye >= montant_total THEN 'PAYEE'
        END,
        date_modification = CURRENT_TIMESTAMP
    WHERE id_facture = NEW.id_facture;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_maj_statut_facture
AFTER INSERT ON paiements
FOR EACH ROW
EXECUTE FUNCTION maj_statut_facture();

-- ============================================
-- DONNÉES DE TEST
-- ============================================

-- Insertion de clients
INSERT INTO clients (nom, prenom, telephone, email, type_client) VALUES
('Dupont', 'Jean', '0612345678', 'jean.dupont@email.fr', 'particulier'),
('Martin', 'Sophie', '0623456789', 'sophie.martin@email.fr', 'particulier'),
('Entreprise ABC', NULL, '0134567890', 'contact@abc.fr', 'entreprise');

-- Insertion de services
INSERT INTO services (code_service, libelle, prix_unitaire_ht, taux_tva, categorie, unite_mesure) VALUES
('CARB_SP95', 'Essence Sans Plomb 95', 1.65, 20.00, 'Carburant', 'litre'),
('CARB_SP98', 'Essence Sans Plomb 98', 1.75, 20.00, 'Carburant', 'litre'),
('CARB_GAZOIL', 'Gazole', 1.55, 20.00, 'Carburant', 'litre'),
('LAV_SIMPLE', 'Lavage Simple', 8.00, 20.00, 'Lavage', 'unité'),
('LAV_COMPLET', 'Lavage Complet', 15.00, 20.00, 'Lavage', 'unité'),
('VID_MOTEUR', 'Vidange Moteur', 45.00, 20.00, 'Entretien', 'unité'),
('VID_FILTRE', 'Remplacement Filtre à Huile', 12.00, 20.00, 'Entretien', 'unité');

-- Création d'un devis exemple
INSERT INTO devis (id_client, date_validite, observations) 
VALUES (1, CURRENT_DATE + 30, 'Devis pour entretien complet');

INSERT INTO lignes_devis (id_devis, id_service, quantite, prix_unitaire_ht, taux_tva)
SELECT 1, id_service, 1, prix_unitaire_ht, taux_tva
FROM services WHERE code_service IN ('VID_MOTEUR', 'VID_FILTRE');

-- Création d'une facture exemple
INSERT INTO factures (id_client, date_echeance, observations)
VALUES (1, CURRENT_DATE + 30, 'Achat carburant');

INSERT INTO lignes_factures (id_facture, id_service, quantite, prix_unitaire_ht, taux_tva)
SELECT 1, id_service, 50, prix_unitaire_ht, taux_tva
FROM services WHERE code_service = 'CARB_SP95';

-- ============================================
-- VUES UTILES
-- ============================================

-- Vue récapitulative des factures
CREATE OR REPLACE VIEW v_factures_recapitulatif AS
SELECT 
    f.id_facture,
    f.numero_facture,
    f.date_facture,
    c.nom || ' ' || COALESCE(c.prenom, '') AS client,
    c.telephone,
    f.montant_ttc,
    f.montant_paye,
    f.solde_restant,
    f.statut,
    CASE 
        WHEN f.date_echeance < CURRENT_DATE AND f.statut != 'PAYEE' THEN 'En retard'
        ELSE 'À jour'
    END AS etat_paiement
FROM factures f
JOIN clients c ON f.id_client = c.id_client
ORDER BY f.date_facture DESC;

-- Vue des ventes par service
CREATE OR REPLACE VIEW v_ventes_par_service AS
SELECT 
    s.categorie,
    s.libelle,
    COUNT(lf.id_ligne_facture) AS nombre_ventes,
    SUM(lf.quantite) AS quantite_totale,
    SUM(lf.montant_ttc) AS chiffre_affaires_ttc
FROM services s
LEFT JOIN lignes_factures lf ON s.id_service = lf.id_service
GROUP BY s.id_service, s.categorie, s.libelle
ORDER BY chiffre_affaires_ttc DESC;

COMMENT ON DATABASE station_service_db IS 'Base de données système de facturation pour station-service';
COMMENT ON TABLE clients IS 'Table des clients (particuliers et entreprises)';
COMMENT ON TABLE services IS 'Catalogue des services proposés par la station';
COMMENT ON TABLE devis IS 'Devis émis aux clients';
COMMENT ON TABLE factures IS 'Factures émises aux clients';
COMMENT ON TABLE paiements IS 'Historique des paiements reçus';