CREATE TABLE [api].[touchpaderrmsg]
(
    [Message_ID] int NOT NULL,
    [Lang_Code] nvarchar(3) NOT NULL DEFAULT (''),
    [Message_Type] nvarchar(3) NOT NULL DEFAULT (''),
    [Message_Text] nvarchar(4000) NOT NULL DEFAULT (''),
    [EventType] int NOT NULL DEFAULT (''),
    CONSTRAINT [PK_TouchPadErrmsg] PRIMARY KEY ([Message_ID], [Lang_Code], [Message_Type])
);
GO
