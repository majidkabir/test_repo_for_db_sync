SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_522ExtInfo02                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Display case count                                                */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 08-Oct-2015  James     1.0   SOS348695 Created                             */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_522ExtInfo02]
   @nMobile         INT,           
   @nFunc           INT,           
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT,           
   @nInputKey       INT,           
   @cStorerKey      NVARCHAR( 15), 
   @cFacility       NVARCHAR( 5),  
   @cID             NVARCHAR( 18), 
   @cFromLOC        NVARCHAR( 10), 
   @cSKU            NVARCHAR( 20), 
   @nQTY            INT,           
   @cSuggestedLOC   NVARCHAR( 10), 
   @cToLOC          NVARCHAR( 10), 
   @cPickAndDropLOC NVARCHAR( 10), 
   @cFinalLOC       NVARCHAR( 10), 
   @cExtendedInfo1  NVARCHAR( 20) OUTPUT, 
   @nErrNo          INT           OUTPUT, 
   @cErrMsg         NVARCHAR( 20) OUTPUT, 
   @nAfterStep      INT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLot        NVARCHAR( 10), 
           @cCaseCnt    NVARCHAR( 10)

   IF @nInputKey = 1 
   BEGIN
      IF @nStep = 2 
      BEGIN
         SELECT TOP 1 @cLot = Lot
         From dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE ID = @cID
         AND   LOC = @cFromLOC
         AND   SKU = @cSKU
         AND   ( QTY - QTYALLOCATED - QTYPICKED) > 0

         SELECT @cCaseCnt = Lottable06
         FROM dbo.LotAttribute WITH (NOLOCK) 
         WHERE LOT = @cLOT
         
         SET @cExtendedInfo1 = 'CASE QTY: ' + @cCaseCnt
      END
   END
END

GO