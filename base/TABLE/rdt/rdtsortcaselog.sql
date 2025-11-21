CREATE TABLE [rdt].[rdtsortcaselog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Mobile] int NOT NULL,
    [LoadKey] nvarchar(10) NOT NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdtSortCaseLog] PRIMARY KEY ([RowRef])
);
GO
