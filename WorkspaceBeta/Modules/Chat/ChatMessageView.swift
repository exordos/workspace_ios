//
//  ChatMessageView.swift
//  WorkspaceBeta
//
//

import SwiftUI
import Kingfisher

enum MessagePart: Hashable {
    case image(fileName: String, urn: String)
    case file(fileName: String, uuid: String)
    case quote(displayName: String, uuid: String, text: String)
    case plainText(text: String)
}

struct ChatMessageView: View {
    let viewModel: ChatViewModel
    let message: MessageResponseData
    let isCurrentUser: Bool
    let currentJitsiBaseUrl: String
    let enhanceImageUrl: (String) -> String
    let enhanceImageRequest: (URLRequest) -> URLRequest
    let onTapOnCallView: (String) -> Void

    var body: some View {
        if isCurrentUser {
            HStack(alignment: .bottom, spacing: 15) {
                Spacer()
                ContentMessageView(viewModel: viewModel,
                                   message: message,
                                   isCurrentUser: isCurrentUser,
                                   currentJitsiBaseUrl: currentJitsiBaseUrl,
                                   enhanceImageUrl: enhanceImageUrl,
                                   enhanceImageRequest: enhanceImageRequest,
                                   onTapOnCallView: onTapOnCallView)
                    .cornerRadius(8, corners: [.topLeft, .topRight, .bottomLeft])
                    .cornerRadius(2, corners: [.bottomRight])
            }
        } else {
            HStack(alignment: .bottom, spacing: 15) {
                ContentMessageView(viewModel: viewModel,
                                   message: message,
                                   isCurrentUser: isCurrentUser,
                                   currentJitsiBaseUrl: currentJitsiBaseUrl,
                                   enhanceImageUrl: enhanceImageUrl,
                                   enhanceImageRequest: enhanceImageRequest,
                                   onTapOnCallView: onTapOnCallView)
                    .cornerRadius(8, corners: [.topLeft, .topRight, .bottomRight])
                    .cornerRadius(2, corners: [.bottomLeft])
                Spacer()
            }
        }
    }
}

struct ContentMessageView: View {
    let viewModel: ChatViewModel
    var message: MessageResponseData
    var isCurrentUser: Bool
    let currentJitsiBaseUrl: String
    let enhanceImageUrl: (String) -> String
    let enhanceImageRequest: (URLRequest) -> URLRequest
    let onTapOnCallView: (String) -> Void

    var body: some View {
        if message.payload.content.contains(currentJitsiBaseUrl) {
            let roomName = message.payload.content.split(separator: "/").last.map(String.init) ?? ""
            CallMessageView(message: message, roomName: roomName, onTapOnCallView: onTapOnCallView)
        } else {
            TextMessageView(viewModel: viewModel, message: message, isCurrentUser: isCurrentUser)
        }
    }
}

struct TextMessageView: View {
    let viewModel: ChatViewModel
    var message: MessageResponseData
    var isCurrentUser: Bool

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(message.author?.displayableName ?? "")
                    .foregroundStyle(isCurrentUser ? Color.indicatorBlue : Color.indicatorPurple)
                    .font(.system(size: 14, weight: .medium))
            }
            let messageParts = MarkdownPayloadParser.parse(message.payload.content)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading) {
                    ForEach(messageParts, id: \.self) { messagePart in
                        switch messagePart {
                        case let .image(fileName: fileName, urn: urn):
                            if let avatarUrlString = UrnParser.parse(urn: urn, baseUrl: viewModel.eventHandler.userProfile.selectedServer?.baseUrl ?? ""), let avatarUrl = URL(string: avatarUrlString) {
                                KFImage(avatarUrl)
                                    .requestModifier(AnyModifier { request in
                                        let modifiedRequest = viewModel.apiClient.addHeaders(to: request)
                                        return modifiedRequest
                                    })
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Text(fileName)
                            }
                        case let .file(fileName: fileName, uuid: uuid):
                            Text(fileName)
                        case let .quote(displayName: displayName, uuid: uuid, text: text):
                            QuotedMessagePartView(quotedMessageUuid: uuid, isOwn: message.isOwn, viewModel: viewModel)
                        case let .plainText(text: text):
                            Text(LocalizedStringKey(text))
                                .lineLimit(Int.max)
                                .foregroundStyle(Color.textHeaders)
                                .font(.system(size: 14))
                        }
                    }
                }
                Text(DateFormatter.timeFormatter.string(from: message.createdAt))
                    .foregroundStyle(Color.messageTimeColor)
                    .font(.system(size: 12))
            }
        }
        .padding(10)
        .background(isCurrentUser ? Color.messageOwnBackground : Color.messageBackground)
    }
}

struct ImageMessageView: View {
    let text: String
    var messageUrlString: String
    var message: MessageResponseData
    var isCurrentUser: Bool
    let enhanceImageRequest: (URLRequest) -> URLRequest

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(message.author?.displayableName ?? "")
                    .foregroundStyle(isCurrentUser ? Color.indicatorBlue : Color.indicatorPurple)
                    .font(.system(size: 14, weight: .medium))
            }
            if let messageUrl = URL(string: messageUrlString) {
                KFImage(messageUrl)
                    .requestModifier(AnyModifier { request in
                        let modifiedRequest = enhanceImageRequest(request)
                        return modifiedRequest
                    })
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 100.0)
            }
            HStack(alignment: .bottom) {
                Text(LocalizedStringKey(text))
                    .lineLimit(Int.max)
                    .foregroundStyle(Color.textHeaders)
                    .font(.system(size: 14))
                Text(DateFormatter.timeFormatter.string(from: message.createdAt))
                    .foregroundStyle(Color.messageTimeColor)
                    .font(.system(size: 12))
            }
        }
        .padding(10)
        .background(isCurrentUser ? Color.messageOwnBackground : Color.messageBackground)
    }
}

struct CallMessageView: View {
    var message: MessageResponseData
    let roomName: String
    let onTapOnCallView: (String) -> Void

    var body: some View {
        VStack(alignment: .trailing) {
            HStack {
                Text("Звонок")
                    .foregroundStyle(Color.indicatorGreen)
                    .font(.system(size: 14, weight: .medium))
                Text(LocalizedStringKey(roomName))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(Color.textHeaders)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12.0)
                Image(systemName: "phone.fill")
                    .foregroundStyle(Color.indicatorGreen)
            }
            HStack(alignment: .bottom) {
                Text(DateFormatter.timeFormatter.string(from: message.createdAt))
                    .foregroundStyle(Color.messageTimeColor)
                    .font(.system(size: 12))
            }
        }
        .onTapGesture {
            onTapOnCallView(roomName)
        }
        .padding(10)
        .background(Color.messageActiveCallBackground)
    }
}

struct QuotedMessagePartView: View {
    let quotedMessageUuid: String
    let isOwn: Bool
    let viewModel: ChatViewModel

    var body: some View {
        let message = viewModel.model.messages.first { $0.uuid == quotedMessageUuid }
        if let message {
            VStack(alignment: .leading) {
                Text(message.author?.displayableName ?? "Цитируемое сообщение")
                    .foregroundStyle(Color.indicatorOrange)
                    .font(.system(size: 12.0))
                    .lineLimit(1)
                Text(message.payload.content)
            }
            .padding(8.0)
            .background(isOwn ? Color.messageOwnSelectedBg : Color.messageBackground)
            .referenced()
        }
    }
}

extension View {
    func referenced() -> some View {
        modifier(ReferenceModifier())
    }
}

struct ReferenceModifier : ViewModifier {

    func body(content: Content) -> some View {
        content
            .padding(.leading, 4)
            .background(Color.indicatorOrange, in: RoundedRectangle(cornerRadius: 12))
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

enum MarkdownPayloadParser {
    private static let imageRegex = try! NSRegularExpression(
        pattern: #"\[((?:\\.|[^\]\\])*)\]\((urn:image:[^)]+)\)"#
    )
    private static let fileRegex = try! NSRegularExpression(
        pattern: #"\[((?:\\.|[^\]\\])*)\]\(urn:file:([^)]+)\)"#
    )
    private static let quoteRegex = try! NSRegularExpression(
        pattern: #"\[((?:\\.|[^\]\\])*)\]\(urn:quote:([0-9a-fA-F-]{36})(?:\?text=([^\s)&#]+))?\)"#
    )
    private static let unescapeRegex = try! NSRegularExpression(pattern: #"\\(.)"#)
    static func parse(_ content: String) -> [MessagePart] {
        let input = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return [] }
        var elements: [MessagePart] = []
        var index = input.startIndex
        while index < input.endIndex {
            guard let next = findNextSpecial(in: input, from: index) else {
                appendPlainText(to: &elements, raw: String(input[index...]))
                break
            }
            if next.start > index {
                appendPlainText(to: &elements, raw: String(input[index..<next.start]))
            }
            elements.append(next.element)
            index = next.end
        }
        return elements
    }
    private static func appendPlainText(to elements: inout [MessagePart], raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            elements.append(.plainText(text: text))
        }
    }
    private struct SpecialMatch {
        let start: String.Index
        let end: String.Index
        let element: MessagePart
    }
    private static func findNextSpecial(in input: String, from fromIndex: String.Index) -> SpecialMatch? {
        var searchIndex = fromIndex
        while searchIndex < input.endIndex {
            let image = firstMatch(of: imageRegex, in: input, from: searchIndex)
            let file = firstMatch(of: fileRegex, in: input, from: searchIndex)
            let quote = firstMatch(of: quoteRegex, in: input, from: searchIndex)
            var candidates: [SpecialMatch] = []
            if let image {
                candidates.append(
                    SpecialMatch(
                        start: image.range.lowerBound,
                        end: image.range.upperBound,
                        element: .image(
                            fileName: unescape(image.group(1, in: input)),
                            urn: image.group(2, in: input)
                        )
                    )
                )
            }
            if let file {
                candidates.append(
                    SpecialMatch(
                        start: file.range.lowerBound,
                        end: file.range.upperBound,
                        element: .file(
                            fileName: unescape(file.group(1, in: input)),
                            uuid: file.group(2, in: input)
                        )
                    )
                )
            }
            if let quote {
                let encoded = quote.group(3, in: input)
                if let selectedText = encoded.removingPercentEncoding {
                    candidates.append(
                        SpecialMatch(
                            start: quote.range.lowerBound,
                            end: quote.range.upperBound,
                            element: .quote(
                                displayName: unescape(quote.group(1, in: input)),
                                uuid: quote.group(2, in: input),
                                text: selectedText
                            )
                        )
                    )
                }
            }
            guard let next = candidates.min(by: { $0.start < $1.start }) else {
                return nil
            }
            let literals = [findCodeBlock(in: input, from: searchIndex), findInlineCode(in: input, from: searchIndex)]
                .compactMap { $0 }
            if let literal = literals.min(by: { $0.start < $1.start }),
               literal.start <= next.start {
                searchIndex = literal.end
                continue
            }
            return next
        }
        return nil
    }

    private static func findCodeBlock(in input: String, from fromIndex: String.Index) -> SpecialMatch? {
        let openingRegex = try! NSRegularExpression(
            pattern: #"(?m)^(`{3,}|~{3,})[^\r\n]*\r?\n"#
        )
        guard let opening = firstMatch(of: openingRegex, in: input, from: fromIndex) else {
            return nil
        }
        let fence = opening.group(1, in: input)
        let fenceChar = String(fence.first!)
        let closingRegex = try! NSRegularExpression(
            pattern: #"(?m)^\#(fenceChar){\#(fence.count),}[ \t]*(?:\r?\n|$)"#
        )
        let afterOpening = opening.range.upperBound
        let closing = firstMatch(of: closingRegex, in: input, from: afterOpening)
        let end = closing?.range.upperBound ?? input.endIndex
        return SpecialMatch(
            start: opening.range.lowerBound,
            end: end,
            element: .plainText(text: String(input[opening.range.lowerBound..<end]))
        )
    }
    private static func findInlineCode(in input: String, from fromIndex: String.Index) -> SpecialMatch? {
        let openingRegex = try! NSRegularExpression(pattern: #"`+"#)
        guard let opening = firstMatch(of: openingRegex, in: input, from: fromIndex) else {
            return nil
        }
        let ticks = opening.group(0, in: input)
        let closingRegex = try! NSRegularExpression(
            pattern: #"(?<!`)`{\#(ticks.count)}(?!`)"#
        )
        guard let closing = firstMatch(of: closingRegex, in: input, from: opening.range.upperBound) else {
            return nil
        }
        let end = closing.range.upperBound
        return SpecialMatch(
            start: opening.range.lowerBound,
            end: end,
            element: .plainText(text: String(input[opening.range.lowerBound..<end]))
        )
    }
    // MARK: - Helpers
    struct RegexMatch {
        let range: Range<String.Index>
        let nsMatch: NSTextCheckingResult
    }
    private static func firstMatch(
        of regex: NSRegularExpression,
        in input: String,
        from fromIndex: String.Index
    ) -> RegexMatch? {
        let nsRange = NSRange(fromIndex..<input.endIndex, in: input)
        guard let match = regex.firstMatch(in: input, options: [], range: nsRange),
              let range = Range(match.range, in: input) else {
            return nil
        }
        return RegexMatch(range: range, nsMatch: match)
    }
    private static func unescape(_ value: String) -> String {
        let nsRange = NSRange(value.startIndex..<value.endIndex, in: value)
        return unescapeRegex.stringByReplacingMatches(
            in: value,
            options: [],
            range: nsRange,
            withTemplate: "$1"
        )
    }
}
private extension NSTextCheckingResult {
    func group(_ index: Int, in string: String) -> String {
        guard numberOfRanges > index,
              let range = Range(range(at: index), in: string) else {
            return ""
        }
        return String(string[range])
    }
}
private extension MarkdownPayloadParser.RegexMatch {
    func group(_ index: Int, in string: String) -> String {
        nsMatch.group(index, in: string)
    }
}
