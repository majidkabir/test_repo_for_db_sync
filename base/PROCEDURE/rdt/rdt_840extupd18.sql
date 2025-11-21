SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_840ExtUpd18                                     */  
/* Purpose: If config turn on, 1 order only allow pack to 1 carton      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author     Purposes                                 */  
/* 2021-11-17  1.0  James      WMS-18321. Created                       */ 
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_840ExtUpd18] (  
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
   DECLARE @cCartonType          NVARCHAR( 10)
   DECLARE @bSuccess             INT
   DECLARE @cTransmitLogKey      NVARCHAR( 10)
   DECLARE @c_QCmdClass          NVARCHAR(10)   = ''   
   DECLARE @b_Debug              INT = 0
   DECLARE @cUserCartonTypeDesc  NVARCHAR(10)
   DECLARE @nExpectedQty         INT = 0
   DECLARE @nPackedQty           INT = 0
   DECLARE @fCartonWeight        FLOAT = 0
   DECLARE @fSTDGROSSWGT         FLOAT = 0
   DECLARE @fTotalCartonWGT      FLOAT = 0
   DECLARE @cErrMsg1             NVARCHAR( 20) = ''
   DECLARE @cWeightChk           NVARCHAR( 10)  
   DECLARE @cWeightMax           NVARCHAR( 5)  
   DECLARE @cWeightMin           NVARCHAR( 5)  
   DECLARE @cShipperKey          NVARCHAR( 15)  
   DECLARE @cOrdType             NVARCHAR( 10)  
   DECLARE @cPmtTerm             NVARCHAR( 10)  
   DECLARE @cPickDetailKey       NVARCHAR( 10)
   DECLARE @curUpdQtyMoved       CURSOR
     
   SET @nTranCount = @@TRANCOUNT  
  
   BEGIN TRAN  
   SAVE TRAN rdt_840ExtUpd18  
   
   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SET @curUpdQtyMoved = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT PickDetailKey 
         FROM dbo.PICKDETAIL WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey
         AND   QtyMoved > 0
         OPEN @curUpdQtyMoved
         FETCH NEXT FROM @curUpdQtyMoved INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.PickDetail SET
               QtyMoved = 0, 
               EditWho = SUSER_SNAME(), 
               EditDate = GETDATE()
            WHERE PickDetailKey = @cPickDetailKey
            
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 179054
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdQtyMovedEr'    
               GOTO RollBackTran
            END   
            
            FETCH NEXT FROM @curUpdQtyMoved INTO @cPickDetailKey
         END
      END
   END
   
   IF @nStep = 3
   BEGIN
      IF @nInputKey = 0
      BEGIN
         -- Only for customer orders. Move orders always can pack into multi carton
         IF EXISTS ( SELECT 1 FROM dbo.ORDERS WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND ECOM_SINGLE_Flag <> '')
         BEGIN
            IF rdt.rdtGetConfig( @nFunc, 'OrderNotAllowMultiCtn', @cStorerKey) = 1      
            BEGIN
            SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)
            WHERE Orderkey = @cOrderkey
            AND   Storerkey = @cStorerkey
            AND   Status < '9'

            SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            
            IF @nExpectedQty <> @nPackedQty
            BEGIN
               SET @nErrNo = 179051
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'1 Order 1 Ctn'    
               GOTO Quit
            END            
            
            IF EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)
                        WHERE PickSlipNo = @cPickSlipNo
                        AND   CartonNo = @nCartonNo)
            BEGIN
               SELECT @cShipperKey = ShipperKey,  
                      @cOrdType = [Type],   
                      @cPmtTerm = PmtTerm  
               FROM dbo.ORDERS WITH (NOLOCK)  
               WHERE OrderKey = @cOrderKey  
         
               SELECT @cWeightChk = UDF04   
               FROM dbo.CODELKUP WITH (NOLOCK)  
               WHERE ListName = 'HMCOURIER'  
               AND   Storerkey = @cStorerkey  
               AND   Code = @cShipperKey  
               AND   Long = @cOrdType  
               AND   UDF01 = @cPmtTerm  
               
               IF ISNULL( @cWeightChk, '') <> '' AND CHARINDEX( '_', @cWeightChk) > 0  
               BEGIN  
                  SELECT @cWeightMin = LEFT( @cWeightChk, CHARINDEX( '_', @cWeightChk) - 1)  
                  SELECT @cWeightMax = RIGHT( @cWeightChk, CHARINDEX( '_', @cWeightChk) - 1)  
              
                  SELECT @cCartonType = CartonType
                  FROM dbo.PackInfo WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo
                  AND   CartonNo = @nCartonNo 

                  SELECT @fCartonWeight = CartonWeight 
                  FROM dbo.CARTONIZATION WITH (NOLOCK) 
                  WHERE CartonType = @cCartonType

                  SELECT @fSTDGROSSWGT = ISNULL( SUM( SKU.STDGROSSWGT * PD.Qty), 0)
                  FROM dbo.PACKDETAIL PD WITH (NOLOCK)
                  JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.Storerkey = SKU.StorerKey AND PD.Sku = SKU.Sku) 
                  WHERE PD.PickSlipNo = @cPickSlipNo
                  AND   PD.CartonNo = @nCartonNo 
         
                  SET @fTotalCartonWGT = @fCartonWeight + @fSTDGROSSWGT
         
                  IF @fTotalCartonWGT > CAST( @cWeightMax AS FLOAT) 
                  BEGIN
                     SET @nErrNo = 179052
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Over Weight'    
                     GOTO Quit
                  END
               END 
            END
         END
         END
      END
   END
   
   IF @nStep = 4  
   BEGIN  
      IF @nInputKey = 1 
      BEGIN  
         SELECT @cShipperKey = ShipperKey,  
                  @cOrdType = [Type],   
                  @cPmtTerm = PmtTerm  
         FROM dbo.ORDERS WITH (NOLOCK)  
         WHERE OrderKey = @cOrderKey  
         
         SELECT @cWeightChk = UDF04   
         FROM dbo.CODELKUP WITH (NOLOCK)  
         WHERE ListName = 'HMCOURIER'  
         AND   Storerkey = @cStorerkey  
         AND   Code = @cShipperKey  
         AND   Long = @cOrdType  
         AND   UDF01 = @cPmtTerm  
               
         IF ISNULL( @cWeightChk, '') <> '' AND CHARINDEX( '_', @cWeightChk) > 0  
         BEGIN  
            SELECT @cWeightMin = LEFT( @cWeightChk, CHARINDEX( '_', @cWeightChk) - 1)  
            SELECT @cWeightMax = RIGHT( @cWeightChk, CHARINDEX( '_', @cWeightChk) - 1)  
                  
            SELECT @cCartonType = CartonType
            FROM dbo.PackInfo WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            AND   CartonNo = @nCartonNo 

            SELECT @fCartonWeight = CartonWeight 
            FROM dbo.CARTONIZATION WITH (NOLOCK) 
            WHERE CartonType = @cCartonType

            SELECT @fSTDGROSSWGT = ISNULL( SUM( SKU.STDGROSSWGT * PD.Qty), 0)
            FROM dbo.PACKDETAIL PD WITH (NOLOCK)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.Storerkey = SKU.StorerKey AND PD.Sku = SKU.Sku) 
            WHERE PD.PickSlipNo = @cPickSlipNo
            AND   PD.CartonNo = @nCartonNo 
         
            SET @fTotalCartonWGT = @fCartonWeight + @fSTDGROSSWGT
         
            IF @fTotalCartonWGT >= CAST( @cWeightMin AS FLOAT) AND  
               @fTotalCartonWGT < CAST( @cWeightMax AS FLOAT)   
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg1 = rdt.rdtgetmessage( 179053, @cLangCode, 'DSP')
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
               IF @nErrNo = 1
                  SET @cErrMsg1 = ''

               SET @nErrNo = 0
               SET @cErrMsg = ''
            END
         END
         
         -- Insert transmitlog2 here
         EXECUTE ispGenTransmitLog2 
            @c_TableName      = 'WSCRRDTMTE', 
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
         WHERE tablename = 'WSCRRDTMTE'
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
      END
   END  
   
   GOTO Quit  
  
   RollBackTran:  
         ROLLBACK TRAN rdt_840ExtUpd18  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  

   Fail:  

GO