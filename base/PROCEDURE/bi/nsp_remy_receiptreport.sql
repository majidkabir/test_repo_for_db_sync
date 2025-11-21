SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
-- https://jiralfl.atlassian.net/browse/BI-197
/* Updates:                                                                */
/* Date         Author      Ver.  Purposes                                 */
/* 19-July-2021  GuanHaoChan 1.0   Created                                  */
/***************************************************************************/
CREATE PROCEDURE [BI].[nsp_REMY_ReceiptReport]
	-- Add the parameters for the stored procedure here
	--@c_StorerKey   NVARCHAR(15) = ''
   @c_Key1 	      NVARCHAR(20) = ''
 --, @c_Key2        NVARCHAR(20) = ''
 --, @c_Key3        NVARCHAR(20) = ''

AS
BEGIN
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   -- Insert statements for procedure here

   SELECT R.CarrierReference AS [BL Number]
         ,R.ReceiptKey AS [ASN#]
         ,RD.Sku AS [SKU]
         ,S.DESCR AS [SKU Description]
         ,RD.QtyExpected AS [ASN Qty]
         ,RD.QtyReceived AS [Received Qty]
         ,RD.Lottable02 AS [LOT#]
         ,CONVERT(varchar,RD.DateReceived,111) AS [Date Receieved]
   FROM dbo.V_RECEIPT R WITH (NOLOCK)
   INNER JOIN dbo.V_RECEIPTDETAIL RD WITH (NOLOCK)
   ON R.ReceiptKey = RD.ReceiptKey
   INNER JOIN dbo.V_SKU S WITH (NOLOCK)
   ON S.StorerKey = RD.StorerKey 
   AND S.Sku = RD.Sku
   WHERE R.CarrierReference = @c_Key1
   --AND R.ContainerKey = @c_Key2
   --AND S.Sku = @c_Key2
   --AND RD.Lottable02 = @c_Key3
   --AND S.StorerKey = @c_StorerKey

END --End Stored Procedure

GO