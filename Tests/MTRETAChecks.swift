import Foundation

final class MTRETAMockProtocol: URLProtocol {
    static var status = 200
    static var payload = Data()
    static var expectedLanguage = "EN"
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
        precondition(query.contains(URLQueryItem(name: "line", value: "TKL")))
        precondition(query.contains(URLQueryItem(name: "sta", value: "TKO")))
        precondition(query.contains(URLQueryItem(name: "lang", value: Self.expectedLanguage)))
        precondition(request.cachePolicy == .reloadIgnoringLocalCacheData)
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.payload)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main
struct MTRETAChecks {
    static func decode(_ json: String) throws -> MTRETAResponse {
        try JSONDecoder().decode(MTRETAResponse.self, from: Data(json.utf8))
    }

    static func main() async throws {
        let json = """
        {"status":1,"sys_time":"2026-08-31 23:59:00","isdelay":"N","data":{"TKL-TKO":{
        "sys_time":"2026-08-31 23:59:00",
        "UP":[
        {"seq":"2","dest":"POA","plat":"1","time":"2026-09-01 00:04:00","ttnt":"999","valid":"N"},
        {"seq":1,"dest":"LHP","plat":1,"time":"2026-09-01 00:01:00"},
        {"seq":"3","dest":"POA","plat":"1","time":"2026-08-31 23:58:00"}],
        "DOWN":[{"seq":"1","dest":"TIK","plat":"2","time":"2026-09-01 00:02:00"}]}}}
        """
        let result = try decode(json)
        let now = MTRClock.date("2026-08-31 23:59:00")!
        let station = result.station(line: "TKL", code: "TKO")!
        let up = station.trains(direction: .up, now: now)
        precondition(up.map(\.dest) == ["LHP", "POA"]) // Preserve both branches; exclude old prediction.
        precondition(up[0].platform == "1" && up[1].platform == "1")
        precondition(up[0].date!.timeIntervalSince(now) == 120) // Midnight rollover, HK time.
        precondition(up[0].date == ISO8601DateFormatter().date(from: "2026-08-31T16:01:00Z"))
        precondition(station.trains(direction: .down, now: now).map(\.dest) == ["TIK"])
        precondition(result.station(line: "EAL", code: "TKO") == nil)
        precondition(result.updatedAt(line: "TKL", code: "TKO") == now)
        precondition(MTRTravelDirection(patternID: "LMC-UT") == .up)
        precondition(MTRTravelDirection(patternID: "TKS-DT") == .down)
        precondition(MTRTravelDirection(patternID: "UT") == .up)

        let east = try decode("""
        {"status":"1","data":{"EAL-SHT":{"UP":[
        {"seq":"1","dest":"RAC","plat":"3","time":"-","timetype":"D","route":"RAC"},
        {"seq":"2","dest":"SHS","plat":"3","time":"2026-09-01 00:05:00","timetype":"A"}]}}}
        """)
        let eastTrains = east.station(line: "EAL", code: "SHT")!.trains(direction: .up, now: now)
        precondition(eastTrains.count == 2 && eastTrains[0].viaRacecourse)
        precondition(eastTrains[0].date == nil && eastTrains[0].timetype == "D")
        precondition(eastTrains[1].dest == "SHS") // Short working is not discarded.
        let absent = try decode("{\"status\":1,\"isdelay\":\"Y\",\"data\":{\"TKL-TKO\":{\"sys_time\":\"-\"}}}")
        precondition(absent.station(line: "TKL", code: "TKO")!.trains(direction: .up, now: now).isEmpty)
        precondition(absent.isdelay == "Y" && absent.updatedAt(line: "TKL", code: "TKO") == nil)
        let alert = try decode("{\"status\":0,\"message\":\"Service suspended\",\"url\":\"https://www.mtr.com.hk/alert/test.html\"}")
        precondition(alert.station(line: "TKL", code: "TKO") == nil && alert.serviceNoticeURL != nil)
        let unsafe = try decode("{\"status\":0,\"url\":\"https://mtr.com.hk.example.com/alert\"}")
        precondition(unsafe.serviceNoticeURL == nil)
        precondition(station.trains(direction: .up, now: now.addingTimeInterval(600)).isEmpty)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MTRETAMockProtocol.self]
        let session = URLSession(configuration: config)
        MTRETAMockProtocol.payload = Data(json.utf8)
        let english = try await MTRETAService().fetch(line: "TKL", station: "TKO", chinese: false, session: session)
        precondition(english.status == 1)
        MTRETAMockProtocol.expectedLanguage = "TC"
        _ = try await MTRETAService().fetch(line: "TKL", station: "TKO", chinese: true, session: session)
        MTRETAMockProtocol.status = 429
        do {
            _ = try await MTRETAService().fetch(line: "TKL", station: "TKO", chinese: true, session: session)
            fatalError("HTTP 429 must not become empty arrivals")
        } catch let error as URLError { precondition(error.code == .badServerResponse) }
        MTRETAMockProtocol.status = 200
        MTRETAMockProtocol.payload = Data("invalid JSON".utf8)
        do {
            _ = try await MTRETAService().fetch(line: "TKL", station: "TKO", chinese: true, session: session)
            fatalError("Malformed JSON accepted")
        } catch is DecodingError {}
        print("PASS: MTR direction/branch preservation, numeric/string fields, HK midnight times, expired trains, Racecourse, alerts, empty data, language and HTTP/JSON failures.")

        if CommandLine.arguments.contains("--live") {
            for (line, code) in [("TWL", "ADM"), ("EAL", "SHT"), ("TKL", "TKO")] {
                let live = try await MTRETAService().fetch(line: line, station: code, chinese: false)
                precondition(live.status == 0 || live.status == 1)
                if live.status == 1 {
                    precondition(live.station(line: line, code: code) != nil)
                }
                print("LIVE: \(line)-\(code) response decoded, status \(live.status).")
            }
        }
    }
}
