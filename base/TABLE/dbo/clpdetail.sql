CREATE TABLE [dbo].[clpdetail]
(
    [CLPOrderKey] nvarchar(10) NOT NULL,
    [CLPOrderLineNumber] nvarchar(5) NOT NULL,
    [POKey] nvarchar(18) NOT NULL,
    [POLineNumber] nvarchar(5) NOT NULL,
    [Qty] int NOT NULL,
    [CaseId] nvarchar(20) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [TimeStamp] nvarchar(18) NULL,
    CONSTRAINT [PKCLPDETAIL] PRIMARY KEY ([CLPOrderKey], [CLPOrderLineNumber]),
    CONSTRAINT [FK_CLPDETAIL_PODETAIL_01] FOREIGN KEY ([POKey], [POLineNumber]) REFERENCES [dbo].[PODETAIL] ([POKey], [POLineNumber])
);
GO
