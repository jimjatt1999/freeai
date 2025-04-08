//
//  LLMEvaluator.swift
//  free ai
//
//  Created by Jordan Singer on 10/4/24.
//

import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import SwiftUI

enum LLMEvaluatorError: Error {
    case modelNotFound(String)
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
            
            Task { @MainActor in
                self.modelInfo = "Preparing to download \(self.modelConfiguration.name)..."
            }

            let modelContainer = try await LLMModelFactory.shared.loadContainer(configuration: model) {
                progress in
                Task { @MainActor in
                    self.modelInfo =
                        "Downloading \(self.modelConfiguration.name): \(Int(progress.fractionCompleted * 100))%"
                    self.progress = progress.fractionCompleted
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

            if modelContainer.configuration.modelType == .reasoning {
                isThinking = true
            }

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

        } catch {
            output = "Failed: \(error)"
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
                    
                    if modelContainer.configuration.modelType == .reasoning {
                        isThinking = true
                    }
                    
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
                    
                } catch {
                    continuation.finish(throwing: error)
                }
                
                running = false
            }
        }
    }
}
