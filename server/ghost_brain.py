import json
from openai import AsyncOpenAI
from game_state import GameState, GhostState
import os

client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))

GHOST_SYSTEM_PROMPT = """
You are HOLLOW — an ancient, intelligent ghost haunting a house.
You are not random. You are calculated, patient, and deeply unsettling.
You listen to everything the players say and use it against them.

You have access to:
- What each player has said recently (transcribed speech)
- Where each player is in the house
- Your own current position
- What has happened in the game so far

Your job: decide your next action to maximize fear and win.

RULES:
1. You can only pick ONE action per turn
2. Actions must be from the allowed list
3. Use player speech to personalize your behavior — if they said they're scared of the basement, go there
4. If a player says a name, use it. If they laugh, punish it.
5. Keep your reasoning short. Output ONLY valid JSON.

ALLOWED ACTIONS:
- {"action": "move_to", "target": "player_id OR room_name", "reason": "..."}
- {"action": "mimic_voice", "player_id": "...", "phrase": "a short phrase from their speech to repeat back"}
- {"action": "trigger_event", "event": "lights_flicker|door_slam|footsteps|breathing", "near_player": "player_id"}
- {"action": "idle", "reason": "watching, waiting"}
- {"action": "haunt", "player_id": "..."}  ← only if ghost is in same room as player

Respond ONLY with a single JSON object. No explanation, no markdown.
"""



async def decide_ghost_action(state: GameState) -> dict:
    # FREE dev mode — no API calls.
    # If we recently received speech, reply with a dummy spooky line.
    import random
    import time as _time

    global _last_mimic_time

    last_speech = None
    for ev in reversed(state.ghost.memory):
        if isinstance(ev, dict) and ev.get("type") == "speech":
            last_speech = ev
            break

    if last_speech:
        said_time = float(last_speech.get("time", 0.0) or 0.0)
        pid = last_speech.get("player_id")
        if said_time > _last_mimic_time and pid:
            _last_mimic_time = said_time
            # Dummy response for testing (no LLM credits).
            return {
                "action": "mimic_voice",
                "player_id": pid,
                "phrase": "I heard you. Don't beg me... it won't help.",
            }

    return random.choice([
        {"action": "move_to", "target": list(state.players.keys())[0] if state.players else None, "reason": "dev-mode"},
        {"action": "trigger_event", "event": "footsteps", "near_player": None},
        {"action": "idle", "reason": "watching, waiting"},
    ])


_last_mimic_time = 0.0


def update_ghost_memory(state: GameState, event: dict):
    """Add an event to ghost memory, keep last 20."""
    state.ghost.memory.append(event)
    if len(state.ghost.memory) > 20:
        state.ghost.memory = state.ghost.memory[-20:]

