SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1841PrePltSort05.sql                            */  
/* Purpose:  Set cPosition                                              */
/* Customer: For Amazon                                                 */
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2019-11-28 1.0.0  XLL045   FCR-1066 suggested position               */  
/************************************************************************/ 

CREATE   PROC rdt.rdt_1841PrePltSort05 ( 
   @nMobile         INT,      
   @nFunc           INT,      
   @cLangCode       NVARCHAR( 3),      
   @nStep           INT,      
   @nInputKey       INT,      
   @cStorerkey      NVARCHAR( 15),      
   @cFacility       NVARCHAR( 5),      
   @cReceiptKey     NVARCHAR( 20),      
   @cLane           NVARCHAR( 10),      
   @cUCC            NVARCHAR( 20),      
   @cSKU            NVARCHAR( 20),      
   @cType           NVARCHAR( 10),       
   @cCreateUCC      NVARCHAR( 1),             
   @cLottable01     NVARCHAR( 18),            
   @cLottable02     NVARCHAR( 18),            
   @cLottable03     NVARCHAR( 18),            
   @dLottable04     DATETIME,                 
   @dLottable05     DATETIME,                 
   @cLottable06     NVARCHAR( 30),            
   @cLottable07     NVARCHAR( 30),            
   @cLottable08     NVARCHAR( 30),            
   @cLottable09     NVARCHAR( 30),            
   @cLottable10     NVARCHAR( 30),            
   @cLottable11     NVARCHAR( 30),            
   @cLottable12     NVARCHAR( 30),            
   @dLottable13     DATETIME,                 
   @dLottable14     DATETIME,                 
   @dLottable15     DATETIME,                 
   @cPosition       NVARCHAR( 20)  OUTPUT,      
   @cToID           NVARCHAR( 18)  OUTPUT,      
   @cClosePallet    NVARCHAR( 1)   OUTPUT,      
   @nErrNo          INT            OUTPUT,      
   @cErrMsg         NVARCHAR( 20)  OUTPUT  
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   IF @nFunc = 1841
   BEGIN
      IF @nStep = 2
      BEGIN
         IF @nInputKey = 1 -- ENTER
        BEGIN      
            SELECT TOP 1 @cPosition = ISNULL(UserDefine02,'') FROM dbo.receiptdetail WITH(NOLOCK) WHERE ReceiptKey = @cReceiptKey AND UserDefine01 = @cUCC
         END
      END      
   END
   Quit:
 
END

GO