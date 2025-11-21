SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* Stored Procedure: rdt_600GetRecInfoSPVLT                               */
/*                                                                        */
/* Purpose: Setting pallet type same as latest received for this ASN      */
/*                                                                        */
/*                                                                        */
/* Updates:                                                               */
/* Date         Author   Ver.    Purposes                                 */
/* 18/10/2024   PPA374   1.0     Created                                  */
/* 31/10/2024   PPA374   1.1.0   UWP-26437 Added more lottables           */
/**************************************************************************/
CREATE   PROCEDURE [RDT].[rdt_600GetRecInfoSPVLT]  
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey       NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cID          NVARCHAR( 18)  OUTPUT,
   @cSKU         NVARCHAR( 20)  OUTPUT,
   @nQTY         INT            OUTPUT,
   @cLottable01  NVARCHAR( 18)  OUTPUT,
   @cLottable02  NVARCHAR( 18)  OUTPUT,
   @cLottable03  NVARCHAR( 18)  OUTPUT,
   @dLottable04  DATETIME       OUTPUT,
   @dLottable05  DATETIME       OUTPUT,
   @cLottable06  NVARCHAR( 30)  OUTPUT,
   @cLottable07  NVARCHAR( 30)  OUTPUT,
   @cLottable08  NVARCHAR( 30)  OUTPUT,
   @cLottable09  NVARCHAR( 30)  OUTPUT,
   @cLottable10  NVARCHAR( 30)  OUTPUT,
   @cLottable11  NVARCHAR( 30)  OUTPUT,
   @cLottable12  NVARCHAR( 30)  OUTPUT,
   @dLottable13  DATETIME       OUTPUT,
   @dLottable14  DATETIME       OUTPUT,
   @dLottable15  DATETIME       OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT  
AS 
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   IF @nFunc = 600
   BEGIN
      IF @nStep = 4  
      --Setting lottable 2 to be same as latest lottable 2 for this ASN
      BEGIN  
         SET @cLottable02 = (SELECT TOP 1 Lottable02 FROM dbo.RECEIPTDETAIL rd WITH(NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND StorerKey = @cStorerKey
            AND DateReceived = (SELECT max(DateReceived) 
                                 FROM dbo.RECEIPTDETAIL rd2 WITH(NOLOCK) 
                                 WHERE rd.ReceiptKey = rd2.ReceiptKey 
                                    AND StorerKey = @cStorerKey))  
      
         SET @dLottable05 = ''
         SET @cLottable11 = ''
         SET @cLottable12 = ''
      END
   END
END -- End Procedure  

GO