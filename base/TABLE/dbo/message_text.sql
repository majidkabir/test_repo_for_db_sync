CREATE TABLE [dbo].[message_text]
(
    [MsgId] nvarchar(40) NOT NULL DEFAULT (' '),
    [MsgLangId] int NOT NULL DEFAULT ((0)),
    [MsgTitle] nvarchar(255) NOT NULL DEFAULT (' '),
    [MsgText] nvarchar(255) NOT NULL DEFAULT (' '),
    CONSTRAINT [PK_msgid_langid] PRIMARY KEY ([MsgId], [MsgLangId]),
    CONSTRAINT [FK_msgid] FOREIGN KEY ([MsgId]) REFERENCES [dbo].[MESSAGE_ID] ([MsgId])
);
GO
