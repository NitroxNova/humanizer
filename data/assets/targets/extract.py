import gzip
import shutil
from pathlib import Path

for p in Path('.').iterdir():
  if p.is_dir():
    for f in p.iterdir():
      if f.suffix == '.gz':
        with gzip.open(f, 'rb') as fin:
          with open(str(f).replace('.gz', ''), 'wb') as fout:
            shutil.copyfileobj(fin, fout)