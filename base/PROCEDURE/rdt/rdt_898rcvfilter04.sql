SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/******************************************************************************/
/* Store procedure: rdt_898RcvFilter04                                        */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: filter by ExternKey, POKey, POLineNumber                          */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 10-12-2021  1.0  Ung         WMS-18390 Created base on rdtNIKTWUCCRcvFilter*/
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_898RcvFilter04]
    @nMobile     INT
   ,@nFunc       INT
   ,@cLangCode   NVARCHAR(  3)
   ,@cReceiptKey NVARCHAR( 10)
   ,@cPOKey      NVARCHAR( 10)
   ,@cToLOC      NVARCHAR( 10)
   ,@cToID       NVARCHAR( 18)
   ,@cLottable01 NVARCHAR( 18)
   ,@cLottable02 NVARCHAR( 18)
   ,@cLottable03 NVARCHAR( 18)
   ,@dLottable04 DATETIME
   ,@cSKU        NVARCHAR( 20)
   ,@cUCC        NVARCHAR( 20)
   ,@nQTY        INT
   ,@cCustomSQL  NVARCHAR( MAX) OUTPUT
   ,@nErrNo      INT            OUTPUT
   ,@cErrMsg     NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cStorerKey    NVARCHAR( 15)
   DECLARE @cPOLineNumber NVARCHAR( 5)
   DECLARE @cFilterCode   NVARCHAR( 5)
   DECLARE @cExternKey    NVARCHAR( 20)
   DECLARE @cUserDefine03 NVARCHAR( 20)
   DECLARE @cSourceKey    NVARCHAR( 20)

   -- Get session info
   SELECT
      @cStorerKey = StorerKey,
      @cUCC = V_UCC                 -- Parent is custom confirm SP, not pass-in UCC and receive by loose, but UCC needed in below
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Get UCC info
   SET @cExternKey = ''
   SET @cPOKey     = ''
   SET @cPOLineNumber = ''
   SELECT TOP 1
       @cExternKey    = ExternKey
      ,@cUserDefine03 = SUBSTRING( UserDefined03, 1, 10)
      ,@cPOKey        = SUBSTRING( UCC.Sourcekey, 1, 10)
      ,@cPOLineNumber = SUBSTRING( UCC.Sourcekey, 11, 5)
   FROM dbo.UCC WITH (NOLOCK)
   WHERE UCCNo = @cUCC
      AND StorerKey = @cStorerKey
      AND SKU = @cSKU
      AND Status = '0'
   ORDER BY UCC_RowRef

   SELECT @cFilterCode = Code
   FROM dbo.Codelkup WITH (NOLOCK)
   WHERE ListName = 'UCCFilter'
   AND StorerKey = ISNULL(RTRIM(@cStorerKey),'' )

   -- Build custom SQL
   IF @cExternKey <> ''
   BEGIN
      IF ISNULL(RTRIM(@cFilterCode),'' ) = '1'
      BEGIN

         SET @cCustomSQL = @cCustomSQL +
         ' AND RTRIM( ExternReceiptKey) = ''' + RTRIM( @cExternKey) + '''' +
         ' AND RTRIM( PoKey) = ''' + RTRIM( @cPOKey) + '''' +
         ' AND RTRIM( POLineNumber) = ''' + RTRIM( @cPOLineNumber) + ''''
      END
      ELSE IF ISNULL(RTRIM(@cFilterCode),'' ) = '2'
      BEGIN

         SET @cCustomSQL = @cCustomSQL +
            ' AND RTRIM( ExternReceiptKey) = ''' + RTRIM( @cExternKey) + '''' +
            ' AND RTRIM( UserDefine03) = ''' + RTRIM( @cUserDefine03) + '''' +
            ' AND RTRIM( PoKey) = ''' + RTRIM( @cPOKey) + ''''
      END
   END
END

GO