//
//  ChatMessageView.swift
//  WorkspaceBeta
//
//

import SwiftUI
import Kingfisher

struct ChatMessageView: View {

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
                ContentMessageView(message: message,
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
                ContentMessageView(message: message,
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
    var message: MessageResponseData
    var isCurrentUser: Bool
    let currentJitsiBaseUrl: String
    let enhanceImageUrl: (String) -> String
    let enhanceImageRequest: (URLRequest) -> URLRequest
    let onTapOnCallView: (String) -> Void

    var body: some View {
        if let imageMessageParts {
            ImageMessageView(text: imageMessageParts.0, messageUrlString: enhanceImageUrl(imageMessageParts.1), message: message, isCurrentUser: isCurrentUser, enhanceImageRequest: enhanceImageRequest)
        } else if message.payload.content.contains(currentJitsiBaseUrl) {
            let roomName = message.payload.content.split(separator: "/").last.map(String.init) ?? ""
            CallMessageView(message: message, roomName: roomName, onTapOnCallView: onTapOnCallView)
        } else {
            TextMessageView(message: message, isCurrentUser: isCurrentUser)
        }
    }

    var imageMessageParts: (String, String)? {
        let imageRegex = try? Regex(#"^(?:(?<line>[^\r\n]*)\R)?\[[^\]]*]\((?<path>/user_uploads/[^)]+)\)"#)

        guard let imageRegex else { return nil }

        let match = message.payload.content.firstMatch(of: imageRegex)

        guard let match else { return nil }
        let line = match.output[1].substring
        let path = match.output[2].substring
        guard let path else { return nil }
        return (String(line ?? ""), String(path))
    }
}

struct TextMessageView: View {
    var message: MessageResponseData
    var isCurrentUser: Bool

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(message.author?.displayableName ?? "")
                    .foregroundStyle(isCurrentUser ? Color.indicatorBlue : Color.indicatorPurple)
                    .font(.system(size: 14, weight: .medium))
            }
            HStack(alignment: .bottom) {
                Text(LocalizedStringKey(message.payload.content))
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

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}
