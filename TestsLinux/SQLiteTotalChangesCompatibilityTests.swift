import Foundation
import Testing

#if canImport(SQLite3)
import SQLite3
#elseif canImport(CSQLite3)
import CSQLite3
#endif

#if canImport(SQLite3) || canImport(CSQLite3)
/// `sqlite3_total_changes64` arrived in SQLite 3.37. Enterprise Linux 9 ships 3.34 and
/// resolves the call through the `CSQLite3` shim's 32-bit fallback instead. `CostUsageStore`
/// reads this counter to decide whether a write landed, so both paths must agree that it
/// advances on writes and holds still on reads.
@Suite
struct SQLiteTotalChangesCompatibilityTests {
    private static func totalChanges64(_ database: OpaquePointer) -> Int64 {
        #if canImport(SQLite3)
        sqlite3_total_changes64(database)
        #else
        codexbar_sqlite3_total_changes64(database)
        #endif
    }

    @Test
    func `the total changes counter advances on writes and holds still on reads`() throws {
        var handle: OpaquePointer?
        #expect(sqlite3_open(":memory:", &handle) == SQLITE_OK)
        let database = try #require(handle)
        defer { sqlite3_close(database) }
        #expect(sqlite3_exec(database, "CREATE TABLE rows (value INTEGER)", nil, nil, nil) == SQLITE_OK)

        let beforeInsert = Self.totalChanges64(database)
        #expect(sqlite3_exec(database, "INSERT INTO rows VALUES (1), (2), (3)", nil, nil, nil) == SQLITE_OK)
        let afterInsert = Self.totalChanges64(database)
        #expect(afterInsert == beforeInsert + 3)

        // Equality is what the store reads as "nothing was written", so a read must not move it.
        #expect(sqlite3_exec(database, "SELECT count(*) FROM rows", nil, nil, nil) == SQLITE_OK)
        #expect(Self.totalChanges64(database) == afterInsert)

        #expect(sqlite3_exec(database, "UPDATE rows SET value = value + 1", nil, nil, nil) == SQLITE_OK)
        #expect(Self.totalChanges64(database) == afterInsert + 3)
    }
}
#endif
