SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1829ExtValid03                                        */
/* Purpose: Validate ASN & UCC scanned in                                     */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2018-Feb-05 1.0  James    WMS3858 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1829ExtValid03] (
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
   DECLARE @cContainerKey  NVARCHAR( 18)
   DECLARE @cStatus        NVARCHAR( 10)
   DECLARE @cExternReceiptKey NVARCHAR( 20)

   SET @nErrNo = 0
   SET @cStatus = ''

   SET @cReceiptKey = @cParam1
   SET @cContainerKey = @cParam2
   
   IF @nStep = 1 -- Search Criteria
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF ISNULL( @cParam1, '') <> '' 
         BEGIN
            SELECT @cStatus = [Status]
            FROM dbo.Receipt WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   ReceiptKey = @cParam1
            AND   ASNStatus <> 'CANC'

            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 119501
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ASN
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- ASN
               GOTO Quit
            END 

            IF ISNULL( @cStatus, '') = '9'
            BEGIN
               SET @nErrNo = 119502
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ASN
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- ASN
               GOTO Quit
            END 
         END

         IF ISNULL( @cParam2, '') <> '' 
         BEGIN
            SELECT TOP 1 @cStatus = [Status]
            FROM dbo.Receipt WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   ContainerKey = @cParam2
            AND   ASNStatus <> 'CANC'
            ORDER BY 1 DESC   -- Status 9 come first

            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 119503
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Cont ID
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- ASN
               GOTO Quit
            END 

            IF ISNULL( @cStatus, '') = '9'
            BEGIN
               SET @nErrNo = 119504
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN Finalized
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- ASN
               GOTO Quit
            END 
         END

         IF ISNULL( @cParam1, '') = '' AND ISNULL( @cParam2, '') = ''
         BEGIN
            SET @nErrNo = 119508
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Value Needed
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ASN
            GOTO Quit
         END 
      END
   END

   IF @nStep = 2 -- UCC
   BEGIN
      IF ISNULL( @cReceiptKey, '') <> ''
      BEGIN
         SELECT @cExternReceiptKey = ExternReceiptKey
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   [Status] < '9'
         AND   ASNStatus <> 'CANC'

         SELECT @cStatus = [Status] 
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCCNo
         AND   ExternKey = @cExternReceiptKey
         AND   [Status] = '0'
      END
      ELSE
         SELECT @cStatus = [Status] 
         FROM dbo.UCC UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCCNo
         AND   [Status] = '0'
         AND   EXISTS ( SELECT 1 FROM dbo.Receipt R WITH (NOLOCK)
                        WHERE UCC.StorerKey = R.StorerKey
                        AND   UCC.ExternKey = R.ExternReceiptKey
                        AND   SUBSTRING( UCC.SourceKey, 1, 10) = R.ReceiptKey
                        AND   R.ContainerKey = @cContainerKey
                        AND   R.Status < '9'
                        AND   R.ASNStatus <> 'CANC')

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 119505
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Not Exists
         GOTO Quit
      END

      IF @cStatus = '1'
      BEGIN
         SET @nErrNo = 119506
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Received
         GOTO Quit
      END

      IF @cStatus = '6'
      BEGIN
         SET @nErrNo = 119507
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC NotInUse
         GOTO Quit
      END
   END

   Quit:



GO