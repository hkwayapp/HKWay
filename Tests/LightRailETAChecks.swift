import Foundation

final class LightRailMockProtocol: URLProtocol {
    static var code = 200
    static var payload = Data()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        precondition(request.url?.query?.contains("station_id=430") == true)
        precondition(request.url?.query?.contains("with_special=0") == true)
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.code, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.payload)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main
struct LightRailETAChecks {
    static func main() async throws {
        let json = """
        {"status":1,"system_time":"2026-08-31 11:00:00","platform_list":[
          {"platform_id":1,"route_list":[
            {"route_no":"751","dest_en":"Tin Yat","dest_ch":"天逸","time_en":"2 mins","time_ch":"2 分鐘","arrival_departure":"A","stop":0,"special":0},
            {"route_no":"705","dest_en":"TSW Circular","dest_ch":"天水圍循環綫","time_en":"departing","arrival_departure":"D","stop":0},
            {"route_no":"751","dest_en":"Tin Yat","dest_ch":"天逸","time_en":"5 mins","special":1}]},
          {"platform_id":3,"route_list":[
            {"route_no":"751","dest_en":"Yau Oi","dest_ch":"友愛","time_en":"-","stop":1},
            {"route_no":"706","dest_en":"TSW Circular","dest_ch":"天水圍循環綫","time_en":"arriving","stop":0}]}
        ]}
        """
        let data = Data(json.utf8)
        let result = try JSONDecoder().decode(LightRailETAResponse.self, from: data)
        let allPlatforms = result.allRoutePlatforms
        precondition(allPlatforms.map(\.platform_id) == [1, 3])
        let allTrains = allPlatforms.flatMap { $0.route_list ?? [] }
        precondition(allTrains.count == 4)
        precondition(Set(allTrains.map(\.route_no)) == Set(["751", "705", "706"]))
        precondition(allTrains.filter { $0.route_no == "751" }.count == 2)
        let empty = try JSONDecoder().decode(LightRailETAResponse.self, from: Data("{\"status\":1}".utf8))
        precondition(empty.allRoutePlatforms.isEmpty)
        let tinYat = LightRailStop(stationID: 550, english: "Tin Yat", traditional: "天逸", simplified: "天逸")
        let filtered = result.platforms(routeID: "751", destination: tinYat, circular: false)
        precondition(filtered.count == 1 && filtered[0].platform_id == 1)
        precondition(filtered[0].route_list?.count == 1) // Excludes opposite & special routes.
        precondition(result.platforms(routeID: "705", destination: nil, circular: true).count == 1)
        precondition(result.platforms(routeID: "706", destination: nil, circular: true).first?.platform_id == 3)
        precondition(result.platforms(routeID: "505", destination: tinYat, circular: false).isEmpty)
        precondition(result.platform_list?[1].route_list?[0].time_en == "-")
        precondition(result.platform_list?[1].route_list?[0].stop == 1)
        let unavailable = try JSONDecoder().decode(LightRailETAResponse.self, from: Data("{\"status\":0}".utf8))
        precondition(unavailable.platforms(routeID: "751", destination: tinYat, circular: false).isEmpty)
        precondition(unavailable.allRoutePlatforms.isEmpty)
        precondition(result.timestamp == ISO8601DateFormatter().date(from: "2026-08-31T03:00:00Z"))
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [LightRailMockProtocol.self]
        let session = URLSession(configuration: config)
        LightRailMockProtocol.payload = data
        let fetched = try await LightRailETAService().fetch(stationID: 430, session: session)
        precondition(fetched.status == 1)
        LightRailMockProtocol.code = 429
        do {
            _ = try await LightRailETAService().fetch(stationID: 430, session: session)
            fatalError("HTTP failure must not become empty arrivals")
        } catch let error as URLError { precondition(error.code == .badServerResponse) }
        print("PASS: route/direction filtering, circular routes, special exclusion, platform IDs, API alerts, Hong Kong timestamp and HTTP failures.")
    }
}
