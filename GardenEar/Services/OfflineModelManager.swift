//
//  OfflineModelManager.swift
//  GardenEar
//
//  Created by Sridhar Ippili on 4/17/26.
//

import Foundation
import Combine

enum ModelDownloadState {
  case notDownloaded
  case downloading(progress: Double)
  case downloaded
  case failed(String)
}

@MainActor
class OfflineModelManager: ObservableObject {
  static let shared = OfflineModelManager()
  
  @Published var birdNetState: ModelDownloadState = .notDownloaded
  @Published var natureLMState: ModelDownloadState = .notDownloaded
  
  private let birdNetFileName = "BirdNET_GLOBAL_6K_V2.4.tflite"
  private let birdNetURL = "https://github.com/birdnet-team/BirdNET-Analyzer/releases/download/v2.4/BirdNET_GLOBAL_6K_V2.4_Model_FP32.tflite"
  
  private var modelsDirectory: URL {
    FileManager.default.urls(
      for: .documentDirectory,
      in: .userDomainMask)[0]
      .appendingPathComponent("Models")
  }
  
  init() {
    try? FileManager.default.createDirectory(
      at: modelsDirectory,
      withIntermediateDirectories: true
    )
    checkExistingDownloads()
  }
  
  func checkExistingDownloads() {
    let birdNetPath = modelsDirectory
      .appendingPathComponent(birdNetFileName)
    if FileManager.default.fileExists(atPath: birdNetPath.path) {
      birdNetState = .downloaded
    } else {
      birdNetState = .notDownloaded
    }
  }
  
  var birdNetModelURL: URL? {
    let path = modelsDirectory
      .appendingPathComponent(birdNetFileName)
    return FileManager.default
      .fileExists(atPath: path.path) ? path : nil
  }
  
  var isBirdNetDownloaded: Bool {
    if case .downloaded = birdNetState { return true }
    return false
  }
  
  func downloadBirdNet() async {
    guard let url = URL(string: birdNetURL) else { return }
    birdNetState = .downloading(progress: 0)
    
    do {
      let destPath = modelsDirectory
        .appendingPathComponent(birdNetFileName)
      
      // Stream download with progress
      let (asyncBytes, response) = try await URLSession.shared
        .bytes(from: url)
      
      let totalBytes = response.expectedContentLength
      var downloadedBytes: Int64 = 0
      var data = Data()
      
      for try await byte in asyncBytes {
        data.append(byte)
        downloadedBytes += 1
        if downloadedBytes % 100_000 == 0 {
          let progress = totalBytes > 0
            ? Double(downloadedBytes) / Double(totalBytes)
            : 0
          birdNetState = .downloading(progress: progress)
        }
      }
      
      try data.write(to: destPath)
      birdNetState = .downloaded
      print("[OfflineModel] BirdNET downloaded successfully")
      
    } catch {
      birdNetState = .failed(error.localizedDescription)
      print("[OfflineModel] Download failed: \(error)")
    }
  }
  
  func deleteBirdNet() {
    let path = modelsDirectory
      .appendingPathComponent(birdNetFileName)
    try? FileManager.default.removeItem(at: path)
    birdNetState = .notDownloaded
  }
}
