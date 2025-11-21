CREATE TABLE [dbo].[channelinvholddetail]
(
    [RefID] bigint IDENTITY(1,1) NOT NULL,
    [InvHoldkey] bigint NOT NULL DEFAULT ((0)),
    [SourceLineNo] nvarchar(5) NOT NULL DEFAULT (''),
    [Channel_ID] bigint NOT NULL DEFAULT ((0)),
    [Qty] int NOT NULL DEFAULT ((0)),
    [Hold] nvarchar(1) NOT NULL DEFAULT ('0'),
    [DateOn] datetime NOT NULL DEFAULT (getdate()),
    [WhoOn] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [DateOff] datetime NOT NULL DEFAULT (getdate()),
    [WhoOff] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nchar(1) NULL,
    CONSTRAINT [PK_ChannelInvHoldDetail] PRIMARY KEY ([RefID])
);
GO

CREATE INDEX [IDX_ChannelInvHoldDetail_InvHoldkey] ON [dbo].[channelinvholddetail] ([InvHoldkey], [SourceLineNo], [Channel_ID], [Hold]);
GO