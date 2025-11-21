SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1829ExtValid01                                        */
/* Purpose: Validate Pallet DropID                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2017-Jul-19 1.0  James    WMS2289 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1829ExtValid01] (
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

   DECLARE @cReceiptGroup       NVARCHAR( 20)

   SET @nErrNo = 0
   SET @cReceiptGroup = @cParam1
   
   IF @nStep = 1 -- Search Criteria
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF ISNULL( @cReceiptGroup, '') = '' 
         BEGIN
            SET @nErrNo = 112451
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need RecGrp
            GOTO Quit
         END 

         IF NOT EXISTS ( 
               SELECT 1 
               FROM dbo.Receipt WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   ReceiptGroup = @cReceiptGroup
               AND   [Status] < '9' 
               AND   ASNStatus <> 'CANC')
         BEGIN
            SET @nErrNo = 112452
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RecGrp
            GOTO Quit
         END

         IF NOT EXISTS ( 
            SELECT 1 
            FROM dbo.ReceiptDetail RD WITH (NOLOCK)
            JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
            WHERE R.StorerKey = @cStorerKey
            AND   R.ReceiptGroup = @cReceiptGroup
            AND   R.Status < '9' 
            AND   R.ASNStatus <> 'CANC'
            AND   NOT EXISTS ( SELECT 1 FROM RDT.rdtPreReceiveSort2Log RL WITH (NOLOCK)
                              WHERE RL.UCCNo = RD.UserDefine01
                              AND   RL.UDF01 = R.ReceiptGroup
                              AND   RL.StorerKey = R.StorerKey
                              AND   RL.Facility = R.Facility))
         BEGIN
            SET @nErrNo = 112453
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RecGrp Sorted
            GOTO Quit
         END
      END
   END

   IF @nStep = 2 -- UCC
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail RD WITH (NOLOCK)
                      JOIN dbo.Receipt R WITH (NOLOCK) ON RD.ReceiptKey = R.ReceiptKey
                      WHERE R.StorerKey = @cStorerKey
                      AND   R.ReceiptGroup = @cReceiptGroup
                      AND   R.Status < '9' 
                      AND   R.ASNStatus <> 'CANC'
                      AND   RD.UserDefine01 = @cUCCNo)
      BEGIN
         SET @nErrNo = 112454
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Not Exists
         GOTO Quit
      END

      IF EXISTS ( SELECT 1 FROM RDT.rdtPreReceiveSort2Log WITH (NOLOCK)
                  WHERE UCCNo = @cUCCNo
                  AND   UDF01 = @cReceiptGroup
                  AND   StorerKey = @cStorerKey)
      BEGIN
         SET @nErrNo = 112455
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Scanned
         GOTO Quit
      END
   END

   IF @nStep = 4 -- End pre sorting
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM RDT.rdtPreReceiveSort2Log WITH (NOLOCK)
                      WHERE UDF01 = @cReceiptGroup
                      AND   StorerKey = @cStorerKey
                      AND   [Status] = '0')
      BEGIN
         SET @nErrNo = 112456
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Nothing 2 end
         GOTO Quit         
      END
   END

   Quit:



GO