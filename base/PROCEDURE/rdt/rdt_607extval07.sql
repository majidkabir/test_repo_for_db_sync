SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*******************************************************************************/
/* Store procedure: rdt_607ExtVal07                                            */
/* Copyright      : MWMS                                                       */
/* Customer       : Granite                                                    */
/*                                                                             */
/* Purpose: Validate Over Receive and Validate ASN Cancel Date PASSED          */
/*                                                                             */
/* Date          Author    Ver.     Purposes                                   */
/* 2024-10-30    SK        1.0.0    UWP-26373 Created                          */
/*******************************************************************************/
CREATE   PROCEDURE [RDT].[rdt_607ExtVal07]
   @nMobile             INT,           
   @nFunc               INT,           
   @cLangCode           NVARCHAR( 3),  
   @nStep               INT,           
   @nAfterStep          INT,            
   @nInputKey           INT,           
   @cFacility           NVARCHAR( 5),   
   @cStorerKey          NVARCHAR( 15), 
   @cReceiptKey         NVARCHAR( 10), 
   @cPOKey              NVARCHAR( 10), 
   @cRefNo              NVARCHAR( 20), 
   @cSKU                NVARCHAR( 20), 
   @nQTY                INT,           
   @cLottable01         NVARCHAR( 18), 
   @cLottable02         NVARCHAR( 18), 
   @cLottable03         NVARCHAR( 18), 
   @dLottable04         DATETIME,      
   @dLottable05         DATETIME,      
   @cLottable06         NVARCHAR( 30), 
   @cLottable07         NVARCHAR( 30),
   @cLottable08         NVARCHAR( 30),
   @cLottable09         NVARCHAR( 30),
   @cLottable10         NVARCHAR( 30),
   @cLottable11         NVARCHAR( 30),
   @cLottable12         NVARCHAR( 30),
   @dLottable13         DATETIME,
   @dLottable14         DATETIME,
   @dLottable15         DATETIME, 
   @cReasonCode         NVARCHAR( 5), 
   @cSuggID             NVARCHAR( 18), 
   @cSuggLOC            NVARCHAR( 10), 
   @cID                 NVARCHAR( 18), 
   @cLOC                NVARCHAR( 10), 
   @cReceiptLineNumber    NVARCHAR( 5), 
   @nErrNo              INT           OUTPUT, 
   @cErrMsg             NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   IF @nFunc = 607 -- Return V7
   BEGIN  

      IF @nStep = 1 -- ASN, PO
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- VARIABLE
            DECLARE @cCancelFlg NVARCHAR(1)
         
            SET @cCancelFlg = 'N'
            
            SELECT 
               @cCancelFlg = CASE WHEN Userdefine06 < getdate() THEN 'Y' ELSE 'N' END    
            FROM dbo.Receipt (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey

            -- ASN CANCELLATION DATE PASSED 
            IF (@cCancelFlg) = 'Y'
            BEGIN  
               SET @nErrNo = 228101
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cancel Date Passed
               GOTO Quit  
            END
         END
      END
     
      IF @nStep = 3 -- QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check SKU QTY
            DECLARE @nExpQTY INT
            DECLARE @nRcvQTY INT
            SELECT 
               @nExpQTY = ISNULL( SUM( QTYExpected), 0), 
               @nRcvQTY = ISNULL( SUM( BeforeReceivedQTY), 0)
            FROM dbo.ReceiptDetail (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
               AND SKU = @cSKU
               
            -- Check over receive
            IF (@nRcvQTY + @nQTY) > @nExpQTY
            BEGIN  
               SET @nErrNo = 228102
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over receive
               GOTO Quit  
            END
         END
      END
   END
Quit:

END

GO