import SwiftUI

struct AirportBusView: View {
    @Environment(\.transitLanguage)
    private var transitLanguage

    @State private var isPopularAreasExpanded = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Please Select Route")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(AirportRouteCategory.allCases) { category in
                        NavigationLink {
                            AirportRouteAreaView(category: category)
                        } label: {
                            CustomInfoCardView(
                                title: category.title(
                                    for: transitLanguage
                                )
                            ) {
                                Text(verbatim: category.displayCode)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(localized(
                        "Airport buses departing from the airport",
                        "由機場開出的巴士",
                        "由机场开出的巴士"
                    ))
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Button {
                        withAnimation(.snappy) {
                            isPopularAreasExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.title3)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Popular Areas")
                                    .font(.headline)

                                Text(localized(
                                    "Use the locations below to filter routes that pass through them.",
                                    "使用下列地點篩選途經該處的路線。",
                                    "使用下列地点筛选途经该处的路线。"
                                ))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)

                            Image(systemName: "chevron.down")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                                .rotationEffect(
                                    .degrees(
                                        isPopularAreasExpanded ? 180 : 0
                                    )
                                )
                        }
                        .foregroundStyle(.primary)
                        .padding(16)
                        .contentShape(.rect)
                        .customInfoCardSurface(cornerRadius: 22)
                    }
                    .buttonStyle(.plain)

                    if isPopularAreasExpanded {
                        VStack(alignment: .leading, spacing: 12) {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(AirportPopularArea.allCases) { area in
                                    NavigationLink {
                                        AirportPopularAreaRouteListView(
                                            area: area
                                        )
                                    } label: {
                                        CustomInfoCardView(title: "") {
                                            VStack(spacing: 8) {
                                                Image(
                                                    systemName: area.systemImage
                                                )
                                                .font(.title2)

                                                Text(
                                                    area.title(
                                                        for: transitLanguage
                                                    )
                                                )
                                                .font(.headline)
                                                .multilineTextAlignment(.center)
                                            }
                                            .foregroundStyle(.primary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            Label(
                                localized(
                                    "Routes shown depart from the airport and call at one or more stops in the selected area.",
                                    "顯示的路線由機場開出，並會停靠所選地區的一個或多個巴士站。",
                                    "显示的路线由机场开出，并会停靠所选地区的一个或多个巴士站。"
                                ),
                                systemImage: "info.circle"
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                        }
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(
                                    with: .scale(
                                        scale: 0.96,
                                        anchor: .top
                                    )
                                ),
                                removal: .opacity.combined(
                                    with: .scale(
                                        scale: 0.98,
                                        anchor: .top
                                    )
                                )
                            )
                        )
                    }
                }
                .padding(.top, 12)
                .animation(
                    .snappy,
                    value: isPopularAreasExpanded
                )
            }
            .padding()
        }
        .navigationTitle(
            transitLanguage.localized("Airport Bus")
        )
        .navigationBarTitleDisplayMode(.inline)
    }

    private func localized(
        _ english: String,
        _ traditional: String,
        _ simplified: String
    ) -> String {
        transitLanguage.newsText(english, traditional, simplified)
    }
}

#Preview {
    NavigationStack {
        AirportBusView()
    }
}
