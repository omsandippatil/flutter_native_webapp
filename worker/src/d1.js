// d1.js
// All D1 database queries in one place — no raw SQL anywhere else.
//
// Account queries:
//   getAccount(phone, db)      → row or null
//   upsertAccount(phone, hash, db)
//
// Profile queries:
//   getProfilesByPhone(phone, db) → array of profile rows
//   getProfile(profileId, db)     → single profile row or null
//
// Progress queries:
//   getProgress(profileId, db)    → progress row or null
//   upsertProgress(profileId, stepIndex, completedIds, db)
//
// Session queries:
//   insertSession(jti, phone, db)
//   revokeSession(jti, db)
//   isSessionRevoked(jti, db)     → boolean
