function rowsForSinks(sinks) {
    const rows = [];
    for (const sink of sinks) {
        const device = sink.properties?.["node.nick"] || sink.description || sink.name;
        const ports = sink.ports?.length ? sink.ports : [null];
        for (const port of ports) {
            if (port?.availability === "not available")
                continue;
            const type = (port?.type || sink.properties?.["device.form_factor"] || "").toLowerCase();
            const label = port ? port.description || port.name : device;
            const detail = sinks.length > 1 && port ? device : "";
            rows.push({
                key: sink.name + "/" + (port?.name || ""),
                sinkName: sink.name,
                portName: port?.name || "",
                label: label,
                detail: detail,
                description: (sink.description || device) + (port ? " · " + label : ""),
                activePort: !port || sink.active_port === port.name,
                symbol: ["headphone", "headphones", "headset"].includes(type) ? "headphones" : type === "speaker" ? "speaker" : type === "hdmi" ? "monitor" : "volume"
            });
        }
    }
    return rows;
}
