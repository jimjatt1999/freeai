import Foundation
import SwiftUI
import PDFKit
import QuickLook
import NaturalLanguage

class DocumentProcessor: ObservableObject {
    @Published var processingState: DocumentProcessingState = .idle
    @Published var progress: Double = 0.0
    @Published var documentTitle: String = ""
    @Published var documentSummary: String = ""
    @Published var chunks: [String] = []
    @Published var isCancelled: Bool = false
    
    private let maxChunkSize = 2000 // Maximum characters per chunk
    private let llm: LLMEvaluator
    private let maxSummarySize = 8000 // Maximum characters for final summary
    private let isCancelledBinding: Binding<Bool>
    
    init(llm: LLMEvaluator, isCancelledBinding: Binding<Bool>) {
        self.llm = llm
        self.isCancelledBinding = isCancelledBinding
    }
    
    // Main processing function
    func processDocument(at url: URL) async {
        do {
            // Extract document title from filename
            documentTitle = url.deletingPathExtension().lastPathComponent
            
            // Update state to loading
            await updateState(.loading, progress: 0.1)
            
            // Extract text based on file type
            let text = try await extractText(from: url)
            
            // Break text into chunks
            await updateState(.chunking, progress: 0.3)
            let chunks = chunkText(text)
            self.chunks = chunks
            
            // Create chunk summaries
            await updateState(.summarizing, progress: 0.5)
            let chunkSummaries = await summarizeChunks(chunks)
            
            // Create final summary
            await updateState(.finalizing, progress: 0.8)
            let finalSummary = await createFinalSummary(chunkSummaries)
            self.documentSummary = finalSummary
            
            // Complete
            await updateState(.complete, progress: 1.0)
            
        } catch {
            await updateState(.error(error.localizedDescription), progress: 0)
        }
    }
    
    // Extract text from document
    private func extractText(from url: URL) async throws -> String {
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "pdf":
            return try extractTextFromPDF(url)
        case "txt":
            return try String(contentsOf: url, encoding: .utf8)
        case "docx", "doc":
            // For DOCX, we'd need a third-party library or use NSAttributedString's document types
            // This is a simplified placeholder
            return "Document text extraction for DOCX not fully implemented."
        default:
            throw DocumentError.unsupportedFileFormat
        }
    }
    
    // Extract text from PDF
    private func extractTextFromPDF(_ url: URL) throws -> String {
        guard let pdf = PDFDocument(url: url) else {
            throw DocumentError.failedToLoadPDF
        }
        
        var text = ""
        for i in 0..<pdf.pageCount {
            if let page = pdf.page(at: i), let pageText = page.string {
                text += pageText + "\n\n"
            }
        }
        
        return text
    }
    
    // Break text into manageable chunks
    private func chunkText(_ text: String) -> [String] {
        var chunks: [String] = []
        var currentChunk = ""
        
        // Try to split by paragraphs first
        let paragraphs = text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        for paragraph in paragraphs {
            if (currentChunk + paragraph).count <= maxChunkSize {
                currentChunk += paragraph + "\n"
            } else {
                // If paragraph is too long, split by sentences
                if paragraph.count > maxChunkSize {
                    let sentences = splitIntoSentences(paragraph)
                    for sentence in sentences {
                        if (currentChunk + sentence).count <= maxChunkSize {
                            currentChunk += sentence + " "
                        } else {
                            if !currentChunk.isEmpty {
                                chunks.append(currentChunk)
                                currentChunk = sentence + " "
                            } else {
                                // If a single sentence is too long, split by word count
                                let words = sentence.components(separatedBy: .whitespaces)
                                var wordChunk = ""
                                
                                for word in words {
                                    if (wordChunk + word).count <= maxChunkSize {
                                        wordChunk += word + " "
                                    } else {
                                        chunks.append(wordChunk)
                                        wordChunk = word + " "
                                    }
                                }
                                
                                if !wordChunk.isEmpty {
                                    currentChunk = wordChunk
                                }
                            }
                        }
                    }
                } else {
                    chunks.append(currentChunk)
                    currentChunk = paragraph + "\n"
                }
            }
        }
        
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        
        return chunks
    }
    
    // Split text into sentences using NaturalLanguage
    private func splitIntoSentences(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range])
            sentences.append(sentence)
            return true
        }
        
        return sentences.isEmpty ? [text] : sentences
    }
    
    // Summarize individual chunks
    private func summarizeChunks(_ chunks: [String]) async -> [String] {
        var summaries: [String] = []
        let totalChunks = chunks.count
        
        for (index, chunk) in chunks.enumerated() {
            // Check for cancellation before each chunk
            if isCancelledBinding.wrappedValue { 
                print("Summarization cancelled.")
                return [] // Return empty array on cancellation
            }
            
            let truncatedChunk = String(chunk.prefix(maxChunkSize))
            let prompt = "Summarize the following text in a concise manner, preserving key information:\n\n\(truncatedChunk)"
            
            let modelName = await llm.modelConfiguration.name
            let thread = Thread()
            
            // Add a user message with the document content to the thread
            let userMessage = Message(role: .user, content: prompt, thread: thread)
            
            let output = await llm.generate(
                modelName: modelName,
                thread: thread,
                systemPrompt: "You are a document summarization assistant. Create concise summaries that preserve the most important information."
            )
            
            summaries.append(output)
            
            // Update progress based on chunk completion
            let newProgress = 0.5 + (0.3 * Double(index + 1) / Double(totalChunks))
            await updateState(.summarizing, progress: newProgress)
        }
        
        return summaries
    }
    
    // Create a final summary from chunk summaries
    private func createFinalSummary(_ summaries: [String]) async -> String {
        // Check for cancellation before combining
        if isCancelledBinding.wrappedValue { 
            print("Final summary generation cancelled.")
            return "" // Return empty string on cancellation
        }
        
        let combinedSummaries = summaries.joined(separator: "\n\n")
        let truncatedSummaries = String(combinedSummaries.prefix(maxSummarySize))
        
        let prompt = "Create a comprehensive summary of the following document summaries, organizing the information in a coherent way:\n\n\(truncatedSummaries)"
        
        let modelName = await llm.modelConfiguration.name
        let thread = Thread()
        
        // Add a user message with the combined summaries to the thread
        let userMessage = Message(role: .user, content: prompt, thread: thread)
        
        let output = await llm.generate(
            modelName: modelName,
            thread: thread,
            systemPrompt: "You are a document summarization assistant. Create a well-structured, comprehensive summary that maintains the document's key information and flow."
        )
        
        return output
    }
    
    // Update state on main thread
    @MainActor
    private func updateState(_ state: DocumentProcessingState, progress: Double) {
        self.processingState = state
        self.progress = progress
    }
}

// Document processing errors
enum DocumentError: Error, LocalizedError {
    case unsupportedFileFormat
    case failedToLoadPDF
    case failedToExtractText
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFileFormat:
            return "This document format is not supported."
        case .failedToLoadPDF:
            return "Failed to load the PDF document."
        case .failedToExtractText:
            return "Failed to extract text from the document."
        }
    }
} 