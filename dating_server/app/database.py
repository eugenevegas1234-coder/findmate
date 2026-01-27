import psycopg
from psycopg.rows import dict_row

DATABASE_URL = "postgresql://postgres:23111978Dd@localhost:5432/dating_db"

def get_connection():
    return psycopg.connect(DATABASE_URL, row_factory=dict_row)

def init_db():
    conn = get_connection()
    cur = conn.cursor()
    
    cur.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            email VARCHAR(255) UNIQUE NOT NULL,
            password VARCHAR(255) NOT NULL,
            name VARCHAR(100) NOT NULL,
            age INTEGER,
            city VARCHAR(100),
            bio TEXT,
            interests TEXT[],
            photo VARCHAR(500),
            latitude DOUBLE PRECISION,
            longitude DOUBLE PRECISION,
            show_location BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    cur.execute("""
        CREATE TABLE IF NOT EXISTS likes (
            id SERIAL PRIMARY KEY,
            from_user_id INTEGER REFERENCES users(id),
            to_user_id INTEGER REFERENCES users(id),
            is_like BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(from_user_id, to_user_id)
        )
    """)
    
    cur.execute("""
        CREATE TABLE IF NOT EXISTS matches (
            id SERIAL PRIMARY KEY,
            user1_id INTEGER REFERENCES users(id),
            user2_id INTEGER REFERENCES users(id),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(user1_id, user2_id)
        )
    """)
    
    conn.commit()
    cur.close()
    conn.close()
    print("Database initialized!")

def load_users():
    users = {}
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("SELECT * FROM users")
        rows = cur.fetchall()
        for row in rows:
            user_id = row['id']
            users[user_id] = {
                "id": user_id,
                "email": row['email'],
                "password": row['password'],
                "name": row['name'],
                "age": row.get('age'),
                "city": row.get('city'),
                "bio": row.get('bio'),
                "interests": row.get('interests') or [],
                "photo": row.get('photo'),
                "latitude": float(row['latitude']) if row.get('latitude') else None,
                "longitude": float(row['longitude']) if row.get('longitude') else None,
                "show_location": row.get('show_location', True),
                "created_at": str(row.get('created_at', ''))
            }
        cur.close()
        conn.close()
    except Exception as e:
        print(f"Error loading users: {e}")
    return users

def load_likes():
    likes = {}
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("SELECT from_user_id, to_user_id FROM likes")
        rows = cur.fetchall()
        for row in rows:
            from_id = row['from_user_id']
            to_id = row['to_user_id']
            if from_id not in likes:
                likes[from_id] = []
            likes[from_id].append(to_id)
        cur.close()
        conn.close()
    except Exception as e:
        print(f"Error loading likes: {e}")
    return likes

def load_matches():
    matches = {}
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("SELECT user1_id, user2_id FROM matches")
        rows = cur.fetchall()
        for row in rows:
            u1, u2 = row['user1_id'], row['user2_id']
            if u1 not in matches:
                matches[u1] = []
            if u2 not in matches:
                matches[u2] = []
            if u2 not in matches[u1]:
                matches[u1].append(u2)
            if u1 not in matches[u2]:
                matches[u2].append(u1)
        cur.close()
        conn.close()
    except Exception as e:
        print(f"Error loading matches: {e}")
    return matches

def save_user(user_data):
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO users (email, password, name, age, city, bio, interests, photo, latitude, longitude, show_location)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (
            user_data['email'], user_data['password'], user_data['name'],
            user_data.get('age'), user_data.get('city'), user_data.get('bio'),
            user_data.get('interests', []), user_data.get('photo'),
            user_data.get('latitude'), user_data.get('longitude'),
            user_data.get('show_location', True)
        ))
        user_id = cur.fetchone()['id']
        conn.commit()
        cur.close()
        conn.close()
        return user_id
    except Exception as e:
        print(f"Error saving user: {e}")
        return None

def update_user(user_id, user_data):
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("""
            UPDATE users SET name=%s, age=%s, city=%s, bio=%s, interests=%s, 
            photo=%s, latitude=%s, longitude=%s, show_location=%s
            WHERE id=%s
        """, (
            user_data.get('name'), user_data.get('age'), user_data.get('city'),
            user_data.get('bio'), user_data.get('interests', []),
            user_data.get('photo'), user_data.get('latitude'),
            user_data.get('longitude'), user_data.get('show_location', True),
            user_id
        ))
        conn.commit()
        cur.close()
        conn.close()
    except Exception as e:
        print(f"Error updating user: {e}")

def save_like(from_user_id, to_user_id, is_like=True):
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO likes (from_user_id, to_user_id, is_like)
            VALUES (%s, %s, %s)
            ON CONFLICT DO NOTHING
        """, (from_user_id, to_user_id, is_like))
        conn.commit()
        cur.close()
        conn.close()
    except Exception as e:
        print(f"Error saving like: {e}")

def save_match(user1_id, user2_id):
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO matches (user1_id, user2_id)
            VALUES (%s, %s)
            ON CONFLICT DO NOTHING
        """, (min(user1_id, user2_id), max(user1_id, user2_id)))
        conn.commit()
        cur.close()
        conn.close()
    except Exception as e:
        print(f"Error saving match: {e}")

if __name__ == "__main__":
    init_db()
