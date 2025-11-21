CREATE TABLE [rdt].[rdtwatteamlog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [TeamUser] nvarchar(18) NOT NULL,
    [MemberUser] nvarchar(18) NOT NULL,
    [Storerkey] nvarchar(15) NULL DEFAULT (''),
    [Facility] nvarchar(5) NULL DEFAULT (''),
    [Editdate] datetime NOT NULL DEFAULT (getdate()),
    [Editwho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [UDF01] nvarchar(60) NULL DEFAULT (''),
    [UDF02] nvarchar(60) NULL DEFAULT (''),
    [UDF03] nvarchar(60) NULL DEFAULT (''),
    [UDF04] nvarchar(60) NULL DEFAULT (''),
    [UDF05] nvarchar(60) NULL DEFAULT (''),
    CONSTRAINT [PKrdtWATTeamLog] PRIMARY KEY ([RowRef])
);
GO
