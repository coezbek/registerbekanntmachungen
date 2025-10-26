// scripts/build-index.js
const fs = require('fs');
const path = require('path');
const Fuse = require('fuse.js');

const dbPath = './db';
const publicPath = './public';
const filePaths = [];

console.log('Starte Aggregation der Daten für den Suchindex...');

// 1. Finde alle JSON-Datendateien
function findJsonFiles(dir) {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        if (entry.isDirectory()) {
            findJsonFiles(fullPath);
        } else if (entry.name.startsWith('registerbekanntmachungen-') && entry.name.endsWith('.json')) {
            filePaths.push(fullPath.replace(/\\/g, '/'));
        }
    }
}
findJsonFiles(dbPath);
filePaths.sort().reverse(); // Sortiert absteigend, neueste Datei zuerst
console.log(`Gefunden: ${filePaths.length} tägliche Datendateien.`);

// 2. Erstelle ein leichtgewichtiges Array von Objekten für die Suche
let searchableAnnouncements = [];
filePaths.forEach(filePath => {
    try {
        const fileContent = fs.readFileSync(filePath);
        const data = JSON.parse(fileContent);
        if (data && data.announcements) {
            data.announcements.forEach((ann) => {
                searchableAnnouncements.push({
                    id: ann.id,
                    name: ann.company_name,
                    reg: ann.registernummer,
                    seat: ann.company_seat,
                    // Remove "Amtsgericht " as a stop word to improve search for city names
                    court: ann.amtsgericht ? ann.amtsgericht.replace(/Amtsgericht\s/i, '').trim() : '',
                    type: ann.type,
                    date: ann.date,
                    file: filePath
                });
            });
        }
    } catch (err) {
        console.error(`Fehler bei der Verarbeitung von ${filePath}:`, err);
    }
});

console.log(`Aggregiert: ${searchableAnnouncements.length} durchsuchbare Einträge.`);

// 3. Erstelle und speichere Metadaten
const oldestDate = filePaths.length > 0 ? filePaths[filePaths.length - 1].match(/(\d{4}-\d{2}-\d{2})/)[0] : null;
const latestDateWithData = searchableAnnouncements.length > 0 ? searchableAnnouncements[0].date : null;

const metadata = {
    totalAnnouncements: searchableAnnouncements.length,
    oldestDate: oldestDate,
    latestDateWithData: latestDateWithData
};

if (!fs.existsSync(publicPath)) {
    fs.mkdirSync(publicPath);
}
fs.writeFileSync(path.join(publicPath, 'metadata.json'), JSON.stringify(metadata));
console.log('Metadaten (metadata.json) erfolgreich erstellt.');

// 4. Speichere die Artefakte
fs.writeFileSync(path.join(publicPath, 'search-data.json'), JSON.stringify(searchableAnnouncements));
fs.writeFileSync(path.join(publicPath, 'file-manifest.json'), JSON.stringify(filePaths));

// Determine file size for logging
const stats = fs.statSync(path.join(publicPath, 'search-data.json'));
const fileSizeInMB = (stats.size / (1024 * 1024)).toFixed(2);

console.log('Successfully created search-data.json and file-manifest.json in public/ directory.');
console.log(`search-data.json size: ${fileSizeInMB} MB`);