export type CrawlSchemaField = {
  name: string;
  description: string;
  type: 'string' | 'number' | 'boolean';
};

export type CrawlOptions = {
  schema?: CrawlSchemaField[];
  instruction?: string;
  config?: {
    maxDepth?: number;
    maxPages?: number;
  };
  timeoutMs?: number;
  crawlerConfig?: {
    type?: string;
    params?: Record<string, unknown>;
  };
  extractionConfig?: Record<string, unknown>;
};

export type CrawlSinglePageResult<T = any> = {
  items: T[];
  markdown?: string | null;
  html?: string | null;
  raw?: unknown;
};

export function crawlSinglePage<T = any>(
  url: string,
  options?: CrawlOptions,
): Promise<CrawlSinglePageResult<T>>;

export function pingCrawl4ai(): Promise<boolean>;

export function crawlMarkdown<T = any>(
  url: string,
  crawlerParams?: Record<string, unknown>,
): Promise<CrawlSinglePageResult<T>>;

