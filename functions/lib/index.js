"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.cleanupStaleQueue = exports.onMatchmakingWrite = void 0;
const admin = require("firebase-admin");
// تهيئة Firebase Admin مرة واحدة عند الإقلاع
admin.initializeApp();
var matchmaking_1 = require("./matchmaking");
Object.defineProperty(exports, "onMatchmakingWrite", { enumerable: true, get: function () { return matchmaking_1.onMatchmakingWrite; } });
Object.defineProperty(exports, "cleanupStaleQueue", { enumerable: true, get: function () { return matchmaking_1.cleanupStaleQueue; } });
//# sourceMappingURL=index.js.map