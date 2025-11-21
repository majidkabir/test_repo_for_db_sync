CREATE TABLE [dbo].[pbcatedt]
(
    [pbe_name] nvarchar(30) NOT NULL,
    [pbe_edit] nvarchar(254) NULL,
    [pbe_type] smallint NOT NULL,
    [pbe_cntr] int NULL,
    [pbe_seqn] smallint NOT NULL,
    [pbe_flag] int NULL,
    [pbe_work] nvarchar(32) NULL
);
GO

CREATE UNIQUE INDEX [pbcatedt_idx] ON [dbo].[pbcatedt] ([pbe_name], [pbe_seqn]);
GO