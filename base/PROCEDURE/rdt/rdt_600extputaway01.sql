SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600ExtPutaway01                                       */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 19-Apr-2015  Ung       1.0   SOS335126 Created                             */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_600ExtPutaway01]
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
   @cFinalLOC     NVARCHAR( 10), 
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

   IF @nFunc = 600 -- Normal receive v7
   BEGIN
      SET @cSuggToLOC = ''

      -- Get SKU putaway before
      IF @cSuggToLOC = ''
         SELECT @cSuggToLOC = PutawayLOC 
         FROM ReceiptDetail WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey 
            AND SKU = @cSKU
            AND QTYReceived > 0
            AND PutawayLOC <> ''
      
      -- Find a friend
      IF @cSuggToLOC = ''
         SELECT @cSuggToLOC = SL.LOC 
         FROM SKUxLOC SL WITH (NOLOCK) 
            JOIN LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
         WHERE SL.StorerKey = @cStorerKey
            AND SL.SKU = @cSKU
            AND LOC.PutawayZone = 'LOR_P1'
            AND SL.QTY-SL.QTYPicked > 0

      -- Find a friend (with same ItemClass)
      IF @cSuggToLOC = ''
      BEGIN
         DECLARE @cItemClass NVARCHAR( 10)
         SELECT @cItemClass = ItemClass FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
         
         SELECT TOP 1 
            @cSuggToLOC = SL.LOC 
         FROM SKUxLOC SL WITH (NOLOCK) 
            JOIN LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
            JOIN SKU WITH (NOLOCK) ON (SL.StorerKey = SKU.StorerKey AND SL.SKU = SKU.SKU)
         WHERE SKU.StorerKey = @cStorerKey
            AND LOC.PutawayZone = 'LOR_P1'
            AND SL.QTY-SL.QTYPicked > 0
            AND SKU.ItemClass = @cItemClass
         ORDER BY LOC.LOC DESC
      END
   END
END

SET QUOTED_IDENTIFIER OFF

GO