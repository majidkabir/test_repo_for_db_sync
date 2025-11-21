SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_FlowThruSort_Label01                            */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Print flow thru sortation label                             */
/* (use sp coz dun want to hardcode db name)                            */
/* Called from: r_dw_order_label01                                      */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 24-Mar-2009 1.0  James       Created                                 */
/************************************************************************/

CREATE PROC [dbo].[isp_FlowThruSort_Label01] 
   @c_WaveKey     NVARCHAR( 10),
   @c_UserName    NVARCHAR( 18),
   @c_BatchNo     NVARCHAR( 10)
AS
BEGIN
   SET NOCOUNT ON			-- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    

   Select 
         R.SKU AS SKU,
         S.Style AS STYLE,
         S.Color AS COLOR,
         S.Measurement AS MEASUREMENT,
         R.ConsigneeKey AS CONSIGNEEKEY,
   		SUM(R.Qty) AS QTY                                 
   FROM rdt.rdtFlowThruSortDistr R WITH (NOLOCK) 
   JOIN dbo.SKU S WITH (NOLOCK) ON (R.StorerKey = S.StorerKey AND R.SKU = S.SKU)
   Where WaveKey = @c_WaveKey 
   AND UserName = @c_UserName
   AND BatchNo = @c_BatchNo 
   GROUP BY R.SKU, S.Style, S.Color, S.Measurement, R.ConsigneeKey
END

GO