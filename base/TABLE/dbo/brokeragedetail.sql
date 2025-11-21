CREATE TABLE [dbo].[brokeragedetail]
(
    [BrokerageDetailKey] bigint IDENTITY(1,1) NOT NULL,
    [BrokerageKey] bigint NOT NULL,
    [BrokerageLineNumber] nvarchar(5) NOT NULL DEFAULT (' '),
    [Storerkey] nvarchar(15) NOT NULL,
    [BrokerageExternKey] nvarchar(20) NOT NULL DEFAULT (' '),
    [ExternLineNo] nvarchar(20) NOT NULL DEFAULT (' '),
    [Sku] nvarchar(20) NULL DEFAULT (NULL),
    [SkuDescription] nvarchar(60) NULL DEFAULT (' '),
    [Qty] int NULL DEFAULT ('0'),
    [UnitPrice] float NULL DEFAULT ('0'),
    [UOM] nvarchar(10) NULL DEFAULT (' '),
    [HTSCode] nvarchar(10) NULL DEFAULT (' '),
    [CountryOfOrigin] nvarchar(30) NULL DEFAULT (' '),
    [Notes] nvarchar(1024) NULL DEFAULT (' '),
    [Userdefine01] nvarchar(30) NULL DEFAULT (' '),
    [Userdefine02] nvarchar(30) NULL DEFAULT (' '),
    [Userdefine03] nvarchar(30) NULL DEFAULT (' '),
    [Userdefine04] nvarchar(30) NULL DEFAULT (' '),
    [Userdefine05] nvarchar(30) NULL DEFAULT (' '),
    [Userdefine06] datetime NULL,
    [Userdefine07] datetime NULL,
    [Userdefine08] nvarchar(30) NULL DEFAULT (' '),
    [Userdefine09] nvarchar(30) NULL DEFAULT (' '),
    [Userdefine10] nvarchar(30) NULL DEFAULT (' '),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] varchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] varchar(128) NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_BrokerageDetail] PRIMARY KEY ([BrokerageDetailKey])
);
GO

CREATE INDEX [IDX_BD_Brokerage] ON [dbo].[brokeragedetail] ([Storerkey], [BrokerageKey], [BrokerageLineNumber]);
GO
CREATE INDEX [IDX_BD_ExternBrokerage] ON [dbo].[brokeragedetail] ([BrokerageExternKey], [ExternLineNo]);
GO