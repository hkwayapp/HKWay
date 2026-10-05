import Foundation

enum OperatorSelectionPreference {

    static let storageKey = "selectedOperatorIds"

    static func ids(from value: String) -> Set<String> {
        Set(
            value
                .split(separator: "\n")
                .flatMap {
                    $0.split(separator: "+")
                }
                .map(String.init)
        )
    }

    static func value(from ids: Set<String>) -> String {
        Set(
            ids.flatMap {
                $0.split(separator: "+")
                    .map(String.init)
            }
        )
        .sorted()
        .joined(separator: "\n")
    }
}
