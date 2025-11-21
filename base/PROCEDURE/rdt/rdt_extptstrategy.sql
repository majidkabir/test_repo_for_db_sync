SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_ExtPTStrategy                                         */
/* Copyright      : Maersk                                                    */
/* Customer       : VLT                                                       */
/* Purpose: Extended putaway For VLT                                          */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2024-09-23   Dennis    1.0   FCR-632 Created                               */
/******************************************************************************/

CREATE   PROCEDURE rdt.rdt_ExtPTStrategy
   @nMobile       INT,           
   @nFunc         INT,           
   @cLangCode     NVARCHAR( 3), 
   @nStep         INT,           
   @nInputKey     INT,           
   @cFacility     NVARCHAR( 5), 
   @cStorerKey    NVARCHAR( 15), 
   @cType         NVARCHAR( 10), --SUGGEST/EXECUTE/CANCEL
   @cReceiptKey   NVARCHAR( 10), 
   @cPOKey        NVARCHAR( 10), 
   @cLOC          NVARCHAR( 10), 
   @cID           NVARCHAR( 18),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,
   @cRDLineNo     NVARCHAR(5), 
   @cFinalLOC     NVARCHAR( 10) = '', 
   @cSuggToLOC    NVARCHAR( 10)  OUTPUT,
   @nPABookingKey INT            OUTPUT,
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   Declare @nCubic INT = 0,
      @nWeight float = 0
   IF @nFunc = 600 -- Normal receive v7
   BEGIN


      SELECT @nCubic = ISNULL(P.LengthUOM3,0) * ISNULL(P.WidthUOM3,0) * ISNULL(P.HeightUOM3,0) * @nQTY,
      @nWeight = SKU.STDGROSSWGT * @nQTY
      FROM dbo.SKU WITH (NOLOCK) 
      LEFT JOIN dbo.PACK P WITH (NOLOCK) ON SKU.PACKKey = P.PackKey
      WHERE SKU.SKU = @cSKU
      AND SKU.StorerKey = @cStorerKey

      SET @cSuggToLOC = ''

      SELECT @cSuggToLOC = PutawayLoc 
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey 
            AND ToID = @cID
            AND SKU = @cSKU

      IF ISNULL(@cSuggToLOC,'') = ''
         SELECT TOP 1 
            @cSuggToLOC = LOC.LOC 
         FROM dbo.LOC WITH (NOLOCK) 
         LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC AND LLI.StorerKey = @cStorerKey)
         LEFT JOIN dbo.SKU WITH (NOLOCK) ON LLI.SKU = SKU.SKU AND SKU.StorerKey = LLI.StorerKey
         LEFT JOIN dbo.PACK P WITH (NOLOCK) ON SKU.PACKKey = P.PackKey
         LEFT JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON SL.Loc = LOC.Loc AND SL.StorerKey = @cStorerKey
         WHERE 
            LOC.LocationType = 'SHELF'
            AND LOC.LocationCategory = 'SHELVING'
            AND LOC.LocationFlag = 'NONE'
            AND LOC.STATUS = 'OK'
            AND LOC.FACILITY = @cFacility
         GROUP BY LOC.LOC,PALogicalLoc
         HAVING SUM(ISNULL((LLI.qty-LLI.QtyPicked+PendingMoveIn),0) * ISNULL(P.LengthUOM3,0) * ISNULL(P.WidthUOM3,0) * ISNULL(P.HeightUOM3,0)) + @nCubic <= MAX(LOC.CubicCapacity)
         AND SUM(ISNULL((LLI.qty-LLI.QtyPicked+PendingMoveIn),0) * ISNULL(SKU.STDGROSSWGT,0)) + @nWeight <= MAX(LOC.WeightCapacity)
         Order by PALogicalLoc, LOC.Loc

      IF ISNULL(@cSuggToLOC,'')<>''
      BEGIN
         UPDATE ReceiptDetail WITH(ROWLOCK) SET
         PutawayLoc = @cSuggToLOC
         WHERE ReceiptKey = @cReceiptKey 
            AND ToId = @cID
            AND SKU = @cSKU
      END
   END
   ELSE
   BEGIN
      SET @nPABookingKey = 0
      SELECT @nCubic = ISNULL(P.LengthUOM3,0) * ISNULL(P.WidthUOM3,0) * ISNULL(P.HeightUOM3,0) * @nQTY,
      @nWeight = SKU.STDGROSSWGT * @nQTY
      FROM dbo.SKU WITH (NOLOCK) 
      LEFT JOIN dbo.PACK P WITH (NOLOCK) ON SKU.PACKKey = P.PackKey
      WHERE SKU.SKU = @cSKU
      AND SKU.StorerKey = @cStorerKey

      SET @cSuggToLOC = ''
      SELECT TOP 1 
         @cSuggToLOC = LOC.LOC 
      FROM dbo.LOC WITH (NOLOCK) 
      LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC AND LLI.StorerKey = @cStorerKey)
      LEFT JOIN dbo.SKU WITH (NOLOCK) ON LLI.SKU = SKU.SKU AND SKU.StorerKey = LLI.StorerKey
      LEFT JOIN dbo.PACK P WITH (NOLOCK) ON SKU.PACKKey = P.PackKey
      LEFT JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON SL.Loc = LOC.Loc AND SL.StorerKey = @cStorerKey
      WHERE 
         LOC.LocationType = 'SHELF'
         AND LOC.LocationCategory = 'SHELVING'
         AND LOC.LocationFlag = 'NONE'
         AND LOC.STATUS = 'OK'
         AND LOC.LOC <> @cFinalLOC
         AND LOC.FACILITY = @cFacility
         AND SL.Sku = @cSKU
         AND SL.LocationType = 'PICK'
      GROUP BY LOC.LOC,PALogicalLoc
      HAVING SUM(ISNULL((LLI.qty-LLI.QtyPicked+PendingMoveIn),0) * ISNULL(P.LengthUOM3,0) * ISNULL(P.WidthUOM3,0) * ISNULL(P.HeightUOM3,0)) + @nCubic <= MAX(LOC.CubicCapacity)
      AND SUM(ISNULL((LLI.qty-LLI.QtyPicked+PendingMoveIn),0) * ISNULL(SKU.STDGROSSWGT,0)) + @nWeight <= MAX(LOC.WeightCapacity)
      Order by PALogicalLoc, LOC.Loc

   END
END 
Quit:

SET QUOTED_IDENTIFIER OFF

GO