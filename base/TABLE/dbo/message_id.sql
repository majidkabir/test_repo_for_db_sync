CREATE TABLE [dbo].[message_id]
(
    [MsgId] nvarchar(40) NOT NULL DEFAULT (' '),
    [MsgIcon] nvarchar(12) NOT NULL DEFAULT (' '),
    [MsgButton] nvarchar(17) NOT NULL DEFAULT (' '),
    [MsgDefaultButton] int NOT NULL DEFAULT ((0)),
    [MsgSeverity] int NOT NULL DEFAULT ((0)),
    [MsgPrint] nvarchar(1) NOT NULL DEFAULT (' '),
    [MsgUserInput] nvarchar(1) NOT NULL DEFAULT (' '),
    CONSTRAINT [PK_msgid] PRIMARY KEY ([MsgId])
);
GO
