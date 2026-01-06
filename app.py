# app.py - Application Flask pour système de facturation
from flask import Flask, render_template, request, jsonify, send_file
from flask_cors import CORS
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime, timedelta
from decimal import Decimal
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import cm
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_RIGHT
import os
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'change-me')

# Activer CORS pour permettre les requêtes depuis le navigateur
CORS(app)

# ============================================
# CONNEXION BASE DE DONNÉES
# ============================================

def get_db_connection():
    """Établit une connexion à la base de données PostgreSQL"""
    conn = psycopg2.connect(
        host=os.getenv('DB_HOST', 'localhost'),
        database=os.getenv('DB_NAME', 'projetBDD'),
        user=os.getenv('DB_USER', 'postgres'),
        password=os.getenv('DB_PASSWORD', 'zizou'),
        port=os.getenv('DB_PORT', '5432')
    )
    return conn

# ============================================
# ROUTES PAGE D'ACCUEIL
# ============================================

@app.route('/')
def index():
    """Page d'accueil avec dashboard"""
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Statistiques du jour
            cur.execute("""
                SELECT 
                    COUNT(*) as nb_factures,
                    COALESCE(SUM(montant_ttc), 0) as ca_jour,
                    COALESCE(SUM(montant_paye), 0) as encaissements
                FROM factures 
                WHERE date_facture = CURRENT_DATE
            """)
            stats_jour = cur.fetchone()

            # Factures impayées
            cur.execute("""
                SELECT COUNT(*) as nb_impayees, COALESCE(SUM(solde_restant), 0) as montant_impaye
                FROM factures 
                WHERE statut IN ('IMPAYEE', 'PARTIELLEMENT_PAYEE')
            """)
            stats_impayees = cur.fetchone()

        return render_template('factures.html', stats_jour=stats_jour, stats_impayees=stats_impayees)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

# ROUTES CLIENTS


@app.route('/clients')
def clients():
    """Liste des clients"""
    return render_template('clients.html')

@app.route('/api/clients', methods=['GET'])
def get_clients():
    """API: Récupère tous les clients"""
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT id_client, nom, prenom, telephone, email, type_client, actif
                FROM clients 
                WHERE actif = TRUE
                ORDER BY nom, prenom
            """)
            clients = cur.fetchall()
        return jsonify(clients)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/clients', methods=['POST'])
def create_client():
    """API: Crée un nouveau client"""
    conn = None
    try:
        data = request.json
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                INSERT INTO clients (nom, prenom, telephone, email, type_client)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING id_client, nom, prenom
            """, (data['nom'], data.get('prenom'), data.get('telephone'), 
                  data.get('email'), data.get('type_client', 'particulier')))
            client = cur.fetchone()
        conn.commit()
        return jsonify({'success': True, 'client': client}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

# ROUTES SERVICES

@app.route('/services')
def services():
    """Liste des services"""
    return render_template('services.html')

@app.route('/api/services', methods=['GET'])
def get_services():
    """API: Récupère tous les services actifs"""
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT id_service, code_service, libelle, prix_unitaire_ht, 
                       taux_tva, categorie, unite_mesure
                FROM services 
                WHERE actif = TRUE
                ORDER BY categorie, libelle
            """)
            services = cur.fetchall()
        return jsonify(services)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/services', methods=['POST'])
def create_service():
    """API: Crée un nouveau service"""
    conn = None
    try:
        data = request.json
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                INSERT INTO services (code_service, libelle, prix_unitaire_ht, 
                                    taux_tva, categorie, unite_mesure)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id_service, code_service, libelle
            """, (data['code_service'], data['libelle'], data['prix_unitaire_ht'],
                  data.get('taux_tva', 20), data['categorie'], data.get('unite_mesure', 'unité')))
            service = cur.fetchone()
        conn.commit()
        return jsonify({'success': True, 'service': service}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()


# ROUTES FACTURES


@app.route('/factures')
def factures():
    """Page de gestion des factures"""
    return render_template('factures.html')

@app.route('/api/factures', methods=['GET'])
def get_factures():
    """API: Récupère toutes les factures"""
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT 
                    f.id_facture,
                    f.numero_facture,
                    f.date_facture,
                    c.nom || ' ' || COALESCE(c.prenom, '') as client,
                    f.montant_ttc,
                    f.montant_paye,
                    f.solde_restant,
                    f.statut
                FROM factures f
                JOIN clients c ON f.id_client = c.id_client
                ORDER BY f.date_facture DESC
                LIMIT 100
            """)
            factures = cur.fetchall()

        # Convertir types non JSON-serialisables (Decimal, date) en types natifs JSON
        def serialize_row(row):
            out = {}
            for k, v in row.items():
                if isinstance(v, Decimal):
                    out[k] = float(v)
                elif isinstance(v, (datetime,)):
                    out[k] = v.isoformat()
                else:
                    out[k] = v
            return out

        factures_serialized = [serialize_row(r) for r in factures]
        return jsonify(factures_serialized)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/factures', methods=['POST'])
def create_facture():
    """API: Crée une nouvelle facture"""
    conn = None
    try:
        data = request.json
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Insertion de la facture
            date_echeance = datetime.now() + timedelta(days=30)
            cur.execute("""
                INSERT INTO factures (id_client, date_echeance, observations)
                VALUES (%s, %s, %s)
                RETURNING id_facture, numero_facture
            """, (data['id_client'], date_echeance, data.get('observations', '')))
            facture = cur.fetchone()
            id_facture = facture['id_facture']

            # Insertion des lignes de facture
            for ligne in data['lignes']:
                cur.execute("""
                    INSERT INTO lignes_factures 
                    (id_facture, id_service, quantite, prix_unitaire_ht, taux_tva)
                    VALUES (%s, %s, %s, %s, %s)
                """, (id_facture, ligne['id_service'], ligne['quantite'],
                      ligne['prix_unitaire_ht'], ligne['taux_tva']))

            # Récupération de la facture complète
            cur.execute("""
                SELECT 
                    f.*,
                    c.nom, c.prenom, c.telephone, c.email, c.adresse
                FROM factures f
                JOIN clients c ON f.id_client = c.id_client
                WHERE f.id_facture = %s
            """, (id_facture,))
            facture_complete = cur.fetchone()

        conn.commit()
        return jsonify({'success': True, 'facture': facture_complete}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/factures/<int:id_facture>')
def get_facture_detail(id_facture):
    """API: Récupère le détail d'une facture"""
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Récupération facture
            cur.execute("""
                SELECT 
                    f.*,
                    c.nom, c.prenom, c.telephone, c.email, c.adresse
                FROM factures f
                JOIN clients c ON f.id_client = c.id_client
                WHERE f.id_facture = %s
            """, (id_facture,))
            facture = cur.fetchone()

            # Récupération lignes
            cur.execute("""
                SELECT 
                    lf.*,
                    s.libelle, s.unite_mesure
                FROM lignes_factures lf
                JOIN services s ON lf.id_service = s.id_service
                WHERE lf.id_facture = %s
            """, (id_facture,))
            lignes = cur.fetchall()

            # Récupération paiements
            cur.execute("""
                SELECT * FROM paiements
                WHERE id_facture = %s
                ORDER BY date_paiement DESC
            """, (id_facture,))
            paiements = cur.fetchall()

        return jsonify({'facture': facture, 'lignes': lignes, 'paiements': paiements})
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()


# ROUTES PAIEMENTS


@app.route('/api/paiements', methods=['POST'])
def create_paiement():
    """API: Enregistre un paiement"""
    conn = None
    try:
        data = request.json
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                INSERT INTO paiements 
                (id_facture, montant, mode_paiement, reference_paiement, observations)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING id_paiement, date_paiement
            """, (data['id_facture'], data['montant'], data['mode_paiement'],
                  data.get('reference_paiement'), data.get('observations')))
            paiement = cur.fetchone()
        conn.commit()
        return jsonify({'success': True, 'paiement': paiement}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()


# GÉNÉRATION PDF


@app.route('/api/factures/<int:id_facture>/pdf')
def generer_pdf_facture(id_facture):
    """Génère un PDF pour une facture"""
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Récupération données
            cur.execute("""
                SELECT 
                    f.*,
                    c.nom, c.prenom, c.telephone, c.email, c.adresse
                FROM factures f
                JOIN clients c ON f.id_client = c.id_client
                WHERE f.id_facture = %s
            """, (id_facture,))
            facture = cur.fetchone()

            cur.execute("""
                SELECT 
                    lf.*,
                    s.libelle, s.unite_mesure
                FROM lignes_factures lf
                JOIN services s ON lf.id_service = s.id_service
                WHERE lf.id_facture = %s
            """, (id_facture,))
            lignes = cur.fetchall()

        # Création PDF
        filename = f"facture_{facture['numero_facture']}.pdf"
        filepath = os.path.join('exports', filename)
        os.makedirs('exports', exist_ok=True)
        
        doc = SimpleDocTemplate(filepath, pagesize=A4)
        elements = []
        styles = getSampleStyleSheet()
        
        # Titre
        title_style = ParagraphStyle(
            'CustomTitle',
            parent=styles['Heading1'],
            fontSize=24,
            textColor=colors.HexColor('#2c3e50'),
            alignment=TA_CENTER
        )
        elements.append(Paragraph(f"FACTURE N° {facture['numero_facture']}", title_style))
        elements.append(Spacer(1, 1*cm))
        
        # Informations client
        client_info = f"""
        <b>Client:</b><br/>
        {facture['nom']} {facture.get('prenom', '')}<br/>
        {facture.get('adresse', '')}<br/>
        Tél: {facture.get('telephone', '')}<br/>
        Email: {facture.get('email', '')}
        """
        elements.append(Paragraph(client_info, styles['Normal']))
        elements.append(Spacer(1, 0.5*cm))
        
        # Date
        date_info = f"Date: {facture['date_facture'].strftime('%d/%m/%Y')}<br/>Échéance: {facture['date_echeance'].strftime('%d/%m/%Y')}"
        elements.append(Paragraph(date_info, styles['Normal']))
        elements.append(Spacer(1, 1*cm))
        
        # Tableau des lignes
        data = [['Désignation', 'Qté', 'PU HT', 'TVA', 'Total TTC']]
        for ligne in lignes:
            data.append([
                ligne['libelle'],
                f"{ligne['quantite']} {ligne['unite_mesure']}",
                f"{ligne['prix_unitaire_ht']:.2f} €",
                f"{ligne['taux_tva']:.0f}%",
                f"{ligne['montant_ttc']:.2f} €"
            ])
        
        table = Table(data, colWidths=[8*cm, 2*cm, 3*cm, 2*cm, 3*cm])
        table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#3498db')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 12),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
            ('GRID', (0, 0), (-1, -1), 1, colors.black),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#ecf0f1')])
        ]))
        elements.append(table)
        elements.append(Spacer(1, 1*cm))
        
        # Totaux
        totaux_style = ParagraphStyle(
            'Totaux',
            parent=styles['Normal'],
            fontSize=12,
            alignment=TA_RIGHT
        )
        elements.append(Paragraph(f"<b>Total HT:</b> {facture['montant_ht']:.2f} €", totaux_style))
        elements.append(Paragraph(f"<b>TVA:</b> {facture['montant_tva']:.2f} €", totaux_style))
        elements.append(Paragraph(f"<b style='font-size:14'>TOTAL TTC:</b> <b style='font-size:14'>{facture['montant_ttc']:.2f} €</b>", totaux_style))
        
        # Génération
        doc.build(elements)
        
        return send_file(filepath, as_attachment=True, download_name=filename)
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# LANCEMENT APPLICATION

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)