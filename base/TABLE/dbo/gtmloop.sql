CREATE TABLE [dbo].[gtmloop]
(
    [PalletId] nvarchar(18) NOT NULL,
    [TaskDetailKey] nvarchar(10) NOT NULL,
    [MsgId] nvarchar(20) NULL,
    [Status] nvarchar(10) NULL,
    [Workstation] nvarchar(30) NULL,
    [OrderKey] nvarchar(20) NULL,
    [Priority] nvarchar(10) NULL,
    [AddDate] datetime NULL,
    [AddWho] nvarchar(128) NULL,
    [EditDate] datetime NULL,
    [EditWho] nvarchar(200) NULL,
    [SourceType] nvarchar(30) NULL,
    CONSTRAINT [PK_GTMLoop_1] PRIMARY KEY ([PalletId])
);
GO

CREATE INDEX [IDX_GTMloop_Workstation] ON [dbo].[gtmloop] ([Workstation], [TaskDetailKey]);
GO