SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1829ExtValid04                                        */
/* Purpose: Validate ASN & UCC scanned in                                     */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2018-Jan-05 1.0  James    WMS8010 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1829ExtValid04] (
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
            SET @nErrNo = 135051
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
            SET @nErrNo = 135052
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ASN
            GOTO Quit
         END
      END
   END

   Quit:



GO