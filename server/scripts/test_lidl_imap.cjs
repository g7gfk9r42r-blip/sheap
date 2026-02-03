// scripts/test_lidl_imap.cjs
require('dotenv').config();
const { ImapFlow } = require('imapflow');

/**
 * Kleiner Connectivity-Test:
 * - verbindet sich mit iCloud-IMAP
 * - liest die letzten 5 Mails aus der INBOX
 * - gibt From, Subject, Datum aus
 */
async function main() {
  const {
    LIDL_IMAP_HOST,
    LIDL_IMAP_PORT,
    LIDL_IMAP_SECURE,
    LIDL_IMAP_USER,
    LIDL_IMAP_PASS,
  } = process.env;

  if (!LIDL_IMAP_HOST || !LIDL_IMAP_USER || !LIDL_IMAP_PASS) {
    console.error('❌ IMAP-Env-Variablen fehlen. Bitte .env prüfen.');
    process.exit(1);
  }

  const client = new ImapFlow({
    host: LIDL_IMAP_HOST,
    port: Number(LIDL_IMAP_PORT || 993),
    secure: String(LIDL_IMAP_SECURE || 'true') === 'true',
    auth: {
      user: LIDL_IMAP_USER,
      pass: LIDL_IMAP_PASS,
    },
  });

  console.log('⏳ Verbinde zu IMAP…');

  try {
    await client.connect();
    console.log('✅ Verbindung aufgebaut:', LIDL_IMAP_USER);

    // INBOX "sperren"
    let lock = await client.getMailboxLock('INBOX');
    try {
      // Letzte 5 Mails holen (nach Ankunft sortiert)
      const uids = await client.search(
        { all: true },
        { sort: ['arrival'], limit: 5, uid: true }
      );

      if (!uids.length) {
        console.log('📭 Keine Mails in der INBOX gefunden.');
        return;
      }

      console.log(`📩 Gefundene Mails: ${uids.length}`);
      
      // Falls zu viele UIDs: in Batches aufteilen (IMAP-Server limitieren oft große FETCH-Commands)
      const BATCH_SIZE = 50;
      if (uids.length > BATCH_SIZE) {
        // Batch-weise verarbeiten (komma-separierte Liste pro Batch)
        for (let i = 0; i < uids.length; i += BATCH_SIZE) {
          const batch = uids.slice(i, i + BATCH_SIZE);
          const batchSeq = batch.join(',');
          for await (let msg of client.fetch(batchSeq, { envelope: true, uid: true })) {
            const from =
              msg.envelope.from && msg.envelope.from[0]
                ? `${msg.envelope.from[0].name || ''} <${msg.envelope.from[0].address}>`
                : '(unbekannt)';
            const subject = msg.envelope.subject || '(kein Betreff)';
            const date = msg.envelope.date || '(kein Datum)';
            console.log('─────────────');
            console.log('Von:    ', from);
            console.log('Betreff:', subject);
            console.log('Datum:  ', date);
          }
        }
      } else {
        // Kleine Listen können direkt übergeben werden
        for await (let msg of client.fetch(uids, {
          envelope: true,
        })) {
          const from =
            msg.envelope.from && msg.envelope.from[0]
              ? `${msg.envelope.from[0].name || ''} <${msg.envelope.from[0].address}>`
              : '(unbekannt)';
          const subject = msg.envelope.subject || '(kein Betreff)';
          const date = msg.envelope.date || '(kein Datum)';
          console.log('─────────────');
          console.log('Von:    ', from);
          console.log('Betreff:', subject);
          console.log('Datum:  ', date);
        }
      }
    } finally {
      lock.release();
    }
  } catch (err) {
    console.error('❌ Fehler beim IMAP-Connect oder Fetch:');
    console.error(err);
  } finally {
    await client.logout();
    console.log('👋 Logout von IMAP.');
  }
}

main();