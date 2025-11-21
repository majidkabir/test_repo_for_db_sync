SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_1825ExtVal01                                    */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 03-Jan-2018 1.0  James       WMS7488. Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1825ExtVal01] (  
   @nMobile          INT,  
   @nFunc            INT,  
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT,  
   @nAfterStep       INT,
   @nInputKey        INT,  
   @cFacility        NVARCHAR( 5),  
   @cStorerKey       NVARCHAR( 15),  
   @tVar             VariableTable READONLY,
   @nErrNo           INT            OUTPUT,  
   @cErrMsg          NVARCHAR( 20)  OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @cReceiptKey       NVARCHAR( 10)
   DECLARE @cUCC_ReceiptKey   NVARCHAR( 10)
   DECLARE @cUCC              NVARCHAR( 20)

   -- Variable mapping
   SELECT @cReceiptKey = ISNULL( Value, '') FROM @tVar WHERE Variable = '@cReceiptKey'
   SELECT @cUCC = ISNULL( Value, '') FROM @tVar WHERE Variable = '@cUCC'

   IF @nStep = 2 -- UCC
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SET @nErrNo = 0
         /*
         SELECT TOP 1 @cUCC_ReceiptKey = ReceiptKey
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCC
         ORDER BY 1

         IF ISNULL( @cUCC_ReceiptKey, '') = ''
         BEGIN
            SET @nErrNo = 133551
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')-- UCC NO ASN
            GOTO Quit
         END

         IF @cUCC_ReceiptKey <> @cReceiptKey
         BEGIN
            SET @nErrNo = 133552
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')-- UCC DIFF ASN
            GOTO Quit
         END
         */

         IF NOT EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                         WHERE ReceiptKey = @cReceiptKey
                         AND   UserDefine01 = @cUCC)
         BEGIN
            SET @nErrNo = 133551
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')-- UCC NO in ASN
            GOTO Quit
         END
      END   -- InputKey
   END   -- Step

   Quit:
END  

GO