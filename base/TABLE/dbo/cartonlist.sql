CREATE TABLE [dbo].[cartonlist]
(
    [CartonKey] nvarchar(10) NOT NULL,
    [CartonType] nvarchar(10) NULL,
    [CurrWeight] float NULL,
    [CurrCube] float NULL,
    [CurrCount] float NULL,
    [Status] nvarchar(10) NULL,
    [Seqno] int NULL,
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [Adddate] datetime NULL DEFAULT (getdate()),
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nchar(1) NULL,
    CONSTRAINT [PK_CartonList] PRIMARY KEY ([CartonKey])
);
GO
