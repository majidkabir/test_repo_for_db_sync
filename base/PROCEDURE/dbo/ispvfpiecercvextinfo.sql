SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispVFPieceRcvExtInfo                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Decode Label No Scanned                                     */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 21-11-2013  1.0  Ung         SOS288143. Created                      */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispVFPieceRcvExtInfo]
   @c_ReceiptKey     NVARCHAR(10),
   @c_POKey          NVARCHAR(10),
   @c_ToLOC          NVARCHAR(10),
   @c_ToID           NVARCHAR(18),
   @c_Lottable01     NVARCHAR(18),
   @c_Lottable02     NVARCHAR(18),
   @c_Lottable03     NVARCHAR(18),
   @d_Lottable04     DATETIME,
   @c_StorerKey      NVARCHAR(15),
   @c_SKU            NVARCHAR(20),
	@c_oFieled01      NVARCHAR(20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cOtherSKU NVARCHAR(20)   
   SET @cOtherSKU = ''
   
   -- Get other SKU in ID
   SELECT TOP 1 @cOtherSKU = SKU
   FROM ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @c_ReceiptKey
      AND ToID = @c_ToID
      AND SKU <> @c_SKU

   IF @cOtherSKU = ''
      SET @c_oFieled01 = 'SINGLESKU'
   ELSE
      SET @c_oFieled01 = 'MULTISKU'
     
QUIT:
END -- End Procedure


GO