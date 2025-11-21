SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
   
/******************************************************************************/    
/* Store procedure: rdt_PTLCart_Assign_WaveTotes                             */    
/* Copyright      : LFLogistics                                               */    
/*                                                                            */    
/* Date       Rev  Author   Purposes                                          */    
/* 27-07-2020 1.0  YeeKung  WMS-14246 Created                                 */     
/******************************************************************************/    
    
CREATE PROC [RDT].[rdt_PTLCart_Assign_WaveTotes] (    
   @nMobile          INT,     
   @nFunc            INT,     
   @cLangCode        NVARCHAR( 3),     
   @nStep            INT,     
   @nInputKey        INT,     
   @cFacility        NVARCHAR( 5),     
   @cStorerKey       NVARCHAR( 15),      
   @cCartID          NVARCHAR( 10),    
   @cPickZone        NVARCHAR( 10),    
   @cMethod          NVARCHAR( 1),    
   @cPickSeq         NVARCHAR( 1),    
   @cDPLKey          NVARCHAR( 10),    
   @cType            NVARCHAR( 15), --POPULATE-IN/POPULATE-OUT/CHECK    
   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,       
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,       
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,       
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,       
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,       
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,      
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,      
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,      
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,      
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,      
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,     
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,     
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,     
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,     
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,     
   @nScn             INT           OUTPUT,    
   @nErrNo           INT           OUTPUT,     
   @cErrMsg          NVARCHAR( 20) OUTPUT    
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF 
   
   DECLARE @cWavePK              NVARCHAR(20)   
   DECLARE @nTotalOrder          INT    
   DECLARE @nTotalTote           INT
   DECLARE @cDefaultToteIDAsPos  NVARCHAR(20)
   DECLARE @cWavekey             NVARCHAR(20)
   DECLARE @cCaseID              NVARCHAR(20)
   DECLARE @cOrderKey            NVARCHAR(10)   
   DECLARE @cToteID              NVARCHAR(20) 
   DECLARE @nStorerQty           INT
   DECLARE @nTranCount           INT 
   DECLARE @nPosition            INT 

   DECLARE @cErrMsg1 NVARCHAR(20),
           @cErrMsg2 NVARCHAR(20)

   SET @nTranCount = @@TRANCOUNT  
   
    /***********************************************************************************************    
                                                POPULATE    
   ***********************************************************************************************/    
   IF @cType = 'POPULATE-IN'    
   BEGIN    
      
      --SET @cWavePK=''
      --SELECT TOP 1 @cWavePK=wavekey+caseid FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID 
      --SELECT @nTotalOrder = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID    
      --SELECT @nTotalTote = COUNT(1) 
      --From Pickdetail  PD (NOLOCK) JOIN orderinfo oi (NOLOCK) 
      --ON oi.OrderKey=PD.OrderKey 
      --Where oi.storename <> '' and PD.WaveKey = @cWavekey 
      --   and pd.caseid=@cCaseID


      -- Prepare next screen var    
      SET @cOutField01 = @cCartID    
      SET @cOutField02 = @cPickZone    
      SET @cOutField03 = @cWavePK    
      SET @cOutField04 = '' -- OrderKey    

      IF ISNULL(@cWavePK,'') = ''    
      BEGIN
         -- Enable disable field    
         SET @cFieldAttr03 = ''  -- wavePK    
         SET @cFieldAttr05 = 'O' -- ToteID
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- wavePK
      END
      ELSE    
      BEGIN
         -- Enable disable field    
         SET @cFieldAttr03 = 'O'  -- wavePK    
         SET @cFieldAttr05 = ' ' -- ToteID
      END

      -- Go to batch totes screen    
      SET @nScn = 5043
      GOTO QUIT
   END  
   
   IF @cType = 'POPULATE-OUT'    
   BEGIN    
      
      IF (@cFieldAttr05='')
      BEGIN

         SET @cWavekey = SUBSTRING(@cOutField03,1,10) 
         SET @cCaseID = SUBSTRING(@cOutField03,11,10) 

         SET @nTotalTote = CAST (@cOutField04 AS INT)

         SELECT @nStorerQty=susr5 FROM STORER (nolock) where storerkey=@cstorerkey  

         IF(@nStorerQty>@nTotalTote)
         BEGIN    
            SET @nErrNo = 156108    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need BatchKey 
            SET @cErrMsg1 = 'No of ToteID scanned'  
            SET @cErrMsg2 = 'less than store.susr5'    
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '156108', @cErrMsg1,@cErrMsg2    
         END
         ELSE
         BEGIN

            BEGIN TRAN 
            SAVE TRAN rdt_PTLCart_Assign_WaveTotes

            UPDATE PD WITH (ROWLOCK)
            set PD.dropid=oi.storename
            from pickdetail pd join orderinfo oi on pd.orderkey=oi.orderkey
            where pd.wavekey=@cWavekey
               AND pd.caseid=@cCaseID
               AND pd.storerkey=@cStorerKey

            IF @@ERROR <>0
            BEGIN    
               SET @nErrNo = 156112    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need BatchKey    
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- BatchKey    
               GOTO RollBackTran   
            END
         END
         
         SET @nScn = 5043
         SET @nErrNo='-1'
         SET @cOutField03=''
         SET @cOutField04=''
         SET @cOutField05=''
         SET @cFieldAttr03 = '' -- wavepk    
         SET @cFieldAttr05 = 'O' -- ToteID   
         GOTO Quit   
         
      END

      -- Enable field    
      SET @cFieldAttr03 = '' -- wavepk    
      SET @cFieldAttr04 = '' -- wavepk    
      SET @cFieldAttr05 = ' ' -- ToteID    
      GOTO QUIT
  -- Go to cart screen    
   END

   /***********************************************************************************************    
                                                 CHECK    
   ***********************************************************************************************/    
   IF @cType = 'CHECK'    
   BEGIN
      DECLARE @cCheckBatchUsed NVARCHAR( 1)    
      DECLARE @cMultiPickerBatch NVARCHAR( 1)    
      DECLARE @cPickConfirmStatus NVARCHAR( 1)    
      DECLARE @cIPAddress NVARCHAR(40)    
      DECLARE @cLOC NVARCHAR(10)    
      DECLARE @cSKU NVARCHAR(20)    
      DECLARE @nQTY INT    
      DECLARE @curPD CURSOR

      -- Get storer config     
    
      -- Screen mapping    
      SET @cWavePK = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END       
      SET @cToteID   = CASE WHEN @cFieldAttr05 = '' THEN @cInField05 ELSE @cOutField05 END
      
       -- WAVEPK field enabled    
      IF @cFieldAttr03 = ''    
      BEGIN 
         -- Check blank    
         IF @cWavePK = ''     
         BEGIN    
            SET @nErrNo = 156101    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need BatchKey    
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- BatchKey    
            GOTO Quit    
         END

         SET @cWavekey = SUBSTRING(@cWavePK,1,10) 
         SET @cCaseID = SUBSTRING(@cWavePK,11,10) 

         IF EXISTS( Select 1 From Pickdetail  PD JOIN WAVEDETAIL WD ON WD.OrderKey=PD.OrderKey Where PD.DropID <> '' and WD.WaveKey = @cWavekey AND CASEID=@cCaseID)
         BEGIN  
            SET @nErrNo = 156102     
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Batch Assigned   
            SET @cErrMsg1 = 'ToteId had '
            SET @cErrMsg2 = 'assigned'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '156102', @cErrMsg1,@cErrMsg2   
            SET @cOutField03 = ''    
            GOTO Quit    
         END 
                                                                                                      
         IF EXISTS( Select 1 From Pickdetail  PD JOIN WAVEDETAIL WD  ON WD.OrderKey=PD.OrderKey Where PD.DropID <> ''  AND PD.caseid =@cCaseID and WD.WaveKey = @cWavekey)
            AND Exists (Select 1 From Pickdetail  PD JOIN WAVEDETAIL WD ON WD.OrderKey=PD.OrderKey Where PD.DropID = ''  AND PD.caseid =@cCaseID and WD.WaveKey = @cWavekey) 
         BEGIN    
            SET @nErrNo = 156103    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Batch Assigned 
            SET @cErrMsg1 = 'Partial Assigned'
            SET @cErrMsg2 = 'WavePK'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '156103', @cErrMsg1,@cErrMsg2   
            SET @cOutField03 = ''    
            GOTO Quit  
         END    

         IF NOT EXISTS (Select 1 From Pickdetail  PD  Where PD.DropID = '' and PD.WaveKey = @cWavekey AND PD.caseid =@cCaseID)
         BEGIN
            SET @nErrNo = 156112    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Batch Assigned 
            SET @cErrMsg1 = 'ToteId fully '
            SET @cErrMsg2 = 'assigned'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '156103', @cErrMsg1,@cErrMsg2   
            SET @cOutField03 = ''    
            GOTO Quit  
         END


         IF EXISTS (SELECT 1 from packheader PH(NOLOCK) 
                     JOIN pickdetail pdo (nolock) ON pdo.OrderKey=ph.OrderKey
                     JOIN PackDetail pd (NOLOCK) ON pd.PickSlipNo=ph.PickSlipNo and pdo.sku=pd.sku
                     WHERE pd.Qty>0
                        and pdo.wavekey= @cWavekey
                        and pdo.CaseID=@cCaseID
                        and pd.storerkey=@cStorerKey)
         BEGIN    
            SET @nErrNo = 156104    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Batch Assigned    
            SET @cErrMsg1 = 'Pack Started'
            SET @cErrMsg2 = 'already'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '156104', @cErrMsg1,@cErrMsg2  
            SET @cOutField03 = ''    
            GOTO Quit    
         END 

         BEGIN TRAN 
         SAVE TRAN rdt_PTLCart_Assign_WaveTotes

         UPDATE OI WITH (ROWLOCK)
         set OI.StoreName=''
         from pickdetail pd join orderinfo oi on pd.orderkey=oi.orderkey
         where pd.wavekey=@cWavekey
            AND pd.caseid=@cCaseID
            AND pd.storerkey=@cStorerKey
            AND OI.StoreName<>''

         IF @@ERROR <>0
         BEGIN    
            SET @nErrNo = 156112    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need BatchKey    
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- BatchKey    
            GOTO RollBackTran   
         END

         SET @cOutField03=@cWavepk
         SET @cOutField04 = 0
         SET @cFieldAttr03='O'
         SET @cFieldAttr05=''
         SET @nErrNo='-1'
         GOTO QUIT

      END

      IF @cFieldAttr05=''
      BEGIN

         SET @cWavekey = SUBSTRING(@cWavePK,1,10) 
         SET @cCaseID = SUBSTRING(@cWavePK,11,10) 

         SET @nTotalTote = CAST (@cOutField04 AS INT)

          -- Check blank    
         IF ISNULL(@cToteID,'') = ''     
         BEGIN    
            SET @nErrNo = 156105    
            SET @cErrMsg =  rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need BatchKey
            SET @cErrMsg1 = @cErrMsg
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '156105', @cErrMsg1  
            SET @cOutField03=''
            SET @cOutField05=''
            SET @cFieldAttr03 = '' -- wavepk    
            SET @cFieldAttr05 = 'O' -- ToteID      
            GOTO Quit    
         END

         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'DROPID', @cToteID) = 0  
         BEGIN    
            SET @nErrNo = 156106    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need BatchKey 
            SET @cErrMsg1 = 'Invalid Format Scanned:'
            SET @cErrMsg2 = @cToteID
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '156106', @cErrMsg1,@cErrMsg2   
            SET @cOutField03=''
            SET @cOutField05=''
            SET @cFieldAttr03 = '' -- wavepk    
            SET @cFieldAttr05 = 'O' -- ToteID      
            GOTO Quit   
         END

         IF EXISTS(SELECT 1 
                  From Pickdetail  PD (NOLOCK) JOIN orderinfo oi (NOLOCK) 
                  ON oi.OrderKey=PD.OrderKey 
                  Where oi.storename=@cToteID 
                     and PD.WaveKey = @cWavekey 
                     and pd.caseid=@cCaseID)
         BEGIN    
            SET @nErrNo = 156107    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need BatchKey    
            SET @cErrMsg1 = 'Duplicate ToteID:'
            SET @cErrMsg2 = @cToteID   
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '156107', @cErrMsg1,@cErrMsg2 
            SET @cOutField03=''
            SET @cOutField05=''
            SET @cFieldAttr03 = '' -- wavepk    
            SET @cFieldAttr05 = 'O' -- ToteID      
            GOTO Quit   
         END

         IF EXISTS (SELECT 1 FROM STORER (nolock) where susr5<=@nTotalTote and storerkey=@cstorerkey)
         BEGIN    
            SET @nErrNo = 156108    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need BatchKey 
            SET @cErrMsg1 = 'Exceeded '+CAST(@nTotalTote AS NVARCHAR(5))+' Totes'  
            SET @cErrMsg2 = 'Scanned'    
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '156108', @cErrMsg1,@cErrMsg2   
            SET @cOutField03=''
            SET @cOutField05=''
            SET @cFieldAttr03 = '' -- wavepk    
            SET @cFieldAttr05 = 'O' -- ToteID      
            GOTO Quit    
         END


         IF EXISTS (select 1 from pickdetail pd (NOLOCK) join orders o (NOLOCK)
                     on pd.orderkey=o.orderkey  
                     WHERE pd.dropid=@cToteID 
                        AND pd.storerkey=@cStorerKey 
                        and pd.status<>'9'
                        and o.sostatus<>'5'
                        and (pd.wavekey<>@cWavekey OR pd.caseid<>@cCaseID))

       BEGIN    
            SET @nErrNo = 156109   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need BatchKey 
            SET @cErrMsg1 = 'Pack Incomplete:'  
            SET @cErrMsg2 = @cToteID   
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '156109', @cErrMsg1,@cErrMsg2   
            SET @cOutField03=''
            SET @cOutField05=''
            SET @cFieldAttr03 = '' -- wavepk    
            SET @cFieldAttr05 = 'O' -- ToteID      
            GOTO Quit   
         END

         BEGIN TRAN 
         SAVE TRAN rdt_PTLCart_Assign_WaveTotes

         UPDATE orderinfo WITH (ROWLOCK)
         set storename=@cToteID
         WHERE orderkey = (SELECT TOP 1 O.orderkey FROM 
                         PICKDETAIL (NOLOCK) PD JOIN ORDERS O (NOLOCK)
                         ON PD.orderkey=O.orderkey AND PD.storerkey=O.storerkey
                         JOIN orderinfo OI (NOLOCK)
                         ON OI.orderkey=O.orderkey
                         WHERE pd.wavekey=@cWavekey
                           AND pd.caseid=@cCaseID
                           AND pd.storerkey=@cStorerKey
                           AND OI.storename =''
                        ORDER BY O.BilledContainerQty)

         IF @@ERROR <>0
         BEGIN    
            SET @nErrNo = 156111    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need BatchKey    
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- BatchKey    
            GOTO RollBackTran      
         END

         SET @cToteID=''  
         SET @cOutField04=@nTotalTote+1
         SET @nErrNo='-1'
         GOTO QUIT

      END
   END
 
        
    
RollBackTran:    
   ROLLBACK TRAN rdt_PTLCart_Assign_WaveTotes    
    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN    
END 

GO