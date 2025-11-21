CREATE TABLE [dbo].[calendar]
(
    [CalendarGroup] nvarchar(10) NOT NULL,
    [Description] nvarchar(60) NOT NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PKCalendar] PRIMARY KEY ([CalendarGroup])
);
GO
