SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE    PROC [BI].[isp_RPT_AMZ_Outbound_Ship_Confirmation_001_orig]
  @MBOL     	nvarchar (30)
		

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


select MB.MbolKey as [ShipRef]
, MB.ExternMbolKey as [AltShipRef]
, O.ConsigneeKey as [FC]
, U.UCCNo as [CartonID]
, O.IntermodalVehicle as [TruckReference]
, MB.DepartureDate as [TruckDeparture]
, MB.ArrivalDateFinalDestination as [DeliveryDate]
, RD.UserDefine09 as [HSCode]
, RD.UserDefine10 as [CoO]
from dbo.MBOL MB with(NOLOCK) join dbo.MBOLDETAIL MBD with(NOLOCK) on MB.MbolKey=MBD.MbolKey
join dbo.ORDERS O with(NOLOCK) on MBD.OrderKey=O.OrderKey
join dbo.PICKDETAIL PD with(NOLOCK) on O.OrderKey=PD.OrderKey and O.StorerKey=PD.Storerkey
left join dbo.UCC U with(NOLOCK) on PD.DropID=U.Id and PD.Storerkey=U.Storerkey
left join dbo.RECEIPTDETAIL RD with(NOLOCK) on U.Receiptkey=RD.ReceiptKey and U.ReceiptLineNumber=RD.ReceiptLineNumber and U.Storerkey=RD.StorerKey
WHERE MB.MbolKey =@MBOL
Group by MB.MbolKey,MB.ExternMbolKey,O.ConsigneeKey,O.IntermodalVehicle,MB.DepartureDate,U.UCCNo,MB.ArrivalDateFinalDestination,RD.UserDefine09,RD.UserDefine10

END

GO