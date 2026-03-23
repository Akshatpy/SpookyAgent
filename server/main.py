import asyncio
import json
import time
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import uvicorn
from pathlib import Path
from dotenv import load_dotenv

# Ensure API keys are loaded before importing modules that read env vars at import time.
dotenv_path = Path(__file__).resolve().parents[1] / ".env"
load_dotenv(dotenv_path=dotenv_path)

from game_state import GameState, PlayerState
from ghost_brain import decide_ghost_action, update_ghost_memory
from voice_pipeline import transcribe_audio, synthesize_ghost_voice

# ── Shared state ──────────────────────────────────────────────
state = GameState()
connections: dict[str, WebSocket] = {}  # player_id → websocket
audio_buffers: dict[str, bytearray] = {}  # player_id -> accumulated mic bytes
player_audio_rate: dict[str, int] = {}  # player_id -> sample rate reported by client
speech_buffers: dict[str, list[str]] = {}  # player_id -> recent transcript fragments
speech_timers: dict[str, float] = {}  # player_id -> time of last transcript fragment
speech_started_at: dict[str, float] = {}  # player_id -> time first fragment arrived
speech_empty_windows: dict[str, int] = {}  # player_id -> consecutive empty STT windows
last_sent_transcript: dict[str, tuple[str, float]] = {}  # player_id -> (text, timestamp)

# Whisper needs enough context; tiny chunks often produce empty text.
DEFAULT_AUDIO_SAMPLE_RATE = 44100
STT_WINDOW_SECONDS = 2
SENTENCE_GAP_SECONDS = 0.8
EMPTY_WINDOWS_TO_FLUSH = 2.5  # require sustained silence before flush
MAX_SENTENCE_WAIT_SECONDS = 5.0

# ── FastAPI app ───────────────────────────────────────────────
app = FastAPI(title="HOLLOW server")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# ── Ghost AI loop ─────────────────────────────────────────────
async def ghost_loop():
    """Every 3 seconds, ask the LLM what the ghost should do."""
    while True:
        await asyncio.sleep(3)
        if state.game_phase != "playing" or not state.players:
            continue

        try:
            action = await decide_ghost_action(state)
            await handle_ghost_action(action)
        except Exception as e:
            print(f"[ghost_loop] error: {e}")


async def handle_ghost_action(action: dict):
    """Execute a ghost action — update state + notify all clients."""
    update_ghost_memory(state, {"time": time.time(), "ghost_action": action})
    state.ghost.current_action = action.get("action", "idle")

    if action["action"] == "move_to":
        # For MVP: just store intent, Godot moves the ghost
        state.ghost.target_player_id = action.get("target")

    elif action["action"] == "haunt":
        pid = action.get("player_id")
        if pid and pid in state.players:
            state.players[pid].haunt_count += 1
            state.players[pid].is_haunted = True
            if state.players[pid].haunt_count >= 3:
                await broadcast({"type": "player_eliminated", "player_id": pid})
                # Check win condition
                if all(p.haunt_count >= 3 for p in state.players.values()):
                    state.game_phase = "ghost_wins"
                    await broadcast({"type": "game_over", "winner": "ghost"})

    elif action["action"] == "mimic_voice":
        pid = action.get("player_id")
        phrase = action.get("phrase", "I'm scared...")

        # Synthesize ghost voice (in player's voice if cloned, else default)
        voice_id = state.players[pid].eleven_voice_id if pid in state.players else None
        audio_bytes = await synthesize_ghost_voice(phrase, voice_id)

        # Send audio to all players
        await broadcast({
            "type": "ghost_voice",
            "phrase": phrase,
            "near_player": pid,
            "audio_b64": __import__("base64").b64encode(audio_bytes).decode()
        })
        return  # Don't double-broadcast

    elif action["action"] == "trigger_event":
        await broadcast({
            "type": "ghost_event",
            "event": action.get("event", "footsteps"),
            "near_player": action.get("near_player")
        })
        return

    # Broadcast ghost state update to all players
    await broadcast({
        "type": "ghost_update",
        "ghost": {
            "position": state.ghost.position,
            "action": state.ghost.current_action,
            "target": state.ghost.target_player_id
        }
    })


async def broadcast(msg: dict):
    dead = []
    for pid, ws in connections.items():
        try:
            await ws.send_json(msg)
        except Exception:
            dead.append(pid)
    for pid in dead:
        del connections[pid]


async def sentence_flush_loop():
    """Flush per-player transcript fragments into full sentences after a pause."""
    while True:
        await asyncio.sleep(0.3)
        now = time.time()

        for player_id in list(speech_timers.keys()):
            last_fragment_t = speech_timers.get(player_id, 0.0)

            fragments = speech_buffers.get(player_id, [])
            if not fragments:
                continue

            # Merge fragments into one sentence-ish utterance.
            full_text = " ".join(fragments).strip()
            started_t = speech_started_at.get(player_id, last_fragment_t)
            waited = now - started_t
            silence_windows = speech_empty_windows.get(player_id, 0)

            # Flush only after real silence (multiple empty windows),
            # or after a hard max wait to avoid never flushing.
            if silence_windows < EMPTY_WINDOWS_TO_FLUSH and waited < MAX_SENTENCE_WAIT_SECONDS:
                continue
            if now - last_fragment_t < SENTENCE_GAP_SECONDS and waited < MAX_SENTENCE_WAIT_SECONDS:
                continue

            speech_buffers[player_id] = []
            del speech_timers[player_id]
            if player_id in speech_started_at:
                del speech_started_at[player_id]
            speech_empty_windows[player_id] = 0

            if len(full_text) < 2:
                continue

            # Server-side dedupe for repeated STT windows.
            last = last_sent_transcript.get(player_id)
            if last is not None:
                prev_text, prev_time = last
                if prev_text == full_text and (now - prev_time) < 2.5:
                    continue
            last_sent_transcript[player_id] = (full_text, now)

            print(f"[speech] {player_id}: {full_text}")

            transcript_msg = {
                "type": "speech_transcript",
                "player_id": player_id,
                "text": full_text
            }
            # Broadcast once to all clients (including sender) to avoid duplicate UI lines.
            await broadcast(transcript_msg)

            if player_id in state.players:
                state.players[player_id].voice_samples.append(full_text)
                if len(state.players[player_id].voice_samples) > 20:
                    state.players[player_id].voice_samples = state.players[player_id].voice_samples[-20:]

            player_name = state.players[player_id].name if player_id in state.players else player_id
            update_ghost_memory(state, {
                "type": "speech",
                "player": player_name,
                "player_id": player_id,
                "said": full_text,
                "time": now
            })


# ── WebSocket endpoint ────────────────────────────────────────
@app.websocket("/ws/{player_id}")
async def player_ws(websocket: WebSocket, player_id: str):
    await websocket.accept()
    connections[player_id] = websocket
    audio_buffers.setdefault(player_id, bytearray())
    player_audio_rate.setdefault(player_id, DEFAULT_AUDIO_SAMPLE_RATE)

    if player_id not in state.players:
        state.players[player_id] = PlayerState(id=player_id, name=f"Player_{player_id[:4]}")

    # Send current state to new player
    await websocket.send_json({
        "type": "state_sync",
        "state": state.model_dump()
    })
    await broadcast({"type": "player_joined", "player_id": player_id, "name": state.players[player_id].name})

    try:
        while True:
            data = await websocket.receive()
            if data.get("type") == "websocket.disconnect":
                raise WebSocketDisconnect()

            if "text" in data:
                msg = json.loads(data["text"])
                await handle_player_message(player_id, msg)

            elif "bytes" in data:
                # Raw PCM audio from player's mic
                try:
                    await handle_audio(player_id, data["bytes"])
                except Exception as e:
                    print(f"[handle_audio fatal] {player_id}: {e}")

    except (WebSocketDisconnect, RuntimeError):
        if player_id in connections:
            del connections[player_id]
        if player_id in state.players:
            del state.players[player_id]
        if player_id in audio_buffers:
            del audio_buffers[player_id]
        if player_id in player_audio_rate:
            del player_audio_rate[player_id]
        if player_id in speech_buffers:
            del speech_buffers[player_id]
        if player_id in speech_timers:
            del speech_timers[player_id]
        if player_id in speech_started_at:
            del speech_started_at[player_id]
        if player_id in speech_empty_windows:
            del speech_empty_windows[player_id]
        if player_id in last_sent_transcript:
            del last_sent_transcript[player_id]
        await broadcast({"type": "player_left", "player_id": player_id})


async def handle_player_message(player_id: str, msg: dict):
    msg_type = msg.get("type")

    if msg_type == "start_game":
        state.game_phase = "playing"
        state.started_at = time.time()
        await broadcast({"type": "game_started"})

    elif msg_type == "position_update":
        if player_id in state.players:
            state.players[player_id].position = msg.get("position", {"x": 0, "y": 0})

    elif msg_type == "fuse_found":
        state.fuses_found += 1
        update_ghost_memory(state, {"event": "fuse_found", "by": player_id, "total": state.fuses_found})
        if state.fuses_found >= 4:
            state.game_phase = "players_win"
            await broadcast({"type": "game_over", "winner": "players"})
        else:
            await broadcast({"type": "fuse_update", "count": state.fuses_found})

    elif msg_type == "set_name":
        if player_id in state.players:
            state.players[player_id].name = msg.get("name", "Unknown")

    elif msg_type == "audio_config":
        # Client tells us its capture/mix sample rate.
        try:
            sr = int(msg.get("sample_rate", DEFAULT_AUDIO_SAMPLE_RATE))
            if 8000 <= sr <= 192000:
                player_audio_rate[player_id] = sr
        except Exception:
            pass


async def handle_audio(player_id: str, audio_bytes: bytes):
    """Receive audio chunk from player, transcribe it, add to ghost memory."""
    if len(audio_bytes) < 1000:
        return  # too short, skip

    buf = audio_buffers.setdefault(player_id, bytearray())
    buf.extend(audio_bytes)

    sr = int(player_audio_rate.get(player_id, DEFAULT_AUDIO_SAMPLE_RATE))
    min_bytes = sr * STT_WINDOW_SECONDS * 4
    if len(buf) < min_bytes:
        return

    # Consume buffered bytes for one transcription window.
    chunk = bytes(buf)
    audio_buffers[player_id] = bytearray()
    try:
        text = await transcribe_audio(chunk, sample_rate=sr)
        if not text or len(text.strip()) < 2:
            speech_empty_windows[player_id] = speech_empty_windows.get(player_id, 0) + 1
            return

        fragment = text.strip()
        fragments = speech_buffers.setdefault(player_id, [])
        if not fragments:
            speech_started_at[player_id] = time.time()
        fragments.append(fragment)
        speech_timers[player_id] = time.time()
        speech_empty_windows[player_id] = 0

    except Exception as e:
        print(f"[audio error] {e}")


# ── Startup ───────────────────────────────────────────────────
@app.on_event("startup")
async def startup():
    asyncio.create_task(ghost_loop())
    asyncio.create_task(sentence_flush_loop())
    print("HOLLOW server running. Ghost is awake.")


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)

