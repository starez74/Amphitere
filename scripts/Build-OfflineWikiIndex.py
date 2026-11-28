#!/usr/bin/env python3
"""Offline NetHackWiki XML -> SQLite FTS4 text index; Python standard library only.

Wiki text is *not* a MediaWiki rendering. Templates and complex markup are
imperfectly removed. Treat extracted passages as reference material requiring
version checks; never treat them as authoritative instructions.
"""
import argparse
import gzip
import html
import os
import re
import sqlite3
import sys
import urllib.parse
import xml.etree.ElementTree as ET
from pathlib import Path

MAX_TEXT = 16000
TITLE_EXCLUDE = ("Source:", "File:", "Image:", "Template:", "Category:", "NetHackWiki:",
                 "User:", "Talk:", "MediaWiki:", "Help:")
LINK = re.compile(r"\\[\\[(?:[^]\\n]*?\\|)?([^]\\n]+?)\\]\\]")
EXTERNAL = re.compile(r"\\[(?:https?://)[^\\s\\]]+\\s+([^\\]]+)\\]")
TEMPLATE = re.compile(r"\\{\\{[^{}]*\\}\\}", re.S)
TAG = re.compile(r"<[^>]*>", re.S)
SPACE = re.compile(r"\\s+")


def plain(wikitext):
    # Remove large sections that do not read sensibly as plain paragraphs.
    s = re.sub(r"<(ref|gallery|syntaxhighlight|source|pre|nowiki)\\b[^>]*>.*?</\\1>",
               " ", wikitext, flags=re.I | re.S)
    s = re.sub(r"<!--.*?-->", " ", s, flags=re.S)
    s = re.sub(r"\\{\\|.*?\\|\\}", " ", s, flags=re.S)
    # Repeatedly discard nested template constructs; preserve surrounding prose.
    for _ in range(12):
        result = TEMPLATE.sub(" ", s)
        if result == s:
            break
        s = result
    s = re.sub(r"^\\s*\\|.*$", " ", s, flags=re.M)
    s = LINK.sub(lambda m: m.group(1), s)
    s = EXTERNAL.sub(lambda m: m.group(1), s)
    s = re.sub(r"\\[https?://[^]\\n]*\\]", " ", s)
    s = TAG.sub(" ", s)
    s = re.sub(r"'{2,5}", "", s)
    s = re.sub(r"={2,}\\s*(.*?)\\s*={2,}", r". \\1. ", s)
    return SPACE.sub(" ", html.unescape(s)).strip()[:MAX_TEXT]


def index(source: Path, output: Path):
    output.parent.mkdir(parents=True, exist_ok=True)
    tmp = output.with_suffix(".partial.sqlite")
    if tmp.exists():
        tmp.unlink()
    db = sqlite3.connect(str(tmp))
    try:
        db.execute("PRAGMA journal_mode=DELETE")
        db.execute("PRAGMA synchronous=FULL")
        db.execute("CREATE VIRTUAL TABLE wiki_fts USING fts4(title, body, url, tokenize=unicode61)")
        db.execute("CREATE TABLE info(key TEXT PRIMARY KEY, value TEXT NOT NULL)")
        db.execute("INSERT INTO info VALUES('source','https://nethackwiki.com/wiki/NetHackWiki:Download')")
        db.execute("INSERT INTO info VALUES('license','https://nethackwiki.com/wiki/NetHackWiki:Copyrights')")
        db.execute("INSERT INTO info VALUES('format','wiki-wikitext-excerpt-v1')")
        pagecount = 0
        textcount = 0
        opener = gzip.open if str(source).endswith(".gz") else open
        with opener(source, "rb") as f:
            stream = ET.iterparse(f, events=("start", "end"))
            _, root = next(stream)
            for event, elem in stream:
                if event != "end" or elem.tag.rsplit("}", 1)[-1] != "page":
                    continue
                ns = elem.findtext("./{*}ns")
                title = elem.findtext("./{*}title") or ""
                rev = elem.find("./{*}revision/{*}text")
                if ns == "0" and title and rev is not None and not title.startswith(TITLE_EXCLUDE):
                    raw = rev.text or ""
                    if len(raw) >= 120:
                        body = plain(raw)
                        if len(body) >= 100:
                            url = "https://nethackwiki.com/wiki/" + urllib.parse.quote(
                                title.replace(" ", "_"), safe="()/':")
                            db.execute("INSERT INTO wiki_fts(title,body,url) VALUES(?,?,?)",
                                       (title, body, url))
                            textcount += 1
                            if textcount % 500 == 0:
                                db.commit()
                pagecount += 1
                elem.clear()
                root.clear()
        db.execute("INSERT INTO info VALUES('indexed_pages',?)", (str(textcount),))
        db.commit()
        integrity = db.execute("PRAGMA integrity_check").fetchone()[0]
        if integrity != "ok":
            raise RuntimeError("SQLite integrity check failed: " + str(integrity))
        db.close()
        db = None
        os.replace(tmp, output)
        print(f"Indexed {textcount} articles from {pagecount} wiki pages")
        print(f"SQLite FTS4 index: {output} ({output.stat().st_size / 1048576:.1f} MiB)")
        print("Warning: raw wiki-to-text extraction is heuristic; verify version-specific facts.")
    finally:
        if db is not None:
            db.close()
        if tmp.exists():
            tmp.unlink()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path, help="nethackwiki_current.xml.gz")
    parser.add_argument("output", type=Path, help="wiki-index.sqlite")
    args = parser.parse_args()
    if not args.input.is_file():
        sys.exit("Dump not found: " + str(args.input))
    index(args.input, args.output)
