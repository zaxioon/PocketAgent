import {
  AggregateSearchSource,
  AggregateSearchSourceMetadata
} from './AggregateSearchTypes';

const SOURCE_METADATA: AggregateSearchSourceMetadata[] = [
  { source: 'youtube', isExternal: true, languages: ['zh-Hans', 'zh-Hant', 'en'], languageFilterMode: 'native' },
  { source: 'bilibili', isExternal: false, languages: ['zh-Hans', 'zh-Hant'], languageFilterMode: 'intrinsic' },
  { source: 'x', isExternal: true, languages: ['zh-Hans', 'zh-Hant', 'en'], languageFilterMode: 'native' },
  { source: 'hackernews', isExternal: true, languages: ['en'], languageFilterMode: 'intrinsic' },
  { source: 'reddit', isExternal: true, languages: ['zh-Hans', 'zh-Hant', 'en'], languageFilterMode: 'none' },
  { source: 'zhihu', isExternal: false, languages: ['zh-Hans', 'zh-Hant'], languageFilterMode: 'intrinsic' }
];

function cloneMetadata(metadata: AggregateSearchSourceMetadata): AggregateSearchSourceMetadata {
  return {
    source: metadata.source,
    isExternal: metadata.isExternal,
    languages: metadata.languages.slice(),
    languageFilterMode: metadata.languageFilterMode
  };
}

export function aggregateSearchRegistryMetadata(): AggregateSearchSourceMetadata[] {
  return SOURCE_METADATA.map((metadata: AggregateSearchSourceMetadata): AggregateSearchSourceMetadata =>
    cloneMetadata(metadata));
}

export function aggregateSearchRegistrySourceIds(): AggregateSearchSource[] {
  return SOURCE_METADATA.map((metadata: AggregateSearchSourceMetadata): AggregateSearchSource => metadata.source);
}

export function aggregateSearchRegistryMetadataFor(
  source: AggregateSearchSource
): AggregateSearchSourceMetadata {
  for (let index = 0; index < SOURCE_METADATA.length; index++) {
    if (SOURCE_METADATA[index].source === source) {
      return cloneMetadata(SOURCE_METADATA[index]);
    }
  }
  return cloneMetadata(SOURCE_METADATA[0]);
}
