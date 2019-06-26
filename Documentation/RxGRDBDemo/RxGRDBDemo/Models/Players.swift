import Action
import GRDB
import RxGRDB
import RxSwift

/// Players is responsible for high-level operations on the players database.
///
///
struct Players {
    private let database: DatabaseWriter
    
    init(database: DatabaseWriter) {
        self.database = database
    }
    
    // MARK: - Modify Players
    
    func deleteAll() -> Completable {
        // Erase the database writer type in an AnyDatabaseWriter, so that we
        // accept a DatabasePool in the app, a DatabaseQueue in tests, and also
        // have access to the RxGRDB APIs with the `rx` joiner defined on the
        // ReactiveCompatible protocol.
        //
        // TODO GRDB: If we define the `database` property as AnyDatabaseWriter
        // and erase the type in the initializer, we have a crash when the
        // database changes and observations are triggered. Workaround: perform
        // late type erasing.
        //
        // TODO RxRGDB: We could avoid this churn by exposing observables
        // without the `rx` joiner, directly on DatabaseWriter and
        // DatabaseReader protocols, as in GRDBCombine.
        return AnyDatabaseWriter(database).rx.write(updates: _deleteAll)
    }
    
    func refresh() -> Completable {
        return AnyDatabaseWriter(database).rx.write(updates: _refresh)
    }
    
    func stressTest() -> Completable {
        return Completable.zip(repeatElement(refresh(), count: 50))
    }
    
    // MARK: - Access Players
    
    /// An observable that tracks changes in any request of players
    func observeAll(_ request: QueryInterfaceRequest<Player>) -> Observable<[Player]> {
        return request.rx.observeAll(in: database)
    }
    
    // MARK: - Implementation
    //
    // Good practice: defining methods that accept a Database connection.
    // They can easily be composed in safe database transactions in our
    // high-level public methods.
    
    private func _deleteAll(_ db: Database) throws {
        _ = try Player.deleteAll(db)
    }
    
    private func _refresh(_ db: Database) throws {
        if try Player.fetchCount(db) == 0 {
            // Insert new random players
            for _ in 0..<8 {
                var player = Player(id: nil, name: Player.randomName(), score: Player.randomScore())
                try player.insert(db)
            }
        } else {
            // Insert a player
            if Bool.random() {
                var player = Player(id: nil, name: Player.randomName(), score: Player.randomScore())
                try player.insert(db)
            }
            // Delete a random player
            if Bool.random() {
                try Player.order(sql: "RANDOM()").limit(1).deleteAll(db)
            }
            // Update some players
            for var player in try Player.fetchAll(db) where Bool.random() {
                try player.updateChanges(db) {
                    $0.score = Player.randomScore()
                }
            }
        }
    }
}
