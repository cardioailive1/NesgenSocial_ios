import XCTest
@testable import NexgenSocial

/// Decodes the shapes the live API actually returns, through the app's own
/// services and models.
///
/// The fixtures below were captured from `https://nexgensocial-udp.fly.dev`
/// on 2026-08-14 with a signed-in account, then trimmed to one item and had
/// names and ids replaced. They exist because a field the server renames or
/// re-types is invisible on the device: the decode throws, the view model
/// catches it, and the screen draws an empty list. Every one of these went
/// through `JSONDecoder` for real before it was written down.
@MainActor
final class APIContractTests: XCTestCase {

    override func tearDown() {
        StubAPI.restore()
        super.tearDown()
    }

    func testFeedPostDecodesIncludingItsMediaArray() async throws {
        StubAPI.install(json: """
        {"posts":[{"id":"p1","type":"IMAGE","body":null,
          "mediaUrl":"/uploads/1.png",
          "media":[{"id":"m1","postId":"p1","url":"/uploads/1.png","kind":"PHOTO","position":0,
                    "createdAt":"2026-08-02T14:25:48.414Z"}],
          "groupId":null,"audience":"PUBLIC","circleId":null,"category":"GENERAL",
          "isAiGenerated":false,"aiTool":null,"editedAt":null,
          "createdAt":"2026-08-02T14:25:48.414Z",
          "author":{"id":"u1","username":"someone","displayName":"Some One","avatarUrl":null},
          "likeCount":5,"commentCount":1,"likedByViewer":false,"contextNoteCount":0,
          "feedReason":"Public post","scoreBreakdown":{"recency":0.02,"engagement":0.263}}]}
        """)

        let posts = try await PostsService.feed().posts
        let post = try XCTUnwrap(posts.first)
        XCTAssertEqual(post.author?.displayName, "Some One")
        XCTAssertEqual(post.likeCount, 5)
        XCTAssertEqual(post.feedReason, "Public post")
        XCTAssertEqual(post.displayMedia.count, 1)
        XCTAssertEqual(post.displayMedia.first?.kind, .photo)
    }

    func testReelDecodes() async throws {
        StubAPI.install(json: """
        {"reels":[{"id":"r1","videoUrl":"/uploads/reel.webm","thumbnailUrl":"/uploads/reel.jpg",
          "caption":null,"durationSec":19.295,"soundName":null,"soundArtist":null,
          "isOriginalAudio":true,"colorGrade":"dramatic","createdAt":"2026-08-14T02:27:39.948Z",
          "author":{"id":"u1","username":"someone","displayName":"Some One","avatarUrl":"/uploads/a.jpg"},
          "hashtags":[],"viewCount":1,"likeCount":0,"commentCount":0,"likedByViewer":false,
          "discovery":{"completionRate":100,"replayRate":0,"newAudienceRate":100,"rankScore":0.4609}}]}
        """)

        let all = try await ReelsService.discover()
        let reel = try XCTUnwrap(all.first)
        XCTAssertEqual(reel.videoUrl, "/uploads/reel.webm")
        XCTAssertEqual(reel.author?.username, "someone")
    }

    /// `_count: { members: n }` is Prisma's shape, and `SocialGroup` has a
    /// hand-written decoder purely to read it.
    func testGroupDecodesPrismaMemberCount() async throws {
        StubAPI.install(json: """
        {"groups":[{"id":"g1","name":"CardioMed","description":"Medical Technology",
          "coverUrl":null,"isPrivate":false,"ownerId":"u1",
          "createdAt":"2026-07-30T23:50:16.772Z",
          "owner":{"id":"u1","username":"someone","displayName":"Some One","avatarUrl":null},
          "_count":{"members":7}}]}
        """)

        let all = try await GroupsService.all()
        let group = try XCTUnwrap(all.first)
        XCTAssertEqual(group.name, "CardioMed")
        XCTAssertEqual(group.memberCount, 7)
    }

    func testGroupMemberDecodes() async throws {
        StubAPI.install(json: """
        {"members":[{"id":"u2","username":"member","displayName":"A Member","avatarUrl":null,
          "role":"MEMBER","joinedAt":"2026-07-31T01:32:11.931Z","isOwner":false}]}
        """)

        let all = try await GroupsService.members(of: "g1")
        let member = try XCTUnwrap(all.first)
        XCTAssertEqual(member.role, "MEMBER")
        XCTAssertEqual(member.isOwner, false)
    }

    func testConversationDecodesWithNoLastMessage() async throws {
        StubAPI.install(json: """
        {"conversations":[{"id":"c1","isGroup":false,"title":null,
          "otherUser":{"id":"u1","username":"someone","displayName":"Some One","avatarUrl":null},
          "lastMessage":null,"lastMessageAt":"2026-08-06T16:25:03.994Z","unreadCount":0}]}
        """)

        let all = try await MessagesService.conversations()
        let conversation = try XCTUnwrap(all.first)
        XCTAssertEqual(conversation.otherUser?.username, "someone")
        XCTAssertNil(conversation.lastMessage)
    }

    func testFriendsOverviewDecodes() async throws {
        StubAPI.install(json: """
        {"incomingRequests":[],"sentRequests":[],
         "friends":[{"id":"u1","username":"someone","displayName":"Some One","avatarUrl":"/uploads/a.jpg"}]}
        """)

        let overview = try await FriendsService.overview()
        XCTAssertEqual(overview.friends.count, 1)
        XCTAssertTrue(overview.incomingRequests.isEmpty)
    }

    func testFriendSuggestionDecodesItsMutualsCopy() async throws {
        StubAPI.install(json: """
        {"suggestions":[{"id":"u3","username":"someone.else@example.com","displayName":"Some Else",
          "avatarUrl":null,"bio":"Always ready","occupation":"Student","city":"Wa",
          "reason":"2 mutual friends","mutuals":2}]}
        """)

        let all = try await FriendsService.suggestions()
        let suggestion = try XCTUnwrap(all.first)
        XCTAssertEqual(suggestion.reason, "2 mutual friends")
    }

    func testCommentDecodes() async throws {
        StubAPI.install(json: """
        {"comments":[{"id":"cm1","postId":"p1","authorId":"u1","body":"Nice",
          "createdAt":"2026-08-02T14:29:49.414Z",
          "author":{"id":"u1","username":"someone","displayName":"Some One","avatarUrl":null}}]}
        """)

        let all = try await PostsService.comments(for: "p1")
        let comment = try XCTUnwrap(all.first)
        XCTAssertEqual(comment.body, "Nice")
        XCTAssertEqual(comment.author?.displayName, "Some One")
    }

    /// Scores come back as two lists of fixtures plus league metadata, and
    /// scores themselves are strings, not numbers.
    func testSportsScoresDecodeStringScores() async throws {
        StubAPI.install(json: """
        {"league":"English Premier League",
         "broadcastUrl":"https://example.com/tv",
         "upcoming":[{"id":"1","homeTeam":"Arsenal","awayTeam":"Coventry City",
           "homeScore":null,"awayScore":null,"date":"2026-08-21","time":"19:00:00",
           "timestamp":"2026-08-21T19:00:00","venue":"Emirates Stadium","status":"NS",
           "isLive":false,"thumbUrl":"https://example.com/1.jpg"}],
         "recent":[{"id":"2","homeTeam":"West Ham United","awayTeam":"Leeds United",
           "homeScore":"3","awayScore":"0","date":"2026-05-24","time":"15:00:00",
           "timestamp":"2026-05-24T15:00:00","venue":"London Stadium","status":"FT",
           "isLive":false,"thumbUrl":null}],
         "noData":false,"leagueId":"4328"}
        """)

        let scores = try await SportsService.scores(league: "epl")
        XCTAssertEqual(scores.upcoming.count, 1)
        // Scores arrive as strings from this provider and as numbers from
        // others, which is what `LooseString` is for.
        XCTAssertEqual(scores.recent.first?.homeScore?.text, "3")
    }

    func testLeagueKeysDecode() async throws {
        StubAPI.install(json: """
        {"leagues":[{"key":"epl","label":"English Premier League","sport":"Soccer",
          "verified":true,"broadcastUrl":"https://example.com/tv"}]}
        """)

        let all = try await SportsService.leagues()
        let league = try XCTUnwrap(all.first)
        XCTAssertEqual(league.key, "epl", "the league key drives every scores request")
    }

    func testMeetingDecodes() async throws {
        StubAPI.install(json: """
        {"meetings":[{"id":"m1","title":"Product Development","description":null,
          "code":"GCT-Z2V-7E5","status":"LIVE","scheduledFor":null,
          "startedAt":"2026-08-10T15:53:22.418Z",
          "host":{"id":"u1","username":"someone","displayName":"Some One","avatarUrl":null},
          "participantCount":2,"isHost":false}]}
        """)

        let all = try await MeetingsService.all()
        let meeting = try XCTUnwrap(all.first)
        XCTAssertEqual(meeting.code, "GCT-Z2V-7E5")
        XCTAssertEqual(meeting.status, "LIVE")
    }

    func testNewsItemDecodes() async throws {
        StubAPI.install(json: """
        {"items":[{"source":"BBC News","title":"A headline",
          "link":"https://example.com/a","description":"Some copy.",
          "publishedAt":"2026-08-14T13:58:55.000Z"}],
         "failedSources":[],"cachedAt":"2026-08-14T14:00:00.000Z"}
        """)

        let news = try await NewsService.breaking()
        XCTAssertEqual(news.items.first?.source, "BBC News")
    }

    func testPoliticalPageDecodesWithItsMediaGallery() async throws {
        StubAPI.install(json: """
        {"pages":[{"id":"pp1","type":"PARTY","name":"A Party","description":"About",
          "organization":"Political party","websiteUrl":null,"region":"Somewhere",
          "avatarUrl":null,"coverUrl":"/uploads/cover.jpg",
          "media":[{"id":"pm1","pageId":"pp1","url":"/uploads/1.jpg","kind":"PHOTO",
                    "caption":null,"position":0,"createdAt":"2026-08-02T22:13:36.607Z"}],
          "followerCount":1,"isFollowing":false}]}
        """)

        let all = try await PoliticalService.pages(type: "")
        let page = try XCTUnwrap(all.first)
        XCTAssertEqual(page.name, "A Party")
        XCTAssertEqual(page.type, "PARTY")
    }

    func testPrivacySettingsDecode() async throws {
        StubAPI.install(json: """
        {"privacySettings":{"id":"ps1","userId":"u1","allowInterestTargeting":false,
          "allowBehavioralTracking":false,"allowAggregateInsights":false,
          "showVisitedPlaces":false,"updatedAt":"2026-07-31T03:08:50.723Z"}}
        """)

        let settings = try await ProfileService.setPrivacy("showVisitedPlaces", false)
        XCTAssertEqual(settings.showVisitedPlaces, false)
    }

    func testAdPricingDecodesWithANullExtensionTier() async throws {
        StubAPI.install(json: """
        {"basePriceCents":5000,"baseDurationDays":1,"baseReach":1000,
         "paymentUrl":"https://example.com/pay",
         "starter":{"priceCents":5000,"durationDays":1,"reachCap":1000},
         "extension":null}
        """)

        let pricing = try await AdsService.pricing()
        XCTAssertEqual(pricing.basePriceCents, 5000)
    }
}
