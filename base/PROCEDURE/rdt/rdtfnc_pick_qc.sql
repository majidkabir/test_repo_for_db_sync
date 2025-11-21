SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/  
/* Store procedure: rdtfnc_Pick_QC                                           */  
/* Copyright      : IDS                                                      */  
/*                                                                           */  
/* Modifications log:                                                        */  
/*                                                                           */  
/* Date       Rev  Author    Purposes                                        */  
/* 2020-09-07 1.0  Chermaine WMS-14893 Created                               */  
/*****************************************************************************/  
  
CREATE PROC [RDT].[rdtfnc_Pick_QC](  
   @nMobile    INT,  
   @nErrNo     INT  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max  
) AS  
  
SET NOCOUNT ON   -- SQL 2005 Standard  
SET QUOTED_IDENTIFIER OFF   
SET ANSI_NULLS OFF     
SET CONCAT_NULL_YIELDS_NULL OFF    

-- Misc variables  
DECLARE  
   @bSuccess   INT
  
 
-- Define a variable  
DECLARE  
   @nFunc               INT,  
   @nScn                INT,  
   @nStep               INT,  
   @cLangCode           NVARCHAR(3),  
   @nMenu               INT,  
   @nInputKey           NVARCHAR(3),  
   @cPrinter            NVARCHAR(10),  
   @cPrinter_Paper      NVARCHAR(10),  
   @cUserName           NVARCHAR(18),  
  
   @cStorerKey          NVARCHAR(15),  
   @cFacility           NVARCHAR(5),  
  
   @cPickslipNo         NVARCHAR( 10),  
   @cPickConfirmStatus  NVARCHAR( 1),
   @cDecodeSP           NVARCHAR( 1),
   @cReasonCode         NVARCHAR( 30),
   @cSKU                NVARCHAR( 20),
   @cLabelNo            NVARCHAR( 20),
   @cBarcode            NVARCHAR( 20),  
   @cUPC                NVARCHAR( 20),  
   @cSKUBarcode         NVARCHAR( 20), 
   @cSKUDescr           NVARCHAR( 60),
   @cPickDetailQty      NVARCHAR( 5),
   @nScanQty            INT,
   @nQTY                INT,
   @nQTYAlloc           INT,  
   @nQTYPick            INT,
   @nRowRef             INT,
   @nScanSkuQty         INT,
   @nPDSKUQty           INT,
   @cFromLoc            NVARCHAR( 10),
   @cFromLot            NVARCHAR( 10),
   @cToLoc              NVARCHAR( 10),
   @cPickQCToLoc        NVARCHAR( 10),
   @cFromLocType        NVARCHAR( 10),
   @cChkStatus          NVARCHAR( 1),
   @cStatus             NVARCHAR( 10),
   @cOrderKey           NVARCHAR( 10),
   @cFromID             NVARCHAR( 18),

     
   @cSpecialHandling    NVARCHAR( 1),  
   @cLOC                NVARCHAR( 10),  
   @cLOC_Facility       NVARCHAR( 5),  
   @cDropLoc            NVARCHAR( 10),  
   @cID                 NVARCHAR( 18),   
   @cDropID             NVARCHAR( 18),   
   @cOption             NVARCHAR( 1),      
     
   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),  
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),  
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),  
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),  
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),  
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),  
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),  
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),  
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),  
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),  
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),  
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),  
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),  
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),  
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),  
  
   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),  
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),  
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),  
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),  
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),  
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),  
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),  
   @cFieldAttr15 NVARCHAR( 1),  
  
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),  
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),  
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),  
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),  
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)  
  
-- Getting Mobile information  
SELECT  
   @nFunc            = Func,  
   @nScn             = Scn,  
   @nStep            = Step,  
   @nInputKey        = InputKey,  
   @cLangCode        = Lang_code,  
   @nMenu            = Menu,  
  
   @cFacility        = Facility,  
   @cStorerKey       = StorerKey,  
   @cPrinter         = Printer,  
   @cPrinter_Paper   = Printer_Paper,  
   @cUserName        = UserName,  
  
   @cPickslipNo      = V_PickslipNo,   
   @cSKU             = V_SKU,
     
   @cPickConfirmStatus = V_String1,  
   @cReasonCode        = V_String2,   
   @cPickDetailQty     = V_String3,   
   @cFromLoc           = V_String4,  
   @cToLoc             = V_String5,  
   @cFromLocType       = V_String6,  
   @cPickQCToLoc       = V_String7,
   @cFromLot           = V_String8,
   
   @nScanQty           = V_Integer1,
  
   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  
  
   @cFieldAttr01  = FieldAttr01,    @cFieldAttr02   = FieldAttr02,  
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,  
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,  
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,  
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,  
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,  
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,  
   @cFieldAttr15 =  FieldAttr15  
  
FROM   RDTMOBREC (NOLOCK)  
WHERE  Mobile = @nMobile  
  
-- Redirect to respective screen  
IF @nFunc = 1848  
BEGIN  
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1848  
   IF @nStep = 1 GOTO Step_1   -- Scn = 5840 PICKSLIP NO  
   IF @nStep = 2 GOTO Step_2   -- Scn = 5841 REASON CODE  
   IF @nStep = 3 GOTO Step_3   -- Scn = 5842 SKU
   IF @nStep = 4 GOTO Step_4   -- Scn = 5844 Option  
END  
  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step 0. Called from menu (func = 1848)  
********************************************************************************/  
Step_0:  
BEGIN  
   -- Set the entry point  
   SET @nScn  = 5840  
   SET @nStep = 1  
   SET @nQTYAlloc = 0
   SET @nQTYPick = 0
   
   
   SET @cPickConfirmStatus = ''  
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)    
   --IF @cPickConfirmStatus = '0'  
   --   SET @cPickConfirmStatus = '5'
   
   SET @cDecodeSP = ''
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey) 
   
   SET @cPickQCToLoc = ''
   SET @cPickQCToLoc = rdt.RDTGetConfig( @nFunc, 'PickQCToLoc', @cStorerKey) 
     
   -- Prep next screen var  
   SET @cOutField01 = ''  
   
   -- insert to Eventlog  
   EXEC RDT.rdt_STD_EventLog  
      @cActionType   = '1', -- SignIn  
      @cUserID       = @cUserName,  
      @nMobileNo     = @nMobile,  
      @nFunctionID   = @nFunc,  
      @cFacility     = @cFacility,  
      @cStorerKey    = @cStorerkey 
END  
GOTO Quit  
  
/********************************************************************************  
Step 1. screen = 5840  
   PickslipNo: (Field01, input)  
********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cPickslipNo = @cInField01  
      SET @nScanQty = 0
  
      --Check if it is blank  
      IF @cPickslipNo = ''  
      BEGIN  
         SET @nErrNo = 158801  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PSNO  
         GOTO Step_1_Fail  
      END  
      
      IF NOT EXISTS (SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE pickslipNo = @cPickslipNo)
      BEGIN
      	SET @nErrNo = 158802  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO  
         GOTO Step_1_Fail 
      END
      
      DECLARE @cChkStorerKey NVARCHAR( 15)  
      DECLARE @cChkFacility  NVARCHAR( 5)  
      DECLARE @cChkUDF10     NVARCHAR( 10)  
  
      -- Get Order info        
      SELECT TOP 1
         @cChkStorerKey = O.StorerKey,   
         @cChkFacility = O.Facility,   
         @cChkUDF10 = O.UserDefine10, 
         @cChkStatus = PD.status
      FROM pickDetail PD WITH (NOLOCK) 
      JOIN ORDERS O WITH (NOLOCK) ON (O.orderKey = PD.orderKey)
      WHERE PD.pickslipNo = @cPickslipNo
      ORDER BY PD.Status
        
      --Check Storer  
      IF @cChkStorerKey <> @cStorerKey
      BEGIN  
         SET @nErrNo = 158803  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Storer  
         GOTO Step_1_Fail  
      END  
      
      --Check Facility  
      IF @cChkFacility <> @cFacility
      BEGIN  
         SET @nErrNo = 158804  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DiffFacility  
         GOTO Step_1_Fail  
      END 
      
      --check status     
      IF @cChkStatus > @cPickConfirmStatus OR  @cChkStatus = '4'
      BEGIN  
         SET @nErrNo = 158805  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidStatus  
         GOTO Step_1_Fail  
      END 
      
      --Check Status  
      IF @cChkFacility <> @cFacility
      BEGIN  
         SET @nErrNo = 158804  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DiffFacility  
         GOTO Step_1_Fail  
      END 
  
      --prepare next screen
      SET @cOutField01 = @cPickslipNo  
      SET @cOutField02 = ''  
  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
          
      EXEC RDT.rdt_STD_EventLog  
      @cActionType   = '9', -- SignOut  
      @cUserID       = @cUserName,  
      @nMobileNo     = @nMobile,  
      @nFunctionID   = @nFunc,  
      @cFacility     = @cFacility,  
      @cStorerKey    = @cStorerkey   
  
      -- Back to menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
  
      SET @cOutField01 = ''  
   END  
   GOTO Quit  
  
   Step_1_Fail:  
   BEGIN  
      SET @cPickslipNo = ''  
      SET @cOutField01 = ''  
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 2. screen = 5841  
   PICKSLIP NO (Field01)
   REASON CODE  (Field02, Input)  
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cReasonCode = @cInField02  
  
      IF @cReasonCode = ''  
      BEGIN  
         SET @nErrNo = 158806  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedReasonCode  
         GOTO Step_2_Fail  
      END  
      
      IF LEN (@cReasonCode) <> 8  
      BEGIN  
         SET @nErrNo = 158807  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Code  
         GOTO Step_2_Fail  
      END
      
      --IF NOT EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK) WHERE code = @cReasonCode AND listName ='QCReason' AND storerKey = @cStorerKey)
      --BEGIN  
      --   SET @nErrNo = 158807  
      --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Code  
      --   GOTO Step_2_Fail  
      --END
      
      SELECT @cPickDetailQty = SUM(Qty) FROM pickDetail WITH (NOLOCK) WHERE Storerkey = @cStorerKey AND pickslipNo = @cPickslipNo AND STATUS <= @cPickConfirmStatus AND STATUS <> '4'
    
      
      SET @cOutField01 = @cPickslipNo 
      SET @cOutField02 = @cReasonCode
           
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
      GOTO Quit  
  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      SET @cOutField01 = @cPickslipNo  
  
      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
   GOTO Quit  
  
   Step_2_Fail:  
   BEGIN   
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 3. screen = 5842  
   PICKSLIP NO (Field01)
   REASON CODE (Field02)   
   SKU         (Field03, Input)   
********************************************************************************/  
Step_3:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping   
      SET @cSKU = @cInField03 
      --SET @cBarcode = @cInField03  
      SET @cUPC = @cSKU  
      --SET @cSKUBarcode = @cInField03
      --SET @cLabelNo = @cInField05  
         
      IF @cSKU = ''  
      BEGIN  
         SET @nErrNo = 158808  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU  
         GOTO Step_3_Fail  
      END  
      
      -- Standard decode  
      IF @cDecodeSP = '1'  
      BEGIN  
         EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,  
            @cUPC    = @cSKU    OUTPUT,  
            @nQTY    = @nQTY    OUTPUT,  
            @nErrNo  = @nErrNo  OUTPUT,  
            @cErrMsg = @cErrMsg OUTPUT,  
            @cType   = 'UPC'  
  
         IF @nErrNo <> 0  
            GOTO Step_3_Fail   
      END  
        
      -- Get SKU count  
      DECLARE @nSKUCnt INT  
      SET @nSKUCnt = 0  
      EXEC RDT.rdt_GetSKUCNT  
          @cStorerKey  = @cStorerKey  
         ,@cSKU        = @cUPC  
         ,@nSKUCnt     = @nSKUCnt   OUTPUT  
         ,@bSuccess    = @bSuccess  OUTPUT  
         ,@nErr        = @nErrNo    OUTPUT  
         ,@cErrMsg     = @cErrMsg   OUTPUT  
  
      -- Check SKU  
      IF @nSKUCnt = 0  
      BEGIN  
         SET @nErrNo = 158809  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU 
         GOTO Step_3_Fail  
      END   
      
      -- Check barcode return multi SKU  
      IF @nSKUCnt > 1  
      BEGIN  
         SET @nErrNo = 158810  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod  
         GOTO Step_3_Fail  
      END  
  
      -- Get SKU  
      EXEC rdt.rdt_GetSKU  
          @cStorerKey  = @cStorerKey  
         ,@cSKU        = @cUPC      OUTPUT  
         ,@bSuccess    = @bSuccess  OUTPUT  
         ,@nErr        = @nErrNo    OUTPUT  
         ,@cErrMsg     = @cErrMsg   OUTPUT  
      IF @nErrNo <> 0  
         GOTO Step_3_Fail  
         
      SET @cSKU = @cUPC 
      
      IF NOT EXISTS (SELECT 1  FROM pickDetail WITH (NOLOCK) WHERE Storerkey = @cStorerKey AND PickSlipNo = @cPickslipNo AND sku = @cSKU)
      BEGIN
      	SET @nErrNo = 158811  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU  
         GOTO Step_3_Fail 
      END
      
            
      --SELECT @cFromLocType = locationType FROM loc WITH (NOLOCK) WHERE loc = @cFromLoc
      
      SELECT @cSKUDescr = Descr FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU 
      
      SELECT @nScanSkuQty = SUM(ScanQty) FROM rdt.RDTPickQCLog WITH (NOLOCK) WHERE Storerkey = @cStorerkey AND PickslipNo = @cPickslipNo AND MovedQty = 0 AND sku = @cSKU AND mobile = @nMobile
      
      SELECT @nPDSkuQty = SUM(Qty) FROM pickDetail WITH (NOLOCK) WHERE Storerkey = @cStorerKey AND PickSlipNo = @cPickslipNo AND sku = @cSKU
      
      SELECT @nScanSkuQty = ISNULL(@nScanSkuQty,0) + 1
      
      IF @nScanSkuQty > @nPDSkuQty
      BEGIN
      	SET @nErrNo = 158812  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- OverShortPick  
         GOTO Step_3_Fail 
      END
      
     
      INSERT INTO rdt.RDTPickQCLog ( storerKey, PickslipNo,SKU,ScanQty,MovedQty,ReasonCode,Mobile,AddWho)
      VALUES ( @cStorerkey,@cPickslipNo,@cSKU,1,0,@cReasonCode,@nMobile,@cUserName)
      
      Select @nScanQty = SUM(ScanQty) FROM rdt.RDTPickQCLog WITH (NOLOCK) WHERE Storerkey = @cStorerkey AND PickslipNo = @cPickslipNo AND MovedQty = 0
      
           
      SET @cOutField01 = @cPickslipNo 
      SET @cOutField02 = @cReasonCode  
      SET @cOutField03 = ''
      SET @cOutField04 = @cSKU
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
      SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 40)     
      SET @cOutField07 = CONVERT(NVARCHAR( 5), @nScanQty) + '/' + @cPickDetailQty  
         
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      SET @cOutField01 = ''  
        
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  
   GOTO Quit  
  
   Step_3_Fail:  
   BEGIN  
      SET @cOutField03 = ''
   END  
   
END  
GOTO Quit  
 
/********************************************************************************  
Step 4. screen = 5843  
   CONFIRM ?? (field01, input)  
********************************************************************************/  
Step_4:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      SET @cOption = @cInfield01  
  
      IF ISNULL(@cOption, '') = ''  
      BEGIN  
         SET @nErrNo = 158813  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Option Req  
         GOTO Step_4_Fail  
      END  
  
      IF @cOption NOT IN ('1', '2')  
      BEGIN  
         SET @nErrNo = 158814  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Option  
         GOTO Step_4_Fail  
      END  
      
      IF @cPickQCToLoc = '0' 
      BEGIN
      	SET @nErrNo = 158815  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need To Loc  
         GOTO Step_4_Fail
      END
      
      IF @cOption = '1'  
      BEGIN  
      	
      	EXEC RDT.rdt_PickQC_Confirm @nMobile, @nFunc, @cUserName, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey  
            ,@cPickSlipNo  
            ,@nErrNo       OUTPUT  
            ,@cErrMsg      OUTPUT  
            
         IF @nErrNo <> 0  
            GOTO Step_4_Fail  
            
      END   -- @cOption = '1'  
      ELSE
      BEGIN  --@cOption = '2'--cancel
      	DELETE rdt.RDTPickQCLog WHERE storerKey = @cStorerKey AND pickslipNo = @cPickslipNo AND movedQty = 0  AND mobile = @nMobile
      END
      
      --after confirm or option2 , back scn 2
      SET @cOutField01 = @cPickslipNo
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''  
           
      SET @nScn = @nScn - 2  
      SET @nStep = @nStep - 2
   END
   
   --IF @nInputKey = 0 -- ESC  
   --BEGIN 
   --   SET @cOutField01 = @cPickslipNo
   --   SET @cOutField02 = ''
   --   SET @cOutField03 = ''
   --   SET @cOutField04 = ''
   --   SET @cOutField05 = ''
   --   SET @cOutField06 = ''
   --   SET @cOutField07 = ''  
           
   --   SET @nScn = @nScn - 2  
   --   SET @nStep = @nStep - 2
   --END
   GOTO Quit 
        
   Step_4_Fail:  
   BEGIN  
      SET @cOutField01 = ''
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Quit. Update back to I/O table, ready to be pick up by JBOSS  
********************************************************************************/  
Quit:  
BEGIN  
   UPDATE RDTMOBREC WITH (ROWLOCK) SET  
       ErrMsg        = @cErrMsg,  
       Func          = @nFunc,  
       Step          = @nStep,  
       Scn           = @nScn,  
  
       StorerKey     = @cStorerKey,  
       Facility      = @cFacility,  
       Printer       = @cPrinter,  
       Printer_Paper = @cPrinter_Paper,  
       UserName      = @cUserName,  
  
       V_PickslipNo  = @cPickslipNo,
          
       V_String1     = @cPickConfirmStatus,  
       V_String2     = @cReasonCode,   
       V_String3     = @cPickDetailQty,   
       V_String4     = @cFromLoc,
       V_String5     = @cToLoc,   
       V_String6     = @cFromLocType,   
       V_String7     = @cPickQCToLoc,
       V_String8     = @cFromLot,
       
       V_Integer1    = @nScanQty,
 
         
      I_Field01 = @cInField01,  O_Field01 = @cOutField01,  
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,  
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,  
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,  
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,  
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,  
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,  
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,  
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,  
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,  
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,  
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,  
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,  
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,  
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,  
  
      FieldAttr01  = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,  
      FieldAttr03  = @cFieldAttr03,   FieldAttr04  = @cFieldAttr04,  
      FieldAttr05  = @cFieldAttr05,   FieldAttr06  = @cFieldAttr06,  
      FieldAttr07  = @cFieldAttr07,   FieldAttr08  = @cFieldAttr08,  
      FieldAttr09  = @cFieldAttr09,   FieldAttr10  = @cFieldAttr10,  
      FieldAttr11  = @cFieldAttr11,   FieldAttr12  = @cFieldAttr12,  
      FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,  
      FieldAttr15  = @cFieldAttr15  
  
   WHERE Mobile = @nMobile  
END  

GO