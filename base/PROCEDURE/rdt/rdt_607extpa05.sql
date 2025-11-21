SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_607ExtPA05                                            */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 21-Feb-2018  ChewKP    1.0   WMS-3895 Created                              */
/* 15-Mar-2019  James     1.1   WMS-8158 Add Lot01 & 08 filter (james01)      */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_607ExtPA05]
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
      

      IF @cSuggLOC = ''
      BEGIN
         IF EXISTS ( SELECT 1 FROM LotxLocxID LLI WITH (NOLOCK)
                     JOIN CodeLkup CLK  WITH (NOLOCK) ON LLI.LOC = CLK.SHORT AND LLI.StorerKey = CLK.StorerKey AND CLK.ListName = 'UARESTAGE'
                     JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LLI.Lot = LA.Lot
                     WHERE LLI.StorerKey = @cStorerKey 
                     AND   LLI.SKU = @cSKU 
                     AND   LLI.Qty <> '0' 
                     AND   LA.Lottable01 = @cLottable01  
                     AND   LA.Lottable08 = @cLottable08)
         BEGIN
            SELECT TOP 1 
                    @cSuggID = LLI.ID
                   ,@cSuggLOC = LLI.LOC
            FROM LotxLocxID  LLI WITH (NOLOCK)
            JOIN CodeLkup CLK  WITH (NOLOCK) ON LLI.LOC = CLK.SHORT AND LLI.StorerKey = CLK.StorerKey AND CLK.LISTNAME = 'UARESTAGE'
            JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LLI.Lot = LA.Lot
            WHERE LLI.StorerKey = @cStorerKey 
            AND   LLI.SKU = @cSKU 
            AND   LLI.Qty <> '0' 
            AND   LA.Lottable01 = @cLottable01
            AND   LA.Lottable08 = @cLottable08
         END
         ELSE
         BEGIN
            SET @cSuggLOC = 'NEW SKU'
         END

      END
      
      
   END

Quit:

END

GO