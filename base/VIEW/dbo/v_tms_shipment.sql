SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 

CREATE VIEW dbo.V_TMS_Shipment
AS
Select * from dbo.[TMS_Shipment] (NOLOCK)


GO