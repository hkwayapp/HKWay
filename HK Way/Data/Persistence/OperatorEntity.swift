//
//  OperatorEntity.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import Foundation
import SwiftData

@Model
final class OperatorEntity {

    @Attribute(.unique)
    var id: String

    var nameEnglish: String
    var nameSimplified: String
    var nameTraditional: String

    var routes: [RouteEntity] = []

    init(
        id: String,
        nameEnglish: String,
        nameSimplified: String,
        nameTraditional: String
    ) {
        self.id = id
        self.nameEnglish = nameEnglish
        self.nameSimplified = nameSimplified
        self.nameTraditional = nameTraditional
    }
}

extension OperatorEntity {

    func displayName(
        for language: TransitLanguage
    ) -> String {
        switch language {
        case .english:
            nameEnglish.transitDisplayName
        case .traditionalChinese:
            nameTraditional
        case .simplifiedChinese:
            nameSimplified
        }
    }
}
