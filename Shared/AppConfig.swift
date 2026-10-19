import Foundation

/// The one file to edit when starting a new app from this template.
/// Everything user-facing that changes per app (name, copy, product IDs, links) lives here.
/// Compiled into both the app and the widget, so keep it free of UIKit/SwiftUI imports.
enum AppConfig {
    // MARK: Identity
    static let appName = "Confined Space Log"
    static let bundleID = "com.example.confined-space-log"
    static let appGroupID = "group.com.example.confined-space-log"
    /// Your App Store ID once the app is live. The Rate button stays hidden while it is empty.(the number in the App Store URL).
    static let appStoreID = ""

    // MARK: Sync
    /// Set to true only after enabling iCloud + CloudKit on the App ID (see docs/capabilities.md).
    static let iCloudSyncEnabled = false

    // MARK: StoreKit (must match App Store Connect and StoreKit/Products.storekit)
    static let productPrefix = bundleID.replacingOccurrences(of: "-", with: "")
    static let annualProductID = "\(productPrefix).pro.annual"
    static let lifetimeProductID = "\(productPrefix).pro.lifetime"

    // MARK: Links
    static let supportEmail = "support@somexai.com"
    static let privacyPolicyURL = URL(string: "https://somexai.com/privacy/confined-space-log/")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    // MARK: Copy
    static let entryNoun = "Permit"
    static let entryNounPlural = "Permits"
    /// File name stem for exports: "confined-space-permit-2026-09-14.pdf".
    static let exportFileStem = "confined-space-permit"

    /// The sentence that has to appear in the app and on every export. The app is a record
    /// keeper: it makes no safety determination and authorises no entry.
    static let disclaimer = """
        \(appName) records what the entry supervisor entered. It makes no safety determination, \
        does not authorise any entry, and does not decide whether conditions are acceptable. \
        Acceptable entry conditions shown here are the ones you recorded from your own written \
        confined space program.
        """

    static let onboarding: [OnboardingPage] = [
        OnboardingPage(symbol: "doc.text.below.ecg", title: "A permit, not a checklist",
                       body: "An entry permit is a document with a life: drafted, tested, issued, then cancelled and filed. The app runs it through all four and will not let a draft act like an issued permit."),
        OnboardingPage(symbol: "person.2.wave.2.fill", title: "Who is inside, right now",
                       body: "Entrants sign in and out by name and time. The board shows the live count and the time left on every open permit, which is the first thing anybody asks when something goes wrong."),
        OnboardingPage(symbol: "hand.raised.slash", title: "Your numbers, your call",
                       body: "You enter your site's own acceptable entry conditions and your own meter readings. The app compares one to the other and says whose criterion it is. It never decides that a space is safe."),
    ]

    static let paywallSymbol = "checkmark.seal.fill"
    static let paywallHeadline = "Unlock \(appName)"
    static let paywallBenefits = [
        "Unlimited spaces, permits and entrants",
        "Timestamped atmospheric test log",
        "Live entrant roster and expiry clock",
        "Entry permit PDFs to post and to file",
        "One-year retention clock on cancelled permits",
        "No ads, no account, no tracking",
    ]

    // MARK: How-to guide (Settings → How do I use this app; also the ? button on the board)
    static let howToIntro = "Six steps, in the order the permit goes through them. The space is set up once; everything after that happens at the manway."
    static let howTo: [HowToStep] = [
        HowToStep(symbol: "circle.dashed", title: "Add the space once",
                  body: "Open Spaces and tap Add a space. Put in the space ID, where it is, what kind it is, the hazards you already know about and the isolation points. Every permit for that space starts pre-filled from this, so the tank only gets typed in once.",
                  tip: "Photograph the manway and the lockout points while you are standing there. It settles arguments about which valve was blanked."),
        HowToStep(symbol: "slider.horizontal.below.rectangle", title: "Record your acceptable entry conditions",
                  body: "On the same space screen, fill in Acceptable entry conditions from your own written program. The app ships no numbers and suggests none — these are yours, and every screen that shows a reading against them says so.",
                  tip: "Leave a gas blank if your program does not set a limit for it. Blank means no criterion, which is not the same as zero."),
        HowToStep(symbol: "doc.badge.plus", title: "Draft the permit",
                  body: "On the Board tab tap New permit and choose the space. Fill in the purpose, the authorised window, the attendant, the hazards, the isolation and the ventilation, the rescue services and how entrants will call the attendant. Nobody may enter on a draft."),
        HowToStep(symbol: "aqi.medium", title: "Test before entry",
                  body: "On the permit tap Record a test, set it to Before entry, and type in what the meter reads. The time is stamped on it. The app will not let a permit be issued until a test has been recorded, because the standard tests before it authorises."),
        HowToStep(symbol: "signature", title: "Sign to issue it",
                  body: "Name the entry supervisor, sign with a finger, and tap Issue permit. The permit goes onto the board with its clock running. If something is missing the app lists exactly what.",
                  tip: "The list under Issue permit is the standard's own preconditions, not the app's preferences."),
        HowToStep(symbol: "person.badge.clock", title: "Run the entry, then cancel it",
                  body: "Tap Sign in beside each entrant as they go through the manway and Sign out as they come back. Retest with Record a test as your program requires. When the work is done sign everyone out, then tap Cancel permit and sign. It moves to Archive with its one-year retention clock, and Entry permit (PDF) prints the whole record."),
    ]

    /// Display prices used only by DEBUG screenshot runs (`-mockPrices`). Keep in sync with StoreKit/Products.storekit.
    static let mockPrices = (annual: "$14.99", lifetime: "$34.99")

    // MARK: Behaviour
    /// Ask for an App Store review after this many successful saves (once per app version).
    static let reviewAfterSuccesses = 3
}

struct HowToStep: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
    var tip: String? = nil
}

struct OnboardingPage: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
}
