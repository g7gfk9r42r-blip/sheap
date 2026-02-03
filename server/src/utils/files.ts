import { dirname } from 'path';
import { ensureDirSync } from 'fs-extra';
import { writeFileSync } from 'fs';

export function saveJsonFile(filePath: string, data: unknown) {
  ensureDirSync(dirname(filePath));
  writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf-8');
}
