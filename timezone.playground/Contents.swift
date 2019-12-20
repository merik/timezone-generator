import UIKit

var str = "Hello, playground"

class DST {
    var month = 1
    var weekDayOrdinal = 1
    var weekDay = 1
    var hour = 3
    var minute = 0
    
    var dstOffset = 0
    var gmtOffset = 0
    
    init?(date: Date, calendar: Calendar, timeZone: TimeZone, dstOffset: Int, gmtOffset: Int) {
        let components = calendar.dateComponents(in: timeZone, from: date)
        guard let month = components.month, let weekDayOrdinal = components.weekdayOrdinal, let weekDay = components.weekday, let hour = components.hour, let minute = components.minute else {
            return nil
        }
        self.month = month
        self.weekDayOrdinal = weekDayOrdinal
        self.weekDay = weekDay
        self.hour = hour
        self.minute = minute
        self.dstOffset = dstOffset
        self.gmtOffset = gmtOffset
    }
    
    var asPosix: String {
        //#posix_string: M4.1.0/02:00:00
        // Sunday is zero in Posix
        // Sunday is 1 in Swift
        let weekDay = self.weekDay - 1
        return String(format: "M%d.%d.%d/%02d:%02d:00", month, weekDayOrdinal, weekDay, hour, minute)
    }
    
    func getJsonString(for tag: String) -> String {
        // swift: sunday = 1
        // sunday = 7
        var weekDay = self.weekDay - 1
        if weekDay == 0 {
            weekDay = 7
        }
        
        let json =
            """
            "\(tag)": {
                    "month": \(month),
                    "weekday_ordinal": \(weekDayOrdinal),
                    "weekday": \(weekDay),
                    "hour": \(hour),
                    "minute": \(minute),
                    "offset": \(dstOffset),
                    "gmt_offset": \(gmtOffset)
                }
            """
        return json
    }
}

func getFirstDayOfYear(timezoneString: String) -> Date? {
    guard let timezone = TimeZone(identifier: timezoneString) else {
        return nil
    }
    
    var calendar = Calendar.current
    calendar.timeZone = timezone
    var dateComponents = calendar.dateComponents(in: timezone, from: Date())
    dateComponents.day = 1
    dateComponents.month = 1
    dateComponents.minute = 0
    dateComponents.second = 0
    dateComponents.hour = 10
    
    return calendar.date(from: dateComponents)
    
}

func getEndDST(dstDate: Date, timezone: TimeZone) -> Date {
    
    var date = dstDate
    var calendar = Calendar.current
    calendar.timeZone = timezone
    
    while timezone.isDaylightSavingTime(for: date) {
        date = calendar.date(byAdding: .day, value: 1, to: date)!
    }
    
    while !timezone.isDaylightSavingTime(for: date) {
        date = calendar.date(byAdding: .minute, value: -15, to: date)!
    }
    date = calendar.date(byAdding: .minute, value: 15, to: date)!
    return date
}

func getStartDST(dstDate: Date, timezone: TimeZone) -> Date {
    
    var date = dstDate
    var calendar = Calendar.current
    calendar.timeZone = timezone
    
    while timezone.isDaylightSavingTime(for: date) {
        date = calendar.date(byAdding: .day, value: -1, to: date)!
    }
    
    while !timezone.isDaylightSavingTime(for: date) {
        date = calendar.date(byAdding: .minute, value: 15, to: date)!
    }
    return date
}

func getStartDST(notDstDate: Date, timezone: TimeZone) -> Date? {
    
    var date = notDstDate
    var calendar = Calendar.current
    calendar.timeZone = timezone
    
    var counter = 0
    while !timezone.isDaylightSavingTime(for: date) {
        date = calendar.date(byAdding: .day, value: 1, to: date)!
        counter = counter + 1
        if counter >= 350 {     // no daylight saving
            return nil
        }
    }
    
    while timezone.isDaylightSavingTime(for: date) {
        date = calendar.date(byAdding: .minute, value: -15, to: date)!
    }
    date = calendar.date(byAdding: .minute, value: 15, to: date)!
    return date
}

func getDST(of timezoneString: String) -> (dstFrom: DST?, dstUntil: DST?) {
    guard let firstDate = getFirstDayOfYear(timezoneString: timezoneString) else {
        return (nil, nil)
    }
    guard let timezone = TimeZone(identifier: timezoneString) else {
        return (nil, nil)
    }
    
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.timeZone = timezone
    
    var calendar = Calendar.current
    calendar.timeZone = timezone
    
    if timezone.isDaylightSavingTime(for: firstDate) {
        let startDate = getStartDST(dstDate: firstDate, timezone: timezone)
        let endDate = getEndDST(dstDate: firstDate, timezone: timezone)
        let dstOffset = Int(timezone.daylightSavingTimeOffset(for: calendar.date(byAdding: .day, value: 1, to: startDate)!))
        let gmtOffset = Int(timezone.secondsFromGMT(for: calendar.date(byAdding: .day, value: 1, to: startDate)!)) - dstOffset
        
        let startDst = DST(date: startDate, calendar: calendar, timeZone: timezone, dstOffset: dstOffset, gmtOffset: gmtOffset)
        let endDst = DST(date: endDate, calendar: calendar, timeZone: timezone, dstOffset: dstOffset, gmtOffset: gmtOffset)
        
        
        //print(formatter.string(from: startDate))
        //print(formatter.string(from: endDate))
        return (startDst, endDst)
    } else {
        if let startDate = getStartDST(notDstDate: firstDate, timezone: timezone) {
            let endDate = getEndDST(dstDate: startDate, timezone: timezone)
            let dstOffset = Int(timezone.daylightSavingTimeOffset(for: calendar.date(byAdding: .day, value: 1, to: startDate)!))
            let gmtOffset = Int(timezone.secondsFromGMT(for: calendar.date(byAdding: .day, value: 1, to: startDate)!)) - dstOffset
            
            //print(formatter.string(from: startDate))
            //print(formatter.string(from: endDate))
            let startDst = DST(date: startDate, calendar: calendar, timeZone: timezone, dstOffset: dstOffset, gmtOffset: gmtOffset)
            let endDst = DST(date: endDate, calendar: calendar, timeZone: timezone, dstOffset: dstOffset, gmtOffset: gmtOffset)
            return (startDst, endDst)
        }
    }
    return (nil, nil)
}

func secondsToTimeString(seconds: Int, zeroedHour: Bool) -> String {
    //3600: 01:00:00
    //#36000: 10:00:00
    let minutes = seconds / 60
    let hour = minutes / 60
    let minute = minutes % 60
    if zeroedHour {
        return String(format: "%02d:%02d:00", hour, minute)
    } else {
        return String(format: "%d:%02d:00", hour, minute)
    }
}

func rawOffsetToCSTString(rawOffset: Int) -> String {
    //#-7200 -> CST 2:00:00
    //#36000 -> CST-10:00:00
    //#0 -> CST 0:00:00
    let prefix = rawOffset > 0 ? "CST-" : "CST "
    return prefix + secondsToTimeString(seconds: abs(rawOffset), zeroedHour: false)
}

func buildHikvisionTimeZoneString(timezone: String, rawOffset: Int, dstOffset: Int, dstFrom: DST?, dstTo: DST?) -> String {
    //#-7200 -> #CST 2:00:00DST01:00:00,M10.1.0/03:00:00,M4.1.0/02:00:00
    // sunday is zero
    var timezoneString = rawOffsetToCSTString(rawOffset: rawOffset)
    if dstOffset != 0 {
        timezoneString += "DST" + secondsToTimeString(seconds: dstOffset, zeroedHour: true)
        if let dstFrom = dstFrom, let dstTo = dstTo {
            timezoneString += "," + dstFrom.asPosix
            timezoneString += "," + dstTo.asPosix
        }
        
    }
    
    return timezoneString
    
}
func buildDHTimeZone(rawOffset: Int) -> Int {
    let gmtMinutes = [0, 60, 120, 180, 210, 240, 270, 300, 330, 345,
                    360, 390, 420, 480, 540, 570, 600, 660, 720, 780,
                    -60, -120, -180, -210, -240, -300, -360, -420, -480,
                    -540, -600, -660, -720]
    
    for (index, offset) in gmtMinutes.enumerated() {
        if offset * 60 == rawOffset {
            return index
        }
    }
    
    return -1
}

func buildTimeZoneInfo(_ timezoneString: String) -> String? {
    
    guard let timezone = TimeZone(identifier: timezoneString) else {
        return nil
    }
    
    let (dstFrom, dstTo) = getDST(of: timezoneString)

    if let dstFrom = dstFrom, let dstTo = dstTo {
        let dstOffset = dstFrom.dstOffset
        let rawOffset = dstFrom.gmtOffset
        let hikString = buildHikvisionTimeZoneString(timezone: timezoneString, rawOffset: rawOffset, dstOffset: dstOffset, dstFrom: dstFrom, dstTo: dstTo)
        let dhTimeZone = buildDHTimeZone(rawOffset: rawOffset)
        
        let dstFromJson = dstFrom.getJsonString(for: "dst_from")
        let dstToJson = dstTo.getJsonString(for: "dst_until")
        
        let jsonString =
            """
            "\(timezoneString)": {
                "hik_timezone": "\(hikString)",
                "dh_timezone": \(dhTimeZone),
                "dst_offset": \(dstOffset),
                "raw_offset": \(rawOffset),
                \(dstFromJson),
                \(dstToJson)
            }
            """
        return jsonString
    } else {
        let dstOffset = 0
        let rawOffset = timezone.secondsFromGMT()
        let hikString = buildHikvisionTimeZoneString(timezone: timezoneString, rawOffset: rawOffset, dstOffset: dstOffset, dstFrom: dstFrom, dstTo: dstTo)
        let dhTimeZone = buildDHTimeZone(rawOffset: rawOffset)
        
        
        let jsonString =
        """
        "\(timezoneString)": {
            "hik_timezone": "\(hikString)",
            "dh_timezone": \(dhTimeZone),
            "dst_offset": \(dstOffset),
            "raw_offset": \(rawOffset),
            "dst_from": null,
            "dst_until": null
        }
        """
        return jsonString
    }
    
}

func buildTimeZoneJson(max: Int = 10) -> String {
    let timezones = TimeZone.knownTimeZoneIdentifiers
    var json = "{"
    
    for timezone in timezones {
        if let timezoneJson = buildTimeZoneInfo(timezone) {
            json += "\n    " + timezoneJson + ","
        }
    }
    
    if timezones.count > 0 {
        json.removeLast() // ,
    }
    
    json += "\n}"
    return json
    
}
//print(buildTimeZoneInfo("America/Santiago")!)
print(buildTimeZoneJson())
//let timezoneJson = buildTimeZoneInfo("Australia/Sydney")
//print(timezoneJson!)
//getDST(of: "Europe/Stockholm")

