import Foundation

enum FederalState: String, CaseIterable, Identifiable {
    case bw = "Baden-Württemberg"
    case by = "Bayern"
    case be = "Berlin"
    case bb = "Brandenburg"
    case hb = "Bremen"
    case hh = "Hamburg"
    case he = "Hessen"
    case mv = "Mecklenburg-Vorpommern"
    case ni = "Niedersachsen"
    case nw = "Nordrhein-Westfalen"
    case rp = "Rheinland-Pfalz"
    case sl = "Saarland"
    case sn = "Sachsen"
    case st = "Sachsen-Anhalt"
    case sh = "Schleswig-Holstein"
    case th = "Thüringen"
    
    var id: String { self.rawValue }
    
    var stateCode: String {
        switch self {
        case .bw: return "BW"
        case .by: return "BY"
        case .be: return "BE"
        case .bb: return "BB"
        case .hb: return "HB"
        case .hh: return "HH"
        case .he: return "HE"
        case .mv: return "MV"
        case .ni: return "NI"
        case .nw: return "NW"
        case .rp: return "RP"
        case .sl: return "SL"
        case .sn: return "SN"
        case .st: return "ST"
        case .sh: return "SH"
        case .th: return "TH"
        }
    }
}
