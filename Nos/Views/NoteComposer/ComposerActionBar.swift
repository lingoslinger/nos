import Dependencies
import Foundation
import SwiftUI
import SwiftUINavigation

/// A horizontal bar that gives the user options to customize their message in the message composer.
struct ComposerActionBar: View {

    /// A controller for the text entered in the note composer.
    @Binding var editingController: NoteEditorController

    /// The expiration time for the note, if any.
    @Binding var expirationTime: TimeInterval?

    /// Whether we're currently uploading an image or not.
    @Binding var isUploadingImage: Bool

    /// Turns on and off a Preview switch.
    @Binding var showPreview: Bool

    @Dependency(\.fileStorageAPIClient) private var fileStorageAPIClient

    enum SubMenu {
        case expirationDate
    }

    @State private var subMenu: SubMenu?
    @State private var alert: AlertState<AlertAction>?

    fileprivate enum AlertAction {
    }

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
                defaultMenu
            case .expirationDate:
                backArrow
                ScrollView(.horizontal) {
                    HStack {
                        Text(.localizable.noteDisappearsIn)
                            .font(.clarityRegular(.caption))
                            .foregroundColor(.secondaryTxt)
                            .transition(.move(edge: .trailing))
                            .padding(10)

                        ExpirationTimePicker(expirationTime: $expirationTime)
                            .padding(.vertical, 12)
                    }
                }
            }
            Spacer()
        }
        .frame(minHeight: 56)
        .animation(.easeInOut(duration: 0.2), value: subMenu)
        .transition(.move(edge: .leading))
        .onChange(of: expirationTime) { _, _ in
            subMenu = .none
        }
        .alert(unwrapping: $alert) { (_: AlertAction?) in
        }
        .background(
            LinearGradient(
                colors: [Color.actionBarGradientTop, Color.actionBarGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .frame(width: nil, height: 1, alignment: .top)
                .foregroundColor(Color.actionBarBorderTop),
            alignment: .top
        )
    }

    var defaultMenu: some View {
        HStack(spacing: 0) {
            if !showPreview {
                attachMediaView
                expirationTimeView
            }
            Spacer()
            previewToggle
        }
    }

    /// Attach Media View
    private var attachMediaView: some View {
        ImagePickerButton(cameraDevice: .rear, mediaTypes: [.image, .movie]) { imageURL in
            Task {
                await uploadImage(at: imageURL)
            }
        } label: {
            Image.attachMediaButton
                .foregroundColor(.secondaryTxt)
                .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.leading, 8)
        .accessibilityLabel(Text(.localizable.attachMedia))
    }

    /// Expiration Time
    private var expirationTimeView: some View {
        Group {
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
                .accessibilityLabel(Text(.localizable.expirationDate))
                .padding(12)
            } else {
                Button {
                    subMenu = .expirationDate
                } label: {
                    Image.disappearingMessages
                        .foregroundColor(.secondaryTxt)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
    }

    /// Preview Toggle
    private var previewToggle: some View {
        Group {
            Text(.localizable.preview)
                .padding(.horizontal, 10)
                .foregroundColor(Color.secondaryTxt)
            Toggle(isOn: $showPreview) {
                EmptyView()
            }
            .labelsHidden()
            .disabled(editingController.isEmpty)
        }
    }

    /// Uploads an image at the given URL to a file storage service.
    /// - Parameter imageURL: File URL of the image the user wants to upload.
    private func uploadImage(at imageURL: URL) async {
        do {
            startUploadingImage()
            let url = try await fileStorageAPIClient.upload(fileAt: imageURL, isProfilePhoto: false)
            await editingController.append(url)
            endUploadingImage()
        } catch {
            endUploadingImage()

            alert = AlertState {
                TextState(String(localized: .imagePicker.errorUploadingFile))
            } message: {
                if case let FileStorageAPIClientError.uploadFailed(message) = error, let message {
                    TextState(
                        String(localized: .imagePicker.errorUploadingFileWithMessage(message))
                    )
                } else {
                    TextState(String(localized: .imagePicker.errorUploadingFileMessage))
                }
            }
        }
    }

    private func startUploadingImage() {
        self.isUploadingImage = true
    }
    
    private func endUploadingImage() {
        self.isUploadingImage = false
        self.subMenu = .none
    }
}

struct ComposerActionBar_Previews: PreviewProvider {
    
    @State static var controller = NoteEditorController()
    @State static var emptyExpirationTime: TimeInterval?
    @State static var setExpirationTime: TimeInterval? = 60 * 60
    @State static var showPreview = false
    
    static var previews: some View {
        VStack {
            Spacer()
            ComposerActionBar(
                editingController: $controller, 
                expirationTime: $emptyExpirationTime, 
                isUploadingImage: .constant(false),
                showPreview: $showPreview
            )
            Spacer()
            ComposerActionBar(
                editingController: $controller, 
                expirationTime: $setExpirationTime, 
                isUploadingImage: .constant(false),
                showPreview: $showPreview
            )
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.appBg)
        .environment(\.sizeCategory, .extraExtraLarge)
    }
}
