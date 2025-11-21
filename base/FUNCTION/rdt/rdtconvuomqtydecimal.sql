SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Function       : rdtConvUOMQtyDecimal                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Convert QTY based on FromUOM and ToUOM                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2024-06-27   1.0  Dennis     Created                                 */
/************************************************************************/

CREATE FUNCTION rdt.rdtConvUOMQtyDecimal ( 
   @cStorer  NVARCHAR( 15),
   @cSKU     NVARCHAR( 20),
   @nFromQTY FLOAT,
   @cFromUOM NVARCHAR( 1),
   @cToUOM   NVARCHAR( 1)
) RETURNS INT AS
BEGIN

   IF @nFromQTY IS NULL
      GOTO FAIL

   DECLARE @nEaQTY  FLOAT
   DECLARE @nDivQTY INT
   DECLARE @nToQTY  INT

   SELECT @nEaQTY  = 0
   SELECT @nDivQTY = 0
   SELECT @nToQTY  = 0

   SELECT 
      @nEaQTY = CASE @cFromUOM
            WHEN '1' THEN @nFromQTY * PACK.Pallet
            WHEN '2' THEN @nFromQTY * PACK.CaseCnt
            WHEN '3' THEN @nFromQTY * PACK.InnerPack
            WHEN '4' THEN @nFromQTY * PACK.OtherUnit1
            WHEN '5' THEN @nFromQTY * PACK.OtherUnit2
            WHEN '6' THEN @nFromQTY * PACK.QTY
            WHEN '7' THEN @nFromQTY * PACK.Cube
            WHEN '8' THEN @nFromQTY * PACK.GrossWgt
            WHEN '9' THEN @nFromQTY * PACK.NetWgt
            ELSE NULL END,
      @nDivQTY = CASE @cToUOM
            WHEN '1' THEN PACK.Pallet
            WHEN '2' THEN PACK.CaseCnt
            WHEN '3' THEN PACK.InnerPack
            WHEN '4' THEN PACK.OtherUnit1
            WHEN '5' THEN PACK.OtherUnit2
            WHEN '6' THEN PACK.QTY
            ELSE NULL END
   FROM dbo.SKU SKU (NOLOCK)
   INNER JOIN dbo.PACK PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
   WHERE SKU.StorerKey = @cStorer
   AND   SKU.SKU = @cSKU

   IF @nEaQTY IS NULL OR @nDivQTY IS NULL OR @nDivQTY = 0
      GOTO FAIL
   IF TRY_PARSE(CONVERT(VARCHAR,CONVERT(DECIMAL(18,0),@nEAQTY/@nDivQTY)) AS INT) IS NULL
      GOTO FAIL
   SELECT @nToQTY = @nEaQTY / @nDivQTY

   RETURN @nToQTY

FAIL:
   RETURN NULL
END

GO