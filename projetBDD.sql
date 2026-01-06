DROP TABLE IF EXISTS paiement CASCADE ;
DROP TABLE IF EXISTS ligne_facture CASCADE ;
DROP TABLE IF EXISTS facture CASCADE ;
DROP TABLE IF EXISTS ligne_devis CASCADE ;
DROP TABLE IF EXISTS devis CASCADE ;
DROP TABLE IF EXISTS service CASCADE ;
DROP TABLE IF EXISTS client CASCADE ;
DROP TABLE IF EXISTS utilisateur CASCADE ;

-- TABLE : UTILISATEUR
 -- ================================================
CREATE TABLE utilisateur (
    id_utilisateur SERIAL PRIMARY KEY ,
    nom VARCHAR (100) NOT NULL ,
    prenom VARCHAR (100) NOT NULL ,
    email VARCHAR (100) NOT NULL UNIQUE ,
    mot_de_passe_hash VARCHAR (255) NOT NULL ,
    role VARCHAR (20) NOT NULL CHECK ( role IN ('GERANT ', 'EMPLOYE ')),
    actif BOOLEAN NOT NULL DEFAULT TRUE ,
    date_creation TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index pour recherche par email
CREATE INDEX idx_utilisateur_email ON utilisateur ( email );

TABLE : CLIENT
 -- ================================================
CREATE TABLE client (
    id_client SERIAL PRIMARY KEY ,
    nom VARCHAR (100) NOT NULL ,
    prenom VARCHAR (100) ,
    telephone VARCHAR (20) NOT NULL ,
    email VARCHAR (100) ,
    adresse TEXT ,
    ville VARCHAR (50) ,
    code_postal VARCHAR (10) ,
    immatriculation_vehicule VARCHAR (20) ,
    modele_vehicule VARCHAR (100) ,
    date_creation TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ,
    actif BOOLEAN NOT NULL DEFAULT TRUE ,

-- Contraintes
    CONSTRAINT chk_client_telephone CHECK ( LENGTH ( TRIM ( telephone )
) >= 10)
);

-- Index pour recherches fréquentes
CREATE INDEX idx_client_nom ON client (nom);
CREATE INDEX idx_client_telephone ON client ( telephone );
CREATE INDEX idx_client_actif ON client ( actif );



-- TABLE : SERVICE
-- ================================================

CREATE TABLE service (
    id_service SERIAL PRIMARY KEY ,
    code VARCHAR (20) NOT NULL UNIQUE ,
    designation VARCHAR (200) NOT NULL ,
    description TEXT ,
    prix_unitaire_ht DECIMAL (10 ,2) NOT NULL ,
    taux_tva DECIMAL (5 ,2) NOT NULL ,
    unite VARCHAR (20) NOT NULL DEFAULT 'unit',
    categorie VARCHAR (50) NOT NULL ,
    actif BOOLEAN NOT NULL DEFAULT TRUE ,
    -- Contraintes
    CONSTRAINT chk_service_prix_positif CHECK ( prix_unitaire_ht >
    0) ,
    CONSTRAINT chk_service_tva_valide CHECK ( taux_tva IN (0, 5.5 ,
    10, 20) )
);

-- Index pour recherches
CREATE INDEX idx_service_code ON service ( code );
CREATE INDEX idx_service_categorie ON service ( categorie );
CREATE INDEX idx_service_actif ON service ( actif );


-- TABLE : DEVIS
-- ================================================
CREATE TABLE devis (
    id_devis SERIAL PRIMARY KEY ,
    numero VARCHAR (20) NOT NULL UNIQUE ,
    date_emission DATE NOT NULL DEFAULT CURRENT_DATE ,
    date_validite DATE NOT NULL ,
    id_client INTEGER NOT NULL ,
    montant_ht DECIMAL (10 ,2) NOT NULL DEFAULT 0,
    montant_tva DECIMAL (10 ,2) NOT NULL DEFAULT 0,
    montant_ttc DECIMAL (10 ,2) NOT NULL DEFAULT 0,
    statut VARCHAR (20) NOT NULL DEFAULT 'EN_ATTENTE',
    remarques TEXT ,
    id_utilisateur INTEGER NOT NULL ,
    date_creation TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ,

-- Clés étrangres
    CONSTRAINT fk_devis_client FOREIGN KEY ( id_client )
        REFERENCES client ( id_client ) ON DELETE RESTRICT ,
    CONSTRAINT fk_devis_utilisateur FOREIGN KEY ( id_utilisateur )
        REFERENCES utilisateur ( id_utilisateur ) ON DELETE RESTRICT
    CONSTRAINT chk_devis_statut CHECK ( statut IN ('EN_ATTENTE','ACCEPTE', 'REFUSE')),
    CONSTRAINT chk_devis_dates CHECK ( date_validite >=date_emission ),
    CONSTRAINT chk_devis_montants_positifs CHECK (montant_ht >= 0 AND montant_tva >= 0 AND montant_ttc >= 0)
);


-- Index pour recherches et performances
CREATE INDEX idx_devis_numero ON devis ( numero );
CREATE INDEX idx_devis_client ON devis ( id_client );
CREATE INDEX idx_devis_statut ON devis ( statut );
CREATE INDEX idx_devis_date ON devis ( date_emission DESC );

-- TABLE : LIGNE_DEVIS
-- ================================================
CREATE TABLE ligne_devis (
    id_ligne_devis SERIAL PRIMARY KEY ,
    id_devis INTEGER NOT NULL ,
    id_service INTEGER NOT NULL ,
    quantite DECIMAL (10 ,2) NOT NULL ,
    prix_unitaire_ht DECIMAL (10 ,2) NOT NULL ,
    taux_tva DECIMAL (5 ,2) NOT NULL ,
    montant_ht DECIMAL (10 ,2) NOT NULL ,
    montant_tva DECIMAL (10 ,2) NOT NULL ,
    montant_ttc DECIMAL (10 ,2) NOT NULL ,

-- Clés étrangres
    CONSTRAINT fk_ligne_devis_devis FOREIGN KEY ( id_devis )
        REFERENCES devis ( id_devis ) ON DELETE CASCADE ,
    CONSTRAINT fk_ligne_devis_service FOREIGN KEY ( id_service )
        REFERENCES service ( id_service ) ON DELETE RESTRICT ,

-- Contraintes
    CONSTRAINT chk_ligne_devis_quantite CHECK ( quantite > 0) ,
    CONSTRAINT chk_ligne_devis_prix CHECK ( prix_unitaire_ht >= 0)
);

-- Index pour performances
CREATE INDEX idx_ligne_devis_devis ON ligne_devis ( id_devis );
CREATE INDEX idx_ligne_devis_service ON ligne_devis ( id_service );

-- TABLE : FACTURE
-- ================================================
CREATE TABLE facture (
    id_facture SERIAL PRIMARY KEY ,
    numero VARCHAR (20) NOT NULL UNIQUE ,
    date_emission DATE NOT NULL DEFAULT CURRENT_DATE ,
    date_echeance DATE NOT NULL ,
    id_client INTEGER NOT NULL ,
    id_devis INTEGER ,
    montant_ht DECIMAL (10 ,2) NOT NULL DEFAULT 0,
    montant_tva DECIMAL (10 ,2) NOT NULL DEFAULT 0,
    montant_ttc DECIMAL (10 ,2) NOT NULL DEFAULT 0,
    montant_paye DECIMAL (10 ,2) NOT NULL DEFAULT 0,
    solde_restant DECIMAL (10 ,2) NOT NULL DEFAULT 0,
    statut VARCHAR (20) NOT NULL DEFAULT 'IMPAYEE',
    remarques TEXT ,
    id_utilisateur INTEGER NOT NULL ,
    date_creation TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ,

    -- Clés étrangres
    CONSTRAINT fk_facture_client FOREIGN KEY ( id_client )
    REFERENCES client ( id_client ) ON DELETE RESTRICT ,
    CONSTRAINT fk_facture_devis FOREIGN KEY ( id_devis )
    REFERENCES devis ( id_devis ) ON DELETE RESTRICT ,
    CONSTRAINT fk_facture_utilisateur FOREIGN KEY ( id_utilisateur
    )
    REFERENCES utilisateur ( id_utilisateur ) ON DELETE RESTRICT

 -- Contraintes
    CONSTRAINT chk_facture_statut CHECK ( statut IN ('IMPAYEE', 'PARTIELLEMENT_PAYEE', 'PAYE', 'ANNULEE')),
    CONSTRAINT chk_facture_dates CHECK ( date_echeance >=date_emission ),
    CONSTRAINT chk_facture_montants CHECK (
        montant_ht >= 0 AND
        montant_tva >= 0 AND
        montant_ttc >= 0 AND
        montant_paye >= 0 AND
        montant_paye <= montant_ttc AND
        solde_restant >= 0 AND
        solde_restant = montant_ttc - montant_paye)
);

-- Index pour recherches et performances
CREATE INDEX idx_facture_numero ON facture ( numero );
CREATE INDEX idx_facture_client ON facture ( id_client );
CREATE INDEX idx_facture_statut ON facture ( statut );
CREATE INDEX idx_facture_date ON facture ( date_emission DESC );
CREATE INDEX idx_facture_devis ON facture ( id_devis );

-- TABLE : PAIEMENT
-- ================================================
CREATE TABLE paiement (
    id_paiement SERIAL PRIMARY KEY ,
    id_facture INTEGER NOT NULL ,
    date_paiement DATE NOT NULL DEFAULT CURRENT_DATE ,
    montant DECIMAL (10 ,2) NOT NULL ,
    mode_paiement VARCHAR (20) NOT NULL ,
    reference VARCHAR (50) ,
    remarques TEXT ,
    id_utilisateur INTEGER NOT NULL ,
    date_creation TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ,
    -- Clés étrangres
    CONSTRAINT fk_paiement_facture FOREIGN KEY ( id_facture )
        REFERENCES facture ( id_facture ) ON DELETE RESTRICT ,
    CONSTRAINT fk_paiement_utilisateur FOREIGN KEY (id_utilisateur )
        REFERENCES utilisateur ( id_utilisateur ) ON DELETE RESTRICT
    -- Contraintes
    CONSTRAINT chk_paiement_montant CHECK ( montant > 0) ,
    CONSTRAINT chk_paiement_mode CHECK ( mode_paiement IN ('ESPECES', 'CARTE', 'CHEQUE','VIREMENT', 'AUTRE'))
);
-- Index pour recherches
CREATE INDEX idx_paiement_facture ON paiement ( id_facture );
CREATE INDEX idx_paiement_date ON paiement ( date_paiement DESC );
CREATE INDEX idx_paiement_mode ON paiement ( mode_paiement );


-- VUES UTILES
-- ================================================

-- Vue : Historique complet client
CREATE OR REPLACE VIEW v_historique_client AS
SELECT
    c. id_client ,
    c.nom || ' ' || COALESCE (c.prenom , '') AS nom_complet ,
    'DEVIS' AS type_document ,
    d. numero AS numero_document ,
    d. date_emission ,
    d. montant_ttc ,
    d.statut ,
    NULL AS solde_restant
FROM client c
JOIN devis d ON c. id_client = d. id_client
UNION ALL
SELECT
    c. id_client ,
    c.nom || ' ' || COALESCE (c.prenom , '') AS nom_complet ,
    'FACTURE' AS type_document ,
    f. numero AS numero_document ,
    f. date_emission ,
    f. montant_ttc ,
    f.statut ,
    f. solde_restant
FROM client c
JOIN facture f ON c. id_client = f. id_client
ORDER BY date_emission DESC ;

-- Vue : Factures i m p a y e s ou partiellement p a y e s

CREATE OR REPLACE VIEW v_factures_impayees AS
SELECT
    f. id_facture ,
    f.numero ,
    f. date_emission ,
    f. date_echeance ,
    c.nom || ' ' || COALESCE (c.prenom , '') AS nom_client ,
    c. telephone ,
    f. montant_ttc ,
    f. montant_paye ,
    f. solde_restant ,
    f.statut ,
    CASE
        WHEN f. date_echeance < CURRENT_DATE THEN 'EN_RETARD'
        ELSE 'A_JOUR'
    END AS etat_echeance
FROM facture f
JOIN client c ON f. id_client = c. id_client
WHERE f. statut IN ('IMPAYEE', 'PARTIELLEMENT_PAYEE')
ORDER BY f. date_echeance ASC;

-- Vue : Statistiques des services
CREATE OR REPLACE VIEW v_statistiques_services AS
SELECT
    s. id_service ,
    s.code ,
    s. designation ,
    s. categorie ,
    COUNT ( DISTINCT lf. id_facture ) AS nb_factures ,
    SUM (lf. quantite ) AS quantite_totale ,
    SUM (lf. montant_ttc ) AS ca_total
FROM service s
LEFT JOIN ligne_facture lf ON s. id_service = lf. id_service
LEFT JOIN facture f ON lf. id_facture = f. id_facture
WHERE f. statut != 'ANNULEE ' OR f. statut IS NULL
GROUP BY s. id_service , s.code , s. designation , s. categorie
ORDER BY ca_total DESC NULLS LAST ;

-- FONCTIONS ET TRIGGERS
-- ================================================

-- Fonction : Génération automatique numéro devis
CREATE OR REPLACE FUNCTION generer_numero_devis ()
RETURNS TRIGGER AS $
DECLARE
    annee INTEGER ;
    prochain_numero INTEGER ;
    nouveau_numero VARCHAR (20) ;

BEGIN
    annee := EXTRACT ( YEAR FROM CURRENT_DATE );

    SELECT COALESCE (MAX ( CAST ( SUBSTRING ( numero FROM 10) AS INTEGER
    )), 0) + 1
    INTO prochain_numero
    FROM devis
    WHERE SUBSTRING ( numero FROM 5 FOR 4) = annee :: TEXT ;

    nouveau_numero := 'DEV -' || annee || '-' || LPAD (
    prochain_numero :: TEXT , 4, '0');

    NEW . numero := nouveau_numero ;
    RETURN NEW ;
END ;
$ LANGUAGE postgresql ;

CREATE TRIGGER trg_generer_numero_devis
BEFORE INSERT ON devis
FOR EACH ROW
WHEN (NEW . numero IS NULL OR NEW. numero = '')
EXECUTE FUNCTION generer_numero_devis ();

-- Fonction : Genration automatique numro facture
CREATE OR REPLACE FUNCTION generer_numero_facture ()
RETURNS TRIGGER AS $
DECLARE 
    annee INTEGER ;
    prochain_numero INTEGER ;
    nouveau_numero VARCHAR (20) ;
BEGIN
    annee := EXTRACT ( YEAR FROM CURRENT_DATE );

    SELECT COALESCE (MAX ( CAST ( SUBSTRING ( numero FROM 10) AS INTEGER
    )), 0) + 1
    INTO prochain_numero
    FROM facture
    WHERE SUBSTRING ( numero FROM 5 FOR 4) = annee :: TEXT ;

    nouveau_numero := 'FAC -' || annee || '-' || LPAD (
    prochain_numero :: TEXT , 4, '0');

    NEW . numero := nouveau_numero ;
    RETURN NEW ;
END ;
$ LANGUAGE postpgresql ;

CREATE TRIGGER trg_generer_numero_facture
BEFORE INSERT ON facture

FOR EACH ROW
WHEN (NEW . numero IS NULL OR NEW. numero = '')
EXECUTE FUNCTION generer_numero_facture ();

-- Fonction : Calcul automatique montants ligne devis
CREATE OR REPLACE FUNCTION calculer_montants_ligne_devis ()
RETURNS TRIGGER AS $
BEGIN
    NEW . montant_ht := NEW. quantite * NEW. prix_unitaire_ht ;
    NEW . montant_tva := NEW . montant_ht * (NEW. taux_tva / 100) ;
    NEW . montant_ttc := NEW . montant_ht + NEW. montant_tva ;

    -- Arrondi 2 d c i m a l e s
    NEW . montant_ht := ROUND (NEW. montant_ht , 2);
    4NEW . montant_tva := ROUND (NEW. montant_tva , 2);
    NEW . montant_ttc := ROUND (NEW. montant_ttc , 2);

    RETURN NEW ;
END ;
$ LANGUAGE postgresql ;

CREATE TRIGGER trg_calculer_montants_ligne_devis
BEFORE INSERT OR UPDATE ON ligne_devis
FOR EACH ROW
EXECUTE FUNCTION calculer_montants_ligne_devis ();

-- Fonction : Calcul automatique montants ligne facture
CREATE OR REPLACE FUNCTION calculer_montants_ligne_facture ()
RETURNS TRIGGER AS $
BEGIN
    NEW . montant_ht := NEW. quantite * NEW. prix_unitaire_ht ;
    NEW . montant_tva := NEW . montant_ht * (NEW. taux_tva / 100) ;
    NEW . montant_ttc := NEW . montant_ht + NEW. montant_tva ;

    -- Arrondi 2 d c i m a l e s
    NEW . montant_ht := ROUND (NEW. montant_ht , 2);
    NEW . montant_tva := ROUND (NEW. montant_tva , 2);
    NEW . montant_ttc := ROUND (NEW. montant_ttc , 2);
    RETURN NEW ;
END ;
$ LANGUAGE postgresql ;

CREATE TRIGGER trg_calculer_montants_ligne_facture
BEFORE INSERT OR UPDATE ON ligne_facture
FOR EACH ROW
EXECUTE FUNCTION calculer_montants_ligne_facture ();

-- Fonction : Mise jour totaux devis

CREATE OR REPLACE FUNCTION maj_totaux_devis ()
RETURNS TRIGGER AS $
DECLARE
    v_id_devis INTEGER ;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_id_devis := OLD . id_devis ;
    ELSE
        v_id_devis := NEW . id_devis ;
    END IF;
    UPDATE devis
    SET montant_ht = (
            SELECT COALESCE (SUM ( montant_ht ), 0)
            FROM ligne_devis
            WHERE id_devis = v_id_devis
            ),
        montant_tva = (
            SELECT COALESCE (SUM ( montant_tva ), 0)
            FROM ligne_devis
            WHERE id_devis = v_id_devis
            ),
        montant_ttc = (
            SELECT COALESCE (SUM ( montant_ttc ), 0)
            FROM ligne_devis
            WHERE id_devis = v_id_devis
            )
    WHERE id_devis = v_id_devis ;

    RETURN NULL ;
END ;
$ LANGUAGE postgresql ;

CREATE TRIGGER trg_maj_totaux_devis
AFTER INSERT OR UPDATE OR DELETE ON ligne_devis
FOR EACH ROW
EXECUTE FUNCTION maj_totaux_devis ();

-- Fonction : Mise jour totaux facture
CREATE OR REPLACE FUNCTION maj_totaux_facture ()
RETURNS TRIGGER AS $
DECLARE
    v_id_facture INTEGER ;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_id_facture := OLD . id_facture ;
    ELSE
        v_id_facture := NEW . id_facture ;
END IF;

    UPDATE facture
    SET montant_ht = (
        SELECT COALESCE (SUM ( montant_ht ), 0)
        FROM ligne_facture
        WHERE id_facture = v_id_facture
        ),
        montant_tva = (
        SELECT COALESCE (SUM ( montant_tva ), 0)
        FROM ligne_facture
        WHERE id_facture = v_id_facture
        ),
        montant_ttc = (
        SELECT COALESCE (SUM ( montant_ttc ), 0)
        FROM ligne_facture
        WHERE id_facture = v_id_facture
        );

        solde_restant = (
        SELECT COALESCE (SUM ( montant_ttc ), 0)
        FROM ligne_facture
        WHERE id_facture = v_id_facture
        ) - (
        SELECT COALESCE (SUM ( montant ), 0)
        FROM paiement
        WHERE id_facture = v_id_facture
        )
        WHERE id_facture = v_id_facture ;

    RETURN NULL ;
END ;
$ LANGUAGE postgresql ;

CREATE TRIGGER trg_maj_totaux_facture
AFTER INSERT OR UPDATE OR DELETE ON ligne_facture
FOR EACH ROW
EXECUTE FUNCTION maj_totaux_facture ();

-- Fonction : Mise jour statut facture a p r s paiement
CREATE OR REPLACE FUNCTION maj_statut_facture_paiement ()
RETURNS TRIGGER AS $
DECLARE
    v_id_facture INTEGER ;
    v_montant_ttc DECIMAL (10 ,2);
    v_montant_paye DECIMAL (10 ,2);
    v_solde DECIMAL (10 ,2);
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_id_facture := OLD . id_facture ;
    ELSE

        v_id_facture := NEW . id_facture ;
    END IF;

-- Calcul du montant p a y total
    SELECT
        f. montant_ttc ,
        COALESCE (SUM (p. montant ), 0)
    INTO v_montant_ttc , v_montant_paye
    FROM facture f
    LEFT JOIN paiement p ON f. id_facture = p. id_facture
    WHERE f. id_facture = v_id_facture
    GROUP BY f. montant_ttc ;

    v_solde := v_montant_ttc - v_montant_paye ;

    -- Mise jour de la facture
    UPDATE facture
    SET montant_paye = v_montant_paye ,
        solde_restant = v_solde ,
        statut = CASE
            WHEN v_solde = 0 THEN 'PAYEE'
            WHEN v_solde > 0 AND v_montant_paye > 0 THEN 'PARTIELLEMENT_PAYEE'
            ELSE 'IMPAYEE'
        END
    WHERE id_facture = v_id_facture ;

RETURN NULL ;
END
$ LANGUAGE postgresql ;

CREATE TRIGGER trg_maj_statut_facture_paiement
AFTER INSERT OR UPDATE OR DELETE ON paiement
FOR EACH ROW
EXECUTE FUNCTION maj_statut_facture_paiement ();

-- DONNEES DE TEST --

INSERT INTO utilisateur (nom , prenom , email , mot_de_passe_hash ,
role ) VALUES
    ('ADMIN', 'Gerant', 'gerant@station.tg', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8 / LewY5GyYIj .7', 'GERANT'),
    ('MENSAH', 'Kofi', 'kofimensah@statio.tg', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8 / LewY5GyYIj .7', 'EMPLOYE');

-- Insertion clients
INSERT INTO client (nom , prenom , telephone , email , ville ,
immatriculation_vehicule , modele_vehicule ) VALUES
    ('AGBODJAN', 'Edem', '90123456', 'edemagbodjan@email.tg', 'Lome', 'TG -1234 - AA', 'Toyota Corolla 2018 '),
    ('KOUASSI', 'Ama', '91234567', 'amakouassi@email.tg', 'Lome', '
    TG -5678 - BB', 'Honda Civic 2020'),
    ('ATTIOGBE', 'Koffi', '92345678', NULL , 'Kara', 'TG -9012 - CC', '
    Peugeot 208 2019');

-- Insertion services
INSERT INTO service (code , designation , prix_unitaire_ht ,
taux_tva , unite , categorie ) VALUES
    ('CARB -ESS', 'Essence Super', 650.00 , 20.00 , 'litre', 'Carburant'),
    ('CARB -GAZ', 'Gasoil', 580.00 , 20.00 , 'litre', 'Carburant'),
    ('MAINT -VID', 'Vidange complete', 25000.00 , 20.00 , 'unit', 'Entretien'),
    ('MAINT -FIL', 'Changement filtres', 8000.00 , 20.00 , 'unit', 'Entretien'),
    ('LAV -EXT', 'Lavage exterieur', 3000.00 , 20.00 , 'unit', 'Lavage'),
    ('LAV - COMP ', 'Lavage complet + interieur', 6000.00 , 20.00 , 'unit', 'Lavage'),
    ('PNEU -MNT ','Montage / Démontage pneus', 4000.00 , 20.00 , 'pneu',
    'Pneumatique'),
    ('DIAG - ELEC', 'Diagnostic lectronique', 15000.00 , 20.00 , 'unit', 'Diagnostic');
-- Message de confirmation
DO $
BEGIN
    RAISE NOTICE 'Base de donnée créee avec succes !';
    RAISE NOTICE 'Utilisateurs : 2 (1 gérant ,1 employé )';
    RAISE NOTICE 'Clients : 3';
    RAISE NOTICE 'Services : 8';
END $;