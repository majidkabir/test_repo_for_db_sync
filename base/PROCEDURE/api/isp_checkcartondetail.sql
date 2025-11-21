SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: isp_CheckCartonDetail                                     */  
/* Copyright      : LFLogistics                                               */  
/*                                                                            */  
/* Date         Rev  Author     Purposes                                      */  
/* 2020-03-27   1.0  Chermaine  Created                                       */ 
/* 2020-10-28   1.1  Chermaine  TPS-533 change @cInputCube to nvarchar(10) (cc01)*/
/* 2021-09-05   1.2  Chermaine  TPS-11 ErrMsg add to rdtmsg (cc02)            */
/* 2022-05-18   1.3  YeeKung    TPS-585 extended weight and cube length (yeekung01)*/  
/* 2024-01-30   1.4  Yeekung    TPS-879 Fix innerjoin (yeekung03)             */
/* 2025-02-14   1.5  yeekung    TPS-995 Follow Error Message (yeekung04)      */
/* 2025-02-18   1.6  YeeKung    TPS-1013 Add new path (yeekung05)             */
/* 2025-02-20   1.7  GhChan     TPS-1013, UWP29093 Enhance UPC,Lottable       */
/*                               , BarcodeObj (Gh01)                          */
/******************************************************************************/  
  
CREATE   PROC [API].[isp_CheckCartonDetail] (  
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
   @cScanNoType   NVARCHAR( 30),
   @cPickSlipNo   NVARCHAR( 30),
   @cDropID       NVARCHAR( 30),    
   @cCartonNo     NVARCHAR( 3),
     
   @cOrderKey     NVARCHAR( 10),  
   @cOrderKeyCheck   NVARCHAR( 10),
   @cLoadKey      NVARCHAR( 10),  
   @cZone         NVARCHAR( 18),  
   @cLot          NVARCHAR( 30),
   @cStatus       NVARCHAR( 2),
     
   @nTotalPick    INT,   
   @nTotalShort   INT,  
   @EcomSingle    NVARCHAR( 1),
   @CalOrderSKU    NVARCHAR( 1),
     
  
   @cDynamicTb1   NVARCHAR( 30),
   @cDynamicTb2   NVARCHAR( 30),
   @cDynamicCol1  NVARCHAR( 30),
   @cDynamicCol2  NVARCHAR( 30),
   
   @cDynamicRightName1  NVARCHAR( 30),
   @cDynamicRightValue1  NVARCHAR( 30),
   @cDymEcomCtnWgtTb    NVARCHAR( 20),
   @cDymEcomCtnWgtCol   NVARCHAR( 20),
   @cDymEcomCtnCubeTb   NVARCHAR( 20),
   @cDymEcomCtnCubeCol  NVARCHAR( 20),
   @cDymCtnWgtTb        NVARCHAR( 20),
   @cDymCtnWgtCol       NVARCHAR( 20),
   @cDymCtnCubeTb       NVARCHAR( 20),
   @cDymCtnCubeCol      NVARCHAR( 20),
   @pickSkuDetailJson   NVARCHAR( MAX),
   @cPSN                INT,
   @cLBarcode           INT
      
 SET @EcomSingle = '0' 
 SET @CalOrderSKU = 'N'
 SET @cPSN = 0
 SET @cLBarcode = 0

--LEFT Panel: SKU + Image
DECLARE @packSKUDetail TABLE (         
    SKU              NVARCHAR( 30),  
    Descr            NVARCHAR( 150),
    RetailSKU        NVARCHAR( 30),
    ManufacturerSKU  NVARCHAR( 30),
    AltSKU           NVARCHAR( 30),
    QtyToPack        INT,
    PackedQty        INT,    
    Img              NVARCHAR( 1024),
    Ecom_CartonType  NVARCHAR( 10),
    InputWeight      NVARCHAR( 30),  --(cc01)  
    InputCube        NVARCHAR( 30),  --(cc01)  
    WEIGHT           FLOAT,
    CUBE             FLOAT,
    Ecom_Weight      FLOAT,
    Ecom_Cube        FLOAT,
    DynamicColName1  NVARCHAR( 50),
    DynamicColName2  NVARCHAR( 50),
    DynamicColValue1 NVARCHAR( 150),
    DynamicColValue2 NVARCHAR( 150),
    --UPC              NVARCHAR(MAX),
    UCC              NVARCHAR(MAX)
    --barcodeObj        NVARCHAR(MAX),
    --lottableVal     NVARCHAR(MAX)
) 

DECLARE @barcodeObj TABLE (
   barcodeVal NVARCHAR(250),
   AntiDiversionCode NVARCHAR(250),
   SKU   NVARCHAR(20)
)
--DECLARE @pickSKUDetail TABLE (  
CREATE TABLE #pickSKUDetail ( 
    SKU              NVARCHAR( 30),  
    QtyToPack        INT,
    OrderKey         NVARCHAR( 30),
    PickslipNo       NVARCHAR( 30),
    LoadKey          NVARCHAR( 30),--externalOrderKey
    PickDetailStatus NVARCHAR ( 3)
)

  
--Decode Json Format
SELECT @cStorerKey = StorerKey, @cFacility = Facility,  @nFunc=Func,@cScanNo=ScanNo, @cType = cType, @cUserName = UserName, @cLangCode = LangCode, @cCartonNo = CartonNo, @cOrderKeyCheck = OrderKey
FROM OPENJSON(@json)  
WITH (  
      StorerKey   NVARCHAR ( 15),
      Facility    NVARCHAR ( 5),
      Func        INT,  
      ScanNo     NVARCHAR( 30),
      cType       NVARCHAR( 30),
      UserName NVARCHAR( 30),
      LangCode    NVARCHAR( 3),
      CartonNo    NVARCHAR( 3),
      OrderKey    NVARCHAR( 10)
)  
--SELECT @cStorerKey AS StorerKey, @cFacility AS Facility,@nFunc AS Func, @cScanNo AS ScanNo, @cType AS TYPE, @cUserName AS userName, @cLangCode AS LangCode, @cOrderKeyCheck as OrderKey


--Data Validate  - Check ScanNo blank 
IF @cScanNo = ''  
BEGIN  
   SET @b_Success = 0
   SET @n_Err = 1000951
   SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Please scan or enter Packing Document No to proceed : isp_CheckCartonDetail'
   GOTO EXIT_SP
END  

IF @cCartonNo = ''
BEGIN  
   SET @b_Success = 0  
   SET @n_Err = 1000952  
   SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Unable to identify Carton No for check carton function. Function : isp_CheckCartonDetail'                                                 
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
      PickDetailStatus  NVARCHAR( 1)   '$.PickDetailStatus'
)

IF @EcomSingle = '1'
BEGIN
   
   SELECT @cPickSlipNo = pickslipNo FROM #pickSKUDetail WHERE orderKey = @cOrderKeyCheck
   
END

 --check storerConfig to skip cartonize
 DECLARE @skipCartonize NVARCHAR( 1)
 DECLARE @hidePackedSku NVARCHAR( 1)
 
 SET @hidePackedSku = '0'
 
 IF EXISTS (SELECT TOP 1 1  FROM dbo.storerConfig WITH (NOLOCK) WHERE storerKey = @cStorerKey AND configKey = 'TPS-captureWeight'AND (sValue LIKE '%w%' or sValue LIKE'%c%'))
 BEGIN
    SET @skipCartonize = '0'
 END
 ELSE
 BEGIN
    SELECT @skipCartonize = sValue FROM dbo.StorerConfig WITH (NOLOCK) WHERE storerKey = @cStorerKey AND configKey = 'TPS-skipCartonize'
 END
 
 --check cartonType setup
 IF (@skipCartonize = '0' OR isNull(@skipCartonize,'') = '')
 BEGIN
    IF NOT EXISTS (SELECT TOP 1 1 FROM STORER S WITH (NOLOCK)
               JOIN CARTONIZATION C WITH (NOLOCK) ON (S.cartonGroup=C.CartonizationGroup)  WHERE S.StorerKey = @cStorerKey)
   BEGIN
      SET @n_Err = 1000953
      SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Please setup Cartonization in SCE/WMS to proceed. Function : isp_CheckCartonDetail'
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
   IF (ISNULL(@cDynamicTb1,'') <> '' AND @cDynamicTb1 NOT IN ('SKU')) OR (ISNULL(@cDynamicTb2,'') <> '' AND @cDynamicTb2 NOT IN ('SKU')) 
   BEGIN
      SET @n_Err = 1000954
      SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Incorrect dynamic Weight and Cube columns setup. Function : isp_CheckCartonDetail'
      GOTO EXIT_SP
   END
   
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

---- not in scope-- configure wan to display image not
--SELECT TOP 1
--@cDisplayImg = svalue
--FROM storerConfig (NOLOCK)
--WHERE storerKey = @cStorerKey
--AND configKey = 'TPS-DisplayImage'
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
      SET @n_Err = 1000955
      SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Incorrect dynamic SKU Weight column setup. Function : isp_CheckCartonDetail'
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
      SET @n_Err = 1000956
      SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Incorrect dynamic SKU Cube column setup. Function : isp_CheckCartonDetail'
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
      SET @n_Err = 1000957
      SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Incorrect dynamic E-Comm Carton Weight column setup. Function : isp_CheckCartonDetail'
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
      SET @n_Err = 1000958
      SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Incorrect dynamic E-Comm Cube column setup. Function : isp_CheckCartonDetail'
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


--DECLARE @cSQLLottableSelect NVARCHAR ( MAX)
--DECLARE @cSQLUPCSelect NVARCHAR ( MAX)
DECLARE @cSQLUCCSelect NVARCHAR ( MAX)
--DECLARE @cSQLSNOSelect NVARCHAR ( MAX)


--SET @cSQLLottableSelect = ',ISNULL((SELECT lottablevalue as Lottablevalue,  SUM(qty) as PackedQty
--                           FROM PackDetail (nolock)
--                           WHERE PickSlipNo = PD.pickslipNo
--                              AND CartonNo = PD.CartonNo
--                              AND ISNULL(lottablevalue,'''') <>''''
--                           group by lottablevalue FOR JSON AUTO),' +'''[]'')'  + 'AS Lottable'


--SET @cSQLUPCSelect = ',ISNULL((SELECT UPC as UPC,  SUM(qty) as QTY
--                           FROM PackDetail (nolock)
--                           WHERE PickSlipNo = PD.pickslipNo
--                              AND  CartonNo = PD.CartonNo
--                              AND ISNULL(UPC,'''') <>''''
--                           group by UPC FOR JSON AUTO),' +'''[]'')'  + 'AS UPC'

                           
SET @cSQLUCCSelect = ',ISNULL((SELECT UCCNO
                           FROM packDetail PDl(nolock)
                              JOIN UCC UCC (NOLOCK) ON UCC.UCCNO = PDL.UPC
                           WHERE PickSlipNo = PD.pickslipNo
                           and cartonno = PD.CartonNo),'''')'  + 'AS UCC'


IF EXISTS (   SELECT 1 
            FROM PackSerialNo PSN (NOLOCK)
               JOIN #pickSKUDetail pick on (pick.pickslipNo = PSN.pickslipNo and pick.sku = PSN.sku)  
            WHERE  cartonno = @cCartonNo
            )
BEGIN
   SET @cPSN = 1
   IF EXISTS (   SELECT 1 
            FROM PackSerialNo PSN (NOLOCK)
               JOIN #pickSKUDetail pick on (pick.pickslipNo = PSN.pickslipNo and pick.sku = PSN.sku)  
            WHERE  cartonno = @cCartonNo
                  AND ISNULL(Barcode,'') <>''
            )
   BEGIN
      SET @cLBarcode = 1
      INSERT INTO @barcodeObj (barcodeVal, AntiDiversionCode,SKU)
      SELECT '' ,Barcode, SKU
         FROM PackSerialNo (nolock)
         WHERE PickSlipNo = @cPickSlipNo
            AND cartonno = @cCartonNo
            AND ISNULL(SerialNo,'') <>''
         group by Barcode, SKU
      --SET @cSQLSNOSelect = ',ISNULL((SELECT '''' as barcodeVal,Barcode AS AntiDiversionCode
      --                     FROM PackSerialNo (nolock)
      --                     WHERE PickSlipNo = PD.pickslipNo
      --                        AND cartonno = PD.CartonNo
      --                        AND ISNULL(SerialNo,'''') <>''''
      --                     group by Barcode FOR JSON AUTO),' +'''[]'')'  + 'AS barcodeObj'
   END
   ELSE
   BEGIN
      INSERT INTO @barcodeObj (barcodeVal, AntiDiversionCode,SKU)
      SELECT '' ,SerialNo , SKU
      FROM PackSerialNo (nolock)
      WHERE PickSlipNo = @cPickSlipNo
         AND cartonno = @cCartonNo
         AND ISNULL(SerialNo,'') <>''
      group by SerialNo, SKU
      --SET @cSQLSNOSelect = ',ISNULL((SELECT '''' as barcodeVal,SerialNo AS AntiDiversionCode
      --               FROM PackSerialNo (nolock)
      --               WHERE PickSlipNo = PD.pickslipNo
      --                  AND cartonno = PD.CartonNo
      --                  AND ISNULL(SerialNo,'''') <>''''
      --               group by SerialNo FOR JSON AUTO),' +'''[]'')'  + 'AS barcodeObj'
   END


END
ELSE
BEGIN
   INSERT INTO @barcodeObj (barcodeVal, AntiDiversionCode,SKU)
   SELECT '',SerialNo,SKU
      FROM SerialNo (nolock)
      WHERE PickSlipNo = @cPickSlipNo
         AND cartonno = @cCartonNo
         AND ISNULL(SerialNo,'') <>''
      group by SerialNo, SKU
   --SET @cSQLSNOSelect = ',ISNULL((SELECT '''' as barcodeVal,SerialNo AS AntiDiversionCode
   --            FROM SerialNo (nolock)
   --            WHERE PickSlipNo = PD.pickslipNo
   --               AND cartonno = PD.CartonNo
   --               AND ISNULL(SerialNo,'''') <>''''
   --            group by SerialNo FOR JSON AUTO),' +'''[]'')'  + 'AS barcodeObj'
END

--WeightKey in 
DECLARE @cInputWeight   NVARCHAR(30)   --(cc01)
DECLARE @cInputCube     NVARCHAR(30)  --(cc01)

SELECT @cInputWeight = CONVERT(NVARCHAR(30),CAST(ISNULL(weight, 0) AS numeric(20,4))), @cInputCube = CONVERT(NVARCHAR(30),CAST(ISNULL(Cube, 0) AS decimal(20,4))) FROM packInfo WITH (NOLOCK) WHERE cartonNo = @cCartonNo AND pickslipno = @cPickSlipNo  
--SELECT @cCartonNo AS cCartonNo, @cPickSlipNo AS cPickSlipNo
--SELECT @cInputWeight AS cInputWeight,@cInputCube AS cInputCube
--SELECT @cSQLDymWgtSelect AS SQLDymWgtSelect
--form packInfo output 
DECLARE @cSQLCobine     NVARCHAR( MAX)
DECLARE @cSQLMainSelect NVARCHAR( MAX)
DECLARE @cSQLFrom       NVARCHAR( MAX)
   
IF @EcomSingle = '1'  
BEGIN  
 SET @cSQLMainSelect = '  
   SELECT   
   sku.SKU,SKU.descr,SKU.RetailSKU, SKU.ManufacturerSKU,SKU.ALTSKU,(pick.QtyToPack-isnull((SUM(PD.qty)),0)) AS QtyToPack, SUM(PD.qty) AS PackedQty,'''' AS Img,SKU.EcomCartonType,  
   ' + ISNULL(@cInputWeight,'0') + ' AS InputWeight, '+ ISNULL(@cInputCube,'0') + ' AS InputCube'  

   SET @cSQLFrom =  
   '  
   FROM dbo.packHeader PH WITH (NOLOCK)   
   JOIN dbo.packDetail PD WITH (NOLOCK) on (PH.pickslipNo = PD.pickslipNo and PH.storerKey = PD.storerKey)  
   JOIN dbo.SKU sku WITH (NOLOCK) on (SKU.SKU = PD.SKU)  
   JOIN #pickSKUDetail pick on (pick.OrderKey = PH.orderKey and pick.pickslipNo = PD.pickslipNo and pick.sku = Sku.sku)  
   WHERE SKU.storerKey = ''' +@cStorerKey+ '''  
   and PH.OrderKey = ''' +@cOrderKeyCheck+ '''  
   GROUP BY sku.SKU,SKU.descr,SKU.RetailSKU, SKU.ManufacturerSKU,SKU.ALTSKU,sku.WEIGHT,sku.[CUBE],  
   SKU.EcomCartonType,sku.StdGrossWgt,sku.StdCube,pick.QtyToPack  
   '  --, lottablevalue,PD.pickslipNo, PD.CartonNo,PD.UPC
END  
ELSE  
BEGIN  
 SET @cSQLMainSelect = '    
   SELECT    
   sku.SKU,SKU.descr,SKU.RetailSKU, SKU.ManufacturerSKU,SKU.ALTSKU,(pick.QtyToPack-isnull((SUM(PD.qty)),0)) AS QtyToPack, SUM(PD.qty) AS PackedQty,'''' AS Img,SKU.EcomCartonType,    
   ' + ISNULL(@cInputWeight,'0') + ' AS InputWeight, '+ ISNULL(@cInputCube,'0') + ' AS InputCube'    
     
    
   SET @cSQLFrom =    
   '    
   FROM #pickSKUDetail pick    
   LEFT JOIN dbo.SKU sku WITH (NOLOCK) ON (sku.sku = pick.sku)    
   LEFT JOIN dbo.packDetail PD WITH (NOLOCK) on (pick.pickslipNo = PD.pickslipNo and SKU.SKU = PD.SKU)    
   WHERE SKU.storerKey = ''' +@cStorerKey+ '''    
   and PD.cartonNo = ''' +@cCartonNo+ '''    
   GROUP BY sku.SKU,SKU.descr,SKU.RetailSKU, SKU.ManufacturerSKU,SKU.ALTSKU,sku.WEIGHT,sku.[CUBE],    
   SKU.EcomCartonType,sku.StdGrossWgt,sku.StdCube,pick.QtyToPack  ,PD.pickslipNo, PD.CartonNo
   '
END  
  



  
SET @cSQLCobine = @cSQLMainSelect+@cSQLDymWgtSelect+@cSQLDynamicSelect
--+@cSQLUPCSelect 
+ @cSQLUCCSelect
--+ @cSQLSNOSelect
--+ @cSQLLottableSelect
+ @cSQLFrom+@cSQLGropBy  


  --select @cSQLCobine
--LEFT JOIN dbo.packDetail PD WITH (NOLOCK) on (pick.pickslipNo = PD.pickslipNo and PD.storerKey = PD.storerKey)

INSERT INTO @packSKUDetail
EXEC (@cSQLCobine)

--DROP TABLE #pickSKUDetail 
--SELECT * FROM #pickSKUDetail ORDER BY pickslipNo

--SELECT pick.*,SUM(PD.QTY) AS PackedQty,PD.QTY AS CartonQty FROM #pickSKUDetail pick
--LEFT JOIN packDetail PD (NOLOCK) ON ( pick.PickslipNo = PD.PickSlipNo AND pick.sku = PD.SKU)
----LEFT JOIN packDetail PD2 (NOLOCK) ON ( PD.PickslipNo = PD2.PickSlipNo AND PD2.sku = PD.SKU AND PD2.CartonNo = @cCartonNo)
--WHERE PD.cartonno = @cCartonNo
--GROUP BY pick.sku,pick.LoadKey,pick.OrderKey,pick.PickDetailStatus,pick.PickslipNo,pick.QtyToPack,PD.PickSlipNo,PD.pickslipNo,PD.SKU,PD.QTY--,PD2.pickslipNo,PD2.SKU,,PD2.CartonNo,PD2.QTY

--SELECT 'AA',* FROM @packSKUDetail

--get img
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
      --default Img, cause sp still point to MYWMS
      INSERT INTO @SkuImg
      EXEC [API].[isp_Get_SKU_Image_UR] 
      --exec [MYWMS].rdt.[Get_SKU_Image_URL_test]       
      --EXEC [MYWMS].[WM].[lsp_WM_Get_SKU_Image_URL]
         'NIKEMY'      
      , @cSku            
      , @cUserName         
      , @b_Success        OUTPUT  
      , @n_err            OUTPUT                                                                                                             
      , @c_ErrMsg         OUTPUT

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
     

--output Json format  
SET @b_Success = 1  
----SET @jResult = (SELECT * FROM @packSKUDetail FOR JSON AUTO, INCLUDE_NULL_VALUES)

--SET @jResult = (SELECT MAX(PD.CartonNo) AS MaxCartonNo,(SELECT COUNT(CartonStatus)AS HoldStatus from packInfo WITH (NOLOCK) WHERE pickslipno=@cPickSlipNo AND cartonStatus = 'Hold') AS HoldStatus ,
--@cDynamicRightName1 AS DynamicRightName1,@cDynamicRightValue1 AS DynamicRightValue1,@skipCartonize AS skipCartonize,@hidePackedSku AS hidePackedSku,@EcomSingle AS EcomSingle,
----COUNT(PKI.cartonStatus) AS HoldStatus,
--   (SELECT p.*,UPC.upc
--   FROM @packSKUDetail p 
--   left JOIN (SELECT UPC,sku FROM UPC (NOLOCK) WHERE StorerKey = @cStorerKey) UPC
--   ON UPC.sku = p.sku 
--   FOR JSON AUTO, INCLUDE_NULL_VALUES ) AS Details
   
--FROM #pickSKUDetail PSKU  WITH (NOLOCK) 
--LEFT JOIN PackDetail PD WITH (NOLOCK) ON (PSKU.pickslipno = PD.pickslipNo)
----WHERE PD.PickSlipNo = @cPickSlipNo
--AND StorerKey = @cStorerKey
--FOR JSON AUTO, INCLUDE_NULL_VALUES)

SET @jResult = 
   (SELECT p.*
   ,ISNULL((SELECT lottablevalue as Lottable,  SUM(qty) as PackedQty
                           FROM PackDetail (nolock)
                           WHERE PickSlipNo = @cPickSlipNo
                              AND cartonno = @cCartonNo
                              AND ISNULL(lottablevalue,'') <>''''
                              AND SKU = P.SKU 
                           group by lottablevalue FOR JSON PATH),'[]') AS Lottable
   ,ISNULL((SELECT ISNULL(UPC,'') as UPC,  ISNULL(SUM(qty),'') as QTY
                           FROM PackDetail (nolock)
                           WHERE PickSlipNo = @cPickSlipNo
                              AND cartonno = @cCartonNo
                              AND ISNULL(UPC,'') <>''
                              AND SKU = P.SKU 
                           group by UPC FOR JSON PATH),'[]') AS UPC
   ,  ISNULL((SELECT barcodeVal, AntiDiversionCode FROM @barcodeObj WHERE SKU = P.SKU FOR JSON PATH),'[]') AS barcodeObj
   FROM @packSKUDetail p
   FOR JSON AUTO, INCLUDE_NULL_VALUES ) 
   
--FROM #pickSKUDetail PSKU  WITH (NOLOCK) 
--LEFT JOIN PackDetail PD WITH (NOLOCK) ON (PSKU.pickslipno = PD.pickslipNo)
----WHERE PD.PickSlipNo = @cPickSlipNo
--AND StorerKey = @cStorerKey
--FOR JSON AUTO, INCLUDE_NULL_VALUES)

DROP TABLE #pickSKUDetail 

EXIT_SP:
   REVERT  


GO