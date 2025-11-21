SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_OrderInfo] AS
SELECT OrderKey
, OrderInfo01
, OrderInfo02
, OrderInfo03
, OrderInfo04
, OrderInfo05
, OrderInfo06
, OrderInfo07
, OrderInfo08
, OrderInfo09
, OrderInfo10
, AddWho
, AddDate
, EditWho
, EditDate
, TrafficCop=CAST(TrafficCop AS NVARCHAR)
, ArchiveCop=CAST(ArchiveCop AS NVARCHAR)
, EcomOrderId
, ReferenceId
, StoreName
, Platform
, InvoiceType
, PmtDate
, InsuredAmount
, CarrierCharges
, OtherCharges
, PayableAmount
, DeliveryMode
, CarrierName
, DeliveryCategory
, Notes
, Notes2
, OTM_OrderOwner
, OTM_BillTo
, OTM_NotifyParty
, CourierTimeStamp
   FROM [OrderInfo] WITH (NOLOCK)

GO