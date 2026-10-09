# Wrap a raw tool dump (out/<slug>.raw + out/<slug>.spec, written by lib.lua export) into a macro template.
# usage: python macro.py <slug> <destination.setting> [more destinations]
import os
import sys

here = os.path.dirname(os.path.abspath(__file__))
slug = sys.argv[1]
raw = open(os.path.join(here, 'out', slug + '.raw'), encoding='utf-8').read()
spec = [l.rstrip('\n').split('\t') for l in open(os.path.join(here, 'out', slug + '.spec'), encoding='utf-8') if l.strip()]

key = 'Tools = ordered() {'
start = raw.index(key) + len(key)
depth, i, in_str = 1, start, False
while depth:
    c = raw[i]
    if in_str:
        if c == '\\':
            i += 1
        elif c == '"':
            in_str = False
    elif c == '"':
        in_str = True
    elif c == '{':
        depth += 1
    elif c == '}':
        depth -= 1
    i += 1
inner = '\n'.join('\t\t' + l for l in raw[start:i - 1].strip('\n').split('\n'))

name, mains, outs, ctls = 'Macro', [], [], []
for row in spec:
    kind = row[0]
    if kind == 'NAME':
        name = row[1]
    elif kind == 'MAIN':
        mains.append(row[1:3])
    elif kind == 'OUT':
        outs.append(row[1:3])
    elif kind == 'CTL':
        ctls.append(row[1:] + [''] * (6 - len(row)))

lines = []
for n, (op, src) in enumerate(mains, 1):
    lines.append('\t\t\t\tMainInput%d = InstanceInput { SourceOp = "%s", Source = "%s" },' % (n, op, src))
for n, (op, src, label, group, page) in enumerate(ctls, 1):
    parts = ['SourceOp = "%s"' % op, 'Source = "%s"' % src]
    if label:
        parts.append('Name = "%s"' % label)
    if group:
        parts.append('ControlGroup = %s' % group)
    if page:
        parts.append('Page = "%s"' % page)
    lines.append('\t\t\t\tInput%d = InstanceInput { %s },' % (n, ', '.join(parts)))
outputs = '\n'.join('\t\t\t\tMainOutput%d = InstanceOutput { SourceOp = "%s", Source = "%s" }' % (n, op, src)
                    for n, (op, src) in enumerate(outs, 1))

out = '''{
	Tools = ordered() {
		%s = MacroOperator {
			CtrlWZoom = false,
			Inputs = ordered() {
%s
			},
			Outputs = {
%s
			},
			ViewInfo = GroupInfo { Pos = { 0, 0 } },
			Tools = ordered() {
%s
			}
		}
	},
	ActiveTool = "%s"
}
''' % (name, '\n'.join(lines), outputs, inner, name)

for dest in sys.argv[2:]:
    open(dest, 'w', encoding='utf-8', newline='\n').write(out)
    print('wrote', dest, len(out))
