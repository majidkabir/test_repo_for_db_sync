CREATE TABLE [dbo].[gtmlog]
(
    [Logids] bigint IDENTITY(1,1) NOT NULL,
    [PalletId] nvarchar(30) NULL,
    [TaskDetailKey] nvarchar(20) NULL,
    [MsgType] nvarchar(100) NULL,
    [FromLoc] nvarchar(20) NULL,
    [ToLoc] nvarchar(20) NULL,
    [LogDate] datetime NULL,
    [EditBy] nvarchar(50) NULL,
    [ErrMsg] nvarchar(1000) NULL,
    [ErrCode] int NULL,
    CONSTRAINT [PK_GTM_CallLog] PRIMARY KEY ([Logids])
);
GO
