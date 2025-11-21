SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_898ExtVal03                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2019-05-02 1.0  James   Created                                      */
/* 2019-06-07 1.1  James   WMS9283-Change check PO Type from Codelkup   */
/*                         (james01)                                    */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_898ExtVal03]
    @nMobile     INT
   ,@nFunc       INT
   ,@cLangCode   NVARCHAR(  3)
   ,@nStep       INT
   ,@nInputKey   INT
   ,@cReceiptKey NVARCHAR( 10)
   ,@cPOKey      NVARCHAR( 10)
   ,@cLOC        NVARCHAR( 10)
   ,@cToID       NVARCHAR( 18)
   ,@cLottable01 NVARCHAR( 18)
   ,@cLottable02 NVARCHAR( 18)
   ,@cLottable03 NVARCHAR( 18)
   ,@dLottable04 DATETIME
   ,@cUCC        NVARCHAR( 20)
   ,@cSKU        NVARCHAR( 20)
   ,@nQTY        INT
   ,@cParam1     NVARCHAR( 20) OUTPUT
   ,@cParam2     NVARCHAR( 20) OUTPUT
   ,@cParam3     NVARCHAR( 20) OUTPUT
   ,@cParam4     NVARCHAR( 20) OUTPUT
   ,@cParam5     NVARCHAR( 20) OUTPUT
   ,@cOption     NVARCHAR( 1)
   ,@nErrNo      INT       OUTPUT
   ,@cErrMsg     NVARCHAR( 20) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPOType     NVARCHAR( 10)
          ,@cPOSource   NVARCHAR( 2)
          ,@cStorerKey  NVARCHAR( 15)

   SELECT @cStorerKey = StorerKey,
          @nStep = @nStep,
          @nInputKey = @nInputKey
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile 

   
   IF @nStep = 1  -- ASN
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         CREATE TABLE #POTYPENIKE (  
            RowRef               INT IDENTITY(1,1) NOT NULL,  
            ExternPOKeyPrefix    NVARCHAR(10)  NULL,
            POType               NVARCHAR( 10) NULL,
            [Type]               NVARCHAR( 10) NULL)
  
         INSERT INTO #POTYPENIKE (ExternPOKeyPrefix, POType, [Type]) 
         SELECT DISTINCT Code, Code2, Short
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = 'NIKEPOTYPE'
         AND   StorerKey = @cStorerKey

         SELECT TOP 1 
                @cPOKey = POKey,
                @cPOSource = SUBSTRING( ExternReceiptKey, 1, 2)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey

         IF NOT EXISTS ( SELECT 1 FROM #POTYPENIKE WHERE ExternPOKeyPrefix = @cPOSource)
         --IF @cPOSource NOT IN ('35', '80')
         BEGIN
            SET @nErrNo = 138101
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid POType
            GOTO Quit
         END

         SELECT @cPOType = POType
         FROM dbo.PO WITH (NOLOCK)
         WHERE POKey = @cPOKey

         -- Transfer type PO
         IF NOT EXISTS ( SELECT 1 FROM #POTYPENIKE WHERE ExternPOKeyPrefix = @cPOSource AND [Type] = 'UCCNum')
         --IF ( @cPOSource = '35' AND @cPOType = 'Z030') OR ( @cPOSource = '80')
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                        WHERE ReceiptKey = @cReceiptKey
                        AND   LOTTABLE10 LIKE '000%')
                        --AND   BeforeReceivedQty = 0)
            BEGIN
               SET @nErrNo = 138102
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L10 need blank
               GOTO Quit
            END
         END
      END
   END
   
   IF @nStep = 3  -- ID
   BEGIN
      IF @nInputKey = 1
      BEGIN
         -- Check any SKU with different LOTTABLE value within this ASn
         -- To prevent 1 ucc HAVING multiple lot after received
         IF EXISTS ( SELECT 1 FROM (
         --SKU, COUNT( 1) FROM (
         SELECT SKU, LOTTABLE01, LOTTABLE02, LOTTABLE03, LOTTABLE04, LOTTABLE06, LOTTABLE07, LOTTABLE08, 
         LOTTABLE09, LOTTABLE11, LOTTABLE12, LOTTABLE13, LOTTABLE14, LOTTABLE15, COUNT(1) AS DUPLICATE
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey =  @cReceiptKey
         AND   StorerKey = @cStorerKey
         AND   BeforeReceivedQty = 0
         GROUP BY SKU, LOTTABLE01, LOTTABLE02, LOTTABLE03, LOTTABLE04, LOTTABLE06, LOTTABLE07, LOTTABLE08, 
                  LOTTABLE09, LOTTABLE11, LOTTABLE12, LOTTABLE13, LOTTABLE14, LOTTABLE15
         HAVING COUNT( 1) > 1) A
         GROUP BY SKU
         HAVING COUNT( 1) > 1)
         BEGIN
            SET @nErrNo = 138103
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN MULTI LOTS
            GOTO Quit
         END
      END
   END

Quit:

END

GO