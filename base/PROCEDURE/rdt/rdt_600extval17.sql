SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_600ExtVal17                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Reject B2C type ASN           									   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-09-19 1.0  yeekung   WMS-23684 Created                          */
/************************************************************************/

CREATE   PROC [RDT].[rdt_600ExtVal17] (
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

   DECLARE @CUPC                NVARCHAR( 30) 
   
   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 4
      BEGIN
      	IF @nInputKey = 1
      	BEGIN
      		SELECT @cUPC = V_Max
      		FROM RDT.RDTMobrec WITH (NOLOCK)
      		WHERE Mobile = @nMobile
            
            IF EXISTS ( SELECT 1
                        FROM UPC (NOLOCK) 
                        WHERE UPC = @cUPC
                           AND Storerkey = @cStorerkey)
            BEGIN
               IF NOT EXISTS ( SELECT 1
                           FROM SKU (NOLOCK) 
                           WHERE ALTSKU = @cUPC
                              AND Storerkey = @cStorerkey)
               BEGIN
                  SET @nErrNo = 204651   
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidAltSKU  
                  GOTO Quit 
               END
            END
            ELSE
            BEGIN
               SET @nErrNo = 204652   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidUPC  
               GOTO Quit 
            END


      	END
      END
   END         

   Quit:


GO