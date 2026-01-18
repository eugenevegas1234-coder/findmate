from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
import json

app = FastAPI(title="Dating App API")
security = HTTPBearer()

# Базы данных (в памяти)
users_db = {}
likes_db = {}  # {user_id: [liked_user_ids]}
matches_db = {}  # {user_id: [matched_user_ids]}
tokens_db = {}

# Модели
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

class LikeRequest(BaseModel):
    target_user_id: int

# Получить текущего пользователя
def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials
    if token not in tokens_db:
        raise HTTPException(status_code=401, detail="Invalid token")
    return tokens_db[token]

# Регистрация
@app.post("/register")
def register(user: UserRegister):
    if user.email in [u["email"] for u in users_db.values()]:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    user_id = len(users_db) + 1
    users_db[user_id] = {
        "id": user_id,
        "email": user.email,
        "password": user.password,
        "name": user.name,
        "age": user.age,
        "city": user.city,
        "bio": user.bio,
        "interests": user.interests,
        "created_at": datetime.now().isoformat()
    }
    
    # Инициализируем лайки и матчи
    likes_db[user_id] = []
    matches_db[user_id] = []
    
    token = f"token_{user_id}_{datetime.now().timestamp()}"
    tokens_db[token] = users_db[user_id]
    
    return {"token": token, "user": users_db[user_id]}

# Вход
@app.post("/login")
def login(user: UserLogin):
    for u in users_db.values():
        if u["email"] == user.email and u["password"] == user.password:
            token = f"token_{u['id']}_{datetime.now().timestamp()}"
            tokens_db[token] = u
            return {"token": token, "user": u}
    raise HTTPException(status_code=401, detail="Invalid email or password")

# Профиль
@app.get("/profile")
def get_profile(current_user: dict = Depends(get_current_user)):
    return current_user

# Обновить профиль
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
    
    tokens_db[list(tokens_db.keys())[list(tokens_db.values()).index(current_user)]] = users_db[user_id]
    
    return users_db[user_id]

# Получить анкеты для просмотра
@app.get("/profiles")
def get_profiles(current_user: dict = Depends(get_current_user)):
    current_id = current_user["id"]
    my_interests = set(current_user.get("interests", []))
    my_likes = likes_db.get(current_id, [])
    my_matches = matches_db.get(current_id, [])
    
    profiles = []
    for user in users_db.values():
        # Не показываем себя, уже лайкнутых и матчи
        if user["id"] != current_id and user["id"] not in my_likes:
            user_interests = set(user.get("interests", []))
            common = my_interests & user_interests
            
            profiles.append({
                "id": user["id"],
                "name": user["name"],
                "age": user.get("age"),
                "city": user.get("city"),
                "bio": user.get("bio"),
                "interests": list(user_interests),
                "common_interests": list(common),
                "match_score": len(common)
            })
    
    # Сортируем по количеству общих интересов
    profiles.sort(key=lambda x: x["match_score"], reverse=True)
    return profiles

# Лайкнуть пользователя
@app.post("/like/{user_id}")
def like_user(user_id: int, current_user: dict = Depends(get_current_user)):
    current_id = current_user["id"]
    
    if user_id not in users_db:
        raise HTTPException(status_code=404, detail="User not found")
    
    if user_id == current_id:
        raise HTTPException(status_code=400, detail="Cannot like yourself")
    
    # Добавляем лайк
    if current_id not in likes_db:
        likes_db[current_id] = []
    
    if user_id not in likes_db[current_id]:
        likes_db[current_id].append(user_id)
    
    # Проверяем взаимный лайк
    is_match = False
    if user_id in likes_db and current_id in likes_db[user_id]:
        # ЭТО МАТЧ!
        is_match = True
        
        # Добавляем в матчи обоим
        if current_id not in matches_db:
            matches_db[current_id] = []
        if user_id not in matches_db:
            matches_db[user_id] = []
        
        if user_id not in matches_db[current_id]:
            matches_db[current_id].append(user_id)
        if current_id not in matches_db[user_id]:
            matches_db[user_id].append(current_id)
    
    return {
        "status": "liked",
        "is_match": is_match,
        "matched_user": users_db[user_id] if is_match else None
    }

# Пропустить пользователя
@app.post("/skip/{user_id}")
def skip_user(user_id: int, current_user: dict = Depends(get_current_user)):
    return {"status": "skipped"}

# Получить список матчей
@app.get("/matches")
def get_matches(current_user: dict = Depends(get_current_user)):
    current_id = current_user["id"]
    my_matches = matches_db.get(current_id, [])
    
    matches = []
    for match_id in my_matches:
        if match_id in users_db:
            user = users_db[match_id]
            matches.append({
                "id": user["id"],
                "name": user["name"],
                "age": user.get("age"),
                "city": user.get("city"),
                "bio": user.get("bio"),
                "interests": user.get("interests", [])
            })
    
    return matches

# Проверить статус
@app.get("/")
def root():
    return {"status": "Dating API is running", "users": len(users_db)}
