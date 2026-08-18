import Foundation

/// Every path the app calls, in one place.
///
/// Paths live here rather than inline at the call site so a backend rename is
/// a single edit, and so it's possible to see the whole API surface the app
/// depends on without grepping the view layer.
enum APIEndpoints {

    // MARK: - Auth & profile

    enum Auth {
        static let me       = "/api/auth/me"
        static let login    = "/api/auth/login"
        static let register = "/api/auth/register"
        static let forgotPassword = "/api/auth/forgot-password"
    }

    enum Profile {
        static let me        = "/api/profile/me"
        static let interests = "/api/profile/interests"
        static let myInterests = "/api/profile/me/interests"
        static let privacy   = "/api/profile/me/privacy"
        static let places    = "/api/profile/me/places"
        static func place(_ id: String) -> String { "\(places)/\(id)" }
        static func geocode(_ query: String) -> String { "/api/profile/geocode?q=\(query.urlQueryEscaped)" }
    }

    // MARK: - Posts

    enum Posts {
        static let root = "/api/posts"
        static let feed = "/api/posts/feed"
        static func explore(category: String) -> String { "/api/posts/explore?category=\(category.urlQueryEscaped)" }
        static func like(_ id: String) -> String { "/api/posts/\(id)/like" }
        static func comments(_ id: String) -> String { "/api/posts/\(id)/comments" }
        static func notes(_ id: String) -> String { "/api/posts/\(id)/notes" }
        static func voteNote(_ id: String) -> String { "/api/posts/notes/\(id)/vote" }
    }

    enum Reels {
        static let discover = "/api/reels/discover"
        static func like(_ id: String) -> String { "/api/reels/\(id)/like" }
        static func view(_ id: String) -> String { "/api/reels/\(id)/view" }
    }

    // MARK: - Messaging & calls

    enum Messages {
        static let root = "/api/messages"
        static func withUser(_ username: String) -> String { "/api/messages/with/\(username)" }
        static func messages(in conversationId: String) -> String { "/api/messages/\(conversationId)/messages" }
    }

    enum Calls {
        static let root     = "/api/messages/calls"
        static let incoming = "/api/messages/calls/incoming"
        static let history  = "/api/messages/calls/history"
        static func call(_ id: String) -> String { "/api/messages/calls/\(id)" }
        static func details(_ id: String) -> String { "/api/messages/calls/\(id)/details" }
    }

    // MARK: - Social graph

    enum Friends {
        static let root        = "/api/friends"
        static let requests    = "/api/friends/requests"
        static let suggestions = "/api/suggestions/friends"
        static func request(_ id: String) -> String { "\(requests)/\(id)" }
        static func friend(_ id: String) -> String { "\(root)/\(id)" }
    }

    enum Follows {
        static func user(_ username: String) -> String { "/api/follows/\(username)" }
    }

    enum Users {
        static func search(_ query: String) -> String {
            query.isEmpty ? "/api/users" : "/api/users?q=\(query.urlQueryEscaped)"
        }
    }

    enum Groups {
        static let root = "/api/groups"
        static let mine = "/api/groups/mine"
        static func posts(_ id: String) -> String { "/api/groups/\(id)/posts" }
        static func members(_ id: String) -> String { "/api/groups/\(id)/members" }
        static func join(_ id: String) -> String { "/api/groups/\(id)/join" }
        static func leave(_ id: String) -> String { "/api/groups/\(id)/leave" }
    }

    enum Circles {
        static let root = "/api/circles"
        static func circle(_ id: String) -> String { "/api/circles/\(id)" }
        static func members(_ id: String) -> String { "/api/circles/\(id)/members" }
        static func member(_ id: String, userId: String) -> String { "/api/circles/\(id)/members/\(userId)" }
    }

    enum SocialAccounts {
        static let root    = "/api/social/accounts"
        static let invites = "/api/social/invites"
        static func account(_ provider: String) -> String { "/api/social/accounts/\(provider.lowercased())" }
        static func connect(_ provider: String) -> String { "\(account(provider))/connect" }
    }

    // MARK: - Content verticals

    enum News {
        static let breaking  = "/api/news/breaking"
        static let newsrooms = "/api/newsrooms"
        static func newsroom(_ slug: String) -> String { "/api/newsrooms/\(slug)" }
        static func follow(_ id: String) -> String { "/api/newsrooms/\(id)/follow" }
    }

    enum Sports {
        static let leagues = "/api/sports/leagues"
        static let live    = "/api/sports/live"
        static func scores(league: String) -> String { "/api/sports/scores?league=\(league.urlQueryEscaped)" }
    }

    enum Political {
        static let pages = "/api/political/pages"
        static func posts(_ id: String) -> String { "/api/political/pages/\(id)/posts" }
        static func follow(_ id: String) -> String { "/api/political/pages/\(id)/follow" }
        static let archive = "/api/political/archive"
    }

    enum Livestreams {
        static let root = "/api/livestreams"
        static func end(_ id: String) -> String { "/api/livestreams/\(id)/end" }
    }

    enum Meetings {
        static let root = "/api/meetings"
        static func byCode(_ code: String) -> String { "/api/meetings/by-code/\(code)" }
        static func join(_ id: String) -> String { "/api/meetings/\(id)/join" }
        static func leave(_ id: String) -> String { "/api/meetings/\(id)/leave" }
        static func start(_ id: String) -> String { "/api/meetings/\(id)/start" }
        static func end(_ id: String) -> String { "/api/meetings/\(id)/end" }
        static func myStatus(_ id: String) -> String { "/api/meetings/\(id)/my-status" }
    }

    enum Marketplace {
        static let root = "/api/marketplace"
        static func listings(query: String) -> String {
            query.isEmpty ? root : "\(root)?q=\(query.urlQueryEscaped)"
        }
        static func listing(_ id: String) -> String { "\(root)/\(id)" }
    }

    enum Jobs {
        static let root = "/api/jobs"
        static let mine = "/api/jobs/mine"
        static let myApplications = "/api/jobs/applications/mine"

        static func search(_ query: String) -> String {
            query.isEmpty ? root : "\(root)?q=\(query.urlQueryEscaped)"
        }

        /// Browse with the same filters the web app sends. Empty values are
        /// left out so the server falls back to "any".
        static func browse(_ filters: [String: String]) -> String {
            let query = filters
                .filter { !$0.value.isEmpty }
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value.urlQueryEscaped)" }
                .joined(separator: "&")
            return query.isEmpty ? root : "\(root)?\(query)"
        }

        static func job(_ id: String) -> String { "\(root)/\(id)" }
        static func apply(_ id: String) -> String { "\(root)/\(id)/apply" }
        static func applicants(_ id: String) -> String { "\(root)/\(id)/applications" }
        static func application(_ id: String) -> String { "\(root)/applications/\(id)" }
    }

    // MARK: - Monetisation

    enum Ads {
        static let pricing  = "/api/ads/pricing"
        static let events   = "/api/ads/events"
        static let estimate = "/api/ads/audience-estimate"
        static let mine     = "/api/premium/ads"
        static func serve(limit: Int) -> String { "/api/ads/serve?limit=\(limit)" }
        static func insights(_ id: String) -> String { "/api/ads/\(id)/insights" }
        static func checkout(_ id: String) -> String { "/api/premium/ads/\(id)/checkout" }
        static func extendCheckout(_ id: String) -> String { "/api/premium/ads/\(id)/extend/checkout" }
    }

    enum Premium {
        static let status    = "/api/premium/status"
        static let upgrade   = "/api/premium/upgrade"
        static let downgrade = "/api/premium/downgrade"
    }

    // MARK: - Push

    enum Push {
        static let apnsSubscribe   = "/api/push/apns-subscribe"
        static let apnsUnsubscribe = "/api/push/apns-unsubscribe"
        static let voipSubscribe   = "/api/push/voip-subscribe"
    }
}

extension String {
    /// Percent-encoding for a value going into a query string. Falls back to
    /// the raw string rather than dropping the parameter, so a search with an
    /// odd character degrades instead of silently querying for nothing.
    var urlQueryEscaped: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
