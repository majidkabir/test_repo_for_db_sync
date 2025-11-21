CREATE TABLE [dbo].[channelinvhold]
(
    [InvHoldkey] bigint IDENTITY(1,1) NOT NULL,
    [HoldType] nvarchar(10) NOT NULL DEFAULT (''),
    [Sourcekey] nvarchar(10) NOT NULL DEFAULT (''),
    [Hold] nvarchar(1) NOT NULL DEFAULT ('0'),
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (''),
    [Sku] nvarchar(20) NOT NULL DEFAULT (''),
    [Facility] nvarchar(15) NOT NULL DEFAULT (''),
    [Channel] nvarchar(20) NOT NULL DEFAULT (''),
    [C_Attribute01] nvarchar(30) NOT NULL DEFAULT (''),
    [C_Attribute02] nvarchar(30) NOT NULL DEFAULT (''),
    [C_Attribute03] nvarchar(30) NOT NULL DEFAULT (''),
    [C_Attribute04] nvarchar(30) NOT NULL DEFAULT (''),
    [C_Attribute05] nvarchar(30) NOT NULL DEFAULT (''),
    [Channel_ID] bigint NOT NULL DEFAULT ((0)),
    [Remarks] nvarchar(255) NOT NULL DEFAULT (''),
    [DateOn] datetime NOT NULL DEFAULT (getdate()),
    [WhoOn] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [DateOff] datetime NOT NULL DEFAULT (getdate()),
    [WhoOff] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nchar(1) NULL,
    CONSTRAINT [PK_ChannelInvHold] PRIMARY KEY ([InvHoldkey])
);
GO

CREATE INDEX [IDX_ChannelInvHold_1] ON [dbo].[channelinvhold] ([HoldType], [Sourcekey], [Hold]);
GO
CREATE INDEX [IDX_ChannelInvHold_2] ON [dbo].[channelinvhold] ([Facility], [Channel], [C_Attribute01], [C_Attribute02], [C_Attribute03], [C_Attribute04], [C_Attribute05]);
GO