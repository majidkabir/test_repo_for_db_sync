SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/               
/* Copyright: LF                                                              */               
/* Purpose:                                                                   */               
/*                                                                            */               
/* Modifications log:                                                         */               
/*                                                                            */               
/* Date       Rev  Author     Purposes                                        */               
/* 2017-05-23 1.0  ChewKP     Created. WMS-1931                               */          
/* 2017-06-24 1.1  Shong      Change Report Type (Bartender)                  */            
/* 2018-11-13 1.2  TungGH     Performance                                     */            
/* 2019-08-29 1.3  James      WMS-10366 Add RDTFormat to Qty (james01)        */        
/* 2019-08-29 1.3  James      WMS-12137 Add child serialno validation(james02)*/       
/* 2020-05-04 1.4  YeeKung    WMS-13083 Add childserialno validation(yeekung01)*/     
/******************************************************************************/              
              
CREATE PROC [RDT].[rdtfnc_SerialNo_Serialize] (              
   @nMobile    int,              
   @nErrNo     int  OUTPUT,              
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max              
)              
AS              
   SET NOCOUNT ON              
   SET QUOTED_IDENTIFIER OFF              
   SET ANSI_NULLS OFF              
   SET CONCAT_NULL_YIELDS_NULL OFF              
              
-- Misc variable              
DECLARE               
   @nCount      INT,              
   @nRowCount   INT              
              
-- RDT.RDTMobRec variable              
DECLARE               
   @nFunc      INT,              
   @nScn       INT,              
   @nStep      INT,              
   @cLangCode  NVARCHAR( 3),              
   @nInputKey  INT,              
   @nMenu      INT,              
              
   @cStorerKey NVARCHAR( 15),              
   @cFacility  NVARCHAR( 5),               
   @cPrinter   NVARCHAR( 20),               
   @cUserName  NVARCHAR( 18),              
                 
   @nError            INT,              
   @b_success         INT,              
   @n_err             INT,                   
   @c_errmsg          NVARCHAR( 250),               
   @cPUOM             NVARCHAR( 10),                  
   @bSuccess          INT,              
   @cDataWindow       NVARCHAR( 50),          
   @cTargetDB         NVARCHAR( 20),         
   @cWorkOrderNo      NVARCHAR( 10),        
   @cFromSKUInput     NVARCHAR( 20),           
   @cToSKUInput       NVARCHAR( 20),           
   @cSerialNo         NVARCHAR( 20),        
   @nSKUCnt           INT,        
   @cFromSKU          NVARCHAR( 20),        
   @cToSKU            NVARCHAR( 20),         
   @cBatchKey         NVARCHAR( 10),        
   @n9LQty            INT,        
   @nInnerQty         INT,        
   @nMasterQty        INT,        
   @c9LNewLabel       NVARCHAR(1),        
   @cInnerNewLabel    NVARCHAR(1),        
   @cMasterNewLabel   NVARCHAR(1),        
   @n9LCount          INT,        
   @cToSerialNo       NVARCHAR(20),        
   @nInnerCount       INT,        
   @nMasterCount      INT,        
   @nRowRef           INT,        
   @cFromSerialNo     NVARCHAR(20),        
   @cParentSerialNo   NVARCHAR(20),        
   @cInnerSerialNo    NVARCHAR(20),        
   @cMasterSerialNo   NVARCHAR(20),         
   @nMasterSerialNoKey INT,        
   @cSKU              NVARCHAR(20),        
   @cSKUInput         NVARCHAR(20),        
   @c9LSerialNo       NVARCHAR(20),        
   @cRemarks          NVARCHAR(20),        
   @cGenSerialSP      NVARCHAR(30),        
   @cSQL              NVARCHAR(1000),         
   @cSQLParam         NVARCHAR(1000),         
   @cPrinter9L        NVARCHAR( 20),              
   @cPrinterInner     NVARCHAR( 20),              
   @cPrinterMaster    NVARCHAR( 20),              
   @cPrinterGTIN      NVARCHAR( 20),        
   @cStatus           NVARCHAR( 10),        
   @cLocationCode     NVARCHAR( 10),        
   @nMasterUnitQty    INT,        
   @cOption           NVARCHAR(1),        
   --@nMasterQty        INT,        
   @cGenerateLabel    NVARCHAR(1),        
   @cWorkOrderSKU     NVARCHAR(20),        
   @cPackKey          NVARCHAR(10),        
   @nInnerPack        INT,        
   @nCaseCnt          INT,        
   @cSerialType       NVARCHAR(1),        
   @cChildSerialNo    NVARCHAR(20),        
   @cPassed           NVARCHAR(1),        
   @nScanCount        INT,        
   @nCLabelQty        INT,        
   @cExtendedUpdateSP NVARCHAR(30),         
   @nFromFunc         INT,        
   @cInvalidSerialNo01 NVARCHAR(20),        
   @cInvalidSerialNo02 NVARCHAR(20),        
   @cInvalidSerialNo03 NVARCHAR(20),        
   @nErrorCount        INT,        
   @nFromScn           INT,        
   @nFromStep          INT,        
   @cInnerSKU          NVARCHAR(20),        
   @cMasterSKU         NVARCHAR(20),         
   @cSerialNoCode      NVARCHAR(2),        
        
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),            
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),            
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),            
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),            
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),            
                    
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
   @cFieldAttr15 NVARCHAR( 1)              
                 
-- Load RDT.RDTMobRec              
SELECT               
   @nFunc      = Func,              
   @nScn       = Scn,              
   @nStep      = Step,              
   @nInputKey  = InputKey,              
   @nMenu      = Menu,              
   @cLangCode  = Lang_code,              
              
   @cStorerKey = StorerKey,              
   @cFacility  = Facility,              
   @cPrinter   = Printer,               
   @cUserName  = UserName,              
   --@cLightMode  = LightMode,          
   @cSKU       = V_SKU,          
   --@cSKUDescr   = V_SKUDescr,          
           
   --@cLot        = V_Lot,          
   @cPUOM     = V_UOM,             
           
                 
   @cWorkOrderNo        = V_String1,            
   @cOption             = V_String2,        
   --@n9LQty              = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3, 5), 0) = 1 THEN LEFT( V_String3, 5) ELSE 0 END,          
   --@nInnerQty           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4, 5), 0) = 1 THEN LEFT( V_String4, 5) ELSE 0 END,          
   --@nMasterQty          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5, 5), 0) = 1 THEN LEFT( V_String5, 5) ELSE 0 END,          
   --@nTotalMasterQty     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6, 5), 0) = 1 THEN LEFT( V_String6, 5) ELSE 0 END,          
   @cGenSerialSP        = V_String6,        
   @cBatchKey           = V_String7,        
   @cExtendedUpdateSP   = V_String8,        
   @cInvalidSerialNo01  = V_String9,        
   @cInvalidSerialNo02  = V_String10,        
   @cInvalidSerialNo03  = V_String11,        
   --@nErrorCount         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String12, 5), 0) = 1 THEN LEFT( V_String12, 5) ELSE 0 END,          
   --@nFromScn            = V_String13,        
   --@nFromStep           = V_String14,        
   --@nCaseCnt   = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String15, 5), 0) = 1 THEN LEFT( V_String15, 5) ELSE 0 END,        
        
   @n9LQty              = V_Integer1,          
   @nInnerQty           = V_Integer2,          
   @nMasterQty          = V_Integer3,          
   @nErrorCount         = V_Integer4,        
   @nCaseCnt            = V_Integer5,        
   @nFromScn            = V_FromScn,        
   @nFromStep           = V_FromStep,        
                       
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
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04  = FieldAttr04,              
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,              
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,              
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,              
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,              
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,              
   @cFieldAttr15 =  FieldAttr15              
              
FROM RDTMOBREC (NOLOCK)              
WHERE Mobile = @nMobile              
              
Declare @n_debug INT              
              
SET @n_debug = 0              
              
              
IF @nFunc IN ( 1010, 1013 )   -- Serial No Serialize        
BEGIN              
                 
   -- Redirect to respective screen              
   IF @nStep = 0 GOTO Step_0   -- Serial No SKU Change          
   IF @nStep = 1 GOTO Step_1   -- Scn = 4890. WorkOrderNo, Option        
   IF @nStep = 2 GOTO Step_2   -- Scn = 4891. SKU, Qty         
   IF @nStep = 3 GOTO Step_3   -- Scn = 4892. SKU, Child SerialNo         
   IF @nStep = 4 GOTO Step_4   -- Scn = 4893. SKU, Parent SerialNo         
   IF @nStep = 5 GOTO Step_5   -- Scn = 4894. SKU, Parent SerialNo         
   IF @nStep = 6 GOTO Step_6   -- Scn = 4895. SKU, Option 1 = Continue , 9 = Close Carton        
                 
END              
              
              
RETURN -- Do nothing if incorrect step              
              
/********************************************************************************              
Step 0. func = 1010. Menu              
********************************************************************************/              
Step_0:              
BEGIN              
   -- Get prefer UOM              
   SET @cPUOM = ''              
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA              
   FROM RDT.rdtMobRec M WITH (NOLOCK)              
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)              
   WHERE M.Mobile = @nMobile              
               
           
   SET @cGenSerialSP = ''          
   SET @cGenSerialSP = rdt.RDTGetConfig( @nFunc, 'GenSerialSP', @cStorerKey)          
   IF @cGenSerialSP = '0'            
   BEGIN          
      SET @cGenSerialSP = ''          
   END           
           
           
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)        
   IF @cExtendedUpdateSP = '0'        
      SET @cExtendedUpdateSP = ''        
              
        
              
   -- Initiate var              
   -- EventLog - Sign In Function              
   EXEC RDT.rdt_STD_EventLog              
     @cActionType = '1', -- Sign in function              
     @cUserID     = @cUserName,              
     @nMobileNo   = @nMobile,              
     @nFunctionID = @nFunc,              
     @cFacility   = @cFacility,              
     @cStorerKey  = @cStorerkey,        
     @nStep       = @nStep                    
                   
           
   SET @cWorkOrderNo = ''        
   SET @cOption      = ''        
   SET @nFromStep = 0        
   SET @nFromScn  = 0        
           
   SET @cInvalidSerialNo01 = ''        
   SET @cInvalidSerialNo02 = ''        
   SET @cInvalidSerialNo03 = ''        
        
   -- Init screen              
   SET @cOutField01 = ''               
   SET @cOutField02 = ''              
              
   -- Set the entry point              
   SET @nScn = 4890              
   SET @nStep = 1              
                 
   EXEC rdt.rdtSetFocusField @nMobile, 1              
                 
END              
GOTO Quit              
              
              
/********************************************************************************              
Step 1. Scn = 4890.              
   WorkOrderNo     (field01 , input)              
             
            
********************************************************************************/              
Step_1:              
BEGIN              
   IF @nInputKey = 1 --ENTER              
   BEGIN              
                    
      SET @cWorkOrderNo = ISNULL(RTRIM(@cInField01),'')              
      SET @cOption      = ISNULL(RTRIM(@cInField02),'')              
                  
      IF @cWorkOrderNo = ''        
      BEGIN        
         SET @nErrNo = 109801              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WorkOrdeRNoReq            
         SET @cWorkOrderNo = ''        
         EXEC rdt.rdtSetFocusField @nMobile, 1        
         GOTO Step_1_Fail          
      END        
              
              
      IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrder WITH (NOLOCK)          
                      WHERE StorerKey = @cStorerKey          
                      AND Facility = @cFacility          
                      AND WorkOrderKey = @cWorkOrderNo )           
      BEGIN          
         SET @nErrNo = 109802              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvdWorkOrder        
         SET @cWorkOrderNo = ''        
         EXEC rdt.rdtSetFocusField @nMobile, 1        
         GOTO Step_1_Fail              
      END            
              
      IF ISNULL(@cOption,'' )  = ''         
      BEGIN        
         SET @nErrNo = 109803              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionReq        
         SET @cOption = ''        
         EXEC rdt.rdtSetFocusField @nMobile, 2        
         GOTO Step_1_Fail              
      END        
              
      IF @cOption NOT IN ('1','2' )         
      BEGIN        
         SET @nErrNo = 109804              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidOption        
         SET @cOption = ''        
         EXEC rdt.rdtSetFocusField @nMobile, 2        
         GOTO Step_1_Fail              
      END        
              
      IF @cOption = '1'         
      BEGIN        
         -- Prepare Next Screen Variable              
         --SET @cOutField01 = @cPTSZone            
         SET @cOutField01 = ''          
         SET @cOutField02 = ''        
                 
         -- GOTO Next Screen              
         SET @nScn = @nScn + 1              
         SET @nStep = @nStep + 1             
                        
                 
         EXEC rdt.rdtSetFocusField @nMobile, 1        
      END        
      ELSE IF @cOption = '2'         
      BEGIN        
         SET @cSKU = ''        
         SET @cChildSerialNo = ''        
                 
         -- Prepare Next Screen Variable              
         --SET @cOutField01 = @cPTSZone            
         SET @cOutField01 = ''          
         SET @cOutField02 = ''        
         SET @cOutField03 = ''        
                 
         SET @nErrorCount = 1        
         SET @cInvalidSerialNo01 = ''        
         SET @cInvalidSerialNo02 = ''        
         SET @cInvalidSerialNo03 = ''        
                 
         SET @cOutField04 = ''        
         SET @cOutField05 = ''        
         SET @cOutField06 = ''        
                 
         -- GOTO Next Screen              
         SET @nScn = @nScn + 2              
         SET @nStep = @nStep + 2             
                 
         EXEC rdt.rdtSetFocusField @nMobile, 1        
      END        
            
                
                    
   END  -- Inputkey = 1              
              
   IF @nInputKey = 0             
   BEGIN              
                      
--    -- EventLog - Sign In Function              
      EXEC RDT.rdt_STD_EventLog              
        @cActionType = '9', -- Sign in function              
        @cUserID     = @cUserName,              
        @nMobileNo   = @nMobile,              
        @nFunctionID = @nFunc,              
        @cFacility   = @cFacility,              
        @cStorerKey  = @cStorerkey,        
        @nStep       = @nStep                    
                  
      --go to main menu              
      SET @nFunc = @nMenu              
      SET @nScn  = @nMenu              
      SET @nStep = 0              
      SET @cOutField01 = ''              
          
   END              
   GOTO Quit              
              
   STEP_1_FAIL:              
   BEGIN              
      -- Prepare Next Screen Variable              
      SET @cOutField01 = @cWorkOrderNo        
      SET @cOutField02 = @cOption        
             
   END              
END               
GOTO QUIT              
              
              
/********************************************************************************              
Step 2. Scn = 4891.               
               
   SKU        (field01, input)              
   Quantity   (field02, input)              
          
                 
********************************************************************************/              
Step_2:              
BEGIN              
   IF @nInputKey = 1              
   BEGIN              
      SET @cSKUInput    = ISNULL(RTRIM(@cInField01),'')              
      SET @nMasterQty   = ISNULL(RTRIM(@cInField02),'')           
              
      --SET @cSKUInput = '001172-0000'        
      --SET @nMasterQty = 2         
                   
      IF @cSKUInput = ''              
      BEGIN              
     SET @nErrNo = 109805              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKUReq'        
         SET @cSKU = ''         
         EXEC rdt.rdtSetFocusField @nMobile, 1        
         GOTO Step_2_Fail            
      END              
              
      -- Get SKU barcode count            
      --DECLARE @nSKUCnt INT            
      EXEC rdt.rdt_GETSKUCNT            
          @cStorerKey  = @cStorerKey            
         ,@cSKU        = @cSKUInput            
         ,@nSKUCnt     = @nSKUCnt       OUTPUT            
         ,@bSuccess    = @b_Success     OUTPUT            
         ,@nErr        = @nErrNo        OUTPUT            
         ,@cErrMsg     = @cErrMsg       OUTPUT            
              
      -- Check SKU/UPC            
      IF @nSKUCnt = 0            
      BEGIN            
         SET @nErrNo = 109806            
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU          
         SET @cSKU = ''         
         EXEC rdt.rdtSetFocusField @nMobile, 1          
         GOTO Step_2_Fail            
      END            
              
      -- Check multi SKU barcode            
      IF @nSKUCnt > 1            
      BEGIN            
         SET @nErrNo = 109807         
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod            
         SET @cSKU = ''         
         EXEC rdt.rdtSetFocusField @nMobile, 1        
         GOTO Step_2_Fail            
      END            
              
      -- Get SKU code            
      EXEC rdt.rdt_GETSKU            
          @cStorerKey  = @cStorerKey            
         ,@cSKU        = @cSKUInput     OUTPUT            
         ,@bSuccess    = @b_Success     OUTPUT            
         ,@nErr        = @nErrNo        OUTPUT            
         ,@cErrMsg     = @cErrMsg       OUTPUT            
              
      IF @nErrNo = 0         
      BEGIN        
         SET @cSKU = @cSKUInput        
      END        
              
      SELECT         
                     
            @cWorkOrderSKU  = ISNULL(WKORDUDef3 ,'')        
      FROM dbo.WorkOrder WITH (NOLOCK)         
      WHERE StorerKey = @cStorerKey        
      AND WorkOrderKey = @cWorkOrderNo         
              
      SELECT @c9LNewLabel = WKORDUDEF1         
      FROM dbo.WorkOrderDetail WITH (NOLOCK)         
      WHERE WorkOrderKey = @cWorkOrderNo        
      AND Type = 'REWORK'        
      AND Unit = '9L'        
        
              
      SELECT @cInnerNewLabel = WKORDUDEF1         
      FROM dbo.WorkOrderDetail WITH (NOLOCK)         
      WHERE WorkOrderKey = @cWorkOrderNo        
      AND Type = 'REWORK'        
      AND Unit = 'Inner'        
              
      SELECT @cMasterNewLabel = WKORDUDEF1         
      FROM dbo.WorkOrderDetail WITH (NOLOCK)         
      WHERE WorkOrderKey = @cWorkOrderNo        
      AND Type = 'REWORK'        
      AND Unit = 'Master'        
                    
              
      IF @cSKU <> @cWorkOrderSKU        
      BEGIN        
         SET @nErrNo = 109810        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU            
         SET @cSKU = ''         
         EXEC rdt.rdtSetFocusField @nMobile, 1        
         GOTO Step_2_Fail          
      END        
              
              
      --IF @nMasterQty = ''        
      --BEGIN        
      --   SET @nErrNo = 109808        
      --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QtyReq'        
      --   SET @nMasterQty = 0         
      --   EXEC rdt.rdtSetFocusField @nMobile, 2        
      --   GOTO Step_2_Fail        
      --END        
        
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'QTY', @cInField02) = 0        
      BEGIN        
         SET @nErrNo = 142153        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty        
         SET @nMasterQty = 0         
         EXEC rdt.rdtSetFocusField @nMobile, 2     
         GOTO Step_2_Fail        
      END        
        
      IF RDT.rdtIsValidQTY( @nMasterQty, 1) = 0        
      BEGIN        
         SET @nErrNo = 109809        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'        
         SET @nMasterQty = 0         
         EXEC rdt.rdtSetFocusField @nMobile, 2        
         GOTO Step_2_Fail        
      END        
              
       -- Generating Label        
              
      SELECT @cPrinter9L = UDF01         
            ,@cPrinterInner = UDF02         
            ,@cPrinterMaster = UDF03        
            ,@cPrinterGTIN = UDF04        
      FROM dbo.CodeLkup WITH (NOLOCK)         
      WHERE ListName = 'SERIALPRN'        
      AND StorerKey = @cStorerKey        
      AND Code = @cUserName         
              
      SELECT @cPackKey = PackKey        
      FROM dbo.SKU WITH (NOLOCK)         
      WHERE StorerKey = @cStorerKey        
      AND SKU         = @cSKU        
              
      SELECT @nInnerPack = ISNULL(InnerPack,0)         
            ,@nCaseCnt  = ISNULL(CaseCnt,0)         
      FROM dbo.Pack WITH (NOLOCK)         
      WHERE PackKey = @cPackKey         
        
      SET @n9LQty     = 0         
      SET @nInnerQty  = 0         
              
              
      SET @n9LQty = @nMasterQty * @nCaseCnt        
              
      IF @nInnerPack > 0         
      BEGIN        
          SET @nInnerQty  = @nMasterQty * ( @nCaseCnt / @nInnerPack )         
      END         
              
              
      --IF @c9LNewLabel = '1'         
      BEGIN        
         -- Print 9L         
         SET @nCount = 1         
         WHILE @nCount <= @n9LQty        
         BEGIN        
                   
                 
            SET @c9LSerialNo = ''        
                    
            IF @cGenSerialSP <> ''          
            BEGIN          
                 IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenSerialSP AND type = 'P')          
                 BEGIN          
                               
                 
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cGenSerialSP) +          
                                 ' @nMobile ,@nFunc ,@cLangCode ,@nStep ,@nInputKey ,@cStorerkey ,@cFromSKU ,@cToSKU ,@cSerialNo ,@cSerialType ,@cWorkOrderKey ,@cBatchKey ,@cNewSerialNo OUTPUT ,@nErrNo OUTPUT ,@cErrMsg OUTPUT'          
                     SET @cSQLParam =          
                        ' @nMobile                   INT,                     '+        
                        ' @nFunc                     INT,                   '+        
                        ' @cLangCode            NVARCHAR( 3),            '+        
                        ' @nStep                     INT,                     '+        
                        ' @nInputKey                 INT,                     '+        
                        ' @cStorerkey                NVARCHAR( 15),           '+        
                        ' @cFromSKU                  NVARCHAR( 20),           '+        
                        ' @cToSKU                    NVARCHAR( 20),           '+        
                        ' @cSerialNo                 NVARCHAR( 20),           '+        
                        ' @cSerialType               NVARCHAR( 10),           '+        
                        ' @cWorkOrderKey             NVARCHAR( 10),           '+        
                        ' @cBatchKey                 NVARCHAR( 10),           '+        
                        ' @cNewSerialNo              NVARCHAR( 20) OUTPUT,    '+        
                        ' @nErrNo                    INT           OUTPUT,    '+        
                        ' @cErrMsg                   NVARCHAR( 20) OUTPUT     '        
                                
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,          
                        @nMobile ,@nFunc ,@cLangCode ,@nStep ,@nInputKey ,@cStorerkey ,@cFromSKU ,@cToSKU ,@cSerialNo ,'EACHES' ,@cWorkOrderNo ,@cBatchKey ,@c9LSerialNo OUTPUT,@nErrNo OUTPUT ,@cErrMsg OUTPUT        
                      
                             
                 
                     IF @nErrNo <> 0           
                     BEGIN          
                        SET @nErrNo = 109811            
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenSerialNoFail'            
                        SET @cSerialNo = ''        
                        EXEC rdt.rdtSetFocusField @nMobile, 3           
                        GOTO Step_2_Fail        
                     END          
                 END          
            END         
                    
            SELECT @cDataWindow = DataWindow,             
             @cTargetDB = TargetDB             
         FROM rdt.rdtReport WITH (NOLOCK)             
         WHERE StorerKey = @cStorerKey            
         AND   ReportType = 'LOG9LLABEL'           
                 
         -- Bartender No Datawindow Required (SHONG)        
         --IF ISNULL(@cDataWindow,'')  <> ''          
         BEGIN        
           EXEC RDT.rdt_BuiltPrintJob              
                        @nMobile,              
                        @cStorerKey,              
                        'LOG9LLABEL',  -- ReportType              
                        'Serial9L',    -- PrintJobName              
                        @cDataWindow,              
                        @cPrinter9L,              
                        @cTargetDB,              
                        @cLangCode,              
                        @nErrNo  OUTPUT,              
                        @cErrMsg OUTPUT,         
                        @c9LSerialNo         
                                
         END        
                    
            SET @nCount = @nCount + 1         
         END        
      END        
              
      --IF @cInnerNewLabel = '1'         
      BEGIN        
         -- Print Inner         
         IF @nInnerPack > 0         
         BEGIN        
            SET @nCount = 1         
            WHILE @nCount <= @nInnerQty        
            BEGIN        
               SET @cInnerSerialNo = ''        
               IF @cGenSerialSP <> ''          
               BEGIN          
                         
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenSerialSP AND type = 'P')          
                  BEGIN          
                               
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cGenSerialSP) +          
                     ' @nMobile ,@nFunc ,@cLangCode ,@nStep ,@nInputKey ,@cStorerkey ,@cFromSKU ,@cToSKU ,@cSerialNo ,@cSerialType ,@cWorkOrderKey ,@cBatchKey ,@cNewSerialNo OUTPUT ,@nErrNo OUTPUT ,@cErrMsg OUTPUT'          
                     SET @cSQLParam =          
                        ' @nMobile                   INT,                     '+                              
                        ' @nFunc                     INT,                     '+        
                        ' @cLangCode                 NVARCHAR( 3),            '+        
                        ' @nStep                     INT,                     '+        
                        ' @nInputKey                 INT,                     '+        
                        ' @cStorerkey                NVARCHAR( 15),           '+        
                        ' @cFromSKU                  NVARCHAR( 20),           '+        
                        ' @cToSKU                    NVARCHAR( 20),           '+        
                        ' @cSerialNo                 NVARCHAR( 20),           '+        
                        ' @cSerialType               NVARCHAR( 10),           '+        
                        ' @cWorkOrderKey             NVARCHAR( 10),           '+        
                        ' @cBatchKey                 NVARCHAR( 10),           '+        
                        ' @cNewSerialNo              NVARCHAR( 20) OUTPUT,    '+        
                        ' @nErrNo                    INT           OUTPUT,    '+        
                        ' @cErrMsg                   NVARCHAR( 20) OUTPUT     '        
                                
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,          
                        @nMobile ,@nFunc ,@cLangCode ,@nStep ,@nInputKey ,@cStorerkey ,@cFromSKU ,@cToSKU ,@cSerialNo ,'INNER' ,@cWorkOrderNo ,@cBatchKey ,@cInnerSerialNo OUTPUT,@nErrNo OUTPUT ,@cErrMsg OUTPUT        
                         
          
                 
                     IF @nErrNo <> 0           
                     BEGIN          
                        SET @nErrNo = 109812            
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenSerialNoFail'            
                        SET @cSerialNo = ''        
                        EXEC rdt.rdtSetFocusField @nMobile, 3           
                        GOTO Step_2_Fail        
                     END          
                  END          
                         
               END         
                       
               -- Print LabelNo         
               SELECT   @cDataWindow = DataWindow,             
                        @cTargetDB = TargetDB             
               FROM rdt.rdtReport WITH (NOLOCK)             
               WHERE StorerKey = @cStorerKey            
               AND   ReportType = 'LOGMASTLBL'           
                   
           -- Bartender No Datawindow Required (SHONG)        
           --IF ISNULL(@cDataWindow,'')  <> ''         
           BEGIN        
            EXEC RDT.rdt_BuiltPrintJob              
                         @nMobile,              
                         @cStorerKey,              
                         'LOGMASTLBL',    -- ReportType              
                         'SerialInnner',    -- PrintJobName              
                         @cDataWindow,              
                         @cPrinterInner,              
                         @cTargetDB,              
                         @cLangCode,              
                         @nErrNo  OUTPUT,              
                         @cErrMsg OUTPUT,         
                         @cStorerKey,        
                         @cSKU,           
                         @cWorkOrderNo,        
                         @nInnerPack,        
                         @cInnerSerialNo        
           END        
               SET @nCount = @nCount + 1         
            END        
         END        
      END        
              
      --IF @cMasterNewLabel = '1'         
      BEGIN        
         -- Print Master Label        
         SET @nCount = 1         
         WHILE @nCount <= @nMasterQty        
         BEGIN        
            SET @cMasterSerialNo = ''        
            IF @cGenSerialSP <> ''          
            BEGIN          
                          
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenSerialSP AND type = 'P')          
                  BEGIN          
                               
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cGenSerialSP) +          
                     ' @nMobile ,@nFunc ,@cLangCode ,@nStep ,@nInputKey ,@cStorerkey ,@cFromSKU ,@cToSKU ,@cSerialNo ,@cSerialType ,@cWorkOrderKey ,@cBatchKey ,@cNewSerialNo OUTPUT ,@nErrNo OUTPUT ,@cErrMsg OUTPUT'          
                     SET @cSQLParam =          
                        ' @nMobile                   INT,                     '+        
                        ' @nFunc                     INT,                     '+        
                        ' @cLangCode                 NVARCHAR( 3),            '+        
                        ' @nStep                     INT,                     '+        
                        ' @nInputKey                 INT,     '+        
                        ' @cStorerkey                NVARCHAR( 15),           '+        
                        ' @cFromSKU                  NVARCHAR( 20),        '+        
                        ' @cToSKU                    NVARCHAR( 20),           '+        
                        ' @cSerialNo                 NVARCHAR( 20),           '+        
                        ' @cSerialType               NVARCHAR( 10),           '+        
                        ' @cWorkOrderKey             NVARCHAR( 10),           '+        
                        ' @cBatchKey                 NVARCHAR( 10),           '+        
                        ' @cNewSerialNo              NVARCHAR( 20) OUTPUT,    '+        
                        ' @nErrNo                    INT           OUTPUT,    '+        
                        ' @cErrMsg                   NVARCHAR( 20) OUTPUT     '        
                                
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,          
                        @nMobile ,@nFunc ,@cLangCode ,@nStep ,@nInputKey ,@cStorerkey ,@cFromSKU ,@cToSKU ,@cSerialNo ,'MASTER' ,@cWorkOrderNo ,@cBatchKey ,@cMasterSerialNo OUTPUT, @nErrNo OUTPUT ,@cErrMsg OUTPUT        
                      
                             
                 
                     IF @nErrNo <> 0           
                     BEGIN          
                        SET @nErrNo = 109813            
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenSerialNoFail'            
                        SET @cSerialNo = ''        
                        EXEC rdt.rdtSetFocusField @nMobile, 3           
                        GOTO Step_2_Fail        
                     END          
                 END          
            END         
                    
            -- Print LabelNo         
          SELECT @cDataWindow = DataWindow,             
             @cTargetDB = TargetDB             
         FROM rdt.rdtReport WITH (NOLOCK)             
         WHERE StorerKey = @cStorerKey            
         AND   ReportType = 'LOGMASTLBL'           
                 
         -- Bartender No Datawindow Required (SHONG)         
         --IF ISNULL(@cDataWindow,'')  <> ''         
         BEGIN        
           EXEC RDT.rdt_BuiltPrintJob              
                        @nMobile,              
                        @cStorerKey,              
                        'LOGMASTLBL',    -- ReportType              
                        'SerialMaster',    -- PrintJobName              
                        @cDataWindow,              
                        @cPrinterMaster,              
                        @cTargetDB,              
                        @cLangCode,              
                        @nErrNo  OUTPUT,              
                        @cErrMsg OUTPUT,         
                        @cStorerKey,        
                       @cSKU,           
                       @cWorkOrderNo,        
                       @nCaseCnt,        
                       @cMasterSerialNo        
         END        
                    
            SET @nCount = @nCount + 1         
         END        
      END        
                    
                    
   END  -- Inputkey = 1              
                 
   IF @nInputKey = 0               
   BEGIN              
       -- Prepare Previous Screen Variable              
       SET @cOutField01 = ''           
                        
       -- GOTO Previous Screen              
       SET @nScn = @nScn - 1              
       SET @nStep = @nStep - 1              
                     
       EXEC rdt.rdtSetFocusField @nMobile, 1          
   END              
   GOTO Quit              
                 
   Step_2_Fail:              
   BEGIN              
                    
      -- Prepare Next Screen Variable              
              
      SET @cOutField01 = @cSKU           
      SET @cOutField02 = @nMasterQty           
              
                    
   END              
              
END               
GOTO QUIT              
              
/********************************************************************************      
Step 3. Scn = 4892.               
               
   SKU            (field01, input)              
   Child SerialNo (field02, input)              
          
                 
********************************************************************************/              
Step_3:              
BEGIN              
   IF @nInputKey = 1              
   BEGIN              
      SET @cSKUInput        = ISNULL(RTRIM(@cInField01),'')              
      SET @cChildSerialNo   = ISNULL(RTRIM(@cInField02),'')           
              
      --SET @cSKUInput = '001172-0000'        
      --SET @cChildSerialNo = '1725FSAP2859'         
        
              
--      1725FSAP2879   1729FSAP291C   1729FSAP293M        
--      1725FSAP2869           
--      1725FSAP2859   1729FSAP290C        
--      1725FSAP2849        
--      1725FSAP2839   1729FSAP289C   1729FSAP292M        
--      1725FSAP2829           
--      1725FSAP2819   1729FSAP288C        
--      1725FSAP2809        
                   
      IF @cSKUInput = ''              
      BEGIN              
         SET @nErrNo = 109814              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKUReq'        
         SET @cSKU = ''         
         EXEC rdt.rdtSetFocusField @nMobile, 1        
         GOTO Step_3_Fail            
      END              
              
      -- Get SKU barcode count            
      --DECLARE @nSKUCnt INT            
      EXEC rdt.rdt_GETSKUCNT            
          @cStorerKey  = @cStorerKey            
         ,@cSKU        = @cSKUInput            
         ,@nSKUCnt     = @nSKUCnt       OUTPUT            
         ,@bSuccess    = @b_Success     OUTPUT            
         ,@nErr        = @nErrNo       OUTPUT            
         ,@cErrMsg     = @cErrMsg       OUTPUT            
              
      -- Check SKU/UPC            
      IF @nSKUCnt = 0            
      BEGIN            
         SET @nErrNo = 109815            
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU          
         SET @cSKU = ''         
         EXEC rdt.rdtSetFocusField @nMobile, 1          
         GOTO Step_3_Fail            
      END            
              
      -- Check multi SKU barcode            
      IF @nSKUCnt > 1            
      BEGIN            
         SET @nErrNo = 109816         
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod            
         SET @cSKU = ''         
         EXEC rdt.rdtSetFocusField @nMobile, 1        
         GOTO Step_3_Fail            
      END            
              
      -- Get SKU code            
      EXEC rdt.rdt_GETSKU            
          @cStorerKey  = @cStorerKey            
         ,@cSKU        = @cSKUInput     OUTPUT            
         ,@bSuccess    = @b_Success     OUTPUT            
         ,@nErr        = @nErrNo        OUTPUT            
         ,@cErrMsg     = @cErrMsg       OUTPUT            
              
      IF @nErrNo = 0         
      BEGIN        
         SET @cSKU = @cSKUInput        
      END        
              
      SELECT         
             @cWorkOrderSKU  = ISNULL(WKORDUDef3 ,'')        
      FROM dbo.WorkOrder WITH (NOLOCK)         
      WHERE StorerKey = @cStorerKey        
      AND WorkOrderKey = @cWorkOrderNo         
              
      SELECT TOP 1 @cGenerateLabel = ISNULL(WKORDUDef1,'')         
      FROM dbo.WorkOrderDetail WITH (NOLOCK)         
      WHERE WorkOrderKey = @cWorkOrderNo         
              
      SELECT         
             @nMasterQty     = ISNULL(Qty,0 )         
      FROM dbo.WorkOrderDetail WITH (NOLOCK)         
      WHERE StorerKey  = @cStorerKey        
      AND WorkOrderKey = @cWorkOrderNo        
      AND Unit         = 'Master'        
                 
              
      IF @cSKU <> @cWorkOrderSKU        
      BEGIN        
         SET @nErrNo = 109817        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU            
         SET @cSKU = ''         
    EXEC rdt.rdtSetFocusField @nMobile, 1       
         GOTO Step_3_Fail          
      END        
              
      SET @cPackKey = ''        
      SELECT @cPackKey = PackKey        
      FROM dbo.SKU WITH (NOLOCK)         
      WHERE StorerKey = @cStorerKey        
      AND SKU         = @cSKU        
              
      SELECT @nInnerPack = ISNULL(InnerPack,0)         
            ,@nCaseCnt  = ISNULL(CaseCnt,0)         
      FROM dbo.Pack WITH (NOLOCK)         
      WHERE PackKey = @cPackKey         
              
      SET @n9LQty     = 0         
      SET @nInnerQty  = 0            
      SET @cPassed    = ''           
              
      --SET @n9LQty = @nMasterQty * @nCaseCnt        
              
      IF @nInnerPack > 0         
      BEGIN        
          SET @nInnerQty  = @nInnerPack -- @nMasterQty * ( @nCaseCnt / @nInnerPack )         
      END         
              
      IF EXISTS ( SELECT 1 FROM rdt.rdtSerialNoLog WITH (NOLOCK)         
                  WHERE StorerKey = @cStorerKey        
                  AND Status <> '9'         
                  AND FromSKU = @cSKU        
                  AND SourceKey = @cWorkOrderNo        
                  AND Func = @nFunc         
                  AND AddWho = @cUserName )         
      BEGIN        
         SELECT TOP 1 @cBatchKey = BatchKey         
         FROM rdt.rdtSerialNoLog WITH (NOLOCK)         
         WHERE StorerKey = @cStorerKey        
         AND Status <> '9'         
         AND FromSKU = @cSKU        
         AND SourceKey = @cWorkOrderNo        
         AND Func = @nFunc         
         AND AddWho = @cUserName         
      END               
      ELSE        
      BEGIN        
                 
         --GetKey         
         EXECUTE dbo.nspg_GetKey        
                  'rdtSerial',        
                  10 ,        
                  @cBatchKey         OUTPUT,        
                  @bSuccess          OUTPUT,        
                  @nErrNo            OUTPUT,        
                  @cErrMsg           OUTPUT        
                          
         IF @bSuccess <> 1        
         BEGIN     
            SET @nErrNo = 109818        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetKeyFail        
            GOTO Step_3_Fail        
         END        
                 
      END           
              
              
      IF ISNULL(@cChildSerialNo,'')  <> ''         
      BEGIN         
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'SERIALNO', @cChildSerialNo) = 0        
         BEGIN        
               SET @nErrNo = 109850        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialNo        
               --SET @cChildSerialNo = ''         
               EXEC rdt.rdtSetFocusField @nMobile, 2        
               GOTO Step_3_Fail        
         END        
              
         SET @cSerialType = RIGHT ( @cChildSerialNo , 1 )         
              
         IF @cSerialType NOT IN ( '9' )         
         BEGIN        
            SET @nErrNo = 109820        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialType        
            --SET @cChildSerialNo = ''         
            EXEC rdt.rdtSetFocusField @nMobile, 2        
            GOTO Step_3_Fail        
         END        
                 
         IF LEN(@cChildSerialNo) <> 12         
         BEGIN        
            SET @nErrNo = 109838        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialNo        
            --SET @cChildSerialNo = ''         
            EXEC rdt.rdtSetFocusField @nMobile, 2        
            GOTO Step_3_Fail        
         END        
      
         -- (james02)      
         IF @nFunc = 1013      
         BEGIN      
            IF NOT EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)      
                            WHERE SerialNo = @cChildSerialNo        
                            AND   StorerKey = @cStorerKey)      
            BEGIN        
               SET @nErrNo = 142154        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SerialNotExist        
               EXEC rdt.rdtSetFocusField @nMobile, 2        
               GOTO Step_3_Fail        
            END        
         END      
    
         --(yeekung01)    
         IF @nFunc = 1010      
         BEGIN      
            IF NOT EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)      
                            WHERE SerialNo = @cChildSerialNo        
                            AND   StorerKey = @cStorerKey) AND  SUBSTRING(@cChildSerialNo,5,2) NOT IN ('FB', 'FN','FS','FL')    
            BEGIN        
               SET @nErrNo = 142155        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SerialNotExist        
               EXEC rdt.rdtSetFocusField @nMobile, 2        
               GOTO Step_3_Fail        
            END        
         END      
      END        
--      IF @nInnerQty = 0 AND @cSerialType = 'C'        
--      BEGIN        
--         SET @nErrNo = 109824        
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialType        
--         GOTO Step_3_Fail        
--      END        
                    
      IF @cSerialType = '9'        
      BEGIN         
         IF @nFunc = 1010        
         BEGIN        
            IF EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)         
                            WHERE SKU = @cSKU        
                            AND SerialNo = @cChildSerialNo        
                            AND StorerKey = @cStorerKey  )         
            BEGIN        
               SET @nErrNo = 109825            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialNo            
               --SET @cChildSerialNo = ''        
               EXEC rdt.rdtSetFocusField @nMobile, 2         
               GOTO Step_3_Fail            
            END        
         END        
                 
         IF EXISTS ( SELECT 1 FROM rdt.rdtserialNoLog WITH (NOLOCK)         
                     WHERE StorerKey = @cStorerKey        
                     AND Status <> '9'         
                     AND Func = @nFunc         
AND FromSerialNo = @cChildSerialNo )          
         BEGIN        
            SET @nErrNo = 109826            
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SerialNoScanned            
            --SET @cChildSerialNo = ''        
            EXEC rdt.rdtSetFocusField @nMobile, 2         
            GOTO Step_3_Fail            
         END        
                 
         INSERT INTO rdt.rdtSerialNoLog ( StorerKey, Status, FromSerialNo, ToSerialNo, ParentSerialNo, FromSKU, ToSKU, SourceKey, SourceType, BatchKey, Remarks, Func, AddWho  )         
         VALUES ( @cStorerKey, '1' , @cChildSerialNo, @cChildSerialNo, '', @cSKU, @cSKU,  @cWorkOrderNo, '', @cBatchKey, '' , @nFunc, @cUserName )         
                 
         IF @@ERROR <> 0         
         BEGIN        
               SET @nErrNo = 109819        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsrdtSerailFail        
               --SET @cChildSerialNo = ''        
               EXEC rdt.rdtSetFocusField @nMobile, 2         
               GOTO Step_3_Fail        
         END           
        
         SELECT @nScanCount = COUNT ( RowRef )         
         FROM rdt.rdtSerialNoLog WITH (NOLOCK)         
         WHERE StorerKey = @cStorerKey        
         AND FromSKU     = @cSKU        
         AND BatchKey    = @cBatchKey        
         AND SourceKey   = @cWorkOrderNo        
         AND Func        = @nFunc         
         AND AddWho      = @cUserName         
         AND Status      = '1'        
                 
                 
         IF @nInnerQty > 0         
         BEGIN        
            IF @nInnerQty = @nScanCount        
            BEGIN   
               SET @cPassed = '1'        
            END        
         END        
         ELSE         
         BEGIN        
            IF @nCaseCnt = @nScanCount        
            BEGIN        
               SET @cPassed = '1'        
            END        
         END        
                          
           IF @cPassed = '1'         
         BEGIN        
                    
            IF @nInnerQty > 0         
            BEGIN        
                       
               -- Prepare Previous Screen Variable              
               SET @cOutField01 = @cSKU          
               SET @cOutField02 = ''        
               SET @cOutField03 = ''        
                       
                                
               -- GOTO Previous Screen              
               SET @nScn = @nScn + 1              
               SET @nStep = @nStep + 1              
                       
               GOTO QUIT         
                       
            END        
            ELSE        
            BEGIN        
               UPDATE rdt.rdtSerialNoLog WITH (ROWLOCK)         
                  SET Status         ='5'        
               WHERE StorerKey = @cStorerKey        
               AND FromSKU     = @cSKU        
               AND BatchKey    = @cBatchKey        
               AND SourceKey   = @cWorkOrderNo        
               AND Func        = @nFunc         
               AND AddWho      = @cUserName         
               AND Status      = '1'           
               --WHERE @cBatchKey = @cBatchKey         
               --AND Status = '1'         
                       
               IF @@ERROR <> 0         
               BEGIN        
                     SET @nErrNo = 109829        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdrdtSerailFail        
                     --SET @cChildSerialNo = ''        
                     EXEC rdt.rdtSetFocusField @nMobile, 2         
                     GOTO Step_3_Fail        
               END        
                       
               -- Prepare Previous Screen Variable              
               SET @cOutField01 = @cSKU          
               SET @cOutField02 = ''        
               SET @cOutField03 = ''        
                                
               -- GOTO Previous Screen              
               SET @nScn = @nScn + 2              
               SET @nStep = @nStep + 2              
                       
   GOTO QUIT         
            END        
                    
         END        
      END        
             
              
      SET @cOutField01 =  @cSKU        
      SET @cOutField02 =  ''        
        
              
      IF @nInnerQty > 0         
      BEGIN        
         SET @cOutField03 =  CASE WHEN @cSerialType = '9' THEN CAST(@nScanCount AS NVARCHAR(5))  + '/' + CAST(@nInnerPack AS NVARCHAR(5)) END        
      END        
      ELSE         
      BEGIN        
         SET @cOutField03 =  CASE WHEN @cSerialType = '9' THEN CAST(@nScanCount AS NVARCHAR(5))  + '/' + CAST(@nCaseCnt AS NVARCHAR(5)) END        
      END        
              
      EXEC rdt.rdtSetFocusField @nMobile, 2         
                    
                    
   END  -- Inputkey = 1              
                 
   IF @nInputKey = 0               
   BEGIN              
               
               
        
       SELECT @nScanCount = COUNT ( RowRef )         
       FROM rdt.rdtSerialNoLog WITH (NOLOCK)         
       WHERE StorerKey = @cStorerKey        
       AND FromSKU     = @cSKU        
       AND BatchKey    = @cBatchKey        
       AND SourceKey   = @cWorkOrderNo        
       AND Func        = @nFunc         
       AND AddWho      = @cUserName         
       AND Status      = '1'        
        
     IF @nScanCount > 0         
     BEGIN         
               
          IF @nCaseCnt = @nScanCount         
          BEGIN        
             SET @cOutField01 = ''        
             SET @cOutField02 = ''           
                  
             -- GOTO Option Screen              
             SET @nScn = @nScn - 2          
             SET @nStep = @nStep - 2         
          END        
          ELSE        
          BEGIN        
                       
             -- Prepare Previous Screen Variable              
             SET @nErrorCount = 0        
                     
             SET @cInvalidSerialNo01 = ''        
             SET @cInvalidSerialNo02 = ''        
             SET @cInvalidSerialNo03 = ''        
                     
             SET @cOutField01 = @cSKU        
             SET @cOutField02 = ''           
                     
             -- GOTO Option Screen              
             SET @nScn = @nScn + 3            
             SET @nStep = @nStep + 3              
                           
             EXEC rdt.rdtSetFocusField @nMobile, 1          
          END        
       END        
       ELSE        
       BEGIN        
             SET @cOutField01 = ''        
             SET @cOutField02 = ''           
                     
         -- GOTO Option Screen              
             SET @nScn = @nScn - 2          
             SET @nStep = @nStep - 2         
       END        
   END              
   GOTO Quit              
                 
   Step_3_Fail:              
   BEGIN              
              
                    
      -- Prepare Next Screen Variable              
      SET @cOutField01 = @cSKU           
      SET @cOutField02 = ''           
              
              
      IF ISNULL(@cChildSerialNo,'')  <> ''         
      BEGIN        
         IF @nErrorCount = 1         
         BEGIN           
            SET @cInvalidSerialNo01 = @cChildSerialNo        
            SET @nErrorCount = @nErrorCount + 1         
         END         
         ELSE IF @nErrorCount = 2         
         BEGIN         
            SET @cInvalidSerialNo02 = @cChildSerialNo          
            SET @nErrorCount = @nErrorCount + 1         
         END         
         ELSE IF @nErrorCount = 3        
     BEGIN        
            SET @cInvalidSerialNo03 = @cChildSerialNo          
            SET @nErrorCount = 1        
         END         
        
         SET @cChildSerialNo = ''         
        
      END        
              
      SET @cOutField04 = @cInvalidSerialNo01         
      SET @cOutField05 = @cInvalidSerialNo02         
      SET @cOutField06 = @cInvalidSerialNo03         
                    
   END              
              
END               
GOTO QUIT           
        
/********************************************************************************              
Step 4. Scn = 4893.               
               
   SKU             (field01)              
   Parent SerialNo (field02, input)              
          
                 
********************************************************************************/              
Step_4:              
BEGIN              
   IF @nInputKey = 1              
   BEGIN              
      SET @cChildSerialNo = ''         
              
      SET @cInnerSKU        = ISNULL(RTRIM(@cInField02),'')           
      SET @cChildSerialNo   = ISNULL(RTRIM(@cInField03),'')           
              
              
      IF @cInnerSKU = ''              
      BEGIN              
         SET @nErrNo = 109842              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKUReq'        
         SET @cInnerSKU = ''         
         EXEC rdt.rdtSetFocusField @nMobile, 2        
         GOTO Step_4_Fail            
      END              
              
      -- Get SKU barcode count            
      --DECLARE @nSKUCnt INT            
      EXEC rdt.rdt_GETSKUCNT            
          @cStorerKey  = @cStorerKey            
         ,@cSKU        = @cInnerSKU            
         ,@nSKUCnt     = @nSKUCnt       OUTPUT            
         ,@bSuccess    = @b_Success     OUTPUT            
         ,@nErr        = @nErrNo        OUTPUT            
         ,@cErrMsg     = @cErrMsg       OUTPUT           
              
      -- Check SKU/UPC            
      IF @nSKUCnt = 0            
      BEGIN            
         SET @nErrNo = 109843            
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU          
         SET @cInnerSKU = ''         
         EXEC rdt.rdtSetFocusField @nMobile, 2          
         GOTO Step_4_Fail            
      END            
              
      -- Check multi SKU barcode            
      IF @nSKUCnt > 1            
      BEGIN            
         SET @nErrNo = 109844         
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod            
         SET @cInnerSKU = ''         
         EXEC rdt.rdtSetFocusField @nMobile, 2        
         GOTO Step_4_Fail            
      END            
              
      -- Get SKU code            
      EXEC rdt.rdt_GETSKU            
          @cStorerKey  = @cStorerKey            
         ,@cSKU        = @cInnerSKU     OUTPUT            
         ,@bSuccess    = @b_Success     OUTPUT            
         ,@nErr        = @nErrNo        OUTPUT            
         ,@cErrMsg     = @cErrMsg       OUTPUT            
              
      IF @nErrNo = 0         
      BEGIN        
         SET @cSKU = @cInnerSKU        
      END        
              
      IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrder WITH (NOLOCK)         
                      WHERE WorkOrderKey = @cWorkOrderNo        
                      AND wkordudef3 = @cSKU  )        
      BEGIN        
         SET @nErrNo = 109845         
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- WrongSKU            
         SET @cInnerSKU = ''         
         EXEC rdt.rdtSetFocusField @nMobile, 2        
         GOTO Step_4_Fail           
      END        
      --SET @cSKUInput = '001172-0000'        --SET @cChildSerialNo = '1729FSAP290C'         
        
              
--      1725FSAP2879   1729FSAP291C   1729FSAP293M        
--      1725FSAP2869           
--      1725FSAP2859   1729FSAP290C        
--      1725FSAP2849        
--      1725FSAP2839   1729FSAP289C   1729FSAP292M        
--      1725FSAP2829           
--      1725FSAP2819   1729FSAP288C        
--      1725FSAP2809        
                   
              
      SELECT         
             @cWorkOrderSKU  = ISNULL(WKORDUDef3 ,'')        
      FROM dbo.WorkOrder WITH (NOLOCK)         
      WHERE StorerKey = @cStorerKey        
      AND WorkOrderKey = @cWorkOrderNo         
              
      SELECT TOP 1 @cGenerateLabel = ISNULL(WKORDUDef1,'')         
      FROM dbo.WorkOrderDetail WITH (NOLOCK)         
      WHERE WorkOrderKey = @cWorkOrderNo         
              
      SELECT         
             @nMasterQty     = ISNULL(Qty,0 )         
      FROM dbo.WorkOrderDetail WITH (NOLOCK)         
      WHERE StorerKey  = @cStorerKey        
      AND WorkOrderKey = @cWorkOrderNo        
      AND Unit         = 'Master'        
     
                    
      SET @cPackKey = ''        
      SELECT @cPackKey = PackKey        
      FROM dbo.SKU WITH (NOLOCK)         
      WHERE StorerKey = @cStorerKey        
      AND SKU         = @cSKU        
        
            
              
      SELECT @nInnerPack = ISNULL(InnerPack,0)         
            ,@nCaseCnt  = ISNULL(CaseCnt,0)         
      FROM dbo.Pack WITH (NOLOCK)         
      WHERE PackKey = @cPackKey         
              
      SET @n9LQty     = 0         
      SET @nInnerQty  = 0            
      SET @cPassed    = ''           
              
      --SET @n9LQty = @nMasterQty * @nCaseCnt        
              
      IF @nInnerPack > 0         
      BEGIN        
          SET @nInnerQty  = @nInnerPack --@nMasterQty * ( @nCaseCnt / @nInnerPack )         
      END         
              
          
              
--      IF EXISTS ( SELECT 1 FROM dbo.Codelkup WITH (NOLOCK)        
--                  WHERE ListName = 'LOGILOC'        
--                  AND StorerKey = @cStorerKey        
--                  AND Short = @cSerialNoCode)   
--      BEGIN        
--         IF NOT EXISTS (SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)         
--                        WHERE StorerKey = @cStorerKey        
--                        AND SKU = @cSKU         
--                        AND ParentSerialNo = @cMasterSerialNo )        
--         BEGIN        
--             IF NOT EXISTS (SELECT 1 FROM rdt.rdtSerialNoLog WITH (NOLOCK)         
--                        WHERE StorerKey = @cStorerKey        
--                        AND FromSKU = @cSKU         
--                        AND ParentSerialNo = @cMasterSerialNo        
--                        AND Status <> '9')        
--            BEGIN        
--               SET @nErrNo = 109850              
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvSerialNo'        
--               SET @cChildSerialNo = ''         
--               EXEC rdt.rdtSetFocusField @nMobile, 3        
--               GOTO Step_4_Fail         
--            END        
--                    
--         END        
--                 
--                
--      END        
--      ELSE        
--      BEGIN        
--         IF NOT EXISTS (SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)         
--                        WHERE StorerKey = @cStorerKey        
--                        AND SKU = @cSKU         
--                        AND ParentSerialNo = @cMasterSerialNo )        
--         BEGIN        
--            SET @nErrNo = 142151           
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvSerialNo'        
--            SET @cChildSerialNo = ''         
--            EXEC rdt.rdtSetFocusField @nMobile, 3        
--            GOTO Step_4_Fail         
--         END        
--      END        
            
      IF ISNULL(@cChildSerialNo, '' ) <> ''       
      BEGIN      
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'SERIALNO', @cChildSerialNo) = 0        
         BEGIN        
               SET @nErrNo = 142152        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialType        
               SET @cChildSerialNo = ''         
               EXEC rdt.rdtSetFocusField @nMobile, 3        
               GOTO Step_4_Fail        
         END        
                 
         SET @cSerialNoCode = SUBSTRING(@cMasterSerialNo, 5,2)        
               
         SET @cSerialType = RIGHT ( @cChildSerialNo , 1 )         
                 
         IF @cSerialType <> 'C'        
         BEGIN        
            SET @nErrNo = 109836        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialType        
            SET @cChildSerialNo = ''         
            EXEC rdt.rdtSetFocusField @nMobile, 3        
            GOTO Step_4_Fail        
         END        
              
         IF @nInnerQty = 0 AND @cSerialType = 'C'        
         BEGIN        
            SET @nErrNo = 109824        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialType        
            SET @cChildSerialNo = ''         
            EXEC rdt.rdtSetFocusField @nMobile, 3        
            GOTO Step_4_Fail        
         END        
                   
                 
         IF EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)         
                         WHERE SKU = @cSKU        
                         AND SerialNo = @cChildSerialNo        
                         AND StorerKey = @cStorerKey  )         
         BEGIN        
            SET @nErrNo = 109827            
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialNo            
            SET @cChildSerialNo = ''         
            EXEC rdt.rdtSetFocusField @nMobile, 3        
            GOTO Step_4_Fail            
         END        
                    
              
         IF EXISTS ( SELECT 1 FROM rdt.rdtserialNoLog WITH (NOLOCK)         
                     WHERE StorerKey = @cStorerKey        
    AND Status <> '9'         
                     AND Func = @nFunc         
                     AND ParentSerialNo = @cChildSerialNo )          
         BEGIN        
            SET @nErrNo = 109828            
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SerialNoScanned            
            SET @cChildSerialNo = ''         
            EXEC rdt.rdtSetFocusField @nMobile, 3        
            GOTO Step_4_Fail            
         END        
                 
         --insert into traceinfo (TraceName,TimeIn,Step1,Step2,Step3,Step4,Step5)        
       --values ('rdtfnc_SerialNo_Serialize',getdate(),@nMobile,@cUserName,@cBatchKey ,@cWorkOrderNo,@cChildSerialNo) --JyhBin        
               
         UPDATE rdt.rdtSerialNoLog WITH (ROWLOCK)         
            SET  ParentSerialNo = @cChildSerialNo        
                ,Status         ='5'        
         WHERE StorerKey = @cStorerKey        
            AND FromSKU     = @cSKU        
            AND BatchKey    = @cBatchKey        
            AND SourceKey   = @cWorkOrderNo        
            AND Func        = @nFunc         
            AND AddWho      = @cUserName         
            AND Status      = '1'        
         --WHERE @cBatchKey = @cBatchKey         
         --AND Status = '1'         
         --AND SourceKey = @cWorkOrderNo        
                 
                 
         IF @@ERROR <> 0         
         BEGIN        
               SET @nErrNo = 109823        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdrdtSerailFail        
               GOTO Step_4_Fail        
         END        
                 
                 
         SELECT @nScanCount = COUNT ( RowRef )         
         FROM rdt.rdtSerialNoLog WITH (NOLOCK)         
         WHERE StorerKey = @cStorerKey        
         AND FromSKU     = @cSKU        
         AND BatchKey    = @cBatchKey        
         AND SourceKey   = @cWorkOrderNo        
         AND Func        = @nFunc         
         AND AddWho      = @cUserName         
         AND Status      = '5'        
                 
   --      IF @nCaseCnt  = @nScanCount        
   --      BEGIN        
   --                 
   --         -- Prepare Previous Screen Variable              
   --         SET @cOutField01 = @cSKU        
   --         SET @cOutField02 = ''           
   --                           
   --         -- GOTO Previous Screen              
   --         SET @nScn = @nScn + 1         
   --         SET @nStep = @nStep + 1           
   --                 
   --         GOTO QUIT         
   --                 
   --      END        
   --      ELSE        
         BEGIN        
            IF @nInnerQty > 0         
            BEGIN        
               SET @cOutField03 =  CASE WHEN @cSerialType = '9' THEN CAST(@nScanCount AS NVARCHAR(5))  + '/' + CAST(@nInnerPack AS NVARCHAR(5)) END        
            END        
            ELSE         
            BEGIN        
               SET @cOutField03 =  CASE WHEN @cSerialType = '9' THEN CAST(@nScanCount AS NVARCHAR(5))  + '/' + CAST(@nCaseCnt AS NVARCHAR(5)) END        
            END        
                    
            -- Prepare Previous Screen Variable          
            IF @nFromStep <> 0         
            BEGIN        
               SET @cOutField01 = ''        
               SET @cOutField02 = ''        
               SET @cOutField03 = ''        
                                 
               -- GOTO Previous Screen              
               SET @nScn = @nScn - 3         
               SET @nStep = @nStep - 3            
                       
               SET @nFromStep = 0         
               SET @nFromScn  = 0         
                       
               --EXEC rdt.rdtSetFocusField @nMobile, 2         
                       
               GOTO QUIT         
            END            
            ELSE        
            BEGIN        
               SET @cInvalidSerialNo01 = ''        
               SET @cInvalidSerialNo02 = ''        
               SET @cInvalidSerialNo03 = ''        
                                
               SET @cOutField01 = @cSKU        
               SET @cOutField02 = ''           
                       
               SET @cOutField04 = ''        
               SET @cOutField05 = ''        
               SET @cOutField06 = ''        
                                 
               -- GOTO Previous Screen              
               SET @nScn = @nScn - 1         
               SET @nStep = @nStep - 1            
                       
               EXEC rdt.rdtSetFocusField @nMobile, 2         
                       
               GOTO QUIT         
            END        
                    
                    
         END        
               
      END            
      ELSE      
      BEGIN               
         SET @cOutField02 = @cInnerSKU      
         SET @cOutField03 = ''      
               
         EXEC rdt.rdtSetFocusField @nMobile, 3          
               
      END      
              
             
              
                    
                    
   END  -- Inputkey = 1              
                 
   --IF @nInputKey = 0               
   --BEGIN              
   --    -- Prepare Previous Screen Variable              
   --    SET @cOutField01 = ''           
   --    SET @cOutField02 = ''           
                        
   --    -- GOTO Previous Screen              
   --    SET @nScn = @nScn - 2              
   --    SET @nStep = @nStep - 2              
                     
   --    EXEC rdt.rdtSetFocusField @nMobile, 1          
   --END              
   GOTO Quit              
                 
   Step_4_Fail:              
   BEGIN              
                    
      -- Prepare Next Screen Variable              
              
      SET @cOutField01 = @cSKU           
      SET @cOutField02 = @cInnerSKU          
      SET @cOutField03 = @cChildSerialNo        
              
                    
   END              
              
END               
GOTO QUIT        
        
        
         
/********************************************************************************              
Step 5. Scn = 4894.               
               
   SKU             (field01)              
   Master SerialNo (field02, input)              
          
                 
********************************************************************************/              
Step_5:              
BEGIN              
   IF @nInputKey = 1              
   BEGIN              
              
      SET @cMasterSKU        = ISNULL(RTRIM(@cInField02),'')           
      SET @cMasterSerialNo   = ISNULL(RTRIM(@cInField03),'')           
              
      --SET @cMasterSerialNo = '1731FSAP892M'        
              
              
--      1725FSAP2879   1729FSAP291C   1729FSAP293M        
--      1725FSAP2869           
--      1725FSAP2859   1729FSAP290C        
--      1725FSAP2849        
--      1725FSAP2839   1729FSAP289C   1729FSAP292M        
--      1725FSAP2829           
--      1725FSAP2819   1729FSAP288C        
--      1725FSAP2809        
              
              
      IF @cMasterSKU = ''              
      BEGIN              
         SET @nErrNo = 109846              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKUReq'        
         SET @cMasterSKU = ''         
         EXEC rdt.rdtSetFocusField @nMobile, 2        
         GOTO Step_5_Fail            
      END              
              
      -- Get SKU barcode count            
      --DECLARE @nSKUCnt INT            
      EXEC rdt.rdt_GETSKUCNT            
          @cStorerKey  = @cStorerKey            
         ,@cSKU        = @cMasterSKU            
         ,@nSKUCnt     = @nSKUCnt       OUTPUT            
         ,@bSuccess    = @b_Success     OUTPUT            
         ,@nErr        = @nErrNo   OUTPUT            
         ,@cErrMsg     = @cErrMsg       OUTPUT            
              
      -- Check SKU/UPC            
      IF @nSKUCnt = 0            
      BEGIN            
         SET @nErrNo = 109847            
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU          
         SET @cMasterSKU = ''         
         EXEC rdt.rdtSetFocusField @nMobile, 2          
         GOTO Step_5_Fail            
      END            
              
      -- Check multi SKU barcode            
      IF @nSKUCnt > 1            
      BEGIN            
         SET @nErrNo = 109848         
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod            
         SET @cMasterSKU = ''         
         EXEC rdt.rdtSetFocusField @nMobile, 2        
         GOTO Step_5_Fail            
      END            
              
      -- Get SKU code            
      EXEC rdt.rdt_GETSKU            
          @cStorerKey  = @cStorerKey            
         ,@cSKU        = @cMasterSKU    OUTPUT            
         ,@bSuccess    = @b_Success     OUTPUT            
         ,@nErr        = @nErrNo        OUTPUT            
         ,@cErrMsg     = @cErrMsg       OUTPUT            
              
      IF @nErrNo = 0         
      BEGIN        
         SET @cSKU = @cMasterSKU        
      END        
              
      IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrder WITH (NOLOCK)         
                      WHERE WorkOrderKey = @cWorkOrderNo        
                      AND wkordudef3 = @cSKU  )        
      BEGIN        
         SET @nErrNo = 109849         
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- WrongSKU            
         SET @cInnerSKU = ''         
         EXEC rdt.rdtSetFocusField @nMobile, 2        
         GOTO Step_5_Fail           
      END        
             
--      IF @cMasterSerialNo = ''              
--      BEGIN              
--         SET @nErrNo = 109830              
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ParentSerialReq'        
--         EXEC rdt.rdtSetFocusField @nMobile, 3        
--         GOTO Step_5_Fail            
--      END              
              
      IF ISNULL(@cMasterSerialNo , '' ) <> ''       
      BEGIN      
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'SERIALNO', @cMasterSerialNo) = 0        
         BEGIN        
               SET @nErrNo = 109850        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvSerialNo'        
               EXEC rdt.rdtSetFocusField @nMobile, 3        
               GOTO Step_5_Fail         
         END        
              
         SET @cSerialType = RIGHT ( @cMasterSerialNo , 1 )         
                 
         IF @cSerialType <> 'M'        
         BEGIN        
            SET @nErrNo = 109837        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialType        
            EXEC rdt.rdtSetFocusField @nMobile, 3        
            GOTO Step_5_Fail        
         END        
              
         IF EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)         
                            WHERE SKU = @cSKU        
                            AND ParentSerialNo = @cMasterSerialNo  )         
         BEGIN        
            SET @nErrNo = 109831            
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialNo            
            EXEC rdt.rdtSetFocusField @nMobile, 3        
            GOTO Step_5_Fail            
         END        
              
         IF EXISTS ( SELECT 1 FROM rdt.rdtserialNoLog WITH (NOLOCK)         
                     WHERE StorerKey = @cStorerKey        
                     AND Status <> '9'         
                     AND Func = @nFunc         
                     AND Remarks = @cMasterSerialNo )          
         BEGIN        
            SET @nErrNo = 109832            
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SerialNoScanned           
            EXEC rdt.rdtSetFocusField @nMobile, 3         
            GOTO Step_5_Fail            
         END       
                 
                 
                 
                 
         IF @cExtendedUpdateSP <> ''        
         BEGIN        
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')        
            BEGIN        
                       
           
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +        
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cWorkOrderNo, @nFromFunc, @cBatchKey, @cSKU, @cMasterserialNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
               SET @cSQLParam =        
                  '@nMobile          INT,                  '+        
                  '@nFunc            INT,                  '+        
                  '@cLangCode        NVARCHAR( 3),         '+        
                  '@nStep            INT,                  '+        
                  '@nInputKey        INT,                  '+        
                  '@cFacility        NVARCHAR( 5),         '+        
                  '@cStorerKey       NVARCHAR( 15),        '+        
                  '@cWorkOrderNo     NVARCHAR( 10),        '+        
                  '@nFromFunc        INT,                  '+        
                  '@cBatchKey        NVARCHAR( 10),        '+        
                  '@cSKU             NVARCHAR( 20),        '+        
                  '@cMasterserialNo  NVARCHAR( 20),        '+        
                  '@nErrNo           INT           OUTPUT, '+        
                  '@cErrMsg          NVARCHAR( 20) OUTPUT  '        
           
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cWorkOrderNo, @nFunc, @cBatchKey, @cSKU, @cMasterserialNo, @nErrNo OUTPUT, @cErrMsg OUTPUT         
           
               IF @nErrNo <> 0        
                  GOTO Step_5_Fail        
            END        
         END        
                 
                 
                 
                 
         SET @cOutField01 = ''           
         SET @cOutField02 = ''           
         SET @cOutField03 = ''          
         SET @cOutField04 = ''          
         SET @cOutField05 = ''          
         SET @cOutField06 = ''          
                 
         SET @cInvalidSerialNo01 = ''        
         SET @cInvalidSerialNo02 = ''        
         SET @cInvalidSerialNo03 = ''        
                        
         -- GOTO Previous Screen              
         SET @nScn = @nScn - 2              
         SET @nStep = @nStep - 2          
                   
                 
         EXEC rdt.rdtSetFocusField @nMobile, 1                
      END      
      ELSE      
      BEGIN               
         SET @cOutField02 = @cMasterSKU      
         SET @cOutField03 = ''      
               
         EXEC rdt.rdtSetFocusField @nMobile, 3          
               
      END      
               
   END  -- Inputkey = 1              
                 
--   IF @nInputKey = 0               
--   BEGIN              
--       -- Prepare Previous Screen Variable              
--       SET @cOutField01 = ''           
--       SET @cOutField02 = ''           
--                        
--       -- GOTO Previous Screen              
--       SET @nScn = @nScn - 1              
--       SET @nStep = @nStep - 1              
--                     
--       EXEC rdt.rdtSetFocusField @nMobile, 1          
--   END              
   GOTO Quit              
                 
   Step_5_Fail:              
   BEGIN              
              
      -- Prepare Next Screen Variable              
              
      SET @cOutField01 = @cSKU           
      SET @cOutField02 = @cMasterSKU          
      SET @cOutField03 = @cMasterSerialNo        
              
              
                    
   END              
              
END               
GOTO QUIT           
        
/********************************************************************************         
Step 6. Scn = 4895.               
               
   SKU             (field01)              
   Option          (field02, input)              
          
                 
********************************************************************************/              
Step_6:              
BEGIN              
   IF @nInputKey = 1              
   BEGIN              
              
      SET @cOption   = ISNULL(RTRIM(@cInField02),'')           
              
      IF @cOption = ''              
      BEGIN              
         SET @nErrNo = 109839              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OptionReq'        
         GOTO Step_6_Fail       
      END              
              
      IF @cOption NOT IN ( '1', '9' )         
      BEGIN        
         SET @nErrNo = 109840              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidOption'        
         GOTO Step_6_Fail            
      END        
        
      SET @cPackKey = ''        
      SELECT @cPackKey = PackKey        
      FROM dbo.SKU WITH (NOLOCK)         
      WHERE StorerKey = @cStorerKey        
      AND SKU         = @cSKU        
              
      SELECT @nInnerPack = ISNULL(InnerPack,0)         
            ,@nCaseCnt  = ISNULL(CaseCnt,0)         
      FROM dbo.Pack WITH (NOLOCK)         
      WHERE PackKey = @cPackKey         
              
      --SET @n9LQty     = 0         
      --SET @nInnerQty  = 0            
      --SET @cPassed    = ''           
              
      ----SET @n9LQty = @nMasterQty * @nCaseCnt        
              
      --IF @nInnerPack > 0         
      --BEGIN        
      --    SET @nInnerQty  = @nInnerPack -- @nMasterQty * ( @nCaseCnt / @nInnerPack )         
      --END         
              
      IF @cOption = '1'         
      BEGIN        
                 
        
         SET @cOutField01 =  @cSKU        
         SET @cOutField02 =  ''        
                 
         IF @nInnerQty > 0         
         BEGIN        
            SET @cOutField03 =  CASE WHEN @cSerialType = '9' THEN CAST(@nScanCount AS NVARCHAR(5))  + '/' + CAST(@nInnerPack AS NVARCHAR(5)) END        
         END        
         ELSE         
         BEGIN        
            SET @cOutField03 =  CASE WHEN @cSerialType = '9' THEN CAST(@nScanCount AS NVARCHAR(5))  + '/' + CAST(@nCaseCnt AS NVARCHAR(5)) END        
         END        
                 
               
               
         EXEC rdt.rdtSetFocusField @nMobile, 2         
                 
         SET @nScn = @nScn - 3              
         SET @nStep = @nStep - 3          
                 
      END        
      ELSE IF @cOption = '9'        
      BEGIN        
         SET @nFromStep = 0        
         SET @nFromScn  = 0        
                 
         IF @nInnerQty > 0         
         BEGIN        
                 
                    
            SET @nFromStep = @nStep        
            SET @nFromScn  = @nScn        
                    
            -- Prepare Previous Screen Variable              
            SET @cOutField01 = @cSKU          
            SET @cOutField02 = ''        
            SET @cOutField03 = ''        
                                
            -- GOTO Previous Screen              
            SET @nScn = @nScn - 2              
            SET @nStep = @nStep - 2              
                    
            GOTO QUIT         
                       
         END        
         ELSE        
         BEGIN        
            UPDATE rdt.rdtSerialNoLog WITH (ROWLOCK)         
               SET Status         ='5'        
            WHERE StorerKey = @cStorerKey        
            AND FromSKU     = @cSKU        
            AND BatchKey    = @cBatchKey        
            AND SourceKey   = @cWorkOrderNo        
            AND Func        = @nFunc         
            AND AddWho      = @cUserName         
            AND Status      = '1'           
            --WHERE @cBatchKey = @cBatchKey         
            --AND Status = '1'       
                       
            IF @@ERROR <> 0         
            BEGIN        
                  SET @nErrNo = 109841        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdrdtSerailFail        
                  GOTO Step_6_Fail        
            END        
                       
            -- Prepare Previous Screen Variable              
            SET @cOutField02 = '' --@cSKU          
            SET @cOutField03 = ''        
                                
            -- GOTO Previous Screen              
            SET @nScn = @nScn - 1               
            SET @nStep = @nStep - 1         
                       
            GOTO QUIT         
         END        
                       
         --SET @cOutField01 = ''           
         --SET @cOutField02 = ''           
         --SET @cOutField03 = ''          
         --SET @cOutField04 = ''          
         --SET @cOutField05 = ''          
         --SET @cOutField06 = ''          
                 
         --SET @cInvalidSerialNo01 = ''        
         --SET @cInvalidSerialNo02 = ''        
         --SET @cInvalidSerialNo03 = ''        
                      
         ---- GOTO Previous Screen              
         --SET @nScn = @nScn - 2              
         --SET @nStep = @nStep - 2          
                   
                 
         --EXEC rdt.rdtSetFocusField @nMobile, 1                
      END             
   END  -- Inputkey = 1              
                 
--   IF @nInputKey = 0               
--   BEGIN              
--       -- Prepare Previous Screen Variable              
--       SET @cOutField01 = ''           
--       SET @cOutField02 = ''           
--                        
--       -- GOTO Previous Screen              
--       SET @nScn = @nScn - 1              
--       SET @nStep = @nStep - 1              
--                     
--       EXEC rdt.rdtSetFocusField @nMobile, 1          
--   END              
   GOTO Quit              
                 
   Step_6_Fail:              
   BEGIN              
              
      -- Prepare Next Screen Variable              
              
      SET @cOutField01 = @cSKU           
      SET @cOutField02 = ''           
              
              
                    
   END              
              
END               
GOTO QUIT           
        
            
/********************************************************************************              
Quit. Update back to I/O table, ready to be pick up by JBOSS              
********************************************************************************/              
Quit:              
              
BEGIN              
   UPDATE RDTMOBREC WITH (ROWLOCK) SET               
      ErrMsg = @cErrMsg,               
      Func   = @nFunc,              
      Step   = @nStep,              
      Scn    = @nScn,              
              
      StorerKey = @cStorerKey,              
      Facility  = @cFacility,               
      Printer   = @cPrinter,               
      --UserName  = @cUserName,             
      EditDate  = GetDate() ,          
      InputKey  = @nInputKey,           
     --LightMode = @cLightMode,          
                    
      --V_SKUDescr = @cSKUDescr,          
      --V_UOM = @cPUOM,          
      V_SKU = @cSKU,           
      --V_Qty = @nExpectedQTY,          
      --V_Lot = @cLot,        
            
      V_String1 = @cWorkOrderNo  ,            
      V_String2 = @cOption       ,            
      --V_String3 = @n9LQty        ,            
      --V_String4 = @nInnerQty     ,            
      --V_String5 = @nMasterQty ,            
      --V_String6 = @nTotalMasterQty,        
      V_String6 = @cGenSerialSP,        
      V_String7 = @cBatchKey,        
      V_String8 = @cExtendedUpdateSP,        
      V_String9 = @cInvalidSerialNo01,        
      V_String10 = @cInvalidSerialNo02,        
      V_String11 = @cInvalidSerialNo03,        
      --V_String12 = @nErrorCount,        
      --V_String13 = @nFromScn,        
      --V_String14 = @nFromStep,        
    --V_String15 = @nCaseCnt,        
        
      V_Integer1 = @n9LQty,          
      V_Integer2 = @nInnerQty,          
      V_Integer3 = @nMasterQty,          
      V_Integer4 = @nErrorCount,        
      V_Integer5 = @nCaseCnt,        
      V_FromScn  = @nFromScn,        
      V_FromStep = @nFromStep,           
        
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