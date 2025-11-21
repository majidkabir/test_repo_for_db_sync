CREATE TABLE [dbo].[jreportfolder]
(
    [SecondLvl] nvarchar(15) NOT NULL DEFAULT ('WMS'),
    [FolderPath] nvarchar(128) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [Remark] nvarchar(200) NOT NULL DEFAULT (''),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PKJReportFolder] PRIMARY KEY ([SecondLvl], [StorerKey])
);
GO
