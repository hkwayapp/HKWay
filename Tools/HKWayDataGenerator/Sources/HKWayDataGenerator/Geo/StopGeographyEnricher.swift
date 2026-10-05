struct StopGeographyEnricher {
    let boundaries: [DistrictBoundary]

    func enrich(_ stops: [Stop]) -> [Stop] {
        stops.map { stop in
            let boundary = boundaries.first {
                $0.contains(
                    latitude: stop.latitude,
                    longitude: stop.longitude
                )
            }

            return Stop(
                id: stop.id,
                nameEnglish: stop.nameEnglish,
                nameTraditional: stop.nameTraditional,
                nameSimplified: stop.nameSimplified,
                latitude: stop.latitude,
                longitude: stop.longitude,
                regionId: boundary?.regionId,
                districtId: boundary?.id
            )
        }
    }
}
