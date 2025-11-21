CREATE TABLE [rdt].[rdttracesummary]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [TransDate] datetime NOT NULL,
    [Hour24] tinyint NOT NULL,
    [Usr] nvarchar(18) NOT NULL,
    [InFunc] int NOT NULL,
    [InStep] int NOT NULL,
    [OutStep] int NOT NULL,
    [AvgTime] int NOT NULL,
    [TotalTrans] int NOT NULL,
    [MinTime] int NOT NULL,
    [MaxTime] int NOT NULL,
    [MS0_1000] int NOT NULL,
    [MS1000_2000] int NOT NULL,
    [MS2000_5000] int NOT NULL DEFAULT ((0)),
    [MS5000_UP] int NOT NULL DEFAULT ((0)),
    CONSTRAINT [PKRDTTraceSummary] PRIMARY KEY ([RowRef])
);
GO
