# music.xedoc.ru

Minimal public frontend and deployment notes for `music.xedoc.ru`.

The production setup is split in two:

- `music.xedoc.ru` server hosts the static website and nginx proxy.
- Local Windows PC runs StableDAW inference with the Medium ARC model and exposes it to the server through an SSH reverse tunnel.

## Source Locations

- Simple public page: `public/index.html`
- Server nginx config: `deploy/nginx/music.xedoc.ru.conf`
- Local Windows launchers: `scripts/start_music_xedoc.bat` and `scripts/stop_music_xedoc.bat`
- StableDAW backend patch: `patches/stabledaw-audio-ready.patch`
- StableDAW library votes patch: `patches/stabledaw-library-votes.patch`
- StableDAW app source locally: `C:\pinokio\api\stabledaw.pinokio.git\app`
- StableDAW app clone on server: `/var/www/music.xedoc.ru/app`
- Generated audio locally: `C:\pinokio\api\stabledaw.pinokio.git\app\data\generations`

Generated audio is not stored on the server in the current setup.

## Routes

- `https://music.xedoc.ru/` - simple prompt-to-music page
- `https://music.xedoc.ru/simple` - same simple page
- `https://music.xedoc.ru/editor` - full StableDAW editor
- `https://music.xedoc.ru/api/*` - proxied to local backend through the SSH tunnel

## Local Startup

After rebooting the Windows inference machine, run:

```bat
C:\pinokio\start_music_xedoc.bat
```

This starts:

- StableDAW backend on `127.0.0.1:8610`
- Medium ARC model
- SSH reverse tunnel to `82.146.42.213`

To stop it:

```bat
C:\pinokio\stop_music_xedoc.bat
```

Keep the backend and tunnel windows open while the public site should generate music.

## StableDAW Backend Patch

`patches/stabledaw-audio-ready.patch` makes `/api/jobs/{id}` expose generated audio as soon as diffusion is done, before spectrogram generation finishes. This lets the public page show the player immediately at `8/8` instead of waiting for spectrogram post-processing.

`patches/stabledaw-library-votes.patch` adds simple per-user like/dislike storage under the local generations folder. The public page creates a browser-local user id and sends it to `/api/library/votes/*`, so one browser user can keep one vote per track. It also adds owner-checked deletion through `/api/library/delete-owned/{entry_id}` for generations created from the public page.

## Deploy Simple Page

Copy `public/index.html` to the server:

```powershell
scp .\public\index.html root@82.146.42.213:/var/www/music.xedoc.ru/app/frontend/dist/simple/index.html
ssh root@82.146.42.213 "chown www-data:www-data /var/www/music.xedoc.ru/app/frontend/dist/simple/index.html"
```

The nginx config maps `/` and `/simple` to this file.

## Deploy Nginx Config

```bash
scp deploy/nginx/music.xedoc.ru.conf root@82.146.42.213:/etc/nginx/sites-available/music.xedoc.ru
ssh root@82.146.42.213 "nginx -t && systemctl reload nginx"
```

## Important Exclusions

Do not commit Stable Audio model files, local `.venv`, generated music, or Pinokio runtime data. Those files are large and machine-specific.
