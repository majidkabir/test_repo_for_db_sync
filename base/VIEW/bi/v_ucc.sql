SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_UCC] AS
SELECT UCCNo
, Storerkey
, ExternKey
, SKU
, qty
, Sourcekey
, Sourcetype
, Userdefined01
, Userdefined02
, Userdefined03
, Status
, AddDate
, AddWho
, EditDate
, EditWho
, Lot
, Loc
, Id
, Receiptkey
, ReceiptLineNumber
, Orderkey
, OrderLineNumber
, WaveKey
, PickDetailKey
, Userdefined04
, Userdefined05
, Userdefined06
, Userdefined07
, Userdefined08
, Userdefined09
, Userdefined10
, UCC_RowRef
, ArchiveCop=CAST(ArchiveCop AS NVARCHAR)
, TrafficCop=CAST(TrafficCop AS NVARCHAR)
   FROM [UCC] WITH (NOLOCK)

GO