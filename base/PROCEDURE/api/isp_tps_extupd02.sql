SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: isp_TPS_ExtUpd02                                          */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2021-10-25   1.0  Chermaine  TPS-597 Created                               */
/* 2025-01-22   1.1  YeeKung    TPS-970 Add New Params (yeekung04)            */
/******************************************************************************/

CREATE   PROC [API].[isp_TPS_ExtUpd02] (
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

DECLARE @curAD CURSOR
DECLARE
	@cSKU             NVARCHAR(20),
   @cSkuBarcode      NVARCHAR(60),
   @cOrderLineNumber NVARCHAR(5),
   @cSerialNo        NVARCHAR(50),
   @cWeight          NVARCHAR(10),
   @cCube            NVARCHAR(10),
   @cLottableVal     NVARCHAR(20),
   @cSerialNoKey     NVARCHAR(60),
   @cErrMsg          NVARCHAR(128),
   @cSerialSKU       NVARCHAR(60),
   @cADCode          NVARCHAR(60),
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
   SkuBarcode      NVARCHAR(60),
   ADCode          NVARCHAR(60)
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

SELECT 'AA',* FROM @CloseCtnList

BEGIN
	SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN isp_TPS_ExtUpd02

	IF @cOrderKey <> ''
	BEGIN
	   SET @curAD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT SKU,SkuBarcode,ADCode
      FROM @CloseCtnList
      WHERE (SkuBarcode <> '' OR ADCode <> '')

      OPEN @curAD
      FETCH NEXT FROM @curAD INTO @cSKU, @cSkuBarcode, @cADCode
      WHILE @@FETCH_STATUS <> -1
      BEGIN
      	IF @cSkuBarcode <> ''
         BEGIN
         	SET @cSerialNo = SUBSTRING(@cSkuBarcode, 3 + 14, LEN(@cSkuBarcode)) --serial+sku
         END
         ELSE
         BEGIN
         	SET @cSerialNo = SUBSTRING(@cADCode, 3 + 14, LEN(@cADCode)) --serial+sku
         END

         IF(LEFT(@cSerialSKU, 2) = '21')
         BEGIN
            SET @cSerialNo =  SUBSTRING(@cSerialSKU, 3, LEN(@cSerialSKU) - 14 - 2)  --SerialNo
         END

         IF @cSerialNo <> ''
         BEGIN
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
                  SET @n_Err = 175740
                  SET @c_ErrMsg = rdt.rdtgetmessage(@n_Err ,@cLangCode ,'DSP') -- 'Fail to get SerialNo Key. Function : isp_TPS_ExtUpd02'
                  GOTO RollBackTran
               END

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



               INSERT INTO SerialNo (SerialNoKey, OrderKey, OrderLineNumber, StorerKey, SKU, SerialNo, Qty)
               VALUES ( @cSerialNoKey, @cOrderKey, ISNULL(@cOrderLineNumber,''), @cStorerKey, @cSKU , @cSerialNo , 1 )

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Err = 175741
                  SET @c_ErrMsg = rdt.rdtgetmessage(@n_Err ,@cLangCode ,'DSP') -- 'Fail to Insert SerialNo table. Function : isp_TPS_ExtUpd02'
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

               UPDATE SerialNo WITH (ROWLOCK) SET
                  OrderKey = @cOrderKey,
                  OrderLineNumber = ISNULL(@cOrderLineNumber,'')
               WHERE StorerKEy = @cStorerKey
               AND OrderKey = ''
               AND SKU = @cSKU
               AND SerialNo = @cSerialNo

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Err = 175742
                  SET @c_ErrMsg = rdt.rdtgetmessage(@n_Err ,@cLangCode ,'DSP') -- 'Fail to Update SerialNo table. Function : isp_TPS_ExtUpd02'
                  GOTO RollBackTran
               END
            END
         END
         FETCH NEXT FROM @curAD INTO @cSKU, @cSkuBarcode, @cADCode
      END
	END
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN isp_TPS_ExtUpd02

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN isp_TPS_ExtUpd02
         SET @b_Success = '1'
END

SET QUOTED_IDENTIFIER OFF

GO