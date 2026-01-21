from fastapi import FastAPI, Depends, HTTPException, WebSocket, WebSocketDisconnect, UploadFile, File, Query
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
import json
import os
import uuid
import aiofiles
import math

app = FastAPI(title="Dating App API")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Статические файлы
os.makedirs("uploads/photos", exist_ok=True)
os.makedirs("uploads/chat", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

security = HTTPBearer()

# Базы данных (в памяти)
users_db = {}
likes_db = {}
matches_db = {}
tokens_db = {}
messages_db = {}

# WebSocket подключения и статусы
active_connections = {}
user_status = {}

# ==================== Функции геолокации ====================

def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Расчёт расстояния между двумя точками в км (формула Haversine)"""
    R = 6371  # Радиус Земли в км
    
    lat1_rad = math.radians(lat1)
    lat2_rad = math.radians(lat2)
    delta_lat = math.radians(lat2 - lat1)
    delta_lon = math.radians(lon2 - lon1)
    
    a = math.sin(delta_lat/2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(delta_lon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    
    return R * c

# ==================== Модели ====================

class UserRegister(BaseModel):
    email: str
    password: str
    name: str
    age: Optional[int] = None
    city: Optional[str] = None
    bio: Optional[str] = None
    interests: list[str] = []

class UserLogin(BaseModel):
    email: str
    password: str

class UserUpdate(BaseModel):
    name: Optional[str] = None
    age: Optional[int] = None
    city: Optional[str] = None
    bio: Optional[str] = None
    interests: Optional[list[str]] = None

class LocationUpdate(BaseModel):
    latitude: float
    longitude: float
    show_location: Optional[bool] = True

class MessageSend(BaseModel):
    text: str
    image_url: Optional[str] = None

class DeleteMessage(BaseModel):
    message_id: int

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

async def send_ws_message(user_id: int, message: dict):
    if user_id in active_connections:
        try:
            await active_connections[user_id].send_json(message)
        except:
            pass

# ==================== Геолокация ====================

@app.put("/location")
def update_location(location: LocationUpdate, current_user: dict = Depends(get_current_user)):
    """Обновление геолокации пользователя"""
    user_id = current_user["id"]
    
    users_db[user_id]["latitude"] = location.latitude
    users_db[user_id]["longitude"] = location.longitude
    users_db[user_id]["show_location"] = location.show_location
    users_db[user_id]["location_updated"] = datetime.now().isoformat()
    
    # Обновляем в токенах
    for token, user in tokens_db.items():
        if user["id"] == user_id:
            tokens_db[token]["latitude"] = location.latitude
            tokens_db[token]["longitude"] = location.longitude
            tokens_db[token]["show_location"] = location.show_location
    
    return {"status": "location_updated"}

@app.get("/location/settings")
def get_location_settings(current_user: dict = Depends(get_current_user)):
    """Получение настроек геолокации"""
    user_id = current_user["id"]
    user = users_db.get(user_id, {})
    
    return {
        "latitude": user.get("latitude"),
        "longitude": user.get("longitude"),
        "show_location": user.get("show_location", True),
        "location_updated": user.get("location_updated")
    }

@app.put("/location/privacy")
def update_location_privacy(show_location: bool, current_user: dict = Depends(get_current_user)):
    """Настройка приватности геолокации"""
    user_id = current_user["id"]
    users_db[user_id]["show_location"] = show_location
    
    for token, user in tokens_db.items():
        if user["id"] == user_id:
            tokens_db[token]["show_location"] = show_location
    
    return {"show_location": show_location}

# ==================== Загрузка файлов ====================

@app.post("/upload/photo")
async def upload_profile_photo(
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user)
):
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    ext = file.filename.split(".")[-1] if "." in file.filename else "jpg"
    filename = f"{current_user['id']}_{uuid.uuid4().hex[:8]}.{ext}"
    filepath = f"uploads/photos/{filename}"

    async with aiofiles.open(filepath, 'wb') as f:
        content = await file.read()
        await f.write(content)

    photo_url = f"/uploads/photos/{filename}"
    users_db[current_user['id']]["photo"] = photo_url

    for token, user in tokens_db.items():
        if user["id"] == current_user["id"]:
            tokens_db[token]["photo"] = photo_url

    return {"photo_url": photo_url}

@app.post("/upload/chat/{user_id}")
async def upload_chat_photo(
    user_id: int,
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user)
):
    current_id = current_user["id"]

    if user_id not in matches_db.get(current_id, []):
        raise HTTPException(status_code=403, detail="You can only send photos to matches")

    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    ext = file.filename.split(".")[-1] if "." in file.filename else "jpg"
    filename = f"{current_id}_{user_id}_{uuid.uuid4().hex[:8]}.{ext}"
    filepath = f"uploads/chat/{filename}"

    async with aiofiles.open(filepath, 'wb') as f:
        content = await file.read()
        await f.write(content)

    image_url = f"/uploads/chat/{filename}"
    return {"image_url": image_url}

# ==================== WebSocket ====================

@app.websocket("/ws/{token}")
async def websocket_endpoint(websocket: WebSocket, token: str):
    user_id = get_user_id_from_token(token)
    if not user_id:
        await websocket.close(code=4001)
        return

    await websocket.accept()
    active_connections[user_id] = websocket
    user_status[user_id] = {"online": True, "last_seen": datetime.now().isoformat()}

    for match_id in matches_db.get(user_id, []):
        await send_ws_message(match_id, {"type": "user_status", "user_id": user_id, "online": True})

    try:
        while True:
            data = await websocket.receive_json()

            if data["type"] == "message":
                receiver_id = data["receiver_id"]
                text = data.get("text", "")
                image_url = data.get("image_url")

                chat_id = get_chat_id(user_id, receiver_id)

                if chat_id not in messages_db:
                    messages_db[chat_id] = []

                new_message = {
                    "id": len(messages_db[chat_id]) + 1,
                    "sender_id": user_id,
                    "receiver_id": receiver_id,
                    "text": text,
                    "image_url": image_url,
                    "timestamp": datetime.now().isoformat(),
                    "is_read": False,
                    "deleted": False
                }
                messages_db[chat_id].append(new_message)

                await send_ws_message(receiver_id, {"type": "new_message", "message": new_message})
                await send_ws_message(user_id, {"type": "message_sent", "message": new_message})

            elif data["type"] == "typing":
                await send_ws_message(data["receiver_id"], {"type": "typing", "user_id": user_id, "is_typing": data["is_typing"]})

            elif data["type"] == "read":
                sender_id = data["sender_id"]
                chat_id = get_chat_id(user_id, sender_id)
                for msg in messages_db.get(chat_id, []):
                    if msg["receiver_id"] == user_id:
                        msg["is_read"] = True
                await send_ws_message(sender_id, {"type": "messages_read", "reader_id": user_id})

            elif data["type"] == "delete_message":
                message_id = data["message_id"]
                partner_id = data["partner_id"]
                chat_id = get_chat_id(user_id, partner_id)

                for msg in messages_db.get(chat_id, []):
                    if msg["id"] == message_id and msg["sender_id"] == user_id:
                        msg["deleted"] = True
                        msg["text"] = ""
                        msg["image_url"] = None
                        await send_ws_message(partner_id, {"type": "message_deleted", "message_id": message_id, "chat_id": chat_id})
                        await send_ws_message(user_id, {"type": "message_deleted", "message_id": message_id, "chat_id": chat_id})
                        break

    except WebSocketDisconnect:
        pass
    finally:
        if user_id in active_connections:
            del active_connections[user_id]
        user_status[user_id] = {"online": False, "last_seen": datetime.now().isoformat()}
        for match_id in matches_db.get(user_id, []):
            await send_ws_message(match_id, {"type": "user_status", "user_id": user_id, "online": False, "last_seen": user_status[user_id]["last_seen"]})

# ==================== Статус ====================

@app.get("/user/{user_id}/status")
def get_user_status_endpoint(user_id: int, current_user: dict = Depends(get_current_user)):
    return user_status.get(user_id, {"online": False, "last_seen": None})

# ==================== Регистрация/Вход ====================

@app.post("/register")
def register(user: UserRegister):
    if user.email in [u["email"] for u in users_db.values()]:
        raise HTTPException(status_code=400, detail="Email already registered")

    user_id = len(users_db) + 1
    users_db[user_id] = {
        "id": user_id, "email": user.email, "password": user.password,
        "name": user.name, "age": user.age, "city": user.city,
        "bio": user.bio, "interests": user.interests, "photo": None,
        "latitude": None, "longitude": None, "show_location": True,
        "created_at": datetime.now().isoformat()
    }
    likes_db[user_id] = []
    matches_db[user_id] = []

    token = f"token_{user_id}_{datetime.now().timestamp()}"
    tokens_db[token] = users_db[user_id]
    return {"token": token, "user": users_db[user_id]}

@app.post("/login")
def login(user: UserLogin):
    for u in users_db.values():
        if u["email"] == user.email and u["password"] == user.password:
            token = f"token_{u['id']}_{datetime.now().timestamp()}"
            tokens_db[token] = u
            return {"token": token, "user": u}
    raise HTTPException(status_code=401, detail="Invalid email or password")

# ==================== Профиль ====================

@app.get("/profile")
def get_profile(current_user: dict = Depends(get_current_user)):
    return current_user

@app.put("/profile")
def update_profile(user_update: UserUpdate, current_user: dict = Depends(get_current_user)):
    user_id = current_user["id"]
    if user_update.name is not None:
        users_db[user_id]["name"] = user_update.name
    if user_update.age is not None:
        users_db[user_id]["age"] = user_update.age
    if user_update.city is not None:
        users_db[user_id]["city"] = user_update.city
    if user_update.bio is not None:
        users_db[user_id]["bio"] = user_update.bio
    if user_update.interests is not None:
        users_db[user_id]["interests"] = user_update.interests

    for token, user in tokens_db.items():
        if user["id"] == user_id:
            tokens_db[token] = users_db[user_id]

    return users_db[user_id]

# ==================== Анкеты ====================

@app.get("/profiles")
def get_profiles(
    current_user: dict = Depends(get_current_user),
    max_distance: Optional[float] = Query(None, description="Максимальное расстояние в км")
):
    current_id = current_user["id"]
    my_interests = set(current_user.get("interests", []))
    my_likes = likes_db.get(current_id, [])
    
    # Мои координаты
    my_lat = current_user.get("latitude")
    my_lon = current_user.get("longitude")

    profiles = []
    for user in users_db.values():
        if user["id"] != current_id and user["id"] not in my_likes:
            user_interests = set(user.get("interests", []))
            common = my_interests & user_interests
            
            # Расчёт расстояния
            distance = None
            user_lat = user.get("latitude")
            user_lon = user.get("longitude")
            show_location = user.get("show_location", True)
            
            if my_lat and my_lon and user_lat and user_lon and show_location:
                distance = calculate_distance(my_lat, my_lon, user_lat, user_lon)
                
                # Фильтр по расстоянию
                if max_distance and distance > max_distance:
                    continue
            
            profiles.append({
                "id": user["id"], "name": user["name"], "age": user.get("age"),
                "city": user.get("city"), "bio": user.get("bio"),
                "interests": list(user_interests), "common_interests": list(common),
                "match_score": len(common), "photo": user.get("photo"),
                "distance": round(distance, 1) if distance else None,
                "show_location": show_location
            })
    
    profiles.sort(key=lambda x: x["match_score"], reverse=True)
    return profiles

# ==================== Лайки ====================

@app.post("/like/{user_id}")
async def like_user(user_id: int, current_user: dict = Depends(get_current_user)):
    current_id = current_user["id"]
    if user_id not in users_db:
        raise HTTPException(status_code=404, detail="User not found")
    if user_id == current_id:
        raise HTTPException(status_code=400, detail="Cannot like yourself")

    if current_id not in likes_db:
        likes_db[current_id] = []
    if user_id not in likes_db[current_id]:
        likes_db[current_id].append(user_id)

    is_match = False
    if user_id in likes_db and current_id in likes_db[user_id]:
        is_match = True
        if current_id not in matches_db:
            matches_db[current_id] = []
        if user_id not in matches_db:
            matches_db[user_id] = []
        if user_id not in matches_db[current_id]:
            matches_db[current_id].append(user_id)
        if current_id not in matches_db[user_id]:
            matches_db[user_id].append(current_id)
        await send_ws_message(user_id, {"type": "new_match", "user": {"id": current_id, "name": current_user["name"], "photo": current_user.get("photo")}})

    return {"status": "liked", "is_match": is_match, "matched_user": users_db[user_id] if is_match else None}

@app.post("/skip/{user_id}")
def skip_user(user_id: int, current_user: dict = Depends(get_current_user)):
    return {"status": "skipped"}

# ==================== Матчи ====================

@app.get("/matches")
def get_matches(current_user: dict = Depends(get_current_user)):
    current_id = current_user["id"]
    my_matches = matches_db.get(current_id, [])
    
    my_lat = current_user.get("latitude")
    my_lon = current_user.get("longitude")

    matches = []
    for match_id in my_matches:
        if match_id in users_db:
            user = users_db[match_id]
            chat_id = get_chat_id(current_id, match_id)
            chat_messages = [m for m in messages_db.get(chat_id, []) if not m.get("deleted")]
            last_message = chat_messages[-1] if chat_messages else None
            status = user_status.get(match_id, {"online": False, "last_seen": None})
            
            # Расстояние
            distance = None
            user_lat = user.get("latitude")
            user_lon = user.get("longitude")
            if my_lat and my_lon and user_lat and user_lon and user.get("show_location", True):
                distance = round(calculate_distance(my_lat, my_lon, user_lat, user_lon), 1)
            
            matches.append({
                "id": user["id"], "name": user["name"], "age": user.get("age"),
                "city": user.get("city"), "bio": user.get("bio"),
                "interests": user.get("interests", []), "last_message": last_message,
                "online": status["online"], "last_seen": status.get("last_seen"),
                "photo": user.get("photo"), "distance": distance
            })
    return matches

# ==================== Чат (HTTP) ====================

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
        "timestamp": datetime.now().isoformat(),
        "is_read": False, "deleted": False
    }
    messages_db[chat_id].append(new_message)
    return new_message

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

@app.delete("/chat/{user_id}/message/{message_id}")
def delete_message(user_id: int, message_id: int, current_user: dict = Depends(get_current_user)):
    current_id = current_user["id"]
    chat_id = get_chat_id(current_id, user_id)

    for msg in messages_db.get(chat_id, []):
        if msg["id"] == message_id and msg["sender_id"] == current_id:
            msg["deleted"] = True
            msg["text"] = ""
            msg["image_url"] = None
            return {"status": "deleted"}

    raise HTTPException(status_code=404, detail="Message not found")

@app.get("/chats")
def get_chats(current_user: dict = Depends(get_current_user)):
    current_id = current_user["id"]
    my_matches = matches_db.get(current_id, [])

    chats = []
    for match_id in my_matches:
        if match_id in users_db:
            user = users_db[match_id]
            chat_id = get_chat_id(current_id, match_id)
            chat_messages = [m for m in messages_db.get(chat_id, []) if not m.get("deleted")]
            unread = sum(1 for m in chat_messages if m["receiver_id"] == current_id and not m["is_read"])
            last_message = chat_messages[-1] if chat_messages else None
            chats.append({
                "user_id": user["id"], "user_name": user["name"],
                "last_message": last_message, "unread_count": unread,
                "photo": user.get("photo")
            })

    chats.sort(key=lambda x: x["last_message"]["timestamp"] if x["last_message"] else "", reverse=True)
    return chats

@app.get("/")
def root():
    return {"status": "Dating API is running", "users": len(users_db)}
