CREATE TABLE [dbo].[idsallocationpool]
(
    [AllocPoolId] uniqueidentifier NOT NULL DEFAULT (newid()),
    [SourceKey] nvarchar(10) NOT NULL,
    [WinUserLogin] nvarchar(18) NOT NULL DEFAULT (' '),
    [WinComputerName] nvarchar(18) NOT NULL,
    [Priority] int NOT NULL DEFAULT ((9)),
    [Status] nvarchar(5) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [SourceType] nvarchar(10) NULL DEFAULT ('L'),
    [Remarks] nvarchar(60) NULL,
    [MsgText] nvarchar(215) NULL,
    [ExtendParms] nvarchar(250) NULL,
    [Wavekey] nvarchar(10) NOT NULL DEFAULT (''),
    [AllocateCmd] nvarchar(1024) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_IDSAllocationPool] PRIMARY KEY ([AllocPoolId])
);
GO
