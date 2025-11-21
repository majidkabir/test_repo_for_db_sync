SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtUCCRcvExtCheck01                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Check UCC base on sourcekey                                 */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 24-02-2014  1.0  ChewKP      SOS#292682. Created                     */
/* 16-Dec-2018 1.1  TLTING01    Missing NOLOCK                          */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtUCCRcvExtCheck01]
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
   ,@nErrNo       INT       OUTPUT
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nSKUCnt_UCC INT
   DECLARE @nSKUCnt_ID  INT
   DECLARE @cUCCSKU     NVARCHAR( 20)
   DECLARE @nUCCQTY     INT
   DECLARE @cIDSKU      NVARCHAR( 20)
   DECLARE @nIDQTY      INT
   DECLARE @cIDL02      NVARCHAR( 18)

-- Get Receipt info
   DECLARE @cStorerKey         NVARCHAR(15)
         , @cReceiptLineNumber NVARCHAR(5)
         , @cSourceType        NVARCHAR(20)
         , @cPOLineNumber      NVARCHAR(5)
         , @cUCCReceiptKey     NVARCHAR(10)
         , @cUCCPOKey          NVARCHAR(10)
         , @cDocType           NVARCHAR(1)
         , @b_success          INT

   SET @cSourceType = ''
   SET @cStorerKey  = ''
   SET @cDocType = ''

   -- Get Receipt info
   SELECT
      @cStorerKey = StorerKey,
      @cDocType = DocType
   FROM dbo.Receipt WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey

   SELECT @cSourceType = SourceType   
   FROM dbo.UCC WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND UCCNo = @cUCC

   IF @cSourceType = 'ASN'
   BEGIN
      -- Get UCC info
      SET @cUCCReceiptKey = ''

      SET @cReceiptLineNumber = ''
      SELECT @cUCCReceiptKey = SubString(UCC.Sourcekey, 1, 10)
      FROM dbo.UCC WITH (NOLOCK)
      WHERE UCCNo = @cUCC
      AND StorerKey = @cStorerKey

      -- Build custom SQL
      IF ISNULL(RTRIM(@cUCCReceiptKey),'')  <> ISNULL(RTRIM(@cReceiptKey),'')
      BEGIN
        SET @nErrNo = 85301
        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCASNNotMatch
        GOTO Quit
      END
   END

   ELSE IF @cSourceType = 'PO'
   BEGIN
      SET @cPOLineNumber = ''
      SET @cPOKey        = ''
      SET @cUCCPOKey     = ''

      SELECT  @cUCCPOKey        = SubString(UCC.Sourcekey, 1, 10)
      FROM dbo.UCC WITH (NOLOCK)
      WHERE UCCNo = @cUCC
      AND StorerKey = @cStorerKey


      --tlting01
      IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail (NOLOCK) WHERE Receiptkey = @cReceiptKey and POKey = @cUCCPOKey )
      BEGIN
        SET @nErrNo = 85302
        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCPONotMatch
        GOTO Quit
      END
   END

   -- Insert interface ADDCTNLOG
   EXEC dbo.ispGenTransmitLog3 'ADDCTNLOG', @cReceiptKey, @cDocType, @cStorerKey, ''
      , @b_success OUTPUT
      , @nErrNo    OUTPUT
      , @cErrMsg   OUTPUT
   IF @b_success <> 1
   BEGIN
      SET @nErrNo = 85303
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins TLog3 Fail
      GOTO Quit
   END

QUIT:
END -- End Procedure


GO