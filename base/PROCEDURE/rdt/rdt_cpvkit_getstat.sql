SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_CPVKit_GetStat                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2018-07-31 1.0  Ung      WMS-5380 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_CPVKit_GetStat] (
   @nMobile          INT,           
   @nFunc            INT,           
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT,           
   @nInputKey        INT,           
   @cFacility        NVARCHAR( 5),   
   @cStorerKey       NVARCHAR( 15), 
   @cType            NVARCHAR( 10), -- CHILD/PARENT/BOTH
   @cKitKey          NVARCHAR( 10),
   @cParentSKU       NVARCHAR( 20),
   @nParentInner     INT, 
   @cChildSKU        NVARCHAR( 20),
   @nChildInner      INT, 
   @nParentScan      INT           OUTPUT,
   @nParentTotal     INT           OUTPUT,
   @nChildScan       INT           OUTPUT,
   @nChildTotal      INT           OUTPUT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @cType = 'CHILD' OR @cType = 'BOTH'
   BEGIN
      SELECT @nChildScan = ISNULL( SUM( L.QTY / CASE WHEN Pack.InnerPack > 0 THEN Pack.InnerPack ELSE 1 END), 0) 
      FROM rdt.rdtCPVKitLog L WITH (NOLOCK)
         JOIN SKU WITH (NOLOCK) ON (L.StorerKey = SKU.StorerKey AND L.SKU = SKU.SKU)
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE L.Mobile = @nMobile
         AND L.KitKey = @cKitKey
         AND L.Type = 'F' -- Child
         AND L.Barcode <> ''
      
      IF @nChildTotal = 0
         SELECT @nChildTotal = ISNULL( SUM( L.ExpectedQTY / CASE WHEN Pack.InnerPack > 0 THEN Pack.InnerPack ELSE 1 END), 0) 
         FROM rdt.rdtCPVKitLog L WITH (NOLOCK)
            JOIN SKU WITH (NOLOCK) ON (L.StorerKey = SKU.StorerKey AND L.SKU = SKU.SKU)
            JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE L.Mobile = @nMobile
            AND L.KitKey = @cKitKey
            AND L.Type = 'F' -- Child
            AND SKU.SerialNoCapture = '3' -- 3=Outbound
   END

   IF @cType = 'PARENT' OR @cType = 'BOTH'
   BEGIN
      SELECT 
         @nParentScan = ISNULL( SUM( QTY), 0), 
         @nParentTotal = ISNULL( SUM( ExpectedQTY), 0) 
      FROM rdt.rdtCPVKitLog WITH (NOLOCK)
      WHERE Mobile = @nMobile
         AND KitKey = @cKitKey
         AND StorerKey = @cStorerKey
         AND SKU = @cParentSKU
         AND Type = 'T' -- To=Parent
   
      IF @nParentInner > 0
      BEGIN
         SET @nParentScan = @nParentScan / @nParentInner
         SET @nParentTotal = @nParentTotal / @nParentInner
      END
   END
END

GO