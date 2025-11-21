SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO




/******************************************************************************/
/* Store procedure: isp_UnHoldCarton                                          */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2020-03-27   1.0  Chermaine  Created                                       */
/* 2021-09-05   1.2  Chermaine  TPS-11 ErrMsg add to rdtmsg (cc01)            */
/* 2025-01-28   1.3  YeeKung    UWP-29489 Change API Username (yeekung01)     */
/******************************************************************************/

CREATE   PROC [API].[isp_UnHoldCarton] (
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
   @cScanNo       NVARCHAR( 30),
   @cType         NVARCHAR( 30),
   @cPickSlipNo   NVARCHAR( 30),
   @cDropID       NVARCHAR( 30),
   @cCartonNo       NVARCHAR( 3),

   @cOrderKey     NVARCHAR( 10),
   @cLoadKey      NVARCHAR( 10),
   @cScanNoType   NVARCHAR( 30),
   @cZone         NVARCHAR( 18)

DECLARE @pickSKUDetail TABLE (
	SKU         NVARCHAR(20),
   PickQty     INT,
   PickslipNo  NVARCHAR( 30)
)

DECLARE @errMsg TABLE (
    nErrNo    INT,
    cErrMsg   NVARCHAR( 1024)
)

--Decode Json Format
SELECT @cStorerKey = StorerKey, @cFacility = Facility,  @nFunc=Func,@cScanNo=ScanNo, @cType = cType, @cUserName = UserName, @cLangCode = LangCode, @cCartonNo = CartonNo
FROM OPENJSON(@json)
WITH (
	   StorerKey   NVARCHAR ( 15),
	   Facility    NVARCHAR ( 5),
      Func        INT,
      ScanNo      NVARCHAR( 30),
      cType       NVARCHAR( 30),
      UserName    NVARCHAR( 30),
      LangCode    NVARCHAR( 3),
      CartonNo    NVARCHAR( 3)
)
--SELECT @cStorerKey AS StorerKey, @cFacility AS Facility,@nFunc AS Func, @cScanNo AS ScanNo, @cType AS TYPE, @cUserName AS userName, @cLangCode AS LangCode

--convert login
--SET @n_Err = 0
--EXEC [WM].[lsp_SetUser] @c_UserName = @cUserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT

--EXECUTE AS LOGIN = @cUserName

--IF @n_Err <> 0
--BEGIN
--   --INSERT INTO @errMsg(nErrNo,cErrMsg)
--   SET @b_Success = 0
--   SET @n_Err = @n_Err
--   SET @c_ErrMsg = @c_ErrMsg
--   GOTO EXIT_SP
--END


----SELECT @cUserName AS username
----select SUSER_SNAME ()

--Data Validate  - ScanNo
IF @cScanNo = ''
BEGIN
   SET @b_Success = 0
   SET @n_Err = 175714
   SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'Please scan or enter Packing Document No to proceed. Function : isp_UnHoldCarton'
                                                                  --
   --SET @jsonErrMsg=(SELECT * FROM @errMsg FOR json AUTO)
   GOTO EXIT_SP
END

--check pickslipNo
EXEC [API].[isp_GetPicklsipNo] @cStorerKey,@cFacility,@nFunc,@cLangCode,@cScanNo,@cType,@cUserName, @jResult OUTPUT,@b_Success OUTPUT,@n_Err OUTPUT,@c_ErrMsg OUTPUT

IF @n_Err <>0
BEGIN
	SET @jResult = ''
	SET @b_Success = 0
   SET @n_Err = @n_Err
   SET @c_ErrMsg = @c_ErrMsg

   GOTO EXIT_SP
END


--Decode pickslipNo Json Format
SELECT @cScanNoType = ScanNoType, @cpickslipNo = PickslipNo, @cDropID = DropID,  @cOrderKey=ISNULL(OrderKey,''), @cLoadKey = LoadKey, @cZone = Zone--, @EcomSingle = EcomSingle
--, @cDynamicRightName1 = DynamicRightName1, @cDynamicRightValue1 = DynamicRightValue1
--,@pickSkuDetailJson = PickSkuDetail
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
SELECT @cScanNoType as ScanNoType, @cpickslipNo as PickslipNo, @cDropID as DropID,  @cOrderKey as OrderKey, @cLoadKey as LoadKey, @cZone as Zone--, @EcomSingle as EcomSingle
--, @cDynamicRightName1 as DynamicRightName1, @cDynamicRightValue1 as DynamicRightValue1

--INSERT INTO @pickSKUDetail
--SELECT *
--FROM OPENJSON(@pickSkuDetailJson)
--WITH (
--      SKU               NVARCHAR( 20)  '$.SKU',
--      QtyToPack         INT            '$.QtyToPack',
--      OrderKey          NVARCHAR( 10)  '$.OrderKey',
--      PickslipNo        NVARCHAR( 30)  '$.PickslipNo',
--      LoadKey           NVARCHAR( 10)  '$.LoadKey',
--      PickDetailStatus  NVARCHAR( 1)   '$.PickDetailStatus'
--)


SELECT @cPickSlipNo AS pickslipNo1

--update packInfo
IF EXISTS (SELECT TOP 1 1 FROM packInfo (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @cCartonNo AND cartonStatus <> 'Hold')
BEGIN
	SET @b_Success = 0
   SET @n_Err = 175715
   SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'Unable to unHold Carton. Carton No is not in On-Hold status. Function : isp_UnHoldCarton'
END
ELSE
BEGIN
	UPDATE packInfo WITH (ROWLOCK)
   SET   cartonStatus ='',
         EditWho = @cUserName,
         EditDate = GETDATE(),
         TrafficCop = NULL
   WHERE PickSlipNo = @cPickSlipNo
   AND CartonNo = @cCartonNo

   IF @@ERROR <> 0
   BEGIN
      SET @b_Success = 0
      SET @n_Err = 175716
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'Unable to update PackInfo. Function : isp_UnHoldCarton'

      GOTO EXIT_SP
   END
   ELSE
   BEGIN
	   SET @b_Success = 1
	   SET @jResult = '[{Success}]'
   END
END



EXIT_SP:
   REVERT

SET QUOTED_IDENTIFIER OFF

GO