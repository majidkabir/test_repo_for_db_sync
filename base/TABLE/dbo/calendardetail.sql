CREATE TABLE [dbo].[calendardetail]
(
    [CalendarGroup] nvarchar(10) NOT NULL,
    [PeriodEnd] datetime NOT NULL,
    [SplitDate] datetime NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PKCalendarDetail] PRIMARY KEY ([CalendarGroup], [PeriodEnd]),
    CONSTRAINT [FK_CalendarDet_Calendar_01] FOREIGN KEY ([CalendarGroup]) REFERENCES [dbo].[CALENDAR] ([CalendarGroup])
);
GO
