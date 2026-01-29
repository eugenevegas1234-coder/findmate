from fastapi import FastAPI, Depends, HTTPException, WebSocket, WebSocketDisconnect, UploadFile, File, Query
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
import os
import uuid
import aiofiles
import math
from app.database import load_users, load_likes, load_matches, save_user, save_like, save_match

app = FastAPI(title="Dating App API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

os.makedirs("uploads/photos", exist_ok=True)
os.makedirs("uploads/chat", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

security = HTTPBearer()

users_db = {}
likes_db = {}
matches_db = {}
tokens_db = {}
messages_db = {}
active_connections = {}
user_status = {}
blocks_db = {}  # {user_id: [blocked_user_ids]}
reports_db = []  # [{reporter_id, reported_id, reason, description, timestamp}]
settings_db = {}  # {user_id: {settings}}


@app.on_event("startup")
def startup_load_data():
    global users_db, likes_db, matches_db
    print("Loading data from database...")

    users_db = load_users()

    for user_id in users_db:
        if user_id not in likes_db:
            likes_db[user_id] = []
        if user_id not in matches_db:
            matches_db[user_id] = []

    loaded_likes = load_likes()
    for from_id, to_ids in loaded_likes.items():
        likes_db[from_id] = to_ids

    loaded_matches = load_matches()
    for user_id, match_ids in loaded_matches.items():
        matches_db[user_id] = match_ids

    print(f"Loaded {len(users_db)} users")

    for uid, u in users_db.items():
        if u.get('latitude') and u.get('longitude'):
            print(f"  User {uid} ({u['name']}): {u['latitude']}, {u['longitude']}")


def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371
    lat1_rad = math.radians(lat1)
    lat2_rad = math.radians(lat2)
    delta_lat = math.radians(lat2 - lat1)
    delta_lon = math.radians(lon2 - lon1)
    a = math.sin(delta_lat/2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(delta_lon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c


class UserRegister(BaseModel):
    email: str
    password: str
    name: str
    age: Optional[int] = None
    city: Optional[str] = None
    bio: Optional[str] = None
    interests: List[str] = []


class UserLogin(BaseModel):
    email: str
    password: str


class UserUpdate(BaseModel):
    name: Optional[str] = None
    age: Optional[int] = None
    city: Optional[str] = None
    bio: Optional[str] = None
    interests: Optional[List[str]] = None


class LocationUpdate(BaseModel):
    latitude: float
    longitude: float
    show_location: Optional[bool] = True


class MessageSend(BaseModel):
    text: str
    image_url: Optional[str] = None


class SettingsUpdate(BaseModel):
    push_notifications: Optional[bool] = None
    message_notifications: Optional[bool] = None
    match_notifications: Optional[bool] = None
    show_online_status: Optional[bool] = None
    show_distance: Optional[bool] = None


class ReportCreate(BaseModel):
    user_id: int
    reason: str
    description: Optional[str] = None


def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials
    if token not in tokens_db:
        raise HTTPException(status_code=401, detail="Invalid token")
    return tokens_db[token]


def get_user_id_from_token(token: str) -> Optional[int]:
    if token in tokens_db:
        return tokens_db[token]["id"]
    return None


def get_chat_id(user1_id: int, user2_id: int) -> str:
    return f"chat_{min(user1_id, user2_id)}_{max(user1_id, user2_id)}"


def is_blocked(user_id: int, target_id: int) -> bool:
    return target_id in blocks_db.get(user_id, [])


async def send_ws_message(user_id: int, message: dict):
    if user_id in active_connections:
        try:
            await active_connections[user_id].send_json(message)
        except:
            pass


# ==================== НАСТРОЙКИ ====================

@app.get("/settings")
def get_settings(current_user: dict = Depends(get_current_user)):
    user_id = current_user["id"]
    default_settings = {
        "push_notifications": True,
        "message_notifications": True,
        "match_notifications": True,
        "show_online_status": True,
        "show_distance": True,
    }
    return settings_db.get(user_id, default_settings)


@app.put("/settings")
def update_settings(settings: SettingsUpdate, current_user: dict = Depends(get_current_user)):
    user_id = current_user["id"]
    if user_id not in settings_db:
        settings_db[user_id] = {
            "push_notifications": True,
            "message_notifications": True,
            "match_notifications": True,
            "show_online_status": True,
            "show_distance": True,
        }
    
    if settings.push_notifications is not None:
        settings_db[user_id]["push_notifications"] = settings.push_notifications
    if settings.message_notifications is not None:
        settings_db[user_id]["message_notifications"] = settings.message_notifications
    if settings.match_notifications is not None:
        settings_db[user_id]["match_notifications"] = settings.match_notifications
    if settings.show_online_status is not None:
        settings_db[user_id]["show_online_status"] = settings.show_online_status
    if settings.show_distance is not None:
        settings_db[user_id]["show_distance"] = settings.show_distance
    
    return {"status": "ok"}


# ==================== БЛОКИРОВКА ====================

@app.post("/block/{user_id}")
def block_user(user_id: int, current_user: dict = Depends(get_current_user)):
    current_id = current_user["id"]
    
    if user_id == current_id:
        raise HTTPException(status_code=400, detail="Cannot block yourself")
    
    if user_id not in users_db:
        raise HTTPException(status_code=404, detail="User not found")
    
    if current_id not in blocks_db:
        blocks_db[current_id] = []
    
    if user_id in blocks_db[current_id]:
        raise HTTPException(status_code=400, detail="User already blocked")
    
    blocks_db[current_id].append(user_id)
    return {"status": "ok", "message": "User blocked"}


@app.delete("/block/{user_id}")
def unblock_user(user_id: int, current_user: dict = Depends(get_current_user)):
    current_id = current_user["id"]
    
    if current_id not in blocks_db or user_id not in blocks_db[current_id]:
        raise HTTPException(status_code=404, detail="Block not found")
    
    blocks_db[current_id].remove(user_id)
    return {"status": "ok", "message": "User unblocked"}


@app.get("/blocked")
def get_blocked_users(current_user: dict = Depends(get_current_user)):
    current_id = current_user["id"]
    blocked_ids = blocks_db.get(current_id, [])
    
    blocked_users = []
    for uid in blocked_ids:
        if uid in users_db:
            user = users_db[uid]
            blocked_users.append({
                "id": user["id"],
                "name": user["name"],
                "photo": user.get("photo")
            })
    
    return blocked_users


# ==================== ЖАЛОБЫ ====================

@app.post("/report")
def report_user(report: ReportCreate, current_user: dict = Depends(get_current_user)):
    current_id = current_user["id"]
    
    if report.user_id == current_id:
        raise HTTPException(status_code=400, detail="Cannot report yourself")
    
    if report.user_id not in users_db:
        raise HTTPException(status_code=404, detail="User not found")
    
    reports_db.append({
        "reporter_id": current_id,
        "reported_id": report.user_id,
        "reason": report.reason,
        "description": report.description,
        "timestamp": datetime.now().isoformat()
    })
    
    return {"status": "ok", "message": "Report submitted"}


# ==================== УДАЛЕНИЕ АККАУНТА ====================

@app.delete("/account")
def delete_account(current_user: dict = Depends(get_current_user)):
    current_id = current_user["id"]
    
    # Деактивируем пользователя
    if current_id in users_db:
        users_db[current_id]["email"] = f"deleted_{current_id}@deleted.com"
        users_db[current_id]["name"] = "Deleted User"
        users_db[current_id]["is_active"] = False
    
    # Удаляем из блокировок
    if current_id in blocks_db:
        del blocks_db[current_id]
    
    # Удаляем токены
    tokens_to_remove = [t for t, u in tokens_db.items() if u["id"] == current_id]
    for t in tokens_to_remove:
        del tokens_db[t]
    
    return {"status": "ok", "message": "Account deleted"}


# ==================== ГЕОЛОКАЦИЯ ====================

@app.put("/location")
def update_location(location: LocationUpdate, current_user: dict = Depends(get_current_user)):
    user_id = current_user["id"]
    users_db[user_id]["latitude"] = location.latitude
    users_db[user_id]["longitude"] = location.longitude
    users_db[user_id]["show_location"] = location.show_location
    for token, user in tokens_db.items():
        if user["id"] == user_id:
            tokens_db[token]["latitude"] = location.latitude
            tokens_db[token]["longitude"] = location.longitude
            tokens_db[token]["show_location"] = location.show_location
    return {"status": "location_updated"}


@app.get("/location/settings")
def get_location_settings(current_user: dict = Depends(get_current_user)):
    user = users_db.get(current_user["id"], {})
    return {
        "latitude": user.get("latitude"),
        "longitude": user.get("longitude"),
        "show_location": user.get("show_location", True)
    }


@app.post("/upload/photo")
async def upload_profile_photo(file: UploadFile = File(...), current_user: dict = Depends(get_current_user)):
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")
    ext = file.filename.split(".")[-1] if "." in file.filename else "jpg"
    filename = f"{current_user['id']}_{uuid.uuid4().hex[:8]}.{ext}"
    filepath = f"uploads/photos/{filename}"
    async with aiofiles.open(filepath, 'wb') as f:
        await f.write(await file.read())
    photo_url = f"/uploads/photos/{filename}"
    users_db[current_user['id']]["photo"] = photo_url
    for token, user in tokens_db.items():
        if user["id"] == current_user["id"]:
            tokens_db[token]["photo"] = photo_url
    return {"photo_url": photo_url}


@app.websocket("/ws/{token}")
async def websocket_endpoint(websocket: WebSocket, token: str):
    user_id = get_user_id_from_token(token)
    if not user_id:
        await websocket.close(code=4001)
        return
    await websocket.accept()
    active_connections[user_id] = websocket
    user_status[user_id] = {"online": True, "last_seen": datetime.now().isoformat()}
    try:
        while True:
            data = await websocket.receive_json()
            if data["type"] == "message":
                receiver_id = data["receiver_id"]
                chat_id = get_chat_id(user_id, receiver_id)
                if chat_id not in messages_db:
                    messages_db[chat_id] = []
                new_message = {
                    "id": len(messages_db[chat_id]) + 1,
                    "sender_id": user_id, "receiver_id": receiver_id,
                    "text": data.get("text", ""), "image_url": data.get("image_url"),
                    "timestamp": datetime.now().isoformat(), "is_read": False, "deleted": False
                }
                messages_db[chat_id].append(new_message)
                await send_ws_message(receiver_id, {"type": "new_message", "message": new_message})
                await send_ws_message(user_id, {"type": "message_sent", "message": new_message})
            elif data["type"] == "typing":
                await send_ws_message(data["receiver_id"], {"type": "typing", "user_id": user_id, "is_typing": data["is_typing"]})
            elif data["type"] == "read":
                chat_id = get_chat_id(user_id, data["sender_id"])
                for msg in messages_db.get(chat_id, []):
                    if msg["receiver_id"] == user_id:
                        msg["is_read"] = True
                await send_ws_message(data["sender_id"], {"type": "messages_read", "reader_id": user_id})
    except WebSocketDisconnect:
        pass
    finally:
        if user_id in active_connections:
            del active_connections[user_id]
        user_status[user_id] = {"online": False, "last_seen": datetime.now().isoformat()}


@app.get("/user/{user_id}/status")
def get_user_status_endpoint(user_id: int, current_user: dict = Depends(get_current_user)):
    return user_status.get(user_id, {"online": False, "last_seen": None})


@app.post("/register")
def register(user: UserRegister):
    if user.email in [u["email"] for u in users_db.values()]:
        raise HTTPException(status_code=400, detail="Email already registered")

    user_data = {
        "email": user.email, "password": user.password, "name": user.name,
        "age": user.age, "city": user.city, "bio": user.bio,
        "interests": user.interests, "photo": None,
        "latitude": None, "longitude": None, "show_location": True
    }
    user_id = save_user(user_data)
    user_data["id"] = user_id

    users_db[user_id] = user_data
    likes_db[user_id] = []
    matches_db[user_id] = []

    token = f"token_{user_id}_{datetime.now().timestamp()}"
    tokens_db[token] = user_data
    return {"token": token, "user": user_data}


@app.post("/login")
def login(user: UserLogin):
    for u in users_db.values():
        if u["email"] == user.email and u["password"] == user.password:
            token = f"token_{u['id']}_{datetime.now().timestamp()}"
            tokens_db[token] = u
            return {"token": token, "user": u}
    raise HTTPException(status_code=401, detail="Invalid email or password")


@app.get("/profile")
def get_profile(current_user: dict = Depends(get_current_user)):
    return current_user


@app.put("/profile")
def update_profile(user_update: UserUpdate, current_user: dict = Depends(get_current_user)):
    user_id = current_user["id"]
    if user_update.name: users_db[user_id]["name"] = user_update.name
    if user_update.age: users_db[user_id]["age"] = user_update.age
    if user_update.city: users_db[user_id]["city"] = user_update.city
    if user_update.bio: users_db[user_id]["bio"] = user_update.bio
    if user_update.interests: users_db[user_id]["interests"] = user_update.interests
    for token, user in tokens_db.items():
        if user["id"] == user_id:
            tokens_db[token] = users_db[user_id]
    return users_db[user_id]


@app.get("/profiles")
def get_profiles(current_user: dict = Depends(get_current_user), max_distance: Optional[float] = Query(None)):
    current_id = current_user["id"]
    my_interests = set(current_user.get("interests") or [])
    my_likes = likes_db.get(current_id, [])
    my_lat = current_user.get("latitude")
    my_lon = current_user.get("longitude")
    my_blocked = blocks_db.get(current_id, [])

    profiles = []
    for user in users_db.values():
        # Пропускаем себя, уже лайкнутых и заблокированных
        if user["id"] == current_id or user["id"] in my_likes or user["id"] in my_blocked:
            continue
        
        # Пропускаем если нас заблокировал этот пользователь
        if current_id in blocks_db.get(user["id"], []):
            continue

        user_interests = set(user.get("interests") or [])
        common = my_interests & user_interests
        distance = None

        user_lat = user.get("latitude")
        user_lon = user.get("longitude")
        show_loc = user.get("show_location", True)

        if my_lat and my_lon and user_lat and user_lon and show_loc:
            distance = calculate_distance(my_lat, my_lon, user_lat, user_lon)
            if max_distance and distance > max_distance:
                continue

        profiles.append({
            "id": user["id"],
            "name": user["name"],
            "age": user.get("age"),
            "city": user.get("city"),
            "bio": user.get("bio"),
            "interests": list(user_interests),
            "common_interests": list(common),
            "match_score": len(common),
            "photo": user.get("photo"),
            "distance": round(distance, 1) if distance else None,
            "latitude": user_lat if show_loc else None,
            "longitude": user_lon if show_loc else None
        })

    profiles.sort(key=lambda x: x["match_score"], reverse=True)
    return profiles


@app.post("/like/{user_id}")
async def like_user(user_id: int, current_user: dict = Depends(get_current_user)):
    current_id = current_user["id"]
    if user_id not in users_db:
        raise HTTPException(status_code=404, detail="User not found")

    if current_id not in likes_db:
        likes_db[current_id] = []
    if user_id not in likes_db[current_id]:
        likes_db[current_id].append(user_id)
        save_like(current_id, user_id)

    is_match = user_id in likes_db and current_id in likes_db.get(user_id, [])
    if is_match:
        if current_id not in matches_db:
            matches_db[current_id] = []
        if user_id not in matches_db:
            matches_db[user_id] = []
        if user_id not in matches_db[current_id]:
            matches_db[current_id].append(user_id)
            matches_db[user_id].append(current_id)
            save_match(current_id, user_id)
        await send_ws_message(user_id, {"type": "new_match", "user": {"id": current_id, "name": current_user["name"], "photo": current_user.get("photo")}})

    return {"status": "liked", "is_match": is_match, "matched_user": users_db[user_id] if is_match else None}


@app.post("/skip/{user_id}")
def skip_user(user_id: int, current_user: dict = Depends(get_current_user)):
    return {"status": "skipped"}


@app.get("/matches")
def get_matches(current_user: dict = Depends(get_current_user)):
    current_id = current_user["id"]
    my_lat = current_user.get("latitude")
    my_lon = current_user.get("longitude")
    my_blocked = blocks_db.get(current_id, [])

    matches = []
    for match_id in matches_db.get(current_id, []):
        # Пропускаем заблокированных
        if match_id in my_blocked or current_id in blocks_db.get(match_id, []):
            continue
            
        if match_id in users_db:
            user = users_db[match_id]
            chat_id = get_chat_id(current_id, match_id)
            chat_messages = [m for m in messages_db.get(chat_id, []) if not m.get("deleted")]
            status = user_status.get(match_id, {"online": False, "last_seen": None})
            distance = None
            if my_lat and my_lon and user.get("latitude") and user.get("longitude") and user.get("show_location", True):
                distance = round(calculate_distance(my_lat, my_lon, user["latitude"], user["longitude"]), 1)
            matches.append({
                "id": user["id"], "name": user["name"], "age": user.get("age"),
                "city": user.get("city"), "bio": user.get("bio"),
                "interests": user.get("interests", []),
                "last_message": chat_messages[-1] if chat_messages else None,
                "online": status["online"], "last_seen": status.get("last_seen"),
                "photo": user.get("photo"), "distance": distance
            })
    return matches


@app.get("/chat/{user_id}/messages")
def get_messages(user_id: int, current_user: dict = Depends(get_current_user)):
    current_id = current_user["id"]
    if user_id not in matches_db.get(current_id, []):
        raise HTTPException(status_code=403, detail="You can only chat with matches")
    chat_id = get_chat_id(current_id, user_id)
    messages = [m for m in messages_db.get(chat_id, []) if not m.get("deleted")]
    for msg in messages:
        if msg["receiver_id"] == current_id:
            msg["is_read"] = True
    return messages


@app.post("/chat/{user_id}/send")
def send_message(user_id: int, message: MessageSend, current_user: dict = Depends(get_current_user)):
    current_id = current_user["id"]
    if user_id not in matches_db.get(current_id, []):
        raise HTTPException(status_code=403, detail="You can only chat with matches")
    chat_id = get_chat_id(current_id, user_id)
    if chat_id not in messages_db:
        messages_db[chat_id] = []
    new_message = {
        "id": len(messages_db[chat_id]) + 1,
        "sender_id": current_id, "receiver_id": user_id,
        "text": message.text, "image_url": message.image_url,
        "timestamp": datetime.now().isoformat(), "is_read": False, "deleted": False
    }
    messages_db[chat_id].append(new_message)
    return new_message


@app.delete("/chat/{user_id}/message/{message_id}")
def delete_message(user_id: int, message_id: int, current_user: dict = Depends(get_current_user)):
    current_id = current_user["id"]
    chat_id = get_chat_id(current_id, user_id)
    
    for msg in messages_db.get(chat_id, []):
        if msg["id"] == message_id and msg["sender_id"] == current_id:
            msg["deleted"] = True
            return {"status": "ok"}
    
    raise HTTPException(status_code=404, detail="Message not found")


@app.get("/chats")
def get_chats(current_user: dict = Depends(get_current_user)):
    current_id = current_user["id"]
    my_blocked = blocks_db.get(current_id, [])
    
    chats = []
    for match_id in matches_db.get(current_id, []):
        # Пропускаем заблокированных
        if match_id in my_blocked or current_id in blocks_db.get(match_id, []):
            continue
            
        if match_id in users_db:
            user = users_db[match_id]
            chat_id = get_chat_id(current_id, match_id)
            chat_messages = [m for m in messages_db.get(chat_id, []) if not m.get("deleted")]
            unread = sum(1 for m in chat_messages if m["receiver_id"] == current_id and not m["is_read"])
            chats.append({
                "user_id": user["id"], "user_name": user["name"],
                "last_message": chat_messages[-1] if chat_messages else None,
                "unread_count": unread, "photo": user.get("photo")
            })
    chats.sort(key=lambda x: x["last_message"]["timestamp"] if x["last_message"] else "", reverse=True)
    return chats


@app.get("/")
def root():
    return {"status": "Dating API is running", "users": len(users_db)}
