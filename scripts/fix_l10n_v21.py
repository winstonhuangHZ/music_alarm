#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v2.1 localization repair + verification.

Writes the full v2.1 content for zh-Hans / zh-Hant / es into their correct
.lproj/Localizable.strings files, removes stray editor artifacts, then checks
that every L("...") key used in Sources/ is present in all 7 languages.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOC = os.path.join(ROOT, "Localizations")

ZH_HANS = """/* Music Alarm - 简体中文 (Chinese, Simplified) */

"Next alarm in %@" = "下一次闹钟在 %@";
"No upcoming alarm" = "没有即将响铃的闹钟";
"No alarms yet" = "还没有闹钟";
"Click “Add Alarm” to create your first alarm." = "点击“添加闹钟”创建你的第一个闹钟。";
"Add Alarm" = "添加闹钟";
"System Default" = "系统默认";
"now" = "现在";
"%dh %dm" = "%d小时%d分";
"%dm %ds" = "%d分%d秒";
"%ds" = "%d秒";
"Time" = "时间";
"Repeat" = "重复";
"Alarm Sound" = "闹钟铃声";
"Sound Source" = "声音来源";
"No music imported yet. Import a song to use as the alarm sound." = "尚未导入音乐。导入一首歌曲作为闹钟铃声。";
"Import Music…" = "导入音乐…";
"Cancel" = "取消";
"Save" = "保存";
"Paste a Spotify playlist, track or album link" = "粘贴 Spotify 播放列表、单曲或专辑链接";
"Paste a Spotify playlist link — URL or spotify:playlist:…" = "粘贴 Spotify 播放列表链接 — URL 或 spotify:playlist:…";
"✓ Valid playlist — will play in order." = "✓ 有效的播放列表 — 将按顺序播放。";
"✓ Valid track — single song." = "✓ 有效的单曲 — 将播放单首歌曲。";
"✓ Valid album — will play in order." = "✓ 有效的专辑 — 将按顺序播放。";
"⚠️ Could not parse a Spotify link." = "⚠️ 无法解析 Spotify 链接。";
"⚠️ Could not parse a Spotify playlist link." = "⚠️ 无法解析 Spotify 播放列表链接。";
"Once" = "仅一次";
"Daily" = "每天";
"Weekdays" = "工作日";
"Local Audio" = "本地音频";
"Spotify Playlist" = "Spotify 播放列表";
"Spotify Playlist · %@" = "Spotify 播放列表 · %@";
"No audio selected" = "未选择音频";
"%d tracks" = "%d 个音轨";
"No audio" = "无音频";
"• Snoozed" = "• 已贪睡";
"Preview Sound" = "试听铃声";
"Edit Alarm" = "编辑闹钟";
"Delete Alarm" = "删除闹钟";
"Time to wake up!" = "该起床啦！";
"Snooze 5 min" = "贪睡 5 分钟";
"Stop" = "停止";
"Music Library" = "音乐库";
"Import Music" = "导入音乐";
"No music imported. Click “Import Music” to add .mp3 / .m4a files." = "尚未导入音乐。点击“导入音乐”添加 .mp3 / .m4a 文件。";
"Import" = "导入";
"Select an .mp3 or .m4a audio file" = "选择一个 .mp3 或 .m4a 音频文件";
"About Music Alarm" = "关于 Music Alarm";
"Hide Music Alarm" = "隐藏 Music Alarm";
"Quit Music Alarm" = "退出 Music Alarm";
"Local" = "本地";
"Spotify" = "Spotify";
"Playlist" = "播放列表";
"Add Track" = "添加音轨";
"Tracks" = "音轨";
"No tracks yet. Add local files or Spotify links below." = "还没有音轨。请在下方添加本地文件或 Spotify 链接。";
"Import & Add" = "导入并添加";
"Add to Playlist" = "添加到播放列表";
"""

ZH_HANT = """/* Music Alarm - 繁體中文 (Chinese, Traditional) */

"Next alarm in %@" = "下一次鬧鐘在 %@";
"No upcoming alarm" = "沒有即將響鈴的鬧鐘";
"No alarms yet" = "還沒有鬧鐘";
"Click “Add Alarm” to create your first alarm." = "點擊「新增鬧鐘」建立你的第一個鬧鐘。";
"Add Alarm" = "新增鬧鐘";
"System Default" = "系統預設";
"now" = "現在";
"%dh %dm" = "%d小時%d分";
"%dm %ds" = "%d分%d秒";
"%ds" = "%d秒";
"Time" = "時間";
"Repeat" = "重複";
"Alarm Sound" = "鬧鐘鈴聲";
"Sound Source" = "聲音來源";
"No music imported yet. Import a song to use as the alarm sound." = "尚未匯入音樂。匯入一首歌曲作為鬧鐘鈴聲。";
"Import Music…" = "匯入音樂…";
"Cancel" = "取消";
"Save" = "儲存";
"Paste a Spotify playlist, track or album link" = "貼上 Spotify 播放清單、單曲或專輯連結";
"Paste a Spotify playlist link — URL or spotify:playlist:…" = "貼上 Spotify 播放清單連結 — URL 或 spotify:playlist:…";
"✓ Valid playlist — will play in order." = "✓ 有效的播放清單 — 將依序播放。";
"✓ Valid track — single song." = "✓ 有效的單曲 — 將播放單首歌曲。";
"✓ Valid album — will play in order." = "✓ 有效的專輯 — 將依序播放。";
"⚠️ Could not parse a Spotify link." = "⚠️ 無法解析 Spotify 連結。";
"⚠️ Could not parse a Spotify playlist link." = "⚠️ 無法解析 Spotify 播放清單連結。";
"Once" = "僅一次";
"Daily" = "每天";
"Weekdays" = "工作日";
"Local Audio" = "本機音訊";
"Spotify Playlist" = "Spotify 播放清單";
"Spotify Playlist · %@" = "Spotify 播放清單 · %@";
"No audio selected" = "未選擇音訊";
"%d tracks" = "%d 個音軌";
"No audio" = "無音訊";
"• Snoozed" = "• 已貪睡";
"Preview Sound" = "試聽鈴聲";
"Edit Alarm" = "編輯鬧鐘";
"Delete Alarm" = "刪除鬧鐘";
"Time to wake up!" = "該起床啦！";
"Snooze 5 min" = "貪睡 5 分鐘";
"Stop" = "停止";
"Music Library" = "音樂庫";
"Import Music" = "匯入音樂";
"No music imported. Click “Import Music” to add .mp3 / .m4a files." = "尚未匯入音樂。點擊「匯入音樂」新增 .mp3 / .m4a 檔案。";
"Import" = "匯入";
"Select an .mp3 or .m4a audio file" = "選擇一個 .mp3 或 .m4a 音訊檔案";
"About Music Alarm" = "關於 Music Alarm";
"Hide Music Alarm" = "隱藏 Music Alarm";
"Quit Music Alarm" = "結束 Music Alarm";
"Local" = "本機";
"Spotify" = "Spotify";
"Playlist" = "播放清單";
"Add Track" = "新增音軌";
"Tracks" = "音軌";
"No tracks yet. Add local files or Spotify links below." = "還沒有音軌。請在下方新增本機檔案或 Spotify 連結。";
"Import & Add" = "匯入並新增";
"Add to Playlist" = "加入播放清單";
"""

ES = """/* Music Alarm - Español (Spanish) */

"Next alarm in %@" = "Próxima alarma en %@";
"No upcoming alarm" = "No hay próximas alarmas";
"No alarms yet" = "Aún no hay alarmas";
"Click “Add Alarm” to create your first alarm." = "Haz clic en « Añadir alarma » para crear tu primera alarma.";
"Add Alarm" = "Añadir alarma";
"System Default" = "Predeterminado del sistema";
"now" = "ahora";
"%dh %dm" = "%dh %dmin";
"%dm %ds" = "%dmin %ds";
"%ds" = "%ds";
"Time" = "Hora";
"Repeat" = "Repetición";
"Alarm Sound" = "Sonido de alarma";
"Sound Source" = "Fuente de sonido";
"No music imported yet. Import a song to use as the alarm sound." = "Aún no hay música importada. Importa una canción para usarla como sonido de alarma.";
"Import Music…" = "Importar música…";
"Cancel" = "Cancelar";
"Save" = "Guardar";
"Paste a Spotify playlist, track or album link" = "Pega un enlace de lista, canción o álbum de Spotify";
"Paste a Spotify playlist link — URL or spotify:playlist:…" = "Pega un enlace de lista de Spotify — URL o spotify:playlist:…";
"✓ Valid playlist — will play in order." = "✓ Lista válida — se reproducirá en orden.";
"✓ Valid track — single song." = "✓ Canción válida — una sola canción.";
"✓ Valid album — will play in order." = "✓ Álbum válido — se reproducirá en orden.";
"⚠️ Could not parse a Spotify link." = "⚠️ No se pudo analizar un enlace de Spotify.";
"⚠️ Could not parse a Spotify playlist link." = "⚠️ No se pudo analizar un enlace de lista de Spotify.";
"Once" = "Una vez";
"Daily" = "Diaria";
"Weekdays" = "Entre semana";
"Local Audio" = "Audio local";
"Spotify Playlist" = "Lista de Spotify";
"Spotify Playlist · %@" = "Lista de Spotify · %@";
"No audio selected" = "Ningún audio seleccionado";
"%d tracks" = "%d pistas";
"No audio" = "Sin audio";
"• Snoozed" = "• Pospuesta";
"Preview Sound" = "Vista previa del sonido";
"Edit Alarm" = "Editar alarma";
"Delete Alarm" = "Eliminar alarma";
"Time to wake up!" = "¡Hora de despertarse!";
"Snooze 5 min" = "Posponer 5 min";
"Stop" = "Detener";
"Music Library" = "Biblioteca de música";
"Import Music" = "Importar música";
"No music imported. Click “Import Music” to add .mp3 / .m4a files." = "No hay música importada. Haz clic en « Importar música » para añadir archivos .mp3 / .m4a.";
"Import" = "Importar";
"Select an .mp3 or .m4a audio file" = "Selecciona un archivo de audio .mp3 o .m4a";
"About Music Alarm" = "Acerca de Music Alarm";
"Hide Music Alarm" = "Ocultar Music Alarm";
"Quit Music Alarm" = "Salir de Music Alarm";
"Local" = "Local";
"Spotify" = "Spotify";
"Playlist" = "Lista";
"Add Track" = "Añadir pista";
"Tracks" = "Pistas";
"No tracks yet. Add local files or Spotify links below." = "Aún no hay pistas. Añade archivos locales o enlaces de Spotify a continuación.";
"Import & Add" = "Importar y añadir";
"Add to Playlist" = "Añadir a la lista";
"""


def verify_bundle(bundle_resources):
    """Verify every L() key in Sources is present in all 7 bundle .lproj files."""
    keys = set()
    src_dir = os.path.join(ROOT, "Sources")
    for root, _, files in os.walk(src_dir):
        for f in files:
            if f.endswith(".swift"):
                with open(os.path.join(root, f), encoding="utf-8") as fh:
                    text = fh.read()
                keys.update(re.findall(r'L\("((?:[^"\\]|\\.)*)"\)', text))
    keys.add("%d tracks")
    langs = ["en", "ar", "zh-Hans", "zh-Hant", "fr", "ru", "es"]
    all_ok = True
    for lang in langs:
        p = os.path.join(bundle_resources, f"{lang}.lproj", "Localizable.strings")
        if not os.path.exists(p):
            print(f"  [{lang}] FILE MISSING: {p}")
            all_ok = False
            continue
        with open(p, encoding="utf-8") as fh:
            content = fh.read()
        missing = sorted(k for k in keys if f'"{k}" =' not in content)
        if missing:
            all_ok = False
            print(f"  [{lang}] MISSING {len(missing)} -> {missing}")
        else:
            print(f"  [{lang}] ALL {len(keys)} keys present OK")
    print("BUNDLE RESULT:", "ALL LANGUAGES OK" if all_ok else "MISSING KEYS FOUND")
    return 0 if all_ok else 1


def main():
    # 1. Remove stray editor artifacts (misfiled copies outside .lproj dirs).
    #    Only when not explicitly verifying the built bundle.
    if "--bundle" in sys.argv:
        bundle_resources = os.path.join(ROOT, "dist", "MusicAlarm.app", "Contents", "Resources")
        if not os.path.isdir(bundle_resources):
            print("ERROR: bundle resources not found:", bundle_resources)
            return 1
        return verify_bundle(bundle_resources)
    strays = [
        os.path.join(LOC, "zh-Hans.l"),
        os.path.join(LOC, "zh-Hant"),
        os.path.join(LOC, "es.lproj", "Localizable.string"),
    ]
    for s in strays:
        if os.path.exists(s):
            os.remove(s)
            print("REMOVED stray:", os.path.relpath(s, ROOT))

    # 2. Write the correct v2.1 content into the proper .lproj files.
    targets = {
        os.path.join(LOC, "zh-Hans.lproj", "Localizable.strings"): ZH_HANS,
        os.path.join(LOC, "zh-Hant.lproj", "Localizable.strings"): ZH_HANT,
        os.path.join(LOC, "es.lproj", "Localizable.strings"): ES,
    }
    for path, content in targets.items():
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        print("WROTE", os.path.relpath(path, ROOT), f"({len(content.encode('utf-8'))} bytes)")

    # 3. Verify: every L("...") key in Sources must exist in all 7 languages.
    keys = set()
    src_dir = os.path.join(ROOT, "Sources")
    for root, _, files in os.walk(src_dir):
        for f in files:
            if f.endswith(".swift"):
                with open(os.path.join(root, f), encoding="utf-8") as fh:
                    text = fh.read()
                keys.update(re.findall(r'L\("((?:[^"\\]|\\.)*)"\)', text))
    keys.add("%d tracks")  # used via String(format:) in Alarm.swift

    langs = ["en", "ar", "zh-Hans", "zh-Hant", "fr", "ru", "es"]
    all_ok = True
    for lang in langs:
        p = os.path.join(LOC, f"{lang}.lproj", "Localizable.strings")
        with open(p, encoding="utf-8") as fh:
            content = fh.read()
        missing = sorted(k for k in keys if f'"{k}" =' not in content)
        if missing:
            all_ok = False
            print(f"  [{lang}] MISSING {len(missing)} -> {missing}")
        else:
            print(f"  [{lang}] ALL {len(keys)} keys present OK")

    print("RESULT:", "ALL LANGUAGES OK" if all_ok else "MISSING KEYS FOUND")
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())