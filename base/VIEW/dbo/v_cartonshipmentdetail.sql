SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_CartonShipmentDetail]
AS SELECT *
FROM [dbo].[CartonShipmentDetail] WITH (NOLOCK)

GO