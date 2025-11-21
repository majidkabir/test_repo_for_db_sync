CREATE TABLE [rdt].[rdtgsicartonlabel_xml]
(
    [SeqNo] int IDENTITY(1,1) NOT NULL,
    [LineText] nvarchar(MAX) NULL,
    [SPID] int NULL,
    [Adddate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PKGSI_XML] PRIMARY KEY ([SeqNo])
);
GO

CREATE INDEX [IX_GSI_SPID] ON [rdt].[rdtgsicartonlabel_xml] ([SPID]);
GO