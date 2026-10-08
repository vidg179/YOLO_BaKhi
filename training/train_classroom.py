"""Run from project root with Python 3.11/3.12 and ultralytics installed.
No images are bundled. Validation runs before importing training dependencies.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

NAMES = ['cell phone', 'laptop', 'desk', 'chair', 'bottle', 'whiteboard', 'blackboard', 'projector', 'tv', 'book', 'backpack', 'mouse', 'keyboard']
ROOT = Path(__file__).resolve().parent

def validate(dataset):
    counts = {split: [0] * len(NAMES) for split in ('train', 'val', 'test')}
    hashes = {}
    for split in counts:
        images = sorted(p for p in (dataset / 'images' / split).glob('*')
                        if p.suffix.lower() in ('.jpg', '.jpeg', '.png'))
        if not images:
            raise ValueError(f'{split}: chưa có ảnh trong {dataset / "images" / split}')
        for image in images:
            digest = hashlib.sha256(image.read_bytes()).hexdigest()
            if digest in hashes and hashes[digest] != split:
                raise ValueError(f'Ảnh trùng giữa các tập: {image}')
            hashes[digest] = split
            label = dataset / 'labels' / split / (image.stem + '.txt')
            if not label.exists():
                raise ValueError(f'Thiếu nhãn: {label}; ảnh nền cần file txt rỗng')
            for line_no, line in enumerate(label.read_text(encoding='utf-8').splitlines(), 1):
                if not line.strip():
                    continue
                parts = line.split()
                if len(parts) != 5:
                    raise ValueError(f'{label}:{line_no}: cần class x_center y_center width height')
                c = int(parts[0])
                x, y, w, h = map(float, parts[1:])
                if not (0 <= c < len(NAMES) and all(math.isfinite(v) for v in (x,y,w,h))
                        and 0 < w <= 1 and 0 < h <= 1
                        and x-w/2 >= -1e-6 and y-h/2 >= -1e-6
                        and x+w/2 <= 1+1e-6 and y+h/2 <= 1+1e-6):
                    raise ValueError(f'{label}:{line_no}: class hoặc tọa độ không hợp lệ')
                counts[split][c] += 1
        missing = [NAMES[i] for i, count in enumerate(counts[split]) if count == 0]
        if missing:
            raise ValueError(f'{split}: chưa có nhãn cho {missing}')
    print(json.dumps(counts, indent=2))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check-only', action='store_true')
    parser.add_argument('--epochs', type=int, default=80)
    parser.add_argument('--device', default='cpu')
    args = parser.parse_args()
    dataset = ROOT / 'datasets' / 'classroom'
    validate(dataset)
    if args.check_only:
        return
    from ultralytics import YOLO
    # Resolve the dataset absolutely; Ultralytics may have a different datasets_dir.
    config = ROOT / 'classroom.resolved.yaml'
    config.write_text('path: ' + dataset.as_posix() + '\ntrain: images/train\nval: images/val\ntest: images/test\nnames:\n'
                      + ''.join(f'  {i}: {name}\n' for i, name in enumerate(NAMES)), encoding='utf-8')
    model = YOLO('yolov8n.pt')
    result = model.train(data=str(config), epochs=args.epochs, imgsz=640,
                        device=args.device, batch=8, workers=0,
                        project=str(ROOT / 'runs'), name='classroom', seed=42)
    best = YOLO(str(Path(result.save_dir) / 'weights' / 'best.pt'))
    best.val(data=str(config), split='test', device=args.device)
    exported = best.export(format='tflite', imgsz=640, int8=False, half=False, nms=False)
    # Keep the working app model untouched until real-device acceptance testing.
    output = ROOT / 'export'; output.mkdir(exist_ok=True)
    (output / 'labels.txt').write_text('\n'.join(best.names[i] for i in range(len(best.names))) + '\n', encoding='utf-8')
    (output / 'config.json').write_text(json.dumps({'coordinate_space': 'normalized'}), encoding='utf-8')
    print(f'Exported: {exported}; labels/config: {output}. Chọn bản float32.tflite.')

if __name__ == '__main__':
    import sys
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
    try:
        main()
    except ValueError as error:
        print(f'Dữ liệu chưa sẵn sàng: {error}', file=sys.stderr)
        raise SystemExit(2)
