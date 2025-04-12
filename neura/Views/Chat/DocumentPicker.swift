import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var processState: DocumentProcessingState
    @Binding var documentTitle: String
    @Binding var documentSummary: String
    @Binding var progress: Double
    @Binding var isCancelled: Bool
    
    @Environment(LLMEvaluator.self) var llm
    @EnvironmentObject var appManager: AppManager
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Define the document types we support
        let supportedTypes: [UTType] = [
            .pdf,                 // PDF documents
            .plainText,           // Plain text files
            UTType(filenameExtension: "docx") ?? .plainText,  // Word documents
            UTType(filenameExtension: "doc") ?? .plainText    // Legacy Word documents
        ]
        
        // Create document picker with supported types
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // Nothing to update
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        private var documentProcessor: DocumentProcessor? = nil
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Security: Ensure we have access to this file
            guard url.startAccessingSecurityScopedResource() else {
                DispatchQueue.main.async {
                    self.parent.processState = .error("Permission denied to access the document.")
                }
                return
            }
            
            // Create document processor with LLM
            self.documentProcessor = DocumentProcessor(llm: parent.llm, isCancelledBinding: parent.$isCancelled)
            
            // Process document in background
            Task {
                // Link cancellation state BEFORE processing
                // documentProcessor?.isCancelled = parent.isCancelled
                
                // Observe document processor state
                setupObservers()
                
                // Process document
                await documentProcessor?.processDocument(at: url)
                
                // Stop accessing the resource when done
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        private func setupObservers() {
            guard let processor = documentProcessor else { return }
            
            // Observe progress and state changes
            Task { @MainActor in
                for await _ in processor.$progress.values {
                    parent.progress = processor.progress
                }
            }
            
            Task { @MainActor in
                for await _ in processor.$processingState.values {
                    parent.processState = processor.processingState
                }
            }
            
            Task { @MainActor in
                for await _ in processor.$documentTitle.values {
                    parent.documentTitle = processor.documentTitle
                }
            }
            
            Task { @MainActor in
                for await _ in processor.$documentSummary.values {
                    parent.documentSummary = processor.documentSummary
                }
            }
            
            // Observe the external cancellation flag
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // Handle cancellation
            DispatchQueue.main.async {
                self.parent.processState = .idle
            }
        }
    }
} 