SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_1581ExtUpd01                                          */
/* Copyright      : LF logistics                                              */
/*                                                                            */
/* Purpose: Prompt receive successfull msg                                    */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 2023-05-22  1.0  James       WMS-21975. Created                            */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1581ExtUpd01]
    @nMobile      INT
   ,@nFunc        INT
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cReceiptKey  NVARCHAR( 10)
   ,@cPOKey       NVARCHAR( 10)
   ,@cExtASN      NVARCHAR( 20)
   ,@cToLOC       NVARCHAR( 10)
   ,@cToID        NVARCHAR( 18)
   ,@cLottable01  NVARCHAR( 18)
   ,@cLottable02  NVARCHAR( 18)
   ,@cLottable03  NVARCHAR( 18)
   ,@dLottable04  DATETIME
   ,@cSKU         NVARCHAR( 20)
   ,@nQTY         INT
   ,@nAfterStep   INT
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cErrMsg1    NVARCHAR( 20)
   DECLARE @cErrMsg2    NVARCHAR( 20)

   IF @nFunc = 1581 -- Piece receiving
   BEGIN
   	IF @nStep = 5
   	BEGIN
   		IF @nInputKey = 1 -- Enter
   		BEGIN
            SET @nErrNo = 0  
            SET @cErrMsg1 = 'RECEIVED'  
            SET @cErrMsg2 = 'SUCCESSFULLY'  
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2  
            IF @nErrNo = 1  
            BEGIN  
               SET @cErrMsg1 = ''  
               SET @cErrMsg2 = ''  
            END  
            SET @nErrNo = 0
   		END
   	END
   END
   
Quit:


END

GO