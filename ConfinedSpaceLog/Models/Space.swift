import Foundation
import SwiftData

/// One confined space, kept once and entered many times.
///
/// The register exists because 29 CFR 1910.146(c) makes the employer identify its permit spaces
/// before anybody goes near one, and because the same tank gets entered a dozen times a year.
/// Re-typing the identification, the known hazards and the isolation points on every permit is
/// the main friction in doing this on paper, so the space carries them and the permit copies
/// them forward.
///
/// The acceptable entry conditions live here too. They are **the user's own numbers**, taken
/// from their site's written confined space program. The app ships none and suggests none.
@Model
final class ConfinedSpace {
    var id: UUID = UUID()
    /// The identification the standard asks a permit to carry: "TK-104", "Digester 2", "MH-88".
    var spaceID: String = ""
    var name: String = ""
    var location: String = ""
    var kindRaw: String = SpaceKind.tank.rawValue
    var spaceDescription: String = ""
    /// Whether the employer has classified this space as permit-required. The user decides.
    var isPermitRequired: Bool = true
    var knownHazardsRaw: [String] = []
    var otherHazards: String = ""
    /// Lockout points, blanks, blinds, valves, breakers — what has to be isolated to enter.
    var isolationPoints: String = ""
    var accessNotes: String = ""
    var notes: String = ""

    // The site's own acceptable entry conditions for this space. Nil means "not recorded",
    // which is different from zero and is displayed that way everywhere.
    var oxygenMinPercent: Double? = nil
    var oxygenMaxPercent: Double? = nil
    var lelMaxPercent: Double? = nil
    var coMaxPPM: Double? = nil
    var h2sMaxPPM: Double? = nil
    var otherGasName: String = ""
    var otherGasUnit: String = ""
    var otherGasMax: Double? = nil

    @Attribute(.externalStorage) var photoData: Data? = nil
    var createdAt: Date = Date()

    /// Nullify, not cascade: a cancelled permit is a retained record and outlives the space
    /// being deleted from the register. The permit keeps its own copy of the identification.
    @Relationship(deleteRule: .nullify, inverse: \Permit.space)
    var permits: [Permit]? = nil

    init(spaceID: String = "", name: String = "", location: String = "") {
        self.id = UUID()
        self.spaceID = spaceID
        self.name = name
        self.location = location
        self.createdAt = .now
    }

    var kind: SpaceKind {
        get { SpaceKind(rawValue: kindRaw) ?? .tank }
        set { kindRaw = newValue.rawValue }
    }

    var knownHazards: [SpaceHazard] {
        get { knownHazardsRaw.compactMap(SpaceHazard.init(rawValue:)) }
        set { knownHazardsRaw = newValue.map(\.rawValue) }
    }

    /// What a row, a permit and a PDF all call this space.
    var title: String {
        let identifier = spaceID.trimmingCharacters(in: .whitespaces)
        let label = name.trimmingCharacters(in: .whitespaces)
        if identifier.isEmpty && label.isEmpty { return "Unnamed space" }
        if identifier.isEmpty { return label }
        if label.isEmpty { return identifier }
        return "\(identifier) — \(label)"
    }

    var sortedPermits: [Permit] {
        (permits ?? []).sorted { $0.sortDate > $1.sortDate }
    }

    var openPermits: [Permit] { sortedPermits.filter { $0.status == .open } }

    /// Whether this space has any acceptable entry condition recorded at all. Until it does,
    /// the app has nothing to compare a reading against and says so rather than inventing one.
    var hasAcceptableConditions: Bool {
        oxygenMinPercent != nil || oxygenMaxPercent != nil || lelMaxPercent != nil
            || coMaxPPM != nil || h2sMaxPPM != nil || otherGasMax != nil
    }
}

/// The kinds of space people actually write on a permit. Not a legal taxonomy — the standard
/// defines a confined space by its characteristics, not by a list of nouns.
enum SpaceKind: String, CaseIterable, Identifiable, Sendable {
    case tank, vessel, silo, pit, vault, manhole, sewer, duct, boiler, hopper, trench, tunnel, other

    var id: String { rawValue }

    var name: String {
        switch self {
        case .tank: return "Tank"
        case .vessel: return "Process vessel"
        case .silo: return "Silo or bin"
        case .pit: return "Pit"
        case .vault: return "Vault"
        case .manhole: return "Manhole"
        case .sewer: return "Sewer or wet well"
        case .duct: return "Duct or plenum"
        case .boiler: return "Boiler or furnace"
        case .hopper: return "Hopper"
        case .trench: return "Excavation or trench"
        case .tunnel: return "Tunnel or crawl space"
        case .other: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .tank, .vessel: return "cylinder"
        case .silo, .hopper: return "triangle"
        case .pit, .vault: return "square.bottomhalf.filled"
        case .manhole, .sewer: return "circle.dashed"
        case .duct: return "rectangle.split.3x1"
        case .boiler: return "flame"
        case .trench, .tunnel: return "arrow.down.right.and.arrow.up.left"
        case .other: return "questionmark.square.dashed"
        }
    }
}

/// The hazards 1910.146 expects a permit to name. Atmospheric first, because those are the ones
/// the testing section of the permit is about, then the physical ones.
enum SpaceHazard: String, CaseIterable, Identifiable, Sendable {
    case oxygenDeficient, oxygenEnriched, flammable, toxic
    case engulfment, convergingWalls, mechanical, electrical
    case thermal, corrosive, residues, falling, noise, poorVisibility, traffic, biological

    var id: String { rawValue }

    var name: String {
        switch self {
        case .oxygenDeficient: return "Oxygen deficient atmosphere"
        case .oxygenEnriched: return "Oxygen enriched atmosphere"
        case .flammable: return "Flammable gas or vapour"
        case .toxic: return "Toxic atmosphere"
        case .engulfment: return "Engulfment by liquid or solid"
        case .convergingWalls: return "Converging walls or sloping floor"
        case .mechanical: return "Moving or energised machinery"
        case .electrical: return "Electrical energy"
        case .thermal: return "Heat or cold"
        case .corrosive: return "Corrosive residue"
        case .residues: return "Sludge, product or residue"
        case .falling: return "Falling or falling objects"
        case .noise: return "Noise"
        case .poorVisibility: return "Poor visibility or lighting"
        case .traffic: return "Traffic or pedestrians"
        case .biological: return "Biological or sewage"
        }
    }

    /// Whether an atmospheric test is the thing that tells you about this hazard.
    var isAtmospheric: Bool {
        switch self {
        case .oxygenDeficient, .oxygenEnriched, .flammable, .toxic: return true
        default: return false
        }
    }

    var symbol: String {
        isAtmospheric ? "aqi.medium" : "exclamationmark.triangle"
    }

    static var atmospheric: [SpaceHazard] { allCases.filter(\.isAtmospheric) }
    static var physical: [SpaceHazard] { allCases.filter { !$0.isAtmospheric } }
}
