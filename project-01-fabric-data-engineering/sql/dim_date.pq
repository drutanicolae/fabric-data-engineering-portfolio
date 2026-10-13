let
    StartDate = #date(2024, 12, 31),
    EndDate = #date(2025, 12, 31),
    NumberOfDays = Duration.Days(EndDate - StartDate) + 1,
    DateList = List.Dates(
        StartDate,
        NumberOfDays,
        #duration(1, 0, 0, 0)
    ),
    DateTable = Table.FromList(
        DateList,
        Splitter.SplitByNothing(),
        {"Date"}
    ),
    ChangedType = Table.TransformColumnTypes(
        DateTable,
        {{"Date", type date}}
    ),
    AddDateKey = Table.AddColumn(
    ChangedType,
    "DateKey",
    each Date.Year([Date]) * 10000
        + Date.Month([Date]) * 100
        + Date.Day([Date]),
    Int64.Type
    ),
    AddYear = Table.AddColumn(
        AddDateKey, "Year", each Date.Year([Date]), Int64.Type
    ),
    AddQuarter = Table.AddColumn(
        AddYear, "Quarter", each "Q" & Text.From(Date.QuarterOfYear([Date])), type text
    ),
    AddMonthNumber = Table.AddColumn(
        AddQuarter, "MonthNumber", each Date.Month([Date]), Int64.Type
    ),
    AddMonthName = Table.AddColumn(
        AddMonthNumber, "MonthName", each Date.MonthName([Date], "en-US"), type text
    ),
    AddDay = Table.AddColumn(
        AddMonthName, "Day", each Date.Day([Date]), Int64.Type
    ),
    AddDayOfWeek = Table.AddColumn(
        AddDay, "DayOfWeek", each Date.DayOfWeekName([Date], "en-US"), type text
    ),
    AddDayOfWeekNumber = Table.AddColumn(
        AddDayOfWeek, "DayOfWeekNumber", each Date.DayOfWeek([Date], Day.Monday) + 1, Int64.Type
    ),
    AddIsWeekend = Table.AddColumn(
        AddDayOfWeekNumber, "IsWeekend", each [DayOfWeekNumber] >= 6, type logical
    )
in
    AddIsWeekend