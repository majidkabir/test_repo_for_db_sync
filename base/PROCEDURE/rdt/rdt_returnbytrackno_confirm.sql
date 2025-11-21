SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_ReturnByTrackNo_Confirm                         */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Print GS1 label                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author    Purposes                                   */
/* 2012-03-15 1.0  Ung       SOS235637 Created                          */
/* 2012-05-18 1.1  Ung       SOS244875 Add factory code and LOT         */
/*                           Storer config ReturnByTrackNoSkipCheckColor*/
/************************************************************************/

CREATE PROC [RDT].[rdt_ReturnByTrackNo_Confirm] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @cUserName    NVARCHAR( 18), 
   @cStorerKey   NVARCHAR( 15), 
   @cFacility    NVARCHAR( 5),
   @cTrackingNo  NVARCHAR( 20), 
   @cRECType     NVARCHAR( 10), 
   @cReceiptKey  NVARCHAR( 10), 
   @cLOC         NVARCHAR( 10), 
   @cSKU         NVARCHAR( 20), 
   @cExchgSKU    NVARCHAR( 20), 
   @cCondition   NVARCHAR( 10), 
   @cReason      NVARCHAR( 10),
   @cFactoryCode NVARCHAR( 10),
   @cFactoryLOT  NVARCHAR( 10),
   @cExternReceiptKey NVARCHAR( 20), 
   @cExternLineNo     NVARCHAR( 20), 
   @nErrNo      INT  OUTPUT,
   @cErrMsg     NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @cUOM      NVARCHAR( 10) 
DECLARE @cPackKey  NVARCHAR( 10)
DECLARE @cReceiptLineNumber NVARCHAR( 5)

-- Get return SKU info
SELECT 
   @cUOM = PackUOM3, 
   @cPackKey = Pack.PackKey
FROM dbo.SKU WITH (NOLOCK)
   INNER JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
WHERE StorerKey = @cStorerKey
   AND SKU = @cSKU 

-- Get max ReceiptLineNumber
SELECT @cReceiptLineNumber = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( ReceiptLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
FROM dbo.ReceiptDetail (NOLOCK)
WHERE ReceiptKey = @cReceiptKey

-- Insert ReceiptDetail
IF @cRECType = 'RETURN'
   INSERT INTO dbo.ReceiptDetail 
      (ReceiptKey, ReceiptLineNumber, StorerKey, SKU, UOM, PackKey, ToLOC, BeforeReceivedQTY, ConditionCode, SubReasonCode, ExternReceiptKey, ExternLineNo, 
      UserDefine05, UserDefine08, UserDefine09, UserDefine10)
   VALUES 
      (@cReceiptKey, @cReceiptLineNumber, @cStorerKey, @cSKU, @cUOM, @cPackKey, @cLOC, 1, @cCondition, @cReason, @cExternReceiptKey, @cExternLineNo, 
      @cTrackingNo, @cRECType, @cFactoryCode, @cFactoryLOT)
ELSE
BEGIN
   DECLARE @cStyle NVARCHAR( 20) 
   DECLARE @cColor NVARCHAR( 10) 
   DECLARE @cSize  NVARCHAR( 5) 

   -- Get Exchange SKU info
   SELECT 
      @cStyle = Style, 
      @cColor = Color, 
      @cSize = Size
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND SKU = @cExchgSKU 
   
   INSERT INTO dbo.ReceiptDetail 
      (ReceiptKey, ReceiptLineNumber, StorerKey, SKU, UOM, PackKey, ToLOC, BeforeReceivedQTY, ConditionCode, SubReasonCode, ExternReceiptKey, ExternLineNo, 
      UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, UserDefine08, UserDefine09, UserDefine10)
   VALUES (@cReceiptKey, @cReceiptLineNumber, @cStorerKey, @cSKU, @cUOM, @cPackKey, @cLOC, 1, @cCondition, @cReason, @cExternReceiptKey, @cExternLineNo, 
      @cStyle, @cColor, @cSize, '1', @cTrackingNo, @cRECType, @cFactoryCode, @cFactoryLOT)
END

IF @@ERROR <> 0
BEGIN
   SET @nErrNo = 76201
   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsRcptdtlFail
   GOTO Quit
END

-- EventLog
EXEC RDT.rdt_STD_EventLog
   @cActionType   = '2', -- Receiving
   @cUserID       = @cUserName,
   @nMobileNo     = @nMobile,
   @nFunctionID   = @nFunc,
   @cFacility     = @cFacility,
   @cStorerKey    = @cStorerKey,
   @cLocation     = @cLOC,
   @cSKU          = @cSKU,
   @cUOM          = @cUOM,
   @nQTY          = 1,
   @cRefNo1       = @cReceiptKey

Quit:

GO