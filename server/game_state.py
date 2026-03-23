from pydantic import BaseModel
from typing import Dict, List, Optional
import time


class PlayerState(BaseModel):
    id: str
    name: str
    position: dict = {"x": 0, "y": 0}
    is_haunted: bool = False
    haunt_count: int = 0
    voice_samples: List[str] = []  # recent transcriptions
    eleven_voice_id: Optional[str] = None  # cloned voice ID


class GhostState(BaseModel):
    position: dict = {"x": 5, "y": 5}
    current_action: str = "idle"
    target_player_id: Optional[str] = None
    memory: List[dict] = []  # rolling log of player speech + events
    personality: str = "malevolent, patient, mimics the weak"


class GameState(BaseModel):
    players: Dict[str, PlayerState] = {}
    ghost: GhostState = GhostState()
    fuses_found: int = 0
    game_phase: str = "lobby"  # lobby | playing | ghost_wins | players_win
    started_at: Optional[float] = None

