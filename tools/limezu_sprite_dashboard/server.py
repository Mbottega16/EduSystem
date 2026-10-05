#!/usr/bin/env python3
"""
Limezu Sprite Hub & Studio Server
Zero external dependencies (pure Python standard library).
Indexes local directories and zip archives on-the-fly.
"""

import os
import sys
import json
import base64
import urllib.parse
import mimetypes
import zipfile
import threading
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler

# Windows consoles default to cp1252, which cannot encode the emoji in this
# tool's own banner and source names -- printing one raises UnicodeEncodeError
# and kills the server before it binds.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

PORT = 5050
DASHBOARD_DIR = os.path.dirname(os.path.abspath(__file__))
TOOLS_DIR = os.path.dirname(DASHBOARD_DIR)
REPO_ROOT = os.path.dirname(TOOLS_DIR)

# Pack locations are never hardcoded. limezu.find_pack() already resolves them
# per-machine from $LIMEZU_DIR, tools/limezu_path.txt, then Desktop/Downloads.
sys.path.insert(0, TOOLS_DIR)
import limezu
import studio

CUSTOM_ITEMS_DIR = os.path.join(DASHBOARD_DIR, "custom_items")
os.makedirs(CUSTOM_ITEMS_DIR, exist_ok=True)

# Modern Interiors Free v2.2 is deliberately NOT a source: its licence is
# non-commercial and EduSystem ships on Steam. The full pack replaces it.
PACK_SOURCES = [
    ("interiors", "🏠 Modern Interiors (full)"),
    ("office", "🏢 Modern Office (Revamped)"),
    ("ui", "🖥️ Modern User Interface"),
]


def discover_sources():
    """Build the source list from whatever packs this machine actually has."""
    found = []
    for key, label in PACK_SOURCES:
        try:
            pack = limezu.find_pack(key)
        except SystemExit:
            print(f"  pack not found, skipping: {key}", file=sys.stderr)
            continue
        except Exception as exc:
            print(f"  pack {key} failed to open: {exc}", file=sys.stderr)
            continue
        found.append({
            "id": key,
            "name": label,
            "type": "zip" if pack.where.lower().endswith(".zip") else "dir",
            "path": pack.where,
            "exclude_zips": True,
        })
        print(f"  {key}: {pack.where}")
    found.append({
        "id": "custom_items",
        "name": "⭐ My Custom & Created Items",
        "type": "dir",
        "path": CUSTOM_ITEMS_DIR,
        "is_custom": True,
    })
    return found


DEFAULT_SOURCES = discover_sources()


def safe_join(base, rel):
    """Join rel onto base, returning None for anything that escapes base.

    /api/delete and the dir-backed image reads take a client-supplied path.
    Without this, '../../..' reaches any file the server process can touch.
    """
    base_abs = os.path.abspath(base)
    target = os.path.abspath(os.path.join(base_abs, rel.replace("\\", "/").lstrip("/")))
    if target != base_abs and not target.startswith(base_abs + os.sep):
        return None
    return target

IMAGE_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.ase', '.aseprite'}

class SpriteCatalog:
    def __init__(self):
        self.sources = list(DEFAULT_SOURCES)
        self.indices = {} # source_id -> list of item dicts
        self.tree_cache = {} # source_id -> folder tree
        self.zip_handles = {} # source_id -> ZipFile object
        self.lock = threading.Lock()
        self.build_all_indices()

    def get_zip_handle(self, zip_path):
        if zip_path not in self.zip_handles:
            self.zip_handles[zip_path] = zipfile.ZipFile(zip_path, 'r')
        return self.zip_handles[zip_path]

    def build_all_indices(self):
        with self.lock:
            for src in self.sources:
                self._index_source(src)

    def refresh_source(self, source_id):
        with self.lock:
            for src in self.sources:
                if src["id"] == source_id:
                    self._index_source(src)
                    break

    def _determine_tags(self, filename, rel_path):
        lower_name = filename.lower()
        lower_path = rel_path.lower()
        tags = []
        res = None
        if "16x16" in lower_path or "16x16" in lower_name:
            res = "16x16"
        elif "32x32" in lower_path or "32x32" in lower_name:
            res = "32x32"
        elif "48x48" in lower_path or "48x48" in lower_name:
            res = "48x48"
        
        is_sheet = False
        if any(w in lower_path or w in lower_name for w in ["tileset", "sheet", "room_builder", "designs", "generator", "interiors_01", "interiors_02", "walls_floors"]):
            is_sheet = True
        elif any(w in lower_path or w in lower_name for w in ["single", "singles", "icon", "premade"]):
            is_sheet = False
        else:
            # Check by name
            if "anim" in lower_name or "walk" in lower_name or "run" in lower_name or "idle" in lower_name:
                is_sheet = True
                tags.append("animation")

        if is_sheet:
            tags.append("sheet")
        else:
            tags.append("single")

        if "character" in lower_path or "character" in lower_name:
            tags.append("character")
        if "ui" in lower_path or "interface" in lower_path:
            tags.append("ui")
        if "shadowless" in lower_path:
            tags.append("shadowless")
        if "black_shadow" in lower_path:
            tags.append("black_shadow")
            
        return res, tags, is_sheet

    def _index_source(self, src):
        source_id = src["id"]
        source_type = src["type"]
        source_path = src["path"]
        
        items = []
        folder_set = set()

        if not os.path.exists(source_path):
            self.indices[source_id] = []
            self.tree_cache[source_id] = []
            return

        if source_type == "zip":
            try:
                zf = self.get_zip_handle(source_path)
                for member in zf.namelist():
                    if member.endswith('/'):
                        continue
                    ext = os.path.splitext(member)[1].lower()
                    if ext in IMAGE_EXTENSIONS:
                        folder = os.path.dirname(member)
                        fname = os.path.basename(member)
                        folder_set.add(folder)
                        res, tags, is_sheet = self._determine_tags(fname, member)
                        items.append({
                            "id": f"{source_id}::{member}",
                            "source_id": source_id,
                            "name": fname,
                            "rel_path": member,
                            "folder": folder,
                            "ext": ext,
                            "res": res,
                            "tags": tags,
                            "is_sheet": is_sheet,
                            "is_zip": True
                        })
            except Exception as e:
                print(f"Error indexing zip {source_path}: {e}", file=sys.stderr)

        elif source_type == "dir":
            exclude_zips = src.get("exclude_zips", False)
            for root, dirs, files in os.walk(source_path):
                # Don't index My_Custom_Items if scanning main folder to avoid double counting
                if source_id == "office_extracted" and os.path.abspath(root).startswith(os.path.abspath(CUSTOM_ITEMS_DIR)):
                    continue
                # Skip hidden folders
                dirs[:] = [d for d in dirs if not d.startswith('.')]
                rel_dir = os.path.relpath(root, source_path)
                if rel_dir == '.':
                    rel_dir = ''
                if rel_dir:
                    folder_set.add(rel_dir)
                    
                for f in files:
                    ext = os.path.splitext(f)[1].lower()
                    if ext in IMAGE_EXTENSIONS:
                        full_rel = os.path.join(rel_dir, f) if rel_dir else f
                        res, tags, is_sheet = self._determine_tags(f, full_rel)
                        items.append({
                            "id": f"{source_id}::{full_rel}",
                            "source_id": source_id,
                            "name": f,
                            "rel_path": full_rel,
                            "folder": rel_dir,
                            "ext": ext,
                            "res": res,
                            "tags": tags,
                            "is_sheet": is_sheet,
                            "is_zip": False
                        })

        # Sort items alphabetically by name
        items.sort(key=lambda x: (x["folder"], x["name"]))
        self.indices[source_id] = items

        # Build folder tree
        sorted_folders = sorted(list(folder_set))
        tree = []
        for folder in sorted_folders:
            count = sum(1 for item in items if item["folder"] == folder)
            tree.append({"folder": folder, "count": count})
        self.tree_cache[source_id] = tree

    def get_sources_meta(self):
        result = []
        for src in self.sources:
            s_id = src["id"]
            total = len(self.indices.get(s_id, []))
            result.append({
                "id": s_id,
                "name": src["name"],
                "type": src["type"],
                "path": src["path"],
                "count": total,
                "is_custom": src.get("is_custom", False)
            })
        return result

    def query_sprites(self, source_id, folder=None, search=None, res_filter=None, type_filter=None, page=1, limit=72):
        items = self.indices.get(source_id, [])
        filtered = items

        # Folder filter
        if folder is not None and folder != "":
            filtered = [it for it in filtered if it["folder"] == folder or it["folder"].startswith(folder + "/")]

        # Search filter
        if search:
            q = search.lower().strip()
            filtered = [it for it in filtered if q in it["name"].lower() or q in it["rel_path"].lower()]

        # Resolution filter
        if res_filter and res_filter != "all":
            filtered = [it for it in filtered if it["res"] == res_filter]

        # Type filter
        if type_filter == "sheet":
            filtered = [it for it in filtered if it["is_sheet"]]
        elif type_filter == "single":
            filtered = [it for it in filtered if not it["is_sheet"]]
        elif type_filter == "anim":
            filtered = [it for it in filtered if "animation" in it["tags"]]

        total = len(filtered)
        start = (page - 1) * limit
        end = start + limit
        paged_items = filtered[start:end]

        return {
            "items": paged_items,
            "total": total,
            "page": page,
            "limit": limit,
            "total_pages": (total + limit - 1) // limit if limit > 0 else 1
        }

    def get_image_data(self, source_id, rel_path):
        src = next((s for s in self.sources if s["id"] == source_id), None)
        if not src:
            return None, None
        
        if src["type"] == "zip":
            zf = self.get_zip_handle(src["path"])
            try:
                data = zf.read(rel_path)
                mime = mimetypes.guess_type(rel_path)[0] or 'image/png'
                return data, mime
            except KeyError:
                return None, None
        else:
            full_path = safe_join(src["path"], rel_path)
            if full_path and os.path.exists(full_path) and os.path.isfile(full_path):
                with open(full_path, 'rb') as f:
                    data = f.read()
                mime = mimetypes.guess_type(full_path)[0] or 'image/png'
                return data, mime
            return None, None

catalog = SpriteCatalog()

class HubRequestHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DASHBOARD_DIR, **kwargs)

    def do_HEAD(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query)

        if path == "/api/image":
            source_id = query.get("source_id", [""])[0]
            rel_path = query.get("path", [""])[0]
            data, mime = catalog.get_image_data(source_id, rel_path)
            if data is not None:
                self.send_response(200)
                self.send_header("Content-Type", mime)
                self.send_header("Content-Length", str(len(data)))
                self.send_header("Cache-Control", "public, max-age=86400")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
            else:
                self.send_error(404, "Sprite not found")
        else:
            self.send_response(200)
            self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query)

        if path == "/api/sources":
            self._send_json(catalog.get_sources_meta())
        elif path == "/api/generators":
            self._send_json(studio.list_generators())
        elif path == "/api/tree":
            source_id = query.get("source_id", ["office_extracted"])[0]
            tree = catalog.tree_cache.get(source_id, [])
            self._send_json(tree)
        elif path == "/api/sprites":
            source_id = query.get("source_id", ["office_extracted"])[0]
            folder = query.get("folder", [None])[0]
            search = query.get("search", [None])[0]
            res_filter = query.get("res", ["all"])[0]
            type_filter = query.get("type", ["all"])[0]
            try:
                page = int(query.get("page", ["1"])[0])
            except ValueError:
                page = 1
            try:
                limit = int(query.get("limit", ["72"])[0])
            except ValueError:
                limit = 72
            result = catalog.query_sprites(source_id, folder, search, res_filter, type_filter, page, limit)
            self._send_json(result)
        elif path == "/api/image":
            source_id = query.get("source_id", [""])[0]
            rel_path = query.get("path", [""])[0]
            data, mime = catalog.get_image_data(source_id, rel_path)
            if data is not None:
                self.send_response(200)
                self.send_header("Content-Type", mime)
                self.send_header("Content-Length", str(len(data)))
                self.send_header("Cache-Control", "public, max-age=86400")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(data)
            else:
                self.send_error(404, "Sprite not found")
        elif path == "/" or path == "/index.html":
            index_path = os.path.join(DASHBOARD_DIR, "index.html")
            with open(index_path, "rb") as f:
                content = f.read()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)
        else:
            # Fall back to static file serving
            super().do_GET()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length) if length > 0 else b'{}'
        try:
            payload = json.loads(body.decode('utf-8'))
        except Exception:
            payload = {}

        if path == "/api/save-item":
            # Save new item (base64 image) to My_Custom_Items
            name = payload.get("name", "custom_sprite.png").strip()
            if not name.endswith(".png"):
                name += ".png"
            # Sanitize filename
            safe_name = "".join(c for c in name if c.isalnum() or c in ('_', '-', '.'))
            if not safe_name:
                safe_name = "custom_item.png"

            data_str = payload.get("data", "")
            if "," in data_str:
                data_str = data_str.split(",", 1)[1]
            try:
                img_bytes = base64.b64decode(data_str)
                out_path = os.path.join(CUSTOM_ITEMS_DIR, safe_name)
                # Ensure unique filename if already exists
                base, ext = os.path.splitext(safe_name)
                counter = 1
                while os.path.exists(out_path):
                    out_path = os.path.join(CUSTOM_ITEMS_DIR, f"{base}_{counter}{ext}")
                    counter += 1
                
                with open(out_path, "wb") as f:
                    f.write(img_bytes)
                
                catalog.refresh_source("custom_items")
                self._send_json({"success": True, "filename": os.path.basename(out_path), "path": out_path})
            except Exception as e:
                self._send_json({"success": False, "error": str(e)}, status=500)

        elif path == "/api/duplicate":
            # Duplicate item to custom items
            source_id = payload.get("source_id")
            rel_path = payload.get("path")
            data, _ = catalog.get_image_data(source_id, rel_path)
            if data is not None:
                base_name = os.path.basename(rel_path)
                name, ext = os.path.splitext(base_name)
                copy_name = f"{name}_copy{ext}"
                out_path = os.path.join(CUSTOM_ITEMS_DIR, copy_name)
                counter = 1
                while os.path.exists(out_path):
                    out_path = os.path.join(CUSTOM_ITEMS_DIR, f"{name}_copy_{counter}{ext}")
                    counter += 1
                with open(out_path, "wb") as f:
                    f.write(data)
                catalog.refresh_source("custom_items")
                self._send_json({"success": True, "filename": os.path.basename(out_path)})
            else:
                self._send_json({"success": False, "error": "Item not found"}, status=404)

        elif path == "/api/delete":
            # Delete an item from custom items
            target = safe_join(CUSTOM_ITEMS_DIR, payload.get("path") or "")
            if target is None:
                self._send_json({"success": False, "error": "Path refused"}, status=400)
            elif os.path.exists(target) and os.path.isfile(target):
                os.remove(target)
                catalog.refresh_source("custom_items")
                self._send_json({"success": True})
            else:
                self._send_json({"success": False, "error": "File not found"}, status=404)

        elif path == "/api/sources/add":
            # Add dynamic source directory or zip
            add_path = payload.get("path", "").strip()
            name = payload.get("name", os.path.basename(add_path)).strip()
            if os.path.exists(add_path):
                is_zip = add_path.endswith('.zip')
                new_id = f"custom_src_{len(catalog.sources)+1}"
                catalog.sources.append({
                    "id": new_id,
                    "name": f"📁 {name}",
                    "type": "zip" if is_zip else "dir",
                    "path": add_path
                })
                catalog.refresh_source(new_id)
                self._send_json({"success": True, "sources": catalog.get_sources_meta()})
            else:
                self._send_json({"success": False, "error": "Path does not exist"}, status=400)

        elif path == "/api/generate":
            # Run one of the repo's generator CLIs and hand back its output.
            result = studio.run_generator(
                payload.get("generator", ""), payload.get("args") or [])
            self._send_json(result, status=200 if result.get("ok") else 400)

        elif path == "/api/transform":
            # Colour / texture / shape pass over one sprite. Source is either a
            # catalogued sprite (source_id + path) or inline base64 data.
            try:
                if payload.get("data"):
                    raw = payload["data"]
                    if "," in raw:
                        raw = raw.split(",", 1)[1]
                    png = base64.b64decode(raw)
                else:
                    png, _ = catalog.get_image_data(
                        payload.get("source_id", ""), payload.get("path", ""))
                if not png:
                    self._send_json({"success": False, "error": "Sprite not found"}, status=404)
                    return
                out, size = studio.transform(png, payload)
                self._send_json({
                    "success": True,
                    "width": size[0],
                    "height": size[1],
                    "data": "data:image/png;base64," + base64.b64encode(out).decode("ascii"),
                })
            except Exception as exc:
                self._send_json({"success": False, "error": str(exc)}, status=400)

        else:
            self.send_error(404, "Endpoint not found")

    def _send_json(self, data, status=200):
        body = json.dumps(data).encode('utf-8')
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

def run():
    print(f"🎮 Limezu Sprite Hub Server starting on http://127.0.0.1:{PORT}")
    # Loopback only, never 0.0.0.0: this host's firewall permits inbound on the
    # Public profile and home Wi-Fi is Public, so a wildcard bind publishes the
    # sprite packs and the delete endpoint to the whole network.
    server = ThreadingHTTPServer(("127.0.0.1", PORT), HubRequestHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server.")
        server.server_close()

if __name__ == "__main__":
    run()
