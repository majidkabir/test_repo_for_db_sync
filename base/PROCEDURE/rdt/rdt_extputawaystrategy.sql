SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_ExtPutawayStrategy                                       */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2024-09-23   Deenis    1.0   FCR-632 Created                               */
/******************************************************************************/

CREATE   PROCEDURE rdt.rdt_ExtPutawayStrategy
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
      SELECT @nCubic = P.CubeUOM3 * @nQTY,
      @nWeight = SKU.STDGROSSWGT * @nQTY
      FROM SKU WITH (NOLOCK) 
      LEFT JOIN PACK P WITH (NOLOCK) ON SKU.PACKKey = P.PackKey
      WHERE SKU.SKU = @cSKU
      AND SKU.StorerKey = @cStorerKey

      SET @cSuggToLOC = ''
      -- Get SKU putaway before
      IF @cSuggToLOC = ''
         SELECT @cSuggToLOC = PutawayLOC 
         FROM ReceiptDetail WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey 
            AND SKU = @cSKU
            AND QTYReceived > 0
            AND PutawayLOC <> ''

      IF @cSuggToLOC = '' OR @cSuggToLOC IS NULL
         SELECT TOP 1 
            @cSuggToLOC = LOC.LOC 
         FROM LOC WITH (NOLOCK) 
         LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC AND LLI.StorerKey = @cStorerKey)
         LEFT JOIN SKU WITH (NOLOCK) ON LLI.SKU = SKU.SKU AND SKU.StorerKey = LLI.StorerKey
         LEFT JOIN PACK P WITH (NOLOCK) ON SKU.PACKKey = P.PackKey
         WHERE 
            LOC.LocationType = 'TROLLEYIB'
            AND LOC.LocationCategory = 'TROLLEYIB'
            AND LOC.LocationFlag NOT IN ('NONE','HOLD')
         GROUP BY LOC.LOC
         HAVING ISNULL(SUM((LLI.qty-LLI.QtyPicked+PendingMoveIn) * P.CubeUOM3),0) + @nCubic <= MAX(LOC.CubicCapacity)
         AND ISNULL(SUM((LLI.qty-LLI.QtyPicked+PendingMoveIn) * SKU.STDGROSSWGT),0) + @nWeight <= MAX(LOC.WeightCapacity)

      IF ISNULL(@cSuggToLOC,'')<>''
      BEGIN
         UPDATE ReceiptDetail SET
         PutawayLoc = @cSuggToLOC
         WHERE ReceiptKey = @cReceiptKey 
            AND ReceiptLineNumber = @cRDLineNo
            AND SKU = @cSKU
      END
   END
   ELSE
   BEGIN
      SELECT @nCubic = P.CubeUOM3 * @nQTY,
      @nWeight = SKU.STDGROSSWGT * @nQTY
      FROM SKU WITH (NOLOCK) 
      LEFT JOIN PACK P WITH (NOLOCK) ON SKU.PACKKey = P.PackKey
      WHERE SKU.SKU = @cSKU
      AND SKU.StorerKey = @cStorerKey

      SET @cSuggToLOC = ''
      SELECT TOP 1 
         @cSuggToLOC = LOC.LOC 
      FROM LOC WITH (NOLOCK) 
      LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC AND LLI.StorerKey = @cStorerKey)
      LEFT JOIN SKU WITH (NOLOCK) ON LLI.SKU = SKU.SKU AND SKU.StorerKey = LLI.StorerKey
      LEFT JOIN PACK P WITH (NOLOCK) ON SKU.PACKKey = P.PackKey
      WHERE 
         LOC.LocationType = 'TROLLEYIB'
         AND LOC.LocationCategory = 'TROLLEYIB'
         AND LOC.LocationFlag NOT IN ('NONE','HOLD')
         AND LOC.LOC <> @cFinalLOC
      GROUP BY LOC.LOC
      HAVING ISNULL(SUM((LLI.qty-LLI.QtyPicked+PendingMoveIn) * P.CubeUOM3),0) + @nCubic <= MAX(LOC.CubicCapacity)
      AND ISNULL(SUM((LLI.qty-LLI.QtyPicked+PendingMoveIn) * SKU.STDGROSSWGT),0) + @nWeight <= MAX(LOC.WeightCapacity)
   END
END
Quit:

SET QUOTED_IDENTIFIER OFF

GO