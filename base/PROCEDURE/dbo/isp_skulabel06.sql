SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_SKULabel06                                     */
/*                                                                      */
/* Purpose: Piece Receiving SKU LABEL                                   */
/*                                                                      */
/* Input Parameters: @c_ReceiptKey,  @c_ReceiptLineNumber               */
/*                                                                      */
/* Called By:  dw = r_dw_sku_label06                                    */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2017-08-16   James         WMS2604. Created                          */
/************************************************************************/
CREATE PROC [dbo].[isp_SKULabel06] (
      @c_ReceiptKey              NVARCHAR( 10) 
   ,  @c_ReceiptLineNumber       NVARCHAR( 5)
) 
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Lottable03 NVARCHAR( 18),
           @c_ToLOC      NVARCHAR( 10),
           @c_ToLOC1     NVARCHAR( 10),
           @c_ToLOC2     NVARCHAR( 10),
           @c_ToLOC3     NVARCHAR( 10),
           @c_ToLOC4     NVARCHAR( 10),
           @c_ToLOC5     NVARCHAR( 10),
           @c_ToID       NVARCHAR( 18),
           @c_ToID1      NVARCHAR( 18),
           @c_ToID2      NVARCHAR( 18),
           @c_SKU        NVARCHAR( 20),
           @n_ToIDLen    INT,
           @n_NoOfToID   INT

                                              
   SELECT 
          @c_ToLOC = Lottable03, 
          @c_ToID = ToID,
          @n_NoOfToID = UserDefine05, 
          @c_SKU = SKU.BUSR10
   FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
   JOIN SKU SKU WITH (NOLOCK) ON ( RD.SKU = SKU.SKU AND RD.StorerKey = SKU.StorerKey)
   WHERE ReceiptKey = @c_ReceiptKey
   AND   ReceiptLineNumber = @c_ReceiptLineNumber

   SET @c_ToLOC1 = SUBSTRING( @c_ToLOC, 1, 3) + '-'
   SET @c_ToLOC2 = SUBSTRING( @c_ToLOC, 4, 3) + '-' 
   SET @c_ToLOC3 = SUBSTRING( @c_ToLOC, 7, 2) + '-'
   SET @c_ToLOC4 = SUBSTRING( @c_ToLOC, 9, 1) + '-'
   SET @c_ToLOC5 = SUBSTRING( @c_ToLOC, 10, 1)

   SET @c_ToID1 = @c_ToID  + '-'
   SET @c_ToID2 = @n_NoOfToID

   SET @c_ToLOC = @c_ToLOC1 + @c_ToLOC2 + @c_ToLOC3 + @c_ToLOC4 + @c_ToLOC5
   SET @c_ToID = RTRIM( @c_ToID1) + @c_ToID2

   --SELECT @c_ReceiptKey AS ReceiptKey, @c_ToLOC AS ToLOC, @c_ToID AS ToID, @c_SKU AS SKU

   SELECT @c_ReceiptKey AS ReceiptKey, @c_ToLOC1 AS ToLOC1, @c_ToLOC2 AS ToLOC2, 
          @c_ToLOC3 AS ToLOC3, @c_ToLOC4 AS ToLOC4, @c_ToLOC5 AS ToLOC5, 
          @c_ToID1 AS ToID1, @c_ToID2 AS ToID2, @c_SKU AS SKU
END

GO