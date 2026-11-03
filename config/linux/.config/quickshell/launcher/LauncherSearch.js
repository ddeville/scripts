function normalize(text) {
    return String(text || "").normalize("NFKD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
}

function matchScore(text, query) {
    if (text === query)
        return 1000;
    if (text.startsWith(query))
        return 900;
    const position = text.indexOf(query);
    if (position >= 0)
        return /[\s._-]/.test(text[position - 1]) ? 800 : 700;

    let previous = -1;
    let gaps = 0;
    for (const character of query) {
        const next = text.indexOf(character, previous + 1);
        if (next < 0)
            return -1;
        gaps += next - previous - 1;
        previous = next;
    }
    return Math.max(1, 400 - gaps);
}

function search(entries, query, history) {
    const words = normalize(query).trim().split(/\s+/).filter(Boolean);
    const matches = [];
    for (const entry of entries) {
        const fields = [
            {text: normalize(entry.name), penalty: 0},
            {text: normalize(entry.genericName), penalty: 100},
            {text: normalize(entry.id), penalty: 300}
        ].concat(Array.from(entry.keywords || [], keyword => ({text: normalize(keyword), penalty: 200})));
        let score = 0;
        for (const word of words) {
            let best = -1;
            for (const field of fields) {
                const match = matchScore(field.text, word);
                if (match >= 0)
                    best = Math.max(best, Math.max(0, match - field.penalty));
            }
            if (best < 0) {
                score = -1;
                break;
            }
            score += best;
        }
        if (score >= 0)
            matches.push({entry: entry, score: score});
    }
    matches.sort((a, b) => {
        const aUsage = history[a.entry.id] || {};
        const bUsage = history[b.entry.id] || {};
        return b.score - a.score || (bUsage.count || 0) - (aUsage.count || 0) || (bUsage.lastUsed || 0) - (aUsage.lastUsed || 0) || a.entry.name.localeCompare(b.entry.name);
    });
    return matches.map(match => match.entry);
}

function launchContext(entry, home) {
    const command = Array.from(entry.command);
    const directory = entry.workingDirectory || home;
    return {
        command: entry.runInTerminal ? ["ghostty", "--working-directory=" + directory, "-e"].concat(command) : command,
        workingDirectory: directory
    };
}
