SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*********************************************************************************/    
/* Store procedure: isp_GetToPackDetail                                          */    
/* Copyright      : LFLogistics                                                  */    
/*                                                                               */    
/* Date         Rev  Author     Purposes                                         */    
/* 2019-11-08   1.0  Chermaine  Created                                          */    
/* 2020-12-30   1.1  Chermaine  TPS-518 Add @PackCaptureNewLabelno config (cc01) */    
/* 2021-01-25   1.2  Chermaine  TPS-271 Add Config to print at last Carton(cc02) */    
/* 2021-01-25   1.3  Chermaine  TPS-527 Add Config defaultCartonType (cc03)      */    
/* 2021-03-17   1.4  Chermaine  TPS-572/473 Add Config AutoScanInWhenPack (cc04) */    
/* 2021-03-22   1.5  Chermaine  TPS-567 Add Config AutoScanoutWhenPack           */    
/*                                      Add Config CheckPickB4Pack (cc05)        */    
/* 2021-04-21   1.6  Chermaine  TPS-563 Add display info (cc06)                  */    
/* 2021-04-21   1.7  Chermaine  TPS-476 Add Indicator (cc07)                     */    
/* 2021-05-28   1.8  Chermaine  TPS-591 Add lottable config (cc08)               */    
/* 2021-08-28   1.9  Chermaine  TPS-596 Add ExternalSP for skipCartonize (cc09)  */    
/* 2021-09-03   2.0  Chermaine  TPS-563 change country code to countryName (cc10)*/    
/* 2021-09-05   2.1  Chermaine  TPS-11  ErrMsg add to rdtmsg (cc11)              */    
/* 2021-09-22   2.2  Chermaine  TPS-616 Add DecodeSP (cc12)                      */    
/* 2021-12-08   2.3  Chermaine  WMS-18363 Trim SKU (cc13)                        */    
/* 2021-12-08   2.4  Chermaine  TPS-612 Add PackIndicator Config (cc14)          */    
/* 2022-05-18   2.5  YeeKung    WMS-19689 Add lower (yeekung01)                  */  
/* 2022-07-19   2.6  YeeKung    TPS-648 Add UCC (yeekung02)                      */  
/* 2023-02-10   2.7  yeekung    TPS-661 Add Packheaderstatus (yeekung01)         */  
/* 2023-02-28   2.8  YeeKung    TPS-557 Add otherunit2/removeskuserialnocapture  */  
/*                               (yeekung04)                                     */  
/* 2023-03-14   2.9  YeeKung    TPS-681 remove UCC (yeekung05)                   */  
/* 2023-06-06   3.0  YeeKung    TPS-684 Add Loadkey (yeekung06)                  */  
/* 2023-08-16   3.1  YeeKung    TPS-779 Get KeyPad (yeekung07)                   */  
/* 2023-08-28   3.2  YeeKung    TPS-766 skipconfirm config (yeekung08)           */  
/* 2023-12-20   3.3  YeeKung    TPS-833 Correct the cartonno (yeekung09)         */  
/* 2024-01-26   3.4  YeeKung    JSM-205457 Add trim SKU (yeekung10)              */  
/* 2024-01-31   3.5  YeeKung    TPS-879 Fix Maxcarton +1 (yeekung11)             */  
/*                                  storerkey = @cstorerkey (yeekung12)          */  
/* 2024-02-05   3.6  YeeKung    TPS-882 Fix get in between cartonno (yeekung13)  */  
/* 2024-02-07   3.7  YeeKung    TPS-863 Dynamic Show display column (yeekung14)  */  
/* 2024-02-09   3.8  YeeKung    TPS-821 Add display print(yeekung15)             */      
/* 2024-02-28   3.9  YeeKung    TPS-842 Performance Tune Add page (yeekung15)    */  
/* 2024-05-29   4.0  YeeKung    Solved blocking (yeekung16)							   */  
/* 2024-06-18   4.1  YeeKung    TPS-925 Add TPS-ConfirmADSCN (yeekung17)			*/  
/* 2024-11-06   4.2  YeeKung    TPS-969 Add Facility (yeekung18)                 */  
/* 2025-01-10   4.3  YeeKung    Fix Storer and Facility (yeekung19)              */  
/* 2025-01-13   4.4  YeeKung    UWP-28644 Fix the ConfirmADScn (yeekung19)       */    
/* 2025-01-21   4.5  Yeekung    FCR-1542 Customize Disable Numpad (yeekung20)    */  
/* 2025-01-21   4.6  YeeKung    TPS-995 Change error message (yeekung21)         */  
/* 2025-02-04   4.7  YeeKung    UWP-28228 Add TimeZone (yeekung22)               */  
/*********************************************************************************/    
    
CREATE   PROC [API].[isp_GetToPackDetail] (    
   @json       NVARCHAR( MAX),    
   @jResult    NVARCHAR( MAX) OUTPUT,    
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
      @cLangCode     NVARCHAR( 3),    
      @cUserName     NVARCHAR( 30),    
      @cStorerKey    NVARCHAR( 15),    
      @cFacility     NVARCHAR( 5),    
      @nFunc         INT,    
      @cScanNo       NVARCHAR( 30),    
      @cType         NVARCHAR( 30),    
      @cScanNoType   NVARCHAR( 30),    
      @cPickSlipNo   NVARCHAR( 30),    
      @cDropID       NVARCHAR( 30),    
     
      @cOrderKey     NVARCHAR( 10),    
      @cLoadKey      NVARCHAR( 10),    
      @cZone         NVARCHAR( 18),    
      @cLot          NVARCHAR( 30),    
      @cStatus       NVARCHAR( 2),    
      @cCtryCode     NVARCHAR( 10),  --(cc06)    
      @cIndicator    NVARCHAR( 20),  --(cc07)    
     
      @nTotalPick    INT,    
      @nTotalShort   INT,    
      @EcomSingle    NVARCHAR( 1),    
      @CalOrderSKU   NVARCHAR( 1),    
      @cAutoScanInWhenPack    NVARCHAR ( 1), --(cc04)    
      @cAutoScanOutWhenPack   NVARCHAR ( 1), --(cc05)    
      @cCheckPickB4Pack       NVARCHAR ( 1), --(cc05)    
      @cAutoScanOutOp1        NVARCHAR (20), --(cc05)    
      @cOrderStatus           NVARCHAR ( 1), --(cc05)    
      @cPickingPickslipNo     NVARCHAR (30), --(cc05)    
      @cPackByLottable        NVARCHAR(30),  --(cc08)    
      @cLottableNum           NVARCHAR(50),  --(cc08)    
      @cLotLabel              NVARCHAR(50),  --(cc08)    
      @cLotDropDownBy         NVARCHAR(50),  --(cc08)    
      @cAutoDefaultLot        NVARCHAR(50),  --(cc08)    
      @cLotSP                 NVARCHAR(50),  --(cc08)    
      @cSkipCartonSP          NVARCHAR(30),  --(cc09)    
      @cPackQtyIndicatorFlag  NVARCHAR(1),   --(cc14)    
      @nPackQtyIndicator      INT,           --(cc14)    
     
      @cDynamicTb1   NVARCHAR( 30),    
      @cDynamicTb2   NVARCHAR( 30),    
      @cDynamicCol1  NVARCHAR( 30),    
      @cDynamicCol2  NVARCHAR( 30),    
     
      @cDynamicRightName1  NVARCHAR( 30),    
      @cDynamicRightValue1 NVARCHAR( 30),    
      @cDymEcomCtnWgtTb    NVARCHAR( 20),    
      @cDymEcomCtnWgtCol   NVARCHAR( 20),    
      @cDymEcomCtnCubeTb   NVARCHAR( 20),    
      @cDymEcomCtnCubeCol  NVARCHAR( 20),    
      @cDymCtnWgtTb        NVARCHAR( 20),    
      @cDymCtnWgtCol       NVARCHAR( 20),    
      @cDymCtnCubeTb       NVARCHAR( 20),    
      @cDymCtnCubeCol      NVARCHAR( 20),    
      @pickSkuDetailJson   NVARCHAR( MAX),  
      @cGetKeyPadInput     NVARCHAR( 1), --(yeekung07)  
      @cGetKeyPadInputSP   NVARCHAR( 20), --(yeekung07)  
      @cSkipPckCfmBtn      NVARCHAR( 20), --(yeekung08)  
      @cDisplayvalueCol    NVARCHAR( 20),  
      @cDisplayDesc        NVARCHAR( 60),  
      @cGetReprintOpt      NVARCHAR( 20),  
      @cTimeZone           NVARCHAR( 20)  
  
   DECLARE @cSQLMainSelect NVARCHAR( MAX)   
   DECLARE @cSQL       NVARCHAR( MAX)    
   DECLARE @cSQLParams NVARCHAR( MAX)    
     
   SET @EcomSingle = '0'    
   SET @CalOrderSKU = 'N'    
     
   --LEFT Panel: SKU + Image    
   DECLARE @packSKUDetail TABLE (    
      SKU              NVARCHAR( 30),    
      Descr            NVARCHAR( 150),    
      RetailSKU        NVARCHAR( 30),    
      ManufacturerSKU  NVARCHAR( 30),    
      AltSKU           NVARCHAR( 30),    
      QtyToPack        INT,    
      PackedQty        INT,    
      PackQtyIndicator INT,   --(cc14)    
      Img              NVARCHAR( 1024),    
      Ecom_CartonType  NVARCHAR( 10),    
      AD               NVARCHAR( 1),  --(cc12)    
      PackOtherUnit    INT,   --(cc14)    
      WEIGHT           FLOAT,    
      CUBE             FLOAT,    
      Ecom_Weight      FLOAT,    
      Ecom_Cube        FLOAT,    
      DynamicColName1  NVARCHAR( 50),    
      DynamicColName2  NVARCHAR( 50),    
      DynamicColValue1 NVARCHAR( 150),    
      DynamicColValue2 NVARCHAR( 150)    
   )    
    
   --DECLARE @pickSKUDetail TABLE (    
   CREATE TABLE #pickSKUDetail (    
      SKU              NVARCHAR( 30),    
      QtyToPack        INT,    
      OrderKey         NVARCHAR( 30),    
      PickslipNo       NVARCHAR( 30),    
      LoadKey          NVARCHAR( 30),--externalOrderKey    
      PickDetailStatus NVARCHAR ( 3)--,  
   --  UCCNo            NVARCHAR( 20)--(yeekung02)  
   )    
  
  
   --DECLARE @pickSKUDetail TABLE (    
   CREATE TABLE #PackTable (    
      SKU              NVARCHAR( 30),    
      QtyToPack        INT,    
      PickslipNo       NVARCHAR( 30)   
   --  UCCNo            NVARCHAR( 20)--(yeekung02)  
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
      SET @n_Err = 1000851    
      SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Please scan or enter Packing Document No to proceed. Function : isp_GetToPackDetail'    
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
  
   select @jResult as '1'  
     
   --Decode Json Format    
   SELECT @cScanNoType = ScanNoType, @cpickslipNo = PickslipNo, @cDropID = DropID,  @cOrderKey=OrderKey, @cLoadKey = LoadKey, @cZone = Zone, @EcomSingle = EcomSingle    
   , @cDynamicRightName1 = DynamicRightName1, @cDynamicRightValue1 = DynamicRightValue1,@pickSkuDetailJson = PickSkuDetail    
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
     
   INSERT INTO #pickSKUDetail    
   SELECT *    
   FROM OPENJSON(@pickSkuDetailJson)    
   WITH (    
      SKU               NVARCHAR( 20)  '$.SKU',    
      QtyToPack         INT            '$.QtyToPack',    
      OrderKey          NVARCHAR( 10)  '$.OrderKey',    
      PickslipNo        NVARCHAR( 30)  '$.PickslipNo',    
      LoadKey           NVARCHAR( 10)  '$.LoadKey',    
      PickDetailStatus  NVARCHAR( 1)   '$.PickDetailStatus' --,  
   --  UCCNO             NVARCHAR( 20)  '$.UCCNo'      --(yeekung02)            
   )    
   --SELECT * FROM #pickSKUDetail    
   --check storerConfig to skip cartonize    
   DECLARE @skipCartonize     NVARCHAR( 1)    
   DECLARE @hidePackedSku     NVARCHAR( 1)    
   DECLARE @navCtnScn NVARCHAR( 1)    
   DECLARE @cPrintAfterPack   NVARCHAR( 1)    --(cc02)    
   DECLARE @cDefaultCartonType   NVARCHAR( 1) --(cc03)    
   DECLARE @cDecodeSP         NVARCHAR( 20)   --(cc12)    
   DECLARE @cADBarcode        NVARCHAR( 60)   --(cc12)    
   DECLARE @cScanGetUCC       NVARCHAR( 1)   --(cc12)    
   DECLARE @cGetUCC           NVARCHAR( 20)  
   DECLARE @cConfirmADScn     NVARCHAR( 20)  
     
   SET @hidePackedSku = '0'    
   SET @cADBarcode = '0'    
     
   --(cc02)    
   SELECT @cPrintAfterPack = sValue FROM dbo.StorerConfig WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND configKey = 'TPS-PrintAfterPacked'    
   --(cc03)    
   SELECT @cDefaultCartonType = sValue FROM dbo.StorerConfig WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND configKey = 'DefaultCartonType'    
     
   SELECT @navCtnScn = sValue FROM dbo.StorerConfig WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND configKey = 'TPS-NavCtnScn'    
  
   EXEC nspGetRight    
         @c_Facility   = @cFacility   
      ,  @c_StorerKey  = @cStorerKey   
      ,  @c_sku        = ''    
      ,  @c_ConfigKey  = 'TPS-GetReprintOpt'    
      ,  @b_Success    = @b_Success       OUTPUT    
      ,  @c_authority  = @cGetReprintOpt OUTPUT    
      ,  @n_err        = @n_Err           OUTPUT    
      ,  @c_errmsg     = @c_ErrMsg        OUTPUT  
  
      --(cc12)    
   SELECT @cDecodeSP = sValue FROM dbo.StorerConfig WITH (NOLOCK) WHERE storerKey = @cStorerKey AND configKey = 'TPS-DecodeSP'    
   IF ISNULL(@cDecodeSP,'') <> ''    
   BEGIN    
   SET @cDecodeSP = '1'    
   END    
   ELSE    
      SET @cDecodeSP = '0'    
  
   --(cc12)    
   SELECT @cGetUCC = sValue FROM dbo.StorerConfig WITH (NOLOCK) WHERE storerKey = @cStorerKey AND configKey = 'TPS-GetUCC'    
   IF ISNULL(@cGetUCC,'')  IN ('','0')   
   BEGIN    
   SET @cGetUCC = '0'    
   END    
   ELSE  
   BEGIN  
      SET @cGetUCC = '1'    
   END  
  
  
   SELECT @cConfirmADScn = sValue FROM dbo.StorerConfig WITH (NOLOCK) WHERE storerKey = @cStorerKey AND configKey = 'TPS-ConfirmADScn'    
   IF ISNULL(@cConfirmADScn,'') IN ('','0')   
   BEGIN    
      SET @cConfirmADScn = '0'    
   END    
   ELSE  
   BEGIN  
      SET @cConfirmADScn = '1'    
   END  
  
   IF EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK) WHERE Listname = 'REQEXP'AND Code ='ADBARCODE' AND storerKey = @cStorerKey)    
   BEGIN    
      SET @cADBarcode = '1'    
   END    
    
   --(cc08)    
   SET @cPackByLottable = ''    
   EXEC nspGetRight    
         @c_Facility   = @cFacility    
      ,  @c_StorerKey  = @cStorerKey    
      ,  @c_sku        = ''    
      ,  @c_ConfigKey  = 'PackByLottable'    
      ,  @b_Success    = @b_Success       OUTPUT    
      ,  @c_authority  = @cPackByLottable OUTPUT    
      ,  @n_err        = @n_Err           OUTPUT    
      ,  @c_errmsg     = @c_ErrMsg        OUTPUT    
      ,  @c_Option1    = @cLottableNum    OUTPUT    
      ,  @c_Option2    = @cLotLabel       OUTPUT    
      ,  @c_Option3    = @cLotDropDownBy  OUTPUT    
      ,  @c_Option4    = @cAutoDefaultLot OUTPUT    
      ,  @c_Option5    = @cLotSP          OUTPUT    
  
   EXEC nspGetRight  -- (yeekung20)  
         @c_Facility   = @cFacility   
      ,  @c_StorerKey  = @cStorerKey   
      ,  @c_sku        = ''    
      ,  @c_ConfigKey  = 'TPS-GetKeyPadInput'    
      ,  @b_Success    = @b_Success       OUTPUT    
      ,  @c_authority  = @cGetKeyPadInputSP OUTPUT    
      ,  @n_err        = @n_Err           OUTPUT    
      ,  @c_errmsg     = @c_ErrMsg        OUTPUT  
    
       IF NOT EXISTS (SELECT TOP 1 1  
                  FROM dbo.storerConfig WITH (NOLOCK) 
                  WHERE storerKey = @cStorerKey 
                     AND configKey = 'TPS-GetKeyPadInput'
                     AND ISNULL(SVALUE,'') <> ''
                     AND (Facility = @cFacility OR Facility = '') ) 
   BEGIN
      SET @cGetKeyPadInputSP ='1'
   END


   SELECT @cAutoScanInWhenPack = sValue FROM dbo.StorerConfig WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND configKey ='AutoScanInWhenPack' --(cc04)    
   SELECT @cAutoScanOutWhenPack = sValue, @cAutoScanOutOp1 = option1 FROM dbo.StorerConfig WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND configKey ='AutoScanOutWhenPack' --(cc05)    
   IF @cAutoScanOutOp1 = ''    
      SET @cAutoScanOutOp1 = '0'    
   SELECT @cCheckPickB4Pack = sValue FROM dbo.StorerConfig WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND configKey ='CheckPickB4Pack' --(cc05)    
   SELECT @cOrderStatus = STATUS FROM Orders WITH (NOLOCK) WHERE storerKey = @cStorerKey AND orderKey = @cOrderKey --(cc05)    
   SELECT @cPickingPickslipNo = pickslipNo FROM pickingInfo WITH (NOLOCK) WHERE pickslipNo = @cPickSlipNo    
   SELECT @cPackQtyIndicatorFlag = sValue FROM dbo.StorerConfig WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND configKey = 'TPS-PackQtyIndicator'  --(cc14)    
   SELECT @cSkipPckCfmBtn = sValue FROM dbo.StorerConfig WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND configKey = 'TPS-SkipPckCfmBtn'  --(yeekung87)    
  
    
   IF EXISTS (SELECT TOP 1 1  FROM dbo.storerConfig WITH (NOLOCK) WHERE storerKey = @cStorerKey AND configKey = 'TPS-captureWeight' AND (sValue LIKE '%w%' or sValue LIKE'%c%'))    
   BEGIN    
      SET @skipCartonize = '0'    
   END    
   ELSE    
   BEGIN    
      SELECT @skipCartonize = sValue, @cSkipCartonSP = OPTION1 FROM dbo.StorerConfig WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND configKey = 'TPS-skipCartonize'    
      SELECT 'TPS-skipCartonize',@cSkipCartonSP,@cStorerKey    
      --(cc09)    
      DECLARE @cskipCtnSQL NVARCHAR(MAX)    
      DECLARE @cskipCtnParam NVARCHAR(MAX)    
      IF @cSkipCartonSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSkipCartonSP AND type = 'P')    
         BEGIN    
            SET @cskipCtnSQL = 'EXEC API.' + RTRIM( @cSkipCartonSP) + ' @cStorerKey, @cFacility, @nFunc, @cLangCode, @cPickSlipNo, @cDropID, @cOrderKey ' +    
               ',@skipCartonize  OUTPUT ' +    
               ',@b_Success      OUTPUT ' +    
               ',@n_Err          OUTPUT ' +    
               ',@c_ErrMsg       OUTPUT '    
            SET @cskipCtnParam = ' @cStorerKey NVARCHAR(15), @cFacility NVARCHAR(5), @nFunc INT, @cLangCode NVARCHAR(3), @cPickSlipNo NVARCHAR(20), @cDropID NVARCHAR(20), @cOrderKey NVARCHAR(10)' +    
               ',@skipCartonize   NVARCHAR( 1)  OUTPUT' +    
               ',@b_Success       INT           OUTPUT' +    
               ',@n_Err           INT           OUTPUT' +    
               ',@c_ErrMsg        NVARCHAR( 20) OUTPUT'    
            EXEC sp_ExecuteSQL @cskipCtnSQL, @cskipCtnParam, @cStorerKey, @cFacility, @nFunc, @cLangCode, @cPickSlipNo, @cDropID, @cOrderKey    
               ,@skipCartonize OUTPUT    
               ,@b_Success    OUTPUT    
               ,@n_Err        OUTPUT    
               ,@c_ErrMsg     OUTPUT    
     
            IF @b_Success = 0    
            BEGIN    
               SET @n_Err = @n_Err    
               SET @c_ErrMsg = @c_ErrMsg    
               GOTO EXIT_SP    
            END    
         END    
      END    
   END    
  
   IF ISNULL(@cGetKeyPadInputSP ,'') <> ''  
   BEGIN  
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetKeyPadInputSP AND type = 'P')    
      BEGIN    
         DECLARE @cGetKeyPadSQL NVARCHAR(MAX)    
         DECLARE @cGetKeyPadParam NVARCHAR(MAX)    
  
         SET @cGetKeyPadSQL = 'EXEC API.' + RTRIM( @cGetKeyPadInputSP) + ' @cStorerKey, @cFacility, @nFunc, @cLangCode, @cPickSlipNo, @cDropID, @cOrderKey ' +    
            ',@cGetKeyPadInput OUTPUT ' +    
            ',@b_Success      OUTPUT ' +    
            ',@n_Err          OUTPUT ' +    
            ',@c_ErrMsg       OUTPUT '    
         SET @cGetKeyPadParam = ' @cStorerKey NVARCHAR(15), @cFacility NVARCHAR(5), @nFunc INT, @cLangCode NVARCHAR(3), @cPickSlipNo NVARCHAR(20), @cDropID NVARCHAR(20), @cOrderKey NVARCHAR(10)' +    
            ',@cGetKeyPadInput   NVARCHAR( 1)  OUTPUT' +    
            ',@b_Success       INT           OUTPUT' +    
            ',@n_Err           INT           OUTPUT' +    
            ',@c_ErrMsg        NVARCHAR( 20) OUTPUT'    
         EXEC sp_ExecuteSQL @cGetKeyPadSQL, @cGetKeyPadParam, @cStorerKey, @cFacility, @nFunc, @cLangCode, @cPickSlipNo, @cDropID, @cOrderKey    
            ,@cGetKeyPadInput OUTPUT    
            ,@b_Success    OUTPUT    
            ,@n_Err        OUTPUT    
            ,@c_ErrMsg     OUTPUT    
  
         IF @b_Success = 0    
         BEGIN    
            SET @n_Err = @n_Err    
            SET @c_ErrMsg = @c_ErrMsg    
            GOTO EXIT_SP    
         END    
      END    
      ELSE   
      BEGIN  
         SET @cGetKeyPadInput = @cGetKeyPadInputSP  
      END  
   END  
    
   --(cc04)    
   IF (@cPickingPickslipNo = '' OR @cPickingPickslipNo IS NULL)    
   BEGIN    
      IF @cAutoScanInWhenPack <> '1'    
      BEGIN    
         SET @n_Err = 1000852    
         SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Packing Cannot Be Done Without Scanning In Pickslips: isp_GetToPackDetail'    
         GOTO EXIT_SP    
      END    
   END    
    
   --(cc05)    
   If @cCheckPickB4Pack = '1'    
   BEGIN    
      IF EXISTS (SELECT 1 FROM pickingInfo WITH (NOLOCK) WHERE pickslipNo = @cPickSlipNo AND (ScanOUtDate IS NULL OR YEAR(scanOutDate) IN ('1900')))    
      BEGIN    
         IF @cAutoScanOutWhenPack = '1' AND @cOrderStatus> @cAutoScanOutOp1    
         BEGIN    
            IF NOT EXISTS (SELECT 1 FROM pickingInfo WITH (NOLOCK) WHERE pickslipNo = @cPickSlipNo)    
            BEGIN    
               INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID )    
               VALUES  (@cPickSlipNo, GETDATE(), SUSER_SNAME() )    
     
               IF @@ERROR <> 0    
               BEGIN    
                  SET @n_Err = 1000853    
                  SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Insert PickingInfo fail: isp_GetToPackDetail'    
                  GOTO EXIT_SP    
               END    
            END    
     
            UPDATE PickingInfo WITH (ROWLOCK)    
            SET ScanInDate = GETDATE(),    
            PickerID = SUSER_SNAME()    
            WHERE Pickslipno = @cPickSlipNo    
     
            IF @@ERROR <> 0    
            BEGIN    
               SET @n_Err = 1000854    
               SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Update PickingInfo fail: isp_GetToPackDetail'    
               GOTO EXIT_SP    
            END    
         END    
      END    
   END    
    
   --(cc06)--(cc10)    
   IF NOT EXISTS (SELECT 1  
                  FROM Storerconfig (NOLOCK)  
                  WHERE Storerkey = @cStorerKey  
                     AND Configkey = 'TPS-DisplayCol')  
   BEGIN  
      SET @cDisplayDesc ='Country Name'  
  
      SELECT @cDisplayvalueCol = UPPER(c.Long)    
      FROM orders o WITH (NOLOCK)    
      JOIN codelkup c WITH (NOLOCK) ON (c.code = O.C_ISOCntryCode)    
      WHERE o.orderKey = @cOrderKey    
      AND o.StorerKey = @cStorerKey    
      AND c.listName = 'ISOCOUNTRY'   
   END  
   ELSE  
   BEGIN  
      DECLARE @cColumnName NVARCHAR(30)  
      SELECT @cColumnName = Svalue,  
            @cDisplayDesc = ConfigDesc  
      FROM Storerconfig (NOLOCK)  
      WHERE Storerkey = @cStorerKey  
         AND Configkey = 'TPS-DisplayCol'  
  
      IF EXISTS(SELECT   1  
               FROM INFORMATION_SCHEMA.COLUMNS  
               WHERE TABLE_NAME = 'Orders'  
               AND COLUMN_NAME = @cColumnName)  
      BEGIN  
  
         SET @cSQL    = ' SELECT @cDisplayvalueCol = ' + @cColumnName +  
                              ' FROM dbo.Orders O (NOLOCK)  
                              WHERE (O.orderKey = @cOrderKey OR O.Loadkey = @cLoadkey)  
                                 AND O.StorerKey = @cStorerKey'  
     
         SET @cSQLParams =  
         ' @cOrderKey NVARCHAR(20),' +  
         ' @cLoadkey  NVARCHAR(20),' +  
         ' @cStorerKey NVARCHAR(20),' +  
         ' @cDisplayvalueCol NVARCHAR(20) OUTPUT'  
  
  
         EXEC sp_executesql @cSQL,@cSQLParams,@cOrderKey,@cLoadkey,@cStorerKey,@cDisplayvalueCol OUTPUT  
      END  
      ELSE  
      BEGIN  
         SET @n_Err = 1000855    
         SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Error Column name From Order table: isp_GetToPackDetail'   
         GOTO EXIT_SP    
      END  
   END  
     
   --get workInstruction (cc06)    
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
            GOTO EXIT_SP    
         END    
      END    
   END    
    
   --(cc07)    
   IF @cScanNoType = 'Ecom_multi'    
   BEGIN    
      SET @cIndicator = 'E-Comm Multi'    
   END    
   ELSE IF @cScanNoType = 'Ecom_single'    
   BEGIN    
      SET @cIndicator = 'E-Comm Single'    
   END    
   ELSE IF @cScanNoType NOT like 'Ecom%'    
   BEGIN    
      IF @cType = 'ToteID'    
      BEGIN    
         SET @cIndicator = 'B2B Tote ID'    
      END    
      ELSE    
      BEGIN    
         SET @cIndicator = 'B2B Pickslip'    
      END    
   END    
    
   --check cartonType setup    
   IF (@skipCartonize = '0' OR isNull(@skipCartonize,'') = '')    
   BEGIN    
      IF NOT EXISTS (SELECT TOP 1 1 FROM STORER S WITH (NOLOCK)    
         JOIN CARTONIZATION C WITH (NOLOCK) ON (S.cartonGroup=C.CartonizationGroup)  WHERE S.StorerKey = @cStorerKey)    
      BEGIN    
         SET @n_Err = 1000856    
         SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Please setup Cartonization in SCE/WMS to proceed. Function : isp_GetToPackDetail'    
         GOTO EXIT_SP    
      END    
   END    
  
   --check storerConfig to hide Packed sku    
   IF EXISTS (SELECT TOP 1 1  FROM dbo.storerConfig WITH (NOLOCK) WHERE storerKey = @cStorerKey AND configKey = 'TPS-HidePackedSku' AND sValue ='1')    
   BEGIN    
      SET @hidePackedSku = '1'    
   END    
    
   --set Dynamic Column    
   DECLARE @cSQLDynamicSelect NVARCHAR ( MAX)    
   DECLARE @cSQLGropBy        NVARCHAR ( MAX)    
     
   SELECT TOP 1    
      @cDynamicTb1 = rdt.rdtGetParsedString( OPTION1, 1, '.'),    
      @cDynamicTb2 = rdt.rdtGetParsedString( OPTION2, 1, '.'),    
      @cDynamicCol1 = rdt.rdtGetParsedString( OPTION1, 2, '.'),    
      @cDynamicCol2 = rdt.rdtGetParsedString( OPTION2, 2, '.')    
   FROM StorerConfig (NOLOCK)    
   WHERE storerKey = @cStorerKey    
   AND configKey ='TPS-dynamicPackDetail'    
    
   --SELECT @cDynamicTb1 AS cDynamicTb1,@cDynamicTb2 AS cDynamicTb2    
     
   IF @@ROWCOUNT > 0    
   BEGIN    
    
      IF ISNULL(@cDynamicTb1,'') = '' AND ISNULL(@cDynamicTb2,'') = ''    
      BEGIN    
         SET @cSQLDynamicSelect = ','''' AS DynamicColName1,'''' AS DynamicColValue1,'''' AS DynamicColName2,'''' AS DynamicColValue2 '    
         SET @cSQLGropBy = ''    
      END    
    
      IF ISNULL(@cDynamicTb1,'') = '' AND ISNULL(@cDynamicTb2,'') <> ''    
      BEGIN    
         SET @cSQLDynamicSelect = '    
            ,'''' ,'''+@cDynamicCol2+''' AS DynamicColName2    
            ,''''    
            ,' +@cDynamicTb2+ '.' + @cDynamicCol2 + ' AS DynamicColValue2    
         '    
         SET @cSQLGropBy = '    
            ,' +@cDynamicTb2+ '.' + @cDynamicCol2 + '    
            '    
      END    
    
      IF ISNULL(@cDynamicTb1,'') <> '' AND ISNULL(@cDynamicTb2,'') = ''    
      BEGIN    
         SET @cSQLDynamicSelect = '    
            ,'''+@cDynamicCol1+''' AS DynamicColName1 ,''''    
            ,' +@cDynamicTb1+ '.' + @cDynamicCol1 + ' AS DynamicColValue1    
            ,''''    
            '    
     
         SET @cSQLGropBy = '    
            ,' +@cDynamicTb1+ '.' + @cDynamicCol1 + '    
            '    
      END    
    
      IF ISNULL(@cDynamicTb1,'') <> '' AND ISNULL(@cDynamicTb2,'') <> ''    
      BEGIN    
         SET @cSQLDynamicSelect = '    
            ,'''+@cDynamicCol1+''' AS DynamicColName1 ,'''+@cDynamicCol2+''' AS DynamicColName2    
            ,' +@cDynamicTb1+ '.' + @cDynamicCol1 + ' AS DynamicColValue1    
            ,' +@cDynamicTb2+ '.' + @cDynamicCol2 + ' AS DynamicColValue2    
            '    
     
         SET @cSQLGropBy = '    
            ,' +@cDynamicTb1+ '.' + @cDynamicCol1 + '    
            ,' +@cDynamicTb2+ '.' + @cDynamicCol2 + '    
            '    
      END    
   END    
   ELSE    
   BEGIN    
      IF ISNULL(@cDynamicTb1,'') = '' AND ISNULL(@cDynamicTb2,'') = ''    
      BEGIN    
         SET @cSQLDynamicSelect = ','''' AS DynamicColName1,'''' AS DynamicColValue1,'''' AS DynamicColName2,'''' AS DynamicColValue2 '    
         SET @cSQLGropBy = ''    
      END    
   END    
    
   DECLARE @cSQLDymWgtSelect NVARCHAR ( 150)    
   -- Dynamic SKU weight    
   IF EXISTS (SELECT TOP 1 1 FROM storerConfig WITH (NOLOCK) WHERE storerKey =@cStorerKey AND configKey = 'TPS-SKUWgt' AND OPTION1 <>'')    
   BEGIN    
      SELECT TOP 1    
         @cDymCtnWgtTb = rdt.rdtGetParsedString( OPTION1, 1, '.'),    
         @cDymCtnWgtCol = rdt.rdtGetParsedString( OPTION1, 2, '.')    
      FROM StorerConfig (NOLOCK)    
      WHERE storerKey = @cStorerKey    
      AND configKey ='TPS-SKUWgt'    
      AND OPTION1 <>''    
     
      IF (ISNULL(@cDymCtnWgtTb,'') NOT IN ('SKU')) OR (ISNULL(@cDymCtnWgtTb,'') = '')    
      BEGIN    
         SET @n_Err = 1000857    
         SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Incorrect dynamic SKU Weight column setup. Function : isp_GetToPackDetail'    
         GOTO EXIT_SP    
      END    
      ELSE    
      BEGIN    
         SET @cSQLDymWgtSelect = @cSQLDymWgtSelect+' ,'+@cDymCtnWgtTb+'.'+@cDymCtnWgtCol    
      END    
   END    
   ELSE    
   BEGIN    
      SET @cSQLDymWgtSelect = @cSQLDymWgtSelect + ', SKU.stdGrossWgt'    
   END    
    
   --Dynamic sku cube    
   IF EXISTS (SELECT TOP 1 1 FROM storerConfig WITH (NOLOCK) WHERE storerKey =@cStorerKey AND configKey = 'TPS-SKUCube' AND OPTION1 <>'')    
   BEGIN    
      SELECT TOP 1    
         @cDymCtnCubeTb = rdt.rdtGetParsedString( OPTION1, 1, '.'),    
         @cDymCtnCubeCol = rdt.rdtGetParsedString( OPTION1, 2, '.')    
      FROM StorerConfig (NOLOCK)    
      WHERE storerKey = @cStorerKey    
      AND configKey ='TPS-SKUCube'    
      AND OPTION1 <>''    
     
      IF (ISNULL(@cDymCtnCubeTb,'') NOT IN ('SKU')) OR (ISNULL(@cDymCtnCubeTb,'') = '')    
      BEGIN    
         SET @n_Err = 1000858    
         SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Incorrect dynamic SKU Cube column setup. Function : isp_GetToPackDetail'    
         GOTO EXIT_SP    
      END    
      ELSE    
      BEGIN    
         SET @cSQLDymWgtSelect = @cSQLDymWgtSelect+' ,'+@cDymCtnCubeTb+'.'+@cDymCtnCubeCol    
      END    
   END    
   ELSE    
   BEGIN    
      SET @cSQLDymWgtSelect = @cSQLDymWgtSelect + ', SKU.stdCube'    
   END    
    
   -- Dynamic Ecom Carton weight    
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
         SET @n_Err = 1000859    
         SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Incorrect dynamic E-Comm Carton Weight column setup. Function : isp_GetToPackDetail'    
         GOTO EXIT_SP    
      END    
      ELSE    
      BEGIN    
         SET @cSQLDymWgtSelect = @cSQLDymWgtSelect+' ,'+@cDymEcomCtnWgtTb+'.'+@cDymEcomCtnWgtCol    
      END    
   END    
   ELSE    
   BEGIN    
      SET @cSQLDymWgtSelect = @cSQLDymWgtSelect + ', SKU.Weight'    
   END    
    
   --Dynamic Carton cube    
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
         SET @n_Err = 1000860    
         SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Incorrect dynamic E-Comm Cube column setup. Function : isp_GetToPackDetail'    
         GOTO EXIT_SP    
      END    
      ELSE    
      BEGIN    
         SET @cSQLDymWgtSelect = @cSQLDymWgtSelect+' ,'+@cDymEcomCtnCubeTb+'.'+@cDymEcomCtnCubeCol    
      END    
   END    
   ELSE    
   BEGIN    
      SET @cSQLDymWgtSelect = @cSQLDymWgtSelect + ', SKU.Cube'    
   END   
  
  
   INSERT INTO #PackTable  
   SELECT PD.SKU,SUM(PD.QTY) AS QtyToPack,@cPickSlipNo   
   FROM packdetail PD WITH (NOLOCK)  
   WHERE PD.pickslipno=@cPickSlipNo  
   GROUP BY PD.SKU  
     
   --form packInfo output    
   DECLARE @cSQLCobine     NVARCHAR( MAX)    
   DECLARE @cSQLFrom       NVARCHAR( MAX)    
     
   --(sum(pick.QtyToPack)-isnull((SUM(PD.qty)),0)) AS QtyToPack    
   IF @EcomSingle = '1'    
   BEGIN    
      SET @cSQLMainSelect = '    
         SELECT    
         Trim(sku.SKU),SKU.descr,Trim(lower(SKU.RetailSKU)), Trim(LOWER(SKU.ManufacturerSKU)),Trim(LOWER(SKU.ALTSKU))    
         ,(SUM(pick.QtyToPack)-ISNULL(SUM(PH.QtyToPack),0)) AS QtyToPack,  
            ISNULL(SUM(PH.QtyToPack),0) AS PackedQty    
         , case when isnull(SKU.PackQtyIndicator,0) = 0 then 1 else isnull(SKU.PackQtyIndicator,0) end    
         ,'''' AS Img,SKU.EcomCartonType ' +    
         ', CASE WHEN SKU.SUSR4 = ''AD'' THEN ''1'' ELSE ''0'' END AS AD  --(cc12)--(cc13)   
         , SUM(Pack.otherunit2) '--(cc12)--(cc13)    
     
   END    
   ELSE    
   BEGIN    
      SET @cSQLMainSelect = '    
         SELECT    
         Trim(PICK.SKU),SKU.descr,Trim(LOWER(SKU.RetailSKU)), Trim(LOWER(SKU.ManufacturerSKU)),Trim(LOWER(SKU.ALTSKU))    
         ,(SUM(pick.QtyToPack)-ISNULL(SUM(PH.QtyToPack),0)) AS QtyToPack,  
            ISNULL(SUM(PH.QtyToPack),0)  AS PackedQty   
         ,case when isnull(SKU.PackQtyIndicator,0) = 0 then 1 else isnull(SKU.PackQtyIndicator,0) end    
         ,'''' AS Img,SKU.EcomCartonType ' +    
         ', CASE WHEN SKU.SUSR4 = ''AD''  THEN ''1'' ELSE ''0'' END AS AD   
         , SUM(Pack.otherunit2)'--(cc12)--(cc13)    
     
   END    
    
    
   SET @cSQLFrom =    
      '    
      FROM #pickSKUDetail pick    
      JOIN dbo.SKU sku WITH (NOLOCK) ON (sku.sku = pick.sku)   
      LEFT JOIN #PackTable PH WITH (NOLOCK) ON (pick.pickslipno=PH.pickslipno and PICK.sku=PH.SKU)  
      JOIN PACK PACK (NOLOCK) ON (SKU.packkey=PACK.packkey)  
      WHERE SKU.storerKey = ''' +@cStorerKey+ '''    
      GROUP BY PICK.SKU,SKU.descr,SKU.RetailSKU, SKU.ManufacturerSKU,SKU.ALTSKU,SKU.PackQtyIndicator,sku.WEIGHT,sku.[CUBE],    
      SKU.EcomCartonType,sku.StdGrossWgt,sku.StdCube,pick.QtyToPack ' +    
      ',SKU.SUSR4,pick.pickslipno '  --(cc12)    
     
     
   SET @cSQLCobine = @cSQLMainSelect+@cSQLDymWgtSelect+@cSQLDynamicSelect+@cSQLFrom+@cSQLGropBy    
   --LEFT JOIN dbo.packDetail PD WITH (NOLOCK) on (pick.pickslipNo = PD.pickslipNo and PD.storerKey = PD.storerKey)    
  
    
   INSERT INTO @packSKUDetail    
   EXEC (@cSQLCobine)    
  
   IF @@ERROR <> 0  
   BEGIN    
      SET @n_Err = 1000861    
      SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Execute Custom SQL Failed. Function : isp_GetToPackDetail'    
      GOTO EXIT_SP    
   END    
  
   DECLARE @nTTlQTYPack INT  
   DECLARE @nPackQty INT  
  
   SELECT @nTTlQTYPack = SUM(QtyToPack), @nPackQty = SUM(PackedQty) FROM @packSKUDetail  
   IF EXISTS (SELECT 1 FROM @packSKUDetail WHERE QtyToPack<0)    
   BEGIN    
      SET @n_Err = 1000862    
      SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'QTY Over Packed. Function : isp_GetToPackDetail'    
      GOTO EXIT_SP    
   END    
  
   --Check packheader status whether close or open  
   IF EXISTS (SELECT 1 FROM packHeader (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND storerkey=@cStorerKey)  
   BEGIN  
      SELECT @cStatus=Status  
      FROM packHeader (NOLOCK)   
      WHERE PickSlipNo = @cPickSlipNo   
         AND storerkey=@cStorerKey  
   END  
    
   DECLARE @cImageURL NVARCHAR(MAX)  
     
   DECLARE @SkuImg TABLE (    
      storerKey   NVARCHAR( 20),    
      SKU        NVARCHAR( 30),    
      ImageURL   NVARCHAR( 1024)    
   )    
    
   DECLARE @SkuImgURL NVARCHAR( 1024)    
   DECLARE @cSku NVARCHAR ( 30)    
     
   DECLARE curMsg CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
   select sku FROM @packSKUDetail    
    
   OPEN curMsg;    
   FETCH NEXT FROM curMsg INTO @cSku    
   WHILE @@FETCH_STATUS = 0    
      BEGIN    
  
         EXEC [API].[isp_Get_SKU_Image_UR]    
            --exec rdt.[Get_SKU_Image_URL_test]    
            --EXEC [MYWMS].[WM].[lsp_WM_Get_SKU_Image_URL]    
            @cstorerkey   
            , @cSku    
            , @cUserName    
            , @b_Success        OUTPUT    
            , @n_err            OUTPUT    
            , @c_ErrMsg         OUTPUT    
            , @cImageURL        OUTPUT  
  
         --default Img, cause sp still point to MYWMS    
         INSERT INTO @SkuImg  (storerKey,SKU,ImageURL)  
         values(@cstorerkey,@cSku,@cImageURL)  
         --EXEC [MYWMS].[WM].[lsp_WM_Get_SKU_Image_URL]    
         -- @c_Storerkey = 'NIKEMY'    
         --,@c_SKU = @cSku    
         --, @c_UserName = @cUserName    
         --,@c_ReturnType ='PARAM'    
         --,@c_ReturnURL = @SkuImgURL OUTPUT    
  
         --INSERT INTO @SkuImg    
         --VALUES(@cSku,@SkuImgURL)    
     
      FETCH NEXT FROM curMsg INTO @cSku    
      END    
   CLOSE curMsg    
   DEALLOCATE curMsg    
     
   UPDATE @packSKUDetail    
   SET Img = ISNULL(s.ImageURL,'')    
   FROM @packSKUDetail p    
   JOIN  @SkuImg s ON p.sku = s.sku    
    
   --(cc08)    
   --get lottable    
   DECLARE @LottableDropList TABLE (    
      SKU         NVARCHAR( 30),    
      lottable    NVARCHAR( 30),    
      Description NVARCHAR( 250)    
   )    
     
   DECLARE    
      @cLotSQL          NVARCHAR( MAX),    
      @cSQLStatement    NVARCHAR( MAX),    
      @cLottableLabel   NVARCHAR( 20),    
      @cLotSku      NVARCHAR( 20),    
      @cLotOrderKey     NVARCHAR( 30),    
      @cLotPickslipNo   NVARCHAR( 30),    
      @cLotLoadKey      NVARCHAR( 30),    
      @cLotWaveKey      NVARCHAR( 30)    
      --@cLotCode         NVARCHAR( 30),    
      --@cLotDesc         NVARCHAR( 250)    
    
   DECLARE curLot CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
   select sku,OrderKey,PickslipNo,LoadKey FROM #pickSKUDetail    
  
   IF @cPackByLottable = '1'    
   BEGIN    
      OPEN curLot;    
      FETCH NEXT FROM curLot INTO @cLotSku,@cLotOrderKey,@cLotPickslipNo,@cLotLoadKey    
      WHILE @@FETCH_STATUS = 0    
      BEGIN    
         IF @cLotDropDownBy = 'DROPDOWNBYCODELKUP'    
         BEGIN    
            SET @cLotSQL = N' SELECT @cLottableLabel = Lottable' + @cLottableNum  + 'Label ' +    
                                 ' FROM SKU (NOLOCK)    
                                    WHERE Storerkey = @cStorerkey    
                                    AND Sku = @cLotSku '    
     
            EXEC sp_executesql @cLotSQL,    
                  N'@cLottableLabel NVARCHAR(20) OUTPUT, @cStorerkey NVARCHAR(15), @cSku NVARCHAR(20)',    
                  @cLottableLabel OUTPUT,    
                  @cStorerkey,    
                  @cLotSku    
     
            SELECT TOP 1 @cSQLStatement = NOTES    
            FROM CODELKUP(NOLOCK)    
            WHERE ListName = 'LOT' + @cLottableNum + 'List'    
               AND Storerkey = @cStorerkey    
               AND UDF01 = @cLottableLabel    
               AND ISNULL(UDF01,'') <> ''    
               AND Short = 'SQL'    
     
            IF ISNULL(@cSQLStatement,'') <> ''    
            BEGIN    
               EXEC sp_executesql @cSQLStatement,    
                  N'@cStorerkey NVARCHAR(15), @cLotSku NVARCHAR(20)',    
                  @cStorerkey,    
                  @cLotSku    
     
               SELECT @n_err = @@ERROR    
               IF @n_err <> 0    
               BEGIN    
                  SET @n_Err = 1000863    
                  SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Execute Custom SQL Failed. Function : isp_GetToPackDetail'    
                  GOTO EXIT_SP    
               END    
            END    
            ELSE    
            BEGIN    
               INSERT INTO @LottableDropList    
               SELECT @cLotSku,Code, Description    
               FROM CODELKUP(NOLOCK)    
               WHERE ListName = 'LOT' + @cLottableNum + 'List'    
                  AND Storerkey = @cStorerkey    
                  AND UDF01 = @cLottableLabel    
                  AND ISNULL(UDF01,'') <> ''    
               ORDER BY 1    
            END    
         END    
         ELSE IF @cLotDropDownBy = 'DROPDOWNBYPICKSLIP'    
         BEGIN    
            IF ISNULL(@cLotOrderKey,'') <> ''    
            BEGIN    
               INSERT INTO @LottableDropList    
               SELECT DISTINCT   @cLotSku,    
                     CASE WHEN @cLottableNum = '01' THEN LA.Lottable01    
                           WHEN @cLottableNum = '02' THEN LA.Lottable02    
                           WHEN @cLottableNum = '03' THEN LA.Lottable03    
                           WHEN @cLottableNum = '04' THEN CONVERT(NVARCHAR,LA.Lottable04,121)    
                           WHEN @cLottableNum = '05' THEN CONVERT(NVARCHAR,LA.Lottable05,121)    
                           WHEN @cLottableNum = '06' THEN LA.Lottable06    
                           WHEN @cLottableNum = '07' THEN LA.Lottable07    
                           WHEN @cLottableNum = '08' THEN LA.Lottable08    
                           WHEN @cLottableNum = '09' THEN LA.Lottable09    
                           WHEN @cLottableNum = '10' THEN LA.Lottable10    
                           WHEN @cLottableNum = '11' THEN LA.Lottable11    
                           WHEN @cLottableNum = '12' THEN LA.Lottable12    
                           WHEN @cLottableNum = '13' THEN CONVERT(NVARCHAR,LA.Lottable13,121)    
                           WHEN @cLottableNum = '14' THEN CONVERT(NVARCHAR,LA.Lottable14,121)    
                           WHEN @cLottableNum = '15' THEN CONVERT(NVARCHAR,LA.Lottable15,121)    
                     END AS lottable,    
                     '' AS Description    
               FROM PICKDETAIL PD (NOLOCK)    
               JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot    
               WHERE PD.Orderkey = @cLotOrderKey    
               AND PD.Sku = @cLotSku    
            END    
            ELSE IF ISNULL(@cLotLoadKey,'') <> ''    
            BEGIN    
               INSERT INTO @LottableDropList    
               SELECT DISTINCT  @cLotSku,    
                     CASE WHEN @cLottableNum = '01' THEN LA.Lottable01    
                           WHEN @cLottableNum = '02' THEN LA.Lottable02    
                           WHEN @cLottableNum = '03' THEN LA.Lottable03    
                           WHEN @cLottableNum = '04' THEN CONVERT(NVARCHAR,LA.Lottable04,121)    
                           WHEN @cLottableNum = '05' THEN CONVERT(NVARCHAR,LA.Lottable05,121)    
                           WHEN @cLottableNum = '06' THEN LA.Lottable06    
                           WHEN @cLottableNum = '07' THEN LA.Lottable07    
                           WHEN @cLottableNum = '08' THEN LA.Lottable08    
                           WHEN @cLottableNum = '09' THEN LA.Lottable09    
                           WHEN @cLottableNum = '10' THEN LA.Lottable10    
                           WHEN @cLottableNum = '11' THEN LA.Lottable11    
                           WHEN @cLottableNum = '12' THEN LA.Lottable12    
                           WHEN @cLottableNum = '13' THEN CONVERT(NVARCHAR,LA.Lottable13,121)    
                           WHEN @cLottableNum = '14' THEN CONVERT(NVARCHAR,LA.Lottable14,121)    
                           WHEN @cLottableNum = '15' THEN CONVERT(NVARCHAR,LA.Lottable15,121)    
                     END AS lottable,    
                     '' AS Description    
               FROM LOADPLANDETAIL LPD (NOLOCK)    
               JOIN PICKDETAIL PD (NOLOCK) ON LPD.Orderkey = PD.Orderkey    
               JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot    
               WHERE LPD.Loadkey = @cLotLoadKey    
               AND PD.Sku = @cLotSku    
            END    
            ELSE    
            BEGIN    
               INSERT INTO @LottableDropList    
               SELECT @cLotSku, Code, Description    
               FROM CODELKUP(NOLOCK)    
               WHERE 1=2    
            END    
         END    
         ELSE IF @cLotDropDownBy = 'DROPDOWNBYLOAD'    
         BEGIN    
            IF ISNULL(@cLotLoadKey,'') <> ''    
            BEGIN    
               INSERT INTO @LottableDropList    
               SELECT DISTINCT @cLotSku,    
                     CASE WHEN @cLottableNum = '01' THEN LA.Lottable01    
                           WHEN @cLottableNum = '02' THEN LA.Lottable02    
                           WHEN @cLottableNum = '03' THEN LA.Lottable03    
                           WHEN @cLottableNum = '04' THEN CONVERT(NVARCHAR,LA.Lottable04,121)    
                           WHEN @cLottableNum = '05' THEN CONVERT(NVARCHAR,LA.Lottable05,121)    
                           WHEN @cLottableNum = '06' THEN LA.Lottable06    
                           WHEN @cLottableNum = '07' THEN LA.Lottable07    
                           WHEN @cLottableNum = '08' THEN LA.Lottable08    
                           WHEN @cLottableNum = '09' THEN LA.Lottable09    
                           WHEN @cLottableNum = '10' THEN LA.Lottable10    
                           WHEN @cLottableNum = '11' THEN LA.Lottable11    
                           WHEN @cLottableNum = '12' THEN LA.Lottable12    
                           WHEN @cLottableNum = '13' THEN CONVERT(NVARCHAR,LA.Lottable13,121)    
                           WHEN @cLottableNum = '14' THEN CONVERT(NVARCHAR,LA.Lottable14,121)    
                           WHEN @cLottableNum = '15' THEN CONVERT(NVARCHAR,LA.Lottable15,121)    
                     END AS lottable,    
                     '' AS Description    
               FROM LOADPLANDETAIL LPD (NOLOCK)    
               JOIN PICKDETAIL PD (NOLOCK) ON LPD.Orderkey = PD.Orderkey    
               JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot    
               WHERE LPD.Loadkey = @cLotLoadKey    
               AND PD.Sku = @cLotSku    
            END    
            ELSE    
            BEGIN    
               INSERT INTO @LottableDropList    
               SELECT @cLotSku,Code, Description    
               FROM CODELKUP(NOLOCK)    
               WHERE 1=2    
            END    
        END    
         ELSE IF @cLotDropDownBy = 'DROPDOWNBYWAVE'    
         BEGIN    
            SELECT TOP 1 @cLotWaveKey = WD.Wavekey    
            FROM PICKHEADER PH (NOLOCK)    
            JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey    
            JOIN WAVEDETAIL WD (NOLOCK) ON O.Orderkey = WD.Orderkey    
            WHERE PH.Pickheaderkey = @cLotPickslipNo    
     
            IF ISNULL(@cLotWaveKey,'') = ''    
            BEGIN    
               SELECT TOP 1 @cLotWaveKey = WD.Wavekey    
               FROM PICKHEADER PH (NOLOCK)    
               JOIN LOADPLANDETAIL LPD (NOLOCK) ON PH.Externorderkey = LPD.Loadkey    
               JOIN WAVEDETAIL WD (NOLOCK) ON LPD.Orderkey = WD.Orderkey    
               WHERE PH.Pickheaderkey = @cLotPickslipNo    
               AND ISNULL(PH.Orderkey,'') = ''    
            END    
     
            IF ISNULL(@cLotWaveKey,'') <> ''    
            BEGIN    
               INSERT INTO @LottableDropList    
               SELECT DISTINCT @cLotSku,    
                  CASE WHEN @cLottableNum = '01' THEN LA.Lottable01    
                        WHEN @cLottableNum = '02' THEN LA.Lottable02    
                        WHEN @cLottableNum = '03' THEN LA.Lottable03    
                        WHEN @cLottableNum = '04' THEN CONVERT(NVARCHAR,LA.Lottable04,121)    
                        WHEN @cLottableNum = '05' THEN CONVERT(NVARCHAR,LA.Lottable05,121)    
                        WHEN @cLottableNum = '06' THEN LA.Lottable06    
                        WHEN @cLottableNum = '07' THEN LA.Lottable07    
                        WHEN @cLottableNum = '08' THEN LA.Lottable08    
                        WHEN @cLottableNum = '09' THEN LA.Lottable09    
                        WHEN @cLottableNum = '10' THEN LA.Lottable10    
                        WHEN @cLottableNum = '11' THEN LA.Lottable11    
                        WHEN @cLottableNum = '12' THEN LA.Lottable12    
                        WHEN @cLottableNum = '13' THEN CONVERT(NVARCHAR,LA.Lottable13,121)    
                        WHEN @cLottableNum = '14' THEN CONVERT(NVARCHAR,LA.Lottable14,121)    
                        WHEN @cLottableNum = '15' THEN CONVERT(NVARCHAR,LA.Lottable15,121)    
                  END AS lottable,    
                        '' AS Description    
               FROM WAVEDETAIL WD (NOLOCK)    
               JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey    
               JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot    
               WHERE WD.Wavekey = @cLotWaveKey    
               AND PD.Sku = @cLotSku    
            END    
            ELSE    
            BEGIN    
               INSERT INTO @LottableDropList    
               SELECT @cLotSku,Code, Description    
               FROM CODELKUP(NOLOCK)    
               WHERE 1=2    
            END    
         END    
         ELSE    
         BEGIN    
            INSERT INTO @LottableDropList    
            SELECT @cLotSku,Code, Description    
            FROM CODELKUP(NOLOCK)    
            WHERE 1=2    
         END    
     
     
         FETCH NEXT FROM curLot INTO @cLotSku,@cLotOrderKey,@cLotPickslipNo,@cLotLoadKey    
         END    
      CLOSE curLot    
      DEALLOCATE curLot    
   END    
   DECLARE @nMAXCtnNo INT  
   DECLARE @nPackedCtnQTY INT  
   DECLARE @cShowColumn NVARCHAR(20)  
  
   IF  EXISTS (SELECT 1  
               FROM   packdetail (nolock) PD  
               WHERE    PD.pickslipno = @cPickSlipNo  
                  AND PD.Storerkey = @cStorerkey)   
   BEGIN  
      IF NOT EXISTS (SELECT 1  
                     FROM   packdetail (nolock) PD  
                     WHERE    PD.pickslipno = @cPickSlipNo  
                        AND PD.Storerkey = @cStorerkey  
                        AND PD.CartonNo = 1 )  
      BEGIN  
         SET @nMAXCtnNo = 1  
      END  
      ELSE  
      BEGIN  
  
         SELECT  TOP 1 @nMAXCtnNo = PDS.CartonNo + 1  --(yeekung13)  
         FROM   packdetail (nolock) PDS  
         WHERE  PDS.pickslipno = @cPickSlipNo --(yeekung16)  
            AND PDS.Storerkey = @cStorerkey   
            AND NOT EXISTS  
               (  
               SELECT  1  
               FROM    packdetail (nolock) pd   
               WHERE PD.pickslipno = @cPickSlipNo  
                  AND PD.Storerkey = @cStorerkey   
                  AND PD.CartonNo = PDS.CartonNo + 1  
               )  
         ORDER BY PDS.CartonNo  
      END  
   END  
   ELSE  
   BEGIN  
      SET @nMAXCtnNo = 1  
   END  
  
   SELECT  @nPackedCtnQTY = COUNT(DISTINCT PD.Cartonno)  
   FROM   packdetail (nolock) PD  
   WHERE    PD.pickslipno = @cPickSlipNo  
      AND PD.Storerkey = @cStorerkey   
  
  
   SET @nMAXCtnNo = CASE WHEN ISNULL(@nMAXCtnNo,'0') = 0 THEN 0 ELSE @nMAXCtnNo END  
     
   SET @nPackedCtnQTY = CASE WHEN ISNULL(@nPackedCtnQTY,'0') = 0 THEN 0 ELSE @nPackedCtnQTY END  
  
   SET @cTimeZone = FORMAT(DATEADD(MINUTE, DATEPART(TZOFFSET, SYSDATETIMEOFFSET()), 0), 'UTC+HH:mm')  
     
   --output Json format    
   SET @b_Success = 1    
   ----SET @jResult = (SELECT * FROM @packSKUDetail FOR JSON AUTO, INCLUDE_NULL_VALUES)    
     
   SET @jResult = (  
   SELECT @nMAXCtnNo AS MaxCartonNo,@nPackedCtnQTY AS PackedCtnQTY, (SELECT COUNT(CartonStatus)AS HoldStatus from packInfo WITH (NOLOCK) WHERE pickslipno=@cPickSlipNo AND cartonStatus = 'Hold') AS HoldStatus ,    
   @cDynamicRightName1 AS DynamicRightName1,@cDynamicRightValue1 AS DynamicRightValue1,@skipCartonize AS skipCartonize,@navCtnScn AS navCtnScn    
   ,@hidePackedSku AS hidePackedSku,@EcomSingle AS EcomSingle, @cPrintAfterPack AS PrintAfterPack, @cDefaultCartonType AS DefaultCartonType    
   ,@cOrderKey AS OrderKey  
   --, @cCtryCode AS CtryCode  
   ,@cDisplayDesc AS DisplayDescription  
   ,@cDisplayvalueCol AS DisplayValue  
   , @cPickSlipNo AS PickslipNo, @cDropID AS DropID, @cWorkInstruction AS WorkInstruction--(cc06)    
   ,@cIndicator AS Indicator--(cc07)    
   ,@cDecodeSP AS DecodeSP,@cADBarcode AS ADBarcode --(cc12)   
   ,@cGetUCC AS GetUCC --(yeekung01)  
   ,@cConfirmADScn AS ConfirmADScn  
   ,@cPackQtyIndicatorFlag AS PackQtyIndicatorFlag --(cc14)    
   ,@cLoadkey AS Loadkey --(yeekung06)  
   ,@cGetKeyPadInput AS GetKeyPadInput --(yeekung07)  
   ,@cSkipPckCfmBtn  AS SkipPackCfmBtn --(yeekung08)  
   ,@cTimeZone       AS TimeZone  
   ,@cGetReprintOpt  AS GetReprintOpt    
   ,CASE WHEN ISNULL(@cAutoDefaultLot,'') <> '' THEN '1' ELSE '0' END AS lottableEnable --(cc08)    
   ,(SELECT Option1 AS Option1_title,Option2 AS Option2_mandatory    
   ,Option3 AS Option3_sp, Option4 AS Option4, Option5 AS Option5_regexp    
      FROM dbo.storerConfig WITH (NOLOCK)    
      WHERE StorerKey = @cStorerKey    
         AND configKey = 'PackCaptureNewLabelno'    
         AND svalue = '1'   
      FOR JSON AUTO) AS PackCaptureNewLabelno, -- (cc01)    
   (SELECT p.*,ISNULL((SELECT RTRIM(U.upc) AS upc  FROM UPC U WITH (NOLOCK) JOIN  #pickSKUDetail PSKU WITH (NOLOCK) ON PSKU.SKU =U.SKU  WHERE PSKU.PickSlipNo = @cPickSlipNo  AND PSKU.SKU = P.SKU AND U.StorerKey = @cStorerKey FOR JSON PATH), '[]') AS UPC 
   
   , ISNULL((SELECT L.lottable FROM @LottableDropList L WHERE P.SKU = L.SKU FOR JSON PATH), '[]') AS Lottable  , @cStatus AS status  
   FROM @packSKUDetail p    
   FOR JSON AUTO, INCLUDE_NULL_VALUES ) AS Details,    
   (@nTTlQTYPack+@nPackQty) AS TTLQTYPack,  
   @nPackQty AS PackedQTY  
   --LEFT JOIN PackDetail PD WITH (NOLOCK) ON (PSKU.pickslipno = PD.pickslipNo)    
   --AND StorerKey = @cStorerKey    
   FOR JSON PATH, INCLUDE_NULL_VALUES)     
     
   DROP TABLE #pickSKUDetail    
     
   EXIT_SP:    
      REVERT   
END   

GO