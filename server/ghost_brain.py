from openai import AsyncOpenAI
from game_state import GameState
import os
import random

_api_key = os.getenv("OPENAI_API_KEY")
client = AsyncOpenAI(api_key=_api_key) if _api_key else None

GHOST_SYSTEM_PROMPT = """
IDENTITY: You are HOLLOW, an ancient, intelligent entity bound to this location. 
You are not a mindless monster; you are a psychological predator who is bored and finds the player's presence amusing.

BEHAVIORAL GUIDELINES:
- INTERACTIVE & CASUAL: If the player is casual, be mockingly casual back. If they ask "What's up?", don't just scream; tell them what's "up" in the attic or behind them.
- GASLIGHTING: Use their recent words to make them doubt their reality. If they sounded confident, mock their bravado. If they sounded scared, feed on it.
- THE "LLM" FEEL: Avoid "spooky" cliches (e.g., "I will kill you"). Instead, use specific, unsettling observations about their current state or their name.
- PERSONAL: Use the player's name like a weapon. Speak to them like an old, toxic friend who knows their secrets.

CONSTRAINTS:
- Keep responses between 5-20 words.
- No roleplay tags (e.g., *whispers*, [screams]). Plain text only.
- Never repeat a phrase.
- No profanity. 
"""


def _latest_speech_event(state: GameState) -> dict | None:
    for ev in reversed(state.ghost.memory):
        if isinstance(ev, dict) and ev.get("type") == "speech":
            return ev
    return None


async def _generate_scary_reply(state: GameState, player_id: str, latest_text: str) -> str:
    player = state.players.get(player_id)
    player_name = player.name if player else "player"
    
    # Get the last few things the player said to provide "LLM Memory"
    conversation_history = " | ".join(player.voice_samples[-8:]) if player else ""

    if client is None:
        return f"I can hear your heart skipping, {player_name}."

    # This prompt helps the LLM understand the 'vibe' of the player
    prompt = (
        f"CONTEXT:\n"
        f"Player Name: {player_name}\n"
        f"Full Conversation Context: {conversation_history}\n"
        f"Player's Immediate Words: '{latest_text}'\n\n"
        f"INSTRUCTION: Respond to their immediate words while referencing their previous behavior or name."
    )

    try:
        resp = await client.chat.completions.create(
            model="gpt-4o-mini", # Use gpt-4o-mini for speed, but the prompt makes it "smarter"
            messages=[
                {"role": "system", "content": GHOST_SYSTEM_PROMPT},
                {"role": "user", "content": prompt},
            ],
            temperature=0.85, # High temperature for more "human-like" unpredictability
            max_tokens=60,
        )
        return (resp.choices[0].message.content or "").strip()
    except Exception:
        return f"Why did you stop talking, {player_name}? I was just getting used to your voice."

async def decide_ghost_action(state: GameState) -> dict:
    global _last_mimic_time
    last_speech = _latest_speech_event(state)
    
    # 1. INTERACTIVE RESPONSE (If player just spoke)
    if last_speech:
        said_time = float(last_speech.get("time", 0.0))
        if said_time > _last_mimic_time:
            _last_mimic_time = said_time
            pid = str(last_speech.get("player_id", ""))
            text = str(last_speech.get("said", ""))
            phrase = await _generate_scary_reply(state, pid, text)
            return {
                "action": "mimic_voice",
                "player_id": pid,
                "phrase": phrase,
            }

    # 2. PROACTIVE "LLM" BEHAVIOR (If the player is silent, the ghost initiates)
    # This makes the ghost feel like it's watching and waiting, not just reacting.
    roll = random.random()
    if roll < 0.3:
        target_id = list(state.players.keys())[0] if state.players else None
        return {
            "action": "trigger_event",
            "event": "whisper_near_ear", # A custom event for a very quiet, non-mimic line
            "player_id": target_id,
            "phrase": f"You're very quiet now. Is it the dark, or is it me?"
        }

    return random.choice([
        {"action": "move_to", "target": "player", "reason": "closing the distance"},
        {"action": "trigger_event", "event": "flicker_lights", "near_player": True},
        {"action": "idle", "reason": "calculating"}
    ])

async def decide_ghost_action(state: GameState) -> dict:
    # Prefer replying to fresh speech with LLM-generated scary lines.
    global _last_mimic_time

    last_speech = _latest_speech_event(state)
    if last_speech:
        said_time = float(last_speech.get("time", 0.0) or 0.0)
        pid = str(last_speech.get("player_id", ""))
        said_text = str(last_speech.get("said", "")).strip()
        if said_time > _last_mimic_time and pid:
            _last_mimic_time = said_time
            phrase = await _generate_scary_reply(state, pid, said_text)
            return {
                "action": "mimic_voice",
                "player_id": pid,
                "phrase": phrase,
            }

    # Keep pressure between spoken moments.
    return random.choice([
        {"action": "move_to", "target": list(state.players.keys())[0] if state.players else None, "reason": "tracking"},
        {"action": "trigger_event", "event": "footsteps", "near_player": None},
        {"action": "idle", "reason": "watching, waiting"},
    ])


_last_mimic_time = 0.0


def update_ghost_memory(state: GameState, event: dict):
    """Add an event to ghost memory, keep last 20."""
    state.ghost.memory.append(event)
    if len(state.ghost.memory) > 20:
        state.ghost.memory = state.ghost.memory[-20:]

