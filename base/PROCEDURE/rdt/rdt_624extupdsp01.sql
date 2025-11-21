SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_624ExtUpdSP01                                   */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Called from: rdtfnc_UCC_SortAndMove                                  */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2017-10-10  1.0  ChewKP   WMS-3166 Created                           */
/* 2018-07-11  1.1  TanJH    rdt_Move update wrong LOT bcoz missing LOT (JH01)*/  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_624ExtUpdSP01] (  
    @nMobile        INT,                
    @nFunc          INT,                
    @cLangCode      NVARCHAR(3),        
    @nStep          INT,           
    @nInputKey      INT,                
    @cUserName      NVARCHAR( 18),       
    @cFacility      NVARCHAR( 5),        
    @cStorerKey     NVARCHAR( 15),       
    @cUCC           NVARCHAR( 20),   
    @cToID          NVARCHAR( 10),
    @cToLoc         NVARCHAR( 10),    
    @nErrNo         INT OUTPUT,      
    @cErrMsg        NVARCHAR( 20) OUTPUT  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE 
             @nTranCount    INT
           , @bSuccess      INT
           , @nUCCRowRef    INT
           , @cSKU          NVARCHAR(20) 
           , @cUCCLoc       NVARCHAR(10) 
           , @nUCCQty       INT
           , @cFromID       NVARCHAR(18) 
           , @cFromLOT      NVARCHAR( 10)  --(JH01)
            

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_624ExtUpdSP01
   
   IF @nFunc = 624 
   BEGIN
   
      IF @nStep = 2
      BEGIN
         IF @nInputKey = 1
         BEGIN
           --SELECT @cToID '@cToID' , @cToLOC '@cToLOC' 

           DECLARE CUR_UCCMOVE CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
           
           SELECT UCC_RowRef, SKU, Qty, Loc, ID, LOT --(JH01) add LOT
           FROM dbo.UCC WITH (NOLOCK)
           WHERE StorerKey = @cStorerKey
           AND   UCCNo = @cUCC
           AND   Status = '1'
           
           OPEN CUR_UCCMOVE
           FETCH NEXT FROM CUR_UCCMOVE INTO @nUCCRowRef, @cSKU, @nUCCQty, @cUCCLoc, @cFromID, @cFromLOT  --(JH01) add @cFromLOT
           WHILE @@FETCH_STATUS <> -1
           BEGIN
               
               EXEC RDT.rdt_Move
               @nMobile     = @nMobile,
               @cLangCode   = @cLangCode, 
               @nErrNo      = @nErrNo  OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
               @cSourceType = 'rdt_624ExtUpdSP01', 
               @cStorerKey  = @cStorerKey,
               @cFacility   = @cFacility, 
               @cFromLOC    = @cUCCLoc, 
               @cToLOC      = @cToLOC, 
               @cFromID     = @cFromID,
               @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
               @cSKU        = @cSKU, 
               @nQty        = @nUCCQty,
               @cFromLOT    = @cFromLOT,  --(JH01)
               @nFunc       = @nFunc  
               
               IF @@ERROR <> 0
               BEGIN
                  GOTO RollBackTran
               END
               
               UPDATE dbo.UCC WITH (ROWLOCK) 
               SET ID  = @cToID
                  ,Loc = @cToLoc
               WHERE StorerKey = @cStorerKey
               AND UCCNo = @cUCC
               AND UCC_RowRef = @nUCCRowRef

               IF @@ERROR <> 0 
               BEGIN
                  SET @nErrNo = 115751
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdUCCFail'  
                  GOTO RollBackTran
               END
               
               FETCH NEXT FROM CUR_UCCMOVE INTO @nUCCRowRef, @cSKU, @nUCCQty, @cUCCLoc, @cFromID, @cFromLOT  --(JH01) add @cFromLOT
           END
           CLOSE CUR_UCCMOVE
           DEALLOCATE CUR_UCCMOVE
                     
         END
      END

   END
   
   
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_624ExtUpdSP01

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_624ExtUpdSP01

  
Fail:  
END  


GO