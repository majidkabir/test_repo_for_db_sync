SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1720ExtUpdSP01                                  */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Pallet Consolidation Extended Update                        */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2015-06-15  1.0  ChewKP   SOS#354259 Created                         */  
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1720ExtUpdSP01] (    
      @nMobile        INT, 
      @nFunc          INT, 
      @cLangCode      NVARCHAR( 3),  
      @nStep          INT, 
      @cStorerKey     NVARCHAR( 15), 
      @cFacility      NVARCHAR( 5), 
      @cFromPalletID  NVARCHAR( 20), 
      @cToPalletID    NVARCHAR( 20), 
      @cDropID        NVARCHAR( 20), 
      @nErrNo         INT           OUTPUT, 
      @cErrMsg        NVARCHAR( 20) OUTPUT
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
  
   DECLARE @nTranCount        INT  
         , @cPalletLineNumber NVARCHAR(5) 
         , @cNewPalletLineNumber NVARCHAR(5)
         , @cPickDetailKey     NVARCHAR(10)
         , @cFromID            NVARCHAR(18)
         , @nQty               INT
         , @cFromLoc           NVARCHAR(10)
         , @cToID              NVARCHAR(18)
         , @cToLoc             NVARCHAR(10) 
         , @cSKU               NVARCHAR(20)
     
     
   SET @nErrNo    = 0    
   SET @cErrMsg   = ''   
  
     
   SET @nTranCount = @@TRANCOUNT  
     
   BEGIN TRAN  
   SAVE TRAN rdt_1720ExtUpdSP01  
   
   IF @nFunc = 1720 
   BEGIN
      
      IF @nStep = '2'
      BEGIN
         SET @cDropID = '' 
         
         DECLARE C_PalletConso CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
            
         SELECT PD.PickDetailKey
               ,PD.ID
               ,PD.SKU
               ,PD.QTy
               ,PD.Loc
               ,PD.DropID
         FROM dbo.Pickdetail PD WITH (NOLOCK) 
         WHERE PD.StorerKey = @cStorerKey
         AND PD.Status <= '5'
         AND PD.ID = @cFromPalletID
         ORDER BY PD.PickDetailKey
         
         
         OPEN C_PalletConso        
         FETCH NEXT FROM C_PalletConso INTO  @cPickDetailKey, @cFromID, @cSKU, @nQty, @cFromLoc, @cDropID
         WHILE (@@FETCH_STATUS <> -1)        
         BEGIN        
            
            SELECT Top 1 @cToLoc = LLI.Loc 
            FROM dbo.LotxLocxID LLI  WITH (NOLOCK) 
            INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = LLI.Loc
            WHERE LLI.StorerKey = @cStorerKey
            AND LLI.ID = @cToPalletID
            AND LLI.Qty > 0 
            AND Loc.LocationCategory = 'PACK&HOLD'

            IF ISNULL(@cToLoc,'')  = ''
            BEGIN 
               SET @nErrNo = 94605
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidToPallet
               GOTO RollBackTran
            END
            
            -- ID not same , need to move PickDetail ID as well.
            EXECUTE rdt.rdt_Move    
               @nMobile     = @nMobile,    
               @cLangCode   = @cLangCode,    
               @nErrNo      = @nErrNo  OUTPUT,    
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max    
               @cSourceType = 'rdt_1720ExtUpdSP01',    
               @cStorerKey  = @cStorerKey,    
               @cFacility   = @cFacility,    
               @cFromLOC    = @cFromLOC,    
               @cToLOC      = @cToLOC,    
               @cFromID     = @cFromID,           -- NULL means not filter by ID. Blank is a valid ID    
               @cToID       = @cToPalletID,       -- NULL means not changing ID. Blank consider a valid ID    
               @cSKU        = @cSKU,    
               @nQTY        = @nQTY,   
               @nFunc       = @nFunc,
               @nQTYPick    = @nQTY,   
               @cCaseID     = @cDropID
            
            IF @nErrNo <> 0 
            BEGIN
               GOTO RollBackTran  
            END
               
                      
            FETCH NEXT FROM C_PalletConso INTO  @cPickDetailKey, @cFromID, @cSKU, @nQty, @cFromLoc
            
         END
         CLOSE C_PalletConso          
         DEALLOCATE C_PalletConso 
         
         DECLARE CUR_PD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      		   
         SELECT PalletLineNumber
         FROM dbo.PalletDetail WITH (NOLOCK)  
         WHERE PalletKey = @cFromPalletID
         Order By PalletLineNumber
        
         OPEN CUR_PD  
         
         FETCH NEXT FROM CUR_PD INTO @cPalletLineNumber
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            
            SET @cNewPalletLineNumber = ''
      	   SELECT @cNewPalletLineNumber =
            RIGHT( '00000' + CAST( CAST( IsNULL( MAX( PalletLineNumber), 0) AS INT) + 1 AS VARCHAR( 5)), 5)
            FROM dbo.PalletDetail WITH (NOLOCK)
            WHERE PalletKey = @cToPalletID
            
      	   Update dbo.PalletDetail
      	   SET PalletKey = @cToPalletID
      	      ,PalletLineNumber = @cNewPalletLineNumber 
      	   WHERE PalletKey = @cFromPalletID 
      	       AND PalletLineNumber = @cPalletLineNumber
      	   
      	   IF @@ERROR <> 0 
      	   BEGIN
      	      SET @nErrNo = 94601
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPalletDetFail
               GOTO RollBackTran
      	   END
      	   
      	   
      	   FETCH NEXT FROM CUR_PD INTO @cPalletLineNumber
      	   
   	   END
   	   CLOSE CUR_PD  
         DEALLOCATE CUR_PD  
                  
         
         DELETE FROM dbo.Pallet
         WHERE PalletKey = @cFromPalletID
         
         IF @@ERROR <> 0 
         BEGIN
            SET @nErrNo = 94602
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPalletFail
            GOTO RollBackTran
         END
         
         
      END
      
      IF @nStep = '3'
      BEGIN

         INSERT INTO TRACEINFO ( TraceNAme , TimeIN, Col1, col2, col3, col4 ) 
         VALUES ( 'rdt_1720ExtUpdSP01', getdate() , @cFromPalletID , @cDropID , @cToPalletID, '' )  

         DECLARE C_PalletConso CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
            
         SELECT PD.PickDetailKey
               ,PD.ID
               ,PD.SKU
               ,PD.QTy
               ,PD.Loc
         FROM dbo.Pickdetail PD WITH (NOLOCK) 
         WHERE PD.StorerKey = @cStorerKey
         AND PD.Status <= '5'
         AND PD.ID = @cFromPalletID
         AND PD.CaseID = @cDropID
         ORDER BY PD.PickDetailKey
         
         
         OPEN C_PalletConso        
         FETCH NEXT FROM C_PalletConso INTO  @cPickDetailKey, @cFromID, @cSKU, @nQty, @cFromLoc
         WHILE (@@FETCH_STATUS <> -1)        
         BEGIN        
            
            SELECT Top 1 @cToLoc = LLI.Loc 
            FROM dbo.LotxLocxID LLI  WITH (NOLOCK) 
            INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = LLI.Loc
            WHERE LLI.StorerKey = @cStorerKey
            AND LLI.ID = @cToPalletID
            AND LLI.Qty > 0
            AND Loc.LocationCategory = 'PACK&HOLD'

            IF ISNULL(@cToLoc,'')  = ''
            BEGIN 
               SET @nErrNo = 94606
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidToPallet
               GOTO RollBackTran
            END
            
            -- ID not same , need to move PickDetail ID as well.
            EXECUTE rdt.rdt_Move    
               @nMobile     = @nMobile,    
               @cLangCode   = @cLangCode,    
               @nErrNo      = @nErrNo  OUTPUT,    
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max    
               @cSourceType = 'rdt_1720ExtUpdSP01',    
               @cStorerKey  = @cStorerKey,    
               @cFacility   = @cFacility,    
               @cFromLOC    = @cFromLOC,    
               @cToLOC      = @cToLOC,    
               @cFromID     = @cFromID,           -- NULL means not filter by ID. Blank is a valid ID    
               @cToID       = @cToPalletID,       -- NULL means not changing ID. Blank consider a valid ID    
               @cSKU        = @cSKU,    
               @nQTY        = @nQTY,   
               @nFunc       = @nFunc,
               @nQTYPick    = @nQTY,   
               @cCaseID     = @cDropID
            
            IF @nErrNo <> 0 
            BEGIN
               GOTO RollBackTran  
            END
               
                      
            FETCH NEXT FROM C_PalletConso INTO  @cPickDetailKey, @cFromID, @cSKU, @nQty, @cFromLoc
            
         END
         CLOSE C_PalletConso          
         DEALLOCATE C_PalletConso 
         
         DECLARE CUR_PD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      		   
         SELECT PalletLineNumber
         FROM dbo.PalletDetail WITH (NOLOCK)  
         WHERE PalletKey = @cFromPalletID
         AND CaseID = @cDropID
         Order By PalletLineNumber
        
         OPEN CUR_PD  
         
         FETCH NEXT FROM CUR_PD INTO @cPalletLineNumber
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            
            SET @cNewPalletLineNumber = ''
      	   SELECT @cNewPalletLineNumber =
            RIGHT( '00000' + CAST( CAST( IsNULL( MAX( PalletLineNumber), 0) AS INT) + 1 AS VARCHAR( 5)), 5)
            FROM dbo.PalletDetail WITH (NOLOCK)
            WHERE PalletKey = @cToPalletID
            
      	   Update dbo.PalletDetail
      	   SET PalletKey = @cToPalletID
      	      ,PalletLineNumber = @cNewPalletLineNumber 
      	   WHERE PalletKey = @cFromPalletID 
      	       AND PalletLineNumber = @cPalletLineNumber
      	       AND CaseID = @cDropID
      	   
      	   IF @@ERROR <> 0 
      	   BEGIN
      	      SET @nErrNo = 94603
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPalletDetFail
               GOTO RollBackTran
      	   END
      	   
      	   
      	   FETCH NEXT FROM CUR_PD INTO @cPalletLineNumber
      	   
   	   END
   	   CLOSE CUR_PD  
         DEALLOCATE CUR_PD  
                  
         IF NOT EXISTS ( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK) 
                         WHERE PalletKey = @cFromPalletID ) 
         BEGIN
            DELETE FROM dbo.Pallet
            WHERE PalletKey = @cFromPalletID
            
            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 94604
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPalletFail
               GOTO RollBackTran
            END
         END
      END

      
      
      
   END
   

   
   
  
   GOTO QUIT   
     
RollBackTran:  
   ROLLBACK TRAN rdt_1720ExtUpdSP01 -- Only rollback change made here  
  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN rdt_1720ExtUpdSP01  
   
  
END    

GO