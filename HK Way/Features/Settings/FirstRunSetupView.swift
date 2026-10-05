import SwiftData
import SwiftUI

struct FirstRunSetupView: View {
    static let completionStorageKey = "firstRunSetup.completed.v1"

    @Query(sort: \OperatorEntity.id) private var operators: [OperatorEntity]

    @AppStorage("appLanguage")
    private var selectedLanguage = TransitLanguage.traditionalChinese.rawValue

    @AppStorage(OperatorSelectionPreference.storageKey)
    private var selectedOperatorIDsValue = ""

    @AppStorage(DefaultAppTab.storageKey)
    private var defaultTab = DefaultAppTab.nearby.rawValue

    @State private var page = 0

    var isDatasetReady = true
    var datasetLoadFailed = false
    let onComplete: () -> Void
    var onCancel: (() -> Void)?

    private var selectedOperatorIDs: Set<String> {
        OperatorSelectionPreference.ids(from: selectedOperatorIDsValue)
    }

    private var setupLanguage: TransitLanguage {
        TransitLanguage(preferenceValue: selectedLanguage)
    }

    private var selectableOperators: [OperatorEntity] {
        operators.filter { !$0.id.contains("+") }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CustomAppBackgroundView()

                Group {
                    switch page {
                    case 0: welcomePage
                    case 1: languagePage
                    case 2: startPage
                    case 3: operatorsPage
                    default: favoritesIntroductionPage
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .toolbar {
                if page > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation { page -= 1 }
                        } label: {
                            Label(backTitle, systemImage: "chevron.left")
                        }
                    }
                } else if let onCancel {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(closeTitle, action: onCancel)
                    }
                }
            }
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: "tram.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(.tint)

            VStack(spacing: 10) {
                Text(welcomeTitle)
                    .font(.largeTitle.bold())

                Text(welcomeDetail)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            Spacer()
            primaryButton(title: continueTitle) {
                withAnimation { page = 1 }
            }
        }
    }

    private var languagePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            setupHeading(title: languageTitle, detail: languageDetail)

            VStack(spacing: 0) {
                ForEach(TransitLanguage.allCases) { option in
                    Button {
                        selectedLanguage = option.rawValue
                    } label: {
                        HStack {
                            Text(option.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedLanguage == option.rawValue {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .padding()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if option != TransitLanguage.allCases.last {
                        Divider().padding(.leading)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            Spacer()
            primaryButton(title: continueTitle) {
                withAnimation { page = 2 }
            }
        }
    }

    private var startPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            setupHeading(title: startPageSetupTitle, detail: startPageSetupDetail)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(DefaultAppTab.allCases) { tab in
                    selectionButton(
                        title: title(for: tab),
                        systemImage: tab.systemImage,
                        isSelected: defaultTab == tab.rawValue
                    ) {
                        defaultTab = tab.rawValue
                    }
                }
            }

            Spacer()
            primaryButton(title: continueTitle) {
                withAnimation { page = 3 }
            }
        }
    }

    private var operatorsPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            setupHeading(title: operatorTitle, detail: operatorDetail)

            if datasetLoadFailed {
                statusCard(
                    systemImage: "exclamationmark.triangle.fill",
                    title: datasetErrorTitle,
                    detail: datasetErrorDetail
                )
                Spacer()
            } else if !isDatasetReady {
                statusCard(
                    systemImage: nil,
                    title: preparingOperatorsTitle,
                    detail: preparingOperatorsDetail
                )
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        selectionButton(
                            title: allOperatorsTitle,
                            isSelected: selectedOperatorIDs.isEmpty
                        ) {
                            selectedOperatorIDsValue = ""
                        }

                        ForEach(selectableOperators) { operatorEntity in
                            selectionButton(
                                title: operatorEntity.displayName(for: setupLanguage),
                                isSelected: selectedOperatorIDs.contains(operatorEntity.id)
                            ) {
                                toggleOperator(operatorEntity.id)
                            }
                        }
                    }
                }
            }

            primaryButton(
                title: continueTitle,
                isEnabled: isDatasetReady && !datasetLoadFailed,
                action: { withAnimation { page = 4 } }
            )
        }
    }

    private var favoritesIntroductionPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    setupHeading(
                        title: favoritesIntroductionTitle,
                        detail: favoritesIntroductionDetail
                    )

                    VStack(spacing: 12) {
                        introductionRow(
                            systemImage: "bus.fill",
                            title: favoriteRoutesTitle,
                            detail: favoriteRoutesDetail
                        )
                        introductionRow(
                            systemImage: "mappin.and.ellipse",
                            title: favoriteStopsTitle,
                            detail: favoriteStopsDetail
                        )
                        introductionRow(
                            systemImage: "tram.fill",
                            title: favoriteStationsTitle,
                            detail: favoriteStationsDetail
                        )
                        introductionRow(
                            systemImage: "square.grid.2x2.fill",
                            title: widgetTitle,
                            detail: widgetDetail
                        )
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "bookmark")
                            .font(.title2)
                            .foregroundStyle(.tint)
                        Text(bookmarkHint)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.vertical, 2)
            }

            primaryButton(title: finishTitle, action: onComplete)
        }
    }

    private func introductionRow(
        systemImage: String,
        title: String,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func statusCard(
        systemImage: String?,
        title: String,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.orange)
            } else {
                ProgressView().controlSize(.large)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func setupHeading(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.title.bold())
            Text(detail).foregroundStyle(.secondary)
        }
    }

    private func primaryButton(
        title: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!isEnabled)
    }

    private func selectionButton(
        title: String,
        systemImage: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                if let systemImage {
                    Image(systemName: systemImage).frame(width: 24)
                }
                Text(title).multilineTextAlignment(.leading)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                }
            }
            .foregroundStyle(.primary)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleOperator(_ id: String) {
        var selection = selectedOperatorIDs
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
        selectedOperatorIDsValue = OperatorSelectionPreference.value(from: selection)
    }

    private func title(for tab: DefaultAppTab) -> String {
        switch tab {
        case .favorites:
            localized("Favorites", "收藏", "收藏")
        case .nearby:
            localized("Nearby", "附近", "附近")
        }
    }

    private var welcomeTitle: String { localized("Welcome to HK Way", "歡迎使用 喂!香港", "欢迎使用 喂!香港") }
    private var welcomeDetail: String { localized("Live arrival information, routes and transport tools for journeys across Hong Kong.", "提供實時到站資訊、路線及交通工具，助你暢遊香港。", "提供实时到站资讯、路线及交通工具，助你畅游香港。") }
    private var languageTitle: String { localized("Choose a language", "選擇語言", "选择语言") }
    private var languageDetail: String { localized("You can change this later in Settings.", "你可稍後在「設定」中更改。", "你可稍后在“设置”中更改。") }
    private var startPageSetupTitle: String { localized("Choose your start page", "選擇開始頁面", "选择开始页面") }
    private var startPageSetupDetail: String { localized("Choose the page shown when HK Way opens.", "選擇開啟 HK Way 時顯示的頁面。", "选择打开 HK Way 时显示的页面。") }
    private var operatorTitle: String { localized("Favourite operators", "常用營運商", "常用运营商") }
    private var operatorDetail: String { localized("Choose the operators you use most. Select All operators if you do not want to filter nearby routes. You can change this selection later in Settings.", "選擇你最常用的營運商。如不想篩選附近路線，請選擇「所有營運商」。你可稍後在「設定」中更改此選擇。", "选择你最常用的运营商。如不想筛选附近路线，请选择“所有运营商”。你可稍后在“设置”中更改此选择。") }
    private var preparingOperatorsTitle: String { localized("Preparing operators…", "正在準備營運商資料⋯", "正在准备运营商资料…") }
    private var preparingOperatorsDetail: String { localized("HK Way is loading its transit dataset in the background. It could take a few minutes depending on network conditions. You can continue as soon as the full operator list is ready.", "HK Way 正在背景載入交通資料，視乎網絡狀況，可能需要數分鐘。完整營運商清單準備好後即可繼續。", "HK Way 正在后台载入交通资料，视网络状况而定，可能需要几分钟。完整运营商列表准备好后即可继续。") }
    private var datasetErrorTitle: String { localized("Unable to prepare the transit data", "未能準備交通資料", "未能准备交通资料") }
    private var datasetErrorDetail: String { localized("Close and reopen HK Way to try again.", "請關閉並重新開啟 HK Way 再試一次。", "请关闭并重新打开 HK Way 后重试。") }
    private var favoritesIntroductionTitle: String { localized("Keep journeys close at hand", "收藏常用行程", "收藏常用行程") }
    private var favoritesIntroductionDetail: String { localized("Save the routes and boarding points you use often, then find them together on the Favorites page.", "儲存你常用的路線及上車地點，之後可在「收藏」頁面集中查看。", "储存你常用的路线及上车地点，之后可在“收藏”页面集中查看。") }
    private var favoriteRoutesTitle: String { localized("Favorite routes", "收藏路線", "收藏路线") }
    private var favoriteRoutesDetail: String { localized("Open a route direction and tap the bookmark button.", "開啟路線方向，然後點按書籤按鈕。", "打开路线方向，然后点击书签按钮。") }
    private var favoriteStopsTitle: String { localized("Favorite bus stops", "收藏巴士站", "收藏巴士站") }
    private var favoriteStopsDetail: String { localized("Open a stop to save it for quick arrival checks.", "開啟巴士站並將它收藏，以便快速查看到站資訊。", "打开巴士站并将其收藏，以便快速查看到站资讯。") }
    private var favoriteStationsTitle: String { localized("Favorite MTR stations", "收藏港鐵站", "收藏地铁站") }
    private var favoriteStationsDetail: String { localized("Open station arrivals and save the direction you travel.", "開啟車站到站資訊，並收藏你的乘車方向。", "打开车站到站资讯，并收藏你的乘车方向。") }
    private var widgetTitle: String { localized("Home Screen widget", "主畫面小工具", "主屏幕小组件") }
    private var widgetDetail: String { localized("After saving favorites, add the HK Way widget to your Home Screen and choose one for quick arrival checks.", "收藏項目後，可將 HK Way 小工具加入主畫面，並選擇一個項目以快速查看到站資訊。", "收藏项目后，可将 HK Way 小组件添加到主屏幕，并选择一个项目以快速查看到站资讯。") }
    private var bookmarkHint: String { localized("Look for the bookmark icon on route, stop and station arrival pages.", "在路線、巴士站及車站到站頁面尋找書籤圖示。", "在路线、巴士站及车站到站页面寻找书签图标。") }
    private var allOperatorsTitle: String { localized("All operators", "所有營運商", "所有运营商") }
    private var continueTitle: String { localized("Continue", "繼續", "继续") }
    private var finishTitle: String { localized("Start using HK Way", "開始使用 HK Way", "开始使用 HK Way") }
    private var backTitle: String { localized("Back", "返回", "返回") }
    private var closeTitle: String { localized("Close", "關閉", "关闭") }

    private func localized(_ english: String, _ traditional: String, _ simplified: String) -> String {
        switch setupLanguage {
        case .english: english
        case .traditionalChinese: traditional
        case .simplifiedChinese: simplified
        }
    }
}

#Preview {
    FirstRunSetupView {}
        .modelContainer(for: OperatorEntity.self, inMemory: true)
}
