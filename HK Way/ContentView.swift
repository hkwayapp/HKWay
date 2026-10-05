//
//  ContentView.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {

    @Environment(PurchaseManager.self)
    private var purchaseManager

    @Environment(\.modelContext)
    private var modelContext

    @State
    private var bootstrapFinished = false

    @State
    private var minimumGreetingDurationElapsed = false

    @State
    private var bootstrapError: Error?

    @State private var loadingWeather = LoadingWeatherStore()
    @State private var journeyAlertManager = JourneyAlertManager.shared

    @AppStorage(FirstRunSetupView.completionStorageKey)
    private var hasCompletedFirstRunSetup = false

    @AppStorage(WhatsNewView.appleTVAnnouncementStorageKey)
    private var hasSeenAppleTVAnnouncement = false

    @State
    private var isWhatsNewPresented = false

    @State
    private var selectedTab: AppTab

    @State
    private var favoritesNavigationID = 0

    @State
    private var nearbyNavigationID = 0

    @State
    private var searchNavigationID = 0

    @State
    private var searchKeyboardActivationID = 0

    @State
    private var dashboardNavigationID = 0

    @State
    private var isNavigationMenuPresented = false

    @State
    private var sideMenuDestination: SideMenuDestination?

    @State
    private var widgetRoute: RouteEntity?

    @State
    private var pendingWidgetRouteId: String?

    @State
    private var pendingExternalURL: URL?

    @State
    private var isExternalLinkWarningPresented = false

    @AppStorage("appLanguage")
    private var selectedLanguage = TransitLanguage.traditionalChinese.rawValue

    @AppStorage("appAccessTier.v1")
    private var accessTierValue = AppAccessTier.free.rawValue

    @AppStorage(AppAppearance.storageKey)
    private var selectedAppearance = AppAppearance.system.rawValue

    private var appLanguage: TransitLanguage {
        TransitLanguage(
            preferenceValue: selectedLanguage
        )
    }

    private var datasetLoadErrorDescription: String {
        switch appLanguage {
        case .english:
            "Unable to prepare the transit dataset. Please try again."
        case .traditionalChinese:
            "未能準備交通資料集，請再試一次。"
        case .simplifiedChinese:
            "无法准备交通数据集，请重试。"
        }
    }

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == selectedTab {
                    resetNavigation(for: newTab)
                } else {
                    selectedTab = newTab
                }
            }
        )
    }

    init() {
        let storedValue = UserDefaults.standard.string(
            forKey: DefaultAppTab.storageKey
        )
        let defaultTab = DefaultAppTab(
            rawValue: storedValue ?? ""
        ) ?? .nearby

        _selectedTab = State(
            initialValue: UIDevice.current.userInterfaceIdiom == .pad
                ? .dashboard
                : defaultTab.appTab
        )
    }

    var body: some View {

        Group {

            if !minimumGreetingDurationElapsed {

                loadingScreen

            } else if !hasCompletedFirstRunSetup {

                FirstRunSetupView(
                    isDatasetReady: bootstrapFinished,
                    datasetLoadFailed: bootstrapError != nil
                ) {
                        let storedValue = UserDefaults.standard.string(
                            forKey: DefaultAppTab.storageKey
                        )
                        selectedTab = UIDevice.current.userInterfaceIdiom == .pad
                            ? .dashboard
                            : DefaultAppTab(
                                rawValue: storedValue ?? ""
                            )?.appTab ?? .nearby
                        hasCompletedFirstRunSetup = true
                    }

            } else if bootstrapFinished {

                mainTabView

            } else if bootstrapError != nil {

                CustomCardView(
                    imageIcon: "exclamationmark.triangle",
                    title: "Dataset Error",
                    subTitle: datasetLoadErrorDescription,
                    animated: true
                )

            } else {

                loadingScreen
            }
        }
        .environment(
            \.transitLanguage,
            appLanguage
        )
        .environment(\.locale, appLanguage.locale)
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme != "hkway" else { return .systemAction }
            pendingExternalURL = ExternalLinkLocalizer.url(
                url,
                for: appLanguage
            )
            isExternalLinkWarningPresented = true
            return .handled
        })
        .preferredColorScheme(
            AppAppearance(rawValue: selectedAppearance)?
                .colorScheme
        )
        .onOpenURL(perform: openWidgetURL)
        .task {
            WatchSyncManager.shared.activate()
            WatchSyncManager.shared.syncSnapshots(
                TransitWidgetSnapshotStore.load()
            )
        }
        .task { await loadingWeather.refresh() }
        .task {
            guard !minimumGreetingDurationElapsed else { return }
            try? await Task.sleep(for: .seconds(1))
            minimumGreetingDurationElapsed = true
        }
        .alert("Leave HK Way?", isPresented: $isExternalLinkWarningPresented) {
            Button("Cancel", role: .cancel) {
                pendingExternalURL = nil
            }
            Button("Continue") {
                guard let url = pendingExternalURL else { return }
                pendingExternalURL = nil
                UIApplication.shared.open(url)
            }
        } message: {
            Text("This link will open outside HK Way. Do you want to continue?")
        }
        .task(id: "\(selectedLanguage)|\(accessTierValue)") {
            TransitWidgetSnapshotStore.setLanguage(appLanguage)
            TransitWidgetSnapshotStore.setAccessTier(
                AppAccessTier(rawValue: accessTierValue) ?? .free
            )
        }
        .sheet(item: $widgetRoute) { route in
            NavigationStack {
                RouteDetailView(route: route)
            }
            .environment(\.transitLanguage, appLanguage)
            .environment(\.locale, appLanguage.locale)
        }
        .sheet(
            isPresented: $isWhatsNewPresented,
            onDismiss: { hasSeenAppleTVAnnouncement = true }
        ) {
            WhatsNewView(language: appLanguage) {
                hasSeenAppleTVAnnouncement = true
                isWhatsNewPresented = false
            }
        }
        .task(id: "\(hasCompletedFirstRunSetup)|\(bootstrapFinished)|\(hasSeenAppleTVAnnouncement)") {
            guard hasCompletedFirstRunSetup,
                  bootstrapFinished,
                  !hasSeenAppleTVAnnouncement else { return }
            isWhatsNewPresented = true
        }
        .task {
            guard !bootstrapFinished else {
                return
            }

            do {

                try await DatasetBootstrapper().bootstrap(
                    modelContext: modelContext
                )

                bootstrapFinished = true
                resolvePendingWidgetRoute()

            } catch {

                bootstrapError = error

                print(
                    "App bootstrap failed:",
                    error
                )
            }
        }
    }

    private var loadingScreen: some View {
        ZStack {
            Image(loadingBackgroundImageName)
                .resizable()
                .scaledToFill()
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.58), .black.opacity(0.18), .black.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .clipped()
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "tram.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text(loadingAppName)
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    Text(loadingTagline)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.78))
                }

                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                    .padding(.top, 8)

                VStack(spacing: 5) {
                    Text(loadingTitle)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(loadingDetail)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            VStack {
                HStack(spacing: 10) {
                    Image(systemName: loadingWeather.symbol)
                    if let temperature = loadingWeather.temperature {
                        Text("\(Int(temperature.rounded()))°C")
                    }
                    if let humidity = loadingWeather.humidity {
                        Text("\(Int(humidity.rounded()))%")
                    }
                    Text(loadingWeather.condition(for: appLanguage))
                        .lineLimit(1)
                    if let warning = displayedWeatherWarning {
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .lineLimit(1)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.black.opacity(0.25), in: Capsule())
                .padding(.top, 18)
                Spacer()
                VStack(spacing: 4) {
                    Text(loadingGreeting)
                        .font(.title2.weight(.semibold))
                    Text(loadingAppName)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .foregroundStyle(.white)
                .padding(.bottom, 44)
            }
        }
    }

    private var loadingBackgroundImageName: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<11: "HKPersonalSunny01"
        case 11..<17: "HKPersonalSunny05"
        case 17..<20: "HKPersonalSunset01"
        default: "HKPersonalNight01"
        }
    }

    private var festivalGreeting: String? {
        var solar = Calendar(identifier: .gregorian)
        solar.timeZone = TimeZone(identifier: "Asia/Hong_Kong") ?? .current
        let solarDate = solar.dateComponents([.month, .day], from: .now)

        switch (solarDate.month, solarDate.day) {
        case (1, 1):
            return appLanguage.newsText("Happy New Year · Travel well in the year ahead.", "新年快樂！新一年，出行順順利利。", "新年快乐 · 新的一年，出行顺顺利利。")
        case (7, 1):
            return appLanguage.newsText("Happy HKSAR Day · Enjoy the city.", "回歸紀念日快樂！去邊都順順利利。", "回归纪念日快乐 · 出行顺顺利利。")
        case (10, 1):
            return appLanguage.newsText("Happy National Day · Enjoy the holiday.", "國慶快樂！假日出行，路上見。", "国庆快乐 · 假日出行，路上见。")
        case (12, 25), (12, 26):
            return appLanguage.newsText("Merry Christmas · Enjoy the festive city.", "聖誕快樂！出街玩，路上見。", "圣诞快乐 · 出街玩，路上见。")
        default:
            break
        }

        var lunar = Calendar(identifier: .chinese)
        lunar.timeZone = solar.timeZone
        let lunarDate = lunar.dateComponents([.month, .day, .isLeapMonth], from: .now)
        guard lunarDate.isLeapMonth != true else { return nil }

        switch (lunarDate.month, lunarDate.day) {
        case (1, 1), (1, 2), (1, 3):
            return appLanguage.newsText("Happy Lunar New Year · Wishing you smooth journeys.", "恭喜發財！出入平安，行程順順利利。", "恭喜发财 · 出入平安，行程顺顺利利。")
        case (1, 15):
            return appLanguage.newsText("Happy Lantern Festival · Enjoy the evening.", "元宵快樂！今晚出街，慢慢行。", "元宵快乐 · 今晚出街，慢慢走。")
        case (5, 5):
            return appLanguage.newsText("Happy Dragon Boat Festival · Travel well.", "端午安康！出街食糉，旅程順順利利。", "端午安康 · 出行顺顺利利。")
        case (8, 15):
            return appLanguage.newsText("Happy Mid-Autumn Festival · Enjoy the moonlight.", "中秋快樂！賞月食餅，出行順順利利。", "中秋快乐 · 赏月吃月饼，出行顺顺利利。")
        case (9, 9):
            return appLanguage.newsText("Happy Chung Yeung Festival · Travel safely.", "重陽節快樂！出入平安。", "重阳节快乐 · 出入平安。")
        default:
            return nil
        }
    }

    private var weatherGreeting: String? {
        if let warning = loadingWeather.warning(for: appLanguage) {
            return appLanguage.newsText(
                "\(warning) · Please take care on your journey.",
                "\(warning)！出街小心，慢慢行。",
                "\(warning) · 出行请注意安全。"
            )
        }
        if loadingWeather.isThunderstorm {
            return appLanguage.newsText(
                "Thunderstorms nearby · Take care on the way.",
                "有雷暴呀！出街小心，慢慢行。",
                "有雷暴 · 出行请注意安全。"
            )
        }
        if loadingWeather.isRainy {
            return appLanguage.newsText(
                "Rainy outside · Remember an umbrella.",
                "落雨呀！記得帶遮。",
                "下雨啦 · 记得带伞。"
            )
        }
        if loadingWeather.isHot {
            return appLanguage.newsText(
                "It’s hot today · Keep hydrated on the way.",
                "天氣熱呀！記得飲多啲水。",
                "天气炎热 · 记得多喝水。"
            )
        }
        if loadingWeather.isWindy {
            return appLanguage.newsText(
                "Windy today · Take care outdoors.",
                "風大呀！出街小心。",
                "风大 · 出门小心。"
            )
        }
        if loadingWeather.isSunny {
            return appLanguage.newsText(
                "Sunny today · Enjoy the journey.",
                "天氣咁好！去邊都得。",
                "天气真好 · 去哪都行。"
            )
        }
        return nil
    }

    private var loadingGreeting: String {
        if let festivalGreeting { return festivalGreeting }
        if let weatherGreeting { return weatherGreeting }
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12:
            return appLanguage.newsText(
                "Good morning · Where would you like to go?",
                "\u{65e9}\u{6668}\u{ff01}\u{4eca}\u{65e5}\u{60f3}\u{53bb}\u{908a}\u{5ea6}\u{ff1f}",
                "\u{65e9}\u{4e0a}\u{597d} · \u{4eca}\u{5929}\u{60f3}\u{53bb}\u{54ea}\u{91cc}\u{ff1f}"
            )
        case 12..<18:
            return appLanguage.newsText(
                "Good afternoon · Where would you like to go?",
                "\u{664f}\u{665d}\u{597d}\u{ff01}\u{4eca}\u{65e5}\u{60f3}\u{53bb}\u{908a}\u{5ea6}\u{ff1f}",
                "\u{4e0b}\u{5348}\u{597d} · \u{4eca}\u{5929}\u{60f3}\u{53bb}\u{54ea}\u{91cc}\u{ff1f}"
            )
        default:
            return appLanguage.newsText(
                "Good evening · Where would you like to go?",
                "\u{591c}\u{665a}\u{597d}\u{ff01}\u{4eca}\u{665a}\u{60f3}\u{53bb}\u{908a}\u{5ea6}\u{ff1f}",
                "\u{665a}\u{4e0a}\u{597d} · \u{4eca}\u{5929}\u{60f3}\u{53bb}\u{54ea}\u{91cc}\u{ff1f}"
            )
        }
    }

    private var displayedWeatherWarning: String? {
        loadingWeather.warning(for: appLanguage)
    }

    private var mainTabView: some View {
        ZStack(alignment: .leading) {
            if UIDevice.current.userInterfaceIdiom == .pad {
                tabs
            } else {
                iphoneTabContent
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        customTabBar
                    }
            }

            if isNavigationMenuPresented {
                Color.black.opacity(0.22)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissNavigationMenu()
                    }
                    .transition(.opacity)

                GeometryReader { proxy in
                    MoreView(
                        onClose: dismissNavigationMenu,
                        onSelectTab: selectTabFromNavigationMenu,
                        onSelectDestination: selectDestinationFromNavigationMenu
                    )
                        .frame(
                            width: min(proxy.size.width * 0.8, 430),
                            height: proxy.size.height,
                            alignment: .leading
                        )
                        .background(Color(uiColor: .systemBackground))
                        .clipShape(
                            UnevenRoundedRectangle(
                                bottomTrailingRadius: 24,
                                topTrailingRadius: 24
                            )
                        )
                        .shadow(color: .black.opacity(0.22), radius: 18, x: 8)
                        .transition(.move(edge: .leading))
                        .zIndex(1)
                }
                .ignoresSafeArea()
                .transition(.move(edge: .leading))
                .zIndex(1)
            }
            if journeyAlertManager.isTracking {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            sideMenuDestination = nil
                            tabSelection.wrappedValue = .favorites
                        } label: {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 34, height: 34)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay {
                                    Circle()
                                        .stroke(Color.accentColor.opacity(0.28), lineWidth: 1)
                                }
                                .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("View active stop alert")
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, UIDevice.current.userInterfaceIdiom == .pad ? 20 : 78)

            }
        }
        .animation(.snappy(duration: 0.32), value: isNavigationMenuPresented)
        .simultaneousGesture(navigationMenuDragGesture)
    }

    @ViewBuilder
    private var iphoneTabContent: some View {
        if let sideMenuDestination {
            NavigationStack {
                SideMenuDestinationView(destination: sideMenuDestination)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: presentNavigationMenu) {
                                Image(systemName: "line.3.horizontal")
                            }
                            .accessibilityLabel("Menu")
                        }
                    }
            }
            .id(sideMenuDestination.id)
        } else {
            switch selectedTab {
            case .favorites:
                NavigationStack {
                    RouteFavoritesView(
                        isFavoritesActive: true,
                        onMenuTap: presentNavigationMenu
                    )
                }
                .id(favoritesNavigationID)

            case .nearby:
                NearbyRouteListView(
                    isNearbyTabSelected: true,
                    onMenuTap: presentNavigationMenu
                )
                .id(nearbyNavigationID)

            case .search:
                RouteListView(
                    isSearchTabSelected: true,
                    keyboardActivationID: searchKeyboardActivationID,
                    onMenuTap: presentNavigationMenu
                )
                .id(searchNavigationID)

            default:
                NearbyRouteListView(
                    isNearbyTabSelected: true,
                    onMenuTap: presentNavigationMenu
                )
                .id(nearbyNavigationID)
            }
        }
    }

    private var customTabBar: some View {
        HStack(spacing: 14) {
            HStack(spacing: 4) {
                customTabButton(
                    tab: .favorites,
                    systemImage: "bookmark"
                )

                customTabButton(
                    tab: .nearby,
                    systemImage: "location.fill"
                )
            }
            .padding(5)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.primary.opacity(0.12), lineWidth: 0.5)
            }

            Spacer(minLength: 18)

            customTabButton(
                tab: .search,
                systemImage: "magnifyingglass",
                isDetached: true,
                onDoubleTap: activateSearchFrontPage
            )
            .padding(5)
            .background(.ultraThinMaterial, in: Circle())
            .overlay {
                Circle()
                    .stroke(.primary.opacity(0.12), lineWidth: 0.5)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func customTabButton(
        tab: AppTab,
        systemImage: String,
        isDetached: Bool = false,
        onDoubleTap: (() -> Void)? = nil
    ) -> some View {
        Button {
            sideMenuDestination = nil
            tabSelection.wrappedValue = tab
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .symbolVariant(tab == .favorites ? .none : .fill)
                .foregroundStyle(selectedTab == tab ? Color.accentColor : .primary)
                .frame(
                    width: isDetached ? 44 : 52,
                    height: 44
                )
                .background {
                    if selectedTab == tab {
                        if isDetached {
                            Circle().fill(Color.accentColor.opacity(0.13))
                        } else {
                            Capsule().fill(Color.accentColor.opacity(0.13))
                        }
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    onDoubleTap?()
                }
        )
        .accessibilityLabel(customTabAccessibilityLabel(for: tab))
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }

    private func customTabAccessibilityLabel(for tab: AppTab) -> String {
        switch tab {
        case .favorites:
            appLanguage.localized("Favorites")
        case .nearby:
            appLanguage.localized("Nearby")
        case .search:
            appLanguage.localized("Search")
        default:
            ""
        }
    }

    private var navigationMenuDragGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .global)
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = abs(value.translation.height)

                guard abs(horizontalDistance) > verticalDistance else { return }

                if isNavigationMenuPresented {
                    if horizontalDistance < -55 {
                        dismissNavigationMenu()
                    }
                } else if value.startLocation.x < 28,
                          horizontalDistance > 55 {
                    presentNavigationMenu()
                }
            }
    }

    private var tabs: some View {
        TabView(selection: tabSelection) {
            if UIDevice.current.userInterfaceIdiom == .pad {
                Tab(value: .dashboard) {
                    NavigationStack {
                        IPadDashboardView()
                    }
                    .id(dashboardNavigationID)
                } label: {
                    Image(systemName: "house.fill")
                        .accessibilityLabel("Home")
                }
            }

            Tab(value: .favorites) {
                NavigationStack {
                    RouteFavoritesView(
                        isFavoritesActive: selectedTab == .favorites,
                        onMenuTap: presentNavigationMenu
                    )
                }
                .id(favoritesNavigationID)
            } label: {
                Image(systemName: "bookmark")
                    .font(.system(size: 14, weight: .medium))
                    .symbolVariant(.none)
                    .accessibilityLabel("Favorites")
            }

            Tab(value: .nearby) {
                NearbyRouteListView(
                    isNearbyTabSelected: selectedTab == .nearby,
                    onMenuTap: presentNavigationMenu
                )
                .id(nearbyNavigationID)
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 14, weight: .medium))
                    .accessibilityLabel("Nearby")
            }

            Tab(value: .search, role: .search) {
                RouteListView(
                    isSearchTabSelected: selectedTab == .search,
                    onMenuTap: presentNavigationMenu
                )
                .id(searchNavigationID)
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .accessibilityLabel("Search")
            }
        }
        .toolbarBackground(.automatic, for: .tabBar)
    }

    private func presentNavigationMenu() {
        isNavigationMenuPresented = true
    }

    private func dismissNavigationMenu() {
        isNavigationMenuPresented = false
    }

    private func activateSearchFrontPage() {
        sideMenuDestination = nil
        selectedTab = .search
        searchNavigationID += 1
        searchKeyboardActivationID += 1
    }

    private func selectTabFromNavigationMenu(_ tab: AppTab) {
        sideMenuDestination = nil
        selectedTab = tab
        dismissNavigationMenu()
    }

    private func selectDestinationFromNavigationMenu(
        _ destination: SideMenuDestination
    ) {
        sideMenuDestination = destination
        dismissNavigationMenu()
    }

    private var loadingTagline: String {
        switch appLanguage {
        case .english: "Your guide to public transport across Hong Kong"
        case .traditionalChinese: "HK Way・你的香港公共交通指南"
        case .simplifiedChinese: "HK Way・你的香港公共交通指南"
        }
    }

    private var loadingAppName: String {
        switch appLanguage {
        case .english: "HK Way"
        case .traditionalChinese, .simplifiedChinese: "喂!香港"
        }
    }

    private var loadingTitle: String {
        switch appLanguage {
        case .english: "Preparing routes, stops and arrival information…"
        case .traditionalChinese: "正在準備路線、車站及到站資訊⋯"
        case .simplifiedChinese: "正在准备路线、车站及到站资讯…"
        }
    }

    private var loadingDetail: String {
        switch appLanguage {
        case .english: "The first setup may take a few minutes."
        case .traditionalChinese: "首次設定可能需時數分鐘。"
        case .simplifiedChinese: "首次设置可能需要几分钟。"
        }
    }

    private func openWidgetURL(_ url: URL) {
        guard url.scheme == "hkway" else { return }

        if url.host == "stop-alert" {
            sideMenuDestination = nil
            tabSelection.wrappedValue = .favorites
            return
        }

        guard
            url.host == "route",
            let routeId = url.pathComponents.dropFirst().first
        else {
            return
        }

        pendingWidgetRouteId = routeId
        resolvePendingWidgetRoute()
    }

    private func resolvePendingWidgetRoute() {
        guard bootstrapFinished, let routeId = pendingWidgetRouteId else {
            return
        }

        var descriptor = FetchDescriptor<RouteEntity>(
            predicate: #Predicate { $0.id == routeId }
        )
        descriptor.fetchLimit = 1
        widgetRoute = try? modelContext.fetch(descriptor).first
        pendingWidgetRouteId = nil
    }

    private func resetNavigation(for tab: AppTab) {
        switch tab {
        case .dashboard:
            dashboardNavigationID += 1
        case .favorites:
            favoritesNavigationID += 1
        case .nearby:
            nearbyNavigationID += 1
        case .search:
            searchNavigationID += 1
        case .more, .settings:
            break
        }
    }

}

struct GlobalWeatherStrip: View {
    @Environment(\.transitLanguage) private var language
    @State private var weather = LoadingWeatherStore()
    var usesWeatherAwareBackground = false

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: weather.symbol)
            if let temperature = weather.temperature {
                Text("\(Int(temperature.rounded()))°")
            }
            if let humidity = weather.humidity {
                Text("\(Int(humidity.rounded()))%")
            }
            Text(weather.condition(for: language))
                .lineLimit(1)
            if weather.warning(for: language) != nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)

                if usesWeatherAwareBackground {
                    LinearGradient(
                        colors: weatherTintColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        }
        .accessibilityElement(children: .combine)
        .task { await weather.refresh() }
    }

    private var weatherTintColors: [Color] {
        switch weather.symbol {
        case "sun.max.fill":
            [.yellow.opacity(0.12), .orange.opacity(0.07)]
        case "cloud.rain.fill", "cloud.bolt.rain.fill":
            [.blue.opacity(0.11), .cyan.opacity(0.06)]
        case "wind":
            [.teal.opacity(0.10), .mint.opacity(0.05)]
        default:
            [.indigo.opacity(0.07), .gray.opacity(0.04)]
        }
    }
}

enum AppTab: String, Hashable {
    case dashboard
    case favorites
    case nearby
    case search
    case more
    case settings
}
