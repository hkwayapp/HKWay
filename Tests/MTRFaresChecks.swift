import Foundation

@main enum MTRFaresChecks {
    static func main() throws {
        let root = "HK Way/Resources/"
        let csv = try String(contentsOfFile: root + "MTRStations.csv", encoding: .utf8)
        let regular = try MTRStations.fareStations(csv, airportExpress: false)
        let airport = try MTRStations.fareStations(csv, airportExpress: true)
        let fares = try MTRFares.parse(String(contentsOfFile: root + "MTRAdultFares.csv", encoding: .utf8))
        let express = try MTRFares.parse(String(contentsOfFile: root + "AirportExpressAdultFares.csv", encoding: .utf8))
        precondition(fares.count == 9116 && express.count == 14)
        precondition(regular.first { $0.id == "HOK" }?.fareID == 39)
        precondition(airport.first { $0.id == "HOK" }?.fareID == 44)
        precondition(regular.first { $0.id == "KOW" }?.fareID == 40)
        precondition(airport.first { $0.id == "KOW" }?.fareID == 45)
        precondition(regular.first { $0.id == "TSY" }?.fareID == 42)
        precondition(airport.first { $0.id == "TSY" }?.fareID == 46)
        precondition(fares["1|2"]?.octopus == Decimal(string: "4.90"))
        precondition(fares["1|3"]?.singleJourney == Decimal(string: "12.50"))
        precondition(fares["1|1"] == nil && fares["1|39"] == nil && fares["3|80"] == nil)
        precondition(express["44|47"]?.octopus == 120)
        precondition(express["47|56"]?.octopus == Decimal(string: "6.5"))
        precondition(express["44|45"] == nil && express["39|47"] == nil)
        for (stations, table) in [(regular, fares), (airport, express)] {
            precondition(Set(stations.map(\.fareID)).count == stations.count)
            for origin in stations {
                let options = MTRFares.destinations(from: origin, stations: stations, fares: table)
                precondition(!options.isEmpty)
                precondition(options.allSatisfy { $0.id != origin.id && table[MTRFares.key(from: origin.fareID, to: $0.fareID)] != nil })
            }
        }
        for invalid in ["1,2,-4,5", "1,2,4.9x,5", "1,2,4,5\n1,2,4,5"] {
            do { _ = try MTRFares.parse("from,to,octopus,single\n" + invalid); fatalError("Accepted invalid data") }
            catch MTRFares.DataError.invalidRow { }
        }
        print("MTR fare checks passed: 9,116 regular pairs, 14 Airport Express pairs; station IDs, filtering and invalid data verified.")
    }
}
