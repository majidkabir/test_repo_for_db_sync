SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1580AutoGenID01                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Auto generate ID                                            */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2018-04-02  1.0  ChewKP    WMS-4126 Created                          */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580AutoGenID01]
  @nMobile     INT,           
  @nFunc       INT,           
  @nStep       INT,           
  @cLangCode   NVARCHAR( 3),  
  @cReceiptKey NVARCHAR( 10), 
  @cPOKey      NVARCHAR( 10), 
  @cLOC        NVARCHAR( 10), 
  @cID         NVARCHAR( 18), 
  @cOption     NVARCHAR( 1),  
  @cAutoID     NVARCHAR( 18) OUTPUT, 
  @nErrNo      INT           OUTPUT, 
  @cErrMsg     NVARCHAR( 20) OUTPUT

AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cExternReceiptKey NVARCHAR(20)
          ,@cStorerKey        NVARCHAR(15) 
          ,@cNCounter         NVARCHAR(3)
          ,@bSuccess          INT

   SET @cAutoID = ''
   SET @cExternReceiptKey = ''

   SELECT @cStorerKey = StorerKey 
   FROM dbo.Receipt WITH (NOLOCK) 
   WHERE ReceiptKey = @cReceiptKey
   

   -- Get SKU info
   SELECT TOP 1 
      @cExternReceiptKey = Externreceiptkey
   FROM dbo.Receipt WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND ReceiptKey = @cReceiptKey
      
   SET @cNCounter = ''  
   SET @bSuccess = 1  
   EXECUTE dbo.nspg_getkey  
    'THAUTOID'  
    , 3  
    , @cNCounter         OUTPUT  
    , @bSuccess          OUTPUT  
    , @nErrNo            OUTPUT  
    , @cErrMsg           OUTPUT  
   IF @bSuccess <> 1  
   BEGIN  
      SET @nErrNo = -1
      --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey  
      --GOTO RollBackTran  
   END  
   
   SET @cAutoID = Left(@cExternReceiptKey,15) + @cNCounter
   
   

Fail:
END


GO