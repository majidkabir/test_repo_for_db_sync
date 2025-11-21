CREATE TABLE [rdt].[rdtmasterpacklog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (''),
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    [ToteNo] nvarchar(20) NOT NULL DEFAULT (''),
    [DropID] nvarchar(20) NOT NULL DEFAULT (''),
    [Status] nvarchar(5) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PKMasterPackLog] PRIMARY KEY ([RowRef])
);
GO
