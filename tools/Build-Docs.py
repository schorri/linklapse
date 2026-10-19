"""Render offline HTML guides using the Python standard library. Developer tool only."""
from pathlib import Path
import html
import re

root = Path(__file__).resolve().parents[1]


def inline(text):
    text = html.escape(text)
    text = re.sub(r'`([^`]+)`', r'<code>\1</code>', text)
    text = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', text)

    def link(match):
        url = match.group(2)
        if url.endswith('.md'):
            url = url[:-3] + '.html'
        return '<a href="' + url + '">' + match.group(1) + '</a>'

    return re.sub(r'\[([^\]]+)\]\(([^)]+)\)', link, text)


def render(text):
    lines, out, i = text.splitlines(), [], 0
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
            continue
        if line.startswith('```'):
            code, i = [], i + 1
            while i < len(lines) and not lines[i].startswith('```'):
                code.append(lines[i])
                i += 1
            out.append('<pre><code>' + html.escape('\n'.join(code)) + '</code></pre>')
            i += 1
            continue
        if line.startswith('#'):
            level = len(line) - len(line.lstrip('#'))
            heading = line[level:].strip()
            ident = re.sub(r'[^a-z0-9-]', '', heading.lower().replace(' ', '-'))
            out.append(f'<h{level} id="{ident}">' + inline(heading) + f'</h{level}>')
            i += 1
            continue
        if line.startswith('|'):
            rows = []
            while i < len(lines) and lines[i].startswith('|'):
                cells = [x.strip() for x in lines[i].strip('|').split('|')]
                if not all(re.fullmatch(r'[:\- ]+', x) for x in cells):
                    rows.append(cells)
                i += 1
            out.append('<div class="scroll"><table><thead><tr>' + ''.join('<th>' + inline(c) + '</th>' for c in rows[0]) + '</tr></thead><tbody>' + ''.join('<tr>' + ''.join('<td>' + inline(c) + '</td>' for c in row) + '</tr>' for row in rows[1:]) + '</tbody></table></div>')
            continue
        if re.match(r'^(\d+\. |- )', line):
            tag, items = ('ol' if re.match(r'^\d+\.', line) else 'ul'), []
            while i < len(lines) and re.match(r'^(\d+\. |- )', lines[i]):
                items.append('<li>' + inline(re.sub(r'^(\d+\. |- )', '', lines[i])) + '</li>')
                i += 1
            out.append('<' + tag + '>' + ''.join(items) + '</' + tag + '>')
            continue
        if line.startswith('> '):
            out.append('<blockquote>' + inline(line[2:]) + '</blockquote>')
            i += 1
            continue
        paragraph, i = [line], i + 1
        while i < len(lines) and lines[i].strip() and not re.match(r'^(#|```|\||> |\d+\. |- )', lines[i]):
            paragraph.append(lines[i])
            i += 1
        out.append('<p>' + inline(' '.join(paragraph)) + '</p>')
    return '\n'.join(out)


css = '''body{margin:0;background:#f3f6fa;color:#19344d;font:16px/1.65 "Segoe UI",Arial,sans-serif}main{max-width:950px;margin:35px auto;padding:35px 45px;background:white;border:1px solid #e2eaf2;border-radius:14px}h1,h2{line-height:1.25;letter-spacing:-.5px}h1{font-size:32px}h2{font-size:23px;margin-top:35px;padding-top:20px;border-top:1px solid #e2eaf2}a{color:#087e75}nav{display:flex;gap:20px;flex-wrap:wrap;padding-bottom:20px;border-bottom:1px solid #e2eaf2;font-size:14px}.scroll{overflow:auto}table{border-collapse:collapse;font-size:14px;width:100%}th,td{padding:9px 12px;border:1px solid #e2eaf2;text-align:left}th{background:#f3f7fb}code{font:14px Consolas,monospace;background:#f0f4f8;padding:2px 4px}pre{background:#f0f4f8;overflow:auto;padding:16px;border-radius:8px}li{margin:7px 0}blockquote{border-left:3px solid #139f8e;padding:12px 18px;margin:20px 0;background:#f2f8f7}@media(max-width:650px){main{margin:0;padding:22px 17px;border:0;border-radius:0}h1{font-size:27px}}@media print{body{background:white;font-size:11pt}main{margin:0;padding:0;border:0}nav{display:none}h2{break-after:avoid}}'''
for name in ['guide', 'guide.de', 'configuration', 'measurement-method', 'validation']:
    source = root / 'docs' / f'{name}.md'
    lang = 'de' if name.endswith('.de') else 'en'
    nav = '<nav><strong>LinkLapse</strong><a href="guide.html">English guide</a><a href="guide.de.html">Deutsche Anleitung</a><a href="configuration.html">Settings</a></nav>'
    doc = '<!doctype html><html lang="' + lang + '"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>LinkLapse Guide</title><style>' + css + '</style></head><body><main>' + nav + render(source.read_text(encoding='utf-8-sig')) + '</main></body></html>'
    source.with_suffix('.html').write_text(doc, encoding='utf-8')
print('Rendered five offline guides.')
