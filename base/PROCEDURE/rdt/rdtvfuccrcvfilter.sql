SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************************/
/* Store procedure: rdtVFUCCRcvFilter                                                              */
/* Copyright      : Maersk                                                                         */
/*                                                                                                 */
/* Purpose: Link ReceiptDetail with UCC                                                            */
/*                                                                                                 */
/* Modifications log:                                                                              */
/*                                                                                                 */
/* Date        Rev  Author      Purposes                                                           */
/* 12-09-2012  1.0  Ung         SOS255639 Created                                                  */
/* 26-02-2014  1.1  Ung         SOS303821 Add ExternReceiptKey                                     */ 
/* 22-08-2023  1.2  Ung         WMS-23484 Support multi SKU UCC, same SKU multiple records         */
/***************************************************************************************************/

CREATE   PROCEDURE [RDT].[rdtVFUCCRcvFilter]
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
   
   DECLARE @cUserDefined03 NVARCHAR(20)
   DECLARE @cExterKey      NVARCHAR(20)
   DECLARE @cStorerKey     NVARCHAR(15)

   -- Get Receipt info
   SELECT @cStorerKey = StorerKey FROM dbo.Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey
   
   -- Get UCC info
   SET @cUserDefined03 = ''
   SET @cExterKey = ''
   SELECT TOP 1 
      @cUserDefined03 = UserDefined03, 
      @cExterKey = ExternKey
   FROM dbo.UCC WITH (NOLOCK) 
   WHERE UCCNo = @cUCC 
      AND StorerKey = @cStorerKey 
      AND SKU = @cSKU
      AND Status = '0'
   ORDER BY UCC_RowRef

   -- Build custom SQL
   IF @cExterKey <> ''
      SET @cCustomSQL = @cCustomSQL + ' AND ExternReceiptKey = ''' + RTRIM( @cExterKey) + '''' 
   IF @cUserDefined03 <> ''
      SET @cCustomSQL = @cCustomSQL + 
         ' AND (RTRIM( UserDefine03) + RTRIM( UserDefine02) = ''' + RTRIM( @cUserDefined03) + '''' + 
         '   OR RTRIM( UserDefine03) = ''' + RTRIM( @cUserDefined03) + ''')'

QUIT:
END -- End Procedure

GO