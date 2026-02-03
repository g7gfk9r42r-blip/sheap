/**
 * Crawl4AI HTTP client (Docker-first).
 *
 * 👉 Recommended dev command:
 *    docker run --rm -p 11235:11235 unclecode/crawl4ai:basic
 *
 * Crawl4AI exposes a REST API. This helper wraps the /crawl endpoint and
 * optionally polls async jobs if the response contains a job identifier.
 */

import { CRAWL4AI_BASE_URL, CRAWL4AI_TOKEN } from '../config.js';

const DOCKER_HINT = 'docker run --rm -p 11235:11235 -e CRAWL4AI_API_KEY=your-token unclecode/crawl4ai:basic';
const DEFAULT_TIMEOUT_MS = 180_000; // 3 minutes
const DEFAULT_POLL_INTERVAL_MS = 2_000;
const DEFAULT_CONFIG = Object.freeze({
  maxDepth: 0,
  maxPages: 1,
});
const DEFAULT_CRAWLER_CONFIG = Object.freeze({
  type: 'CrawlerRunConfig',
  params: {
    scan_full_page: true,
    wait_until: 'domcontentloaded',
    simulate_user: true,
    magic: true,
    page_timeout: 90_000,
    evaluate_js: true,
    scroll_page: true,
    max_scroll_height: 4_000,
  },
});

/**
 * @typedef {Object} CrawlSchemaField
 * @property {string} name
 * @property {string} description
 * @property {'string'|'number'|'boolean'} type
 */

/**
 * @typedef {Object} CrawlOptions
 * @property {CrawlSchemaField[]=} schema
 * @property {string=} instruction
 * @property {{ maxDepth?: number; maxPages?: number }=} config
 * @property {number=} timeoutMs
 * @property {Object=} crawlerConfig
 * @property {Object=} extractionConfig
 */

const normalizeBaseUrl = () => {
  const base = (CRAWL4AI_BASE_URL || '').trim().replace(/\/+$/, '');
  if (!base) {
    throw new Error(
      `[Crawl4AI] CRAWL4AI_BASE_URL missing. Start the docker image via "${DOCKER_HINT}" and set the env variable.`,
    );
  }
  return base;
};

const buildHeaders = () => {
  const headers = { 'Content-Type': 'application/json' };
  
  // Support both CRAWL4AI_TOKEN and CRAWL4AI_API_KEY from environment
  const token = CRAWL4AI_TOKEN || process.env.CRAWL4AI_API_KEY || '';
  
  if (token) {
    // Try Bearer token first (standard OAuth format)
    headers.Authorization = `Bearer ${token}`;
    // Also set X-API-Key as fallback (some APIs use this format)
    headers['X-API-Key'] = token;
  }
  
  return headers;
};

const mergeCrawlerConfig = (baseConfig, overrideConfig) => {
  if (!overrideConfig) {
    return baseConfig;
  }

  const overrideParams =
    overrideConfig.params ??
    (typeof overrideConfig === 'object' && !overrideConfig.type ? overrideConfig : {});

  return {
    type: overrideConfig.type ?? baseConfig.type,
    params: {
      ...baseConfig.params,
      ...overrideParams,
    },
  };
};

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function pollJob(jobId, { baseUrl, timeoutMs = DEFAULT_TIMEOUT_MS }) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const response = await fetch(`${baseUrl}/crawl/${jobId}`, {
      method: 'GET',
      headers: buildHeaders(),
    });

    if (!response.ok) {
      throw new Error(
        `[Crawl4AI] Failed to poll job ${jobId} (${response.status} ${response.statusText})`,
      );
    }

    const payload = await response.json();
    if (payload?.status === 'completed' || payload?.result) {
      return payload.result ?? payload;
    }

    if (payload?.status === 'failed') {
      throw new Error(
        `[Crawl4AI] Job ${jobId} failed${payload.error ? `: ${payload.error}` : ''}`,
      );
    }

    await sleep(DEFAULT_POLL_INTERVAL_MS);
  }

  throw new Error(`[Crawl4AI] Job ${jobId} timed out after ${timeoutMs}ms`);
}

const normalizeResult = (payload) => {
  if (!payload || typeof payload !== 'object') {
    return { items: [], raw: payload };
  }

  // Crawl4AI gibt { success: true, results: [...] } zurück
  const results = payload.results || (Array.isArray(payload) ? payload : [payload]);
  const firstResult = results[0] || {};

  // Extrahiere Markdown aus der richtigen Struktur
  const markdown = 
    firstResult.markdown?.raw_markdown ??
    firstResult.markdown?.markdown_with_citations ??
    (typeof firstResult.markdown === 'string' ? firstResult.markdown : null);

  const candidates = [
    payload.items,
    payload.data?.items,
    firstResult.extracted_content,
    payload.result?.items,
    payload.result?.extracted_data,
    payload.extracted_data,
  ];

  const items = candidates.find(Array.isArray) || [];
  return {
    items,
    markdown: markdown ?? payload.markdown ?? payload.result?.markdown ?? null,
    html: firstResult.html ?? firstResult.cleaned_html ?? payload.html ?? payload.result?.html ?? null,
    raw: {
      ...payload,
      firstResult,
      markdown: firstResult.markdown,
      metadata: firstResult.metadata,
    },
  };
};

/**
 * Crawls a single URL using the Crawl4AI /crawl endpoint.
 *
 * @param {string} url
 * @param {CrawlOptions=} options
 */
export async function crawlSinglePage(url, options = {}) {
  if (!url) {
    throw new Error('[Crawl4AI] crawlSinglePage requires a URL');
  }

  const baseUrl = normalizeBaseUrl();
  const {
    schema,
    instruction,
    config = {},
    timeoutMs = DEFAULT_TIMEOUT_MS,
    crawlerConfig = {},
    extractionConfig,
  } = options;

  const mergedCrawlerConfig = mergeCrawlerConfig(
    DEFAULT_CRAWLER_CONFIG,
    crawlerConfig,
  );

  const payload = {
    urls: [url], // Crawl4AI erwartet 'urls' (Array)
    options: {
      maxDepth: config.maxDepth ?? DEFAULT_CONFIG.maxDepth,
      maxPages: config.maxPages ?? DEFAULT_CONFIG.maxPages,
    },
  };

  if (schema?.length) {
    payload.schema = schema;
    if (instruction) {
      payload.instruction = instruction;
    }
  }

  payload.crawler_config = mergedCrawlerConfig;

  if (extractionConfig) {
    payload.extraction_config = extractionConfig;
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(`${baseUrl}/crawl`, {
      method: 'POST',
      headers: buildHeaders(),
      body: JSON.stringify(payload),
      signal: controller.signal,
    });

    if (!response.ok) {
      const details = await response.text().catch(() => '');
      throw new Error(
        `[Crawl4AI] Request failed (${response.status} ${response.statusText}) ${details}`,
      );
    }

    const body = await response.json().catch(() => {
      throw new Error('[Crawl4AI] Invalid JSON response from /crawl');
    });

    const finalPayload =
      body?.jobId || body?.job_id
        ? await pollJob(body.jobId ?? body.job_id, { baseUrl, timeoutMs })
        : body?.result ?? body;

    const normalized = normalizeResult(finalPayload);
    return normalized;
  } catch (err) {
    if (err.name === 'AbortError') {
      throw new Error(
        `[Crawl4AI] Request aborted after ${timeoutMs}ms. Ensure the docker container is running (${DOCKER_HINT}).`,
      );
    }
    throw err;
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Lightweight health check (optional).
 */
export async function pingCrawl4ai() {
  const baseUrl = normalizeBaseUrl();
  const response = await fetch(`${baseUrl}/health`, {
    method: 'GET',
    headers: buildHeaders(),
  });
  return response.ok;
}

/**
 * Convenience helper to fetch only markdown content with optional crawler overrides.
 *
 * @param {string} url
 * @param {Record<string, unknown>=} crawlerParams
 */
export async function crawlMarkdown(url, crawlerParams = {}) {
  return crawlSinglePage(url, {
    crawlerConfig: {
      type: 'CrawlerRunConfig',
      params: crawlerParams,
    },
  });
}

