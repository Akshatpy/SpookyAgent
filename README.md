# 👻 HOLLOW

**HOLLOW** is a multiplayer horror game where players explore a dark setting while an AI-powered ghost listens to their voices and reacts in realtime.

The ghost uses speech recognition and a language model to generate creepy responses and actions.

---

## 🎮 Features

* 🧍 1–4 player multiplayer (WebSocket-based)
* 👻 AI ghost that chases and haunts players
* 🎤 Real-time microphone input from players
* 🧠 Speech-to-text + LLM-powered ghost response

---

## ⚙️ Tech Stack

### 🎮 Game Client

* **Engine:** Godot 4
* **Language:** GDScript
* **Networking:** WebSockets
* **Audio:** AudioEffectCapture (mic input)

### 🧠 Backend Server

* **Framework:** FastAPI (Python)
* **Communication:** WebSockets
* **Speech-to-Text:** Faster-Whisper (local)
* **AI Model:** OpenAI (LLM for ghost behavior)
* **Audio Processing:** NumPy, SciPy

---

## 👨‍💻 Author

Built by **Akshat** 
