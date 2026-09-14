#include <sqlite3.h>

// sqlite3_total_changes64 arrived in SQLite 3.37.0 (2021-11-27). Enterprise Linux 9
// ships 3.34.1, so fall back to the 32-bit counter there. Both values are only ever
// compared for inequality to detect that a write happened, so a wrap after 2^31
// changes on one connection costs a dropped cache entry, never a wrong result.
static inline sqlite3_int64 codexbar_sqlite3_total_changes64(sqlite3 *database) {
#if SQLITE_VERSION_NUMBER >= 3037000
    return sqlite3_total_changes64(database);
#else
    return (sqlite3_int64)sqlite3_total_changes(database);
#endif
}
