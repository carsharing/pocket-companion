import XCTest
@testable import PetCore

final class PetCoreTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// 2026-01-01 at the given UTC hour.
    private func day(_ hour: Int, plusDays days: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 1, day: 1 + days, hour: hour))!
    }

    private func hatched(at date: Date) -> PetState {
        var pet = PetState(name: "Test", birthDate: date.addingTimeInterval(-Rules.hatchAfter - 60), hue: 0.5)
        pet.advance(to: date, calendar: calendar)
        return pet
    }

    func testEggHatchesAfterDelay() {
        var pet = PetState(name: "Egg", birthDate: day(10), hue: 0)
        pet.advance(to: day(10).addingTimeInterval(Rules.hatchAfter - 60), calendar: calendar)
        XCTAssertEqual(pet.stage, .egg)
        pet.advance(to: day(10).addingTimeInterval(Rules.hatchAfter + 60), calendar: calendar)
        XCTAssertEqual(pet.stage, .baby)
        XCTAssertNotNil(pet.lastEvolutionDate)
    }

    func testEggOnlyAcceptsPetting() {
        var pet = PetState(name: "Egg", birthDate: day(10), hue: 0)
        XCTAssertFalse(pet.perform(.feed, at: day(10), calendar: calendar).succeeded)
        XCTAssertTrue(pet.perform(.pet, at: day(10), calendar: calendar).succeeded)
    }

    func testStatsDecayWhileAwakeAndNeverGoNegative() {
        var pet = hatched(at: day(8))
        let before = pet.fullness
        pet.advance(to: day(12), calendar: calendar)
        XCTAssertLessThan(pet.fullness, before)
        pet.advance(to: day(12, plusDays: 10), calendar: calendar)
        for stat in [pet.fullness, pet.happiness, pet.energy, pet.cleanliness] {
            XCTAssertGreaterThanOrEqual(stat, 0)
            XCTAssertLessThanOrEqual(stat, 1)
        }
    }

    func testSleepsAtNightAndRestoresEnergy() {
        var pet = hatched(at: day(21))
        pet.energy = 0.3
        pet.advance(to: day(23), calendar: calendar)
        XCTAssertTrue(pet.isAsleep(calendar: calendar))
        XCTAssertEqual(pet.mood(calendar: calendar), .sleeping)
        pet.advance(to: day(6, plusDays: 1), calendar: calendar)
        XCTAssertGreaterThan(pet.energy, 0.8)
        pet.advance(to: day(8, plusDays: 1), calendar: calendar)
        XCTAssertFalse(pet.isAsleep(calendar: calendar))
    }

    func testNapsWhenExhaustedDuringTheDay() {
        var pet = hatched(at: day(9))
        pet.energy = 0.13
        pet.advance(to: day(10), calendar: calendar)
        XCTAssertTrue(pet.isNapping)
        XCTAssertTrue(pet.isAsleep(calendar: calendar))
        pet.advance(to: day(19), calendar: calendar)
        XCTAssertFalse(pet.isNapping)
    }

    func testSleepingPetRefusesFoodButAcceptsPets() {
        var pet = hatched(at: day(23))
        XCTAssertFalse(pet.perform(.feed, at: day(23), calendar: calendar).succeeded)
        XCTAssertTrue(pet.perform(.pet, at: day(23), calendar: calendar).succeeded)
    }

    func testFeedingRaisesFullness() {
        var pet = hatched(at: day(12))
        pet.fullness = 0.2
        let outcome = pet.perform(.feed, at: day(12), calendar: calendar)
        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(pet.fullness, 0.55, accuracy: 0.001)
        XCTAssertEqual(pet.care.feeds, 1)
        XCTAssertEqual(pet.recentAction(at: day(12).addingTimeInterval(60)), .feed)
        XCTAssertNil(pet.recentAction(at: day(13)))
    }

    func testFullPetRefusesFood() {
        var pet = hatched(at: day(12))
        pet.fullness = 1
        XCTAssertFalse(pet.perform(.feed, at: day(12), calendar: calendar).succeeded)
    }

    func testMoodReflectsLowestNeed() {
        var pet = hatched(at: day(12))
        pet.fullness = 0.1
        XCTAssertEqual(pet.mood(calendar: calendar), .hungry)
        XCTAssertEqual(pet.topNeed(calendar: calendar), .feed)
        pet.fullness = 1; pet.happiness = 1; pet.energy = 1; pet.cleanliness = 1
        XCTAssertEqual(pet.mood(calendar: calendar), .happy)
        XCTAssertNil(pet.topNeed(calendar: calendar))
    }

    func testGrowsUpThroughAllStages() {
        var pet = PetState(name: "Grow", birthDate: day(9), hue: 0)
        pet.advance(to: day(9).addingTimeInterval(Rules.childAfter + 60), calendar: calendar)
        XCTAssertEqual(pet.stage, .child)
        pet.advance(to: day(9).addingTimeInterval(Rules.adultAfter + 60), calendar: calendar)
        XCTAssertEqual(pet.stage, .adult)
        XCTAssertNotNil(pet.adultForm)
    }

    func testAdultFormFollowsCare() {
        var neglected = CareLog()
        neglected.wellbeingSeconds = 0.2; neglected.trackedSeconds = 1
        XCTAssertEqual(Evolution.adultForm(for: neglected), .cloud)

        var player = CareLog()
        player.wellbeingSeconds = 0.8; player.trackedSeconds = 1
        player.plays = 10; player.feeds = 5; player.pets = 3
        XCTAssertEqual(Evolution.adultForm(for: player), .bouncy)

        var cuddler = player
        cuddler.pets = 20
        XCTAssertEqual(Evolution.adultForm(for: cuddler), .sparkle)

        var foodie = CareLog()
        foodie.wellbeingSeconds = 0.6; foodie.trackedSeconds = 1
        foodie.feeds = 10; foodie.plays = 4; foodie.pets = 4
        XCTAssertEqual(Evolution.adultForm(for: foodie), .gourmet)

        var balanced = CareLog()
        balanced.wellbeingSeconds = 0.6; balanced.trackedSeconds = 1
        balanced.feeds = 5; balanced.plays = 5; balanced.pets = 5
        XCTAssertEqual(Evolution.adultForm(for: balanced), .sprout)
    }

    func testClockGoingBackwardsIsIgnored() {
        var pet = hatched(at: day(12))
        let snapshot = pet
        pet.advance(to: day(11), calendar: calendar)
        XCTAssertEqual(pet, snapshot)
    }

    func testTimelineIsOrderedAndDecays() {
        let pet = hatched(at: day(9))
        let entries = Forecast.timeline(from: pet, start: day(9), count: 8, calendar: calendar)
        XCTAssertEqual(entries.count, 8)
        XCTAssertEqual(entries.first?.date, day(9))
        XCTAssertGreaterThan(entries.first!.state.fullness, entries.last!.state.fullness)
        for (a, b) in zip(entries, entries.dropFirst()) { XCTAssertLessThan(a.date, b.date) }
    }

    func testActivityReactsToRecentCare() {
        var pet = hatched(at: day(12))
        pet.fullness = 0.5
        pet.perform(.feed, at: day(12), calendar: calendar)
        XCTAssertEqual(Forecast.activity(for: pet, at: day(12), calendar: calendar), .eating)
        let asleep = pet.advanced(to: day(23), calendar: calendar)
        XCTAssertEqual(Forecast.activity(for: asleep, at: day(23), calendar: calendar), .sleeping)
    }

    func testRemindersSkipNightAndFindHunger() {
        var pet = hatched(at: day(9))
        pet.fullness = 0.5
        let reminders = ReminderPlanner.upcoming(for: pet, from: day(9), calendar: calendar)
        let hungry = reminders.first { $0.kind == .hungry }
        XCTAssertNotNil(hungry)
        if let date = hungry?.date {
            XCTAssertFalse(DayCycle.isNight(date, calendar: calendar))
            XCTAssertGreaterThan(date, day(9))
        }
    }

    func testStoreRoundTrip() {
        let defaults = UserDefaults(suiteName: "PetCoreTests.\(UUID().uuidString)")!
        let store = PetStore(defaults: defaults, appGroup: nil)
        XCTAssertNil(store.load())
        let (state, outcome) = store.update { $0.perform(.pet, at: $0.birthDate) }
        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(store.load(), state)
    }
}
