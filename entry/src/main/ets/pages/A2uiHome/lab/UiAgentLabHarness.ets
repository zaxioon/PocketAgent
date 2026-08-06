import {
  ActionOffer,
  A2uiAction,
  A2uiComponentCatalogSchema,
  A2uiAgentRunner,
  A2uiComponent,
  A2uiSurfaceState,
  CreateUiTaskPayload,
  DataResult,
  LlmProvider,
  LocalModelSettings,
  OpenAiA2uiModel,
  OpenAiCompatibleModel,
  UI_AGENT_LAB_COMPONENT_CATALOG_JSON,
  UiLayoutPlanner,
  UiRenderResult,
  UiTaskRenderer,
  UserInputPayload,
  aiLogInfo,
  callStructuredToolForUiLab,
  mergeA2uiLayoutWithStatus,
  toolDefinitionForToolId
} from '@loop/agent-core';
import { MultiAgentCanaryRuntime, MultiAgentCanaryOptions } from '../agent/MultiAgentCanaryRuntime';
import { SystemUriOpener } from '../agent/AiphoneRegisteredActionExecutor';
import { HtmlHomeAction, HtmlHomeBlock, HtmlHomeDocument } from '../html/HtmlHomeTypes';

const UI_LAB_LAYOUT_TIMEOUT_MS: number = 60000;
const UI_LAB_SNAPSHOT_LIMIT: number = 12000;
const UI_LAB_LAYOUT_PROMPT_LIMIT: number = 24000;
const UI_LAB_CATALOG_SCHEMA: A2uiComponentCatalogSchema | null =
  A2uiComponentCatalogSchema.parse(UI_AGENT_LAB_COMPONENT_CATALOG_JSON);

type UiLabJsonValue = Object | string | number | boolean | null | undefined;
export type UiLabRecord = Record<string, UiLabJsonValue>;

export interface UiLabFact {
  label: string;
  value: string;
}

export interface UiLabResultSnapshot {
  dataTaskId: string;
  toolId: string;
  outputSchema: string;
  status: string;
  warnings: string[];
  facts: UiLabFact[];
  data: Object;
}

export interface UiLabSummary {
  text: string;
  toolName: string;
  dataLabel: string;
  count: number;
}

export interface UiLabSnapshot {
  summary: UiLabSummary;
  results: UiLabResultSnapshot[];
}

interface UiLabUpdateComponents {
  surfaceId: string;
  components: A2uiComponent[];
}

interface UiLabEnvelope {
  updateComponents?: UiLabUpdateComponents;
}

interface UiLabCreateSurface {
  surfaceId: string;
  root: string;
  title: string;
  intent: string;
  status: string;
  sendDataModel: boolean;
}

interface UiLabCreateEnvelope {
  version: string;
  createSurface: UiLabCreateSurface;
}

interface UiLabComponentsEnvelope {
  version: string;
  updateComponents: UiLabUpdateComponents;
}

interface UiLabUpdateDataModel {
  surfaceId: string;
  path: string;
  value: UiLabJsonValue;
}

interface UiLabDataEnvelope {
  version: string;
  updateDataModel: UiLabUpdateDataModel;
}

interface UiLabOmittedData {
  omittedDueToPromptBudget: boolean;
}

interface UiLabPromptOffer {
  offerId: string;
  label: string;
  variant: string;
}

export interface UiAgentLabSurfaceEvent {
  turnId: string;
  surface: A2uiSurfaceState;
}

export interface UiAgentLabSubmitOutcome {
  ok: boolean;
  status: string;
  message: string;
}

export type UiAgentLabSurfaceListener = (event: UiAgentLabSurfaceEvent) => void;

class RejectUiLabUriOpener implements SystemUriOpener {
  async open(_uri: string): Promise<boolean> {
    return false;
  }
}

function cloneSurface(surface: A2uiSurfaceState): A2uiSurfaceState {
  return JSON.parse(JSON.stringify(surface)) as A2uiSurfaceState;
}

function currentLocalDate(): string {
  const now = new Date();
  const month = (now.getMonth() + 1).toString().padStart(2, '0');
  const day = now.getDate().toString().padStart(2, '0');
  return now.getFullYear().toString() + '-' + month + '-' + day;
}

function recordOf(value: UiLabJsonValue): UiLabRecord | null {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as UiLabRecord;
}

function scalarText(value: UiLabJsonValue): string {
  if (typeof value === 'string') return value.substring(0, 240);
  if (typeof value === 'number' || typeof value === 'boolean') return value.toString();
  return '';
}

function factsOf(data: Object): UiLabFact[] {
  const source = recordOf(data);
  const facts: UiLabFact[] = [];
  if (source === null) return facts;
  const keys = Object.keys(source);
  for (let index = 0; index < keys.length && facts.length < 16; index++) {
    const value = scalarText(source[keys[index]]);
    if (value.length > 0) facts.push({ label: keys[index], value });
  }
  return facts;
}

function uiLabVisibleData(data: Object): Object {
  const source = recordOf(data);
  if (source === null) return data;
  const providerData = source['providerData'];
  if (providerData === null || providerData === undefined || typeof providerData !== 'object') return data;
  const visible = {} as UiLabRecord;
  visible['providerData'] = providerData;
  const providerDataMeta = source['providerDataMeta'];
  if (providerDataMeta !== null && providerDataMeta !== undefined && typeof providerDataMeta === 'object') {
    visible['providerDataMeta'] = providerDataMeta;
  }
  return visible as Object;
}

function sampled(value: UiLabJsonValue, depth: number = 0): UiLabJsonValue {
  if (typeof value === 'string') return value.substring(0, 1200);
  if (value === null || value === undefined || typeof value === 'number' || typeof value === 'boolean') return value;
  if (depth >= 7) return '[bounded]';
  if (Array.isArray(value)) {
    const source = value as UiLabJsonValue[];
    const result: UiLabJsonValue[] = [];
    for (let index = 0; index < source.length && index < 8; index++) result.push(sampled(source[index], depth + 1));
    return result as Object;
  }
  const source = value as UiLabRecord;
  const result: UiLabRecord = {};
  const keys = Object.keys(source);
  for (let index = 0; index < keys.length && index < 40; index++) {
    result[keys[index]] = sampled(source[keys[index]], depth + 1);
  }
  return result as Object;
}

function tightlySampled(value: UiLabJsonValue, depth: number = 0): UiLabJsonValue {
  if (typeof value === 'string') return value.substring(0, 320);
  if (value === null || value === undefined || typeof value === 'number' || typeof value === 'boolean') return value;
  if (depth >= 7) return '[bounded]';
  if (Array.isArray(value)) {
    const source = value as UiLabJsonValue[];
    const result: UiLabJsonValue[] = [];
    for (let index = 0; index < source.length && index < 3; index++) {
      result.push(tightlySampled(source[index], depth + 1));
    }
    return result as Object;
  }
  const source = value as UiLabRecord;
  const result: UiLabRecord = {};
  const keys = Object.keys(source);
  for (let index = 0; index < keys.length && index < 20; index++) {
    result[keys[index]] = tightlySampled(source[keys[index]], depth + 1);
  }
  return result as Object;
}

export function buildUiAgentLabSnapshot(task: CreateUiTaskPayload, data: DataResult[]): UiLabSnapshot {
  const results: UiLabResultSnapshot[] = [];
  for (let index = 0; index < data.length; index++) {
    const visibleData = uiLabVisibleData(data[index].data);
    results.push({
      dataTaskId: index < task.dataTaskIds.length ? task.dataTaskIds[index] : 'data-' + index.toString(),
      toolId: data[index].toolId,
      outputSchema: data[index].outputSchema,
      status: data[index].status,
      warnings: data[index].warnings.slice(0, 8),
      facts: factsOf(visibleData),
      data: sampled(visibleData) as Object
    });
  }
  let snapshot: UiLabSnapshot = {
    summary: {
      text: '已获取 ' + data.length.toString() + ' 组真实数据。',
      toolName: data.length === 1 ? data[0].toolId : 'multi-agent',
      dataLabel: 'uiLabResultSets',
      count: data.length
    },
    results
  };
  if (JSON.stringify(snapshot).length > UI_LAB_SNAPSHOT_LIMIT) {
    snapshot = {
      summary: snapshot.summary,
      results: results.map((item: UiLabResultSnapshot, index: number): UiLabResultSnapshot => {
        const visibleData = index < data.length ? uiLabVisibleData(data[index].data) : item.data;
        return {
          dataTaskId: item.dataTaskId,
          toolId: item.toolId,
          outputSchema: item.outputSchema,
          status: item.status,
          warnings: item.warnings,
          facts: item.facts,
          data: tightlySampled(visibleData) as Object
        };
      })
    };
  }
  if (JSON.stringify(snapshot).length > UI_LAB_SNAPSHOT_LIMIT) {
    snapshot = {
      summary: snapshot.summary,
      results: results.map((item: UiLabResultSnapshot): UiLabResultSnapshot => {
        const omitted: UiLabOmittedData = { omittedDueToPromptBudget: true };
        return {
          dataTaskId: item.dataTaskId,
          toolId: item.toolId,
          outputSchema: item.outputSchema,
          status: item.status,
          warnings: item.warnings,
          facts: item.facts,
          data: omitted
        };
      })
    };
  }
  return snapshot;
}

function pointerToken(value: string): string {
  return value.split('~').join('~0').split('/').join('~1');
}

function decodePointerToken(value: string): string | null {
  let decoded = '';
  for (let index = 0; index < value.length; index++) {
    const current = value.charAt(index);
    if (current !== '~') {
      decoded += current;
      continue;
    }
    if (index + 1 >= value.length) return null;
    const escaped = value.charAt(index + 1);
    if (escaped === '0') decoded += '~';
    else if (escaped === '1') decoded += '/';
    else return null;
    index++;
  }
  return decoded;
}

function pointerParts(path: string): string[] | null {
  if (path.length === 0 || path.charAt(0) !== '/' || path === '/') return null;
  const encoded = path.substring(1).split('/');
  const decoded: string[] = [];
  for (let index = 0; index < encoded.length; index++) {
    const part = decodePointerToken(encoded[index]);
    if (part === null) return null;
    decoded.push(part);
  }
  return decoded;
}

function valueAtPointer(root: UiLabJsonValue, path: string): UiLabJsonValue {
  if (path === '/') return root;
  const parts = pointerParts(path);
  if (parts === null) return undefined;
  let current = root;
  for (let index = 0; index < parts.length; index++) {
    const part = parts[index];
    if (Array.isArray(current)) {
      if (!/^(0|[1-9][0-9]*)$/.test(part)) return undefined;
      const values = current as UiLabJsonValue[];
      const itemIndex = Number(part);
      if (itemIndex >= values.length) return undefined;
      current = values[itemIndex];
      continue;
    }
    const source = recordOf(current);
    if (source === null || Object.keys(source).indexOf(part) < 0) return undefined;
    current = source[part];
  }
  return current;
}

function replaceArrayAtPointer(root: UiLabJsonValue, path: string, value: UiLabJsonValue[]): boolean {
  const parts = pointerParts(path);
  if (parts === null) return false;
  let current = root;
  for (let index = 0; index < parts.length - 1; index++) {
    const part = parts[index];
    if (Array.isArray(current)) {
      if (!/^(0|[1-9][0-9]*)$/.test(part)) return false;
      const values = current as UiLabJsonValue[];
      const itemIndex = Number(part);
      if (itemIndex >= values.length) return false;
      current = values[itemIndex];
      continue;
    }
    const source = recordOf(current);
    if (source === null || Object.keys(source).indexOf(part) < 0) return false;
    current = source[part];
  }
  const last = parts[parts.length - 1];
  let cloned: UiLabJsonValue[];
  try {
    cloned = JSON.parse(JSON.stringify(value)) as UiLabJsonValue[];
  } catch (_error) {
    return false;
  }
  if (Array.isArray(current)) {
    if (!/^(0|[1-9][0-9]*)$/.test(last)) return false;
    const values = current as UiLabJsonValue[];
    const itemIndex = Number(last);
    if (itemIndex >= values.length || !Array.isArray(values[itemIndex])) return false;
    values[itemIndex] = cloned as Object;
    return true;
  }
  const source = recordOf(current);
  if (source === null || Object.keys(source).indexOf(last) < 0 || !Array.isArray(source[last])) return false;
  source[last] = cloned as Object;
  return true;
}

function arrayCandidatePathsOfMergedLayout(jsonl: string, surfaceId: string): string[] {
  const paths: string[] = [];
  const lines = jsonl.trim().split(/\r?\n/);
  for (let lineIndex = 0; lineIndex < lines.length; lineIndex++) {
    let envelope: UiLabRecord;
    try {
      envelope = JSON.parse(lines[lineIndex]) as UiLabRecord;
    } catch (_error) {
      continue;
    }
    const update = recordOf(envelope['updateComponents']);
    if (update === null || update['surfaceId'] !== surfaceId || !Array.isArray(update['components'])) continue;
    const components = update['components'] as UiLabJsonValue[];
    for (let componentIndex = 0; componentIndex < components.length; componentIndex++) {
      const component = recordOf(components[componentIndex]);
      if (component === null) continue;
      if (UI_LAB_CATALOG_SCHEMA !== null && typeof component['component'] === 'string') {
        const bindingPaths = UI_LAB_CATALOG_SCHEMA.bindingPaths(component['component'] as string, component as Object);
        for (let pathIndex = 0; pathIndex < bindingPaths.length; pathIndex++) {
          if (paths.indexOf(bindingPaths[pathIndex]) < 0) paths.push(bindingPaths[pathIndex]);
        }
      }
      if (typeof component['dataPath'] === 'string') {
        const dataPath = component['dataPath'] as string;
        if (paths.indexOf(dataPath) < 0) paths.push(dataPath);
      }
      if (component['component'] === 'List') {
        const children = recordOf(component['children']);
        if (children !== null && typeof children['path'] === 'string') {
          const listPath = children['path'] as string;
          if (paths.indexOf(listPath) < 0) paths.push(listPath);
        }
      }
    }
  }
  return paths;
}

function collectSampledArrayPaths(value: UiLabJsonValue, path: string, output: string[]): void {
  if (value === null || value === undefined) return;
  if (Array.isArray(value)) {
    if (output.indexOf(path) < 0) output.push(path);
    return;
  }
  const source = recordOf(value);
  if (source === null) return;
  const keys = Object.keys(source);
  for (let index = 0; index < keys.length; index++) {
    collectSampledArrayPaths(source[keys[index]], path + '/' + pointerToken(keys[index]), output);
  }
}

function fullUiAgentLabSource(snapshot: UiLabSnapshot, data: DataResult[]): UiLabSnapshot {
  const results: UiLabResultSnapshot[] = [];
  for (let index = 0; index < snapshot.results.length; index++) {
    const sampledResult = snapshot.results[index];
    results.push({
      dataTaskId: sampledResult.dataTaskId,
      toolId: sampledResult.toolId,
      outputSchema: sampledResult.outputSchema,
      status: sampledResult.status,
      warnings: sampledResult.warnings,
      facts: sampledResult.facts,
      data: index < data.length ? uiLabVisibleData(data[index].data) : sampledResult.data
    });
  }
  return { summary: snapshot.summary, results };
}

export function hydrateUiAgentLabSnapshotForMergedLayout(
  snapshot: UiLabSnapshot,
  data: DataResult[],
  mergedJsonl: string,
  surfaceId: string
): UiLabSnapshot {
  const hydrated = JSON.parse(JSON.stringify(snapshot)) as UiLabSnapshot;
  const fullSource = fullUiAgentLabSource(snapshot, data);
  const componentPaths = arrayCandidatePathsOfMergedLayout(mergedJsonl, surfaceId);
  const arrayPaths: string[] = [];
  for (let index = 0; index < componentPaths.length; index++) {
    const sampledValue = valueAtPointer(hydrated as Object, componentPaths[index]);
    collectSampledArrayPaths(sampledValue, componentPaths[index], arrayPaths);
  }
  for (let index = 0; index < arrayPaths.length; index++) {
    const fullValue = valueAtPointer(fullSource as Object, arrayPaths[index]);
    const sampledValue = valueAtPointer(hydrated as Object, arrayPaths[index]);
    if (!Array.isArray(fullValue) || !Array.isArray(sampledValue)) continue;
    replaceArrayAtPointer(hydrated as Object, arrayPaths[index], fullValue as UiLabJsonValue[]);
  }
  return hydrated;
}

export function hydrateUiAgentLabMergedJsonl(
  mergedJsonl: string,
  surfaceId: string,
  snapshot: UiLabSnapshot,
  data: DataResult[]
): string {
  const hydrated = hydrateUiAgentLabSnapshotForMergedLayout(snapshot, data, mergedJsonl, surfaceId);
  const lines = mergedJsonl.trim().split(/\r?\n/);
  let replaced = false;
  for (let index = 0; index < lines.length; index++) {
    let envelope: UiLabRecord;
    try {
      envelope = JSON.parse(lines[index]) as UiLabRecord;
    } catch (_error) {
      continue;
    }
    const update = recordOf(envelope['updateDataModel']);
    if (update === null || update['surfaceId'] !== surfaceId || typeof update['path'] !== 'string') continue;
    const path = update['path'] as string;
    if (path === '/summary') {
      update['value'] = hydrated.summary as Object;
    } else if (path === '/results') {
      update['value'] = hydrated.results as Object;
    } else if (path === '/') {
      update['value'] = hydrated as Object;
    } else {
      continue;
    }
    lines[index] = JSON.stringify(envelope);
    replaced = true;
  }
  return replaced ? lines.join('\n') + '\n' : mergedJsonl;
}

function envelopeLine(value: Object): string {
  return JSON.stringify(value) + '\n';
}

function surfaceShell(surfaceId: string, status: string, components: A2uiComponent[]): string {
  const createBody: UiLabCreateSurface = {
    surfaceId,
    root: 'root',
    title: 'UI Agent Lab',
    intent: 'ui_lab',
    status,
    sendDataModel: true
  };
  const create: UiLabCreateEnvelope = {
    version: 'v0.9.1',
    createSurface: createBody
  };
  const updateBody: UiLabUpdateComponents = { surfaceId, components };
  const update: UiLabComponentsEnvelope = { version: 'v0.9.1', updateComponents: updateBody };
  return envelopeLine(create) + envelopeLine(update);
}

export function uiAgentLabDataJsonl(surfaceId: string, snapshot: UiLabSnapshot): string {
  const rootUpdate: UiLabUpdateDataModel = { surfaceId, path: '/', value: snapshot as Object };
  const rootEnvelope: UiLabDataEnvelope = { version: 'v0.9.1', updateDataModel: rootUpdate };
  return envelopeLine(rootEnvelope);
}

function offerSourceToolId(offer: ActionOffer, data: DataResult[]): string {
  let matched = '';
  for (let index = 0; index < data.length; index++) {
    const definition = toolDefinitionForToolId(data[index].toolId);
    if (definition === null || definition.actions.indexOf(offer.actionId) < 0) continue;
    if (matched.length > 0 && matched !== data[index].toolId) return '';
    matched = data[index].toolId;
  }
  if (matched.length === 0 && data.length === 1) return data[0].toolId;
  return matched;
}

function actionOf(offer: ActionOffer, sourceToolId: string): A2uiAction {
  const action: A2uiAction = {
    id: offer.actionId,
    label: offer.label,
    prompt: offer.label,
    variant: offer.variant,
    kind: 'prompt',
    args: JSON.parse(JSON.stringify(offer.args)) as Object
  };
  if (sourceToolId.length > 0) action.sourceSectionId = sourceToolId;
  return action;
}

function baselineComponents(data: DataResult[], offers: ActionOffer[]): A2uiComponent[] {
  const children: string[] = ['summary'];
  const components: A2uiComponent[] = [
    { id: 'root', component: 'SurfaceRoot', child: 'content' },
    { id: 'content', component: 'Column', children },
    { id: 'summary', component: 'Text', dataPath: '/summary/text' }
  ];
  for (let index = 0; index < data.length; index++) {
    const id = 'result-' + index.toString();
    children.push(id);
    components.push({ id, component: 'InfoRows', title: data[index].toolId, dataPath: '/results/' + index.toString() + '/facts' });
  }
  if (offers.length > 0) {
    const actions: A2uiAction[] = [];
    for (let index = 0; index < offers.length; index++) {
      actions.push(actionOf(offers[index], offerSourceToolId(offers[index], data)));
    }
    children.push('actions');
    components.push({ id: 'actions', component: 'ActionBar', actions });
  }
  return components;
}

function annotateActionSources(jsonl: string, data: DataResult[], offers: ActionOffer[]): string {
  const sourceByAction: Map<string, string> = new Map<string, string>();
  for (let index = 0; index < offers.length; index++) {
    const source = offerSourceToolId(offers[index], data);
    const key = offers[index].actionId + '\n' + JSON.stringify(offers[index].args);
    if (source.length > 0) sourceByAction.set(key, source);
  }
  const lines = jsonl.trim().split(/\r?\n/);
  const output: string[] = [];
  for (let index = 0; index < lines.length; index++) {
    const envelope = JSON.parse(lines[index]) as UiLabEnvelope;
    const components = envelope.updateComponents?.components;
    if (components !== undefined) {
      for (let componentIndex = 0; componentIndex < components.length; componentIndex++) {
        const actions = components[componentIndex].actions;
        if (actions === undefined) continue;
        for (let actionIndex = 0; actionIndex < actions.length; actionIndex++) {
          if (actions[actionIndex].args === undefined) continue;
          const key = actions[actionIndex].id + '\n' + JSON.stringify(actions[actionIndex].args);
          const source = sourceByAction.get(key);
          if (source !== undefined) actions[actionIndex].sourceSectionId = source;
        }
      }
    }
    output.push(JSON.stringify(envelope));
  }
  return output.join('\n') + '\n';
}

export function uiAgentLabLayoutPrompt(
  task: CreateUiTaskPayload,
  snapshot: UiLabSnapshot,
  offers: ActionOffer[]
): string {
  const promptOffers: UiLabPromptOffer[] = offers.slice(0, 24).map(
    (offer: ActionOffer): UiLabPromptOffer => {
      return { offerId: offer.offerId, label: offer.label, variant: offer.variant };
    }
  );
  const instructions = 'Lay out a useful mobile UI from all verified DataResult values.\n' +
    'Choose presentation by the meaning and shape of the actual values. Do not assume a business schema and do not prescribe a chart type.\n' +
    'When result.data.providerData exists, it is the schema-preserving provider payload. Prefer paths below providerData and do not bind generic rows or rawPreview compatibility fields.\n' +
    'If result.data.providerDataMeta.truncated is true, the provider payload is incomplete. Never treat a retained array length as the original total; use only explicit provider counts or providerDataMeta array counts.\n' +
    'For every normal non-error UI Lab result with displayable verified data, you MUST output exactly one HeroBanner. Do not fabricate a HeroBanner summary for an error or no-display-data baseline. HeroBanner is always the first visible element in the main content container. If any other visible component exists, SurfaceRoot.child must reference a Column and the HeroBanner id must be Column.children[0]. Never connect root only to HeroBanner while leaving sibling components disconnected. If HeroBanner is the only visible component, SurfaceRoot.child may reference it directly. Its title is required; use text as a kicker and body to naturally synthesize all verified results without mechanically listing toolId values.\n' +
    '/summary/count and /summary/text describe the number of DataResult sets, not the number of business entities. HeroBanner must never present them as an entity total.\n' +
    'Never infer a total from a sampled array length. State a business count only when result.data explicitly labels a scalar as count or total, or when result.data.summary text explicitly supports it.\n' +
    'For chart components, bind the narrowest matching snapshot paths through fields allowed by the catalog. Never output SVG, path, points, rect, viewBox, coordinates, dimensions, geometry, stroke settings, or colors; the renderer owns them.\n' +
    'Use only the UI Lab component catalog.\n' +
    'Derive every binding path only from the exact structure present in dataSnapshot. The host rejects paths that do not exist in this sampled snapshot.\n' +
    'Author-composed text and labels may be literals where the catalog allows them. When binding snapshot data, use the exact one-key object {"path":"/exact/path/from/dataSnapshot"}. Never print a path string such as "/results/0/data/value" as literal UI text.\n' +
    'Actions may contain only an offered offerId; never output action arguments.\n' +
    'Honor the original user request when choosing the presentation; intent is a shorter Leader summary.\n' +
    'intent=' + JSON.stringify(task.intent) + '\n' +
    'originalUserInput=' + JSON.stringify(task.originalUserInput === undefined ? '' : task.originalUserInput) + '\n';
  const verifiedOffers = 'verifiedOffers=' + JSON.stringify(promptOffers) + '\n';
  const compactResults = snapshot.results.map((item: UiLabResultSnapshot): UiLabResultSnapshot => {
    return {
      dataTaskId: item.dataTaskId, toolId: item.toolId, outputSchema: item.outputSchema,
      status: item.status, warnings: item.warnings, facts: item.facts,
      data: tightlySampled(item.data) as Object
    };
  });
  const compactSnapshot: UiLabSnapshot = { summary: snapshot.summary, results: compactResults };
  const omittedResults = snapshot.results.map((item: UiLabResultSnapshot): UiLabResultSnapshot => {
    const omitted: UiLabOmittedData = { omittedDueToPromptBudget: true };
    return {
      dataTaskId: item.dataTaskId, toolId: item.toolId, outputSchema: item.outputSchema,
      status: item.status, warnings: item.warnings, facts: item.facts, data: omitted
    };
  });
  const omittedSnapshot: UiLabSnapshot = { summary: snapshot.summary, results: omittedResults };
  const snapshots: UiLabSnapshot[] = [snapshot, compactSnapshot, omittedSnapshot];
  const completeMarker = '\ndataSnapshotComplete=true';
  const prefix = instructions + verifiedOffers + 'dataSnapshot=';
  for (let index = 0; index < snapshots.length; index++) {
    const encodedSnapshot = JSON.stringify(snapshots[index]);
    const candidate = prefix + encodedSnapshot + completeMarker;
    if (candidate.length <= UI_LAB_LAYOUT_PROMPT_LIMIT) return candidate;
  }
  return prefix + JSON.stringify(omittedSnapshot) + completeMarker;
}

class UiAgentLabRenderer implements UiTaskRenderer {
  private readonly planner: UiLayoutPlanner;

  constructor(planner: UiLayoutPlanner) {
    this.planner = planner;
  }

  skeleton(task: CreateUiTaskPayload, surfaceId: string): Promise<UiRenderResult> {
    const rendered: UiRenderResult = {
      jsonl: surfaceShell(surfaceId, 'calling_tool', [
        { id: 'root', component: 'SurfaceRoot', child: 'thinking' },
        { id: 'thinking', component: 'ThinkingCard', title: '正在获取真实数据', body: task.intent, status: 'calling_tool' }
      ])
    };
    return Promise.resolve(rendered);
  }

  async result(
    task: CreateUiTaskPayload,
    data: DataResult[],
    offers: ActionOffer[],
    surfaceId: string
  ): Promise<UiRenderResult> {
    const snapshot = buildUiAgentLabSnapshot(task, data);
    const baseline = surfaceShell(surfaceId, 'ready', baselineComponents(data, offers)) +
      uiAgentLabDataJsonl(surfaceId, snapshot);
    let timerId: number = -1;
    const timeout = new Promise<string | null>((resolve: (value: string | null) => void): void => {
      timerId = setTimeout((): void => resolve(null), UI_LAB_LAYOUT_TIMEOUT_MS);
    });
    try {
      const candidate = await Promise.race<string | null>([
        this.planner.plan(uiAgentLabLayoutPrompt(task, snapshot, offers), surfaceId),
        timeout
      ]);
      if (candidate === null) {
        aiLogInfo('[UiAgentLabLayout] surface=' + surfaceId + ' planner=null fallback=true');
        return { jsonl: baseline };
      }
      const merge = mergeA2uiLayoutWithStatus(
        baseline,
        candidate,
        surfaceId,
        offers,
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      aiLogInfo(
        '[UiAgentLabLayout] surface=' + surfaceId + ' mergeAccepted=' + merge.accepted.toString() +
        ' reason=' + merge.reason
      );
      return {
        jsonl: annotateActionSources(
          merge.accepted ? hydrateUiAgentLabMergedJsonl(merge.jsonl, surfaceId, snapshot, data) : merge.jsonl,
          data,
          offers
        )
      };
    } finally {
      if (timerId >= 0) clearTimeout(timerId);
    }
  }

  error(_task: CreateUiTaskPayload, message: string, surfaceId: string): Promise<UiRenderResult> {
    const rendered: UiRenderResult = {
      jsonl: surfaceShell(surfaceId, 'error', [
        { id: 'root', component: 'SurfaceRoot', child: 'error' },
        { id: 'error', component: 'ErrorNotice', title: '请求未完成', body: message.substring(0, 300), status: 'error' }
      ])
    };
    return Promise.resolve(rendered);
  }

  actionStatus(payload: Object, surfaceId: string): Promise<UiRenderResult> {
    const source = payload as UiLabRecord;
    const message = typeof source['message'] === 'string' ? source['message'] as string :
      (typeof source['status'] === 'string' ? '操作状态：' + source['status'] as string : '操作状态已更新。');
    const summary: UiLabSummary = {
      text: message.substring(0, 300),
      toolName: typeof source['actionId'] === 'string' ? source['actionId'] as string : 'action',
      dataLabel: 'actionStatus',
      count: 0
    };
    const update: UiLabUpdateDataModel = { surfaceId, path: '/summary', value: summary as Object };
    const envelope: UiLabDataEnvelope = { version: 'v0.9.1', updateDataModel: update };
    const rendered: UiRenderResult = { jsonl: envelopeLine(envelope) };
    return Promise.resolve(rendered);
  }
}

function actionFrom(component: A2uiComponent, action: A2uiAction): HtmlHomeAction {
  const projected: HtmlHomeAction = {
    id: action.id,
    label: action.label,
    prompt: action.prompt,
    variant: action.variant,
    kind: action.kind,
    sourceComponentId: component.id
  };
  if (action.args !== undefined) projected.args = action.args;
  if (action.sourceSectionId !== undefined) projected.sourceToolId = action.sourceSectionId;
  return projected;
}

export function projectUiAgentLabSurface(surface: A2uiSurfaceState): HtmlHomeDocument {
  const actions: HtmlHomeAction[] = [];
  for (let index = 0; index < surface.components.length; index++) {
    const values = surface.components[index].actions;
    if (values === undefined) continue;
    for (let actionIndex = 0; actionIndex < values.length; actionIndex++) {
      actions.push(actionFrom(surface.components[index], values[actionIndex]));
    }
  }
  const blocks: HtmlHomeBlock[] = [];
  return {
    version: 1,
    surfaceId: surface.surfaceId,
    source: 'model',
    kind: 'generic',
    title: surface.title,
    subtitle: '',
    chips: [],
    metrics: [],
    timeline: [],
    blocks,
    actions,
    history: [],
    persona: { id: '', name: '', avatarKey: '', status: '', reason: '' },
    personaMemory: { summary: '', preferences: [] },
    rawSurfaceRoot: null,
    generatedAt: new Date().toISOString()
  };
}

export class UiAgentLabHarness {
  private readonly runtime: MultiAgentCanaryRuntime;
  private active: boolean = true;
  private generation: number = 0;
  private currentSurface: A2uiSurfaceState | null = null;

  constructor(settings: LocalModelSettings, listener: UiAgentLabSurfaceListener) {
    const provider = new LlmProvider(
      settings.provider,
      settings.apiKey,
      settings.baseUrl,
      settings.model,
      settings.customParametersJson
    );
    const planner = new A2uiAgentRunner(
      new OpenAiA2uiModel(provider, UI_AGENT_LAB_COMPONENT_CATALOG_JSON)
    );
    const options: MultiAgentCanaryOptions = {
      model: new OpenAiCompatibleModel(provider),
      opener: new RejectUiLabUriOpener(),
      uiRenderer: new UiAgentLabRenderer(planner),
      structuredToolCall: callStructuredToolForUiLab,
      allowTrustedOperationTargets: true,
      surfaceDocumentProjector: projectUiAgentLabSurface,
      a2uiParserProfile: 'ui-lab',
      currentHostSurface: (): A2uiSurfaceState | null =>
        this.currentSurface === null ? null : cloneSurface(this.currentSurface),
      currentHostGeneration: (): number => this.generation,
      currentLocalDate,
      onSurface: (surface: A2uiSurfaceState, generation: number): boolean => {
        if (!this.active || generation !== this.generation) return false;
        this.currentSurface = cloneSurface(surface);
        listener({ turnId: 'ui-agent-lab-' + generation.toString(), surface: cloneSurface(surface) });
        return true;
      },
      onMemoryUpdate: (): void => {},
      submitTimeoutMs: 120000,
      actionTimeoutMs: 45000,
      settingsFingerprint: 'ui-lab|' + settings.provider + '|' + settings.baseUrl + '|' + settings.model
    };
    this.runtime = new MultiAgentCanaryRuntime(options);
  }

  async submit(prompt: string): Promise<UiAgentLabSubmitOutcome> {
    const bounded = prompt.trim().substring(0, 4000);
    if (!this.active || bounded.length === 0) {
      return { ok: false, status: 'canceled', message: 'UI Lab runtime 不可用。' };
    }
    this.runtime.cancelActiveTurn('superseded');
    this.generation++;
    const generation = this.generation;
    const input: UserInputPayload = { text: bounded, recentMessages: [] };
    const outcome = await this.runtime.submit(bounded, input, generation);
    return { ok: outcome.ok, status: outcome.status, message: outcome.message };
  }

  async runAction(action: A2uiAction): Promise<boolean> {
    if (!this.active || action.args === undefined) return false;
    const context = this.runtime.currentActionContext(action);
    if (context === null) return false;
    return await this.runtime.runAction(action, context);
  }

  cancel(reason: string): void {
    if (this.active) this.runtime.cancelActiveTurn(reason);
  }

  stop(): void {
    if (!this.active) return;
    this.active = false;
    this.generation++;
    this.runtime.cancelActiveTurn('ui-lab-disposed');
    this.runtime.dispose();
    this.currentSurface = null;
  }
}
