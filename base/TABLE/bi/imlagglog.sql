CREATE TABLE [bi].[imlagglog]
(
    [PromoID] smallint NOT NULL,
    [Batch] int NOT NULL,
    [DATETIME] smalldatetime NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [ModifyDate] datetime NOT NULL,
    [num_CALLS_SWebServiceLog_IN] bigint NOT NULL,
    [num_CALLS_SWebServiceLog_OUT] bigint NOT NULL,
    [num_IML_IN_File] int NULL,
    [num_IML_OUT_File] int NULL,
    CONSTRAINT [PK_IMLAggLog] PRIMARY KEY ([PromoID], [Batch], [StorerKey]),
    CONSTRAINT [FK_IMLAggLog_eComPromo] FOREIGN KEY ([PromoID]) REFERENCES [BI].[eComPromo] ([PromoID])
);
GO
