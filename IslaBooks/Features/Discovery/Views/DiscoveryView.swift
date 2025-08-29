import SwiftUI

struct DiscoveryView: View {
    @StateObject private var viewModel = DiscoveryViewModel()
    @EnvironmentObject var appConfiguration: AppConfiguration
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // 推荐书单区域
                    RecommendationSectionView()
                    
                    // 热门趋势区域  
                    TrendingSectionView()
                    
                    // 主题合集区域
                    TopicCollectionSectionView()
                }
                .padding(.horizontal)
            }
            .navigationTitle("发现")
            .refreshable {
                await viewModel.refresh()
            }
            .onAppear {
                Task {
                    await viewModel.loadRecommendations()
                }
            }
        }
    }
}

struct RecommendationSectionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("每日推荐")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("更多") {
                    // 跳转到更多推荐页面
                }
                .foregroundColor(.accentColor)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { index in
                        BookRecommendationCard()
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}

struct TrendingSectionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("热门趋势")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("更多") {
                    // 跳转到热门页面
                }
                .foregroundColor(.accentColor)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(0..<4, id: \.self) { index in
                    TrendingBookCard()
                }
            }
        }
    }
}

struct TopicCollectionSectionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("主题合集")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            LazyVStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    TopicCollectionRow()
                }
            }
        }
    }
}

struct BookRecommendationCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 书籍封面
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 120, height: 180)
                .overlay(
                    Text("封面")
                        .foregroundColor(.secondary)
                )
            
            // 书籍信息
            VStack(alignment: .leading, spacing: 4) {
                Text("示例书名")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text("作者名")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 120, alignment: .leading)
        }
    }
}

struct TrendingBookCard: View {
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 120)
                .overlay(
                    Text("封面")
                        .foregroundColor(.secondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("热门书籍")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text("作者")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct TopicCollectionRow: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "book.fill")
                        .foregroundColor(.blue)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("主题标题")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("包含 12 本书籍")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    DiscoveryView()
        .environmentObject(AppConfiguration())
}

