SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtVFTWUCCRcvExtChk                                 */
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
/* 15-02-2016  1.1  Ung         SOS361679 Renumber error no             */
/* 27-02-2017  1.2  TLTING      variable Nvarchar                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtVFTWUCCRcvExtChk]
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
   DECLARE @cExternKey  NVARCHAR( 20)

   -- Get Receipt info
   SELECT @cStorerKey = StorerKey FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey

   -- Get UCC info
   SELECT @cExternKey = ExternKey
   FROM dbo.UCC WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
      AND UCCNo = @cUCC

   -- Check UCC format
   IF @@ROWCOUNT > 0
   BEGIN
      -- Get ReceiptDetail info
      IF NOT EXISTS( SELECT TOP 1 1 
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey
            AND RTRIM( ExternReceiptKey) = @cExternKey)
      BEGIN
         SET @nErrNo = 67801
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UDF3 Not In RD
         GOTO Quit
      END
   END

QUIT:
END -- End Procedure


GO