SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1836ExtValid01                                  */  
/* Purpose: Check Pallet capacity                                       */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 2020-07-29   YeeKung   1.0   WMS-14059 Created                       */  
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_1836ExtValid01]  
   @nMobile         INT,  
   @nFunc           INT,  
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT,  
   @nInputKey       INT,  
   @cTaskdetailKey  NVARCHAR( 10),  
   @cFinalLOC       NVARCHAR( 10),  
   @nErrNo          INT             OUTPUT,  
   @cErrMsg         NVARCHAR( 20)   OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @nPalletQty INT,
           @nLLIIDQty INT,
           @cToLoc NVARCHAR(20),
           @cErrMsg1 NVARCHAR(20),
           @cErrMsg2 NVARCHAR(20),
           @cErrMsg3 NVARCHAR(20),
           @cErrMsg4 NVARCHAR(20)

   IF @nFUNC=1836
   BEGIN

      IF @nStep = 0 -- Final Loc  
      BEGIN
         IF (@nInputKey='1')
         BEGIN
            SELECT @cToLoc=Toloc
            FROM taskdetail (NOLOCK) 
            WHERE taskdetailkey=@cTaskdetailKey

            SELECT @nPalletQty=MaxPallet 
            FROM loc (NOLOCK)
            WHERE loc=@cToLoc

            SELECT DISTINCT @nLLIIDQty=count(qty)
            FROM Lotxlocxid (NOLOCK)
            WHERE LOC=@cToLoc
            AND (QTY+PendingMoveIN)>0

            IF @nLLIIDQty>=@nPalletQty
            BEGIN
               SET @nErrNo = -1   
               --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail  

               SET @cErrMsg1 = rdt.rdtgetmessage( 155951, @cLangCode, 'DSP') -- UpdTaskdetFail  
               SET @cErrMsg2 = @cToLoc
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,   
                  @cErrMsg1, @cErrMsg2
               GOTO Quit  
            END
         END
      END
   END
  
QUIT:
  
END  

GO