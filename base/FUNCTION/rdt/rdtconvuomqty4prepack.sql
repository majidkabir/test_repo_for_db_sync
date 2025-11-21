SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Function       : rdtConvUOMQty4Prepack                               */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Convert QTY based on FromUOM and ToUOM for the Prepack      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2010-03-16   1.0  James      Created                                 */
/************************************************************************/

CREATE FUNCTION rdt.rdtConvUOMQty4Prepack ( 
   @cStorer  NVARCHAR( 15),
   @cAltSKU  NVARCHAR( 20),
   @nFromQTY INT,
   @cFromUOM NVARCHAR( 1),
   @cToUOM   NVARCHAR( 1)
) RETURNS INT AS
BEGIN

   IF @nFromQTY IS NULL
      GOTO FAIL

   DECLARE @nEaQTY  INT
   DECLARE @nDivQTY INT
   DECLARE @nToQTY  INT

   SELECT @nEaQTY  = 0
   SELECT @nDivQTY = 0
   SELECT @nToQTY  = 0

   SELECT @nEaQTY = @nFromQTY * SUM(ISNULL(Qty, 0)) FROM dbo.BillOfMaterial WITH (NOLOCK) 
   WHERE StorerKey = @cStorer
      AND SKU = @cAltSKU

   SELECT @nDivQTY = CASE @cToUOM
            WHEN '1' THEN PACK.Pallet
            WHEN '2' THEN PACK.CaseCnt
            WHEN '3' THEN PACK.InnerPack
            WHEN '4' THEN PACK.OtherUnit1
            WHEN '5' THEN PACK.OtherUnit2
            WHEN '6' THEN PACK.QTY
            ELSE NULL END
      FROM dbo.SKU SKU WITH (NOLOCK)
         INNER JOIN dbo.UPC UPC WITH (NOLOCK) ON (UPC.SKU = SKU.SKU AND UPC.StorerKey = SKU.StorerKey)
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (UPC.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorer
         AND UPC.SKU = @cAltSKU
         AND UPC.UOM = 'CS'

   IF @nEaQTY IS NULL OR @nDivQTY IS NULL OR @nDivQTY = 0
      GOTO FAIL

   SELECT @nToQTY = @nEaQTY / @nDivQTY

   RETURN @nToQTY

FAIL:
   RETURN NULL
END

GO