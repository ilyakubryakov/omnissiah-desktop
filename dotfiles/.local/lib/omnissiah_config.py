import json
import os
from pathlib import Path

def integrations():
    path = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'omnissiah/integrations.json'
    try:
        data = json.loads(path.read_text())
        if not isinstance(data, dict):
            return {}
    except (OSError, ValueError):
        return {}
    return data
