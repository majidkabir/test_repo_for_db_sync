SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: isp_TPS_ExtUpd04                                          */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2024-02-27   1.0  YeeKung    TPS-885 Created                               */
/* 2024-06-06   1.1  YeeKung    INC6918718 remove skubarcode (yeekung01)		*/ 
/* 2025-01-28   1.2  YeeKung    UWP-29489 Change API Username (yeekung03)     */
/* 2025-01-22   1.3  YeeKung    TPS-970 Add New Params (yeekung04)            */
/******************************************************************************/

CREATE   PROC [API].[isp_TPS_ExtUpd04] (
	@cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @nFunc           INT,
   @cUserName       Nvarchar( 128),
   @cLangCode       NVARCHAR( 3),
   @cScanNo         NVARCHAR( 50),
   @cPickSlipNo     NVARCHAR( 30),
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

DECLARE @curAD CURSOR
DECLARE
	@cSKU             NVARCHAR(20),
   @cSkuBarcode      NVARCHAR(MAX),
   @cOrderLineNumber NVARCHAR(5),
   @cSerialNo        NVARCHAR(50),
   @cWeight          NVARCHAR(10),
   @cCube            NVARCHAR(10),
   @cLottableVal     NVARCHAR(20),
   @cSerialNoKey     NVARCHAR(60),
   @cErrMsg          NVARCHAR(128),
   @cSerialSKU       NVARCHAR(60),
   @cADCode          NVARCHAR(MAX),
   @cLabelLine       NVARCHAR(20),
   @nQty             INT,
   @bsuccess         INT,
   @nErrNo           INT,
   @nTranCount       INT

DECLARE @CloseCtnList TABLE (
   SKU             NVARCHAR( 20),
   QTY             INT,
   Weight          FLOAT,
   Cube            FLOAT,
   lottableVal     NVARCHAR(60),
   SkuBarcode      NVARCHAR(MAX),
   ADCode          NVARCHAR(MAX)
)


INSERT INTO @CloseCtnList (SKU, QTY, WEIGHT, CUBE, lottableVal,SkuBarcode, ADCode)
SELECT
Hdr.SKU
, Hdr.Qty
, Hdr.Weight
, Hdr.Cube
, Hdr.lottableValue
, Det.barcodeVal
, Det.AntiDiversionCode
FROM OPENJSON(@cCloseCartonJson)
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

BEGIN
	SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN isp_TPS_ExtUpd04

	SET @curAD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT SKU,SkuBarcode,ADCode
   FROM @CloseCtnList
   WHERE (SkuBarcode <> '' OR ADCode <> '')

   OPEN @curAD
   FETCH NEXT FROM @curAD INTO @cSKU, @cSkuBarcode, @cADCode
   WHILE @@FETCH_STATUS <> -1
   BEGIN

      SET @cSerialNo = RIGHT( RTRIM(@cADCode),13)  + FORMAT(GETDATE(), 'yyyyMMddHHmmssfff')--Right 13 chars

      IF @cSerialNo <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM SerialNo WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
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
               SET @n_Err = 175740
               SET @c_ErrMsg = rdt.rdtgetmessage(@n_Err ,@cLangCode ,'DSP') -- 'Fail to get SerialNo Key. Function : isp_TPS_ExtUpd04'
               GOTO RollBackTran
            END

            
            SELECT @cOrderLineNumber = PD.OrderLineNumber
                  ,@cOrderKey        = PD.Orderkey
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN Orders O WITH (NOLOCK) ON PD.Orderkey = O.Orderkey AND PD.Storerkey = O.Storerkey
            WHERE PD.StorerKey = @cStorerKey
               AND O.Loadkey = @cLoadKey
               AND PD.SKU = @cSKU

                                                   
            SELECT @cLabelLine = PD.LabelLine  
            FROM dbo.Packheader PH WITH (NOLOCK)    
               JOIN dbo.packdetail PD(nolock) ON PH.PickSlipNo=PD.PickSlipNo
            WHERE PD.StorerKey = @cStorerKey      
               AND PH.Loadkey  = @cLoadKey      
               AND PD.SKU = @cSKU        


            INSERT INTO SerialNo (SerialNoKey,Orderkey, Orderlinenumber, StorerKey, SKU, SerialNo, Qty,pickslipno,CartonNo,status,AddWho,AddDate,EditWho,EditDate)
            VALUES ( @cSerialNoKey,@cOrderKey,@cOrderLineNumber, @cStorerKey, @cSKU , @cSerialNo , 1,@cPickSlipNo,@nCartonNo,'6',@cUserName,GETDATE(),@cUserName,GETDATE())

            select top 10 * from serialno (nolock) where serialno=@cSerialNo--'AIG59KOJ00324'

            IF @@ERROR <> 0
            BEGIN
               SET @n_Err = 1000401
               SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'1000401 Err Insert SerialNO Function : isp_TPS_ExtUpd04' 
               GOTO RollBackTran
            END

            INSERT INTO PackSerialNo(Pickslipno,cartonno,labelno,labelline,storerkey,sku,serialno,qty,Barcode,AddWho,AddDate,EditWho,EditDate)    
            values(@cPickSlipNo,@nCartonNo,@cLabelNo,@cLabelLine,@cStorerKey,@cSKU,@cSerialNo,1,@cADCode,@cUserName,GETDATE(),@cUserName,GETDATE())    
    
            IF @@ERROR <> 0
            BEGIN
               SET @n_Err = 1000402
               SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'1000401 Err Insert SerialNO Function : isp_TPS_ExtUpd04' 
               GOTO RollBackTran
            END   
         END
      END
      FETCH NEXT FROM @curAD INTO @cSKU, @cSkuBarcode, @cADCode
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN isp_TPS_ExtUpd04

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN isp_TPS_ExtUpd04
         SET @b_Success = '1'
END

GO