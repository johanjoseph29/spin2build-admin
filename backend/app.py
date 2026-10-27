import os
import random
from flask import Flask, request, jsonify, abort
from flask_cors import CORS
from sqlalchemy.exc import IntegrityError
from sqlalchemy import func
from database import SessionLocal, init_db, Admin, Team, Topic, Assignment

app = Flask(__name__)
CORS(app)

# Simple in‑memory token store for the demo
ADMIN_TOKEN = None

def require_admin(func):
    def wrapper(*args, **kwargs):
        auth = request.headers.get('Authorization', '')
        if not auth.startswith('Bearer '):
            abort(401, description='Missing token')
        token = auth.split(' ', 1)[1]
        if token != ADMIN_TOKEN:
            abort(403, description='Invalid token')
        return func(*args, **kwargs)
    wrapper.__name__ = func.__name__
    return wrapper

# Initialize DB when the module loads
init_db()

# ---------- Admin ----------
@app.route('/admin/login', methods=['POST'])
def admin_login():
    data = request.get_json() or {}
    password = data.get('password')
    if not password:
        abort(400, description='Password required')
    with SessionLocal() as db:
        admin = db.query(Admin).first()
        if admin and admin.password == password:
            global ADMIN_TOKEN
            # For simplicity generate a random token each login
            ADMIN_TOKEN = ''.join(random.choices('abcdefghijklmnopqrstuvwxyz0123456789', k=32))
            return jsonify({'token': ADMIN_TOKEN})
    abort(401, description='Invalid credentials')

# Topic CRUD
@app.route('/admin/topics', methods=['POST'])
@require_admin
def add_topic():
    data = request.get_json() or {}
    title = data.get('title', '').strip()
    description = data.get('description', '').strip()
    if not title:
        abort(400, description='Title required')
    with SessionLocal() as db:
        topic = Topic(title=title, description=description or None)
        db.add(topic)
        try:
            db.commit()
            db.refresh(topic)
        except IntegrityError:
            db.rollback()
            abort(409, description='Duplicate topic title')
        return jsonify({'id': topic.id, 'title': topic.title, 'description': topic.description})

@app.route('/admin/topics/bulk', methods=['POST'])
@require_admin
def bulk_add_topics():
    data = request.get_json() or {}
    raw = data.get('topics', '')
    if not isinstance(raw, str):
        abort(400, description='"topics" must be a newline‑separated string')
    titles = [line.strip() for line in raw.split('\n') if line.strip()]
    added = []
    duplicates = []
    with SessionLocal() as db:
        for t in titles:
            if not t:
                continue
            topic = Topic(title=t)
            db.add(topic)
            try:
                db.commit()
                db.refresh(topic)
                added.append({'id': topic.id, 'title': t})
            except IntegrityError:
                db.rollback()
                duplicates.append(t)
    return jsonify({'added': added, 'duplicates': duplicates})

@app.route('/admin/topics/<int:topic_id>', methods=['PUT'])
@require_admin
def edit_topic(topic_id):
    data = request.get_json() or {}
    title = data.get('title')
    description = data.get('description')
    with SessionLocal() as db:
        topic = db.query(Topic).filter(Topic.id == topic_id).first()
        if not topic:
            abort(404, description='Topic not found')
        # Disallow editing assigned topics without explicit confirmation flag
        if topic.assignment and not data.get('force'):
            abort(400, description='Topic is assigned; set "force": true to edit')
        if title is not None:
            topic.title = title.strip()
        if description is not None:
            topic.description = description.strip() or None
        try:
            db.commit()
        except IntegrityError:
            db.rollback()
            abort(409, description='Duplicate topic title')
        return jsonify({'id': topic.id, 'title': topic.title, 'description': topic.description})

@app.route('/admin/topics/<int:topic_id>', methods=['DELETE'])
@require_admin
def delete_topic(topic_id):
    confirm = request.args.get('confirm') == 'true'
    with SessionLocal() as db:
        topic = db.query(Topic).filter(Topic.id == topic_id).first()
        if not topic:
            abort(404, description='Topic not found')
        if topic.assignment and not confirm:
            abort(400, description='Topic assigned; pass confirm=true to delete')
        db.delete(topic)
        db.commit()
        return jsonify({'deleted': topic_id})

@app.route('/admin/topics', methods=['GET'])
@require_admin
def list_topics():
    search = request.args.get('search', '').strip().lower()
    with SessionLocal() as db:
        q = db.query(Topic)
        if search:
            q = q.filter(func.lower(Topic.title).contains(search))
        topics = q.all()
        result = []
        for t in topics:
            result.append({
                'id': t.id,
                'title': t.title,
                'description': t.description,
                'assigned': bool(t.assignment)
            })
        return jsonify(result)

# Team management
@app.route('/admin/teams', methods=['POST'])
@require_admin
def register_team():
    data = request.get_json() or {}
    name = data.get('name', '').strip()
    if not name:
        abort(400, description='Team name required')
    # generate a 6‑character alphanumeric code
    while True:
        code = ''.join(random.choices('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', k=6))
        with SessionLocal() as db:
            if not db.query(Team).filter(Team.code == code).first():
                team = Team(name=name, code=code)
                db.add(team)
                db.commit()
                db.refresh(team)
                return jsonify({'id': team.id, 'name': team.name, 'code': team.code})

@app.route('/admin/teams', methods=['GET'])
@require_admin
def list_teams():
    with SessionLocal() as db:
        teams = db.query(Team).all()
        return jsonify([
            {'id': t.id, 'name': t.name, 'code': t.code, 'has_assignment': bool(t.assignment)}
            for t in teams
        ])

# Overview cards
@app.route('/admin/overview', methods=['GET'])
@require_admin
def overview():
    with SessionLocal() as db:
        total_teams = db.query(Team).count()
        total_topics = db.query(Topic).count()
        assigned = db.query(Assignment).count()
        available = total_topics - assigned
        return jsonify({
            'total_teams': total_teams,
            'total_topics': total_topics,
            'assigned_topics': assigned,
            'available_topics': available
        })

# Assignment table
@app.route('/admin/assignments', methods=['GET'])
@require_admin
def assignments_table():
    with SessionLocal() as db:
        assignments = db.query(Assignment).join(Team).join(Topic).all()
        result = []
        for a in assignments:
            result.append({
                'team_name': a.team.name,
                'team_code': a.team.code,
                'topic_title': a.topic.title,
                'assigned_at': a.assigned_at.isoformat()
            })
        return jsonify(result)

# Reset assignments
@app.route('/admin/reset_assignments', methods=['POST'])
@require_admin
def reset_assignments():
    confirm = request.args.get('confirm') == 'true'
    if not confirm:
        abort(400, description='Pass confirm=true to reset')
    with SessionLocal() as db:
        db.query(Assignment).delete()
        db.commit()
        return jsonify({'reset': True})

# ---------- Team ----------
@app.route('/team/validate', methods=['POST'])
def team_validate():
    data = request.get_json() or {}
    code = data.get('code', '').strip().upper()
    if not code:
        abort(400, description='Code required')
    with SessionLocal() as db:
        team = db.query(Team).filter(Team.code == code).first()
        if not team:
            abort(404, description='Team not found')
        assignment = None
        if team.assignment:
            assignment = {'topic_id': team.assignment.topic.id, 'title': team.assignment.topic.title}
        
        # Also return current list of available topics so the wheel renders the real topics!
        available_topics = db.query(Topic).outerjoin(Assignment).filter(Assignment.id.is_(None)).all()
        topic_titles = [t.title for t in available_topics]
        return jsonify({
            'team_id': team.id,
            'team_name': team.name,
            'code': team.code,
            'assignment': assignment,
            'available_topics': topic_titles
        })

@app.route('/team/spin', methods=['POST'])
def team_spin():
    data = request.get_json() or {}
    code = data.get('code', '').strip().upper()
    if not code:
        abort(400, description='Code required')
    with SessionLocal() as db:
        team = db.query(Team).filter(Team.code == code).first()
        if not team:
            abort(404, description='Team not found')
        # Return existing assignment if any
        if team.assignment:
            return jsonify({'topic_id': team.assignment.topic.id, 'title': team.assignment.topic.title})
        # Transaction: pick a random available topic
        available_topic = db.query(Topic).outerjoin(Assignment).filter(Assignment.id.is_(None)).order_by(func.random()).first()
        if not available_topic:
            abort(409, description='No available topics')
        assignment = Assignment(team_id=team.id, topic_id=available_topic.id)
        db.add(assignment)
        try:
            db.commit()
        except IntegrityError:
            db.rollback()
            abort(500, description='Assignment conflict, try again')
        return jsonify({'topic_id': available_topic.id, 'title': available_topic.title})

if __name__ == '__main__':
    # Listen on all interfaces (LAN) – default Flask port 5000
    app.run(host='0.0.0.0', port=5000, debug=True)
