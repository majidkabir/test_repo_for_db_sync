CREATE TABLE [dbo].[photorepo_account]
(
    [ID] bigint IDENTITY(1,1) NOT NULL,
    [Account] nvarchar(15) NOT NULL DEFAULT (''),
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_PhotoRepo_Account] PRIMARY KEY ([ID])
);
GO

CREATE UNIQUE INDEX [IX_PhotoRepo_Account_UNIQ] ON [dbo].[photorepo_account] ([Account], [StorerKey]);
GO