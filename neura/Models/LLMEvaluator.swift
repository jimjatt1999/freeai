//
//  LLMEvaluator.swift
//  free ai
//
//

import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import SwiftUI

enum LLMEvaluatorError: Error {
    case modelNotFound(String)
    case modelNotDownloaded(String)
}

/// Preference to prioritize offline access even when online
@MainActor
class ModelPreferences {
    static let shared = ModelPreferences()
    
    /// Set to true to always prefer offline model loading without network check
    var forceOfflineMode: Bool {
        get { UserDefaults.standard.bool(forKey: "force_offline_model_loading") }
        set { UserDefaults.standard.set(newValue, forKey: "force_offline_model_loading") }
    }
    
    /// Toggle to always use offline mode
    func toggleOfflineMode() {
        forceOfflineMode = !forceOfflineMode
    }
}

@Observable
@MainActor
class LLMEvaluator {
    var running = false
    var cancelled = false
    var output = ""
    var modelInfo = ""
    var stat = ""
    var progress = 0.0
    var thinkingTime: TimeInterval?
    var collapsed: Bool = false
    var isThinking: Bool = false

    var elapsedTime: TimeInterval? {
        if let startTime {
            return Date().timeIntervalSince(startTime)
        }

        return nil
    }

    private var startTime: Date?

    var modelConfiguration = ModelConfiguration.defaultModel

    func switchModel(_ model: ModelConfiguration) async {
        progress = 0.0 // reset progress
        loadState = .idle
        modelConfiguration = model
        _ = try? await load(modelName: model.name)
    }

    /// parameters controlling the output
    let generateParameters = GenerateParameters(temperature: 0.5)
    let maxTokens = 4096

    /// update the display every N tokens -- 4 looks like it updates continuously
    /// and is low overhead.  observed ~15% reduction in tokens/s when updating
    /// on every token
    let displayEveryNTokens = 4

    enum LoadState {
        case idle
        case loaded(ModelContainer)
    }

    var loadState = LoadState.idle

    /// Try to force offline mode for a specific model
    func forceLocalModelUse(modelID: String) -> Bool {
        if case .idle = loadState {
            ModelPreferences.shared.forceOfflineMode = true
            return true
        }
        return false
    }

    /// load and return the model -- can be called multiple times, subsequent calls will
    /// just return the loaded model
    func load(modelName: String) async throws -> ModelContainer {
        guard let model = ModelConfiguration.getModelByName(modelName) else {
            throw LLMEvaluatorError.modelNotFound(modelName)
        }

        switch loadState {
        case .idle:
            // limit the buffer cache
            MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)
            
            // Optimize system performance for download
            let cache = URLCache.shared
            cache.memoryCapacity = 100 * 1024 * 1024  // 100MB memory cache
            
            // Configure URL session with better timeout handling
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 60.0  // 60 seconds timeout for requests
            config.timeoutIntervalForResource = 300.0  // 5 minutes timeout for resources
            config.waitsForConnectivity = true  // Wait for connectivity if offline
            URLSession.shared.configuration.timeoutIntervalForRequest = config.timeoutIntervalForRequest
            URLSession.shared.configuration.timeoutIntervalForResource = config.timeoutIntervalForResource
            
            Task { @MainActor in
                self.modelInfo = "Preparing to load \(self.modelConfiguration.name)..."
            }

            // Always try to load from local cache first if model was previously installed
            // or offline mode is forced
            let forceOffline = ModelPreferences.shared.forceOfflineMode
            let wasInstalled = UserDefaults.standard.bool(forKey: "model_installed_\(model.id)")
            
            if wasInstalled || forceOffline {
                do {
                    Task { @MainActor in
                        self.modelInfo = "Loading local model \(self.modelConfiguration.name)..."
                    }
                    
                    let modelContainer = try await LLMModelFactory.shared.loadContainer(
                        configuration: model
                    )
                    
                    modelInfo = "Loaded \(self.modelConfiguration.id).  Weights: \(MLX.GPU.activeMemory / 1024 / 1024)M"
                    loadState = .loaded(modelContainer)
                    return modelContainer
                } catch {
                    // If local load fails and we're in force offline mode, throw error
                    if forceOffline {
                        Task { @MainActor in
                            self.modelInfo = "Local model not available and offline mode is enabled."
                        }
                        throw LLMEvaluatorError.modelNotDownloaded(modelName)
                    }
                    
                    // Otherwise we'll fall through to the download path
                    Task { @MainActor in
                        self.modelInfo = "Local model not available. Attempting download..."
                    }
                }
            }
            
            // Try to load model with potential download
            let modelContainer: ModelContainer
            do {
                modelContainer = try await LLMModelFactory.shared.loadContainer(configuration: model) { progress in
                    Task { @MainActor in
                        self.modelInfo =
                            "Downloading \(self.modelConfiguration.name): \(Int(progress.fractionCompleted * 100))%"
                        self.progress = progress.fractionCompleted
                    }
                }
                
                // Mark model as installed for future reference
                UserDefaults.standard.set(true, forKey: "model_installed_\(model.id)")
            } catch {
                // If download fails but we already have it installed, try one more time with local-only
                if UserDefaults.standard.bool(forKey: "model_installed_\(model.id)") {
                    Task { @MainActor in
                        self.modelInfo = "Download failed. Trying to use locally cached model..."
                    }
                    
                    // Try to load from local cache with no download attempt
                    modelContainer = try await LLMModelFactory.shared.loadContainer(
                        configuration: model
                    )
                } else {
                    // No previously successful installation and current download failed
                    throw error
                }
            }
            
            modelInfo =
                "Loaded \(self.modelConfiguration.id).  Weights: \(MLX.GPU.activeMemory / 1024 / 1024)M"
            loadState = .loaded(modelContainer)
            return modelContainer

        case let .loaded(modelContainer):
            return modelContainer
        }
    }

    func stop() {
        isThinking = false
        cancelled = true
    }

    func generate(modelName: String, thread: Thread, systemPrompt: String) async -> String {
        guard !running else { return "" }

        running = true
        cancelled = false
        output = ""
        startTime = Date()

        do {
            let modelContainer = try await load(modelName: modelName)

            // augment the prompt as needed
            let promptHistory = modelContainer.configuration.getPromptHistory(thread: thread, systemPrompt: systemPrompt)

            // DeepSeek models are no longer available
            /*
            if modelContainer.configuration.modelType == .reasoning {
                isThinking = true
            }
            */

            // each time you generate you will get something new
            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

            let result = try await modelContainer.perform { context in
                let input = try await context.processor.prepare(input: .init(messages: promptHistory))
                return try MLXLMCommon.generate(
                    input: input, parameters: generateParameters, context: context
                ) { tokens in

                    var cancelled = false
                    Task { @MainActor in
                        cancelled = self.cancelled
                    }

                    // update the output -- this will make the view show the text as it generates
                    if tokens.count % displayEveryNTokens == 0 {
                        let text = context.tokenizer.decode(tokens: tokens)
                        Task { @MainActor in
                            self.output = text
                        }
                    }

                    if tokens.count >= maxTokens || cancelled {
                        return .stop
                    } else {
                        return .more
                    }
                }
            }

            // update the text if needed, e.g. we haven't displayed because of displayEveryNTokens
            if result.output != output {
                output = result.output
            }
            stat = " Tokens/second: \(String(format: "%.3f", result.tokensPerSecond))"

        } catch let error as URLError {
            // Handle URL-specific errors with more helpful offline-first messages
            let errorMessage: String
            switch error.code {
            case .timedOut:
                errorMessage = "Connection timed out. Since models are designed to work offline, try restarting the app to use the local copy."
            case .notConnectedToInternet:
                errorMessage = "Not connected to the internet. If this model was previously downloaded, try restarting the app to use the local copy."
            case .networkConnectionLost:
                errorMessage = "Network connection was lost. If this model was previously downloaded, restart the app to force using local copy."
            case .cannotFindHost, .cannotConnectToHost:
                errorMessage = "Cannot connect to server. If this model was previously downloaded, restart the app to force using local copy."
            default:
                errorMessage = "Network error: \(error.localizedDescription). If this model was previously downloaded, restart the app to use local copy."
            }
            output = errorMessage
        } catch {
            // Check if it's a model loading error
            if error.localizedDescription.contains("file doesn't exist") || 
               error.localizedDescription.contains("no such file") {
                output = "Model not found locally. Please download the model first with an internet connection."
            } else {
                // General error handling for non-URL errors
                output = "Failed: \(error)"
            }
        }

        running = false
        return output
    }
    
    // Generate a streaming response
    func generateStream(modelName: String, thread: Thread, systemPrompt: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                guard !running else {
                    continuation.finish()
                    return
                }
                
                running = true
                cancelled = false
                output = ""
                startTime = Date()
                var lastOutput = ""
                
                do {
                    let modelContainer = try await load(modelName: modelName)
                    
                    // augment the prompt as needed
                    let promptHistory = modelContainer.configuration.getPromptHistory(thread: thread, systemPrompt: systemPrompt)
                    
                    // DeepSeek models are no longer available
                    /*
                    if modelContainer.configuration.modelType == .reasoning {
                        isThinking = true
                    }
                    */
                    
                    // each time you generate you will get something new
                    MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))
                    
                    try await modelContainer.perform { context in
                        let input = try await context.processor.prepare(input: .init(messages: promptHistory))
                        return try MLXLMCommon.generate(
                            input: input, parameters: generateParameters, context: context
                        ) { tokens in
                            
                            var cancelled = false
                            Task { @MainActor in
                                cancelled = self.cancelled
                            }
                            
                            // update the output -- this will make the view show the text as it generates
                            if tokens.count % displayEveryNTokens == 0 {
                                let text = context.tokenizer.decode(tokens: tokens)
                                Task { @MainActor in
                                    self.output = text
                                    
                                    // Send just the new characters added since last update
                                    if text.count > lastOutput.count {
                                        let newContent = String(text.dropFirst(lastOutput.count))
                                        if !newContent.isEmpty {
                                            continuation.yield(newContent)
                                        }
                                        lastOutput = text
                                    }
                                }
                            }
                            
                            if tokens.count >= maxTokens || cancelled {
                                return .stop
                            } else {
                                return .more
                            }
                        }
                    }
                    
                    // Make sure we've sent all the output
                    if output != lastOutput {
                        let finalContent = String(output.dropFirst(lastOutput.count))
                        if !finalContent.isEmpty {
                            continuation.yield(finalContent)
                        }
                    }
                    
                    continuation.finish()
                    
                } catch let error as URLError {
                    // Handle URL-specific errors with more helpful offline-first messages
                    let errorMessage: String
                    switch error.code {
                    case .timedOut:
                        errorMessage = "Connection timed out. Since models are designed to work offline, try restarting the app to use the local copy."
                    case .notConnectedToInternet:
                        errorMessage = "Not connected to the internet. If this model was previously downloaded, try restarting the app to use the local copy."
                    case .networkConnectionLost:
                        errorMessage = "Network connection was lost. If this model was previously downloaded, restart the app to force using local copy."
                    case .cannotFindHost, .cannotConnectToHost:
                        errorMessage = "Cannot connect to server. If this model was previously downloaded, restart the app to force using local copy."
                    default:
                        errorMessage = "Network error: \(error.localizedDescription). If this model was previously downloaded, restart the app to use local copy."
                    }
                    continuation.finish(throwing: NSError(domain: "NetworkError", 
                                                        code: error.code.rawValue, 
                                                        userInfo: [NSLocalizedDescriptionKey: errorMessage]))
                } catch {
                    // Check if it's a model loading error
                    if error.localizedDescription.contains("file doesn't exist") || 
                       error.localizedDescription.contains("no such file") {
                        let errorMessage = "Model not found locally. Please download the model first with an internet connection."
                        continuation.finish(throwing: NSError(domain: "ModelError", 
                                                            code: 404, 
                                                            userInfo: [NSLocalizedDescriptionKey: errorMessage]))
                    } else {
                        continuation.finish(throwing: error)
                    }
                }
                
                running = false
            }
        }
    }
}
