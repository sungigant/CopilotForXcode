import SwiftUI
import Combine
import GitHubCopilotService
import Persist

struct MCPToolsListView: View {
    @ObservedObject private var mcpToolManager = CopilotMCPToolManagerObservable.shared
    @State private var serverToggleStates: [String: Bool] = [:]
    @State private var isSearchBarVisible: Bool = false
    @State private var searchText: String = ""
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GroupBox(
                label:
                    HStack(alignment: .center) {
                        Text("Available MCP Tools").fontWeight(.bold)
                        Spacer()
                        if isSearchBarVisible {
                            HStack(spacing: 5) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                
                                TextField("Search tools...", text: $searchText)
                                .accessibilityIdentifier("searchTextField")
                                .accessibilityLabel("Search MCP tools")
                                .textFieldStyle(PlainTextFieldStyle())
                                .focused($isSearchFieldFocused)
                                
                                if !searchText.isEmpty {
                                    Button(action: { searchText = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.leading, 7)
                            .padding(.trailing, 3)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color(.textBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(isSearchFieldFocused ?
                                        Color(red: 0, green: 0.48, blue: 1).opacity(0.5) :
                                        Color.gray.opacity(0.4), lineWidth: isSearchFieldFocused ? 3 : 1
                                    )
                            )
                            .cornerRadius(5)
                            .frame(width: 212, height: 20, alignment: .leading)
                            .shadow(color: Color(red: 0, green: 0.48, blue: 1).opacity(0.5), radius: isSearchFieldFocused ? 1.25 : 0, x: 0, y: 0)
                            .shadow(color: .black.opacity(0.05), radius: 0, x: 0, y: 0)
                            .shadow(color: .black.opacity(0.3), radius: 1.25, x: 0, y: 0.5)
                            .padding(2)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        } else {
                            Button(action: { withAnimation(.easeInOut) { isSearchBarVisible = true } }) {
                                Image(systemName: "magnifyingglass")
                                    .padding(.trailing, 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(height: 24)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .clipped()
            ) {
                let filteredServerTools = filteredMCPServerTools()
                if filteredServerTools.isEmpty {
                    EmptyStateView()
                } else {
                    ToolsListView(
                        mcpServerTools: filteredServerTools,
                        serverToggleStates: $serverToggleStates,
                        searchKey: searchText,
                        expandedServerNames: expandedServerNames(filteredServerTools: filteredServerTools)
                    )
                }
            }
            .groupBoxStyle(CardGroupBoxStyle())
        }
        .contentShape(Rectangle()) // Allow the VStack to receive taps for dismissing focus
        .onTapGesture {
            if isSearchFieldFocused { // Only dismiss focus if the search field is currently focused
                isSearchFieldFocused = false
            }
        }
        .onAppear(perform: updateServerToggleStates)
        .onChange(of: mcpToolManager.availableMCPServerTools) { _ in 
            updateServerToggleStates()
        }
        .onChange(of: isSearchFieldFocused) { focused in
            if !focused && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                withAnimation(.easeInOut) {
                    isSearchBarVisible = false
                }
            }
        }
        .onChange(of: isSearchBarVisible) { newIsVisible in
            if newIsVisible {
                // When isSearchBarVisible becomes true, schedule focusing the TextField.
                // The delay helps ensure the TextField is rendered and ready.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFieldFocused = true
                }
            }
        }
    }

    private func updateServerToggleStates() {
        serverToggleStates = mcpToolManager.availableMCPServerTools.reduce(into: [:]) { result, server in
            result[server.name] = !server.tools.isEmpty && !server.tools.allSatisfy{ $0._status != .enabled }
        }
    }

    private func filteredMCPServerTools() -> [MCPServerToolsCollection] {
        let key = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return mcpToolManager.availableMCPServerTools }
        return mcpToolManager.availableMCPServerTools.compactMap { server in
            let filteredTools = server.tools.filter { tool in
                tool.name.lowercased().contains(key) || (tool.description?.lowercased().contains(key) ?? false)
            }
            if filteredTools.isEmpty { return nil }
            return MCPServerToolsCollection(
                name: server.name,
                status: server.status,
                tools: filteredTools,
                error: server.error
            )
        }
    }

    private func expandedServerNames(filteredServerTools: [MCPServerToolsCollection]) -> Set<String> {
        // Expand all groups that have at least one tool in the filtered list
        Set(filteredServerTools.map { $0.name })
    }
}

/// Empty state view when no tools are available
private struct EmptyStateView: View {
    var body: some View {
        Text("No MCP tools available. Make sure your MCP server is configured correctly and running.")
            .foregroundColor(.secondary)
    }
}

// Private components now defined in separate files:
// MCPToolsListContainerView - in MCPToolsListContainerView.swift 
// MCPServerToolsSection - in MCPServerToolsSection.swift
// MCPToolRow - in MCPToolRowView.swift

/// Private alias for maintaining backward compatibility
private typealias ToolsListView = MCPToolsListContainerView
private typealias ServerToolsSection = MCPServerToolsSection
private typealias ToolRow = MCPToolRow
