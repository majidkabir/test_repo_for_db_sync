CREATE TABLE [dbo].[areadetail_dellog]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [AreaKey] nvarchar(10) NOT NULL,
    [PutawayZone] nvarchar(10) NOT NULL,
    [Status] char(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] varchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] char(1) NULL,
    CONSTRAINT [PK_areadetail_dellog] PRIMARY KEY ([Rowref])
);
GO
