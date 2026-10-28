import Foundation

public enum Evolution {
    /// Picks the adult form from the care history.
    public static func adultForm(for care: CareLog) -> AdultForm {
        let average = care.averageWellbeing
        if average < 0.45 { return .cloud }

        let total = Double(max(1, care.feeds + care.plays + care.pets))
        let petShare = Double(care.pets) / total
        let playShare = Double(care.plays) / total
        let feedShare = Double(care.feeds) / total

        if average > 0.72 && petShare >= 0.4 { return .sparkle }
        if playShare >= 0.4 { return .bouncy }
        if feedShare >= 0.45 { return .gourmet }
        return .sprout
    }

    /// When the next stage begins, or nil once adult.
    public static func nextStageDate(for state: PetState) -> (Stage, Date)? {
        switch state.stage {
        case .egg: return (.baby, state.birthDate.addingTimeInterval(Rules.hatchAfter))
        case .baby: return (.child, state.birthDate.addingTimeInterval(Rules.childAfter))
        case .child: return (.adult, state.birthDate.addingTimeInterval(Rules.adultAfter))
        case .adult: return nil
        }
    }
}
