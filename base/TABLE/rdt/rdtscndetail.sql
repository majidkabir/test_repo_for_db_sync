CREATE TABLE [rdt].[rdtscndetail]
(
    [ScnKey] int IDENTITY(1,1) NOT NULL,
    [Scn] int NOT NULL,
    [FieldNo] nvarchar(20) NULL DEFAULT (''),
    [XCol] int NULL,
    [YRow] int NULL,
    [TextColor] nvarchar(20) NULL DEFAULT ('White'),
    [ColType] nvarchar(20) NULL DEFAULT (''),
    [ColRegExp] nvarchar(255) NULL DEFAULT (''),
    [ColText] nvarchar(50) NULL DEFAULT (''),
    [ColValue] nvarchar(50) NULL DEFAULT (''),
    [ColValueLength] smallint NULL DEFAULT ((0)),
    [ColLookUpView] nvarchar(200) NULL DEFAULT (''),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [Func] int NULL,
    [Lang_Code] nvarchar(3) NULL,
    [ColStringExp] nvarchar(100) NULL DEFAULT (''),
    [DataType] nvarchar(15) NOT NULL DEFAULT (''),
    [WebGroup] nvarchar(20) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_RDTSCNDETAIL] PRIMARY KEY ([ScnKey])
);
GO

CREATE INDEX [IX_RDTSCNDETAIL_Scn] ON [rdt].[rdtscndetail] ([Scn], [FieldNo]);
GO