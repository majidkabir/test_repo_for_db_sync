SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_600ExtVal10                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: CHARGEURS															      */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-03-17 1.0  yeekung   WMS-19197 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_600ExtVal10] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5), 
   @cStorerKey   NVARCHAR( 15), 
   @cReceiptKey  NVARCHAR( 10), 
   @cPOKey       NVARCHAR( 10), 
   @cLOC         NVARCHAR( 10), 
   @cID          NVARCHAR( 18), 
   @cSKU         NVARCHAR( 20), 
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
   @nQTY         INT,           
   @cReasonCode  NVARCHAR( 10), 
   @cSuggToLOC   NVARCHAR( 10), 
   @cFinalLOC    NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 10), 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPackKey NVARCHAR(10) 
          ,@nPallet  INT

   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 4 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF EXISTS (SELECT 1  FROM
                        RECEIPTDETAIL (NOLOCK)
                        WHERE Receiptkey=@cReceiptKey
                        AND TOID= @cID
                        AND storerkey=@cStorerKey)
            BEGIN
               IF EXISTS (SELECT 1  FROM
                           RECEIPTDETAIL (NOLOCK)
                           WHERE Receiptkey=@cReceiptKey
                           AND sku<>@csku
                           AND TOID= @cID
                           AND storerkey=@cStorerKey)
               BEGIN
                  SET @nErrNo = 184351   
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID in USE  
                  GOTO QUIT 
               END
            END
         END   
      END      
   END         

   Quit:


GO