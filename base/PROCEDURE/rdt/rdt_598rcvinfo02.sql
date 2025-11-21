SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*******************************************************************************/
/* Store procedure: rdt_598RcvInfo02                                           */
/* Copyright      : Maersk                                                     */
/*                                                                             */
/* Purpose: Get Receiving info for Baryy Callbaut                              */
/*                                                                             */
/* Date        Author     Ver.    Purposes                                     */
/* 2024-06-03  Bruce Ping 1.0     UWP-20196 Created                            */
/* 2025-01-08  Bruce Ping 1.1.0   UWP-28868                                    */
/*******************************************************************************/
  
CREATE     PROCEDURE [RDT].[rdt_598RcvInfo02]  
  
   @nMobile      INT,             
   @nFunc        INT,             
   @cLangCode    NVARCHAR( 3),    
   @nStep        INT,             
   @nInputKey    INT,             
   @cStorerKey   NVARCHAR( 15),   
   @cRefNo       NVARCHAR( 20),   
   @cColumnName  NVARCHAR( 20),   
   @cLOC         NVARCHAR( 10),   
   @cID          NVARCHAR( 18)   OUTPUT,   
   @cSKU         NVARCHAR( 20)   OUTPUT,   
   @nQTY         INT             OUTPUT,   
   @cLottable01  NVARCHAR( 18)   OUTPUT,   
   @cLottable02  NVARCHAR( 18)   OUTPUT,   
   @cLottable03  NVARCHAR( 18)   OUTPUT,   
   @dLottable04  DATETIME        OUTPUT,   
   @dLottable05  DATETIME        OUTPUT,   
   @cLottable06  NVARCHAR( 30)   OUTPUT,   
   @cLottable07  NVARCHAR( 30)   OUTPUT,   
   @cLottable08  NVARCHAR( 30)   OUTPUT,   
   @cLottable09  NVARCHAR( 30)   OUTPUT,   
   @cLottable10  NVARCHAR( 30)   OUTPUT,   
   @cLottable11  NVARCHAR( 30)   OUTPUT,   
   @cLottable12  NVARCHAR( 30)   OUTPUT,   
   @dLottable13  DATETIME        OUTPUT,   
   @dLottable14  DATETIME        OUTPUT,   
   @dLottable15  DATETIME        OUTPUT,   
   @nErrNo       INT             OUTPUT,   
   @cErrMsg      NVARCHAR( 20)   OUTPUT    
AS
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  


   DECLARE @cTareWeight FLOAT
   DECLARE @cExternReceiptKey NVARCHAR(50)
   DECLARE @cReceiptKey NVARCHAR(10)
   DECLARE @nCnt  INT
  
   IF @nFunc = 598
   BEGIN
      IF @nStep = 4  
      BEGIN  
         SELECT TOP 1
            @cLottable01 = Lottable01,
            @cLottable02 = Lottable02,
            @cLottable03 = Lottable03,
            @dLottable04 = Lottable04,
            @dLottable05 = Lottable05,
            @cLottable06 = Lottable06,
            @cLottable07 = Lottable07,
            @cLottable08 = Lottable08,
            @cLottable09 = Lottable09,
            @cLottable10 = Lottable10,
            @cLottable11 = Lottable11,
            @cLottable12 = Lottable12,
            @dLottable13 = Lottable13,
            @dLottable14 = Lottable14,
            @dLottable15 = Lottable15,
            @cTareWeight = sku.TareWeight,
            @cExternReceiptKey = rpt.ExternReceiptKey,
            @cReceiptKey = rpt.ReceiptKey
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
            JOIN rdt.rdtConReceiveLog CRL WITH (NOLOCK) ON (RD.ReceiptKey = CRL.ReceiptKey)
            JOIN dbo.RECEIPT rpt WITH(NOLOCK) ON RD.ReceiptKey = rpt.ReceiptKey
            JOIN dbo.SKU sku WITH(NOLOCK) ON RD.Sku = sku.Sku AND RD.storerkey = sku.storerkey
         WHERE CRL.Mobile = @nMobile
            AND RD.SKU = @cSKU
         ORDER BY
            CASE WHEN @cID = ToID THEN 0 ELSE 1 END,
            CASE WHEN QTYExpected > 0 AND QTYExpected > BeforeReceivedQTY THEN 0 ELSE 1 END,
            ReceiptLineNumber



         SELECT @cLottable02 = @cExternReceiptKey
         SELECT @cLottable06 = ''
         SELECT @cLottable08 = '0'
         SELECT @cLottable09 = '0'
         SELECT @cLottable10 = @cTareWeight
         SELECT @cLottable11 = 'QI'

         SELECT TOP 1 @cLottable07 = P.GrossWgt
         FROM dbo.PALLET P WITH (NOLOCK)
         WHERE PalletKey = @cID
            AND StorerKey = @cStorerKey

      END -- End step 4
   END -- End 598
  
END -- End Procedure


GO