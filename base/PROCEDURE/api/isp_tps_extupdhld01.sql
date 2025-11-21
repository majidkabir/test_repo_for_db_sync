SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

    
/******************************************************************************/      
/* Store procedure: isp_TPS_ExtUpdHld01                                       */      
/* Copyright      : LFLogistics                                               */      
/*                                                                            */      
/* Date         Rev  Author     Purposes                                      */      
/* 2023-05-30   1.0  YeeKung  TPS-735 Created                                 */ 
/* 2025-01-28   1.1  YeeKung    UWP-29489 Change API Username (yeekung01)     */     
/******************************************************************************/      
      
CREATE   PROC [API].[isp_TPS_ExtUpdHld01] (      
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
   @cHoldCartonJson   NVARCHAR (MAX),    
   @b_Success       INT = 1        OUTPUT,    
   @n_Err           INT = 0        OUTPUT,    
   @c_ErrMsg        NVARCHAR( 255) = ''  OUTPUT     
)      
AS      
      
SET NOCOUNT ON      
SET QUOTED_IDENTIFIER OFF      
SET ANSI_NULLS OFF      
SET CONCAT_NULL_YIELDS_NULL OFF      
    
DECLARE @curAD CURSOR    
DECLARE     
   @cSKU             NVARCHAR(20),    
   @cSkuBarcode      NVARCHAR(60),    
   @cOrderLineNumber NVARCHAR(5),
   @cLblLineNumber   NVARCHAR(5),
   @cWeight          NVARCHAR(10),    
   @cCube            NVARCHAR(10),    
   @cLottableVal     NVARCHAR(20),    
   @cSerialNoKey     NVARCHAR(60),    
   @cErrMsg          NVARCHAR(128),    
   @cSerialNo        NVARCHAR(60),    
   @cADCode          NVARCHAR(60),    
   @nQty             INT,  
   @nSNQTY           INT,
   @bsuccess         INT,    
   @nErrNo           INT,    
   @nTranCount       INT    

DECLARE @nNumberOfAD    INT
DECLARE @nCounter       INT = 1
DECLARE @cOtherUnit2    INT
DECLARE @nPackQTY       INT
       
DECLARE @CloseCtnList TABLE (    
   SKU             NVARCHAR( 20),    
   QTY             INT,    
   Weight          FLOAT,    
   Cube            FLOAT,      
   lottableVal     NVARCHAR(60),    
   SkuBarcode      NVARCHAR(60),    
   ADCode          NVARCHAR(60)    
)    
    
    
--INSERT INTO @CloseCtnList    
--SELECT *    
--FROM OPENJSON(@cHoldCartonJson)    
--WITH (    
--   SKU             NVARCHAR( 20) '$.SKU',    
--   Qty             INT           '$.PackedQty',    
--   Weight          Float         '$.WEIGHT',    
--   Cube            Float         '$.CUBE',    
--   lottableValue   NVARCHAR(60)  '$.Lottable',     
--   SkuBarcode      NVARCHAR( 60) '$.SkuBarcode'     
--)    
INSERT INTO @CloseCtnList (SKU, QTY, WEIGHT, CUBE, lottableVal,SkuBarcode, ADCode)    
SELECT     
Hdr.SKU    
, Hdr.Qty    
, Hdr.Weight    
, Hdr.Cube    
, Hdr.lottableValue    
, Det.barcodeVal    
, Det.AntiDiversionCode    
FROM OPENJSON(@cHoldCartonJson)    
WITH (    
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
     
--SELECT 'aa',* FROM @CloseCtnList    
BEGIN    
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN    
   SAVE TRAN isp_TPS_ExtUpdHld01     
    
   IF @cOrderKey <> ''    
   BEGIN    
      IF EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK) WHERE Listname = 'REQEXP'AND Code ='ADBARCODE' AND storerKey = @cStorerKey)    
      BEGIN    
         SELECT @nNumberOfAD =COUNT(ADCode)
         FROM @CloseCtnList    
         WHERE (SkuBarcode <> '' OR ADCode <> '')

         SELECT @nPackQTY =QTY
         FROM @CloseCtnList    
         WHERE (SkuBarcode <> '' OR ADCode <> '')

         SET @curAD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT SKU,SkuBarcode,ADCode,QTY  
         FROM @CloseCtnList    
         WHERE (SkuBarcode <> '' OR ADCode <> '')    
       
         OPEN @curAD    
         FETCH NEXT FROM @curAD INTO @cSKU, @cSkuBarcode, @cADCode,@nQty  
         WHILE @@FETCH_STATUS <> -1    
         BEGIN    
            SELECT @cOtherUnit2 = Pack.OtherUnit2
            FROM SKU SKU (NOLOCK)
               JOIN PACK PACK (NOLOCK) ON SKU.PACKKey = PACK.PackKey
            WHERE  SKU.SKU = @cSKU
               AND SKU.StorerKey = @cStorerKey

            IF @nCounter <> @nNumberOfAD
            BEGIN
               SET @nQty =@cOtherUnit2
               SET @nPackQTY = @nPackQTY - @cOtherUnit2
            END
            ELSE
               SET @nQty = @nPackQTY 

            IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE storerKey = @cStorerKey AND SKU = @cSKU AND susr4 = 'AD')    
            BEGIN    
               IF @cSkuBarcode <> ''    
               BEGIN    
                  SET @cSerialNo = @cSkuBarcode    
               END    
               ELSE    
               BEGIN    
                  SET @cSerialNo = @cADCode    
               END    
    
               IF NOT EXISTS ( SELECT 1 FROM SerialNo WITH (NOLOCK)      
                           WHERE StorerKEy = @cStorerKey      
                           AND SKU = @cSKU      
                           AND SerialNo = @cSerialNo )      
               BEGIN      
                  EXECUTE dbo.nspg_GetKey      
                           'SerialNo',      
                           10 ,      
                           @cSerialNoKey      OUTPUT,      
                           @bsuccess          OUTPUT,      
                           @nErrNo            OUTPUT,      
                           @cErrMsg           OUTPUT      
                     
                  IF @bsuccess <> 1      
                  BEGIN      
                     SET @n_Err = 175737      
                     SET @c_ErrMsg = rdt.rdtgetmessage(@n_Err ,@cLangCode ,'DSP') -- 'Fail to get SerialNo Key. Function : isp_TPS_ExtUpdHld01'      
                     GOTO RollBackTran      
                  END      
                      
                  SELECT @cOrderLineNumber = PD.OrderLineNumber       
                       -- ,@nQty             = PD.Qty      
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                  WHERE PD.StorerKey = @cStorerKey      
                  AND PD.OrderKey = @cOrderKey      
                  AND PD.SKU = @cSKU       
                  AND PD.OrderLineNumber Not IN ( SELECT S.OrderLineNumber FROM       
                                                   dbo.SerialNo S WITH (NOLOCK)       
                                                   WHERE S.OrderKey = @cOrderKey      
                                                   AND S.OrderLineNumber = PD.OrderLineNUmber      
                                                   AND S.SKU = @cSKU  )       
                     
                  SET @nQty = CASE WHEN ISNULL(@nQty,'') IN(0,'') then 1 ELSE @nQty END 
                  

                   SELECT @cLblLineNumber = PD.LabelLine  
                  FROM dbo.Packheader PH WITH (NOLOCK)    JOIN
                  dbo.packdetail PD(nolock) ON PH.PickSlipNo=PD.PickSlipNo
                  WHERE PD.StorerKey = @cStorerKey      
                  AND PH.OrderKey = @cOrderKey      
                  AND PD.SKU = @cSKU    
                  AND PD.CartonNo = @nCartonNo
    

 
                  INSERT INTO PackSerialNo(pickslipno,cartonno,labelno,labelline,storerkey,sku,serialno,qty,AddWho,AddDate,EditWho,EditDate)    
                  values(@cpickslipNo,@nCartonNo,@cLabelNo,@cLblLineNumber,@cStorerKey,@csku,@cSerialNo,@nQty,@cUserName,GETDATE(),@cUserName,GETDATE())    
    
                  IF @@ERROR <> 0       
                  BEGIN       
                     SET @n_Err = 175738      
                     SET @c_ErrMsg = rdt.rdtgetmessage(@n_Err ,@cLangCode ,'DSP') -- 'Fail to Insert SerialNo table. Function : isp_TPS_ExtUpdHld01'      
                     GOTO RollBackTran      
                  END      
                  
                  INSERT INTO SerialNo (SerialNoKey, OrderKey, OrderLineNumber, StorerKey, SKU, SerialNo, Qty, status,AddWho,AddDate,EditWho,EditDate )       
                  VALUES ( @cSerialNoKey, @cOrderKey, ISNULL(@cOrderLineNumber,''), @cStorerKey, @cSKU , @cSerialNo , @nQty, '1' ,@cUserName,GETDATE(),@cUserName,GETDATE())       

                  IF @@ERROR <> 0       
                  BEGIN       
                     SET @n_Err = 175738      
                     SET @c_ErrMsg = rdt.rdtgetmessage(@n_Err ,@cLangCode ,'DSP') -- 'Fail to Insert SerialNo table. Function : isp_TPS_ExtUpdHld01'      
                     GOTO RollBackTran      
                  END      
               END      
               ELSE IF EXISTS (SELECT 1 FROM SerialNo WITH (NOLOCK)      
                           WHERE StorerKEy = @cStorerKey      
                           AND OrderKey = ''      
                           AND SKU = @cSKU      
                           AND SerialNo = @cSerialNo )      
               BEGIN    
                  SELECT @cOrderLineNumber = PD.OrderLineNumber       
                        ,@nQty             = PD.Qty      
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                  WHERE PD.StorerKey = @cStorerKey      
                  AND PD.OrderKey = @cOrderKey      
                  AND PD.SKU = @cSKU       
                  AND PD.OrderLineNumber Not IN ( SELECT S.OrderLineNumber FROM       
                                                   dbo.SerialNo S WITH (NOLOCK)       
                                                   WHERE S.OrderKey = @cOrderKey      
                                                   AND S.OrderLineNumber = PD.OrderLineNUmber      
                                                   AND S.SKU = @cSKU  )  
                                                   
                  SELECT @cLblLineNumber = PD.LabelLine  
                  FROM dbo.Packheader PH WITH (NOLOCK)    JOIN
                  dbo.packdetail PD(nolock) ON PH.PickSlipNo=PD.PickSlipNo
                  WHERE PD.StorerKey = @cStorerKey      
                  AND PH.OrderKey = @cOrderKey      
                  AND PD.SKU = @cSKU    
                  AND PD.CartonNo = @nCartonNo
    
                  IF NOT EXISTS(select 1 from packserialno (nolock)    
                        where pickslipno=@cpickslipNo    
                        and storerkey=@cStorerKey    
                        and sku=@csku
                        and serialno=@cSerialNo)    
                  BEGIN   
  
                     SET @nQty = CASE WHEN ISNULL(@nQty,'') IN(0,'') then 1 ELSE @nQty END  

                     SELECT @nSNQTY=qty
                     FROM SerialNo (NOLOCK)
                     WHERE StorerKEy = @cStorerKey      
                     AND OrderKey = ''      
                     AND SKU = @cSKU      
                     AND SerialNo = @cSerialNo 

                     INSERT INTO PackSerialNo(pickslipno,cartonno,labelno,labelline,storerkey,SerialNo,sku,qty,AddWho,AddDate,EditWho,EditDate)    
                     values(@cpickslipno,@nCartonNo,@cLabelNo,@cLblLineNumber,@cStorerKey,@cserialno,@csku,@nSNQTY,@cUserName,GETDATE(),@cUserName,GETDATE())    
    
                     IF @@ERROR <> 0       
                     BEGIN       
                        SET @n_Err = 175738      
                        SET @c_ErrMsg = rdt.rdtgetmessage(@n_Err ,@cLangCode ,'DSP') -- 'Fail to Insert SerialNo table. Function : isp_TPS_ExtUpdHld01'      
                        GOTO RollBackTran      
                     END      
                  END    

                  UPDATE SerialNo WITH (ROWLOCK) SET    
                     OrderKey = @cOrderKey,    
                     OrderLineNumber = ISNULL(@cOrderLineNumber,''),    
                     STATUS = '6' ,  
                     EditDate = GETDATE(),  
                     EditWho = @cUserName   
                  WHERE StorerKEy = @cStorerKey      
                  AND OrderKey = ''      
                  AND SKU = @cSKU      
                  AND SerialNo = @cSerialNo    
                      
                  IF @@ERROR <> 0       
                  BEGIN       
                     SET @n_Err = 175739      
                     SET @c_ErrMsg = rdt.rdtgetmessage(@n_Err ,@cLangCode ,'DSP') -- 'Fail to Update SerialNo table. Function : isp_TPS_ExtUpdHld01'      
                     GOTO RollBackTran      
                  END      
               END    
            END    
            
            SET @nCounter = @nCounter + 1

            FETCH NEXT FROM @curAD INTO @cSKU, @cSkuBarcode, @cADCode ,@nQty     
         END  


      END    
   END    
 GOTO Quit    
     
 RollBackTran:    
      ROLLBACK TRAN isp_TPS_ExtUpdHld01    
    
   Quit:    
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      BEGIN
         COMMIT TRAN isp_TPS_ExtUpdHld01    
         SET @b_Success = '1'  
      END
    
END      

GO