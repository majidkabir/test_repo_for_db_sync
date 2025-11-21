SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_533ExtUpdSP01                                   */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: CARTERSZ Move By LabelNo                                    */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 08-04-2016  1.0  ChewKP      Created. SOS#368019                     */  
/************************************************************************/    
                   
CREATE PROC [dbo].[rdt_533ExtUpdSP01] (    
   @nMobile      INT,
   @nFunc        INT, 
   @cLangCode    NVARCHAR( 3), 
   @cUserName    NVARCHAR( 18), 
   @cFacility    NVARCHAR( 5), 
   @cStorerKey   NVARCHAR( 15),
   @cPickSlipNo  NVARCHAR( 10),
   @cFromLabelNo NVARCHAR( 20),
   @cToLabelNo   NVARCHAR( 20),
   @cCartonType  NVARCHAR( 10), 
   @cSKU         NVARCHAR( 20),
   @nQTY_Move    INT,
   @nErrNo       INT          OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
     
   DECLARE  
           @nTrancount         INT  
         , @cPickDetailKey     NVARCHAR(10)
         , @cFromID            NVARCHAR(18)
         , @nQty               INT
         , @cFromLoc           NVARCHAR(10)
         , @cToID              NVARCHAR(18)
         , @cToLoc             NVARCHAR(10) 
        

   SET @nErrNo   = 0    
   SET @cErrMsg  = ''   


   SET @nTranCount = @@TRANCOUNT  

   BEGIN TRAN  
   SAVE TRAN rdt_533ExtUpdSP01  
   
   DECLARE C_CarterSZPTS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
      
   SELECT PD.PickDetailKey
         ,PD.ID
         ,PD.SKU
         ,PD.QTy
         ,PD.Loc
   FROM dbo.Pickdetail PD WITH (NOLOCK) 
   WHERE PD.StorerKey = @cStorerKey
   AND PD.Status <= '5'
   AND PD.CaseID = @cFromLabelNo
   ORDER BY PD.PickDetailKey
   
   
   OPEN C_CarterSZPTS        
   FETCH NEXT FROM C_CarterSZPTS INTO  @cPickDetailKey, @cFromID, @cSKU, @nQty, @cFromLoc
   WHILE (@@FETCH_STATUS <> -1)        
   BEGIN        
      
      SELECT @cToID = ID 
            ,@cToLoc = Loc 
      FROM dbo.PickDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND CaseID = @cToLabelNo
      AND PickSlipNo = @cPickSlipNo
      
      IF @cToID <> @cFromID 
      BEGIN
         -- ID not same , need to move PickDetail ID as well.
         EXECUTE rdt.rdt_Move    
            @nMobile     = @nMobile,    
            @cLangCode   = @cLangCode,    
            @nErrNo      = @nErrNo  OUTPUT,    
            @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max    
            @cSourceType = 'rdt_533ExtUpdSP01',    
            @cStorerKey  = @cStorerKey,    
            @cFacility   = @cFacility,    
            @cFromLOC    = @cFromLOC,    
            @cToLOC      = @cToLOC,    
            @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID    
            @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID    
            @cSKU        = @cSKU,    
            @nQTY        = @nQTY,   
            @nFunc       = @nFunc
         
         IF @nErrNo <> 0 
         BEGIN
            GOTO RollBackTran  
         END
         
      END
      
      
      UPDATE dbo.PickDetail WITH (ROWLOCK) 
      SET CaseID = @cToLabelNo
          ,EditWho = @cUserName
          ,EditDate = GetDate()
          ,Trafficcop = NULL
      WHERE PickDetailKey = @cPickDetailKey 
      
      
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 98601  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDetFail'  
         GOTO RollBackTran  
      END  
      
      FETCH NEXT FROM C_CarterSZPTS INTO  @cPickDetailKey, @cFromID, @cSKU, @nQty, @cFromLoc
      
   END
   CLOSE C_CarterSZPTS          
   DEALLOCATE C_CarterSZPTS 
   GOTO QUIT      
                      
 

   
 

     
RollBackTran:  
   ROLLBACK TRAN rdt_533ExtUpdSP01 -- Only rollback change made here  
  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN rdt_533ExtUpdSP01  
    
  
END    

GO