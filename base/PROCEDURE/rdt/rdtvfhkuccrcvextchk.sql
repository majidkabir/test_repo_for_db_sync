SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtVFHKUCCRcvExtChk                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Check UCC.UDF03 exists in RD.UDF03+02                       */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 12-09-2012  1.0  Ung         SOS279908. Created                      */
/* 20-01-2016  1.1  Ung         SOS361679. Add ExternKey                */
/* 26-11-2021  1.2  James       WMS-18455 Check UCC.UDF03 has value only*/
/*                              check ReceiptDetail.UDF03 (james01)     */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdtVFHKUCCRcvExtChk]
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cReceiptKey  NVARCHAR( 10) 
   ,@cPOKey       NVARCHAR( 10) 
   ,@cLOC         NVARCHAR( 10) 
   ,@cToID        NVARCHAR( 18) 
   ,@cLottable01  NVARCHAR( 18) 
   ,@cLottable02  NVARCHAR( 18) 
   ,@cLottable03  NVARCHAR( 18) 
   ,@dLottable04  DATETIME  
   ,@cUCC         NVARCHAR( 20) 
   ,@nErrNo       INT           OUTPUT 
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cStorerKey  NVARCHAR( 15)
   DECLARE @cUCCUDF03   NVARCHAR( 20)
   DECLARE @cExterKey   NVARCHAR( 20)

   -- Get Receipt info
   SELECT @cStorerKey = StorerKey FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey

   -- Get UCC info
   SELECT 
      @cUCCUDF03 = UserDefined03, 
      @cExterKey = ExternKey
   FROM dbo.UCC WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
      AND UCCNo = @cUCC

   -- Check UCC format
   IF @@ROWCOUNT > 0
   BEGIN
      IF ISNULL( @cUCCUDF03, '') <> '' -- (james01)
      BEGIN
         -- Get ReceiptDetail info
         IF NOT EXISTS( SELECT TOP 1 1 
            FROM dbo.ReceiptDetail WITH (NOLOCK) 
            WHERE ReceiptKey = @cReceiptKey
               AND RTRIM( UserDefine03) + RTRIM( UserDefine02) = @cUCCUDF03)
         BEGIN
            SET @nErrNo = 81851
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UDF3 Not In RD
            GOTO Quit
         END
      END
      
      -- Check ExternKey in ASN
      IF @cExterKey <> ''
         IF NOT EXISTS( SELECT TOP 1 1 
            FROM dbo.ReceiptDetail WITH (NOLOCK) 
            WHERE ReceiptKey = @cReceiptKey
               AND ExternReceiptKey = @cExterKey)
         BEGIN
            SET @nErrNo = 81852
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ExtKey NotInRD
            GOTO Quit
         END
   END

QUIT:
END -- End Procedure


GO