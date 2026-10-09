# wrap the raw tool dump into a MacroOperator with published controls
import sys
raw = open('vraw.setting', encoding='utf-8').read()
key = 'Tools = ordered() {'
start = raw.index(key) + len(key)
depth, i, in_str = 1, start, False
while depth:
    c = raw[i]
    if in_str:
        if c == '\\': i += 1
        elif c == '"': in_str = False
    elif c == '"': in_str = True
    elif c == '{': depth += 1
    elif c == '}': depth -= 1
    i += 1
inner = raw[start:i - 1].strip('\n')
inner = '\n'.join('\t\t' + l for l in inner.split('\n'))

def inp(n, op, src, name=None, **kw):
    parts = ['SourceOp = "%s"' % op, 'Source = "%s"' % src]
    if name: parts.append('Name = "%s"' % name)
    for k, v in kw.items():
        parts.append('%s = %s' % (k, ('"%s"' % v) if isinstance(v, str) else v))
    return '\t\t\t\tInput%d = InstanceInput { %s },' % (n, ', '.join(parts))

rows = [
    ('TitleText', 'StyledText', 'Text', {}),
    ('TitleText', 'Font', 'Font', {'ControlGroup': 2}),
    ('TitleText', 'Style', 'Style', {'ControlGroup': 2}),
    ('ComicCtrl', 'TextSize', 'Text Size', {}),
    ('TitleText', 'Red1', 'Text Color', {'ControlGroup': 3}),
    ('TitleText', 'Green1', None, {'ControlGroup': 3}),
    ('TitleText', 'Blue1', None, {'ControlGroup': 3}),
    ('BoxText', 'ExtendHorizontal1', 'Box Padding X', {}),
    ('BoxText', 'ExtendVertical1', 'Box Padding Y', {}),
    ('BoxText', 'Red1', 'Box Color', {'ControlGroup': 4}),
    ('BoxText', 'Green1', None, {'ControlGroup': 4}),
    ('BoxText', 'Blue1', None, {'ControlGroup': 4}),
    ('Backdrop', 'TopLeftRed', 'Background Color', {'ControlGroup': 5}),
    ('Backdrop', 'TopLeftGreen', None, {'ControlGroup': 5}),
    ('Backdrop', 'TopLeftBlue', None, {'ControlGroup': 5}),
    ('ComicCtrl', 'PageCount', 'Page Count', {}),
    ('PageInk', 'NumberIn4', 'Halftone', {}),
    ('ComicCtrl', 'MaxZoom', 'Start Zoom', {}),
    ('ComicCtrl', 'PivotX', 'Zoom Pivot X', {}),
    ('ComicCtrl', 'PivotY', 'Zoom Pivot Y', {}),
]
inputs = '\n'.join(inp(i + 1, op, src, name, **kw) for i, (op, src, name, kw) in enumerate(rows))

out = '''{
	Tools = ordered() {
		ComicIntroVideo = MacroOperator {
			CtrlWZoom = false,
			Inputs = ordered() {
				MainInput1 = InstanceInput { SourceOp = "TileSize", Source = "Input" },
%s
			},
			Outputs = {
				MainOutput1 = InstanceOutput { SourceOp = "FinishGlow", Source = "Output" }
			},
			ViewInfo = GroupInfo { Pos = { 0, 0 } },
			Tools = ordered() {
%s
			}
		}
	},
	ActiveTool = "ComicIntroVideo"
}
''' % (inputs, inner.replace('\t\t', '\t\t\t\t', 1) if False else '\n'.join('\t\t' + l for l in inner.split('\n')))
for dest in sys.argv[1:]:
    open(dest, 'w', encoding='utf-8', newline='\n').write(out)
    print('wrote', dest, len(out))
