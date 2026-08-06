import { UI_AGENT_LAB_COMPONENT_CATALOG_JSON } from '@loop/agent-core';

const UI_LAB_DECISION_NOTES_LINE_MAX: number = 2400;
const UI_LAB_DECISION_LIST_MAX: number = 12;
const UI_LAB_DECISION_ID_MAX: number = 120;
const UI_LAB_DECISION_PURPOSE_MAX: number = 96;
const UI_LAB_DECISION_PATH_MAX: number = 240;

type UiLabDecisionJson = Object | string | number | boolean | null | undefined;
type UiLabDecisionRecord = Record<string, UiLabDecisionJson>;

export interface UiAgentLabPlannedComponent {
  id: string;
  component: string;
  purpose: string;
}

export type UiAgentLabOmissionReason =
  'duplicate' | 'irrelevant' | 'raw_or_unreadable' | 'unsupported_component' | 'mobile_space';

export interface UiAgentLabOmittedData {
  path: string;
  reason: UiAgentLabOmissionReason;
}

export interface UiAgentLabDecisionNotes {
  version: number;
  plannedComponents: UiAgentLabPlannedComponent[];
  omittedData: UiAgentLabOmittedData[];
}

export interface UiAgentLabDecisionOutput {
  protocolCandidate: string;
  decisionNotes: UiAgentLabDecisionNotes | null;
}

export class UiAgentLabDecisionNotesState {
  private surfaceId: string = '';
  private notes: UiAgentLabDecisionNotes | null = null;

  update(surfaceId: string, notes: UiAgentLabDecisionNotes | null): void {
    this.surfaceId = surfaceId;
    this.notes = notes;
  }

  clear(): void {
    this.surfaceId = '';
    this.notes = null;
  }

  read(surfaceId: string): UiAgentLabDecisionNotes | null {
    return this.surfaceId === surfaceId ? this.notes : null;
  }
}

function recordOf(value: UiLabDecisionJson): UiLabDecisionRecord | null {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value)) return null;
  return value as UiLabDecisionRecord;
}

function exactKeys(record: UiLabDecisionRecord, keys: string[]): boolean {
  return Object.keys(record).sort().join(',') === keys.slice().sort().join(',');
}

function boundedText(value: UiLabDecisionJson, maxLength: number): string | null {
  if (typeof value !== 'string') return null;
  const text = value.trim();
  return text.length > 0 && text.length <= maxLength ? text : null;
}

function catalogNames(): Set<string> {
  const names: Set<string> = new Set<string>();
  try {
    const entries = JSON.parse(UI_AGENT_LAB_COMPONENT_CATALOG_JSON) as UiLabDecisionJson[];
    for (let index = 0; index < entries.length; index++) {
      const entry = recordOf(entries[index]);
      if (entry !== null && typeof entry['name'] === 'string') names.add(entry['name'] as string);
    }
  } catch (_error) {
  }
  return names;
}

function decodePointerSegment(segment: string): string {
  return segment.split('~1').join('/').split('~0').join('~');
}

function snapshotHasPath(snapshot: UiLabDecisionJson, path: string): boolean {
  if (path.length === 0 || path.charAt(0) !== '/') return false;
  if (path === '/') return true;
  const parts = path.substring(1).split('/');
  let current: UiLabDecisionJson = snapshot;
  for (let index = 0; index < parts.length; index++) {
    const key = decodePointerSegment(parts[index]);
    if (Array.isArray(current)) {
      if (!/^(0|[1-9][0-9]*)$/.test(key)) return false;
      const values = current as UiLabDecisionJson[];
      const itemIndex = Number(key);
      if (itemIndex >= values.length) return false;
      current = values[itemIndex];
      continue;
    }
    const source = recordOf(current);
    if (source === null || Object.keys(source).indexOf(key) < 0) return false;
    current = source[key];
  }
  return true;
}

function protocolLineOf(line: string): string | null {
  try {
    const envelope = recordOf(JSON.parse(line) as Object);
    if (envelope === null || !exactKeys(envelope, ['version', 'updateComponents']) ||
      typeof envelope['version'] !== 'string' || recordOf(envelope['updateComponents']) === null) {
      return null;
    }
    return line;
  } catch (_error) {
    return null;
  }
}

function omissionReason(value: UiLabDecisionJson): UiAgentLabOmissionReason | null {
  if (value === 'duplicate' || value === 'irrelevant' || value === 'raw_or_unreadable' ||
    value === 'unsupported_component' || value === 'mobile_space') {
    return value as UiAgentLabOmissionReason;
  }
  return null;
}

function collectDataPaths(value: UiLabDecisionJson, paths: Set<string>): void {
  if (Array.isArray(value)) {
    const values = value as UiLabDecisionJson[];
    for (let index = 0; index < values.length; index++) collectDataPaths(values[index], paths);
    return;
  }
  const record = recordOf(value);
  if (record === null) return;
  const keys = Object.keys(record);
  for (let index = 0; index < keys.length; index++) {
    const key = keys[index];
    const child = record[key];
    if (key === 'dataPath' && typeof child === 'string') {
      paths.add(child);
    } else {
      collectDataPaths(child, paths);
    }
  }
}

function notesOf(line: string, snapshotJson: string): UiAgentLabDecisionNotes | null {
  if (line.length === 0 || line.length > UI_LAB_DECISION_NOTES_LINE_MAX) return null;
  try {
    const outer = recordOf(JSON.parse(line) as Object);
    if (outer === null || !exactKeys(outer, ['uiDecisionNotes'])) return null;
    const notes = recordOf(outer['uiDecisionNotes']);
    if (notes === null || !exactKeys(notes, ['omittedData', 'plannedComponents', 'version']) ||
      notes['version'] !== 1 || !Array.isArray(notes['plannedComponents']) || !Array.isArray(notes['omittedData'])) {
      return null;
    }
    const plannedValues = notes['plannedComponents'] as UiLabDecisionJson[];
    const omittedValues = notes['omittedData'] as UiLabDecisionJson[];
    if (plannedValues.length > UI_LAB_DECISION_LIST_MAX || omittedValues.length > UI_LAB_DECISION_LIST_MAX) return null;
    const names = catalogNames();
    const planned: UiAgentLabPlannedComponent[] = [];
    const plannedIds: Set<string> = new Set<string>();
    for (let index = 0; index < plannedValues.length; index++) {
      const item = recordOf(plannedValues[index]);
      if (item === null || !exactKeys(item, ['component', 'id', 'purpose'])) return null;
      const id = boundedText(item['id'], UI_LAB_DECISION_ID_MAX);
      const component = boundedText(item['component'], UI_LAB_DECISION_ID_MAX);
      const purpose = boundedText(item['purpose'], UI_LAB_DECISION_PURPOSE_MAX);
      if (id === null || component === null || purpose === null || !names.has(component) || plannedIds.has(id)) return null;
      plannedIds.add(id);
      planned.push({ id, component, purpose });
    }
    const snapshot = JSON.parse(snapshotJson) as UiLabDecisionJson;
    const omitted: UiAgentLabOmittedData[] = [];
    const omittedPaths: Set<string> = new Set<string>();
    for (let index = 0; index < omittedValues.length; index++) {
      const item = recordOf(omittedValues[index]);
      if (item === null || !exactKeys(item, ['path', 'reason'])) return null;
      const path = boundedText(item['path'], UI_LAB_DECISION_PATH_MAX);
      const reason = omissionReason(item['reason']);
      if (path === null || reason === null || omittedPaths.has(path) || !snapshotHasPath(snapshot, path)) return null;
      omittedPaths.add(path);
      omitted.push({ path, reason });
    }
    return { version: 1, plannedComponents: planned, omittedData: omitted };
  } catch (_error) {
    return null;
  }
}

function notesMatchProtocol(notes: UiAgentLabDecisionNotes, protocolLine: string): boolean {
  try {
    const envelope = recordOf(JSON.parse(protocolLine) as Object);
    const update = envelope === null ? null : recordOf(envelope['updateComponents']);
    if (update === null || !Array.isArray(update['components'])) return false;
    const components = update['components'] as UiLabDecisionJson[];
    const byId: Map<string, string> = new Map<string, string>();
    const presentedDataPaths: Set<string> = new Set<string>();
    for (let index = 0; index < components.length; index++) {
      const component = recordOf(components[index]);
      if (component !== null && typeof component['id'] === 'string' && typeof component['component'] === 'string') {
        byId.set(component['id'] as string, component['component'] as string);
      }
      collectDataPaths(components[index], presentedDataPaths);
    }
    for (let index = 0; index < notes.plannedComponents.length; index++) {
      const planned = notes.plannedComponents[index];
      if (byId.get(planned.id) !== planned.component) return false;
    }
    for (let index = 0; index < notes.omittedData.length; index++) {
      if (presentedDataPaths.has(notes.omittedData[index].path)) return false;
    }
    return true;
  } catch (_error) {
    return false;
  }
}

export function parseUiAgentLabDecisionOutput(
  raw: string,
  enabled: boolean,
  snapshotJson: string
): UiAgentLabDecisionOutput {
  if (!enabled) return { protocolCandidate: raw, decisionNotes: null };
  const trimmed = raw.trim();
  const sourceLines = trimmed.split(/\r?\n/);
  const lines: string[] = [];
  for (let index = 0; index < sourceLines.length; index++) {
    const line = sourceLines[index].trim();
    if (line.length > 0) lines.push(line);
  }
  if (lines.length === 1) return { protocolCandidate: lines[0], decisionNotes: null };
  if (lines.length === 0) return { protocolCandidate: raw, decisionNotes: null };
  const protocolCandidate = protocolLineOf(lines[lines.length - 1]);
  if (protocolCandidate === null) return { protocolCandidate: raw, decisionNotes: null };
  const parsedNotes = lines.length === 2 ? notesOf(lines[0], snapshotJson) : null;
  const decisionNotes = parsedNotes !== null && notesMatchProtocol(parsedNotes, protocolCandidate) ? parsedNotes : null;
  return { protocolCandidate, decisionNotes };
}
