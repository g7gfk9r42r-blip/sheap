/**
 * EDEKA Regionen mit öffentlichen PDF-Download-Links
 * 
 * ⚠️ WICHTIG: Diese Links müssen öffentlich zugänglich sein und direkt zu PDF-Dateien führen.
 * Keine dynamischen Crawls, keine Bot-Umgehung - nur statische PDF-Links!
 * 
 * Die PDF-Links können von KaufDA oder anderen öffentlichen Quellen stammen.
 * Der Nutzer muss diese Links manuell eintragen, nachdem er sie von der öffentlichen Website kopiert hat.
 */

export type EdekaRegion = {
  region: string;
  pdfUrl: string;
  city?: string;
  zipCode?: string;
};

/**
 * Liste der 16 relevanten EDEKA-Regionen
 * 
 * TODO: Der Nutzer muss die PDF-URLs manuell eintragen.
 * 
 * So findest du die PDF-URLs:
 * 1. Gehe zu https://www.kaufda.de/Geschaefte/Edeka
 * 2. Wähle eine Region aus
 * 3. Öffne den Prospekt
 * 4. Rechtsklick auf "PDF herunterladen" → Link-Adresse kopieren
 * 5. Füge die URL hier ein
 */
export const EDEKA_REGIONS: EdekaRegion[] = [
  {
    region: 'Berlin',
    pdfUrl: '', // TODO: PDF-URL von KaufDA eintragen
    city: 'Berlin',
    zipCode: '10115',
  },
  {
    region: 'Hamburg',
    pdfUrl: '', // TODO: PDF-URL von KaufDA eintragen
    city: 'Hamburg',
    zipCode: '20095',
  },
  {
    region: 'München',
    pdfUrl: '', // TODO: PDF-URL von KaufDA eintragen
    city: 'München',
    zipCode: '80331',
  },
  {
    region: 'Nürnberg',
    pdfUrl: '', // TODO: PDF-URL von KaufDA eintragen
    city: 'Nürnberg',
    zipCode: '90402',
  },
  {
    region: 'Essen',
    pdfUrl: '', // TODO: PDF-URL von KaufDA eintragen
    city: 'Essen',
    zipCode: '45127',
  },
  {
    region: 'Düsseldorf',
    pdfUrl: '', // TODO: PDF-URL von KaufDA eintragen
    city: 'Düsseldorf',
    zipCode: '40210',
  },
  {
    region: 'Köln',
    pdfUrl: '', // TODO: PDF-URL von KaufDA eintragen
    city: 'Köln',
    zipCode: '50667',
  },
  {
    region: 'Dortmund',
    pdfUrl: '', // TODO: PDF-URL von KaufDA eintragen
    city: 'Dortmund',
    zipCode: '44135',
  },
  {
    region: 'Stuttgart',
    pdfUrl: '', // TODO: PDF-URL von KaufDA eintragen
    city: 'Stuttgart',
    zipCode: '70173',
  },
  {
    region: 'Freiburg',
    pdfUrl: '', // TODO: PDF-URL von KaufDA eintragen
    city: 'Freiburg',
    zipCode: '79098',
  },
  {
    region: 'Hannover',
    pdfUrl: '', // TODO: PDF-URL von KaufDA eintragen
    city: 'Hannover',
    zipCode: '30159',
  },
  {
    region: 'Münster',
    pdfUrl: '', // TODO: PDF-URL von KaufDA eintragen
    city: 'Münster',
    zipCode: '48143',
  },
  {
    region: 'Augsburg',
    pdfUrl: '', // TODO: PDF-URL von KaufDA eintragen
    city: 'Augsburg',
    zipCode: '86150',
  },
  {
    region: 'Chemnitz',
    pdfUrl: '', // TODO: PDF-URL von KaufDA eintragen
    city: 'Chemnitz',
    zipCode: '09111',
  },
  {
    region: 'Duisburg',
    pdfUrl: '', // TODO: PDF-URL von KaufDA eintragen
    city: 'Duisburg',
    zipCode: '47051',
  },
  {
    region: 'Bonn',
    pdfUrl: '', // TODO: PDF-URL von KaufDA eintragen
    city: 'Bonn',
    zipCode: '53111',
  },
];

/**
 * Validiert, ob eine Region eine gültige PDF-URL hat
 */
export function hasValidPdfUrl(region: EdekaRegion): boolean {
  return !!region.pdfUrl && region.pdfUrl.trim().length > 0 && region.pdfUrl.startsWith('http');
}

/**
 * Gibt nur Regionen mit gültigen PDF-URLs zurück
 */
export function getRegionsWithPdfUrls(): EdekaRegion[] {
  return EDEKA_REGIONS.filter(hasValidPdfUrl);
}

