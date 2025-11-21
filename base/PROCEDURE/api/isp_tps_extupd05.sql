SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/******************************************************************************/        
/* Store procedure: isp_TPS_ExtUpd05                                          */        
/* Copyright      : LFLogistics                                               */        
/*                                                                            */        
/* Date         Rev  Author     Purposes                                      */        
/* 2025-01-21   1.0  yeekung    TPS-970 Created                               */ 
/******************************************************************************/        
        
CREATE    PROC [API].[isp_TPS_ExtUpd05] (        
   @cStorerKey      NVARCHAR( 15),      
   @cFacility       NVARCHAR( 5),        
   @nFunc           INT,            
   @cUserName       Nvarchar( 128),      
   @cLangCode       NVARCHAR( 3),       
   @cScanNo         NVARCHAR( 50),      
   @cpickslipNo     NVARCHAR( 30),      
   @cDropID         NVARCHAR( 50),      
   @cOrderKey       NVARCHAR( 10),      
   @cLoadKey        NVARCHAR( 10),      
   @cZone           NVARCHAR( 18),      
   @EcomSingle      NVARCHAR( 1),       
   @nCartonNo       INT,            
   @cCartonType     NVARCHAR( 10),       
   @cType           NVARCHAR( 30),       
   @fCartonWeight   FLOAT,           
   @fCartonCube     FLOAT,           
   @cWorkstation    NVARCHAR( 30),       
   @cLabelNo        NVARCHAR( 20),      
   @cCloseCartonJson   NVARCHAR (MAX),   
   @pickSkuDetailJson  NVARCHAR (MAX),   
   @b_Success       INT = 1        OUTPUT,      
   @n_Err           INT = 0        OUTPUT,      
   @c_ErrMsg        NVARCHAR( 255) = ''  OUTPUT       
)        
AS        
        
SET NOCOUNT ON        
SET QUOTED_IDENTIFIER OFF        
SET ANSI_NULLS OFF        
SET CONCAT_NULL_YIELDS_NULL OFF        
         
DECLARE   @cJITOrders         NVARCHAR(20),
         @nPickslipPackQty INT,
         @nPickslipPickQty INT,
         @cCartonNo         NVARCHAR(5),
         @nTranCount         INT,
         @bSuccess         INT,
         @b_Debug            INT

DECLARE @cTransmitLogKey      NVARCHAR(20)
DECLARE @c_QCmdClass          NVARCHAR(10)   = ''  
        
DECLARE @CloseCtnList TABLE (     
   UCC             NVARCHAR( 30),  
   SKU             NVARCHAR( 20),      
   QTY             INT,      
   Weight          FLOAT,      
   Cube            FLOAT,        
   lottableVal     NVARCHAR(60),      
   SkuBarcode      NVARCHAR(60),      
   ADCode          NVARCHAR(60)      
)      
    
DECLARE @pickSKUDetail TABLE (  
   SKU              NVARCHAR( 30),    
   QtyToPack        INT,  
   OrderKey         NVARCHAR( 30),  
   PickslipNo       NVARCHAR( 30),  
   LoadKey          NVARCHAR( 30),--externalOrderKey  
   PickDetailStatus NVARCHAR ( 3)  
)  

--INSERT INTO @CloseCtnList      
--SELECT *      
--FROM OPENJSON(@cCloseCartonJson)      
--WITH (      
--   SKU             NVARCHAR( 20) '$.SKU',      
--   Qty             INT           '$.PackedQty',      
--   Weight          Float         '$.WEIGHT',      
--   Cube            Float         '$.CUBE',      
--   lottableValue   NVARCHAR(60)  '$.Lottable',       
--   SkuBarcode      NVARCHAR( 60) '$.SkuBarcode'       
--)      
INSERT INTO @CloseCtnList (UCC,SKU, QTY, WEIGHT, CUBE, lottableVal,SkuBarcode, ADCode)      
SELECT     
HDR.UCC  
, Hdr.SKU      
, Hdr.Qty      
, Hdr.Weight      
, Hdr.Cube      
, Hdr.lottableValue      
, Det.barcodeVal      
, Det.AntiDiversionCode      
FROM OPENJSON(@cCloseCartonJson)      
WITH (      
   UCC            NVARCHAR( 30)  '$.UCC',    
   SKU            NVARCHAR( 20)  '$.SKU',      
   Qty            INT            '$.PackedQty',      
   Weight         FLOAT          '$.WEIGHT',      
   Cube           FLOAT          '$.CUBE',      
   lottableValue  NVARCHAR(60)   '$.Lottable',       
   barcodeObj     NVARCHAR(MAX)  '$.barcodeObj' AS JSON       
) AS Hdr      
OUTER APPLY OPENJSON(barcodeObj)      
WITH (      
   barcodeVal        NVARCHAR(60) '$.barcodeVal',      
   AntiDiversionCode NVARCHAR(60) '$.AntiDiversionCode'      
) AS Det      

INSERT INTO @pickSKUDetail  
SELECT *  
FROM OPENJSON(@pickSkuDetailJson)  
WITH (  
   SKU               NVARCHAR( 20)  '$.SKU',  
   QtyToPack         INT            '$.QtyToPack',  
   OrderKey          NVARCHAR( 10)  '$.OrderKey',  
   PickslipNo        NVARCHAR( 30)  '$.PickslipNo',  
   LoadKey           NVARCHAR( 10)  '$.LoadKey',  
   PickDetailStatus  NVARCHAR( 1)   '$.PickDetailStatus'  
)  
       
--SELECT 'aa',* FROM @CloseCtnList      
BEGIN      
   SET @nTranCount = @@TRANCOUNT      
   BEGIN TRAN      
   SAVE TRAN isp_TPS_ExtUpd05   

   SELECT @cOrderKey = OrderKey
   FROM PickHeader (NOLOCK)
   WHERE PickHeaderkey = @cPickSlipNo

   EXEC nspGetRight    
      @c_Facility   = @cFacility   
   ,  @c_StorerKey  = @cStorerKey   
   ,  @c_sku        = ''    
   ,  @c_ConfigKey  = 'TPS-JITOrders'    
   ,  @b_Success    = @b_Success       OUTPUT    
   ,  @c_authority  = @cJITOrders      OUTPUT    
   ,  @n_err        = @n_Err           OUTPUT    
   ,  @c_errmsg     = @c_ErrMsg        OUTPUT  
   
   IF ISNULL(@cJITOrders,'') = '1'
   BEGIN
      IF NOT EXISTS (SELECT 1
                     FROM Transmitlog2 (NOLOCK)
                     WHERE TableName = 'WSCRSOLBLJTV2'
                        AND Key1 = @cOrderkey 
                        AND Key2 = (@nCartonNo + 1)
                        AND Key3 = @cStorerKey)
      BEGIN
         SELECT @nPickslipPackQty = ISNULL(SUM(PD.Qty),0)   
         FROM PackDetail PD WITH (NOLOCK)   
         JOIN packInfo PKI WITH (NOLOCK) ON (PD.PickSlipNo = PKI.PickSlipNo AND PD.CartonNo = PKI.CartonNo)  
         WHERE PD.pickslipno = @cPickSlipNo 
            AND PD.Storerkey = @cStorerKey 
            AND PKI.CartonStatus = 'Closed'  
         
         SELECT @nPickslipPickQty = SUM(QtyToPack) 
         FROM @pickSKUDetail 
         WHERE pickslipNo = @cPickSlipNo  

         IF @nPickslipPackQty <> @nPickslipPickQty
         BEGIN
            SET @cCartonNo = CAST(@nCartonNo + 1 AS NVARCHAR(5) )

            -- Insert transmitlog2 here  
            EXECUTE ispGenTransmitLog2   
               @c_TableName      = 'WSCRSOLBLJTV2',   
               @c_Key1           = @cOrderKey,   
               @c_Key2           = @cCartonNo,   
               @c_Key3           = @cStorerkey,   
               @c_TransmitBatch  = '',   
               @b_Success        = @bSuccess      OUTPUT,      
               @n_err            = @n_Err         OUTPUT,      
               @c_errmsg         = @c_ErrMsg    OUTPUT      
      
            IF @bSuccess <> 1      
               GOTO QUIT  
      
            SELECT @cTransmitLogKey = transmitlogkey  
            FROM dbo.TRANSMITLOG2 WITH (NOLOCK)  
            WHERE tablename = 'WSCRSOLBLJTV2'  
               AND   key1 = @cOrderKey
               AND   key2 = @cCartonNo
               AND   key3 = @cStorerkey  

            EXEC dbo.isp_QCmd_WSTransmitLogInsertAlert   
               @c_QCmdClass         = @c_QCmdClass,   
               @c_FrmTransmitlogKey = @cTransmitLogKey,   
               @c_ToTransmitlogKey  = @cTransmitLogKey,   
               @b_Debug             = @b_Debug,   
               @b_Success           = @bSuccess         OUTPUT,   
               @n_Err               = @n_Err            OUTPUT,   
               @c_ErrMsg            = @c_ErrMsg         OUTPUT   

            IF @bSuccess <> 1      
               GOTO QUIT  
                  
         END

      END
   END

   GOTO Quit      
       
 RollBackTran:      
      ROLLBACK TRAN isp_TPS_ExtUpd05      
      
   Quit:      
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      BEGIN  
         COMMIT TRAN isp_TPS_ExtUpd05      
         SET @b_Success = '1'    
      END  
      
END        

GO