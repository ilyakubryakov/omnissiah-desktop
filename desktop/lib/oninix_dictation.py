import array
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import signal
import socket
import socketserver
import subprocess
import threading
import time
import wave

import oninix_meetings as speech
import oninix_duck
from oninix_notebook import atomic

STATE = Path(os.environ.get('ONINIX_DICTATION_STATE', str(Path.home() / '.local/state/oninix/dictation')))
CONFIG = Path(os.environ.get('ONINIX_DICTATION_CONFIG', str(Path.home() / '.config/oninix/dictation.json')))
SESSION_RUNTIME = os.environ.get('XDG_RUNTIME_DIR')
DEFAULT_RUNTIME = Path(SESSION_RUNTIME) / f'oninix-dictation-{os.getuid()}' if SESSION_RUNTIME else STATE / 'runtime'
RUNTIME = Path(os.environ.get('ONINIX_DICTATION_RUNTIME', DEFAULT_RUNTIME))
SOCKET = RUNTIME / 'socket'
VAD = speech.CACHE / 'ggml-silero-v6.2.0.bin'
ASSISTANT = Path(shutil.which('oninix-spirit') or '/run/current-system/sw/bin/oninix-spirit')
VAD_HASH = '2aa269b785eeb53a82983a20501ddf7c1d9c48e33ab63a41391ac6c9f7fb6987'

def settings(values=None):
    value = dict(model=speech.profile().get('model', 'base'), language='auto', vocabulary='')
    value.update(speech.read(CONFIG, {}))
    if values:
        value.update({k:v for k,v in values.items() if k in ('model','language','vocabulary')})
    if value['model'] not in speech.MODELS or not speech.LANGUAGE.fullmatch(str(value['language'])):
        raise ValueError('Choose a Whisper model and a language code or auto.')
    if not isinstance(value['vocabulary'], str):
        raise ValueError('Vocabulary must be text.')
    value['vocabulary'] = speech.vocabulary(value['vocabulary'])
    if values is not None:
        speech.write(CONFIG, value)
    return value

def available_vad():
    return VAD.is_file() and VAD.stat().st_size == 885098 and speech.read(VAD.with_suffix('.verified')) == VAD_HASH

def focus():
    locked = json.loads(subprocess.check_output(['hyprctl','-j','locked'], timeout=2))
    if locked.get('locked', True):
        raise ValueError('Dictation is unavailable on the lock screen.')
    window = json.loads(subprocess.check_output(['hyprctl','-j','activewindow'], timeout=2))
    if not window.get('address') or not window.get('pid'):
        raise ValueError('Focus a text field in an application first.')
    return {key:window.get(key) for key in ('address','pid','class','title','monitor','xwayland')}

def same_window(original, current):
    return all(original.get(k) == current.get(k) for k in ('address','pid','class'))

def text_from(result):
    parts = []
    for item in result.get('transcription', []):
        text = item.get('text', '').strip()
        if text and not re.fullmatch(r'\[.*\]|\(.*\)', text):
            parts.append(text)
    text = ' '.join(' '.join(parts).split())
    return ''.join(c for c in text if ord(c) >= 32 and ord(c) != 127)[:12000]

def executable(name):
    found = shutil.which(name)
    if not found:
        candidate = Path.home() / '.local/share/oninix/tools' / name / 'bin' / name
        if candidate.is_file():
            found = str(candidate)
    if not found:
        raise ValueError(name + ' is not installed.')
    return found

def insert_text(text, target, cancelled):
    if not target.get('xwayland'):
        speech.run([executable('wtype'),'-'],cancelled,input_text=text,timeout=10)
        return

    paste = executable('wl-paste')
    copy = executable('wl-copy')
    types = subprocess.run([paste,'--list-types'],capture_output=True,timeout=3)
    offered = types.stdout.decode().splitlines()
    saved_type = next((t for t in offered if t.startswith('image/')), None)
    saved_type = saved_type or next((t for t in ('text/html','text/plain;charset=utf-8','text/plain') if t in offered), None)
    if offered and not saved_type:
        raise ValueError('Clipboard format cannot be preserved. Copy the dictation manually.')
    saved = None
    if saved_type:
        saved = subprocess.run([paste,'--no-newline','--type',saved_type],capture_output=True,timeout=3,check=True).stdout
    elif types.returncode == 0:
        raise ValueError('Clipboard could not be read. Copy the dictation manually.')

    owner = subprocess.Popen([copy,'--foreground','--sensitive','--type','text/plain;charset=utf-8'],stdin=subprocess.PIPE,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    try:
        owner.stdin.write(text.encode()); owner.stdin.close()
        if cancelled.wait(.15) or owner.poll() is not None:
            raise ValueError('Clipboard paste interrupted. Your dictation is kept.')
        if not same_window(target,focus()):
            raise ValueError('Focus changed before paste. Your dictation is kept.')
        address = target.get('address','')
        if not re.fullmatch(r'0x[0-9a-f]+', address):
            raise ValueError('Window address is unknown. Your dictation is kept.')
        speech.run(['hyprctl','dispatch',"hl.dsp.send_shortcut({mods='CTRL', key='code:55', window='address:" + address + "'})"],cancelled,timeout=3)
        time.sleep(.6)
    finally:
        if owner.poll() is None:
            command = [copy,'--type',saved_type] if saved_type else [copy,'--clear']
            subprocess.run(command,input=saved,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=3,check=True)
        if owner.poll() is None:
            owner.terminate()
        owner.wait(timeout=3)

class Dictation:
    def __init__(self):
        RUNTIME.mkdir(parents=True, exist_ok=True, mode=0o700)
        STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.lock = threading.RLock()
        self.cancelled = threading.Event()
        self.finished = set()
        self.keys_up = threading.Event()
        self.process = None
        self.thread = None
        self.token = ''
        self.mode = 'dictation'
        self.target = {}
        self.started = 0
        self.level = 0
        self.text = (STATE / 'draft.txt').read_text() if (STATE / 'draft.txt').exists() else ''
        self.phase = 'review' if self.text else 'error' if (RUNTIME / 'voice.wav').exists() else 'idle'
        self.message = 'Recovered text. Copy it when ready.' if self.text else 'An interrupted recording can be retried.' if self.phase == 'error' else ''
        self.nodes = []
        self.nodes_at = 0
        self.download = {}
        self.downloading = False
        self.blocked = 0
        self.closed = False
        self.ducked = False
        threading.Thread(target=self.monitor, daemon=True).start()

    def devices(self):
        if time.monotonic() - self.nodes_at > 3:
            self.nodes = [n for n in speech.devices() if n['kind'] == 'mic']
            self.nodes_at = time.monotonic()
        return self.nodes

    def status(self):
        with self.lock:
            nodes = self.nodes
            return dict(phase=self.phase, mode=self.mode, message=self.message, text=self.text, level=self.level,
                        seconds=max(0,time.monotonic()-self.started) if self.phase=='recording' else 0,
                        monitor=self.target.get('monitor',-1), settings=settings(), devices=nodes,
                        microphone=speech.read(STATE/'device.json',{}).get('name','default'),
                        ready=speech.model_ready(settings()['model']) and available_vad(), download=self.download,
                        blocked=self.blocked)

    def stop_capture(self):
        if self.process:
            speech.stop_process(self.process)
            self.process = None
        self.level = 0

    def clear_audio(self):
        for name in ('voice.wav','input.wav','result.json'):
            (RUNTIME / name).unlink(missing_ok=True)

    def handle(self, request):
        op = request.get('op'); token = request.get('token','')
        if op == 'status': return self.status()
        if op in ('press','release','keys-up') and not re.fullmatch(r'[A-Za-z0-9_-]{1,100}', token):
            raise ValueError('Invalid shortcut token.')
        with self.lock:
            if op == 'devices':
                self.nodes_at=0; self.devices()
            elif op == 'settings':
                settings(request.get('settings',{}))
            elif op == 'microphone':
                name=request.get('name')
                if name != 'default' and name not in [n['name'] for n in self.devices()]:
                    raise ValueError('Microphone is unavailable.')
                speech.write(STATE/'device.json',dict(name=name))
            elif op == 'download':
                if self.downloading: return self.status()
                self.downloading=True
                threading.Thread(target=self.download_models, daemon=True).start()
            elif op == 'press':
                if token in self.finished: return self.status()
                if self.phase in ('recording','transcribing','cancelling'):
                    return self.status()
                if self.text and self.phase == 'copied':
                    self.text=''; (STATE/'draft.txt').unlink(missing_ok=True)
                if self.text:
                    self.blocked+=1
                    self.message='Previous text is still waiting. Copy or dismiss it, then hold the key again.'
                    return self.status()
                voice=speech.profile()
                if voice and not voice.get('enabled', True):
                    self.phase='error'; self.message='Voice is off: '+voice.get('reason','')+' Run oninix-voice-profile --force to enable it.'
                    return self.status()
                config=settings()
                if not speech.model_ready(config['model']) or not available_vad():
                    self.phase='error'; self.message='Download the dictation models in Notebook → Meet → Setup.'
                    return self.status()
                assistant=request.get('mode')=='assistant'
                self.mode='assistant' if assistant else 'dictation'
                self.target=focus()
                expected=request.get('target')
                if not assistant and expected is not None and (not isinstance(expected,dict) or
                        any(expected.get(k) != self.target.get(k) for k in ('address','pid'))):
                    raise ValueError('Focus changed before recording started. Hold Right Alt again in the text field.')
                if assistant and not ASSISTANT.exists():
                    raise ValueError('The machine spirit is not set up yet.')
                if not assistant:
                    executable('wtype')
                self.ducked=oninix_duck.duck('dictation')>=0
                nodes=self.devices()
                selected=speech.read(STATE/'device.json',{}).get('name','default')
                node=next((n for n in nodes if n['default']),nodes[0] if nodes else None) if selected=='default' else next((n for n in nodes if n['name']==selected),None)
                if not node: raise ValueError('Choose an available microphone in dictation settings.')
                self.clear_audio(); self.cancelled.clear(); self.keys_up.clear()
                self.token=token; self.config=config; self.microphone=node['name']; self.message='Hold Right Ctrl to talk to the machine spirit' if assistant else 'Hold Right Alt to speak'
                self.started=time.monotonic()
                self.process=subprocess.Popen([speech.binary('pw-record'),'--target',self.microphone,'--rate','16000','--channels','1','--format','s16','--properties','{ node.name = oninix-dictation node.dont-reconnect = true }',str(RUNTIME/'voice.wav')],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
                self.phase='recording'
            elif op == 'release':
                if token == self.token and request.get('keys_up') is True:
                    self.keys_up.set()
                if token != self.token:
                    self.finished.add(token)
                elif self.phase=='recording':
                    self.stop_capture()
                    if time.monotonic()-self.started < .3:
                        self.clear_audio(); self.phase='idle'; self.message=''; self.finished.add(token)
                    else:
                        self.launch_recognition(True)
            elif op == 'keys-up':
                if token == self.token:
                    self.keys_up.set()
                else:
                    self.finished.add(token)
            elif op == 'cancel':
                self.cancelled.set(); self.stop_capture()
                self.finished.add(self.token)
                if self.phase=='transcribing':
                    self.phase='cancelling'; self.message='Cancelling…'
                else:
                    self.clear_audio(); self.phase='idle'; self.message=''; self.text=''
                    (STATE/'draft.txt').unlink(missing_ok=True)
            elif op == 'retry':
                if self.phase not in ('error','review') or not (RUNTIME/'voice.wav').exists():
                    raise ValueError('There is no recording to retry.')
                self.cancelled.clear(); self.config=settings(); self.launch_recognition(False)
            elif op == 'copy':
                if not self.text: raise ValueError('There is no text to copy.')
                subprocess.run(['wl-copy'],input=self.text.encode(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=3,check=True)
                self.phase='copied'; self.message='Copied. Paste it where you need it.'
            elif op == 'dismiss':
                if self.phase in ('recording','transcribing','cancelling'): return self.status()
                self.text=''; self.phase='idle'; self.message=''
                self.clear_audio(); (STATE/'draft.txt').unlink(missing_ok=True)
            else: raise ValueError('Unknown dictation action.')
            if len(self.finished)>128: self.finished={self.token}
        return self.status()

    def launch_recognition(self, auto_insert):
        self.phase='transcribing'; self.message='Recognizing speech locally…'
        self.thread=threading.Thread(target=self.recognize,args=(auto_insert,),daemon=True)
        self.thread.start()

    def recognize(self, auto_insert):
        try:
            speech.run([speech.binary('ffmpeg'),'-nostdin','-y','-v','error','-ignore_length','1','-i',str(RUNTIME/'voice.wav'),'-ar','16000','-ac','1','-c:a','pcm_s16le',str(RUNTIME/'input.wav')],self.cancelled,timeout=30)
            with wave.open(str(RUNTIME/'input.wav')) as f:
                samples=array.array('h',f.readframes(f.getnframes()))
            text=''
            if samples and max(abs(s) for s in samples)>32:
                (RUNTIME/'result.json').unlink(missing_ok=True)
                command=[speech.binary('whisper-cli'),'-m',str(speech.model_path(self.config['model'])),'-f',str(RUNTIME/'input.wav'),'-l',self.config['language'],*speech.prompt_args(self.config.get('vocabulary', '')),'-t','4','--vad','-vm',str(VAD),'-oj','-of',str(RUNTIME/'result'),'-np']
                try:
                    speech.run(command,self.cancelled,timeout=300)
                except ValueError:
                    if self.cancelled.is_set(): raise
                    (RUNTIME/'result.json').unlink(missing_ok=True)
                    speech.run(command[:-1]+['-ng','-t','8','-np'],self.cancelled,timeout=300)
                value=speech.read(RUNTIME/'result.json',{})
                if not isinstance(value.get('transcription'),list): raise ValueError('Whisper did not return a transcript. Retry the recording.')
                text=text_from(value)
            with self.lock:
                if self.cancelled.is_set(): raise ValueError('Cancelled')
                self.text=text
                if not text:
                    self.phase='empty'; self.message='No speech detected'; self.clear_audio(); return
                atomic(STATE/'draft.txt',text)
            if auto_insert and self.mode=='assistant':
                result=subprocess.run([str(ASSISTANT),'ask'],input=text,text=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,timeout=20)
                with self.lock:
                    if result.returncode:
                        raise ValueError('The machine spirit did not take the text. Copy it and retry.')
                    self.phase='handed'; self.message='Sent to the machine spirit'; self.text=''
                    (STATE/'draft.txt').unlink(missing_ok=True); self.clear_audio()
                return
            if auto_insert:
                for _ in range(50):
                    if self.keys_up.wait(.1) or self.cancelled.is_set(): break
            with self.lock:
                if self.cancelled.is_set(): raise ValueError('Cancelled')
                if auto_insert and self.keys_up.is_set() and same_window(self.target,focus()):
                    insert_text(text,self.target,self.cancelled)
                    self.phase='inserted'; self.message='Text inserted'; self.text=''
                    (STATE/'draft.txt').unlink(missing_ok=True)
                else:
                    self.phase='review'; self.message='Text is ready. Focus changed or a shortcut key is still held; copy it when ready.'
                self.clear_audio()
        except Exception as exc:
            with self.lock:
                if self.cancelled.is_set() and not self.closed:
                    self.phase='idle'; self.text=''; self.message=''; self.clear_audio(); (STATE/'draft.txt').unlink(missing_ok=True)
                else:
                    self.phase='review' if self.text else 'error'
                    self.message=str(exc) if isinstance(exc,ValueError) else 'Dictation failed. Your recording is kept; check the microphone and retry.'
        finally:
            with self.lock:
                self.finished.add(self.token)

    def monitor(self):
        previous=time.time()
        while not self.closed:
            time.sleep(.25)
            with self.lock:
                now=time.time(); gap=now-previous; previous=now
                if self.ducked and self.phase not in ('recording','transcribing'):
                    self.ducked=False; oninix_duck.restore('dictation')
                if int(now)%10==0 and now-int(now)<.25:
                    oninix_duck.tidy()
                if self.phase!='recording': continue
                try:
                    if gap>10: raise ValueError('Recording interrupted by sleep. Retry or dismiss it.')
                    if time.monotonic()-self.started>90:
                        self.stop_capture(); self.keys_up.set(); self.launch_recognition(False); continue
                    if self.process.poll() is not None: raise ValueError('Microphone recording stopped. Check the input device.')
                    if self.microphone not in [n['name'] for n in self.devices()]: raise ValueError('The microphone disconnected.')
                    if int(time.monotonic()*4)%4==0:
                        focus()
                    path=RUNTIME/'voice.wav'
                    if path.exists() and path.stat().st_size>4096:
                        with path.open('rb') as f: f.seek(-4096,2); values=array.array('h',f.read(4096))
                        self.level=min(1,(sum(x*x for x in values)/len(values))**.5/8192)
                except Exception as exc:
                    self.stop_capture(); self.phase='error'; self.message=str(exc)

    def download_models(self):
        try:
            key=settings()['model']
            self.download=dict(state='downloading',progress=0)
            if not speech.model_ready(key):
                speech.Meetings.download_model(self,key)
                if not speech.model_ready(key): raise ValueError('Whisper download failed.')
            if not available_vad():
                speech.download_verified(
                    VAD, 'https://huggingface.co/ggml-org/whisper-vad/resolve/main/' + VAD.name,
                    885098, VAD_HASH)
            self.download=dict(state='ready',progress=100)
            if self.phase=='error': self.message='Models ready. Hold Right Alt in a text field.'
        except Exception:
            self.download=dict(state='error',message='Model download failed. Check your connection and retry.')
        finally: self.downloading=False

def serve():
    os.umask(0o077)
    speech.private_directory(STATE, create=True)
    speech.private_directory(RUNTIME, create=True)
    guard=(RUNTIME/'lock').open('a');fcntl.flock(guard,fcntl.LOCK_EX|fcntl.LOCK_NB)
    manager=Dictation()
    class Handler(socketserver.StreamRequestHandler):
        def handle(self):
            request={}
            try:
                raw=self.rfile.readline(65537)
                if len(raw)>65536:raise ValueError('Request too large.')
                request=json.loads(raw);result=dict(ok=True,data=manager.handle(request))
            except ValueError as exc:
                with manager.lock:
                    if request.get('op') in ('press','retry') and manager.phase not in ('recording','transcribing','cancelling'):
                        manager.phase='error';manager.message=str(exc)
                result=dict(ok=False,message=str(exc))
            except Exception:result=dict(ok=False,message='Dictation action failed. Your draft is kept.')
            result['requestId']=request.get('requestId')
            self.wfile.write((json.dumps(result,ensure_ascii=False)+'\n').encode())
    SOCKET.unlink(missing_ok=True)
    with socketserver.ThreadingUnixStreamServer(str(SOCKET),Handler) as server:
        def close(*_):
            manager.closed=True;manager.cancelled.set()
            with manager.lock:manager.stop_capture()
            raise SystemExit(0)
        signal.signal(signal.SIGTERM,close);signal.signal(signal.SIGINT,close)
        server.serve_forever()

def rpc(request):
    speech.private_directory(RUNTIME)
    with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as client:
        client.settimeout(12);client.connect(str(SOCKET))
        client.sendall((json.dumps(request)+'\n').encode())
        return json.loads(client.makefile().readline(1024*1024))
