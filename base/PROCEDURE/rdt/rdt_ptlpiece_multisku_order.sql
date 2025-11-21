SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLPiece_MultiSKU_Order                               */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: MultiSKUBarcode with Order scope                                  */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 29-03-2022  1.0  Ung         WMS-19254 Created                             */
/* 09-05-2022  1.1  Ung         WMS-19254 Add UPC param                       */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_PTLPiece_MultiSKU_Order]
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),
   @cStorerKey   NVARCHAR( 15),
   @cStation     NVARCHAR( 10),
   @cMethod      NVARCHAR( 1),
   @cSKU         NVARCHAR( 20),
   @cLastPos     NVARCHAR( 10),
   @cOption      NVARCHAR( 1),
   @cUPC         NVARCHAR( 30)  OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Close cursor
   IF CURSOR_STATUS( 'global', 'Cursor_MultiSKUBarcode') IN (0, 1) -- 0=empty, 1=record
      CLOSE Cursor_MultiSKUBarcode
   IF CURSOR_STATUS( 'global', 'Cursor_MultiSKUBarcode') IN (-1)   -- -1=cursor is closed
      DEALLOCATE Cursor_MultiSKUBarcode

   DECLARE Cursor_MultiSKUBarcode CURSOR FAST_FORWARD READ_ONLY FOR --Note: global cursor
      SELECT A.StorerKey, A.SKU
      FROM
         (
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cUPC
            UNION ALL
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cUPC
            UNION ALL
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cUPC
            UNION ALL
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cUPC
            UNION ALL
            SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cUPC
         ) A 
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.StorerKey = A.StorerKey AND PD.SKU = A.SKU)
         JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
         JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey)
      WHERE L.Station = @cStation   
         AND PD.Status <= '5'  
         AND PD.CaseID = ''  
         AND PD.QTY > 0  
         AND PD.Status <> '4'  
         AND O.Status <> 'CANC'   
         AND O.SOStatus <> 'CANC'  
      GROUP BY A.StorerKey, A.SKU
      ORDER BY A.StorerKey, A.SKU
END

GO