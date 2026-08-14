import {
  AggregateSearchSource,
  AggregateSearchSourceMetadata
} from './AggregateSearchTypes';

const SOURCE_METADATA: AggregateSearchSourceMetadata[] = [
  { source: 'youtube', isExternal: true, languages: ['zh-Hans', 'zh-Hant', 'en'], languageFilterMode: 'native', introducedInRegistryVersion: 1, defaultEnabled: true },
  { source: 'bilibili', isExternal: false, languages: ['zh-Hans', 'zh-Hant'], languageFilterMode: 'intrinsic', introducedInRegistryVersion: 1, defaultEnabled: true },
  { source: 'x', isExternal: true, languages: ['zh-Hans', 'zh-Hant', 'en'], languageFilterMode: 'native', introducedInRegistryVersion: 1, defaultEnabled: true },
  { source: 'hackernews', isExternal: true, languages: ['en'], languageFilterMode: 'intrinsic', introducedInRegistryVersion: 1, defaultEnabled: true },
  { source: 'reddit', isExternal: true, languages: ['zh-Hans', 'zh-Hant', 'en'], languageFilterMode: 'none', introducedInRegistryVersion: 1, defaultEnabled: true },
  { source: 'zhihu', isExternal: false, languages: ['zh-Hans', 'zh-Hant'], languageFilterMode: 'intrinsic', introducedInRegistryVersion: 1, defaultEnabled: true },
  { source: 'douban', isExternal: false, languages: ['zh-Hans', 'zh-Hant'], languageFilterMode: 'intrinsic', introducedInRegistryVersion: 2, defaultEnabled: true },
  { source: 'applepodcasts', isExternal: true, languages: ['zh-Hans', 'zh-Hant', 'en'], languageFilterMode: 'regional', introducedInRegistryVersion: 2, defaultEnabled: true },
  { source: 'twitch', isExternal: true, languages: ['zh-Hans', 'zh-Hant', 'en'], languageFilterMode: 'post_filter', introducedInRegistryVersion: 2, defaultEnabled: true }
];

function cloneMetadata(metadata: AggregateSearchSourceMetadata): AggregateSearchSourceMetadata {
  return {
    source: metadata.source,
    isExternal: metadata.isExternal,
    languages: metadata.languages.slice(),
    languageFilterMode: metadata.languageFilterMode,
    introducedInRegistryVersion: metadata.introducedInRegistryVersion,
    defaultEnabled: metadata.defaultEnabled
  };
}

export function aggregateSearchRegistryMetadata(): AggregateSearchSourceMetadata[] {
  return SOURCE_METADATA.map((metadata: AggregateSearchSourceMetadata): AggregateSearchSourceMetadata =>
    cloneMetadata(metadata));
}

export function aggregateSearchRegistrySourceIds(): AggregateSearchSource[] {
  return SOURCE_METADATA.map((metadata: AggregateSearchSourceMetadata): AggregateSearchSource => metadata.source);
}

export function aggregateSearchRegistryVersion(): number {
  let version = 1;
  SOURCE_METADATA.forEach((metadata: AggregateSearchSourceMetadata): void => {
    version = Math.max(version, metadata.introducedInRegistryVersion);
  });
  return version;
}

export function aggregateSearchDefaultEnabledSourceIdsAfter(
  registryVersion: number = 0
): AggregateSearchSource[] {
  return SOURCE_METADATA.filter((metadata: AggregateSearchSourceMetadata): boolean =>
    metadata.defaultEnabled && metadata.introducedInRegistryVersion > registryVersion
  ).map((metadata: AggregateSearchSourceMetadata): AggregateSearchSource => metadata.source);
}

export function aggregateSearchDefaultEnabledSourceIds(): AggregateSearchSource[] {
  return SOURCE_METADATA.filter((metadata: AggregateSearchSourceMetadata): boolean => metadata.defaultEnabled)
    .map((metadata: AggregateSearchSourceMetadata): AggregateSearchSource => metadata.source);
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
