import { describe, expect, it } from '@ohos/hypium';
import {
  ActionOffer,
  mergeA2uiLayout,
  UI_AGENT_LAB_COMPONENT_CATALOG_JSON
} from '@loop/agent-core';

const SURFACE_ID: string = 'surface-layout-test';
const BASELINE: string =
  '{"version":"v0.9.1","createSurface":{"surfaceId":"surface-layout-test","root":"root","title":"酒店搜索"}}\n' +
  '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
  '{"id":"root","component":"SurfaceRoot","child":"results"},' +
  '{"id":"results","component":"GenericToolResults","dataPath":"/genericToolResults"}]}}\n' +
  '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/genericToolResults","value":[]}}\n' +
  '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/summary","value":{"text":"真实结果"}}}\n';

const VALID_CANDIDATE: string =
  '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
  '{"id":"root","component":"SurfaceRoot","child":"column"},' +
  '{"id":"column","component":"Column","children":["title","results","actions"]},' +
  '{"id":"title","component":"Text","text":"酒店结果","variant":"h3"},' +
  '{"id":"results","component":"GenericToolResults","dataPath":"/genericToolResults"},' +
  '{"id":"actions","component":"ActionBar","actions":[{"offerId":"detail:1"}]}' +
  ']}}';

const LAB_CANDIDATE: string =
  '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
  '{"id":"root","component":"SurfaceRoot","child":"lab-grid"},' +
  '{"id":"lab-grid","component":"MasonryGrid","dataPath":"/genericToolResults"}' +
  ']}}';

const BENTO_CANDIDATE: string =
  '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
  '{"id":"root","component":"SurfaceRoot","child":"lab-grid"},' +
  '{"id":"lab-grid","component":"BentoGrid","dataPath":"/genericToolResults"}' +
  ']}}';

interface ComponentCatalogEntry {
  name: string;
}

const LAB_COMPONENT_NAMES: string[] = [
  'SurfaceRoot', 'Column', 'Row', 'Text', 'InfoRows', 'ActionBar', 'ErrorNotice', 'ThinkingStream',
  'ThinkingCard', 'ScheduleStack', 'SkeletonCard', 'ExpandableCard', 'MediaSlider', 'SceneTabs', 'MasonryGrid'
];

interface HotelIdArg {
  hotelId: number;
}

function offers(): ActionOffer[] {
  const args: HotelIdArg = { hotelId: 1 };
  const offer: ActionOffer = {
    offerId: 'detail:1',
    actionId: 'hotel.detail',
    label: '查看实时房型',
    variant: 'primary',
    args: args
  };
  return [offer];
}

export default function a2uiLayoutMergerTest() {
  describe('A2uiLayoutMerger', () => {
    it('replaces only components and resolves immutable offer references', 0, () => {
      const merged: string = mergeA2uiLayout(BASELINE, VALID_CANDIDATE, SURFACE_ID, offers());
      const baselineLines: string[] = BASELINE.trim().split('\n');
      const mergedLines: string[] = merged.trim().split('\n');
      expect(merged === BASELINE).assertFalse();
      expect(mergedLines[0]).assertEqual(baselineLines[0]);
      expect(mergedLines[2]).assertEqual(baselineLines[2]);
      expect(mergedLines[3]).assertEqual(baselineLines[3]);
      expect(mergedLines[1].includes('"id":"hotel.detail"')).assertTrue();
      expect(mergedLines[1].includes('"offerId"')).assertFalse();
      expect(mergedLines[1].includes('"hotelId":1')).assertTrue();
    });

    it('accepts UI Lab components only when the UI Lab catalog is selected', 0, () => {
      const merged: string = mergeA2uiLayout(
        BASELINE,
        LAB_CANDIDATE,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      expect(merged === BASELINE).assertFalse();
      expect(merged.includes('"component":"MasonryGrid"')).assertTrue();
      expect(mergeA2uiLayout(BASELINE, LAB_CANDIDATE, SURFACE_ID, [])).assertEqual(BASELINE);
    });

    it('keeps the UI Lab allowlist fixed at fifteen components without BentoGrid', 0, () => {
      const catalog = JSON.parse(UI_AGENT_LAB_COMPONENT_CATALOG_JSON) as ComponentCatalogEntry[];
      expect(catalog.length).assertEqual(15);
      for (let index = 0; index < LAB_COMPONENT_NAMES.length; index++) {
        expect(catalog[index].name).assertEqual(LAB_COMPONENT_NAMES[index]);
      }
      expect(UI_AGENT_LAB_COMPONENT_CATALOG_JSON.includes('"name":"BentoGrid"')).assertFalse();
      expect(mergeA2uiLayout(
        BASELINE,
        BENTO_CANDIDATE,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(BASELINE);
    });

    it('rejects business components when the UI Lab catalog is selected', 0, () => {
      expect(mergeA2uiLayout(
        BASELINE,
        VALID_CANDIDATE,
        SURFACE_ID,
        offers(),
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(BASELINE);
    });

    it('falls back exactly for wrong surface or extra envelopes', 0, () => {
      const wrongSurface = VALID_CANDIDATE.replace(SURFACE_ID, 'other-surface');
      const extra = VALID_CANDIDATE + '\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/summary","value":{}}}';
      expect(mergeA2uiLayout(BASELINE, wrongSurface, SURFACE_ID, offers())).assertEqual(BASELINE);
      expect(mergeA2uiLayout(BASELINE, extra, SURFACE_ID, offers())).assertEqual(BASELINE);
    });

    it('falls back exactly for unknown components and data paths', 0, () => {
      expect(mergeA2uiLayout(
        BASELINE,
        VALID_CANDIDATE.replace('GenericToolResults', 'UnknownCard'),
        SURFACE_ID,
        offers()
      )).assertEqual(BASELINE);
      expect(mergeA2uiLayout(
        BASELINE,
        VALID_CANDIDATE.replace('/genericToolResults', '/secret'),
        SURFACE_ID,
        offers()
      )).assertEqual(BASELINE);
    });

    it('falls back exactly for literal actions and unknown offers', 0, () => {
      expect(mergeA2uiLayout(
        BASELINE,
        VALID_CANDIDATE.replace('{"offerId":"detail:1"}', '{"id":"hotel.detail","args":{"hotelId":2}}'),
        SURFACE_ID,
        offers()
      )).assertEqual(BASELINE);
      expect(mergeA2uiLayout(
        BASELINE,
        VALID_CANDIDATE.replace('detail:1', 'detail:unknown'),
        SURFACE_ID,
        offers()
      )).assertEqual(BASELINE);
    });

    it('falls back exactly for duplicate offers and disconnected trees', 0, () => {
      const duplicate = VALID_CANDIDATE.replace(
        '{"offerId":"detail:1"}',
        '{"offerId":"detail:1"},{"offerId":"detail:1"}'
      );
      const disconnected = VALID_CANDIDATE.replace(
        '"children":["title","results","actions"]',
        '"children":["title","results"]'
      );
      expect(mergeA2uiLayout(BASELINE, duplicate, SURFACE_ID, offers())).assertEqual(BASELINE);
      expect(mergeA2uiLayout(BASELINE, disconnected, SURFACE_ID, offers())).assertEqual(BASELINE);
    });

    it('falls back exactly for cycles and unknown fields', 0, () => {
      const cycle = VALID_CANDIDATE.replace(
        '{"id":"title","component":"Text","text":"酒店结果","variant":"h3"}',
        '{"id":"title","component":"Text","child":"root","text":"酒店结果","variant":"h3"}'
      );
      const unknownField = VALID_CANDIDATE.replace(
        '"component":"Column"',
        '"component":"Column","onClick":"unsafe"'
      );
      expect(mergeA2uiLayout(BASELINE, cycle, SURFACE_ID, offers())).assertEqual(BASELINE);
      expect(mergeA2uiLayout(BASELINE, unknownField, SURFACE_ID, offers())).assertEqual(BASELINE);
    });
  });
}
