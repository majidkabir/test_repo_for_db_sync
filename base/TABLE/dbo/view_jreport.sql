CREATE TABLE [dbo].[view_jreport]
(
    [JReport_ID] nvarchar(10) NOT NULL,
    [JReport_Description] nvarchar(4000) NULL DEFAULT (''),
    [JReport_FileName] nvarchar(250) NULL,
    [JReport_Catalog] nvarchar(250) NULL DEFAULT (''),
    [JReport_Category] nvarchar(250) NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [JReport_ID_ndx] PRIMARY KEY ([JReport_ID])
);
GO
