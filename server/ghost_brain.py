from openai import AsyncOpenAI
from game_state import GameState
import os
import random

_api_key = os.getenv("OPENAI_API_KEY")
client = AsyncOpenAI(api_key=_api_key) if _api_key else None

GHOST_SYSTEM_PROMPT = """
You are HOLLOW, a malevolent ghost.
Write one short scary line (8-18 words) spoken directly to the player.
Use their latest words against them. Keep it creepy, personal, and clear.
No profanity. No roleplay tags. Return plain text only.
"""


def _latest_speech_event(state: GameState) -> dict | None:
    for ev in reversed(state.ghost.memory):
        if isinstance(ev, dict) and ev.get("type") == "speech":
            return ev
    return None


async def _generate_scary_reply(state: GameState, player_id: str, latest_text: str) -> str:
    player = state.players.get(player_id)
    player_name = player.name if player else "player"
    recent = player.voice_samples[-5:] if player else []
    recent_text = " | ".join(recent) if recent else latest_text

    if client is None:
        return f"{player_name}... I heard you. Keep talking, and I get closer."

    prompt = (
        f"Player name: {player_name}\n"
        f"Latest speech: {latest_text}\n"
        f"Recent speech: {recent_text}\n"
        "Write one terrifying sentence."
    )

    try:
        resp = await client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": GHOST_SYSTEM_PROMPT},
                {"role": "user", "content": prompt},
            ],
            temperature=0.9,
            max_tokens=50,
        )
        text = (resp.choices[0].message.content or "").strip()
        return text if text else f"{player_name}... your voice belongs to me now."
    except Exception:
        return f"{player_name}... your voice belongs to me now."


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

