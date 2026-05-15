import Foundation

public struct ProfileGroupSection: Equatable, Sendable {
    public let group: DisplaySetupGroup
    public let profiles: [DisplayProfile]
    public let isCurrent: Bool
    public let isExpandedByDefault: Bool

    public init(
        group: DisplaySetupGroup,
        profiles: [DisplayProfile],
        isCurrent: Bool,
        isExpandedByDefault: Bool
    ) {
        self.group = group
        self.profiles = profiles
        self.isCurrent = isCurrent
        self.isExpandedByDefault = isExpandedByDefault
    }
}

public enum ProfileGroupingProjection {
    public static func sections(
        document: ProfileStoreDocument,
        currentFingerprint: DisplaySetupFingerprint?
    ) -> [ProfileGroupSection] {
        let sections: [ProfileGroupSection] = document.displaySetupGroups.compactMap { group in
            let profiles = document.profiles.filter { profile in
                profile.displaySetupFingerprint == group.fingerprint
            }
            let isCurrent = group.fingerprint == currentFingerprint
            guard isCurrent || !profiles.isEmpty else {
                return nil
            }

            return ProfileGroupSection(
                group: group,
                profiles: profiles,
                isCurrent: isCurrent,
                isExpandedByDefault: isCurrent
            )
        }

        return sections.sorted { lhs, rhs in
            if lhs.isCurrent != rhs.isCurrent {
                return lhs.isCurrent
            }
            return false
        }
    }
}
