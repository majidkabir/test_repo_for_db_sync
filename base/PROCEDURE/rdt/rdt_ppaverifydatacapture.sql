SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_PPAVerifyDataCapture                            */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Purpose: Verify Data captured                                        */  
/*                                                                      */  
/* Date        Rev  Author       Purposes                               */  
/* 2019-03-29  1.0  James        WMS-8002 Created                       */  
/* 2021-07-19  1.1  Chermaine    WMS-17439 Add Coo (cc01)               */  
/* 2022-03-28  1.2  James        WMS-17439 Add custom verify sp(james01)*/
/************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_PPAVerifyDataCapture]  
   @nMobile          INT,  
   @nFunc            INT,  
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT,  
   @nInputKey        INT,  
   @cFacility        NVARCHAR( 3),  
   @cStorerKey       NVARCHAR( 15),  
   @cType            NVARCHAR( 10),  
   @tDataCapture     VariableTable READONLY,   
   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,  
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,  
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,  
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,  
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,  
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,  
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,  
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,  
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,  
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,  
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,  
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,  
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,  
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,  
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,  
   @cCaptureData     NVARCHAR( 1)  OUTPUT,  
   @nErrNo           INT           OUTPUT,  
   @cErrMsg          NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nRowCount         INT  
   DECLARE @cSQL              NVARCHAR( MAX)  
   DECLARE @cSQLParam         NVARCHAR( MAX)  
   DECLARE @cBarcode          NVARCHAR( MAX)  
   DECLARE @nScan             INT  
   DECLARE @nTotal            INT  
   DECLARE @nSKUCnt           INT  
   DECLARE @bSuccess          INT  
   DECLARE @cUPC              NVARCHAR( 30)  
   DECLARE @cRetailSKU        NVARCHAR( 20)  
   DECLARE @cAltSKU           NVARCHAR( 20)  
   DECLARE @cManufacturerSKU  NVARCHAR( 20)  
   DECLARE @cSerialNoCapture  NVARCHAR( 1)  
   DECLARE @cBrand            NVARCHAR(10)  
   DECLARE @cDecodeSP         NVARCHAR(20)  
   DECLARE @cOrderKey         NVARCHAR(10)  
   DECLARE @cBatchNo          NVARCHAR(18)  
   DECLARE @cCaseID           NVARCHAR(18)  
   DECLARE @cPalletID         NVARCHAR(18)  
   DECLARE @nCaseCnt          INT  
   DECLARE @nLoop             INT  
   DECLARE @nQTY      INT  
   DECLARE @cDataCaptureExtUpdSP NVARCHAR( 20)  
   DECLARE @cUserName         NVARCHAR( 18)  
   DECLARE @cSKU              NVARCHAR( 20)  
   DECLARE @cTaskDetailKey    NVARCHAR( 10)  

   DECLARE @cCaptureInfoSP NVARCHAR(20)
   SET @cCaptureInfoSP = rdt.RDTGetConfig( @nFunc, 'CaptureInfoSP', @cStorerKey)
   IF @cCaptureInfoSP = '0'
      SET @cCaptureInfoSP = ''

   /***********************************************************************************************
                                     Standard Verify SP
   ***********************************************************************************************/
   IF @cCaptureInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cCaptureInfoSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cCaptureInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType,  ' +
            ' @tDataCapture,  ' + 
            ' @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT, ' +   
            ' @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT, ' +   
            ' @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT, ' +   
            ' @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT, ' +   
            ' @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT, ' +   
            ' @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT, ' +  
            ' @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT, ' +  
            ' @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT, ' +  
            ' @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT, ' +  
            ' @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT, ' +  
            ' @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT, ' + 
            ' @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, ' + 
            ' @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT, ' + 
            ' @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, ' + 
            ' @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, ' + 
            ' @cCaptureData OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT ' 
         SET @cSQLParam =
            ' @nMobile     INT,           ' +
            ' @nFunc       INT,           ' +
            ' @cLangCode   NVARCHAR( 3),  ' +
            ' @nStep       INT,           ' +
            ' @nInputKey   INT,           ' +
            ' @cFacility   NVARCHAR( 5),  ' +
            ' @cStorerKey  NVARCHAR( 15), ' +
            ' @cType       NVARCHAR( 10), ' +
            ' @tDataCapture     VariableTable READONLY,' + 
            ' @cInField01  NVARCHAR(20) OUTPUT,  @cOutField01 NVARCHAR(20) OUTPUT,  @cFieldAttr01 NVARCHAR(1) OUTPUT, ' +   
            ' @cInField02  NVARCHAR(20) OUTPUT,  @cOutField02 NVARCHAR(20) OUTPUT,  @cFieldAttr02 NVARCHAR(1) OUTPUT, ' +   
            ' @cInField03  NVARCHAR(20) OUTPUT,  @cOutField03 NVARCHAR(20) OUTPUT,  @cFieldAttr03 NVARCHAR(1) OUTPUT, ' +   
            ' @cInField04  NVARCHAR(20) OUTPUT,  @cOutField04 NVARCHAR(20) OUTPUT,  @cFieldAttr04 NVARCHAR(1) OUTPUT, ' +   
            ' @cInField05  NVARCHAR(20) OUTPUT,  @cOutField05 NVARCHAR(20) OUTPUT,  @cFieldAttr05 NVARCHAR(1) OUTPUT, ' +   
            ' @cInField06  NVARCHAR(20) OUTPUT,  @cOutField06 NVARCHAR(20) OUTPUT,  @cFieldAttr06 NVARCHAR(1) OUTPUT, ' +  
            ' @cInField07  NVARCHAR(20) OUTPUT,  @cOutField07 NVARCHAR(20) OUTPUT,  @cFieldAttr07 NVARCHAR(1) OUTPUT, ' +  
            ' @cInField08  NVARCHAR(20) OUTPUT,  @cOutField08 NVARCHAR(20) OUTPUT,  @cFieldAttr08 NVARCHAR(1) OUTPUT, ' +  
            ' @cInField09  NVARCHAR(20) OUTPUT,  @cOutField09 NVARCHAR(20) OUTPUT,  @cFieldAttr09 NVARCHAR(1) OUTPUT, ' +  
            ' @cInField10  NVARCHAR(20) OUTPUT,  @cOutField10 NVARCHAR(20) OUTPUT,  @cFieldAttr10 NVARCHAR(1) OUTPUT, ' +  
            ' @cInField11  NVARCHAR(20) OUTPUT,  @cOutField11 NVARCHAR(20) OUTPUT,  @cFieldAttr11 NVARCHAR(1) OUTPUT, ' + 
            ' @cInField12  NVARCHAR(20) OUTPUT,  @cOutField12 NVARCHAR(20) OUTPUT,  @cFieldAttr12 NVARCHAR(1) OUTPUT, ' + 
            ' @cInField13  NVARCHAR(20) OUTPUT,  @cOutField13 NVARCHAR(20) OUTPUT,  @cFieldAttr13 NVARCHAR(1) OUTPUT, ' + 
            ' @cInField14  NVARCHAR(20) OUTPUT,  @cOutField14 NVARCHAR(20) OUTPUT,  @cFieldAttr14 NVARCHAR(1) OUTPUT, ' + 
            ' @cInField15  NVARCHAR(20) OUTPUT,  @cOutField15 NVARCHAR(20) OUTPUT,  @cFieldAttr15 NVARCHAR(1) OUTPUT, ' + 
            ' @cCaptureData NVARCHAR( 1) OUTPUT,   ' + 
            ' @nErrNo  INT           OUTPUT, ' +
            ' @cErrMsg NVARCHAR( 20) OUTPUT  ' 
         
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType, 
            @tDataCapture,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,   
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,   
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,   
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,   
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,   
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT, 
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, 
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT, 
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, 
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, 
            @cCaptureData OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 
      
         GOTO Quit
      END
   END

   /***********************************************************************************************
                                     Standard Verify SP
   ***********************************************************************************************/
   
   --(cc01)  
   DECLARE   
      @cDropID                         NVARCHAR( 20),  
      @cCheckCoo                       NVARCHAR( 1),   
      @cPPACartonIDByPackDetailDropID  NVARCHAR( 1),  
      @cPPACartonIDByPackDetailLabelNo NVARCHAR( 1),  
      @cPPACartonIDByPickDetailCaseID  NVARCHAR( 1)
  
   SELECT @cSKU = Value FROM @tDataCapture WHERE Variable = '@cSKU'  
   SELECT @cBarcode = Value FROM @tDataCapture WHERE Variable = '@cBarcode'  
   SELECT @cUserName = Value FROM @tDataCapture WHERE Variable = '@cUserName'  
   SELECT @nQTY = Value FROM @tDataCapture WHERE Variable = '@nQTY'  
   SELECT @cTaskDetailKey = Value FROM @tDataCapture WHERE Variable = '@cTaskDetailKey'  
   SELECT @cDropID = Value FROM @tDataCapture WHERE Variable = '@cDropID'  --(cc01)  
     
     
   -- Check serial no tally QTY  
   IF @cType = 'CHECK'  
   BEGIN  
    --(cc01)  
    IF @nStep = '2'  --statistic [ENTER]  
    BEGIN  
        --(cc01)  
         SET @cCheckCoo = rdt.RDTGetConfig( @nFunc, 'CheckCOO', @cStorerKey)   
         IF @cCheckCoo = '0'  
            SET @cCheckCoo = ''  
         SET @cPPACartonIDByPackDetailDropID = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPackDetailDropID', @cStorerKey)  
         SET @cPPACartonIDByPackDetailLabelNo = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPackDetailLabelNo', @cStorerKey)  
         SET @cPPACartonIDByPickDetailCaseID = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPickDetailCaseID', @cStorerKey)  
           
         IF @cCheckCoo <> ''   
       BEGIN  
        --1. If Carton ID scanned in screen 1 belong to an export order (Orders.DocType = 'N' AND Orders.C_Country <> Storer.Country WHERE Storer.Storerkey = Orders.StorerKey),              
            IF @cPPACartonIDByPackDetailDropID = '1'  
            BEGIN  
               IF EXISTS( SELECT 1  
                  FROM dbo.PackHeader PH WITH (NOLOCK)  
                     INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
                     INNER JOIN dbo.Orders O WITH (NOLOCK) ON (O.orderKey = PH.OrderKey AND O.StorerKey = PH.StorerKey)  
                     INNER JOIN Storer S WITH (NOLOCK) ON (O.StorerKey = S.StorerKey)  
                  WHERE PD.DropID = @cDropID  
                     AND PH.StorerKey = @cStorerKey  
                     AND O.DocType = 'N'  
                     AND O.C_Country <> S.Country)  
               BEGIN  
                  SET @cCaptureData = 1  
               END  
            END  
            ELSE  
            IF @cPPACartonIDByPackDetailLabelNo = '1'  
            BEGIN  
               IF EXISTS( SELECT 1  
                  FROM dbo.PackHeader PH WITH (NOLOCK)  
                     INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
                     INNER JOIN dbo.Orders O WITH (NOLOCK) ON (O.orderKey = PH.OrderKey AND O.StorerKey = PH.StorerKey)  
                     INNER JOIN Storer S WITH (NOLOCK) ON (O.StorerKey = S.StorerKey)  
                  WHERE PD.LabelNo = @cDropID  
                     AND PH.StorerKey = @cStorerKey  
                     AND O.DocType = 'N'  
                     AND O.C_Country <> S.Country)  
               BEGIN  
                  SET @cCaptureData = 1  
               END  
            END  
            ELSE  
            IF @cPPACartonIDByPickDetailCaseID = '1'  
            BEGIN  
               IF EXISTS( SELECT 1  
                  FROM dbo.PickDetail PD WITH (NOLOCK)  
                     INNER JOIN dbo.Orders O WITH (NOLOCK) ON (O.orderKey = PD.OrderKey AND O.StorerKey = PD.StorerKey)  
                     INNER JOIN Storer S WITH (NOLOCK) ON (O.StorerKey = S.StorerKey)  
                  WHERE PD.CaseID = @cDropID  
                     AND PD.StorerKey = @cStorerKey  
                     AND ShipFlag <> 'Y'  
                     AND O.DocType = 'N'  
                     AND O.C_Country <> S.Country)  
               BEGIN  
                  SET @cCaptureData = 1  
               END  
            END  
            ELSE  
            BEGIN  
               IF EXISTS( SELECT 1  
                  FROM dbo.PickDetail PD WITH (NOLOCK)  
                     INNER JOIN dbo.Orders O WITH (NOLOCK) ON (O.orderKey = PD.OrderKey AND O.StorerKey = PD.StorerKey)  
                     INNER JOIN Storer S WITH (NOLOCK) ON (O.StorerKey = S.StorerKey)  
                  WHERE DropID = @cDropID  
                     AND PD.StorerKey = @cStorerKey  
                     AND ShipFlag <> 'Y'  
                     AND O.DocType = 'N'  
                     AND O.C_Country <> S.Country)  
               BEGIN  
                SET @cCaptureData = 1  
               END  
           ELSE  
           BEGIN  
            SET @cCaptureData = 0  
           END  
            END  
       END  
       ELSE  
       BEGIN  
        SET @cCaptureData = 0 -- No need capture data  
       END  
    END  
  
      IF @nStep = 3 --sku  
      BEGIN  
       -- Get SKU info  
         SELECT   
            @cBrand   = Class,   
            @nCaseCnt = CAST( Pack.CaseCnt AS INT)  
         FROM dbo.SKU WITH (NOLOCK)  
         JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)  
         WHERE StorerKey = @cStorerKey   
         AND   SKU = @cSKU   
  
         -- Check brand need to capture  
         IF EXISTS( SELECT 1 FROM CodeLkup WITH (NOLOCK) WHERE ListName = 'MHCSSCAN' AND Code = @cBrand AND StorerKey = @cStorerKey)  
         BEGIN  
            SET @cCaptureData = 1 -- Need capture data  
            SET @cOutField13 = '0/' + CAST ( @nQTY/@nCaseCnt AS NVARCHAR( 3))  
         END  
         ELSE  
         BEGIN  
          SET @cCaptureData = 0 -- No need capture data  
         END  
      END  
   END  
  
   -- Update serial no  
   IF @cType = 'UPDATE'  
   BEGIN  
      SET @cDecodeSP = rdt.rdtGetConfig( @nFunc, 'VerifyDataCaptureDecodeSP', @cStorerKey)  
      IF @cDecodeSP = '0'  
         SET @cDecodeSP = ''  
  
      IF @cDecodeSP <> ''  
      BEGIN  
         -- Standard decode  
         IF @cDecodeSP = '1'  
         BEGIN  
            -- Set dummy value first  
            SET @cUPC = 'UPC'  
            SET @cBatchNo = 'BatchNo'  
            SET @cCaseID = 'CaseID'  
            SET @cPalletID = 'PalletID'  
  
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,   
               @cUPC          = @cUPC           OUTPUT,  -- UPC  
               @cUserDefine01 = @cBatchNo       OUTPUT,  -- batch no  
               @cUserDefine02 = @cCaseID        OUTPUT,  -- case id  
               @cUserDefine03 = @cPalletID      OUTPUT,  -- pallet id  
               @nErrNo        = @nErrNo         OUTPUT,   
               @cErrMsg       = @cErrMsg        OUTPUT,  
               @cType         = ''  
              
            IF @nErrNo <> 0  
               GOTO Quit  
  
            SET @cUPC = CASE WHEN @cUPC = 'UPC' THEN '' ELSE @cUPC END   
            SET @cBatchNo = CASE WHEN @cBatchNo = 'BatchNo' THEN '' ELSE @cBatchNo END   
            SET @cCaseID = CASE WHEN @cCaseID = 'CaseID' THEN '' ELSE @cCaseID END   
            SET @cPalletID = CASE WHEN @cPalletID = 'PalletID' THEN '' ELSE @cPalletID END   
         END  
         ELSE  
         BEGIN  
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')  
            BEGIN  
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +  
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @tDataCapture, ' +  
                  ' @cSKU OUTPUT, @cBatchNo OUTPUT, @cCaseID OUTPUT, @cPalletID OUTPUT, @nScan OUTPUT, @nTotal OUTPUT, ' +   
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT '  
               SET @cSQLParam =  
                  ' @nMobile        INT,            ' +  
                  ' @nFunc          INT,            ' +  
                  ' @cLangCode      NVARCHAR( 3),   ' +  
                  ' @nStep          INT,            ' +  
                  ' @nInputKey      INT,            ' +  
                  ' @cFacility      NVARCHAR( 5),   ' +  
                  ' @cStorerKey     NVARCHAR( 15),  ' +  
                  ' @tDataCapture   VariableTable READONLY,  ' +  
                  ' @cSKU           NVARCHAR( 20)  OUTPUT, ' +  
                  ' @cBatchNo       NVARCHAR( 18)  OUTPUT, ' +  
                  ' @cCaseID        NVARCHAR( 18)  OUTPUT, ' +  
                  ' @cPalletID      NVARCHAR( 18)  OUTPUT, ' +  
                  ' @nScan          INT            OUTPUT, ' +  
                  ' @nTotal         INT            OUTPUT, ' +  
                  ' @nErrNo         INT            OUTPUT, ' +  
                  ' @cErrMsg        NVARCHAR( 20)  OUTPUT'  
  
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @tDataCapture,   
                  @cSKU OUTPUT, @cBatchNo OUTPUT, @cCaseID OUTPUT, @cPalletID OUTPUT, @nScan OUTPUT, @nTotal OUTPUT,   
                  @nErrNo OUTPUT, @cErrMsg OUTPUT   
  
               IF @nErrNo <> 0  
                  GOTO Quit  
            END  
         END  
  
         IF ISNULL( @cUPC, '') <> ''  
         BEGIN  
            -- Get SKU count  
            EXEC RDT.rdt_GETSKUCNT  
                @cStorerKey  = @cStorerKey  
               ,@cSKU        = @cUPC  
               ,@nSKUCnt     = @nSKUCnt       OUTPUT  
               ,@bSuccess    = @bSuccess      OUTPUT  
               ,@nErr        = @nErrNo        OUTPUT  
               ,@cErrMsg     = @cErrMsg       OUTPUT  
     
            -- Check SKU/UPC  
            IF @nSKUCnt = 0  
            BEGIN  
               SET @nErrNo = 85761  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU  
               GOTO Quit  
            END  
     
            -- Check multi SKU barcode  
            IF @nSKUCnt > 1  
            BEGIN  
               SET @nErrNo = 85762  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod  
               GOTO Quit  
            END  
     
            -- Get SKU code  
            EXEC RDT.rdt_GETSKU  
                @cStorerKey  = @cStorerKey  
               ,@cSKU        = @cUPC          OUTPUT  
               ,@bSuccess    = @bSuccess      OUTPUT  
               ,@nErr        = @nErrNo        OUTPUT  
               ,@cErrMsg     = @cErrMsg       OUTPUT  
  
            SET @cSKU = @cUPC  
         END  
  
         SET @cDataCaptureExtUpdSP = rdt.rdtGetConfig( @nFunc, 'DataCaptureExtUpdSP', @cStorerKey)  
         IF @cDataCaptureExtUpdSP = '0'  
            SET @cDataCaptureExtUpdSP = ''  
  
         IF @cDataCaptureExtUpdSP <> ''  
         BEGIN  
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDataCaptureExtUpdSP AND type = 'P')  
            BEGIN  
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDataCaptureExtUpdSP) +   
                  ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @tDataCapture, ' +  
                  ' @cBatchNo, @cCaseID, @cPalletID, @nErrNo OUTPUT, @cErrMsg OUTPUT '   
               SET @cSQLParam =   
                  '@nMobile       INT,           ' +  
                  '@nFunc         INT,           ' +  
                  '@cLangCode     NVARCHAR( 3),  ' +  
                  '@cUserName     NVARCHAR( 18), ' +  
                  '@cFacility     NVARCHAR( 5),  ' +  
                  '@cStorerKey    NVARCHAR( 15), ' +  
                  '@tDataCapture  VariableTable READONLY, ' +  
                  '@cBatchNo      NVARCHAR( 18), ' +  
                  '@cCaseID       NVARCHAR( 18), ' +  
                  '@cPalletID     NVARCHAR( 18), ' +  
                  '@nErrNo        INT           OUTPUT, ' +  
                  '@cErrMsg       NVARCHAR( 20) OUTPUT  '  
  
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,   
               @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @tDataCapture,   
               @cBatchNo, @cCaseID, @cPalletID, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
               IF @nErrNo <> 0  
                  GOTO Quit  
            END  
         END  
      END  
  
      IF @nErrNo = -1 -- Remain in current screen  
      BEGIN  
         SET @cBarcode = ''  
                 
         -- Prepare next screen var  
         SET @cOutField02 = @cTaskDetailKey  
         SET @cOutField03 = ''  
         SET @cOutField07 = CAST( @nScan AS NVARCHAR( 5)) + '/' + CAST( @nTotal AS NVARCHAR( 5))  
                 
         GOTO Quit  
      END  
   END  
  
Quit:  
  
END

GO