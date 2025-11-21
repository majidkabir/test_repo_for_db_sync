SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1829ExtValid02                                        */
/* Purpose: Validate ASN & UCC scanned in                                     */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2018-Jan-05 1.0  James    WMS3653 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1829ExtValid02] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR(3),
   @nStep        INT,
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR(15),
   @cParam1      NVARCHAR(20),
   @cParam2      NVARCHAR(20),
   @cParam3      NVARCHAR(20),
   @cParam4      NVARCHAR(20),
   @cParam5      NVARCHAR(20),
   @cUCCNo       NVARCHAR(20),
   @nErrNo       INT          OUTPUT,
   @cErrMsg      NVARCHAR(20) OUTPUT
)
AS

   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cReceiptKey    NVARCHAR( 10)
   DECLARE @cUCC_SKU       NVARCHAR( 20)
   DECLARE @nSafe_Level    INT

   SET @nErrNo = 0
   SET @cReceiptKey = @cParam1
   
   IF @nStep = 1 -- Search Criteria
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF ISNULL( @cReceiptKey, '') = '' 
         BEGIN
            SET @nErrNo = 118501
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ASN
            GOTO Quit
         END 

         IF NOT EXISTS ( 
               SELECT 1 
               FROM dbo.Receipt WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   ReceiptKey = @cReceiptKey
               AND   [Status] < '9' 
               AND   ASNStatus <> 'CANC')
         BEGIN
            SET @nErrNo = 118502
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ASN
            GOTO Quit
         END
      END
   END

   IF @nStep = 2 -- UCC
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail RD WITH (NOLOCK)
                      WHERE RD.StorerKey = @cStorerKey
                      AND   RD.ReceiptKey = @cReceiptKey
                      AND   EXISTS ( SELECT 1 FROM dbo.PODETAIL PD WITH (NOLOCK)
                                     WHERE RD.POKey = PD.POKey
                                     AND   RD.POLineNumber = PD.POLineNumber
                                     AND   PD.UserDefine01 = @cUCCNo))
      BEGIN
         SET @nErrNo = 118503
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Not Exists
         GOTO Quit
      END
      
      DECLARE CUR_CHECKUCC CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT DISTINCT RD.SKU 
      FROM dbo.ReceiptDetail RD WITH (NOLOCK)
      WHERE RD.StorerKey = @cStorerKey
      AND   RD.ReceiptKey = @cReceiptKey
      AND   EXISTS ( SELECT 1 FROM dbo.PODETAIL PD WITH (NOLOCK)
                     WHERE RD.POKey = PD.POKey
                     AND   RD.POLineNumber = PD.POLineNumber
                     AND   PD.UserDefine01 = @cUCCNo)
      OPEN CUR_CHECKUCC
      FETCH NEXT FROM CUR_CHECKUCC INTO @cUCC_SKU
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- Get inventory safe level for this sku
         SET @nSafe_Level = 0
         SELECT @nSafe_Level = ISNULL( CAST( BUSR4 AS INT), 0)
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cUCC_SKU

         IF @nSafe_Level = 0
         BEGIN
            SET @nErrNo = 118504
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --X SAFETY STOCK
            CLOSE CUR_CHECKUCC
            DEALLOCATE CUR_CHECKUCC
            GOTO Quit
         END

         FETCH NEXT FROM CUR_CHECKUCC INTO @cUCC_SKU
      END
      CLOSE CUR_CHECKUCC
      DEALLOCATE CUR_CHECKUCC
   END

   Quit:



GO