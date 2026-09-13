// public/app.js
document.addEventListener('DOMContentLoaded', function () {
    const loadingStatus = document.getElementById('loading-status');
    const searchInput = document.getElementById('search-input');
    const datePicker = document.getElementById('date-picker');
    const resultsContainer = document.getElementById('results-container');
    const resultsCount = document.getElementById('results-count');

    let fuse = null;
    let searchableData = [];
    let fileManifest = [];
    const dailyDataCache = new Map();

    async function initialize() {
        try {
            const [searchDataResponse, manifestResponse, metaResponse] = await Promise.all([
                fetch('search-data.json'),
                fetch('file-manifest.json'),
                fetch('metadata.json')
            ]);

            if (!searchDataResponse.ok || !manifestResponse.ok || !metaResponse.ok) {
                throw new Error('Daten-Dateien konnten nicht geladen werden.');
            }

            searchableData = await searchDataResponse.json();
            fileManifest = await manifestResponse.json();
            const metadata = await metaResponse.json();
            
            const fuseOptions = {
                keys: [
                    { name: 'name', weight: 0.5 },
                    { name: 'reg', weight: 0.3 },
                    { name: 'seat', weight: 0.1 },
                    { name: 'court', weight: 0.1 },
                ],
                includeScore: true,
                threshold: 0.2, // Keep it slightly fuzzy for typos
                ignoreLocation: true,
                useExtendedSearch: true,
            };
            fuse = new Fuse(searchableData, fuseOptions);
            
            const formattedOldest = new Date(metadata.oldestDate).toLocaleDateString('de-DE');
            const formattedLatest = new Date(metadata.latestDateWithData).toLocaleDateString('de-DE');
            loadingStatus.textContent = `Bereit. ${metadata.totalAnnouncements} Bekanntmachungen von ${formattedOldest} bis ${formattedLatest} durchsuchbar.`;
            
            setupDatePicker(metadata.oldestDate, metadata.latestDateWithData);
            enableControls();
            loadDataForDate(datePicker.value);

        } catch (error) {
            loadingStatus.textContent = `Fehler: ${error.message}`;
            console.error(error);
        }
    }

    function setupDatePicker(oldestDate, latestDate) {
        if (latestDate && oldestDate) {
            datePicker.value = latestDate;
            datePicker.min = oldestDate;
            datePicker.max = latestDate;
        }
    }

    function handleSearch() {
        const query = searchInput.value.trim();
        datePicker.value = '';

        if (!query) {
            resultsContainer.innerHTML = '';
            resultsCount.textContent = 'Suchbegriff eingeben oder ein Datum auswählen.';
            return;
        }
                
        const results = fuse.search(query);
        renderResults(results.map(r => r.item));
    }

    async function loadDataForDate(dateString) {
        if (!dateString) return;
        searchInput.value = '';
        loadingStatus.textContent = 'Lade...';
        resultsContainer.innerHTML = ''; // Clear previous results immediately

        const filePath = `db/${dateString.substring(0, 7)}/registerbekanntmachungen-${dateString}.json`;
        
        if (!fileManifest.includes(filePath)) {
            resultsCount.textContent = `Keine Daten für den ${dateString} verfügbar.`;
            loadingStatus.textContent = `Bereit. ${searchableData.length} Bekanntmachungen für den Zeitraum ${datePicker.min} bis ${datePicker.max} durchsuchbar.`;
            return;
        }

        try {
            const data = await getDailyData(filePath);
            const sortedAnnouncements = data.announcements.sort((a, b) => a.company_name.localeCompare(b.company_name));
            const formattedDate = new Date(dateString).toLocaleDateString('de-DE');
            renderResults(sortedAnnouncements, `Bekanntmachungen vom ${formattedDate}`);
        } catch (error) {
            resultsCount.textContent = `Fehler beim Laden der Daten für ${dateString}.`;
            console.error(error);
        } finally {
            // Always update the status text
            loadingStatus.textContent = `Bereit. ${searchableData.length} Bekanntmachungen für den Zeitraum ${datePicker.min} bis ${datePicker.max} durchsuchbar.`;
        }
    }
    
    async function getDailyData(filePath) {
        if (dailyDataCache.has(filePath)) return dailyDataCache.get(filePath);
        if (!filePath) throw new Error('Ungültiger Dateipfad angegeben.');
        const response = await fetch(filePath);
        if (!response.ok) throw new Error(`Fehler beim Laden von ${filePath}`);
        const data = await response.json();
        dailyDataCache.set(filePath, data);
        return data;
    }

    function renderResults(results, customTitle = null) {
        resultsCount.textContent = customTitle || `${results.length} Ergebnisse gefunden.`;
        if (results.length === 0 && !customTitle) {
            resultsCount.textContent = 'Keine Ergebnisse gefunden.';
        }

        const fragment = document.createDocumentFragment();
        results.slice(0, 200).forEach(item => {
            const div = document.createElement('div');
            div.className = 'result';

            let detailsContent;
            if (item.details) {
                detailsContent = `<pre>${item.details}</pre>`;
            } else {
                detailsContent = `<div class="details-content">Lade...</div>`;
            }
            

            div.innerHTML = `
                <h3>${item.name || item.company_name}</h3>
                <div class="meta">
                    <span><strong>Datum:</strong> ${new Date(item.date).toLocaleDateString('de-DE')}</span> | 
                    <span><strong>Gericht:</strong> ${item.court || item.amtsgericht}</span> | 
                    <span><strong>Reg.-Nr.:</strong> ${item.reg || item.registernummer}</span>
                </div>
                <p><strong>Typ:</strong> ${item.type}</p>
                <details data-file-path="${item.file || ''}" data-announcement-id="${item.id}">
                    <summary>Details anzeigen</summary>
                    ${detailsContent}
                </details>
            `;
            fragment.appendChild(div);
        });
        resultsContainer.innerHTML = '';
        resultsContainer.appendChild(fragment);
    }
    
    async function handleDetailsToggle(event) {
        const detailsElement = event.target;
        if (detailsElement.tagName !== 'DETAILS' || !detailsElement.open) return;

        const contentDiv = detailsElement.querySelector('.details-content');

        if (!contentDiv) {
            return;
        }
        if (contentDiv.textContent !== 'Lade...') return;

        const filePath = detailsElement.dataset.filePath;
        const announcementId = detailsElement.dataset.announcementId;
        
        if (!filePath) {
             contentDiv.textContent = 'Fehler: Keine Quelldatei für diese Bekanntmachung gefunden.';
             return;
        }

        try {
            const dailyData = await getDailyData(filePath);
            const fullAnnouncement = dailyData.announcements.find(a => a.id === announcementId);
            
            if (fullAnnouncement) {
                const pre = document.createElement('pre');
                pre.textContent = fullAnnouncement.details || 'Keine Details verfügbar.';
                contentDiv.innerHTML = '';
                contentDiv.appendChild(pre);
            } else {
                contentDiv.textContent = 'Fehler: Bekanntmachung in der Quelldatei nicht gefunden.';
            }
        } catch (e) {
            contentDiv.textContent = 'Fehler: Detail-Datei konnte nicht geladen werden.';
            console.error(e);
        }
    }

    function enableControls() {
        [searchInput, datePicker].forEach(el => el.disabled = false);
    }

    let debounceTimer;
    searchInput.addEventListener('keyup', () => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(handleSearch, 300);
    });
    
    datePicker.addEventListener('change', () => loadDataForDate(datePicker.value));
    resultsContainer.addEventListener('toggle', handleDetailsToggle, true);

    initialize();
});