import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @EnvironmentObject var appConfiguration: AppConfiguration
    @State private var showingImportPicker = false
    @State private var showingAddMenu = false
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.books.isEmpty {
                    EmptyLibraryView {
                        showingAddMenu = true
                    }
                } else {
                    BookGridView(books: viewModel.books)
                }
            }
            .navigationTitle("我的书架")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddMenu = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .confirmationDialog("添加书籍", isPresented: $showingAddMenu) {
                Button("从文件导入") {
                    showingImportPicker = true
                }
                Button("扫描二维码") {
                    // 扫描功能
                }
                Button("取消", role: .cancel) { }
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.epub, .plainText],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
            .onAppear {
                viewModel.loadBooks()
            }
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                await viewModel.importBooks(from: urls)
            }
        case .failure(let error):
            print("文件导入失败: \(error)")
        }
    }
}

struct EmptyLibraryView: View {
    let onAddTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "books.vertical")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("书架空空如也")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("导入您的第一本电子书开始阅读之旅")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("添加书籍") {
                onAddTapped()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct BookGridView: View {
    let books: [Book]
    let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 150), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(books, id: \.id) { book in
                    BookCardView(book: book)
                }
            }
            .padding()
        }
    }
}

struct BookCardView: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 书籍封面
            BookCoverView(book: book)
                .frame(height: 180)
            
            // 书籍信息
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if !book.authors.isEmpty {
                    Text(book.authors.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // 阅读进度
                if let progress = book.readingProgress {
                    ProgressView(value: progress)
                        .tint(.accentColor)
                        .scaleEffect(x: 1, y: 0.8)
                }
            }
        }
        .onTapGesture {
            // 打开书籍阅读页面
        }
    }
}

struct BookCoverView: View {
    let book: Book
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Group {
                    if let coverPath = book.coverImagePath {
                        // 加载本地封面图片
                        AsyncImage(url: URL(fileURLWithPath: coverPath)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            DefaultBookCoverView(title: book.title)
                        }
                    } else {
                        DefaultBookCoverView(title: book.title)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct DefaultBookCoverView: View {
    let title: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.closed")
                .font(.title)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.blue, .purple]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// UTType 扩展支持 EPUB
extension UTType {
    static let epub = UTType(filenameExtension: "epub")!
}

#Preview {
    LibraryView()
        .environmentObject(AppConfiguration())
}

