SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1768DisplayQty01                                      */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: If scanned code = upc then need default qty in CA else in EA      */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2022-07-13  James     1.0   WMS-19597. Created                             */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1768DisplayQty01] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cTaskDetailKey  NVARCHAR( 10),
   @cCCKey          NVARCHAR( 10),
   @cCCDetailKey    NVARCHAR( 10),
   @cLoc            NVARCHAR( 10),
   @cID             NVARCHAR( 18),
   @cSKU            NVARCHAR( 20),
   @nActQTY         INT,
   @cBarcode        NVARCHAR( 60),
   @cPUOM           NVARCHAR( 1),
   @nPUOM_Div       NVARCHAR( 5),
   @cPUOM_Desc      NVARCHAR( 5)    OUTPUT,
   @cMUOM_Desc      NVARCHAR( 5)    OUTPUT,
   @cFieldAttr06    NVARCHAR( 1)    OUTPUT,
   @cFieldAttr07    NVARCHAR( 1)    OUTPUT,
   @cOutField04     NVARCHAR( 60)   OUTPUT,
   @cOutField05     NVARCHAR( 60)   OUTPUT,
   @cOutField06     NVARCHAR( 60)   OUTPUT,
   @cOutField07     NVARCHAR( 60)   OUTPUT,
   @tExtendedDisplayQty     VARIABLETABLE READONLY
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nPQTY    INT = 0
   DECLARE @nMQTY    INT = 0

   IF @cBarcode = ''
      GOTO Quit

   IF @nFunc = 1768 -- TMCC SKU
   BEGIN
   	SET @cFieldAttr06 = ''
   	SET @cFieldAttr07 = ''
   	
      SELECT 
         @cMUOM_Desc  = Pack.PackUOM3
      , @cPUOM_Desc  =
      CASE @cPUOM
         WHEN '2' THEN Pack.PackUOM1 -- Case
         WHEN '3' THEN Pack.PackUOM2 -- Inner pack
         WHEN '6' THEN Pack.PackUOM3 -- Master unit
         WHEN '1' THEN Pack.PackUOM4 -- Pallet
         WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
         WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
      END
      ,  @nPUOM_Div  = CAST( IsNULL(
      CASE @cPUOM
         WHEN '2' THEN Pack.CaseCNT
         WHEN '3' THEN Pack.InnerPack
         WHEN '6' THEN Pack.QTY
         WHEN '1' THEN Pack.Pallet
         WHEN '4' THEN Pack.OtherUnit1
         WHEN '5' THEN Pack.OtherUnit2
      END, 1) AS INT)
      FROM dbo.SKU SKU WITH (NOLOCK)
      INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.SKU = @cSKU
      AND SKU.StorerKey = @cStorerKey
         
      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY = 0
         SET @nMQTY = @nActQTY
      END
      ELSE
      BEGIN
         SET @nPQTY = @nActQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
         SET @nMQTY = @nActQTY % @nPUOM_Div  -- Calc the remaining in master unit
      END         

      IF EXISTS ( SELECT 1 FROM dbo.UPC WITH (NOLOCK, INDEX(PK_UPC))
         	   WHERE StorerKey = @cStorerKey
         	   AND   UPC = @cBarcode)
      BEGIN
      	SET @cOutField04 = @cPUOM_Desc
      	SET @cOutField05 = @cMUOM_Desc
      	SET @cOutField06 = @nPQTY
      	SET @cOutField07 = 0
      	
      	EXEC rdt.rdtSetFocusField @nMobile, 06
      END
      ELSE
      BEGIN
      	SET @cOutField04 = ''
      	SET @cOutField05 = @cPUOM_Desc
      	SET @cOutField06 = 0
      	SET @cOutField07 = @nMQTY

         IF @nPQTY > 0
            EXEC rdt.rdtSetFocusField @nMobile, 06
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 07
      END
   END

Quit:

END

GO