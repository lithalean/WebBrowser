import SwiftUI
import WebKit

// MARK: - Universal Browser View
struct UniversalBrowserView: View {
    @StateObject private var browserState = BrowserState()
    @State private var showingSidebar = false
    
    var body: some View {
        GeometryReader { geometry in
            #if os(macOS)
            macOSLayout(geometry: geometry)
            #else
            iOSLayout(geometry: geometry)
            #endif
        }
        .onAppear {
            if browserState.tabs.isEmpty {
                browserState.newTab()
            }
        }
    }
    
    // MARK: - macOS Layout (iPad-style)
    #if os(macOS)
    private func macOSLayout(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Sidebar (macOS only)
            if showingSidebar {
                BrowserSidebar(browserState: browserState)
                    .frame(width: 320)
                    .background(.regularMaterial)
                    .transition(.move(edge: .leading))
            }
            
            // Main Content
            VStack(spacing: 0) {
                UniversalToolbar(
                    browserState: browserState,
                    showingSidebar: $showingSidebar,
                    isCompact: false
                )
                
                if browserState.tabs.count > 1 {
                    UniversalTabBar(browserState: browserState, isCompact: false)
                }
                
                WebViewContainer(browserState: browserState)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
        }
        .background(Color(.systemGroupedBackground))
        .animation(.easeInOut(duration: 0.3), value: showingSidebar)
    }
    #endif
    
    // MARK: - iOS Layout
    private func iOSLayout(geometry: GeometryProxy) -> some View {
        NavigationView {
            VStack(spacing: 0) {
                UniversalToolbar(
                    browserState: browserState,
                    showingSidebar: .constant(false),
                    isCompact: geometry.size.width < 600
                )
                
                if browserState.tabs.count > 1 {
                    UniversalTabBar(browserState: browserState, isCompact: geometry.size.width < 600)
                }
                
                WebViewContainer(browserState: browserState)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Universal Toolbar
struct UniversalToolbar: View {
    @ObservedObject var browserState: BrowserState
    @Binding var showingSidebar: Bool
    let isCompact: Bool
    
    @State private var urlString: String = ""
    @State private var isEditingURL: Bool = false
    @FocusState private var isUrlFieldFocused: Bool
    
    var body: some View {
        if isCompact {
            compactToolbar
        } else {
            expandedToolbar
        }
    }
    
    // MARK: - Compact Toolbar (iPhone)
    private var compactToolbar: some View {
        VStack(spacing: 8) {
            // URL Row
            urlBarSection
            
            // Controls Row
            HStack {
                Spacer()
                
                navigationControls
                
                Spacer()
                
                actionControls
                
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.thickMaterial)
        .onReceive(browserState.$currentTab) { _ in
            updateURLString()
        }
        .onChange(of: isUrlFieldFocused) { focused in
            if !focused { isEditingURL = false }
        }
    }
    
    // MARK: - Expanded Toolbar (iPad/macOS)
    private var expandedToolbar: some View {
        HStack(spacing: 16) {
            #if os(macOS)
            // Sidebar Toggle (macOS only)
            Button(action: { showingSidebar.toggle() }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .background(.regularMaterial, in: Circle())
            #endif
            
            // Navigation Controls
            HStack(spacing: 12) {
                navigationControls
            }
            .frame(height: 44)
            .padding(.horizontal, 16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            
            // URL Bar
            urlBarSection
            
            // Action Controls
            HStack(spacing: 12) {
                actionControls
            }
            .frame(height: 44)
            .padding(.horizontal, 16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.thickMaterial)
        .onReceive(browserState.$currentTab) { _ in
            updateURLString()
        }
        .onChange(of: isUrlFieldFocused) { focused in
            if !focused { isEditingURL = false }
        }
    }
    
    // MARK: - URL Bar Section
    private var urlBarSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.green)
            
            if isEditingURL {
                TextField("Search or enter website", text: $urlString)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($isUrlFieldFocused)
                    .onSubmit { navigateToURL() }
                    .onAppear { isUrlFieldFocused = true }
            } else {
                Button(action: startEditing) {
                    HStack {
                        Text(formatDisplayURL())
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if browserState.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            
            Button(action: reloadOrStop) {
                Image(systemName: browserState.isLoading ? "xmark" : "arrow.clockwise")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
        .onTapGesture { if !isEditingURL { startEditing() } }
    }
    
    // MARK: - Navigation Controls
    private var navigationControls: some View {
        Group {
            Button(action: goBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(browserState.currentTab?.canGoBack == true ? .primary : .secondary)
            }
            .disabled(!(browserState.currentTab?.canGoBack ?? false))
            
            Button(action: goForward) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(browserState.currentTab?.canGoForward == true ? .primary : .secondary)
            }
            .disabled(!(browserState.currentTab?.canGoForward ?? false))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Action Controls
    private var actionControls: some View {
        Group {
            Button(action: { browserState.newTab() }) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
            }
            
            Button(action: showMenu) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helper Methods
    private func updateURLString() {
        if !isEditingURL {
            urlString = browserState.currentTab?.url ?? ""
        }
    }
    
    private func startEditing() {
        isEditingURL = true
        urlString = browserState.currentTab?.url ?? ""
    }
    
    private func formatDisplayURL() -> String {
        guard let url = browserState.currentTab?.url else { return "Search or enter website" }
        return URL(string: url)?.host ?? url
    }
    
    private func goBack() {
        NotificationCenter.default.post(name: .webViewGoBack, object: nil)
    }
    
    private func goForward() {
        NotificationCenter.default.post(name: .webViewGoForward, object: nil)
    }
    
    private func reloadOrStop() {
        if browserState.isLoading {
            NotificationCenter.default.post(name: .webViewStop, object: nil)
        } else {
            NotificationCenter.default.post(name: .webViewReload, object: nil)
        }
    }
    
    private func navigateToURL() {
        var finalURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !finalURL.hasPrefix("http://") && !finalURL.hasPrefix("https://") {
            if finalURL.contains(".") && !finalURL.contains(" ") {
                finalURL = "https://" + finalURL
            } else {
                finalURL = "https://duckduckgo.com/?q=" + finalURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            }
        }
        
        browserState.currentTab?.url = finalURL
        NotificationCenter.default.post(name: .webViewNavigate, object: finalURL)
        isEditingURL = false
        isUrlFieldFocused = false
    }
    
    private func showMenu() {
        // Implement menu
    }
}

// MARK: - Universal Tab Bar
struct UniversalTabBar: View {
    @ObservedObject var browserState: BrowserState
    let isCompact: Bool
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(browserState.tabs.enumerated()), id: \.element.id) { index, tab in
                    UniversalTabItem(
                        tab: tab,
                        isSelected: index == browserState.currentTabIndex,
                        isCompact: isCompact,
                        onSelect: { browserState.selectTab(at: index) },
                        onClose: { browserState.closeTab(at: index) }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: isCompact ? 50 : 60)
        .background(.regularMaterial)
    }
}

// MARK: - Universal Tab Item
struct UniversalTabItem: View {
    let tab: WebTab
    let isSelected: Bool
    let isCompact: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: isCompact ? 8 : 12) {
            // Favicon
            RoundedRectangle(cornerRadius: 4)
                .fill(.secondary.opacity(0.3))
                .frame(width: isCompact ? 16 : 20, height: isCompact ? 16 : 20)
                .overlay(
                    Image(systemName: "globe")
                        .font(.system(size: isCompact ? 8 : 10))
                        .foregroundColor(.secondary)
                )
            
            if !isCompact {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tab.title)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    Text(formatTabURL())
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: 200, alignment: .leading)
            } else {
                Text(tab.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                    .frame(maxWidth: 100, alignment: .leading)
            }
            
            if !isCompact { Spacer() }
            
            if tab.isLoading {
                ProgressView()
                    .controlSize(.mini)
            }
            
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: isCompact ? 14 : 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, isCompact ? 12 : 16)
        .padding(.vertical, isCompact ? 8 : 12)
        .frame(minWidth: isCompact ? 120 : 180, maxWidth: isCompact ? 160 : 300)
        .background(
            RoundedRectangle(cornerRadius: isCompact ? 8 : 12)
                .fill(isSelected ? .selection.opacity(0.8) : .clear)
                .overlay(
                    RoundedRectangle(cornerRadius: isCompact ? 8 : 12)
                        .stroke(isSelected ? .accentColor : .clear, lineWidth: 2)
                )
        )
        .onTapGesture { onSelect() }
        .scaleEffect(isSelected ? 1.0 : 0.95)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    private func formatTabURL() -> String {
        return URL(string: tab.url)?.host ?? tab.url
    }
}

// MARK: - Browser Sidebar (macOS only)
#if os(macOS)
struct BrowserSidebar: View {
    @ObservedObject var browserState: BrowserState
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("WebBrowser")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { browserState.newTab() }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            Divider()
            
            // Content
            ScrollView {
                LazyVStack(spacing: 12) {
                    SidebarSection(title: "Favorites") {
                        ForEach(favoritesSites, id: \.0) { site in
                            SidebarItem(
                                title: site.0,
                                subtitle: site.1,
                                icon: "star.fill"
                            ) {
                                browserState.newTab(url: site.1)
                            }
                        }
                    }
                    
                    SidebarSection(title: "Open Tabs") {
                        ForEach(browserState.tabs, id: \.id) { tab in
                            SidebarItem(
                                title: tab.title,
                                subtitle: URL(string: tab.url)?.host ?? tab.url,
                                icon: "globe"
                            ) {
                                if let index = browserState.tabs.firstIndex(where: { $0.id == tab.id }) {
                                    browserState.selectTab(at: index)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            
            Spacer()
        }
    }
    
    private let favoritesSites = [
        ("WebKit", "https://webkit.org"),
        ("Apple", "https://apple.com"),
        ("Swift", "https://swift.org"),
        ("GitHub", "https://github.com")
    ]
}

struct SidebarSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
            
            content
        }
    }
}

struct SidebarItem: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
#endif

// MARK: - Browser State Management
class BrowserState: ObservableObject {
    @Published var tabs: [WebTab] = []
    @Published var currentTabIndex: Int = 0
    @Published var isLoading: Bool = false
    
    var currentTab: WebTab? {
        guard currentTabIndex < tabs.count else { return nil }
        return tabs[currentTabIndex]
    }
    
    func newTab(url: String = "https://webkit.org") {
        let tab = WebTab(url: url)
        tabs.append(tab)
        currentTabIndex = tabs.count - 1
    }
    
    func closeTab(at index: Int) {
        guard tabs.count > 1, index < tabs.count else { return }
        tabs.remove(at: index)
        if currentTabIndex >= tabs.count {
            currentTabIndex = tabs.count - 1
        }
    }
    
    func selectTab(at index: Int) {
        guard index < tabs.count else { return }
        currentTabIndex = index
    }
}

// MARK: - Web Tab Model
struct WebTab: Identifiable {
    let id = UUID()
    var title: String = "New Tab"
    var url: String
    var isLoading: Bool = false
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    
    init(url: String) {
        self.url = url
    }
}

// MARK: - WebView Container
struct WebViewContainer: View {
    @ObservedObject var browserState: BrowserState
    
    var body: some View {
        if let currentTab = browserState.currentTab {
            WebViewRepresentable(
                url: currentTab.url,
                browserState: browserState
            )
        } else {
            VStack(spacing: 16) {
                Image(systemName: "globe")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("No Tab Selected")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Create a new tab to start browsing")
                    .foregroundColor(.secondary)
                
                Button("New Tab") {
                    browserState.newTab()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - WebView Representable
#if os(iOS)
struct WebViewRepresentable: UIViewRepresentable {
    let url: String
    @ObservedObject var browserState: BrowserState
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        setupNotificationObservers(for: webView)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if let url = URL(string: url), webView.url?.absoluteString != url.absoluteString {
            webView.load(URLRequest(url: url))
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func setupNotificationObservers(for webView: WKWebView) {
        NotificationCenter.default.addObserver(forName: .webViewGoBack, object: nil, queue: .main) { _ in
            webView.goBack()
        }
        NotificationCenter.default.addObserver(forName: .webViewGoForward, object: nil, queue: .main) { _ in
            webView.goForward()
        }
        NotificationCenter.default.addObserver(forName: .webViewReload, object: nil, queue: .main) { _ in
            webView.reload()
        }
        NotificationCenter.default.addObserver(forName: .webViewStop, object: nil, queue: .main) { _ in
            webView.stopLoading()
        }
        NotificationCenter.default.addObserver(forName: .webViewNavigate, object: nil, queue: .main) { notification in
            if let urlString = notification.object as? String, let url = URL(string: urlString) {
                webView.load(URLRequest(url: url))
            }
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: WebViewRepresentable
        
        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.browserState.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.browserState.isLoading = false
            
            if parent.browserState.currentTabIndex < parent.browserState.tabs.count {
                parent.browserState.tabs[parent.browserState.currentTabIndex].title = webView.title ?? "Untitled"
                parent.browserState.tabs[parent.browserState.currentTabIndex].url = webView.url?.absoluteString ?? ""
                parent.browserState.tabs[parent.browserState.currentTabIndex].canGoBack = webView.canGoBack
                parent.browserState.tabs[parent.browserState.currentTabIndex].canGoForward = webView.canGoForward
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.browserState.isLoading = false
        }
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url?.absoluteString {
                parent.browserState.newTab(url: url)
            }
            return nil
        }
    }
}
#else
struct WebViewRepresentable: NSViewRepresentable {
    let url: String
    @ObservedObject var browserState: BrowserState
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsAirPlayForMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        setupNotificationObservers(for: webView)
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        if let url = URL(string: url), webView.url?.absoluteString != url.absoluteString {
            webView.load(URLRequest(url: url))
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func setupNotificationObservers(for webView: WKWebView) {
        NotificationCenter.default.addObserver(forName: .webViewGoBack, object: nil, queue: .main) { _ in
            webView.goBack()
        }
        NotificationCenter.default.addObserver(forName: .webViewGoForward, object: nil, queue: .main) { _ in
            webView.goForward()
        }
        NotificationCenter.default.addObserver(forName: .webViewReload, object: nil, queue: .main) { _ in
            webView.reload()
        }
        NotificationCenter.default.addObserver(forName: .webViewStop, object: nil, queue: .main) { _ in
            webView.stopLoading()
        }
        NotificationCenter.default.addObserver(forName: .webViewNavigate, object: nil, queue: .main) { notification in
            if let urlString = notification.object as? String, let url = URL(string: urlString) {
                webView.load(URLRequest(url: url))
            }
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: WebViewRepresentable
        
        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.browserState.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.browserState.isLoading = false
            
            if parent.browserState.currentTabIndex < parent.browserState.tabs.count {
                parent.browserState.tabs[parent.browserState.currentTabIndex].title = webView.title ?? "Untitled"
                parent.browserState.tabs[parent.browserState.currentTabIndex].url = webView.url?.absoluteString ?? ""
                parent.browserState.tabs[parent.browserState.currentTabIndex].canGoBack = webView.canGoBack
                parent.browserState.tabs[parent.browserState.currentTabIndex].canGoForward = webView.canGoForward
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.browserState.isLoading = false
        }
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url?.absoluteString {
                parent.browserState.newTab(url: url)
            }
            return nil
        }
    }
}
#endif

// MARK: - Notification Names
extension Notification.Name {
    static let webViewGoBack = Notification.Name("webViewGoBack")
    static let webViewGoForward = Notification.Name("webViewGoForward")
    static let webViewReload = Notification.Name("webViewReload")
    static let webViewStop = Notification.Name("webViewStop")
    static let webViewNavigate = Notification.Name("webViewNavigate")
}
