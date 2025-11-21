SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_ORDERS] AS
SELECT *
,ltrim(rtrim(BillToKey)) + ltrim(rtrim(ConsigneeKey)) AS ShipToCode
   FROM DBO.[ORDERS] WITH (NOLOCK)

GO