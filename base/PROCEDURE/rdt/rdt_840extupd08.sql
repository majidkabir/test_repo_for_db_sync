SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/    
/* Store procedure: rdt_840ExtUpd08                                     */    
/* Purpose: Trigger HM related interface and misc update                */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */    
/* 2019-11-19 1.0  James      WMS-11146. Created                        */   
/* 2020-04-15 1.1  James      WMS-12877 Update order status = '1' when  */  
/*                            short pack occured (james01)              */  
/*                            Add isp_AssignPackLabelToOrderByLoad      */  
/*                            Prompt when short pick                    */  
/* 2020-10-06 1.2  James      WMS-14288 Remove trigger TL2 for tablename*/  
/*                            WSORDUPDATE (james02)                     */  
/* 2021-04-01 1.3 YeeKung     WMS-16717 Add serialno and serialqty      */  
/*                            Params (yeekung01)                        */  
/* 2022-09-15 1.4  James      WMS-20788 Add new TL2 insert (james03)    */
/************************************************************************/    
    
CREATE   PROC [RDT].[rdt_840ExtUpd08] (    
   @nMobile     INT,    
   @nFunc       INT,     
   @cLangCode   NVARCHAR( 3),     
   @nStep       INT,     
   @nInputKey   INT,     
   @cStorerkey  NVARCHAR( 15),     
   @cOrderKey   NVARCHAR( 10),     
   @cPickSlipNo NVARCHAR( 10),     
   @cTrackNo    NVARCHAR( 20),     
   @cSKU        NVARCHAR( 20),     
   @nCartonNo   INT,   
   @cSerialNo   NVARCHAR( 30),   
   @nSerialQTY  INT,      
   @nErrNo      INT           OUTPUT,     
   @cErrMsg     NVARCHAR( 20) OUTPUT    
)    
AS    
    
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF     
    
   DECLARE @nTranCount        INT,     
           @nExpectedQty      INT,    
           @nPackedQty        INT,     
           @nOriginalQty      INT,    
           @nPickQty          INT,    
           @nPackQty          INT,    
           @bSuccess          INT,    
           @nShortPack        INT = 0,    
           @cCode             NVARCHAR( 10),  
           @cUpdateSource     NVARCHAR( 10),  
           @cFacility         NVARCHAR( 5)  
    
   DECLARE @cErrMsg01         NVARCHAR( 20)  
   DECLARE @c_APP_DB_Name         NVARCHAR(20)=''      
          ,@c_DataStream          VARCHAR(10)=''      
          ,@n_ThreadPerAcct       INT=0      
          ,@n_ThreadPerStream     INT=0      
          ,@n_MilisecondDelay     INT=0      
          ,@c_IP                  NVARCHAR(20)=''      
          ,@c_PORT                NVARCHAR(5)=''      
          ,@c_IniFilePath         NVARCHAR(200)=''      
          ,@c_CmdType             NVARCHAR(10)=''      
          ,@c_TaskType            NVARCHAR(1)=''    
          ,@n_ShipCounter         INT = 0           
          ,@n_Priority            INT = 0 
   DECLARE @cTransmitLogKey         NVARCHAR( 10) = ''
   DECLARE @cCommand                NVARCHAR( MAX)
   DECLARE @c_QCmdClass             NVARCHAR(10)   = ''     
   DECLARE @b_Debug                 INT = 0  
   DECLARE @cOrderType              NVARCHAR( 10)
   
   SELECT @cFacility = Facility FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile  
     
   IF @nStep = 4    
   BEGIN    
      IF @nInputKey = 1    
      BEGIN    
      	SELECT 
      	   @cOrderType = [Type], 
      	   @cUpdateSource = UpdateSource
      	FROM dbo.ORDERS WITH (NOLOCK)
      	WHERE OrderKey = @cOrderKey
      	
         SET @nTranCount = @@TRANCOUNT      
         BEGIN TRAN  -- Begin our own transaction      
         SAVE TRAN rdt_840ExtUpd08 -- For rollback or commit only our own transaction      
  
         IF @cOrderType = 'COD'
         BEGIN
            -- Customer orders need trigger TL2 if short pack  
            IF NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)   
                            JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.OrderGroup AND C.StorerKey = O.StorerKey)  
                            WHERE C.ListName = 'HMCOSORD'  
                            AND   C.Long = 'M'  
                            AND   O.OrderKey = @cOrderkey  
                            AND   O.StorerKey = @cStorerKey)  
            BEGIN   
               SET @nShortPack = 0    
    
               SELECT @nOriginalQty = ISNULL( SUM( OriginalQty), 0)    
               FROM dbo.Orders O WITH (NOLOCK)    
               JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON ( O.OrderKey = OD.OrderKey)    
               WHERE O.OrderKey = @cOrderKey    
               AND   O.StorerKey = @cStorerkey    
    
               SELECT @nPackQty = ISNULL( SUM( QTY), 0)    
               FROM dbo.PackDetail PD WITH (NOLOCK)    
               JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)    
               WHERE PH.OrderKey = @cOrderKey             
               AND   PH.StorerKey = @cStorerkey    
    
               -- Compare packed qty to order qty to check if short qty    
               IF @nOriginalQty > @nPackQty        
                  SET @nShortPack = 1    
  
               -- Short pick/pack or partial allocate need trigger order value recalculate    
               IF @nShortPack = 1 AND @cUpdateSource <> '1'    
               BEGIN    
                  /* -- (james02)  
                  -- Insert transmitlog2 here   
                  SET @bSuccess = 1    
                  EXEC ispGenTransmitLog2     
                        @c_TableName        = 'WSORDUPDATE'    
                     ,@c_Key1             = @cOrderKey    
                     ,@c_Key2             = ''    
                     ,@c_Key3             = @cStorerkey    
                     ,@c_TransmitBatch    = ''    
                     ,@b_Success          = @bSuccess    OUTPUT    
                     ,@n_err              = @nErrNo      OUTPUT    
                     ,@c_errmsg           = @cErrMsg     OUTPUT          
    
                  IF @bSuccess <> 1        
                     GOTO RollBackTran    
                  */  
                 
                  UPDATE dbo.Orders WITH (ROWLOCK) SET    
                     [Status] = '1',  
                     SOStatus = 'HOLD',    
                     Trafficcop = NULL,    
                     EditDate = GETDATE(),    
                     EditWho = sUSER_sNAME()    
                  WHERE StorerKey = @cStorerkey    
                  AND   OrderKey = @cOrderKey    
                  AND   SOStatus <> 'HOLD'    
    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 146151    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD HOLD FAIL'    
                     GOTO RollBackTran    
                  END  
                 
                  GOTO CommitTrans          
               END    
            END  
         END
         
         SET @nExpectedQty = 0  
         SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)  
         WHERE Orderkey = @cOrderkey  
         AND Storerkey = @cStorerkey  
  
         SET @nPackedQty = 0  
         SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)  
         WHERE PickSlipNo = @cPickSlipNo  
           
         IF @nExpectedQty = @nPackedQty  
         BEGIN  
            -- Trigger pack confirm    
            UPDATE dbo.PackHeader WITH (ROWLOCK) SET    
               STATUS = '9',    
               EditWho = 'rdt.' + sUser_sName(),    
               EditDate = GETDATE()    
            WHERE PickSlipNo = @cPickSlipNo    
            AND   [Status] < '9'    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 146152    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Packcfm fail    
               GOTO RollBackTran      
            END    
              
            UPDATE dbo.Orders WITH (ROWLOCK) SET   
               SOStatus = '0',    
               EditWho = 'rdt.' + sUser_sName(),    
               EditDate = GETDATE()    
            WHERE OrderKey = @cOrderKey  
  
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 146153    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Packcfm fail    
               GOTO RollBackTran      
            END  
  
            -- (james01)  
            -- Update packdetail.labelno=pickdetail.dropid  
            -- Get storer config  
            DECLARE @cAssignPackLabelToOrdCfg NVARCHAR(1)  
            EXECUTE nspGetRight  
               @cFacility,  
               @cStorerKey,  
               '', --@c_sku  
               'AssignPackLabelToOrdCfg',  
               @bSuccess                 OUTPUT,  
               @cAssignPackLabelToOrdCfg OUTPUT,  
               @nErrNo                   OUTPUT,  
               @cErrMsg                  OUTPUT  
            IF @nErrNo <> 0  
               GOTO RollBackTran  
  
            -- Assign  
            IF @cAssignPackLabelToOrdCfg = '1'  
            BEGIN  
               -- Update PickDetail, base on PackDetail.DropID  
               EXEC isp_AssignPackLabelToOrderByLoad  
                     @cPickSlipNo  
                  ,@bSuccess OUTPUT  
                  ,@nErrNo   OUTPUT  
                  ,@cErrMsg  OUTPUT  
               IF @nErrNo <> 0  
                  GOTO RollBackTran  
            END  
         END  

         IF @nShortPack = 1 AND @cOrderType = 'COD'
            GOTO CommitTrans
            
         -- Fully pick = pack only trigger WSCRRDTMTE interface
         IF EXISTS ( SELECT 1 FROM dbo.TransmitLog2 WITH (NOLOCK)
                     WHERE TableName = 'WSCRRDTMTE'
                     AND   key1 = @cOrderKey
                     AND   key2 = @nCartonNo
                     AND   key3 = @cStorerKey
                     AND   transmitflag = '9')
         BEGIN
            DELETE FROM dbo.TransmitLog2
            WHERE TableName = 'WSCRRDTMTE'
            AND   key1 = @cOrderKey
            AND   key2 = @nCartonNo
            AND   key3 = @cStorerKey
            AND   transmitflag = '9'

            IF @@ERROR <> 0
            BEGIN    
               SET @nErrNo = 146156    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelTLog2 Err'    
               GOTO RollBackTran    
            END    
         END
         
         EXEC dbo.ispGenTransmitLog2
            @c_TableName      = 'WSCRRDTMTE',
            @c_Key1           = @cOrderKey,
            @c_Key2           = @nCartonNo ,
            @c_Key3           = @cStorerKey,
            @c_TransmitBatch  = '',
            @b_success        = @bSuccess    OUTPUT,
            @n_err            = @nErrNo      OUTPUT,
            @c_errmsg         = @cErrMsg     OUTPUT

         IF @bSuccess <> 1
         BEGIN
            SET @nErrNo = 146155
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenTLog2 Fail'
            GOTO RollBackTran
         END
         
         SELECT @cTransmitLogKey = transmitlogkey
         FROM dbo.TRANSMITLOG2 WITH (NOLOCK)
         WHERE tablename = 'WSCRRDTMTE'
         AND   key1 = @cOrderKey
         AND   key2 = @nCartonNo
         AND   key3 = @cStorerKey

         EXEC dbo.isp_QCmd_WSTransmitLogInsertAlert   
            @c_QCmdClass         = @c_QCmdClass,   
            @c_FrmTransmitlogKey = @cTransmitLogKey,   
            @c_ToTransmitlogKey  = @cTransmitLogKey,   
            @b_Debug             = @b_Debug,   
            @b_Success           = @bSuccess    OUTPUT,   
            @n_Err               = @nErrNo      OUTPUT,   
            @c_ErrMsg            = @cErrMsg     OUTPUT   

         
         /*
            SELECT @c_APP_DB_Name = APP_DB_Name
               , @c_DataStream = DataStream
               , @n_ThreadPerAcct = ThreadPerAcct
               , @n_ThreadPerStream = ThreadPerStream
               , @n_MilisecondDelay = MilisecondDelay
               , @c_IP = IP
               , @c_PORT = PORT
               , @c_IniFilePath = IniFilePath
               , @c_CmdType = CmdType
               , @c_TaskType = TaskType
               , @n_Priority = ISNULL([Priority],0) 
            FROM QCmd_TransmitlogConfig WITH (NOLOCK)
            WHERE TableName = 'ASSIGNTRACKNO'
            AND [App_Name] = 'WMS'
            AND StorerKey = 'ALL'

            SET @nErrNo = 0
            SET @cCommand = N'EXEC [dbo].[isp_QCmd_WSTransmitLogInsertAlert] ' +
               N' @c_QCmdClass = '''' ' +
               N' , @c_FrmTransmitlogKey = ''' + @cTransmitLogKey + '''' +
               N' , @c_ToTransmitlogKey = ''' + @cTransmitLogKey + '''' +
               N' , @b_Debug = 0 '+
               N' , @b_Success = 0 '+
               N' , @n_Err = 0 '+
               N' , @c_ErrMsg = ''''' 

            EXEC isp_QCmd_SubmitTaskToQCommander
               @cTaskType = 'O' -- D=By Datastream, T=Transmitlog, O=Others
               , @cStorerKey = @cStorerKey
               , @cDataStream = ''
               , @cCmdType = 'SQL'
               , @cCommand = @cCommand
               , @cTransmitlogKey = @cTransmitLogKey
               , @nThreadPerAcct = @n_ThreadPerAcct
               , @nThreadPerStream = @n_ThreadPerStream
               , @nMilisecondDelay = @n_MilisecondDelay
               , @nSeq = 1
               , @cIP = @c_IP
               , @cPORT = @c_PORT
               , @cIniFilePath = @c_IniFilePath
               , @cAPPDBName = @c_APP_DB_Name
               , @bSuccess = 1
               , @nErr = 0
               , @cErrMsg = ''
               , @nPriority = @n_Priority
                  
            IF @nErrNo <> 0
               GOTO RollBackTran
         */
         GOTO CommitTrans    
          
         RollBackTran:      
               ROLLBACK TRAN rdt_840ExtUpd08      
    
         CommitTrans:      
            WHILE @@TRANCOUNT > @nTranCount      
               COMMIT TRAN      
      END    
   END    
       
   Quit:  

GO