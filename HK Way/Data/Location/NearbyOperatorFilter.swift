import Foundation

enum NearbyOperatorFilter: Equatable {
    case preferences
    case all
    case selected(Set<String>)

    func includes(_ operators: Set<String>, preferences: Set<String>) -> Bool {
        switch self {
        case .all: return true
        case .preferences: return preferences.isEmpty || !operators.isDisjoint(with: preferences)
        case .selected(let selection): return !operators.isDisjoint(with: selection)
        }
    }

    func isSelected(_ operatorID: String) -> Bool {
        if case .selected(let selection) = self { return selection.contains(operatorID) }
        return false
    }

    mutating func toggle(_ operatorID: String) {
        var selection: Set<String> = []
        if case .selected(let current) = self { selection = current }
        if selection.contains(operatorID) { selection.remove(operatorID) }
        else { selection.insert(operatorID) }
        self = selection.isEmpty ? .all : .selected(selection)
    }
}
