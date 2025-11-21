SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
     
/*********************************************************************************/  
/* Store procedure: isp_PackConfirm                                              */  
/* Copyright      : Maersk                                                       */  
/*                                                                               */  
/* Date         Rev  Author     Purposes                                         */  
/* 2020-04-09   1.0  Chermaine  Created                                          */  
/* 2020-12-30   1.1  Chermaine  TPS-518 Add @PackCaptureNewLabelno config (cc01) */  
/* 2021-01-07   1.2  Chermaine  TPS-555 if hav preset labelNo from hold carton   */  
/*                              reset before confirm (cc02)                      */  
/* 2021-01-25   1.3  Chermaine  TPS-271 Add Config to print at last Carton(cc03) */  
/* 2021-05-17   1.4  Chermaine  TPS-576 Add customise printing (cc04)            */  
/* 2021-05-31   1.5  Chermaine  TPS-591 Add lottableValue in packDetail (cc05)   */  
/* 2021-09-02   1.6  Chermaine  TPS-592 Add catonNo param (cc06)                 */  
/* 2021-09-05   1.7  Chermaine  TPS-11  ErrMsg add to rdtmsg (cc07)              */  
/* 2021-09-09   1.8  Chermaine  TPS-619 AssignPackLabelToOrdCfg (cc08)           */  
/* 2021-10-04   1.9  Chermaine  TPS-597 Add barcode for SKU scan in              */  
/*                              And Add ExtendedUpdateSP (cc09)                  */    
/* 2021-11-10   2.0  Chermaine  TPS-594 Add ExternalPrint config (cc10)          */  
/* 2022-04-25   2.1  yeekung    Fix PackList (yeekung01)                         */
/* 2022-01-06   2.2  YeeKung    TPS-585 Add Disbale print for label (yeekung01)  */  
/* 2022-08-11   2.3  YeeKung    Fix QTY <0 (yeekung02)                           */
/* 2023-02-03   2.4  YeeKung    TPS-668 Fix cartonno (yeekung03)                 */
/* 2023-03-20   2.5  YeeKung    TPS-678 add new error message (yeekung04)        */
/* 2023-03-20   2.6  YeeKung    TPS-687 add order info into packheader (yeekung05)*/
/* 2023-04-12   2.7  YeeKung    TPS-700 DefaultcartonType (yeekung06)             */
/* 2023-07-11   2.8  YeeKung    TPS-756 Substring orderrefno 18 chars (yeekung07) */
/* 2023-09-12   2.9  YeeKung    TPS-791 resetting the packinfo (yeekung08)        */
/* 2023-07-05   3.0  YeeKung    TPS-735 add hold carton printing(yeekung09)       */
/* 2023-08-09   3.1  YeeKung    TPS-727 add UPC on packdetail (yeekung10)         */  
/* 2023-09-12   3.2  YeeKung    TPS-773/TPS-740 New print (yeekung11)             */
/* 2023-12-11   3.3  YeeKung    TPS-826 Add params for paper (yeekung12)         */
/* 2024-01-30   3.4  YeeKung    Bug Fixed (yeekung13)                            */
/* 2024-01-30   3.5  Yeekung    JSM-205854 Fix labelline (yeekung14)             */
/* 2024-02-27   3.6  Yeekung    TPS-888 Fix the labelline (yeekung04)            */
/* 2024-03-14   3.7  YeeKung    TPS-892 Fix the insert (yeekung15)               */
/* 2024-03-14   3.8  Xulu       BugFixed (XULU01)                                */
/* 2024-05-29   3.9  YeeKung    TPS-908 Fixed the cartonid (yeekung16)				*/
/* 2024-11-06   4.0  YeeKung    TPS-989 Add Facility (yeekung17)                 */
/* 2024-01-14   4.1  YeeKung    UWP-29167 Fix The packdetail (yeekung18)         */
/* 2025-01-23   4.2  YeeKung    FCR-2019  Add CartonWeight (yeekung19)           */
/* 2025-01-28   4.3  YeeKung    UWP-29489 Change API Username (yeekung20)        */
/* 2025-02-10   4.4  GhChan     TPS-985 Carton Type Limit Config (Gh01)           */
/* 2025-01-21   4.5  YeeKung    TPS-970 Add New Param on Extendedupdate(yeekung21)*/
/* 2025-03-03   4.6  YeeKung    UWP-29086 check ucc or lottable qty whether null */
/*                              (yeekung22)                                      */
/*********************************************************************************/  
  
CREATE   PROC [API].[isp_PackConfirm] (  
   @json       NVARCHAR( MAX),    
   @jResult    NVARCHAR( MAX) ='' OUTPUT,    
   @b_Success  INT = 1  OUTPUT,    
   @n_Err      INT = 0  OUTPUT,    
   @c_ErrMsg   NVARCHAR( 255) = ''  OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE   
      @nMobile          INT,  
      @nStep            INT,  
      @cLangCode        NVARCHAR( 3),  
      @nInputKey        INT,  
      
      @cStorerKey       NVARCHAR( 15),  
      @cFacility        NVARCHAR( 5),  
      @nFunc            NVARCHAR( 5),  
      @cUserName        NVARCHAR( 128),  
      @cOriUserName     NVARCHAR( 128),  
      @cScanNo          NVARCHAR( 50),  
      @cScanNoType      NVARCHAR( 30),  
      @cDropID          NVARCHAR( 50),  
      @cPickSlipNo      NVARCHAR( 30),  
      @cZone            NVARCHAR( 18),  
      @nCartonNo        INT,  
      @cCartonID        NVARCHAR( 20),  
      @cType            NVARCHAR( 30),  
      @nQTY             INT,  
      @cSKU             NVARCHAR( 20),  
      @cCartonType      NVARCHAR( 10),  
      @cCube            FLOAT,  
      @cWeight          FLOAT,  
      @fCartonWeight    FLOAT,  
      @fCartonCube      FLOAT,  
      @cCloseCartonJson NVARCHAR( MAX),  
      @cUPCJSON         NVARCHAR( MAX),  
      @cLottableJSON    NVARCHAR( MAX),  
      @cLoadKey         NVARCHAR( 10),  
      @cOrderKey        NVARCHAR( 10),  
      @nPickQty         INT,  
      @nPackQty         INT,  
      @nPackQtyCarton   INT,  
      @cUPC             NVARCHAR( 30),  
      @cLabelLine       NVARCHAR(5),  
      @CalOrderSKU      NVARCHAR( 1),  
      @EcomSingle       NVARCHAR( 1),  
      @nProceedPrintFlag NVARCHAR( 1),  
      
      @cAssignPackLabelToOrdCfg     NVARCHAR(1), --(cc08)  
      @cAssignPackLabelToOrdCfgSP   NVARCHAR(30), --(cc08)  
      
      @cSKUBarcode         NVARCHAR( 60),   --(cc09)  
      @cExtendedUpdateSP   NVARCHAR( 20),   --(cc09)  
      @cExtendedPrintSP    NVARCHAR( 20),   --(cc10)  
      @cDymEcomCtnWgtTb    NVARCHAR( 20),  
      @cDymEcomCtnWgtCol   NVARCHAR( 20),  
      @cDymEcomCtnCubeTb   NVARCHAR( 20),  
      @cDymEcomCtnCubeCol  NVARCHAR( 20),  
      @UpdDymEcomWeight    NVARCHAR( 1),  
      @UpdDymEcomCube      NVARCHAR( 1),  
      @cDymWgtSQL          NVARCHAR( MAX),  
      @cDymCubeSQL         NVARCHAR( MAX),  
      @cCartonWeight       NVARCHAR( 20),  
      @cCartonCube         NVARCHAR( 20),  
   
      @bSuccess            INT,  
      @nErrNo              INT,   
      @cErrMsg             NVARCHAR(250),  
      @nTranCount          INT,  
      @curPD               CURSOR,  
      @GetCartonID         NVARCHAR( MAX),  
      @cShipLabel          NVARCHAR( 10),  
      @nJobID              INT,  
      @cWorkstation        NVARCHAR( 30),  
      @cLabelNo            NVARCHAR( 20), --(cc01)  
      @pickSkuDetailJson   NVARCHAR( MAX),  
      @bToPrint            INT,  
      @cPrintAfterPacked   NVARCHAR( 1),  
      @cLottableVal        NVARCHAR( 60), --(cc05)  
      @cSQL                NVARCHAR(MAX), --(cc08)  
      @cSQLParam           NVARCHAR(MAX), --(cc08)  
      @cDisableLblPrint    NVARCHAR(1), --(yeekung01)  
      @cDisablePLPrint     NVARCHAR(1), --(yeekung01)  
      @cDefaultCartonType  NVARCHAR(20), --(yeekung06) 
      @nUPCQTY             INT,
      @cCurUPC             CURSOR,
      @cUCCCounter         INT,
      @nPackedQTY          INT,
      @cRemainCartonTypeScn INT  = 0,
      @nLimitCartonType    INT --(Gh01)

   DECLARE @cFieldName1 NVARCHAR(max),
         @cFieldName2 NVARCHAR(max),
         @cFieldName3 NVARCHAR(max),
         @cFieldName4 NVARCHAR(max),
         @cParams1    NVARCHAR(max),
         @cParams2    NVARCHAR(max),
         @cParams3    NVARCHAR(max),
         @cParams4    NVARCHAR(max)

   DECLARE @cNewPaperPrinter NVARCHAR(20)
   DECLARE @cNewLabelPrinter NVARCHAR(20)
      
   
   SET @UpdDymEcomWeight = 'N'  
   SET @EcomSingle = '0'  
   SET @UpdDymEcomCube = 'N'  
   SET @nProceedPrintFlag = '0'  
   SET @cDisableLblPrint = '0'  
   SET @cDisablePLPrint = '0'  
   SET @nLimitCartonType = 0  --(Gh01)
  
   DECLARE @CartonIDList TABLE (  
      CartonID        NVARCHAR( 20)  
   )  


   DECLARE @CloseCartonList TABLE (  
      SKU             NVARCHAR( 20),  
      QTY             INT,  
      Weight          FLOAT,  
      Cube            FLOAT,    
      lottableVal     NVARCHAR(MAX),  
      barcodeVal      NVARCHAR(60),  
      ADCode          NVARCHAR(60),
      UPC             NVARCHAR(MAX)
   )  
  
  
   DECLARE @pickSKUDetail TABLE (  
      SKU              NVARCHAR( 30),    
      QtyToPack        INT,  
      OrderKey         NVARCHAR( 30),  
      PickslipNo       NVARCHAR( 30),  
      LoadKey          NVARCHAR( 30),--externalOrderKey  
      PickDetailStatus NVARCHAR ( 3)  
   )  
  
   --decode json  
   SELECT   @cStorerKey = StorerKey, @cFacility = Facility, @nFunc = Func, @cUserName = UserName, @cLangCode = LangCode,  
            @cScanNo = ScanNo, @nCartonNo = CartonNo, @cCartonType = CartonType, @cType = ctype, @fCartonWeight = CartonWeight,   
            @fCartonCube = CartonCube, @cWorkstation = Workstation, @cLabelNo = LabelNo,   
            @cCloseCartonJson=CloseCarton  
   FROM OPENJSON(@json)    
   WITH (  
      StorerKey      NVARCHAR( 30),  
      Facility       NVARCHAR( 30),  
      Func           NVARCHAR( 5),  
      UserName       NVARCHAR( 128),  
      LangCode       NVARCHAR( 3),  
      ScanNo         NVARCHAR( 30),  
      CartonNo       INT,  
      CartonType     NVARCHAR( 30),  
      cType          NVARCHAR( 30),  
      CartonWEIGHT   FLOAT,  
      CartonCUBE     FLOAT,  
      Workstation    NVARCHAR( 30),  
      LabelNo        NVARCHAR( 20), --(cc01)  
      CloseCarton    NVARCHAR( max) as json  
   )   
      
INSERT INTO @CloseCartonList  
SELECT Hdr.SKU  
, Hdr.Qty  
, Hdr.Weight  
, Hdr.Cube  
, Hdr.lottableValue  
, Det.barcodeVal   
, Det.AntiDiversionCode  
, Hdr.UPC 
FROM OPENJSON(@cCloseCartonJson)  
WITH (  
   SKU            NVARCHAR( 20)  '$.SKU',  
   Qty            INT            '$.PackedQty',  
   WEIGHT         FLOAT          '$.WEIGHT',  
   Cube           FLOAT          '$.CUBE',  
   lottableValue  NVARCHAR(MAX)   '$.Lottable' AS JSON, --(cc05)  
   barcodeObj     NVARCHAR(MAX)  '$.barcodeObj' AS JSON, --(cc09)  
   UPC            NVARCHAR(MAX)  '$.UPC' AS JSON --(cc09)  
) AS Hdr  
OUTER APPLY OPENJSON(barcodeObj)  
WITH (  
   barcodeVal        NVARCHAR(60) '$.barcodeVal',  
   AntiDiversionCode NVARCHAR(60) '$.AntiDiversionCode'  
) AS Det  

SELECT @cUPCJson=UPC  
FROM OPENJSON(@cCloseCartonJson)  
WITH (  
   UPC    NVARCHAR( max) as json  
)

SELECT @cLottableJSON=Lottable  
FROM OPENJSON(@cCloseCartonJson)  
WITH (  
   Lottable    NVARCHAR( max) as json  
)

SET @cCartonWeight = CONVERT(NVARCHAR(20),@fCartonWeight)  
SET @cCartonCube = CONVERT(NVARCHAR(20),@fCartonCube)  
SET @cOriUserName = @cUserName  
--convert login   
--SET @n_Err = 0   
--EXEC [WM].[lsp_SetUser] @c_UserName = @cUserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT  

--EXECUTE AS LOGIN = @cUserName  
   
--IF @n_Err <> 0   
--BEGIN    
--   SET @b_Success = 0    
--   SET @n_Err = @n_Err    
--   SET @c_ErrMsg = @c_ErrMsg   
--   SET @jResult = (select '' AS OrderKey, '' as LabelJobID, '' as PackingJobID ,@nProceedPrintFlag AS nProceedPrintFlag, '' AS VasConfig, '' AS VasCol1Name, '' AS VasCol1Value, '' AS WorkInstruction FOR JSON PATH )  
--   GOTO EXIT_SP    
--END    

-- SET @cUserName = @cOriUserName
  
--check pickslipNo  
EXEC [API].[isp_GetPicklsipNo] @cStorerKey,@cFacility,@nFunc,@cLangCode,@cScanNo,@cType,@cUserName, @jResult OUTPUT,@b_Success OUTPUT,@n_Err OUTPUT,@c_ErrMsg OUTPUT  
  
IF @n_Err <>0  
BEGIN  
   SET @jResult = (select '' AS OrderKey, '' as LabelJobID, '' as PackingJobID ,@nProceedPrintFlag AS nProceedPrintFlag, '' AS VasConfig, '' AS VasCol1Name, '' AS VasCol1Value, '' AS WorkInstruction FOR JSON PATH )  
   SET @b_Success = 0    
   SET @n_Err = @n_Err    
   SET @c_ErrMsg = @c_ErrMsg  
   GOTO EXIT_SP  
END  


  
--Decode pickslipNo Json Format  
SELECT @cScanNoType = ScanNoType, @cpickslipNo = PickslipNo, @cDropID = DropID,  @cOrderKey=ISNULL(OrderKey,''), @cLoadKey = LoadKey, @cZone = Zone, @EcomSingle = EcomSingle  
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
SELECT @cScanNoType as ScanNoType, @cpickslipNo as PickslipNo, @cDropID as DropID,  @cOrderKey as OrderKey, @cLoadKey as LoadKey, @cZone as Zone, @EcomSingle as EcomSingle  
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

IF EXISTS (select 1 from @CloseCartonList  where QTY<0) OR 
   EXISTS  (select 1 from @pickSKUDetail  where QtyToPack<0 )
BEGIN  
   SET @jResult = (select '' AS OrderKey, '' as LabelJobID, '' as PackingJobID ,@nProceedPrintFlag AS nProceedPrintFlag, '' AS VasConfig, '' AS VasCol1Name, '' AS VasCol1Value, '' AS WorkInstruction FOR JSON PATH )  
   SET @b_Success = 0    
   SET @n_Err = 1000000    
   SET @c_ErrMsg = @c_ErrMsg  
   GOTO EXIT_SP  
END  
  
IF EXISTS (SELECT sku FROM @CloseCartonList EXCEPT SELECT sku FROM @pickSKUDetail)  
BEGIN  
   SET @b_Success = 0    
   SET @n_Err = 1000001    
   SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Invalid SKU. Scanned SKU not found in SKU table. Function : isp_PackConfirm'  
   SET @jResult = (select '' AS OrderKey, '' as LabelJobID, '' as PackingJobID ,@nProceedPrintFlag AS nProceedPrintFlag, '' AS VasConfig, '' AS VasCol1Name, '' AS VasCol1Value, '' AS WorkInstruction FOR JSON PATH )  
   GOTO EXIT_SP  
END  
  
--(cc03)  
IF EXISTS (SELECT TOP 1 1 FROM storerConfig WITH (NOLOCK) WHERE storerKey = @cStorerKey AND configKey = 'TPS-PrintAfterPacked' AND sValue = '1')  
BEGIN  
   SET @bToPrint = 0  
   SET @cPrintAfterPacked = '1'  
END  
ELSE  
BEGIN  
   SET @bToPrint = 1  
END  

IF EXISTS (SELECT TOP 1 1 FROM storerConfig WITH (NOLOCK) WHERE configkey ='TPS-OnHoldPrint' AND storerKey = @cStorerKey AND sValue = 1)  
BEGIN  
   IF  EXISTS (SELECT 1 FROM PACKinfo (NOLoCK) where PickSlipNo = @cPickSlipNo and Cartonno=@nCartonNo)
   BEGIN
      SET @bToPrint = 0 
   END
END 

  
IF EXISTS (SELECT TOP 1 1 FROM storerConfig WITH (NOLOCK) WHERE storerKey = @cStorerKey AND configKey = 'TPS-DisableLblPrint' AND sValue = '1')  
BEGIN  
   SET @cDisableLblPrint = 1  --(yeekung01)  
END  
  
IF EXISTS (SELECT TOP 1 1 FROM storerConfig WITH (NOLOCK) WHERE storerKey = @cStorerKey AND configKey = 'TPS-DisablePLPrint' AND sValue = '1')  
BEGIN  
   SET @cDisablePLPrint = 1 --(yeekung01)  
END  
  
IF @EcomSingle IN ('1','2')  
BEGIN  
   DECLARE @cEcomSKU NVARCHAR( 30)  
            
   SELECT @cEcomSKU = SKU FROM @CloseCartonList  
            
   SELECT TOP 1 @cOrderKey = orderkey,@cPickSlipNo = PickslipNo, @cLoadKey = LoadKey  
   FROM @pickSKUDetail   
   WHERE pickslipNo NOT IN (SELECT DISTINCT pickslipNo FROM packDetail WITH (NOLOCK) WHERE storerKey = @cStorerKey AND SKU = @cEcomSKU)  
   AND sku = @cEcomSKU  
                      
   --SELECT @cOrderKey AS cOrderKeyEcom, @cPickSlipNo AS cPickSlipNoEcom  
END  


IF ISNULL(@cCartonType,'') =''
BEGIN
   SELECT @cDefaultCartonType = sValue FROM dbo.StorerConfig WITH (NOLOCK) WHERE Storerkey = @cStorerKey AND configKey = 'DefaultCartonType'  
   SET @cCartonType = @cDefaultCartonType
END
--(Gh01) start
ELSE 
BEGIN
   SELECT @nLimitCartonType= TRY_CAST(sValue AS INT) FROM dbo.StorerConfig WITH (NOLOCK) WHERE Storerkey = @cStorerKey AND configKey = 'TPS-LimitCartonType'
   
   IF @@ROWCOUNT = 1 AND @nLimitCartonType > 0
   BEGIN
      IF (SELECT COUNT(DISTINCT CartonType) 
            FROM 
            (SELECT CartonType FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
            UNION
            SELECT @cCartonType) AS TtlCartonType 
         ) > @nLimitCartonType
      BEGIN
         SELECT @c_ErrMsg = STRING_AGG(CartonType, ', ') FROM (SELECT DISTINCT CartonType FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo) AS ExistingItems
         SET @b_Success = 0    
         SET @n_Err = 1000454    
         SET @c_ErrMsg = @c_ErrMsg + ' ' + API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--' - Cannot select more than these items:  Function : isp_PackConfirm'  
         SET @jResult = ''
         --SET @jResult = (select '' AS OrderKey, '' as LabelJobID, '' as PackingJobID ,@nProceedPrintFlag AS nProceedPrintFlag, '' AS VasConfig, '' AS VasCol1Name, '' AS VasCol1Value, '' AS WorkInstruction FOR JSON PATH )  
         GOTO EXIT_SP  
      END
   END
END
--(Gh01) end

--check status       
IF EXISTS (SELECT TOP 1 1 FROM packInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo AND CartonStatus = 'Hold')  
BEGIN  
   SET @b_Success = 0    
   SET @n_Err = 1000002    
   SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Carton No in On-Hold Status. Unable to proceed to Closed Carton. Please Unhold this Carton. Function : isp_PackConfirm'  
   SET @jResult = (select '' AS OrderKey, '' as LabelJobID, '' as PackingJobID ,@nProceedPrintFlag AS nProceedPrintFlag, '' AS VasConfig, '' AS VasCol1Name, '' AS VasCol1Value, '' AS WorkInstruction FOR JSON PATH )  
   GOTO EXIT_SP  
END  
  
-- Check pack confirm already  
IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status = '9')  
BEGIN  
   SET @b_Success = 0    
   SET @n_Err = 1000003    
   SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Pickslip No is already Closed/Packed. Function : isp_PackConfirm'  
   SET @jResult = (select '' AS OrderKey, '' as LabelJobID, '' as PackingJobID ,@nProceedPrintFlag AS nProceedPrintFlag, '' AS VasConfig, '' AS VasCol1Name, '' AS VasCol1Value, '' AS WorkInstruction FOR JSON PATH )  
   GOTO EXIT_SP  
END  
  
-- Check pack confirm already  
IF EXISTS( SELECT 1 FROM PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND cartonNo = @nCartonNo AND cartonStatus = 'Closed')  
BEGIN  
   SET @b_Success = 0    
   SET @n_Err = 1000004    
   SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Carton No is already Closed/Packed. Function : isp_PackConfirm'  
   SET @jResult = (select '' AS OrderKey, '' as LabelJobID, '' as PackingJobID ,@nProceedPrintFlag AS nProceedPrintFlag, '' AS VasConfig, '' AS VasCol1Name, '' AS VasCol1Value, '' AS WorkInstruction FOR JSON PATH )  
   GOTO EXIT_SP  
END  
  
-- check EcomWeight/Cube  
IF @EcomSingle = '1'  
BEGIN  
   IF EXISTS (SELECT TOP 1 1 FROM storerConfig WITH (NOLOCK) WHERE storerKey =@cStorerKey AND configKey = 'TPS-EcomCartonWgt' AND OPTION1 <>'')  
   BEGIN  
      SELECT TOP 1   
         @cDymEcomCtnWgtTb = rdt.rdtGetParsedString( OPTION1, 1, '.'),  
         @cDymEcomCtnWgtCol = rdt.rdtGetParsedString( OPTION1, 2, '.')  
      FROM StorerConfig (NOLOCK)   
      WHERE storerKey = @cStorerKey   
      AND configKey ='TPS-EcomCartonWgt'  
      AND OPTION1 <>''  
        
      IF (ISNULL(@cDymEcomCtnWgtTb,'') NOT IN ('SKU')) OR (ISNULL(@cDymEcomCtnWgtTb,'') = '')  
      BEGIN  
         SET @n_Err = 1000005  
         SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Incorrect dynamic E-Comm Carton Weight column setup. Function : isp_PackConfirm'  
         SET @jResult = (select '' AS OrderKey, '' as LabelJobID, '' as PackingJobID ,@nProceedPrintFlag AS nProceedPrintFlag, '' AS VasConfig, '' AS VasCol1Name, '' AS VasCol1Value, '' AS WorkInstruction FOR JSON PATH )  
         GOTO EXIT_SP  
      END  
      ELSE  
      BEGIN  
         SET @UpdDymEcomWeight = 'Y'  
      END  
   END  
     
   IF EXISTS (SELECT TOP 1 1 FROM storerConfig WITH (NOLOCK) WHERE storerKey =@cStorerKey AND configKey = 'TPS-EcomCartonCube' AND OPTION1 <>'')  
   BEGIN  
      SELECT TOP 1   
         @cDymEcomCtnCubeTb = rdt.rdtGetParsedString( OPTION1, 1, '.'),  
         @cDymEcomCtnCubeCol = rdt.rdtGetParsedString( OPTION1, 2, '.')  
      FROM StorerConfig (NOLOCK)   
      WHERE storerKey = @cStorerKey   
      AND configKey ='TPS-EcomCartonCube'  
      AND OPTION1 <>''  
        
      IF (ISNULL(@cDymEcomCtnCubeTb,'') NOT IN ('SKU')) OR (ISNULL(@cDymEcomCtnCubeTb,'') = '')  
      BEGIN  
         SET @n_Err = 1000006  
         SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Incorrect dynamic E-Comm Cube column setup. Function : isp_packConfirm'  
         SET @jResult = (select '' AS OrderKey, '' as LabelJobID, '' as PackingJobID ,@nProceedPrintFlag AS nProceedPrintFlag, '' AS VasConfig, '' AS VasCol1Name, '' AS VasCol1Value, '' AS WorkInstruction FOR JSON PATH )  
         GOTO EXIT_SP  
      END  
      ELSE  
      BEGIN  
         SET @UpdDymEcomCube = 'Y'  
      END  
   END  
END  
        
--Get CartonID to insert/update packDetail   
IF ISNULL (@cLabelNo,'') = ''  
BEGIN  
   SELECT @cCartonID = LabelNo FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo AND StorerKey = @cStorerKey  
   
   --(cc02) reset pre set lableNo during holdCrton  
   IF @cCartonID = 'PreLabelNo'  
   BEGIN  
      SET @cCartonID = ''  
   END  
   
END  
ELSE  
BEGIN  
   SELECT @cCartonID = @cLabelNo  
END   
  
--SELECT @cCartonID AS cCartonID, @cLabelNo AS LabelNo  
DECLARE @SQLParam NVARCHAR(MAX)   
DECLARE @cCartonNo NVARCHAR(3)  
SET @cCartonNo = CONVERT(NVARCHAR(3),@nCartonNo)  
IF ISNULL(@cCartonID,'') =''   
BEGIN   --(cc06)  
   SET @GetCartonID = '       
   EXEC [API].[isp_GetPackCartonID] ''[{"StorerKey":"' +@cStorerKey+ '","Facility":"' +@cFacility + '","Func":"' +@nFunc + '","PickSlipNo":"' +@cPickSlipNo+ '","CartonNo":"' +@cCartonNo+ '","LangCode":"' +@cLangCode+ '"}]'' ,@jResult OUTPUT,@b_Success OUTPUT,@n_Err OUTPUT,@c_ErrMsg OUTPUT'  
   --SELECT @GetCartonID  
     
   SET @SQLParam = '  
   @jResult NVARCHAR(MAX) OUTPUT,  
   @b_Success  INT OUTPUT,  
   @n_Err      INT OUTPUT,  
   @c_ErrMsg   NVARCHAR( 250) OUTPUT  
   '  
   EXEC sp_ExecuteSQL @GetCartonID,@SQLParam, @jResult OUTPUT , @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT  
      
   IF @b_Success <> 1  
   BEGIN  
      SET @b_Success = 0   
      SET @n_Err = @n_Err  
      SET @c_ErrMsg = @c_ErrMsg  
      SET @jResult = (select '' AS OrderKey, '' as LabelJobID, '' as PackingJobID ,@nProceedPrintFlag AS nProceedPrintFlag, '' AS VasConfig, '' AS VasCol1Name, '' AS VasCol1Value, '' AS WorkInstruction FOR JSON PATH )  
      GOTO EXIT_SP  
   END  
   ELSE  
   BEGIN  
      SET  @cCartonID = LEFT(replace(@jResult,'[{',''),len(@jResult)-4)  
      --SELECT @cCartonID AS cartonID  
   END   
END  
        
--Data Validate  
SET @nTranCount = @@TRANCOUNT  
BEGIN TRAN  
--SAVE TRAN isp_PackConfirm  
  
  
--Close: packHeader  
IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickslipNo = @cPickslipNo)  
BEGIN 


   DECLARE @cRoute NVARCHAR(20) = ''
   DECLARE @cOrderRefNo NVARCHAR(60)   = ''
   DECLARE @cConsigneekey NVARCHAR(20)   = ''

      --(yeekung05)
   SELECT   @cRoute          = ISNULL(Route,''),
            @cOrderRefNo     = ISNULL(ExternOrderkey,''),
            @cConsigneekey   = ISNULL(Consigneekey,'')
   FROM ORDERS (NOLOCK)
   WHERE Orderkey = @cOrderkey
      AND Storerkey = @cStorerKey

   IF ISNULL(@cOrderRefNo,'') <> ''
      SET @cOrderRefNo = SUBSTRING(trim(@cOrderRefNo),1,18)

   INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, LoadKey, AddWho, AddDate,Route,OrderRefNo,ConsigneeKey)  
   VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey, @cLoadKey, @cUserName, GETDATE(),@cRoute,@cOrderRefNo,@cConsigneekey)  
   
   IF @@ERROR <> 0  
   BEGIN        
      SET @b_Success = 0    
      SET @n_Err = 1000007    
      SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Fail to insert into PackHeader. Function : isp_PackConfirm'  
      GOTO RollBackTran  
   END  
END 


--Close: packDetail  
SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT  SKU,QTY,WEIGHT,CUBE,lottableVal,UPC 
   FROM @CloseCartonList  
   GROUP BY SKU,QTY,WEIGHT,[CUBE],lottableVal,UPC   
     
OPEN @curPD 
FETCH NEXT FROM @curPD INTO @cSKU,@nQTY,@cWeight,@cCube,@cLottableJSON,@cUPCJSON  
WHILE @@FETCH_STATUS <> -1  
BEGIN  
     
   -- Check SKU blank  
   IF @cSKU = ''  
   BEGIN     
      SET @b_Success = 0    
      SET @n_Err = 1000012    
      SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'No SKU entered. Please enter or scan valid SKU. Function : isp_PackConfirm'  
      GOTO RollBackTran  
   END  
        
   -- Check blank QTY  
   IF @nQTY = 0  
   BEGIN       
      SET @b_Success = 0    
      SET @n_Err = 1000013    
      SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'No Quantity entered. Please enter valid Quantity. Function : isp_PackConfirm'           
      GOTO RollBackTran  
   END   
        
   IF @nQTY <> '' AND ISNULL(@nQTY,0) = 0 --RDT.rdtIsValidQTY( @nQTY, 1) = 0 --Check zero  
   BEGIN     
      SET @b_Success = 0    
      SET @n_Err = 1000014    
      SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Invalid Quantity entered. Please enter valid Quantity. Function : isp_PackConfirm'  
      GOTO RollBackTran  
   END  
        
   --check pickQty<=packQty (per sku)  
   SELECT @nPackQty = ISNULL(SUM(Qty),0) FROM PackDetail WITH (NOLOCK) WHERE pickslipno = @cPickSlipNo AND SKU = @csku AND Storerkey = @cStorerKey  
   SELECT @nPackQtyCarton = ISNULL(SUM(Qty),0) FROM PackDetail WITH (NOLOCK) WHERE pickslipno = @cPickSlipNo AND SKU = @csku AND Storerkey = @cStorerKey AND cartonNo = @nCartonNo  
   SELECT @nPickQty = QtyToPack FROM @pickSKUDetail WHERE sku = @cSKU  

   IF @nPickQty < @nQTY  
   BEGIN  
      SET @b_Success = 0    
      SET @n_Err = 1000015    
      SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Closed Quantity > Pick Quantity. Please enter valid Quantity. Function : isp_PackConfirm'    
      GOTO RollBackTran  
   END  
   IF  EXISTS( SELECT 1
      FROM OPENJSON(@cUPCJSON)  
      WITH (  
         UPC               NVARCHAR( 30)  '$.UPC',  
         QTY               INT            '$.QTY'
      ) ) OR EXISTS ( SELECT 1
      FROM OPENJSON(@cLottableJSON)  
      WITH (  
         Lottable               NVARCHAR( 30)  '$.Lottable',  
         PackedQTY                    INT            '$.PackedQty'
      ) )
   BEGIN


      IF  EXISTS( SELECT 1
         FROM OPENJSON(@cUPCJSON)  
         WITH (  
            UPC               NVARCHAR( 30)  '$.UPC',  
            QTY               INT            '$.QTY'
         ) )
      BEGIN

         SET @cUCCCounter = 0 
          
   
         SET @cCurUPC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT UPC, SUM(QTY) 
         FROM OPENJSON(@cUPCJSON)  
         WITH (  
            UPC               NVARCHAR( 30)  '$.UPC',  
            QTY               INT            '$.QTY'
         )  
         GROUP BY  UPC

         OPEN @cCurUPC 
         FETCH NEXT FROM @cCurUPC INTO @cUPC,@nUPCQTY
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            IF ISNULL(@cUPC,'') =''
               GOTO NEXT_UPC

            -- Get LabelLine  
            SET @cLabelLine = ''
            SET @nPackedQTY = 0
            SELECT @cLabelLine = LabelLine, @nPackedQTY = qty 
            FROM dbo.PackDetail WITH (NOLOCK)   
            WHERE PickSlipNo = @cPickSlipNo   
               AND CartonNo = @nCartonNo  
               AND LabelNo = @cCartonID   
               AND SKU = @cSKU  
               and upc=@cupc
        
            IF @cLabelLine = ''  
               SELECT @cLabelLine = LabelLine  
               FROM dbo.PackDetail WITH (NOLOCK)   
               WHERE PickSlipNo = @cPickSlipNo   
                  AND CartonNo = @nCartonNo  
                  AND LabelNo = @cCartonID   
                  AND SKU = ''  

            SET @nPackedQTY = CASE WHEN ISNULL(@nPackedQTY,'') ='' THEN 0 ELSE @nPackedQTY END 

            IF @nPackedQTY <> @nUPCQTY
            BEGIN
               SET @nUPCQTY = @nUPCQTY - @nPackedQTY
  
            --IF @cLabelLine = ''  
            --BEGIN  
            --   SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)   
            --   FROM dbo.PackDetail (NOLOCK)  
            --   WHERE Pickslipno = @cPickSlipNo  
            --      AND CartonNo = @nCartonNo  
            --      AND LabelNo = @cCartonID  
            --END 

            -- Close: PackDetail  
               IF NOT EXISTS( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickslipNo = @cPickslipNo AND cartonno =@nCartonNo AND SKU=@cSKU AND LOTTABLEVALUE = @cLottableVal and upc=@cupc)  
               BEGIN  

               
                  SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)   
                  FROM dbo.PackDetail (NOLOCK)  
                  WHERE Pickslipno = @cPickSlipNo  
                     AND CartonNo = @nCartonNo  
                     AND LabelNo = @cCartonID  

                  -- Insert PackDetail  
                  INSERT INTO dbo.PackDetail  
                     (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID,  
                     AddWho, AddDate, EditWho, EditDate  
                     , LOTTABLEVALUE,UPC)--(cc05)  
                  VALUES  
                     (@cPickSlipNo, @nCartonNo, @cCartonID, @cLabelLine, @cStorerKey, @cSKU, @nUPCQTY, ISNULL(@cDropID,''),  
                        @cUserName, GETDATE(), @cUserName, GETDATE()  
                        , @cLottableVal,@cUPC) --(cc05)  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @b_Success = 0    
                     SET @n_Err = 1000016    
                     SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Fail to insert into PackDetail. Function : isp_PackConfirm'          
                     GOTO RollBackTran  
                  END  
               END  
               ELSE  
               BEGIN  
                  -- Update Packdetail  
                  UPDATE dbo.PackDetail WITH (ROWLOCK) SET     
                     SKU = @cSKU,   
                     QTY = QTY+ @nUPCQTY,   
                     DropID = ISNULL(@cDropID,''),  
                     EditWho =  @cUserName,   
                     EditDate = GETDATE(),   
                     ArchiveCop = NULL,  
                     LOTTABLEVALUE = @cLottableVal,
                     UPC   = @cUPC
                  WHERE PickSlipNo = @cPickSlipNo  
                     AND SKU = @cSKU 
                     AND cartonno =@nCartonNo 
                     and upc = @cupc
                  IF @@ERROR <> 0  
                  BEGIN           
                     SET @b_Success = 0    
                     SET @n_Err = 1000017    
                     SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Fail to update into PackDetail. Function : isp_PackConfirm'   
                     GOTO RollBackTran  
                  END
            
               END  
            END

            SET @nQTY = @nQTY- @nUPCQTY

            NEXT_UPC:

            FETCH NEXT FROM @cCurUPC INTO @cUPC,@nUPCQTY
         END
         CLOSE @cCurUPC
         DEALLOCATE @cCurUPC
      END

      IF EXISTS ( SELECT 1
         FROM OPENJSON(@cLottableJSON)  
         WITH (  
            Lottable               NVARCHAR( 30)  '$.Lottable',  
            PackedQTY                    INT            '$.PackedQty'
         ) )
      BEGIN
         DECLARE @cCurLottable Cursor
         DECLARE @cLottableValue NVARCHAR(30)
         DECLARE @nLotQTY INT

         SET @cCurLottable = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT Lottable,SUM(PackedQTY ) 
         FROM OPENJSON(@cLottableJSON)  
         WITH (  
            Lottable               NVARCHAR( 30)  '$.Lottable',  
            PackedQTY              INT            '$.PackedQty'
         )  
         GROUP BY Lottable

         OPEN @cCurLottable 
         FETCH NEXT FROM @cCurLottable INTO @cLottableValue,@nLotQTY
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            IF ISNULL(@cLottableValue,'') =''
               GOTO NEXT_Lottable

                  -- Get LabelLine  
            SET @cLabelLine = ''  
            SET @nPackedQTY = 0
            SELECT @cLabelLine = LabelLine, @nPackedQTY =qty
            FROM dbo.PackDetail WITH (NOLOCK)   
            WHERE PickSlipNo = @cPickSlipNo   
               AND CartonNo = @nCartonNo  
               AND LabelNo = @cCartonID   
               AND SKU = @cSKU  
               and LOTTABLEVALUE=@cLottableValue
        
            IF @cLabelLine = ''  
               SELECT @cLabelLine = LabelLine  
               FROM dbo.PackDetail WITH (NOLOCK)   
               WHERE PickSlipNo = @cPickSlipNo   
                  AND CartonNo = @nCartonNo  
                  AND LabelNo = @cCartonID   
                  AND SKU = ''  
            
            SET @nPackedQTY = CASE WHEN ISNULL(@nPackedQTY,'') ='' THEN 0 ELSE @nPackedQTY END 

            IF @nPackedQTY <> @nLotQTY
            BEGIN
               SET @nLotQTY = @nLotQTY - @nPackedQTY
  
            --IF @cLabelLine = ''  
            --BEGIN  
            --   SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)   
            --   FROM dbo.PackDetail (NOLOCK)  
            --   WHERE Pickslipno = @cPickSlipNo  
            --      AND CartonNo = @nCartonNo  
            --      AND LabelNo = @cCartonID  
            --END 

            -- Close: PackDetail  
               IF NOT EXISTS( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickslipNo = @cPickslipNo AND cartonno =@nCartonNo AND SKU=@cSKU AND LOTTABLEVALUE = @cLottableVal  AND UPC = @cUPC)  
               BEGIN  
               
                  SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)   
                  FROM dbo.PackDetail (NOLOCK)  
                  WHERE Pickslipno = @cPickSlipNo  
                     AND CartonNo = @nCartonNo  
                     AND LabelNo = @cCartonID  

      
                  -- Insert PackDetail  
                  INSERT INTO dbo.PackDetail  
                     (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID,  
                     AddWho, AddDate, EditWho, EditDate  
                     , LOTTABLEVALUE,UPC)--(cc05)  
                  VALUES  
                     (@cPickSlipNo, @nCartonNo, @cCartonID, @cLabelLine, @cStorerKey, @cSKU, @nLotQTY,ISNULL(@cDropID,''),  
                        @cUserName, GETDATE(), @cUserName, GETDATE()  
                        , @cLottableValue,@cUPC) --(cc05)  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @b_Success = 0    
                     SET @n_Err = 1000016    
                     SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Fail to insert into PackDetail. Function : isp_PackConfirm'          
                     GOTO RollBackTran  
                  END  
               END  
               ELSE  
               BEGIN  
                  -- Update Packdetail  
                  UPDATE dbo.PackDetail WITH (ROWLOCK) SET     
                     SKU = @cSKU,   
                     QTY = QTY+ @nLotQTY,   
                     DropID = ISNULL(@cDropID,''),  
                     EditWho =  @cUserName,   
                     EditDate = GETDATE(),   
                     ArchiveCop = NULL,  
                     LOTTABLEVALUE = @cLottableVal,
                     UPC   = @cUPC
                  WHERE PickSlipNo = @cPickSlipNo  
                     AND SKU = @cSKU 
                     AND cartonno =@nCartonNo
                     and LOTTABLEVALUE = @cLottableValue
                  IF @@ERROR <> 0  
                  BEGIN           
                     SET @b_Success = 0    
                     SET @n_Err = 1000017    
                     SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Fail to update into PackDetail. Function : isp_PackConfirm'   
                     GOTO RollBackTran  
                  END
               END 
            END

            SET @nQTY = @nQTY- @nLotQTY

            NEXT_Lottable:

            FETCH NEXT FROM @cCurLottable INTO @cLottableValue,@nLotQTY
         END
         CLOSE @cCurLottable
         DEALLOCATE @cCurLottable

      END

      SET @cUPC = ''
      SET @cLottableVal = ''
   END

   IF @nQTY >0
   BEGIN
                     -- Get LabelLine  
      SET @cLabelLine = ''  
      SET @nPackedQTY = 0
      SELECT @cLabelLine = LabelLine, @nPackedQTY =qty  
      FROM dbo.PackDetail WITH (NOLOCK)   
      WHERE PickSlipNo = @cPickSlipNo   
         AND CartonNo = @nCartonNo  
         AND LabelNo = @cCartonID   
         AND SKU = @cSKU  
         AND UPC = @cSKU
        
      IF @cLabelLine = ''  
         SELECT @cLabelLine = LabelLine  
         FROM dbo.PackDetail WITH (NOLOCK)   
         WHERE PickSlipNo = @cPickSlipNo   
            AND CartonNo = @nCartonNo  
            AND LabelNo = @cCartonID  
            AND SKU = '' 
           
  
      --IF @cLabelLine = ''  
      --BEGIN  
      --   SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)   
      --   FROM dbo.PackDetail (NOLOCK)  
      --   WHERE Pickslipno = @cPickSlipNo  
      --      AND CartonNo = @nCartonNo  
      --      AND LabelNo = @cCartonID  
      --END 


      SET @cUPC = @cSKU

      SET @nPackedQTY = CASE WHEN ISNULL(@nPackedQTY,'') ='' THEN 0 ELSE @nPackedQTY END 

      SET @nQTY = @nQTY - @nPackedQTY

      IF @nQTY > 0
      BEGIN

      --select @cLabelLine,@cUPC

      -- Close: PackDetail  
         IF NOT EXISTS( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickslipNo = @cPickslipNo AND cartonno =@nCartonNo AND UPC = @cSKU AND SKU=@cSKU) 
         BEGIN  
         
            SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)   
            FROM dbo.PackDetail (NOLOCK)  
            WHERE Pickslipno = @cPickSlipNo  
               AND CartonNo = @nCartonNo  
               AND LabelNo = @cCartonID  

            -- Insert PackDetail  
            INSERT INTO dbo.PackDetail  
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID,  
               AddWho, AddDate, EditWho, EditDate  
               , LOTTABLEVALUE,UPC)--(cc05)  
            VALUES  
               (@cPickSlipNo, @nCartonNo, @cCartonID, @cLabelLine, @cStorerKey, @cSKU, @nQTY, ISNULL(@cDropID,''),  
                  @cUserName, GETDATE(), @cUserName, GETDATE()  
                  , @cLottableVal,@cUPC) --(cc05)  
            IF @@ERROR <> 0  
            BEGIN  
               SET @b_Success = 0    
               SET @n_Err = 1000016    
               SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Fail to insert into PackDetail. Function : isp_PackConfirm'          
               GOTO RollBackTran  
            END  
         END  
         ELSE  
         BEGIN  
            -- Update Packdetail  
            UPDATE dbo.PackDetail WITH (ROWLOCK) SET     
               SKU = @cSKU,   
               QTY = QTY + @nQTY,   
               DropID = ISNULL(@cDropID,''),  
               EditWho =  @cUserName,   
               EditDate = GETDATE(),   
               ArchiveCop = NULL,  
               LOTTABLEVALUE = @cLottableVal,
               UPC   = @cUPC
            WHERE PickSlipNo = @cPickSlipNo  
               AND CartonNo = @nCartonNo  
               AND LabelNo = @cCartonID  
            IF @@ERROR <> 0  
            BEGIN           
               SET @b_Success = 0    
               SET @n_Err = 1000017    
               SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Fail to update into PackDetail. Function : isp_PackConfirm'   
               GOTO RollBackTran  
            END  
         END  

      END
   END

     
      --Close: Dynamic EcomWeight  
   IF @EcomSingle = '1'    
   BEGIN      
      --Ecom Carton type  
      IF EXISTS (SELECT TOP 1 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey and SKU = @cSKU and ISNULL(EcomCartonType,'')='' )    
      BEGIN     
         UPDATE SKU WITH (ROWLOCK) SET   
            EcomCartonType = @cCartonType  
         WHERE StorerKey = @cStorerKey   
         and SKU = @cSKU    
      END    
      
      ----Dynamic Ecom Weight col  
      IF @UpdDymEcomWeight = 'Y'  
      BEGIN  
         SET @cDymWgtSQL = 'IF EXISTS (SELECT TOP 1 1 FROM '+@cDymEcomCtnWgtTb+' WITH (NOLOCK) WHERE StorerKey = '''+@cStorerKey+''' and SKU = ''' +@cSKU+''' and (ISNULL('+@cDymEcomCtnWgtCol+','''')='''' OR '+@cDymEcomCtnWgtCol+' = 0))  
            BEGIN  
               UPDATE '+@cDymEcomCtnWgtTb+' WITH (ROWLOCK) SET '+@cDymEcomCtnWgtCol+' = '+@cCartonWeight+' WHERE StorerKey = '''+@cStorerKey+''' and SKU = ''' +@cSKU+'''  
            END  
      '   
         EXEC (@cDymWgtSQL)                   
      END  
      ELSE  
      --Default Ecom Weight col  
      BEGIN  
         IF EXISTS (SELECT TOP 1 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey and SKU = @cSKU and (ISNULL(WEIGHT,'')='' OR WEIGHT = 0))    
         BEGIN     
            UPDATE SKU WITH (ROWLOCK) SET   
               WEIGHT = @cCartonWeight   
            WHERE StorerKey = @cStorerKey   
            and SKU = @cSKU    
         END  
         
         IF @@ERROR <> 0  
         BEGIN           
            SET @b_Success = 0    
            SET @n_Err = 1000018    
            SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Fail to update into SKU. Function : isp_PackConfirm'   
            GOTO RollBackTran  
         END  
      END  
      
      --Dynamic Ecom Cube col  
      IF @UpdDymEcomCube = 'Y'  
      BEGIN  
         SET @cDymCubeSQL = 'IF EXISTS (SELECT TOP 1 1 FROM '+@cDymEcomCtnCubeTb+' WITH (NOLOCK) WHERE StorerKey = '''+@cStorerKey+''' and SKU = ''' +@cSKU+''' and (ISNULL('+@cDymEcomCtnCubeCol+','''')='''' OR '+@cDymEcomCtnCubeCol+' = 0))  
            BEGIN  
               UPDATE '+@cDymEcomCtnCubeTb+' WITH (ROWLOCK) SET '+@cDymEcomCtnCubeCol+' = '+@cCartonCube+' WHERE StorerKey = '''+@cStorerKey+''' and SKU = ''' +@cSKU+'''  
            END  
            '   
         EXEC (@cDymCubeSQL)                   
      END  
      ELSE  
      --Default Ecom Cube col  
      BEGIN  
         IF EXISTS (SELECT TOP 1 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey and SKU = @cSKU and (ISNULL(Cube,'')='' OR Cube = 0))    
         BEGIN     
            UPDATE SKU WITH (ROWLOCK) SET   
               Cube = @cCartonCube  
            WHERE StorerKey = @cStorerKey   
            and SKU = @cSKU    

            IF @@ERROR <> 0  
            BEGIN           
               SET @b_Success = 0    
               SET @n_Err = 1000019    
               SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Fail to update into SKU. Function : isp_PackConfirm'   
               GOTO RollBackTran  
            END 
         END    
      END   
   END     
       
   FETCH NEXT FROM @curPD INTO @cSKU,@nQTY,@cWeight,@cCube,@cLottableJSON,@cUPCJSON  
END 


  
SELECT @nPackQtyCarton = SUM(Qty) FROM packDetail WHERE storerKey = @cStorerKey AND pickSlipNo = @cPickSlipNo AND cartonNo = @nCartonNo  


-- Close: PackInfo  
DECLARE @cWeightItf INT  
DECLARE @nCtnCube Float
DECLARE @nCtnWeight Float
SET @cWeightItf = 0 
SET @nCtnCube  = 0      --XULU01

SELECT   @nCtnCube = cube  ,
         @nCtnWeight = CartonWeight
FROM Cartonization WITH (NOLOCK) --XULU01    
WHERE cartontype = @cCartonType  
  
IF EXISTS (SELECT TOP 1 1 FROM storerConfig WITH (NOLOCK) WHERE configkey ='TPS-CubeByCarton' AND storerKey = @cStorerKey AND sValue = 1)    
BEGIN    
   SET @fCartonCube= @nCtnCube  
END   

IF (@fCartonWeight > 0 OR @fCartonCube > 0)   
BEGIN  
   IF @fCartonWeight > 30   
   BEGIN  
      SET @cWeightItf = 1  
   END  

 --SELECT 'update cartonWeight'  
   IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)  
   BEGIN  

      INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, QTY, Weight, Cube, CartonType,CartonStatus, AddWho,AddDate,EditWho,EditDate)  
      VALUES (@cPickSlipNo, @nCartonNo, @nPackQtyCarton, @fCartonWeight, @fCartonCube, @cCartonType,'Closed',@cUserName,GETDATE(),@cUserName,GETDATE())  
     
      IF @@ERROR <> 0  
      BEGIN    
         SET @b_Success = 0    
         SET @n_Err = 1000008    
         SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Fail to insert into PackInfo. Function : isp_PackConfirm'  
         GOTO RollBackTran  
      END  
   END  
   ELSE  
   BEGIN  
      UPDATE dbo.PackInfo WITH (ROWLOCK) SET   
      --   Qty = @nPackQtyCarton,  
         CartonType = @cCartonType,  
         Weight = @fCartonWeight,  
         [Cube] = @fCartonCube,  
         EditDate = GETDATE(),   
         EditWho = @cUserName,   
         TrafficCop = NULL,  
         cartonStatus = 'Closed'  
      WHERE PickSlipNo = @cPickSlipNo  
         AND CartonNo = @nCartonNo  
        
      IF @@ERROR <> 0  
      BEGIN        
         SET @b_Success = 0    
         SET @n_Err = 1000009    
         SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Fail to update into PackInfo. Function : isp_PackConfirm'  
         GOTO RollBackTran  
      END  
   END  
END  
ELSE  
BEGIN  
 --SELECT 'update skuWeight'  
   DECLARE @ttlWeight FLOAT  
   DECLARE @ttlCube   FLOAT  
   
   IF @ttlWeight > 30   
   BEGIN  
      SET @cWeightItf = 1  
   END  

   SELECT @ttlWeight = SUM(WEIGHT),@ttlCube = SUM(CUBE) FROM @CloseCartonList GROUP BY SKU,QTY,lottableVal  

   IF ISNULL(@ttlCube,0)=0
      SET @ttlCube= @nCtnCube
   
   SET @ttlWeight = @ttlWeight + @nCtnWeight

   IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)  
   BEGIN  
      INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, QTY, Weight, Cube, CartonType,CartonStatus, AddWho,AddDate,EditWho,EditDate)  
      VALUES (@cPickSlipNo, @nCartonNo, @nPackQtyCarton, @ttlWeight, @ttlCube, @cCartonType,'Closed',@cUserName,GETDATE(),@cUserName,GETDATE())  
     
      IF @@ERROR <> 0  
      BEGIN    
         SET @b_Success = 0    
         SET @n_Err = 1000010    
         SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Fail to insert into PackInfo. Function : isp_PackConfirm'  
         GOTO RollBackTran  
      END  
   END  
   ELSE  
   BEGIN  
      UPDATE dbo.PackInfo WITH (ROWLOCK) SET   
    --     QTY = @nPackQtyCarton,  
         CartonType = @cCartonType,  
         Weight = @ttlWeight,  
         [Cube] = @ttlCube,  
         EditDate = GETDATE(),   
         EditWho = @cUserName,   
         TrafficCop = NULL,  
         cartonStatus = 'Closed'  
      WHERE PickSlipNo = @cPickSlipNo  
         AND CartonNo = @nCartonNo  
        
      IF @@ERROR <> 0  
      BEGIN        
         SET @b_Success = 0    
         SET @n_Err = 1000011    
         SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Fail to update into PackInfo. Function : isp_PackConfirm'  
  
         GOTO RollBackTran  
      END  
   END  
END  


  
--DECLARE @cSQL NVARCHAR (MAX)  
--DECLARE @cSQLParam NVARCHAR(MAX)  
DECLARE @cPrintCartonLabelByITF INT  
  
SET @cPrintCartonLabelByITF = 0  
--check weight >30 and hav config  
IF EXISTS (SELECT TOP 1 1 FROM storerConfig WITH (NOLOCK) WHERE configkey ='PrintCartonLabelByITF' AND storerKey = @cStorerKey AND sValue = 1)  
BEGIN  
   SET @cPrintCartonLabelByITF = 1  
END  
  
IF @cWeightItf = 1 AND @cPrintCartonLabelByITF = 1  
BEGIN  
   SET @cSQL = 'EXEC isp_PrintCartonLabel_Interface @c_Pickslipno=@cPickSlipNo, @n_CartonNo_Min=@nCartonNoMin, @n_CartonNo_Max=@nCartonNoMax, @b_Success=@b_Success OUTPUT, @n_Err=@n_Err OUTPUT, @c_ErrMsg=@c_ErrMsg OUTPUT '      
          
   EXEC sp_executesql @cSQL       
      ,N'@cPickSlipNo NVARCHAR(10), @nCartonNoMin INT, @nCartonNoMax INT, @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(255) OUTPUT '       
      ,@cPickSlipNo           
      ,@nCartonNo    
      ,@nCartonNo    
      ,@b_Success      OUTPUT      
      ,@n_Err          OUTPUT      
      ,@c_ErrMsg       OUTPUT      
           
--SELECT @b_Success AS b_Success, @n_Err AS n_Err, @c_ErrMsg AS c_ErrMsg  
     
   IF @n_Err > 0  
   BEGIN  
      GOTO RollBackTran  
   END     
END  
  


   --@cpickslipNo = PickslipNo, @cDropID = DropID,  @cOrderKey=OrderKey, @cLoadKey = LoadKey, @cZone = Zone, @EcomSingle = EcomSingle  
-- Extended validate  --(cc09)  
SELECT @cExtendedUpdateSP = svalue FROM storerConfig WITH (NOLOCK) WHERE storerKey = @cStorerKey AND configKey = 'TPSExtUpdSP'  
IF @cExtendedUpdateSP <> ''    
BEGIN    
   IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')    
   BEGIN    
      SET @cSQL = 'EXEC API.' + RTRIM( @cExtendedUpdateSP) +  
         ' @cStorerKey, @cFacility, @nFunc, @cUserName, @cLangCode, @cScanNo, ' +   
         ' @cpickslipNo, @cDropID, @cOrderKey, @cLoadKey, @cZone, @EcomSingle, ' +  
         ' @nCartonNo, @cCartonType, @cType, @fCartonWeight, @fCartonCube, @cWorkstation, @cLabelNo, ' +   
         ' @cCloseCartonJson,@pickSkuDetailJson, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '  
      SET @cSQLParam =     
         '@cStorerKey      NVARCHAR( 15), ' +  
         '@cFacility       NVARCHAR( 5),  ' +   
         '@nFunc           INT,           ' +  
         '@cUserName       NVARCHAR( 128),' +  
         '@cLangCode       NVARCHAR( 3),  ' +  
         '@cScanNo         NVARCHAR( 50), ' +  
         '@cpickslipNo     NVARCHAR( 30), ' +  
         '@cDropID         NVARCHAR( 50), ' +  
         '@cOrderKey       NVARCHAR( 10), ' +  
         '@cLoadKey        NVARCHAR( 10), ' +  
         '@cZone           NVARCHAR( 18), ' +  
         '@EcomSingle      NVARCHAR( 1),  ' +  
         '@nCartonNo       INT,           ' +  
         '@cCartonType     NVARCHAR( 10), ' +   
         '@cType           NVARCHAR( 30), ' +   
         '@fCartonWeight   FLOAT,         ' +   
         '@fCartonCube     FLOAT,         ' +   
         '@cWorkstation    NVARCHAR( 30), ' +   
         '@cLabelNo        NVARCHAR( 20), ' +  
         '@cCloseCartonJson NVARCHAR( Max), ' +
			'@pickSkuDetailJson   NVARCHAR( MAX),'+
         '@b_Success       INT            OUTPUT, ' +  
         '@n_Err           INT            OUTPUT, ' +  
         '@c_ErrMsg        NVARCHAR( 20)  OUTPUT'  
  
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
         @cStorerKey, @cFacility, @nFunc, @cUserName, @cLangCode, @cScanNo,   
         @cpickslipNo, @cDropID, @cOrderKey, @cLoadKey, @cZone, @EcomSingle,  
         @nCartonNo, @cCartonType, @cType, @fCartonWeight, @fCartonCube, @cWorkstation, @cCartonID,   --yeekung16
         @cCloseCartonJson,@pickSkuDetailJson, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT  
    
      IF @b_Success <> 1  
      BEGIN           
      	SET @b_Success = 0   
         SET @n_Err = @n_Err  
         SET @c_ErrMsg = @c_ErrMsg  
         SET @jResult = (select '' AS OrderKey, '' as LabelJobID, '' as PackingJobID ,@nProceedPrintFlag AS nProceedPrintFlag, '' AS VasConfig, '' AS VasCol1Name, '' AS VasCol1Value, '' AS WorkInstruction FOR JSON PATH )  
         GOTO RollBackTran  
      END             
   END    
END    

  
-- check Qty on pickslip   
DECLARE @nPickslipPackQty INT  
DECLARE @nPickslipPickQty INT  
Declare @cPrintPackList   NVARCHAR( 1)  
  
SET @cPrintPackList = 'N'  

IF EXISTS (SELECT TOP 1 1 FROM storerConfig WITH (NOLOCK) WHERE storerKey = @cStorerKey AND configKey = 'TPS-PackBYRDTTP' AND sValue = '1')    
   SELECT @nPickslipPackQty = ISNULL(SUM(PD.Qty),0)   
   FROM PackDetail PD WITH (NOLOCK)   
   JOIN packInfo PKI WITH (NOLOCK) ON (PD.PickSlipNo = PKI.PickSlipNo AND PD.CartonNo = PKI.CartonNo)  
   WHERE PD.pickslipno = @cPickSlipNo AND PD.Storerkey = @cStorerKey  
ELSE
   SELECT @nPickslipPackQty = ISNULL(SUM(PD.Qty),0)   
   FROM PackDetail PD WITH (NOLOCK)   
   JOIN packInfo PKI WITH (NOLOCK) ON (PD.PickSlipNo = PKI.PickSlipNo AND PD.CartonNo = PKI.CartonNo)  
   WHERE PD.pickslipno = @cPickSlipNo AND PD.Storerkey = @cStorerKey AND PKI.CartonStatus = 'Closed'  
  
SELECT @nPickslipPickQty = SUM(QtyToPack) FROM @pickSKUDetail WHERE pickslipNo = @cPickSlipNo  

SELECT * FROM @pickSKUDetail WHERE pickslipNo = @cPickSlipNo  

IF @nPickslipPackQty = @nPickslipPickQty  
BEGIN  
   UPDATE PackHeader WITH (ROWLOCK) SET   
      Status = '9'   
   WHERE PickSlipNo = @cPickSlipNo  
      AND Status <> '9'  
      
   IF @@ERROR <> 0  
   BEGIN  
      SET @b_Success = 0    
      SET @n_Err = 1000020    
      SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Fail to update into PackHeader. Function : isp_PackConfirm'  
      GOTO RollBackTran  
   END  
     
   --(cc08)  
   EXEC nspGetRight    
         @c_Facility   = @cFacility      
      ,  @c_StorerKey  = @cStorerKey     
      ,  @c_sku        = ''           
      ,  @c_ConfigKey  = 'AssignPackLabelToOrdCfg'     
      ,  @b_Success    = @b_Success                OUTPUT    
      ,  @c_authority  = @cAssignPackLabelToOrdCfg OUTPUT     
      ,  @n_err        = @n_Err                    OUTPUT    
      ,  @c_errmsg     = @c_ErrMsg                 OUTPUT    
     
   IF @cAssignPackLabelToOrdCfg = '1'  
   BEGIN  
      SET @cSQL = 'EXEC isp_AssignPackLabelToOrderByLoad' +                      
                   ' @cPickSlipNo, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '                     
      SET @cSQLParam =                      
         '@cPickSlipNo    NVARCHAR( 20), ' +                      
         '@b_Success      NVARCHAR( 1)  OUTPUT, ' +                           
         '@n_Err          INT           OUTPUT, ' +                      
         '@c_ErrMsg       NVARCHAR( 20) OUTPUT  '                    
                      
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,                      
         @cPickSlipNo, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT  
        
      IF @n_Err <> 0
         GOTO RollBackTran  
   END  
        
   SET @cPrintPackList = 'Y'  
   SET @bToPrint = 1  
END  
  
IF @cPrintCartonLabelByITF = 1  
BEGIN  
   SET @cSQL = 'EXEC isp_PrintCartonLabel_Interface @c_Pickslipno=@cPickSlipNo, @n_CartonNo_Min=@nCartonNoMin, @n_CartonNo_Max=@nCartonNoMax, @b_Success=@b_Success OUTPUT, @n_Err=@n_Err OUTPUT, @c_ErrMsg=@c_ErrMsg OUTPUT '      
          
   EXEC sp_executesql @cSQL       
      ,N'@cPickSlipNo NVARCHAR(10), @nCartonNoMin INT, @nCartonNoMax INT, @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(255) OUTPUT '       
      ,@cPickSlipNo           
      ,@nCartonNo    
      ,@nCartonNo    
      ,@b_Success      OUTPUT      
      ,@n_Err          OUTPUT      
      ,@c_ErrMsg       OUTPUT      
           
   --SELECT @b_Success AS b_Success, @n_Err AS n_Err, @c_ErrMsg AS c_ErrMsg  
     
   IF @n_Err > 0  
   BEGIN  
      SET @b_Success = 0    
      SET @n_Err = @n_Err  
      SET @c_ErrMsg = @c_ErrMsg   
      GOTO RollBackTran  
   END     
END  
  
GOTO Quit  
        
RollBackTran:  
   ROLLBACK TRAN --isp_PackConfirm  
   SET @b_Success = 0  
   SET @jResult = (select '' AS OrderKey, '' as LabelJobID, '' as PackingJobID ,@nProceedPrintFlag AS nProceedPrintFlag, '' AS VasConfig, '' AS VasCol1Name, '' AS VasCol1Value, '' AS WorkInstruction FOR JSON PATH )  
   SET @bToPrint = 0  
   --SELECT @bToPrint AS bToPrint  
  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN --isp_PackConfirm  
  
IF EXISTS (SELECT TOP 1 1 FROM storerConfig WITH (NOLOCK) WHERE storerKey = @cStorerKey AND configKey ='TPS-ExtInfoVAS' AND sValue <> '')  
BEGIN  
   DECLARE @nVasConfig     INT  
   DECLARE @cVasCol1Name   NVARCHAR(30)  
   DECLARE @cVasSP         NVARCHAR(50)  
   DECLARE @cVasSQL        NVARCHAR(MAX)  
   DECLARE @cWorkInstruction  NVARCHAR(4000)  
   DECLARE @cVasCol1Value     NVARCHAR(250)  
   
   SET @nVasConfig = 1  
   SELECT @cVasCol1Name = OPTION1,@cVasSP = sValue FROM storerConfig WITH (NOLOCK) WHERE storerKey = @cStorerKey AND configKey ='TPS-ExtInfoVAS'  
   
   IF ISNULL(@cVasSP,'') <> ''  
   BEGIN  
      SET @cVasSQL = 'EXEC API.'+ @cVasSP+' @cStorerKey=@cStorerKey, @cOrderKey=@cOrderKey, @b_Success=@b_Success OUTPUT, @n_Err=@n_Err OUTPUT, @c_ErrMsg=@c_ErrMsg OUTPUT, @cNotes=@cNotes OUTPUT, @cLong=@cLong OUTPUT '      
          
      EXEC sp_executesql @cVasSQL       
         ,N'@cStorerKey NVARCHAR(15), @cOrderKey NVARCHAR(15), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(255) OUTPUT, @cNotes NVARCHAR( 4000) OUTPUT, @cLong NVARCHAR( 250) OUTPUT'       
         ,@cStorerKey           
         ,@cOrderKey    
         ,@b_Success    OUTPUT      
         ,@n_Err        OUTPUT      
         ,@c_ErrMsg     OUTPUT      
         ,@cWorkInstruction     OUTPUT  
         ,@cVasCol1Value        OUTPUT  
           
      IF @b_Success = 0  
      BEGIN  
         SET @n_Err = @n_Err  
         SET @c_ErrMsg = @c_ErrMsg  
         SET @jResult = (select @cOrderKey AS OrderKey, '' as LabelJobID, '' as PackingJobID ,@nProceedPrintFlag AS nProceedPrintFlag, @nVasConfig AS VasConfig, @cVasCol1Name AS VasCol1Name, '' AS VasCol1Value, '' AS WorkInstruction FOR JSON PATH )   
         GOTO EXIT_SP  
      END    
   END  
END  
  
IF @bToPrint = 1  
BEGIN  
 DECLARE @cLabelPrinter NVARCHAR ( 30)  
   DECLARE @cPaperPrinter NVARCHAR ( 30)  
   DECLARE @cLabelJobID   NVARCHAR ( 30)  
   DECLARE @cPackingJobID NVARCHAR ( 30)  

   DECLARE   @c_ModuleID           NVARCHAR(30) ='TPPack'
            , @c_ReportID           NVARCHAR(10) 
            , @c_PrinterID          NVARCHAR(30)  
            , @c_JobIDs             NVARCHAR(50)   = ''         --(Wan03) -- May return multiple jobs ID.JobID seperate by '|'
            , @c_PrintSource        NVARCHAR(20)
            , @c_AutoPrint          NVARCHAR(1)    = 'N'        --(Wan07)
  
   set @cLabelJobID = ''  
   set @cPackingJobID = ''  
   SET @nProceedPrintFlag = '1'  
   
   -- Extended Print  --(cc10)  
   SELECT @cExtendedPrintSP = svalue FROM storerConfig WITH (NOLOCK) WHERE storerKey = @cStorerKey AND configKey = 'TPSExtPrintSP'  
   IF ISNULL(@cExtendedPrintSP,'') <> ''
   BEGIN    
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedPrintSP AND type = 'P')    
      BEGIN    
         SET @cSQL = 'EXEC API.' + RTRIM( @cExtendedPrintSP) +  
            ' @cStorerKey, @cFacility, @nFunc, @cUserName, @cLangCode, @cScanNo, ' +   
            ' @cpickslipNo, @cDropID, @cOrderKey, @cLoadKey, @cZone, @EcomSingle, ' +  
            ' @nCartonNo, @cCartonType, @cType, @fCartonWeight, @fCartonCube, @cWorkstation, @cLabelNo, ' +   
            ' @cCloseCartonJson, @cPrintPackList,'+
            ' @cLabelJobID OUTPUT, @cPackingJobID OUTPUT, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT ' 
         SET @cSQLParam =     
            '@cStorerKey      NVARCHAR( 15), ' +  
            '@cFacility       NVARCHAR( 5),  ' +   
            '@nFunc           INT,           ' +  
            '@cUserName       NVARCHAR( 128),' +  
            '@cLangCode       NVARCHAR( 3),  ' +  
            '@cScanNo         NVARCHAR( 50), ' +  
            '@cpickslipNo     NVARCHAR( 30), ' +  
            '@cDropID         NVARCHAR( 50), ' +  
            '@cOrderKey       NVARCHAR( 10), ' +  
            '@cLoadKey        NVARCHAR( 10), ' +  
            '@cZone           NVARCHAR( 18), ' +  
            '@EcomSingle      NVARCHAR( 1),  ' +  
            '@nCartonNo       INT,    ' +  
            '@cCartonType     NVARCHAR( 10), ' +   
            '@cType           NVARCHAR( 30), ' +   
            '@fCartonWeight   FLOAT,         ' +   
            '@fCartonCube     FLOAT,         ' +   
            '@cWorkstation    NVARCHAR( 30), ' +   
            '@cLabelNo        NVARCHAR( 20), ' +  
            '@cCloseCartonJson NVARCHAR( Max), ' +  
            '@cPrintPackList  NVARCHAR( 1),  ' +  
            '@cLabelJobID     NVARCHAR ( 30) OUTPUT,  ' +
            '@cPackingJobID   NVARCHAR ( 30) OUTPUT,  ' +
            '@b_Success       INT            OUTPUT, ' +
            '@n_Err           INT            OUTPUT, ' +
            '@c_ErrMsg        NVARCHAR( 20)  OUTPUT'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @cStorerKey, @cFacility, @nFunc, @cUserName, @cLangCode, @cScanNo,
            @cpickslipNo, @cDropID, @cOrderKey, @cLoadKey, @cZone, @EcomSingle,
            @nCartonNo, @cCartonType, @cType, @fCartonWeight, @fCartonCube, @cWorkstation, @cLabelNo,
            @cCloseCartonJson, @cPrintPackList, @cLabelJobID OUTPUT, 
            @cPackingJobID OUTPUT, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT
    
         IF @b_Success <> 1  
         BEGIN  
            SET @b_Success = 0   
            SET @n_Err = @n_Err  
            SET @c_ErrMsg = @c_ErrMsg  
            SET @jResult = (select '' AS OrderKey, '' as LabelJobID, '' as PackingJobID ,@nProceedPrintFlag AS nProceedPrintFlag, '' AS VasConfig, '' AS VasCol1Name, '' AS VasCol1Value, '' AS WorkInstruction FOR JSON PATH )  
            GOTO EXIT_SP  
         END             
      END    
   END    
   ELSE  
   BEGIN  
      --(cc03)  
      DECLARE @tShipLabel AS VariableTable  
      DECLARE @nStartCartonNo INT  
      DECLARE @nEndCartonNo INT  
      --IF @cPrintAfterPacked = '1'  
      --BEGIN  
    
      --   SELECT @nStartCartonNo = MIN(cartonNo),@nEndCartonNo = MAX(CartonNo) FROM PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND pickslipNo = @cPickSlipNo  
      --   -- Common params ofr printing  
      --      --INSERT INTO @tShipLabel (Variable, Value) VALUES   
      --      --   ( '@c_StorerKey',     @cStorerKey),   
      --      --   ( '@c_PickSlipNo',    @cPickSlipNo),   
      --      --   ( '@c_StartCartonNo', CAST( @nStartCartonNo AS NVARCHAR(10))),  
      --      --   ( '@c_EndCartonNo',   CAST( @nEndCartonNo AS NVARCHAR(10)))  
      --END  
      --ELSE  
      --BEGIN  
      --   SET @nStartCartonNo = CAST( @nCartonNo AS NVARCHAR(10))
      --   SET @nEndCartonNo = CAST( @nCartonNo AS NVARCHAR(10))
      --   ---- Common params ofr printing  
      --   --INSERT INTO @tShipLabel (Variable, Value) VALUES   
      --   --   ( '@c_StorerKey',     @cStorerKey),   
      --   --   ( '@c_PickSlipNo',    @cPickSlipNo),   
      --   --   ( '@c_StartCartonNo', CAST( @nCartonNo AS NVARCHAR(10))),  
      --   --   ( '@c_EndCartonNo',   CAST( @nCartonNo AS NVARCHAR(10)))   
      --END  

      --lookup printer  
      SELECT @cPaperPrinter = PrinterID FROM api.AppPrinter WITH (NOLOCK) WHERE Workstation = @cWorkstation AND printerType = 'Paper'  
      SELECT @cLabelPrinter = PrinterID FROM api.AppPrinter WITH (NOLOCK) WHERE Workstation = @cWorkstation AND printerType = 'Label'  
        
      IF @cDisableLblPrint=0  
      BEGIN  
         -- Print label  
         IF EXISTS (SELECT  TOP 1 1 FROM dbo.WMReport WMR WITH (NOLOCK) 
                    JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid =WMRD.reportid
                    WHERE Storerkey = @cStorerKey 
                     AND reporttype ='TPSHIPPLBL'
                     AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility) )  
         BEGIN  
            SELECT   @c_ReportID = WMR.reportid,
               @c_PrintSource = CASE WHEN printtype='LOGIREPORT' THEN 'JReport' ELSE 'WMReport' END,
               @cNewLabelPrinter = Defaultprinterid,
               @cFieldName1  = keyFieldname1,
               @cFieldName2  = keyFieldname2,
               @cFieldName3  = keyFieldname3,
               @cFieldName4  = keyFieldname4
            FROM WMReport WMR (NOLOCK)
            JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid =WMRD.reportid
            WHERE Storerkey = @cStorerkey
               AND reporttype = 'TPSHIPPLBL'
               AND ModuleID ='TPPack'
               AND ispaperprinter <> 'Y'
               and (WMRD.username = '' OR WMRD.username = @cUsername)
               AND (ISNULL(ComputerName,'') ='' OR ComputerName= @cWorkstation)
               AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility) 

            IF @cPrintAfterPacked = '1'  
            BEGIN 
               SET  @cSQL =
               'SELECT  @cParams1='+ @cFieldName1  
                        SELECT @cSQL= CASE  WHEN ISNULL(@cFieldName2,'')<>''THEN @cSQL +',@cParams2=' + @cFieldName2  ELSE  @cSQL END 
                        SELECT @cSQL= CASE WHEN ISNULL(@cFieldName3,'')<>''THEN @cSQL +',@cParams3='  + @cFieldName3  ELSE  @cSQL END
                        SELECT @cSQL= CASE WHEN ISNULL(@cFieldName4,'')<>''THEN @cSQL +',@cParams4='  + @cFieldName4  ELSE  @cSQL END
               SET @cSQL = @cSQL +' FROM Packdetail (NOLOCK)
                  WHERE Storerkey = @cstorerkey
                     AND Pickslipno = @cPickslipno
                  GROUP BY Pickslipno,Storerkey
                  '
            END
            ELSE
            BEGIN 
               SET  @cSQL =
               'SELECT  @cParams1='+ @cFieldName1  
                        SELECT @cSQL= CASE  WHEN ISNULL(@cFieldName2,'')<>''THEN @cSQL +',@cParams2=' + @cFieldName2  ELSE  @cSQL END 
                        SELECT @cSQL= CASE WHEN ISNULL(@cFieldName3,'')<>''THEN @cSQL +',@cParams3='  + @cFieldName3  ELSE  @cSQL END
                        SELECT @cSQL= CASE WHEN ISNULL(@cFieldName4,'')<>''THEN @cSQL +',@cParams4='  + @cFieldName4  ELSE  @cSQL END
               SET @cSQL = @cSQL +' FROM Packdetail (NOLOCK)
                  WHERE Storerkey = @cstorerkey
                     AND Pickslipno = @cPickslipno
                     AND CartonNO = @nCartonno
                  '
            END

            SET @cSQLParam = 
            ' @cFieldName1 NVARCHAR(max),
               @cFieldName2 NVARCHAR(max),
               @cFieldName3 NVARCHAR(max),
               @cFieldName4 NVARCHAR(max),
               @cParams1    NVARCHAR(max) OUTPUT,
               @cParams2    NVARCHAR(max) OUTPUT,
               @cParams3    NVARCHAR(max) OUTPUT,
               @cParams4    NVARCHAR(max) OUTPUT,
               @cstorerkey  NVARCHAR(20),
               @cPickslipno NVARCHAR(20),
               @nCartonno   INT'

            EXEC sp_ExecuteSQL @cSQL,@cSQLParam,@cFieldName1,@cFieldName2,@cFieldName3,@cFieldName4,
                                 @cParams1 OUTPUT,@cParams2 OUTPUT,@cParams3 OUTPUT,@cParams4 OUTPUT,@cstorerkey,@cPickslipno,@nCartonno 
            

            IF ISNULL(@cNewLabelPrinter,'')= ''
               SET @cNewLabelPrinter = @cLabelPrinter

            IF ISNULL(@cNewLabelPrinter,'') = ''  
            BEGIN  
               SET @b_Success = 0    
               SET @n_Err = 1000021    
               SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Label Printer setup not done. Please setup the Label Printer. Function : isp_PackConfirm'  
               SET @jResult = (select @cOrderKey AS OrderKey, '' as LabelJobID, '' as PackingJobID ,@nProceedPrintFlag AS nProceedPrintFlag, @nVasConfig AS VasConfig, @cVasCol1Name AS VasCol1Name, @cVasCol1Value AS VasCol1Value, @cWorkInstruction AS WorkInstruction FOR JSON PATH )   
               GOTO EXIT_SP  
            END  
            ELSE  
            BEGIN  
               --EXEC API.isp_Print @cLangCode, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,   
               --   'TPSHIPPLBL', -- Report type  
               --   @tShipLabel, -- Report params  
               --   'API.isp_PackConfim', --source Type  
               --   @n_Err  OUTPUT,  
               --   @c_ErrMsg OUTPUT,  
               --   '1', --noOfCopy  
               --   '', --@cPrintCommand  
               --   @nJobID OUTPUT,  
               --   @cUsername  
  
               --set @cLabelJobID = @nJobID  

                 EXEC  [WM].[lsp_WM_Print_Report]
                    @c_ModuleID = @c_ModuleID           
                  , @c_ReportID = @c_ReportID         
                  , @c_Storerkey = @cStorerkey         
                  , @c_Facility  = @cFacility        
                  , @c_UserName  = @cUsername   
                  , @c_ComputerName = ''
                  , @c_PrinterID = @cNewLabelPrinter         
                  , @n_NoOfCopy  = '1'     
                  , @c_KeyValue1 = @cParams1        
                  , @c_KeyValue2 = @cParams2        
                  , @c_KeyValue3 = @cParams3     
                  , @c_KeyValue4 = @cParams4    
                  , @b_Success   = @b_Success         OUTPUT      
                  , @n_Err       = @n_Err             OUTPUT
                  , @c_ErrMsg    = @c_ErrMsg          OUTPUT
                  , @c_PrintSource  = @c_PrintSource        
                  , @b_SCEPreView   = 0         
                  , @c_JobIDs      = @cLabelJobID         OUTPUT    
                  , @c_AutoPrint  = 'N'     
         
  
               IF @n_Err <> 0   
               BEGIN  
                  SET @b_Success = 0  
                  SET @n_Err = @n_Err  
                  SET @c_ErrMsg = @c_ErrMsg  
                  SET @jResult = (select @cOrderKey AS OrderKey, '' as LabelJobID, '' as PackingJobID ,@nProceedPrintFlag AS nProceedPrintFlag, @nVasConfig AS VasConfig, @cVasCol1Name AS VasCol1Name, @cVasCol1Value AS VasCol1Value, @cWorkInstruction AS WorkInstruction FOR JSON PATH )   
                  GOTO EXIT_SP  
               END  
            END   
         END  
      END  
  
      IF @cDisablePLPrint=0  
      BEGIN  
         IF @cPrintPackList = 'Y'   
         BEGIN  
            IF EXISTS (SELECT  TOP 1 1 FROM dbo.WMReport WMR WITH (NOLOCK) 
                       JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid =WMRD.reportid
                       WHERE Storerkey = @cStorerKey 
                        AND reportType ='TPPACKLIST'
                        AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility) )  
            BEGIN  
               IF ISNULL(@cPaperPrinter,'') = ''  
               BEGIN  
                  SET @b_Success = 0    
                  SET @n_Err = 1000022    
                  SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Paper Printer setup not done. Please setup the Paper Printer. Function : isp_PackConfirm'  
                  SET @jResult = (select @cOrderKey AS OrderKey, '' as LabelJobID, '' as PackingJobID ,@nProceedPrintFlag AS nProceedPrintFlag, @nVasConfig AS VasConfig, @cVasCol1Name AS VasCol1Name, @cVasCol1Value AS VasCol1Value, @cWorkInstruction AS WorkInstruction FOR JSON PATH )   
                  GOTO EXIT_SP  
               END  
               ELSE  
               BEGIN  
	             --  DECLARE @tPackList AS VariableTable

	   	         --INSERT INTO @tPackList (Variable, Value) VALUES
	             --     ( '@c_PickSlipNo',    @cPickSlipNo)


	               --EXEC API.isp_Print @cLangCode, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
	               --   'TPPACKLIST', -- Report type
	               --   @tPackList, -- Report params
	               --   'API.isp_PackConfim', --source Type
	               --   @n_Err  OUTPUT,
	               --   @c_ErrMsg OUTPUT,
	               --   '1', --noOfCopy
	               --   '', --@cPrintCommand
	               --   @nJobID OUTPUT,
	               --   @cUsername
  
                --  SET @cPackingJobID = @nJobID  

                  SELECT   @c_ReportID = WMR.reportid,
                     @c_PrintSource = CASE WHEN printtype='LOGIREPORT' THEN 'JReport' ELSE 'WMReport' END,
                     @cNewPaperPrinter = Defaultprinterid,
                     @cFieldName1  = keyFieldname1,
                     @cFieldName2  = keyFieldname2,
                     @cFieldName3  = keyFieldname3,
                     @cFieldName4  = keyFieldname4
                  FROM WMReport WMR (NOLOCK)
                  JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid =WMRD.reportid
                  WHERE Storerkey = @cStorerkey
                     AND reporttype = 'TPPACKLIST'
                     AND ModuleID ='TPPack'
                     AND ispaperprinter = 'Y'
                     and (WMRD.username = '' OR WMRD.username = @cUsername)
                     AND (ISNULL(ComputerName,'') ='' OR ComputerName= @cWorkstation)
                     AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility) 

                  SET @cSQL = ''
                  SET @cSQLParam = ''

                  SET  @cSQL =
                  'SELECT  @cParams1='+ @cFieldName1  
                           SELECT @cSQL= CASE  WHEN ISNULL(@cFieldName2,'')<>''THEN @cSQL +',@cParams2=' + @cFieldName2  ELSE  @cSQL END 
                           SELECT @cSQL= CASE WHEN ISNULL(@cFieldName3,'')<>''THEN @cSQL +',@cParams3='  + @cFieldName3  ELSE  @cSQL END
                           SELECT @cSQL= CASE WHEN ISNULL(@cFieldName4,'')<>''THEN @cSQL +',@cParams4='  + @cFieldName4  ELSE  @cSQL END
                  SET @cSQL = @cSQL +' FROM Packdetail (NOLOCK)
                     WHERE Storerkey = @cstorerkey
                        AND Pickslipno = @cPickslipno
                        AND CartonNO = @nCartonno
                     '


                  SET @cSQLParam = 
                  ' @cFieldName1 NVARCHAR(max),
                     @cFieldName2 NVARCHAR(max),
                     @cFieldName3 NVARCHAR(max),
                     @cFieldName4 NVARCHAR(max),
                     @cParams1    NVARCHAR(max) OUTPUT,
                     @cParams2    NVARCHAR(max) OUTPUT,
                     @cParams3    NVARCHAR(max) OUTPUT,
                     @cParams4    NVARCHAR(max) OUTPUT,
                     @cstorerkey  NVARCHAR(20),
                     @cPickslipno NVARCHAR(20),
                     @nCartonno   INT'

                  EXEC sp_ExecuteSQL @cSQL,@cSQLParam,@cFieldName1,@cFieldName2,@cFieldName3,@cFieldName4,
                                       @cParams1 OUTPUT,@cParams2 OUTPUT,@cParams3 OUTPUT,@cParams4 OUTPUT,@cstorerkey,@cPickslipno,@nCartonno 

                  IF ISNULL(@cNewPaperPrinter,'')= ''
                     SET @cNewPaperPrinter = @cPaperPrinter


                  EXEC  [WM].[lsp_WM_Print_Report]
                     @c_ModuleID = @c_ModuleID           
                  , @c_ReportID = @c_ReportID         
                  , @c_Storerkey = @cStorerkey         
                  , @c_Facility  = @cFacility        
                  , @c_UserName  = @cUsername     
                  , @c_ComputerName = ''
                  , @c_PrinterID = @cNewPaperPrinter         
                  , @n_NoOfCopy  = '1'     
                  , @c_KeyValue1 = @cParams1        
                  , @c_KeyValue2 = @cParams2     
                  , @c_KeyValue3 = @cParams3 
                  , @c_KeyValue4 = @cParams4
                  , @b_Success   = @b_Success         OUTPUT      
                  , @n_Err       = @n_Err             OUTPUT
                  , @c_ErrMsg    = @c_ErrMsg          OUTPUT
                  , @c_PrintSource  = @c_PrintSource        
                  , @b_SCEPreView   = 0         
                  , @c_JobIDs      = @cPackingJobID         OUTPUT    
                  , @c_AutoPrint  = 'N'   
                  
                  SET @cPackingJobID = @nJobID  
  
                  IF @n_Err <> 0   
                  BEGIN  
                     SET @b_Success = 0  
                     SET @n_Err = @n_Err  
                     SET @c_ErrMsg = @c_ErrMsg  
                     SET @jResult = (select @cOrderKey AS OrderKey, '' as LabelJobID, '' as PackingJobID ,@nProceedPrintFlag AS nProceedPrintFlag, @nVasConfig AS VasConfig, @cVasCol1Name AS VasCol1Name, @cVasCol1Value AS VasCol1Value, @cWorkInstruction AS WorkInstruction FOR JSON PATH )   
                     GOTO EXIT_SP  
                  END  
               END   
            END  
         END  
      END  
     
      --custom printSP --(cc04)  
      DECLARE @cCustomLabelSP    NVARCHAR(30)  
      SELECT @cCustomLabelSP = svalue FROM storerConfig WITH (NOLOCK) WHERE storerKey =@cStorerKey AND configKey = 'TPS-labelSP'   
     
      IF ISNULL (@cCustomLabelSP,'') <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cCustomLabelSP AND type = 'P')    
         BEGIN  
            SET @cSQL = 'EXEC ' + RTRIM( @cCustomLabelSP) +    
               ' @cStorerKey, @cFacility, @cUserName,  @cPickSlipNo, @cLabelPrinter, @cPaperPrinter, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@cStorerKey      NVARCHAR( 15),' +    
               '@cFacility       NVARCHAR( 5), ' +  
               '@cUserName       NVARCHAR(128),' +      
               '@cPickSlipNo     NVARCHAR( 30),' +    
               '@cLabelPrinter   NVARCHAR( 30),' +    
               '@cPaperPrinter  NVARCHAR( 30),' +    
               '@nErrNo          INT OUTPUT,  ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT'    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @cStorerKey, @cFacility, @cPickSlipNo, @cLabelPrinter, @cPaperPrinter, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Quit    
         END  
      END  
     
     
      IF EXISTS (SELECT  TOP 1 1 FROM dbo.WMReport WMR WITH (NOLOCK) 
                  JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid =WMRD.reportid
                  WHERE Storerkey = @cStorerKey 
                     AND reportType ='TPCtnLbl'
                     AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility) )   
      BEGIN  
         --DECLARE @tCtnLabel AS VariableTable  
      
         --INSERT INTO @tCtnLabel (Variable, Value) VALUES   
         --   ( '@c_PickSlipNo',    @cPickSlipNo)  
      
         --EXEC API.isp_Print @cLangCode, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,   
         --   'TPCtnLbl', -- Report type  
         --   @tCtnLabel, -- Report params  
         --   'API.isp_PackConfim', --source Type  
         --   @n_Err  OUTPUT,  
         --   @c_ErrMsg OUTPUT,  
         --   '1', --noOfCopy  
         --   '', --@cPrintCommand  
         --   @nJobID OUTPUT,  
         --   @cUsername  
         
         SELECT @c_ReportID = WMR.reportid,
                  @c_PrintSource = CASE WHEN printtype='LOGIREPORT' THEN 'JReport' ELSE 'WMReport' END
         FROM WMReport WMR (NOLOCK)
         JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid =WMRD.reportid
         WHERE Storerkey = @cStorerkey
            AND reporttype = 'TPCtnLbl'
            AND ModuleID ='TPPack'
            and (WMRD.username = '' OR WMRD.username = @cUsername)
            AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility) 

         EXEC  [WM].[lsp_WM_Print_Report]
            @c_ModuleID = @c_ModuleID           
            , @c_ReportID = @c_ReportID         
            , @c_Storerkey = @cStorerkey         
            , @c_Facility  = @cFacility        
            , @c_UserName  = @cUsername          
            , @c_ComputerName = ''
            , @c_PrinterID = @cLabelPrinter         
            , @n_NoOfCopy  = '1'     
            , @c_KeyValue1 = @cPickSlipNo        
            , @c_KeyValue2 = ''     
            , @c_KeyValue3 = ''     
            , @c_KeyValue4 = ''     
            , @b_Success   = @b_Success         OUTPUT      
            , @n_Err       = @n_Err             OUTPUT
            , @c_ErrMsg    = @c_ErrMsg          OUTPUT
            , @c_PrintSource  = @c_PrintSource        
            , @b_SCEPreView   = 0         
            , @c_JobIDs      = @cPackingJobID         OUTPUT    
            , @c_AutoPrint  = 'N'    
  
         SET @cPackingJobID = @nJobID  
  
         IF @n_Err <> 0   
         BEGIN  
            SET @b_Success = 0  
            SET @n_Err = @n_Err  
            SET @c_ErrMsg = @c_ErrMsg  
            SET @jResult = (select @cOrderKey AS OrderKey, '' as LabelJobID, '' as PackingJobID ,@nProceedPrintFlag AS nProceedPrintFlag, @nVasConfig AS VasConfig, @cVasCol1Name AS VasCol1Name, @cVasCol1Value AS VasCol1Value, @cWorkInstruction AS WorkInstruction FOR JSON PATH )   
            GOTO EXIT_SP  
         END  
      END  
   END  
END  
  
IF @b_Success = 1  
BEGIN  
   SET @n_Err = 0  
   SET @c_ErrMsg = ''  
   SET @jResult = (select @cOrderKey AS OrderKey, @cLabelJobID as LabelJobID, @cPackingJobID as PackingJobID ,@nProceedPrintFlag AS nProceedPrintFlag, @nVasConfig AS VasConfig, @cVasCol1Name AS VasCol1Name, @cVasCol1Value AS VasCol1Value, @cWorkInstruction AS WorkInstruction FOR JSON PATH )   
END     
           
EXIT_SP:  
REVERT  
  
END  

GO