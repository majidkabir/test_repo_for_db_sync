SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/    
/* Store procedure: rdt_593Print08                                         */    
/*                                                                         */    
/* Modifications log:                                                      */    
/*                                                                         */    
/* Date       Rev  Author   Purposes                                       */    
/* 2016-07-05 1.0  ChewKP   SOS#372474 Created                             */  
/***************************************************************************/    
    
CREATE PROC [RDT].[rdt_593Print08] (    
   @nMobile    INT,    
   @nFunc      INT,    
   @nStep      INT,    
   @cLangCode  NVARCHAR( 3),    
   @cStorerKey NVARCHAR( 15),    
   @cOption    NVARCHAR( 1),    
   @cParam1    NVARCHAR(20),  -- OrderKey 
   @cParam2    NVARCHAR(20),  
   @cParam3    NVARCHAR(20),     
   @cParam4    NVARCHAR(20),    
   @cParam5    NVARCHAR(20),    
   @nErrNo     INT OUTPUT,    
   @cErrMsg    NVARCHAR( 20) OUTPUT    
)    
AS    
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF     
    
   DECLARE @b_Success     INT    
       
   DECLARE @cDataWindow   NVARCHAR( 50)  
         , @cManifestDataWindow NVARCHAR( 50)  
         
   DECLARE @cTargetDB     NVARCHAR( 20)    
   DECLARE @cLabelPrinter NVARCHAR( 10)    
   DECLARE @cPaperPrinter NVARCHAR( 10)    
   DECLARE @cUserName     NVARCHAR( 18)     
   DECLARE @cLabelType    NVARCHAR( 20)    
   
   DECLARE @cToteNo       NVARCHAR( 20)
          ,@cCartonType   NVARCHAR( 10)
          ,@nTranCount    INT   
          ,@cGenLabelNoSP NVARCHAR(30)  
          ,@cPickDetailKey NVARCHAR(10)
          ,@cPickSlipNo   NVARCHAR(10)
          ,@cOrderKey     NVARCHAR(10)
          ,@cLabelNo       NVARCHAR(20)
          ,@nCartonNo     INT
          ,@cLabelLine    NVARCHAR(5)
          ,@cExecStatements   NVARCHAR(4000)         
          ,@cExecArguments    NVARCHAR(4000)  
          ,@cSKU          NVARCHAR(20)  
          ,@nTTL_PackedQty INT
          ,@nTTL_PickedQty INT
          ,@nQty           INT
          ,@cFacility      NVARCHAR(5)
          ,@nTotalPackedQty INT
          ,@cType          NVARCHAR(10)
          ,@cLoadKey       NVARCHAR(10) 
          ,@cTTLWeight     NVARCHAR(10) 
          ,@nFocusParam    INT 
          ,@bsuccess       INT 
          ,@cWaveKey       NVARCHAR(10)
          
   DECLARE  @fCartonWeight FLOAT
           ,@fCartonLength FLOAT
           ,@fCartonHeight FLOAT
           ,@fCartonWidth  FLOAT
           ,@fStdGrossWeight FLOAT
           ,@fCartonTotalWeight FLOAT
           ,@fCartonCube   FLOAT
           ,@nFromCartonNo INT
           ,@nToCartonNo   INT
           ,@cOrderType    NVARCHAR(10)
           ,@bPrintManifest NVARCHAR(1)
           ,@cCartonLabelNo NVARCHAR(20)
           ,@cExternOrderKey  NVARCHAR(30) 
           ,@cNewPickDetailKey NVARCHAR( 10)
           ,@nQTY_PD    INT
           ,@nCaseCNT   INT
           ,@nQty_BAL   INT
           ,@nLoopCount INT
           ,@nType      INT
           ,@nPickedQty INT
           ,@nRemainder INT

   
   SELECT @cLabelPrinter = Printer
         ,@cUserName     = UserName
         ,@cPaperPrinter   = Printer_Paper
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Check label printer blank    
   IF ISNULL(RTRIM(@cLabelPrinter),'')  = ''    
   BEGIN    
      SET @nErrNo = 102157    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq    
      GOTO Quit    
   END    

   SET @nTranCount = @@TRANCOUNT      
         
   BEGIN TRAN      
   SAVE TRAN rdt_593Print08      
      
   IF @cOption = '1' 
   BEGIN 
         
      

      SET @cToteNo      = @cParam1
      --SET @cCartonType  = @cParam3
      --SET @cTTLWeight   = @cParam5
      

      SET @cGenLabelNoSP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo', @cStorerkey)          
             


      IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = ISNULL(RTRIM(@cGenLabelNoSP),'') AND type = 'P')        
      BEGIN      
                    
            SET @nErrNo = 102158      
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'GenLblSPNotFound'      
            --SET @cErrMsg = 'GenLblSPNotFound'      
            GOTO RollBackTran      
      END 
   
      
      -- Check blank    
      IF ISNULL(RTRIM(@cToteNo), '') = ''    
      BEGIN    
         SET @nErrNo = 102159    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ToteNoReq  
         --EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         SET @nFocusParam = 2
         GOTO RollBackTran    
      END    
      
      IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND DropID = @cToteNo
                      AND Status < '5' ) 
      BEGIN    
         SET @nErrNo = 102160   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidTote  
         --EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         SET @nFocusParam = 2
         GOTO RollBackTran    
      END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND DropID = @cToteNo
                      AND Status = '5' ) 
      BEGIN    
         SET @nErrNo = 102161   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidTote  
         --EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         SET @nFocusParam = 2
         GOTO RollBackTran    
      END
      
      IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND DropID = @cToteNo 
                  AND CaseID <> '' ) 
      BEGIN
         SET @nErrNo = 102174   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --TotePacked  
         --EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         SET @nFocusParam = 2
         GOTO RollBackTran    
      END                  
      
      
      SELECT TOP 1 @cWaveKey = WaveKey 
      FROM dbo.PickDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND DropID = @cToteNo 
      AND Status = '5'
      ORDER BY PickDetailKey Desc
      
      

      
      DECLARE C_PEARSONTOTE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      
      SELECT PD.PickDetailKey
            ,PD.SKU
            ,PD.QTy
            ,PD.OrderKey
      FROM dbo.Pickdetail PD WITH (NOLOCK) 
      --INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey
      WHERE PD.StorerKey = @cStorerKey
      AND PD.Status = '5'
      AND PD.DropID = @cToteNo
      AND PD.CaseID = ''
      ORDER BY PD.OrderKey
      
      OPEN C_PEARSONTOTE
      FETCH NEXT FROM C_PEARSONTOTE INTO @cPickDetailKey, @cSKU, @nQTY_PD, @cOrderKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
                 
         
         IF EXISTS ( SELECT 1 FROM dbo.PickHeader WITH (NOLOCK)  
                     WHERE  OrderKey = @cOrderKey ) 
         BEGIN
            
            SELECT @cPickSlipNo = PickHeaderKey 
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey 

            IF NOT EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) 
                            WHERE PickSlipNo = @cPickSlipNo )
            BEGIN
               INSERT INTO dbo.PackHeader         
               (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, AddWho, AddDate, EditWho, EditDate)         
               SELECT TOP 1  O.Route, O.OrderKey,'', O.LoadKey, O.ConsigneeKey, O.Storerkey,         
                  @cPickSlipNo, sUser_sName(), GETDATE(), sUser_sName(), GETDATE()        
               FROM  dbo.Orders O WITH (NOLOCK)
               WHERE O.Orderkey = @cOrderKey         
              
               IF @@ERROR <> 0        
               BEGIN        
                  SET @nErrNo = 102172        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CreatePHdrFail'        
                  GOTO RollBackTran        
               END    
            END
            
         END
         ELSE 
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) 
                            WHERE StorerKey = @cStorerKey
                            AND Orderkey = @cOrderKey  ) 
            BEGIN
                EXECUTE dbo.nspg_GetKey  
                  'PICKSLIP',  
                  9,  
                  @cPickslipno OUTPUT,  
                  @bsuccess   OUTPUT,  
                  @nErrNo     OUTPUT,  
                  @cErrMsg    OUTPUT  
     
                SET @cPickslipno = 'P' + @cPickslipno  
                
                INSERT INTO dbo.PICKHEADER (PickHeaderKey, Storerkey, Orderkey, PickType, Zone, TrafficCop, AddWho, AddDate, EditWho, EditDate)  
                VALUES (@cPickSlipNo, @cStorerkey, @cOrderKey, '0', 'D', '', sUser_sName(), GETDATE(), sUser_sName(), GETDATE())  
                
                IF @@ERROR <> 0  
                BEGIN  
                   SET @nErrNo = 102163  
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPickHdrFail'  
                   GOTO RollBackTran  
                END  
                
                IF NOT EXISTS ( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) 
                                WHERE PickSlipNo = @cPickSlipNo ) 
                BEGIN
                  
                  INSERT INTO dbo.PickingInfo (PickSlipNo , ScanInDate , AddWho  ) 
                  VALUES ( @cPickSlipNo , GetDATE() , @cUserName ) 
                  
                  IF @@ERROR <> 0 
                  BEGIN 
                        SET @nErrNo = 102162        
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPickInfoFail'        
                        GOTO RollBackTran   
                  END
                  
                END
                
                
                INSERT INTO dbo.PackHeader         
                (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, AddWho, AddDate, EditWho, EditDate)         
                SELECT TOP 1  O.Route, O.OrderKey,'', O.LoadKey, O.ConsigneeKey, O.Storerkey,         
                     @cPickSlipNo, sUser_sName(), GETDATE(), sUser_sName(), GETDATE()        
                FROM  dbo.Orders O WITH (NOLOCK)
                WHERE O.Orderkey = @cOrderKey         
              
                IF @@ERROR <> 0        
                BEGIN        
                   SET @nErrNo = 102164        
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CreatePHdrFail'        
                   GOTO RollBackTran        
                END    
                
                
            END
            ELSE 
            BEGIN
               SELECT @cPickSlipNo = PickSlipNo 
               FROM dbo.PackHeader WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND Orderkey = @cOrderKey
            END
         END
         
         SET @cDataWindow = ''
         SET @cTargetDB   = ''
         SET @nFromCartonNo = 0
         SET @nToCartonNo = 0
         
         SELECT @cDataWindow = DataWindow,     
                @cTargetDB = TargetDB     
         FROM rdt.rdtReport WITH (NOLOCK)     
         WHERE StorerKey = @cStorerKey    
         AND   ReportType = 'CARTONLBL'    
         
         SELECT @nCaseCnt = ISNULL(Pack.CaseCnt ,0 ) 
         FROM dbo.Pack Pack WITH (NOLOCK) 
         INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.PacKKey = Pack.PackKey
         WHERE SKU.StorerKey = @cStorerKey 
         AND SKU.SKU = @cSKU
         
         IF @nCaseCNT = 0 
         BEGIN
            SET @nCaseCNT = @nQTY_PD
         END        
         
         SET @nRemainder = 0 
         IF ISNULL(@nQTY_PD%@nCaseCnt, 0 ) > 0
         BEGIN
            SET @nRemainder = 1          
         END

         SET @nQty_BAL = @nQTY_PD
         SET @nLoopCount = ( (@nQTY_PD/@nCaseCnt )   +  @nRemainder ) 
         

         IF @nLoopCount = 1 
         BEGIN 
           SET @nType = 1 
         END
         ELSE 
         BEGIN
            SET @nType = 0
         END
         
         BEGIN
            WHILE @nLoopCount > 0 
            BEGIN
               
               -- Generate LabelNo
               SET @cLabelNo = ''
               SET @nCartonNo = 0   
               SET @cLabelLine = '00000'
               
               SET @cExecStatements = N'EXEC dbo.' + RTRIM( @cGenLabelNoSP) +        
                                      '   @cStorerKey          ' +                           
                                      ' , @cLabelNo     OUTPUT ' +     
                                      ' , @b_success    OUTPUT ' +       
                                      ' , @n_err        OUTPUT ' +       
                                      ' , @c_errmsg     OUTPUT '     
                                          
               
                      
               SET @cExecArguments ='   @cStorerKey  NVARCHAR(15)        ' +                           
                                      ' , @cLabelNo    NVARCHAR(20)  OUTPUT  ' +     
                                      ' , @b_success   INT OUTPUT  ' +       
                                      ' , @n_err       INT OUTPUT  ' +       
                                      ' , @c_errmsg    NVARCHAR(20)  OUTPUT  '             
                            
                             
                        
               EXEC sp_executesql @cExecStatements, @cExecArguments,         
                                      @cStorerKey                       
                                    , @cLabelNo     OUTPUT      
                                    , @b_success    OUTPUT
                                    , @nErrNo       OUTPUT
                                    , @cErrMsg      OUTPUT

               SET @nPickedQty = 0 
               SET @nPickedQty = CASE WHEN @nQTY_Bal > @nCaseCNT THEN @nCaseCNT ELSE @nQty_Bal END                                    
               --PRINT @nPickedQty
               --PRINT @nLoopCount

               IF @nType <> 1 
               BEGIN      
                  IF @nLoopCount <> 1 
                  BEGIN 
                     -- Get new PickDetailkey
                     EXECUTE dbo.nspg_GetKey
                        'PICKDETAILKEY',
                        10 ,
                        @cNewPickDetailKey OUTPUT,
                        @bSuccess          OUTPUT,
                        @nErrNo            OUTPUT,
                        @cErrMsg           OUTPUT
                     
                     IF @bSuccess <> 1
                     BEGIN
                        SET @nErrNo = 102167
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetKeyFail
                        GOTO RollBackTran
                     END
                     
         
                     -- Create new a PickDetail to hold the balance
                     INSERT INTO dbo.PickDetail (
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
                        UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                        ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                        EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                        PickDetailKey,
                        QTY,
                        TrafficCop,
                        OptimizeCop)
                     SELECT
                        @cLabelNo, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
                        UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
                        CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                        EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                        @cNewPickDetailKey,
                        @nPickedQty, -- QTY
                        NULL, -- TrafficCop
                        '1'   -- OptimizeCop
                     FROM dbo.PickDetail WITH (NOLOCK)
               	   WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
               		   SET @nErrNo = 102168
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INSPKDtlFail
                        GOTO RollBackTran
                     END

                  END
               END
   --            -- Split RefKeyLookup
   --            IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
   --            BEGIN
   --               -- Get PickDetail info
   --               DECLARE @cOrderLineNumber NVARCHAR( 5)
   --               DECLARE @cLoadkey NVARCHAR( 10)
   --               SELECT
   --                  @cOrderLineNumber = OD.OrderLineNumber,
   --                  @cLoadkey = OD.Loadkey
   --               FROM dbo.PickDetail PD WITH (NOLOCK)
   --                  INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
   --               WHERE PD.PickDetailkey = @cPickDetailKey
   --      
   --               -- Get PickSlipNo
   --               DECLARE @cPickSlipNo NVARCHAR(10)
   --               SET @cPickSlipNo = ''
   --               SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey
   --               IF @cPickSlipNo = ''
   --                  SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadKey
   --      
   --               -- Insert into
   --               INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)
   --               VALUES (@cNewPickDetailKey, @cPickSlipNo, @cOrderKey, @cOrderLineNumber, @cLoadkey)
   --               IF @@ERROR <> 0
   --               BEGIN
   --                  SET @nErrNo = 101762
   --                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
   --                  GOTO RollBackTran
   --               END
   --            END
      
               -- Change orginal PickDetail with exact QTY (with TrafficCop)
               
               
               
               IF @nLoopCount = 1 
               BEGIN
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                     QTY = @nPickedQty,
                     CaseID = @cLabelNo,
                     EditDate = GETDATE(),
                     EditWho  = SUSER_SNAME(),
                     Trafficcop = NULL
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 102169
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPDPKDtlFail
                     GOTO RollBackTran
                  END
               END
               
               
               
               -- Create PackDetail --
               INSERT INTO dbo.PackDetail        
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, DropID, UPC, AddWho, AddDate, EditWho, EditDate)        
               VALUES        
                  (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, @nPickedQty,        
                  @cToteNo, @cLabelNo, '', sUser_sName(), GETDATE(), sUser_sName(), GETDATE())        
               
               IF @@ERROR <> 0        
               BEGIN        
                  SET @nErrNo = 102166        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDetFail'        
                  GOTO RollBackTran        
               END    

               

               SELECT  @nCartonNo = CartonNo
               FROM dbo.Packdetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND PickSlipNo = @cPickSlipNo
               AND LabelNo = @cLabelNo
               ORDER BY CartonNo
                       
               
               EXEC RDT.rdt_BuiltPrintJob      
                            @nMobile,      
                            @cStorerKey,      
                            'CARTONLBL',      -- ReportType      
                            'CartonLabel',    -- PrintJobName      
                            @cDataWindow,      
                            @cLabelPrinter,      
                            @cTargetDB,      
                            @cLangCode,      
                            @nErrNo  OUTPUT,      
                            @cErrMsg OUTPUT,    
                            @cStorerKey,   
                            @cPickSlipNo, 
                            @nCartonNo,
                            @nCartonNo 
               
               EXEC RDT.rdt_STD_EventLog          
                    @cActionType = '8', -- Packing         
                    @cUserID     = @cUserName,          
                    @nMobileNo   = @nMobile,          
                    @nFunctionID = @nFunc,          
                    @cFacility   = @cFacility,          
                    @cStorerKey  = @cStorerkey,          
                    @cSKU        = @cSku,        
                    @nQty        = @nQty,        
                    @cRefNo1     = @cToteNo,        
                    @cRefNo2     = @cLabelNo,        
                    @cRefNo3     = @cPickSlipNo 
               
      
               
               SET @nQTY_Bal = @nQty_Bal - @nCaseCNT
               

               IF @nQTY_Bal <= 0
               BEGIN
                  BREAK
               END 

               SET @nLoopCount = @nLoopCount - 1 
            END
         END
         
         
         -- PACK Confirm -- 
         SET @nTTL_PackedQty = 0 
         SET @nTTL_PickedQty = 0 

         SELECT @nTTL_PackedQty = SUM(QTY) 
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo 
         
         SELECT @nTTL_PickedQty = SUM(QTY) 
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND OrderKey = @cOrderKey
         AND Status IN ( '0', '3', '4', '5'  ) 

         
         IF ISNULL(@nTTL_PackedQty, 0 ) <> 0 AND  ISNULL(@nTTL_PickedQty,0 )  <> 0 
         BEGIN 
            IF ISNULL(@nTTL_PackedQty, 0 ) = ISNULL(@nTTL_PickedQty,0 ) 
            BEGIN
               UPDATE dbo.PackHeader WITH (ROWLOCK) 
               SET Status = '9'
               WHERE PickSlipNo = @cPickSlipNo 
               
               IF @@ERROR <> 0 
               BEGIN 
                   SET @nErrNo = 102175        
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'        
                   GOTO RollBackTran       
               END
            END
         END
     

     
         FETCH NEXT FROM C_PEARSONTOTE INTO @cPickDetailKey, @cSKU, @nQTY_PD, @cOrderKey
      END
      CLOSE C_PEARSONTOTE        
      DEALLOCATE C_PEARSONTOTE 
      
      -- Display Message 
      SET @nErrNo = 102173        
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LabelPrinted'        
      
      
      
      -- Release RDT.RDTPTLStationLog When Entire Wave is done Packing -- 
--      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
--                      WHERE StorerKey = @cStorerKey
--                      AND WaveKey = @cWaveKey
--                      AND CaseID = '' ) 
--      BEGIN
--         
--         DELETE FROM rdt.rdtPTLStationLog WITH (ROWLOCK) 
--         WHERE WaveKey = @cWaveKey
--         AND StorerKey = @cStorerKey 
--         
--         IF @@ERROR <> 0
--         BEGIN
--            SET @nErrNo = 101772
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ReleaseStsFail
--            GOTO RollBackTran
--         END
--         
--      END 
      
   END
   
   IF @cOption ='2'
   BEGIN
      SET @cLabelNo      = @cParam1
      
      -- Check blank    
      IF ISNULL(RTRIM(@cLabelNo), '') = ''    
      BEGIN    
         SET @nErrNo = 102151    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LabelNoReq  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO RollBackTran    
      END 
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey 
                      AND LabelNo = @cLabelNo ) 
      BEGIN
         SET @nErrNo = 102152
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidLabelNo  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO RollBackTran  
      END
      
      -- Print Carton Label --
      SET @cDataWindow = ''
      SET @cTargetDB   = ''
      SET @nFromCartonNo = 0
      SET @nToCartonNo = 0
      SET @cPickSlipNo = ''
      
      
      
      SELECT @cDataWindow = DataWindow,     
             @cTargetDB = TargetDB     
      FROM rdt.rdtReport WITH (NOLOCK)     
      WHERE StorerKey = @cStorerKey    
      AND   ReportType = 'CARTONLBL'   
      
      SELECT @cPickSlipNo = PickSlipNo 
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND LabelNo = @cLabelNo 
      
      SET @cOrderKey = ''
      SELECT @cOrderKey = OrderKey 
      FROM dbo.PackHeader WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      
      SELECT @nFromCartonNo = MIN(CartonNo)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo 
      AND LabelNo = @cLabelNo    
      
      SELECT @nToCartonNo = MAX(CartonNo)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo    
      AND LabelNo = @cLabelNo 
      
      EXEC RDT.rdt_BuiltPrintJob      
          @nMobile,      
          @cStorerKey,      
          'CARTONLBL',    -- ReportType      
          'CartonLabel',    -- PrintJobName      
          @cDataWindow,      
          @cLabelPrinter,      
          @cTargetDB,      
          @cLangCode,      
          @nErrNo  OUTPUT,      
          @cErrMsg OUTPUT,    
          @cStorerKey,   
          @cPickSlipNo, 
          @nFromCartonNo,
          @nToCartonNo 
                
      
   END
   
   IF @cOption ='3'
   BEGIN
      SET @cExternOrderKey      = @cParam1
      
      -- Check blank    
      IF ISNULL(RTRIM(@cExternOrderKey), '') = ''    
      BEGIN    
         SET @nErrNo = 102153    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ExternKeyReq  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO RollBackTran    
      END 
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey 
                      AND ExternOrderKey = @cExternOrderKey ) 
      BEGIN
         SET @nErrNo = 102154
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvExternKeyReq
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO RollBackTran  
      END
      
      SET @cDataWindow = ''
      SET @cPickSlipNo = '' 
      
      SELECT @cOrderKey = OrderKey 
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE ExternOrderKey = @cExternOrderKey      
      
      
      SELECT @cPickSlipNo = PickSlipNo 
      FROM dbo.PackHeader WITH (NOLOCK)
      WHERE OrderKEy = @cOrderKey
      
    
      SELECT @cDataWindow = DataWindow,  
             @cTargetDB = TargetDB  
      FROM rdt.rdtReport WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      AND   ReportType = 'PACKLIST'  
      

      EXEC RDT.rdt_BuiltPrintJob  
       @nMobile,  
       @cStorerKey,  
       'PACKLIST',              -- ReportType  
       'PackingList',           -- PrintJobName  
       @cDataWindow,  
       @cPaperPrinter,  
       @cTargetDB,  
       @cLangCode,  
       @nErrNo  OUTPUT,  
       @cErrMsg OUTPUT,  
       @cPickSlipNo, 
       @cOrderKey,
       '',
       '',
       ''
            

      
      
   END
   
   IF @cOption = '4'
   BEGIN
      SET @cExternOrderKey      = @cParam1
      
      -- Check blank    
      IF ISNULL(RTRIM(@cExternOrderKey), '') = ''    
      BEGIN    
         SET @nErrNo = 102155    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ExternKeyReq  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO RollBackTran    
      END 
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey 
                      AND ExternOrderKey = @cExternOrderKey ) 
      BEGIN
         SET @nErrNo = 102156
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvExternKeyReq
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
         GOTO RollBackTran  
      END
      
      SET @cDataWindow = ''
      SET @cPickSlipNo = '' 
      
      SELECT @cOrderKey = OrderKey 
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE ExternOrderKey = @cExternOrderKey      
      
      
      SELECT @cPickSlipNo = PickSlipNo 
      FROM dbo.PackHeader WITH (NOLOCK)
      WHERE OrderKEy = @cOrderKey
      
    
      SELECT @cDataWindow = DataWindow,  
             @cTargetDB = TargetDB  
      FROM rdt.rdtReport WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      AND   ReportType = 'INVOICE'  
      

      EXEC RDT.rdt_BuiltPrintJob  
       @nMobile,  
       @cStorerKey,  
       'INVOICE',              -- ReportType  
       'Customer Invoice',     -- PrintJobName  
       @cDataWindow,  
       @cPaperPrinter,  
       @cTargetDB,  
       @cLangCode,  
       @nErrNo  OUTPUT,  
       @cErrMsg OUTPUT,  
       @cPickSlipNo, 
       @cOrderKey,
       '',
       '',
       ''
      
   END
     
   GOTO QUIT       
         
RollBackTran:      
   ROLLBACK TRAN rdt_593Print08 -- Only rollback change made here      
   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam

 
Quit:      
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started      
      COMMIT TRAN rdt_593Print08    
   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam 
        

GO