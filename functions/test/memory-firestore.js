"use strict";

class MemoryFirestore {
  constructor() {
    this.documents = new Map();
    this.tail = Promise.resolve();
  }

  seed(path, data) { this.documents.set(path, structuredClone(data)); }
  read(path) { return structuredClone(this.documents.get(path)); }

  snapshot(path) {
    const data = this.read(path);
    return { id: path.split("/").at(-1), exists: data !== undefined, data: () => structuredClone(data) };
  }

  doc(path) {
    return { path, get: async () => this.snapshot(path) };
  }

  collection(path) {
    const filters = [];
    let cursor;
    let limit = Infinity;
    const query = {
      where: (field, operator, value) => {
        if (operator !== "==") throw new Error("Unsupported test query operator");
        filters.push({ field, value });
        return query;
      },
      startAfter: (snapshot) => { cursor = snapshot.id; return query; },
      limit: (maximum) => { limit = maximum; return query; },
      get: async () => {
        const docs = [...this.documents.entries()]
          .filter(([key, data]) => key.startsWith(`${path}/`) &&
            key.split("/").length === path.split("/").length + 1 &&
            filters.every(({ field, value }) => data[field] === value))
          .sort(([a], [b]) => a.localeCompare(b))
          .filter(([key]) => !cursor || key.split("/").at(-1) > cursor)
          .slice(0, limit)
          .map(([key]) => this.snapshot(key));
        return { docs, size: docs.length };
      },
    };
    return query;
  }

  async runTransaction(callback) {
    // Serialize commits like a retrying Firestore transaction. The fake enforces
    // read-before-write and only applies writes when the callback succeeds.
    const previous = this.tail;
    let release;
    this.tail = new Promise((resolve) => { release = resolve; });
    await previous;
    const writes = [];
    try {
      const transaction = {
        get: async (ref) => {
          if (writes.length) throw new Error("Firestore cannot read after a transaction write");
          return this.snapshot(ref.path);
        },
        set: (ref, data, options) => writes.push({ path: ref.path, data: structuredClone(data), merge: options?.merge }),
      };
      const result = await callback(transaction);
      for (const write of writes) {
        this.seed(write.path, write.merge ? { ...this.read(write.path), ...write.data } : write.data);
      }
      return result;
    } finally { release(); }
  }
}

module.exports = { MemoryFirestore };
