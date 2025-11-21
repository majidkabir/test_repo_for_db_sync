SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_607ExtPA02_IDLOC                                      */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 16-Nov-2016  Ung       1.0   WMS-632 Created                               */
/* 10-Jul-2017  Ung       1.1   WMS-2369 Change suggested ID logic            */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_607ExtPA02_IDLOC]
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

   IF @nFunc = 607 -- Return v7
   BEGIN
      DECLARE @cDocType NVARCHAR(1)
      DECLARE @cRecType NVARCHAR(10)
      SELECT 
         @cDocType = DocType, 
         @cRecType = RecType 
      FROM Receipt WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey

      IF @cSuggLOC = ''
      BEGIN
         SELECT TOP 1
            @cSuggLOC = Code
         FROM CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'PBULKSTACK'
            AND StorerKey = @cStorerKey
            AND UDF01 = @cDocType
      END
      
      IF @cSuggID = ''
      BEGIN
         IF @cDocType = 'A'
         BEGIN
            -- Get last ToID of that SKU
            SELECT TOP 1 
               @cSuggID = ToID 
            FROM ReceiptDetail WITH (NOLOCK) 
            WHERE ReceiptKey = @cReceiptKey 
               AND SKU = @cSKU
            ORDER BY EditDate DESC
         END
         ELSE
         BEGIN
            -- Recalc Lottable02
            IF @cRecType = 'ECOM'
               SET @cLottable02 = 'ECOM'
            ELSE
               SET @cLottable02 = ''
               
            IF @cReasonCode = ''
               SELECT @cSuggID = ISNULL( MIN( LOC.PutawayZone), '')
               FROM LOTxLOCxID LLI WITH (NOLOCK)
                  JOIN LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
                  JOIN PutawayZone WITH (NOLOCK) ON (PutawayZone.PutawayZone = LOC.PutawayZone)
                  JOIN LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
               WHERE LLI.StorerKey = @cStorerKey
                  AND LLI.SKU = @cSKU 
                  AND LLI.QTY > 0 
                  AND LA.Lottable02 = @cLottable02
                  AND PutawayZone.ZoneCategory = 'A' 
            ELSE
               SELECT @cSuggID = ISNULL( MIN( LOC.PutawayZone), '')
               FROM LOTxLOCxID LLI WITH (NOLOCK)
                  JOIN LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
                  JOIN PutawayZone WITH (NOLOCK) ON (PutawayZone.PutawayZone = LOC.PutawayZone)
                  JOIN LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
               WHERE LLI.StorerKey = @cStorerKey
                  AND LLI.SKU = @cSKU 
                  AND LLI.QTY > 0 
                  AND LA.Lottable02 = @cLottable02
                  AND PutawayZone.ZoneCategory <> 'A'          
         
            -- Default suggested ID, if no stock
            IF @cSuggID = ''
            BEGIN
               -- Get SKU info
               DECLARE @cBUSR7 NVARCHAR(30)
               SELECT @cBUSR7 = BUSR7 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
               
               IF @cReasonCode = ''
               BEGIN
                  IF @cLottable02 = 'ECOM'
                     SET @cSuggID = 'ELNEC'
                  ELSE
                     SET @cSuggID = LEFT( @cBUSR7, 17)
               END
               ELSE IF @cReasonCode <> ''
               BEGIN
                  IF @cLottable02 = 'ECOM'
                     SET @cSuggID = 'ELNEC-FLAW'
                  ELSE
                     SET @cSuggID = 'ELN-FLAW'
               END
            END
         END
      END
   END

Quit:

END

GO