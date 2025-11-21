CREATE TABLE [dbo].[holiday]
(
    [HolidayKey] int IDENTITY(1,1) NOT NULL,
    [Holiday] datetime NOT NULL,
    [DayDesc] nvarchar(50) NULL,
    [DayOfWeek] int NULL,
    CONSTRAINT [PK_Holiday] PRIMARY KEY ([HolidayKey])
);
GO
