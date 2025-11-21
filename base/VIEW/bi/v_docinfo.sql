SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_DocInfo]
AS
SELECT RecordID
, TableName
, Key1
, Key2
, Key3
, StorerKey
, LineSeq
, Data
, DataType
, StoredProc
, AddDate
, AddWho
, ArchiveCop=CAST(ArchiveCop AS NVARCHAR)
FROM [dbo].[DocInfo] WITH (NOLOCK)

GO