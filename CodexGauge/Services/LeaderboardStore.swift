import Foundation

@MainActor
final class LeaderboardStore: ObservableObject {
    @Published var people: [LeaderboardPerson] {
        didSet { savePeople() }
    }

    private let defaults: UserDefaults
    private let key = "leaderboardPeople"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([LeaderboardPerson].self, from: data) {
            self.people = decoded
        } else {
            self.people = []
        }
    }

    func upsert(_ person: LeaderboardPerson) {
        if let index = people.firstIndex(where: { $0.id == person.id }) {
            people[index] = person
        } else {
            people.append(person)
        }
    }

    func delete(_ person: LeaderboardPerson) {
        people.removeAll { $0.id == person.id }
    }

    private func savePeople() {
        guard let data = try? JSONEncoder().encode(people) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}
