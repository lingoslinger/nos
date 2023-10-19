//
//  ProfileView.swift
//  Nos
//
//  Created by Matthew Lorentz on 2/16/23.
//

import SwiftUI
import CoreData
import Dependencies
import SwiftUINavigation

struct ProfileView: View {
    
    @ObservedObject var author: Author
    
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var relayService: RelayService
    @EnvironmentObject private var currentUser: CurrentUser
    @EnvironmentObject private var router: Router
    @Dependency(\.analytics) private var analytics
    
    @State private var showingOptions = false
    @State private var showingReportMenu = false
    @State private var walletConnectIsPresented = false
    
    @State private var subscriptionIds: [String] = []

    @State private var alert: AlertState<Never>?
    
    @FetchRequest
    private var events: FetchedResults<Event>

    @State private var unmutedEvents: [Event] = []

    private func computeUnmutedEvents() async {
        unmutedEvents = events.filter {
            if let author = $0.author {
                let notDeleted = $0.deletedOn.count == 0
                return !author.muted && notDeleted
            }
            return false
        }
    }
    
    init(author: Author) {
        self.author = author
        _events = FetchRequest(fetchRequest: author.allPostsRequest())
    }
    
    func refreshProfileFeed() async {
        // Close out stale requests
        if !subscriptionIds.isEmpty {
            await relayService.decrementSubscriptionCount(for: subscriptionIds)
            subscriptionIds.removeAll()
        }
        
        guard let authorKey = author.hexadecimalPublicKey else {
            return
        }
        
        let authors = [authorKey]
        let textFilter = Filter(authorKeys: authors, kinds: [.text, .delete, .repost, .longFormContent], limit: 50)
        async let textSub = relayService.openSubscription(with: textFilter)
        subscriptionIds.append(await textSub)
        subscriptionIds.append(
            contentsOf: await relayService.requestProfileData(
                for: authorKey, 
                lastUpdateMetadata: author.lastUpdatedMetadata, 
                lastUpdatedContactList: author.lastUpdatedContactList
            )
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                ProfileHeader(author: author)
                    .compositingGroup()
                    .shadow(color: .profileShadow, radius: 10, x: 0, y: 4)
                
                LazyVStack {
                    if unmutedEvents.isEmpty {
                        Localized.noEventsOnProfile.view
                            .padding()
                    } else {
                        ForEach(unmutedEvents) { event in
                            VStack {
                                NoteButton(note: event, hideOutOfNetwork: false)
                                    .padding(.bottom, 15)
                            }
                        }
                    }
                }
                .padding(.top, 10)
            }
            .background(Color.appBg)
        }
        .sheet(isPresented: $walletConnectIsPresented) { 
            USBCWizard()
        }
        .nosNavigationBar(title: .profileTitle)
        .navigationDestination(for: Event.self) { note in
            RepliesView(note: note)
        }                  
        .navigationDestination(for: URL.self) { url in URLView(url: url) }
        .navigationDestination(for: ReplyToNavigationDestination.self) { destination in 
            RepliesView(note: destination.note, showKeyboard: true)
        }
        .navigationDestination(for: MutesDestination.self) { _ in
            MutesView()
        }
        .navigationDestination(for: FollowsDestination.self) { destination in
            FollowsView(title: Localized.follows, authors: destination.follows)
        }
        .navigationDestination(for: FollowersDestination.self) { destination in
            FollowsView(title: Localized.followedBy, authors: destination.followers)
        }
        .navigationDestination(for: RelaysDestination.self) { destination in
            RelayView(author: destination.author, editable: false)
        }
        .navigationBarItems(
            trailing:
                HStack {
                    Button(
                        action: {
                            walletConnectIsPresented = true
                        },
                        label: {
                            Text("USBC")
                        }
                    )
                    Button(
                        action: {
                            showingOptions = true
                        },
                        label: {
                            Image(systemName: "ellipsis")
                        }
                    )
                    .confirmationDialog(Localized.share.string, isPresented: $showingOptions) {
                        Button(Localized.copyUserIdentifier.string) {
                            UIPasteboard.general.string = router.viewedAuthor?.publicKey?.npub ?? ""
                        }
                        Button(Localized.copyLink.string) {
                            UIPasteboard.general.string = router.viewedAuthor?.webLink ?? ""
                        }
                        if let author = router.viewedAuthor {
                            if author == currentUser.author {
                                Button(
                                    action: {
                                        currentUser.editing = true
                                        router.push(author)
                                    },
                                    label: {
                                        Text(Localized.editProfile.string)
                                    }
                                )
                                Button(
                                    action: {
                                        router.push(MutesDestination())
                                    },
                                    label: {
                                        Text(Localized.mutedUsers.string)
                                    }
                                )
                            } else {
                                if author.muted {
                                    Button(Localized.unmuteUser.string) {
                                        Task {
                                            do {
                                                try await router.viewedAuthor?.unmute(viewContext: viewContext)
                                            } catch {
                                                alert = AlertState(title: {
                                                    TextState(Localized.error.string)
                                                }, message: {
                                                    TextState(error.localizedDescription)
                                                })
                                            }
                                        }
                                    }
                                } else {
                                    Button(Localized.mute.string) {
                                        Task { @MainActor in
                                            do {
                                                try await router.viewedAuthor?.mute(viewContext: viewContext)
                                            } catch {
                                                alert = AlertState(title: {
                                                    TextState(Localized.error.string)
                                                }, message: {
                                                    TextState(error.localizedDescription)
                                                })
                                            }
                                        }
                                    }
                                }
                                
                                Button(Localized.reportUser.string, role: .destructive) {
                                    showingReportMenu = true
                                }
                            }
                        }
                    }
                }
        )
        .reportMenu($showingReportMenu, reportedObject: .author(author))
        .task {
            await refreshProfileFeed()
            await computeUnmutedEvents()
        }
        .alert(unwrapping: $alert)
        .onAppear {
            router.viewedAuthor = author
            analytics.showedProfile()
        }
        .refreshable {
            await refreshProfileFeed()
            await computeUnmutedEvents()
        }
        .onChange(of: author.muted) { _ in
            Task {
                await computeUnmutedEvents()
            }
        }
        .onChange(of: author.events.count) { _ in
            Task {
                await computeUnmutedEvents()
            }
        }
        .onDisappear {
            Task(priority: .userInitiated) {
                await relayService.decrementSubscriptionCount(for: subscriptionIds)
                subscriptionIds.removeAll()
            }
        }
    }
}

struct IdentityView_Previews: PreviewProvider {
    
    static var previewData = PreviewData()
    static var persistenceController = PersistenceController.preview
    static var previewContext = persistenceController.container.viewContext
    
    static var author: Author = {
        let author: Author
        do {
            author = try Author.findOrCreate(
                by: "d0a1ffb8761b974cec4a3be8cbcb2e96a7090dcf465ffeac839aa4ca20c9a59e",
                context: previewContext
            )
        } catch {
            print(error)
            author = Author(context: previewContext)
        }
        // TODO: derive from private key
        author.name = "Fred"
        author.about = "Reach for the stars. Someday you just might catch one."
        try? previewContext.save()
        return author
    }()
    
    static var previews: some View {
        NavigationStack {
            ProfileView(author: previewData.previewAuthor)
        }
        .environment(\.managedObjectContext, previewData.previewContext)
        .environmentObject(previewData.relayService)
        .environmentObject(previewData.router)
        .environmentObject(previewData.currentUser)
    }
}
