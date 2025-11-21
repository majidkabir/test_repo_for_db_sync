SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE      PROC [BI].[isp_RPT_AMZ_Outbound_Ship_Confirmation_001]
  @STORER 		NVARCHAR (30)
 ,@MBOL     	NVARCHAR (30)
 ,@STARTDATE	DATE 
 ,@ENDDATE		DATE
  

		

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
WHERE MB.MbolKey LIKE (CASE WHEN @MBOL IS NULL THEN '%' ELSE @MBOL END)
AND O.StorerKey LIKE (CASE WHEN @STORER IS NULL THEN '%' ELSE @STORER END)
--AND MB.ShipDate >= @STARTDATE
--AND MB.ShipDate < @ENDDATE
AND MB.ShipDate >= (CASE WHEN @STARTDATE IS NULL THEN getdate()-1 ELSE @STARTDATE END)
AND MB.ShipDate < (CASE WHEN @ENDDATE IS NULL THEN getdate() ELSE @ENDDATE END)
Group by MB.MbolKey,MB.ExternMbolKey,O.ConsigneeKey,O.IntermodalVehicle,MB.DepartureDate,U.UCCNo,MB.ArrivalDateFinalDestination,RD.UserDefine09,RD.UserDefine10
ORDER BY 1

END

GO