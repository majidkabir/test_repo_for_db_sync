SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_607ExStkIDLOC02                                       */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 11-Dec-2017  Ung       1.0   WMS-3539 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_607ExStkIDLOC02]
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cStorerKey   NVARCHAR( 15), 
   @cReceiptKey  NVARCHAR( 10), 
   @cPOKey       NVARCHAR( 10), 
   @cRefNo       NVARCHAR( 20), 
   @cSKU         NVARCHAR( 20), 
   @nQTY         INT,           
   @cLottable01  NVARCHAR( 18), 
   @cLottable02  NVARCHAR( 18), 
   @cLottable03  NVARCHAR( 18), 
   @dLottable04  DATETIME,      
   @dLottable05  DATETIME,      
   @cLottable06  NVARCHAR( 30), 
   @cLottable07  NVARCHAR( 30), 
   @cLottable08  NVARCHAR( 30), 
   @cLottable09  NVARCHAR( 30), 
   @cLottable10  NVARCHAR( 30), 
   @cLottable11  NVARCHAR( 30), 
   @cLottable12  NVARCHAR( 30), 
   @dLottable13  DATETIME,      
   @dLottable14  DATETIME,      
   @dLottable15  DATETIME, 
   @cReasonCode  NVARCHAR( 10), 
   @cID          NVARCHAR( 18), 
   @cLOC         NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 10), 
   @cSuggID      NVARCHAR( 18)  OUTPUT, 
   @cSuggLOC     NVARCHAR( 10)  OUTPUT, 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cASNReason NVARCHAR( 10)
   DECLARE @cUDF01 NVARCHAR( 60)
   DECLARE @cFacility NVARCHAR( 60)

   IF @nFunc = 607 -- Return v7
   BEGIN
      -- Get ASN info
      SELECT 
         @cASNReason = ASNReason, 
         @cFacility = Facility
      FROM Receipt WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey
      
      -- Get code lookup info
      SELECT @cUDF01 = LEFT( UDF01, 10)
      FROM CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'ASNREASON' 
         AND Code = @cASNReason
         AND StorerKey = @cStorerKey

      -- Get suggested LOC
      IF @cUDF01 <> ''
         SET @cSuggLOC = @cUDF01

      -- Get suggested ID
      IF @cASNReason = 'NORMAL'
      BEGIN
         -- Find a friend (same SKU) with min QTY
         SELECT TOP 1 
            @cSuggID = LOC.LOCAisle
         FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND LOC.PutawayZone IN 
               (SELECT Code2 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'ASNREASON' AND Code = @cASNReason AND StorerKey = @cStorerKey) 
            AND LLI.StorerKey = @cStorerKey
            AND LLI.SKU = @cSKU
            AND LLI.QTY-LLI.QTYPicked > 0
         ORDER BY LLI.QTY-LLI.QTYPicked 
         
         IF @@ROWCOUNT = 0
         BEGIN
            -- Get SKU info
            DECLARE @cStyle NVARCHAR(20)
            SELECT @cStyle = Style FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
            
            -- Find a friend (same style) with min QTY
            IF @cStyle <> ''
               SELECT TOP 1 
                  @cSuggID = LOC.LOCAisle
               FROM LOTxLOCxID LLI WITH (NOLOCK)
                  JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
                  JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = LLI.StorerKey AND SKU.SKU = LLI.SKU)
               WHERE LOC.Facility = @cFacility
                  AND LOC.PutawayZone IN
                     (SELECT Code2 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'ASNREASON' AND Code = @cASNReason AND StorerKey = @cStorerKey) 
                  AND LLI.StorerKey = @cStorerKey
                  AND SKU.Style = @cStyle
                  AND LLI.QTY-LLI.QTYPicked > 0
               ORDER BY LLI.QTY-LLI.QTYPicked 
         END      
      END
      
      ELSE IF @cASNReason = 'PRJ'
      BEGIN
         IF @cUDF01 <> ''
            SELECT @cSuggID = MAX( LLI.ID) 
            FROM LOTxLOCxID LLI WITH (NOLOCK)
            WHERE LLI.StorerKey = @cStorerKey
               AND LLI.SKU = @cSKU 
               AND LLI.QTY <> 0 
               AND LOC = @cUDF01
      END
   END

Quit:

END

GO