CREATE TABLE [dbo].[exe2ow_allocpickship]
(
    [seq_no] int IDENTITY(1,1) NOT NULL,
    [ExternOrderkey] nvarchar(50) NOT NULL,
    [ExternLineNo] nvarchar(10) NOT NULL,
    [NewLineNo] nvarchar(10) NOT NULL,
    [BatchNo] nvarchar(18) NOT NULL,
    [Actioncode] nvarchar(1) NOT NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_Exe2OW_AllocPickShip] PRIMARY KEY ([seq_no])
);
GO

CREATE INDEX [idx_Exe2OW_AllocPickShip] ON [dbo].[exe2ow_allocpickship] ([ExternOrderkey], [ExternLineNo]);
GO