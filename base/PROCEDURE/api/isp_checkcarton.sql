SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/
/* Store procedure: isp_CheckCarton                                           */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2020-03-27   1.0  Chermaine  Created                                       */
/* 2021-09-05   1.1  Chermaine  TPS-11 ErrMsg add to rdtmsg (cc01)            */
/* 2023-02-10   1.2  yeekung    TPS-661 Add Packheaderstatus (yeekung01)      */
/* 2024-02-07   1.3  yeekung    TPS-851 Add Total carton qty (yeekung02)      */
/* 2025-02-14   1.4  yeekung    TPS-995 Follow Error Message (yeekung03)      */
/******************************************************************************/

CREATE    PROC [API].[isp_CheckCarton] (
   @json       NVARCHAR( MAX),
   @jResult    NVARCHAR( MAX) OUTPUT,
   @b_Success  INT = 1  OUTPUT,
   @n_Err      INT = 0  OUTPUT,
   @c_ErrMsg   NVARCHAR( 255) = ''  OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE
   @cLangCode     NVARCHAR( 3),
   @cUserName      NVARCHAR( 30),
   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @nFunc         INT,
   @cScanNo      NVARCHAR( 30),
   @cType         NVARCHAR( 30),
   @cPickSlipNo   NVARCHAR( 30),
   @cDropID       NVARCHAR( 30),

   @cOrderKey     NVARCHAR( 10),
   @cLoadKey      NVARCHAR( 10),
   @cZone         NVARCHAR( 18),
   @cLot          NVARCHAR( 30),
   @cStatus       NVARCHAR( 2),
   @cScanNoType   NVARCHAR( 30),
   @pickSkuDetailJson   NVARCHAR( MAX),

   @nTotalPick    INT,
   @nTotalShort   INT

DECLARE @pickSKUDetail TABLE (
    SKU              NVARCHAR( 30),
    QtyToPack        INT,
    OrderKey         NVARCHAR( 30),
    pickslipNo       NVARCHAR( 30),
    loadKey          NVARCHAR( 30),--externalOrderKey
    pickDetailStatus NVARCHAR ( 3)
)

--Decode Json Format
SELECT @cStorerKey = StorerKey, @cFacility = Facility,  @nFunc=Func,@cScanNo=ScanNo, @cType = cType, @cUserName = UserName, @cLangCode = LangCode
FROM OPENJSON(@json)
WITH (
	   StorerKey   NVARCHAR ( 15),
	   Facility    NVARCHAR ( 5),
      Func        INT,
      ScanNo      NVARCHAR( 30),
      cType       NVARCHAR( 30),
      UserName    NVARCHAR( 30),
      LangCode    NVARCHAR( 3)
)
--SELECT @cStorerKey AS StorerKey, @cFacility AS Facility,@nFunc AS Func, @cScanNo AS ScanNo, @cType AS TYPE, @cUserName AS userName, @cLangCode AS LangCode

--Data Validate  - Check ScanNo blank
IF @cScanNo = ''
BEGIN
   SET @b_Success = 0
   SET @n_Err = 1000901
   SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Please scan or enter Packing Document No to proceed : isp_CheckCarton'
   GOTO EXIT_SP
END

--check pickslipNo
EXEC [API].[isp_GetPicklsipNo] @cStorerKey,@cFacility,@nFunc,@cLangCode,@cScanNo,@cType,@cUserName, @jResult OUTPUT,@b_Success OUTPUT,@n_Err OUTPUT,@c_ErrMsg OUTPUT,1

IF @n_Err <>0
BEGIN
	SET @jResult = ''
	SET @b_Success = 0
   SET @n_Err = @n_Err
   SET @c_ErrMsg = @c_ErrMsg

   GOTO EXIT_SP
END


--Decode Json Format
SELECT @cScanNoType = ScanNoType, @cpickslipNo = PickslipNo, @cDropID = DropID,  @cOrderKey=OrderKey, @cLoadKey = LoadKey, @cZone = Zone--, @EcomSingle = EcomSingle
--, @cDynamicRightName1 = DynamicRightName1, @cDynamicRightValue1 = DynamicRightValue1
,@pickSkuDetailJson = PickSkuDetail
FROM OPENJSON(@jResult)
WITH (
	   ScanNoType        NVARCHAR( 30),
	   PickslipNo        NVARCHAR( 30),
      DropID            NVARCHAR( 30),
      OrderKey          NVARCHAR( 10),
      LoadKey           NVARCHAR( 10),
      Zone              NVARCHAR( 18),
      EcomSingle        NVARCHAR( 1),
      DynamicRightName1    NVARCHAR( 30),
      DynamicRightValue1   NVARCHAR( 30),
      PickSkuDetail     NVARCHAR( MAX) as json
)
--SELECT @cScanNoType as ScanNoType, @cpickslipNo as PickslipNo, @cDropID as DropID,  @cOrderKey as OrderKey, @cLoadKey as LoadKey, @cZone as Zone, @EcomSingle as EcomSingle
--, @cDynamicRightName1 as DynamicRightName1, @cDynamicRightValue1 as DynamicRightValue1

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


--SELECT @cPickSlipNo AS pickslipNo
--SELECT * FROM @pickSKUDetail
--SELECT DISTINCT pickslipNo FROM @pickSKUDetail

--retun json - check carton info
SET @b_Success = 1

--SELECT aa.* FROM (
--SELECT PKI.cartonNo,PKI.CartonStatus,PD.Item,PKI.EditWho AS StatusBy,LEFT(CONVERT(VARCHAR,PKI.EditDate,20),16) AS StatusDateTime,PD.LabelNo AS CartonID
--FROM packInfo PKI WITH (NOLOCK)
--LEFT JOIN (select count(SKU) AS Item,cartonNo,pickslipNo,LabelNo FROM packDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo GROUP BY cartonNo,pickslipNo,LabelNo)PD
--ON PD.pickslipNo = PKI.PickSlipNo AND PD.cartonNo = PKI.CartonNo
--WHERE ISNULL(PKI.cartonStatus,'') <> ''
--AND PKI.PickSlipNo = @cPickSlipNo) aa


SET @jResult =(
SELECT aa.* FROM (
SELECT PKI.cartonNo,PKI.CartonStatus,PD.Item,PKI.EditWho AS StatusBy,LEFT(CONVERT(VARCHAR,PKI.EditDate,20),16) AS StatusDateTime,PD.LabelNo AS CartonID,PH.OrderKey,PH.Status AS PackStatus,PD.PACKQTY AS PackedQTY --(yeekung02)
FROM  packInfo PKI WITH (NOLOCK)
LEFT JOIN (select count(PD2.SKU) AS Item,PD2.cartonNo,PD2.pickslipNo,PD2.LabelNo,SUM(pd2.QTY) AS PACKQTY
           FROM  packDetail PD2 WITH (NOLOCK)
           WHERE PD2.pickslipno IN (SELECT DISTINCT pickslipNo FROM @pickSKUDetail)
           GROUP BY PD2.cartonNo,PD2.pickslipNo,PD2.LabelNo)PD
LEFT JOIN packHeader PH WITH (NOLOCK) ON (PH.pickslipno = PD.pickslipno)
ON PD.pickslipNo = PKI.PickSlipNo AND PD.cartonNo = PKI.CartonNo
WHERE ISNULL(PKI.cartonStatus,'') <> ''
AND PKI.PickSlipNo IN (SELECT DISTINCT pickslipNo FROM @pickSKUDetail)
) aa
FOR JSON AUTO, INCLUDE_NULL_VALUES)


EXIT_SP:
   REVERT



GO