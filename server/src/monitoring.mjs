// Fixed-cardinality, process-local metrics. Never accept paths, actors or payloads.
export function createRequestMonitor() {
  let counts = {requests:0, unauthorized:0, forbidden:0, conflicts:0, limited:0, errors:0};
  return Object.freeze({
    observe(status) {
      counts.requests++;
      if(status===401) counts.unauthorized++;
      if(status===403) counts.forbidden++;
      if(status===409) counts.conflicts++;
      if(status===429) counts.limited++;
      if(status>=500 && status<=599) counts.errors++;
    },
    snapshot() { return Object.freeze({...counts}); },
    drain() { const snapshot = Object.freeze({...counts}); for(const key of Object.keys(counts)) counts[key]=0; return snapshot; },
  });
}
