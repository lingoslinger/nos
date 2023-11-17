//
//  ProfileSocialStatsView.swift
//  Nos
//
//  Created by Martin Dutra on 9/8/23.
//

import SwiftUI

struct ProfileSocialStatsView: View {

    @Environment(Router.self) private var router

    var author: Author

    var followsResult: FetchedResults<Follow>
    var followersResult: FetchedResults<Follow>

    var body: some View {
        HStack {
            Group {
                Spacer()
                Button {
                    router.currentPath.wrappedValue.append(
                        FollowsDestination(
                            author: author,
                            follows: followsResult.compactMap { $0.destination }
                        )
                    )
                } label: {
                    tab(label: .following, value: author.follows.count)
                }
                Spacer(minLength: 0)
            }
            Divider.vertical
            Group {
                Spacer(minLength: 0)
                Button {
                    router.currentPath.wrappedValue.append(
                        FollowersDestination(
                            author: author,
                            followers: followersResult.compactMap { $0.source }
                        )
                    )
                } label: {
                    tab(label: .followedBy, value: author.followers.count)
                }
                Spacer(minLength: 0)
            }
            Divider.vertical
            Group {
                Spacer(minLength: 0)
                Button {
                    router.currentPath.wrappedValue.append(
                        RelaysDestination(
                            author: author,
                            relays: author.relays.map { $0 }
                        )
                    )
                } label: {
                    tab(label: .relays, value: author.relays.count)
                }
                Spacer(minLength: 0)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical)
    }

    private func tab(label: Localized, value: Int) -> some View {
        VStack {
            PlainText("\(value)")
                .font(.title)
                .foregroundColor(.primaryTxt)
            PlainText(label.string.lowercased())
                .font(.subheadline)
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                .foregroundColor(.secondaryText)
        }
    }
}

fileprivate extension Divider {
    static var vertical: some View {
        Divider().overlay(Color("divider")).shadow(color: Color("divider-shadow"), radius: 0, x: -0.5)
    }
}
