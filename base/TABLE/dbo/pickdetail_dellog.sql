CREATE TABLE [dbo].[pickdetail_dellog]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [PickDetailKey] nvarchar(18) NOT NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_pickdetail_dellog] PRIMARY KEY ([Rowref])
);
GO

CREATE INDEX [IX_Pickdetail_dellog_Adddate] ON [dbo].[pickdetail_dellog] ([AddDate]);
GO