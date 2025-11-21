SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_840ExtUpd10                                     */  
/* Purpose: Insert transmitlog2 record                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author     Purposes                                 */  
/* 2020-07-05  1.0  James      WMS-13913. Created                       */ 
/* 2021-04-01  1.1 YeeKung    WMS-16717 Add serialno and serialqty      */
/*                            Params (yeekung01)                        */ 
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_840ExtUpd10] (  
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
  
   DECLARE @nTranCount           INT
   DECLARE @cUserCartonType      NVARCHAR( 10)
   DECLARE @cCartonType          NVARCHAR( 10)
   DECLARE @bSuccess             INT
   DECLARE @cTransmitLogKey      NVARCHAR( 10)
   DECLARE @c_QCmdClass          NVARCHAR(10)   = ''   
   DECLARE @b_Debug              INT = 0
   DECLARE @nInsertTL2           INT = 0
   DECLARE @cUserCartonTypeDesc  NVARCHAR(10)
   DECLARE @cCartonTypeDesc      NVARCHAR(10)
        
   SET @nTranCount = @@TRANCOUNT  
  
   BEGIN TRAN  
   SAVE TRAN rdt_840ExtUpd10  
         
   IF @nStep = 4  
   BEGIN  
      IF @nInputKey = 1 
      BEGIN  
         IF @nCartonNo = 1
         BEGIN
            
            SELECT @cUserCartonType = CartonType
            FROM dbo.PackInfo WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSliPno
            AND   CartonNo = @nCartonNo
         
            -- Use ConsoOrderKey here because when insert packdetail will
            -- insert carton type at ConsoOrderKey ( for carton 1 packinfo.cartontype will be inserted by interface)
            -- CtnTyp1 will be overwritten by insert packinfo trigger when ste4 update/insert packinfo
            SELECT @cCartonType = ConsoOrderKey
            FROM dbo.PackHeader WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo

            SELECT @cCartonTypeDesc = LEFT( CartonDescription, 4) 
            FROM dbo.CARTONIZATION WITH (NOLOCK) 
            WHERE CartonType = @cCartonType

            SELECT @cUserCartonTypeDesc = LEFT( CartonDescription, 4) 
            FROM dbo.CARTONIZATION WITH (NOLOCK) 
            WHERE CartonType = @cUserCartonType
            
            IF @cUserCartonTypeDesc = 'HARD' AND @cCartonTypeDesc = 'HARD'
            BEGIN
               -- Insert Transmitlog2 when carton type is different
               IF @cCartonType <> @cUserCartonType
                 SET @nInsertTL2 = 1
            END
            ELSE
            BEGIN
               IF ( @cUserCartonTypeDesc = 'HARD' AND @cCartonTypeDesc = 'SOFT') OR 
                  ( @cUserCartonTypeDesc = 'SOFT' AND @cCartonTypeDesc = 'HARD')
               BEGIN 
                  SET @nInsertTL2 = 1
               END
               ELSE
               BEGIN
                  IF @cUserCartonTypeDesc = 'SOFT' AND @cCartonTypeDesc = 'SOFT'
                  BEGIN
                     SET @nInsertTL2 = 0
                  END
               END
            END
         END
         ELSE
            SET @nInsertTL2 = 1  -- Carton no > 1 need insert Transmitlog2

         IF @nCartonNo = 1
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.TRANSMITLOG2 WITH (NOLOCK) 
                            WHERE tablename = 'WSCRSOREQMP' 
                            AND   key1 = @cOrderKey 
                            AND   key3 = @cStorerkey)
               SET @nInsertTL2 = 1
         END
         
         IF @nInsertTL2 = 1 
         BEGIN
            -- Insert transmitlog2 here
            EXECUTE ispGenTransmitLog2 
               @c_TableName      = 'WSCRSOADDMP', 
               @c_Key1           = @cOrderKey, 
               @c_Key2           = @nCartonNo, 
               @c_Key3           = @cStorerkey, 
               @c_TransmitBatch  = '', 
               @b_Success        = @bSuccess   OUTPUT,    
               @n_err            = @nErrNo     OUTPUT,    
               @c_errmsg         = @cErrMsg    OUTPUT    

            IF @bSuccess <> 1    
               GOTO RollBackTran

            SELECT @cTransmitLogKey = transmitlogkey
            FROM dbo.TRANSMITLOG2 WITH (NOLOCK)
            WHERE tablename = 'WSCRSOADDMP'
            AND   key1 = @cOrderKey
            AND   key2 = @nCartonNo
            AND   key3 = @cStorerkey
            
            EXEC dbo.isp_QCmd_WSTransmitLogInsertAlert 
               @c_QCmdClass         = @c_QCmdClass, 
               @c_FrmTransmitlogKey = @cTransmitLogKey, 
               @c_ToTransmitlogKey  = @cTransmitLogKey, 
               @b_Debug             = @b_Debug, 
               @b_Success           = @bSuccess    OUTPUT, 
               @n_Err               = @nErrNo      OUTPUT, 
               @c_ErrMsg            = @cErrMsg     OUTPUT 

            IF @bSuccess <> 1    
               GOTO RollBackTran

            IF @nCartonNo = 1
            BEGIN
               UPDATE dbo.PackHeader SET 
                  ConsoOrderKey = '', 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME()
               WHERE PickSlipNo = @cPickSlipNo
               SET @nErrNo = @@ERROR
               
               IF @nErrNo <> 0
                  GOTO RollBackTran
            END
            
            GOTO Quit
         END
      END
   END  
  
   GOTO Quit  
  
   RollBackTran:  
         ROLLBACK TRAN rdt_840ExtUpd10  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  

   Fail:  

GO