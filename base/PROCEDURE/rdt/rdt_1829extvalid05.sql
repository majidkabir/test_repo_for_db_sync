SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1829ExtValid05                                        */
/* Purpose: Validate ASN & UCC scanned in                                     */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2018-Feb-05 1.0  James    WMS3858 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1829ExtValid05] (
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

   DECLARE @bSuccess    INT
   DECLARE @cReceiptKey NVARCHAR( 10)
   DECLARE @cSKU        NVARCHAR( 20)

   SET @cReceiptKey = @cParam1
   SET @cSKU = @cUCCNo
   
   IF @nStep = 1 -- Search Criteria
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         DECLARE @cChkFacility  NVARCHAR(5)
         DECLARE @cChkStorerKey NVARCHAR(15)
         DECLARE @cASNStatus    NVARCHAR(10)
         
         -- Check blank
         IF @cReceiptKey = ''
         BEGIN
            SET @nErrNo = 126301
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ASN
            GOTO Quit
         END

         -- Get ASN info
         SELECT 
            @cChkFacility = Facility, 
            @cChkStorerKey = StorerKey, 
            @cASNStatus = ASNStatus
         FROM Receipt WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         
         -- Check ASN valid
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 126302
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ASN
            GOTO Quit
         END
            
         -- Get session info
         DECLARE @cFacility NVARCHAR(5)
         SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

         -- Check facility
         IF @cFacility <> @cChkFacility
         BEGIN
            SET @nErrNo = 126303
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
            GOTO Quit
         END

         -- Validate ASN belong to the storer
         IF @cStorerKey <> @cChkStorerKey
         BEGIN
            SET @nErrNo = 126304
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
            GOTO Quit
         END

         -- Validate ASN status
         IF @cASNStatus = '9'
         BEGIN
            SET @nErrNo = 126305
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN is closed
            GOTO Quit
         END

         -- Check ASN cancelled
         IF @cASNStatus = 'CANC'
         BEGIN
            SET @nErrNo = 126306
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN cancelled
            GOTO Quit
         END
      END
   END

Quit:


GO