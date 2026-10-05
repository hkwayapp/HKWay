import Foundation

@main
struct MTRStationsChecks {
    static func main() throws {
        let csv = try String(contentsOfFile: "HK Way/Resources/MTRStations.csv", encoding: .utf8)
        let lines = ["TWL", "KTL", "ISL", "SIL", "TKL", "TCL", "AEL", "DRL", "EAL", "TML"]
        let membership = try MTRStations.stationLines(csv)
        precondition(membership["ADM"] == Set(["TWL", "ISL", "SIL", "EAL"]))
        precondition(membership["TAW"] == Set(["EAL", "TML"]))
        precondition(membership["NOP"] == Set(["ISL", "TKL"]))
        precondition(membership["TIK"] == Set(["KTL", "TKL"]))
        precondition(membership["TSY"] == Set(["AEL", "TCL"]))
        precondition(membership["LOW"] == Set(["EAL"]))
        precondition(membership["CEN"] == Set(["TWL", "ISL"])) // Do not merge HOK.
        precondition(membership["TST"] == Set(["TWL"])) // Do not merge ETS.
        precondition(membership.values.allSatisfy { $0.isSubset(of: Set(lines)) })
        var count = 0
        for line in lines {
            let patterns = try MTRStations.parse(csv, line: line)
            precondition(patterns.count == (["TKL", "EAL"].contains(line) ? 4 : 2))
            for pattern in patterns {
                precondition(pattern.stations.count >= 2)
                precondition(Set(pattern.stations.map(\.id)).count == pattern.stations.count)
                count += pattern.stations.count
            }
        }
        let east = try MTRStations.parse(csv, line: "EAL")
        precondition(east.first { $0.id == "UT" }!.stations.last!.id == "LOW")
        precondition(east.first { $0.id == "LMC-UT" }!.stations.last!.id == "LMC")
        precondition(east.allSatisfy { $0.stations.count == 14 })
        let tkl = try MTRStations.parse(csv, line: "TKL")
        precondition(tkl.first { $0.id == "TKS-UT" }!.stations.map(\.id) == ["TIK", "TKO", "LHP"])
        precondition(tkl.first { $0.id == "UT" }!.stations.last!.id == "POA")
        let airport = try MTRStations.parse(csv, line: "AEL")
        precondition(airport.first { $0.id == "UT" }!.stations.map(\.id) == ["HOK", "KOW", "TSY", "AIR", "AWE"])
        let tuenMa = try MTRStations.parse(csv, line: "TML")
        precondition(tuenMa.allSatisfy { $0.stations.count == 27 })
        do { _ = try MTRStations.parse(csv, line: "INVALID"); fatalError("Unknown line accepted") }
        catch MTRStations.DataError.missingLine {}
        print("PASS: 10 lines, 24 patterns, \(count) station entries, both branch pairs and numeric ordering.")
    }
}
