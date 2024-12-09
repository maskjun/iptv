//
//  ContentView.swift
//  iptv
//
//  Created by 马军 on 2024/12/9.
//

import SwiftUI
import AVKit

// 频道模型
struct Channel: Identifiable, Codable {
    let id = UUID()
    let name: String
    let url: String
}

// IPTV数据管理类
class IPTVManager: ObservableObject {
    @Published var channels: [Channel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    
    private let defaults = UserDefaults.standard
    private let channelsKey = "saved_channels"
    
    init() {
        loadChannelsFromCache()
    }
    
    var filteredChannels: [Channel] {
        if searchText.isEmpty {
            return channels
        }
        return channels.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    func fetchChannelList(from urlString: String = "http://182.254.159.181/IPTV.txt") {
        guard let url = URL(string: urlString) else {
            self.errorMessage = "无效的URL"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "网络错误: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data,
                      let content = String(data: data, encoding: .utf8) else {
                    self?.errorMessage = "数据解析错误"
                    return
                }
                
                // 解析频道列表
                let channels = content.components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
                    .compactMap { line -> Channel? in
                        let components = line.components(separatedBy: ",")
                        guard components.count == 2 else { return nil }
                        return Channel(name: components[0], url: components[1])
                    }
                
                self?.channels = channels
                self?.saveChannelsToCache()
            }
        }.resume()
    }
    
    private func saveChannelsToCache() {
        if let encoded = try? JSONEncoder().encode(channels) {
            defaults.set(encoded, forKey: channelsKey)
        }
    }
    
    private func loadChannelsFromCache() {
        if let savedChannels = defaults.data(forKey: channelsKey),
           let decodedChannels = try? JSONDecoder().decode([Channel].self, from: savedChannels) {
            self.channels = decodedChannels
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            ChannelListView()
                .tabItem {
                    Image(systemName: "tv")
                    Text("节目列表")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("设置")
                }
        }
    }
}

struct ChannelListView: View {
    @StateObject private var iptvManager = IPTVManager()
    
    var body: some View {
        NavigationView {
            VStack {
                // 搜索栏
                SearchBar(text: $iptvManager.searchText)
                
                if iptvManager.isLoading {
                    ProgressView("加载中...")
                } else if let error = iptvManager.errorMessage {
                    VStack {
                        Text(error)
                            .foregroundColor(.red)
                        Button("重试") {
                            iptvManager.fetchChannelList()
                        }
                    }
                } else {
                    List {
                        ForEach(iptvManager.filteredChannels) { channel in
                            NavigationLink(destination: PlayerView(url: channel.url)) {
                                HStack {
                                    Image(systemName: "tv.fill")
                                    Text(channel.name)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("节目列表")
            .refreshable {
                iptvManager.fetchChannelList()
            }
        }
        .onAppear {
            if iptvManager.channels.isEmpty {
                iptvManager.fetchChannelList()
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("搜索频道", text: $text)
                .padding(8)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct SettingsView: View {
    @StateObject private var iptvManager = IPTVManager()
    @State private var m3uURL: String = "http://182.254.159.181/IPTV.txt"
    @State private var showAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本设置")) {
                    TextField("M3U播放列表URL", text: $m3uURL)
                    Button("更新播放列表") {
                        iptvManager.fetchChannelList(from: m3uURL)
                        showAlert = true
                    }
                }
                
                Section(header: Text("缓存")) {
                    Text("频道数量: \(iptvManager.channels.count)")
                    Button("清除缓存") {
                        UserDefaults.standard.removeObject(forKey: "saved_channels")
                        iptvManager.channels = []
                    }
                }
                
                Section(header: Text("关于")) {
                    Text("版本: 1.0.0")
                }
            }
            .navigationTitle("设置")
            .alert("���新提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                if let error = iptvManager.errorMessage {
                    Text(error)
                } else {
                    Text("播放列表更新成功")
                }
            }
        }
    }
}

struct PlayerView: View {
    let url: String
    @State private var showError = false
    
    var body: some View {
        ZStack {
            if let url = URL(string: url) {
                VideoPlayer(player: AVPlayer(url: url))
                    .edgesIgnoringSafeArea(.all)
            } else {
                Text("无效的视频URL")
                    .foregroundColor(.red)
            }
        }
        .alert("播放错误", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("视频播放出现错误，请稍后重试")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
