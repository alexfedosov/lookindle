import ArgumentParser
import SQLite

enum LookindleError: Error {
    case UnexpectedError
}

struct Lookup {
    let word: String
    let stem: String
    let usage: String

    init(tuple: [Binding?]) throws {
        guard tuple.count == 3,
              let word = tuple[0] as? String,
              let stem = tuple[1] as? String,
              let usage = tuple[2] as? String
                  else { throw LookindleError.UnexpectedError }
       self.word = word
       self.stem = stem
       self.usage = usage
    }
}

@main
struct Lookindle: ParsableCommand {
    @Option(help: "Name of your kindle usb drivce when its mounted, default is \"Kindle\"")
    var kindleName: String?

    @Argument(help: "Lookup language, for instance \"en\" or \"sv\"")
    var lang: String

    var volumeName: String { get { kindleName ?? "Kindle" } }

    mutating func run() throws {
        let db: Connection
        do {
            db = try Connection("/Volumes/\(volumeName)/system/vocabulary/vocab.db")
        } catch {
            print("Unable to open vocabulary database on \(volumeName)")
            print("Here what you can try next:")
            if let name = kindleName {
                print("- Make sure \"\(name)\" is the actual name of your kindle device")
                print("- You can also try to run it without --kindle-name")
            }
            print("- Make sure your kindle is connected")
            return
        }
        let result = try db.prepare("""
                SELECT WORDS.word, WORDS.stem, usage FROM LOOKUPS
                JOIN WORDS ON WORDS.id = word_key
                WHERE LOOKUPS.word_key LIKE '\(lang):' || '%'
                ORDER BY LOOKUPS.timestamp desc
                LIMIT 10;
                """)
        let lookups: [Lookup] = result.compactMap { tuple in
            return try? Lookup(tuple: tuple)
        }
        var wordWidth = 0
        var stemWidth = 0
        for lookup in lookups {
            wordWidth = max(wordWidth, lookup.word.count)
            stemWidth = max(stemWidth, lookup.stem.count)
        }

        for lookup in lookups {
            var line = lookup.word.padding(toLength: wordWidth, withPad: " ", startingAt: 0)
            line += " | "
            line += lookup.stem.padding(toLength: stemWidth, withPad: " ", startingAt: 0)
            line += " | "
            line += lookup.usage
            print(line)
        }

    }
}
