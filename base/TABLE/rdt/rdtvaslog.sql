CREATE TABLE [rdt].[rdtvaslog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Type] nvarchar(10) NOT NULL,
    [UserName] nvarchar(128) NOT NULL,
    [Facility] nvarchar(15) NOT NULL,
    [REF1] nvarchar(30) NULL,
    [REF2] nvarchar(30) NULL,
    [REF3] nvarchar(30) NULL,
    [REF4] nvarchar(30) NULL,
    [REF5] nvarchar(30) NULL,
    [QTY] int NOT NULL,
    [StartDate] datetime NOT NULL DEFAULT (getdate()),
    [EndDate] datetime NOT NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKrdtVASLog] PRIMARY KEY ([RowRef])
);
GO
