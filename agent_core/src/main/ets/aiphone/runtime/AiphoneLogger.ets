import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'AIPhone';
const MAX_LOG_CHARS = 3000;
const COMPLETE_LOG_CHUNK_CHARS = 1000;

export interface AiLogChunk {
  index: number;
  total: number;
  content: string;
}

function trimForLog(message: string): string {
  if (message.length <= MAX_LOG_CHARS) {
    return message;
  }
  return message.substring(0, MAX_LOG_CHARS) + '...<truncated>';
}

export function aiLogInfo(message: string): void {
  const safe = trimForLog(message);
  hilog.info(DOMAIN, TAG, '%{public}s', safe);
  console.info(safe);
}

export function aiLogError(message: string): void {
  const safe = trimForLog(message);
  hilog.error(DOMAIN, TAG, '%{public}s', safe);
  console.error(safe);
}

export function aiLogChunks(message: string): AiLogChunk[] {
  const total = Math.max(1, Math.ceil(message.length / COMPLETE_LOG_CHUNK_CHARS));
  const chunks: AiLogChunk[] = [];
  for (let index = 0; index < total; index++) {
    chunks.push({
      index: index + 1,
      total: total,
      content: message.substring(index * COMPLETE_LOG_CHUNK_CHARS, (index + 1) * COMPLETE_LOG_CHUNK_CHARS)
    });
  }
  return chunks;
}

export function aiLogInfoComplete(prefix: string, message: string): void {
  const chunks = aiLogChunks(message);
  for (let index = 0; index < chunks.length; index++) {
    const chunk = chunks[index];
    aiLogInfo(
      prefix + ' chunk=' + chunk.index.toString() + '/' + chunk.total.toString() +
      ' content=' + JSON.stringify(chunk.content)
    );
  }
}
