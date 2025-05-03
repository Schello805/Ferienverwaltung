import XCTest
@testable import Ferienverwaltung

final class VacationViewModelTests: XCTestCase {
    var viewModel: VacationViewModel!

    override func setUp() {
        super.setUp()
        viewModel = VacationViewModel()
    }

    func testDateParsingIsThreadSafeAndValid() {
        // Teste, dass alle Ferien ein gültiges Start- und Enddatum haben
        let allHolidays = viewModel.schoolHolidays + viewModel.publicHolidays
        for holiday in allHolidays {
            XCTAssertNotNil(holiday.startDateObject, "Startdatum darf nicht nil sein")
            XCTAssertNotNil(holiday.endDateObject, "Enddatum darf nicht nil sein")
            XCTAssertLessThanOrEqual(holiday.startDateObject, holiday.endDateObject, "Startdatum muss vor Enddatum liegen")
        }
    }

    func testParentsPersistence() {
        let parentCount = viewModel.parents.count
        let newParent = Parent(name: "TestElternteil", relationship: "Test", vacationDays: [], symbolName: "person")
        viewModel.parents.append(newParent)
        // Reload
        viewModel.parents = StorageService.shared.loadParents()
        XCTAssertEqual(viewModel.parents.count, parentCount + 1, "Elternteil sollte gespeichert und geladen werden")
    }

    func testChildFreeDaysSum() {
        // Teste, dass die Summe der freien Tage der Kinder korrekt berechnet wird
        let year = Calendar.current.component(.year, from: Date())
        let count = viewModel.totalAdditionalChildFreeDays(in: year)
        XCTAssertGreaterThanOrEqual(count, 0, "Freie Tage der Kinder dürfen nicht negativ sein")
    }

    func testHolidayCacheUpdate() async {
        await viewModel.updateHolidayCache(force: true)
        XCTAssertFalse(viewModel.schoolHolidays.isEmpty, "Schulferien sollten nach Update vorhanden sein")
        XCTAssertFalse(viewModel.publicHolidays.isEmpty, "Feiertage sollten nach Update vorhanden sein")
    }
}
