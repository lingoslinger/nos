//
//  ComposerActionBar.swift
//  Nos
//
//  Created by Matthew Lorentz on 5/3/23.
//

import SwiftUI

/// A horizontal bar that gives the user options to customize their message in the message composer.
struct ComposerActionBar: View {
    
    @Binding var expirationTime: TimeInterval?
    @Binding var postText: NSAttributedString
    @State var fileStorageAPI: FileStorageAPI = NoopFileStorageAPI()
    
    enum SubMenu {
        case expirationDate
    }
    
    @State private var subMenu: SubMenu?

    var backArrow: some View {
        Button { 
            subMenu = .none
        } label: { 
            Image.backChevron
                .frame(minWidth: 44, minHeight: 44)
        }
        .transition(.opacity)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            switch subMenu {
            case .none:
                // Attach Media
                ImagePickerButton { image in
                    Task {
                        do {
                            let attachedFile = AttachedFile(data: image.jpegData(compressionQuality: 0.9)!)
                            let url = try await fileStorageAPI.upload(file: attachedFile)
                            let tmpPostText = NSMutableAttributedString(attributedString: self.postText)
                            tmpPostText.append(NSAttributedString(string: url.absoluteString))
                            self.postText = tmpPostText
                        } catch {
                            print("error uploading image: \(error)")
                        }
                    }
                } label: {
                    Image.attachMediaButton
                        .foregroundColor(.secondaryText)
                        .frame(minWidth: 44, minHeight: 44)                }
                .padding(.leading, 8)
                .accessibilityLabel(Localized.attachMedia.view)

                // Expiration Time
                if let expirationTime, let option = ExpirationTimeOption(rawValue: expirationTime) {
                    ExpirationTimeButton(
                        model: option, 
                        showClearButton: true,
                        isSelected: Binding(get: { 
                            self.expirationTime == option.timeInterval
                        }, set: { 
                            self.expirationTime = $0 ? option.timeInterval : nil
                        })
                    )
                    .accessibilityLabel(Localized.expirationDate.view)
                    .padding(12)
                } else {
                    Button { 
                        subMenu = .expirationDate
                    } label: { 
                        Image.disappearingMessages
                            .foregroundColor(.secondaryText)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }

            case .expirationDate:
                backArrow
                ScrollView(.horizontal) {
                    HStack {
                        PlainText(Localized.noteDisappearsIn.string)
                            .font(.clarityCaption)
                            .foregroundColor(.secondaryText)
                            .transition(.move(edge: .trailing))
                            .padding(10)
                        
                        ExpirationTimePicker(expirationTime: $expirationTime)
                            .padding(.vertical, 12)
                    }
                }
            }
            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: subMenu)
        .transition(.move(edge: .leading))
        .onChange(of: expirationTime) { _ in
            subMenu = .none
        }
        .background(Color.actionBar)
    }
}

struct ComposerActionBar_Previews: PreviewProvider {
    
    @State static var emptyExpirationTime: TimeInterval? 
    @State static var setExpirationTime: TimeInterval? = 60 * 60
    @State static var postText: NSAttributedString = NSAttributedString()
    
    static var previews: some View {
        VStack {
            Spacer()
            ComposerActionBar(expirationTime: $emptyExpirationTime, postText: $postText)
            Spacer()
            ComposerActionBar(expirationTime: $setExpirationTime, postText: $postText)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.appBg)
        .environment(\.sizeCategory, .extraExtraLarge)
    }
}
