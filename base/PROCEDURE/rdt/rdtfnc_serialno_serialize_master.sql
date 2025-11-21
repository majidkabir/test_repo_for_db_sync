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
/* 2017-07-31 1.0  ChewKP     Created. WMS-1931                               */    
/* 2018-11-13 1.1  Gan        Performance tuning                              */
/******************************************************************************/        
        
CREATE PROC [RDT].[rdtfnc_SerialNo_Serialize_Master] (        
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
   @cDataWindow   NVARCHAR( 50),    
   @cTargetDB       NVARCHAR( 20),   
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
   @nTotalMasterCount INT,  
   @cMasterSKU        NVARCHAR(20),  
   @nTempInnerCount   INT,  
   @cSerialNoCode     NVARCHAR(2),  
  
  
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
   
   @n9LQty     = V_Integer1,
   @nInnerQty  = V_Integer2,
   @nMasterQty = V_Integer3,
   @nFromFunc  = V_Integer4,
         
     
           
   @cWorkOrderNo        = V_String1,      
   @cOption             = V_String2,  
   --@n9LQty              = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3, 5), 0) = 1 THEN LEFT( V_String3, 5) ELSE 0 END,    
   --@nInnerQty           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4, 5), 0) = 1 THEN LEFT( V_String4, 5) ELSE 0 END,    
   --@nMasterQty          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5, 5), 0) = 1 THEN LEFT( V_String5, 5) ELSE 0 END,    
   --@nTotalMasterQty     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6, 5), 0) = 1 THEN LEFT( V_String6, 5) ELSE 0 END,    
   @cGenSerialSP        = V_String6,  
   @cBatchKey           = V_String7,  
   --@nFromFunc           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String8, 5), 0) = 1 THEN LEFT( V_String8, 5) ELSE 0 END,    
   @cExtendedUpdateSP   = V_String9,  
     
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
        
        
IF @nFunc in (  1014  , 1015 )  -- Serial No Serialize  
BEGIN        
           
   -- Redirect to respective screen        
   IF @nStep = 0 GOTO Step_0   -- Serial No SKU Change    
   IF @nStep = 1 GOTO Step_1   -- Scn = 5000. WorkOrderNo, Option  
   IF @nStep = 2 GOTO Step_2   -- Scn = 5001. SKU, Qty   
   IF @nStep = 3 GOTO Step_3   -- Scn = 5002. SKU, Child SerialNo   
   IF @nStep = 4 GOTO Step_4   -- Scn = 5003. Option  
     
           
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
     @cStorerKey  = @cStorerkey        
             
     
   SET @cWorkOrderNo = ''  
   SET @cOption      = ''  
  
   -- Init screen        
   SET @cOutField01 = ''         
   SET @cOutField02 = ''        
        
   -- Set the entry point        
   SET @nScn = 5000        
   SET @nStep = 1        
           
   EXEC rdt.rdtSetFocusField @nMobile, 1        
           
END        
GOTO Quit        
        
        
/********************************************************************************        
Step 1. Scn = 5000.        
   WorkOrderNo     (field01 , input)        
       
      
********************************************************************************/        
Step_1:        
BEGIN        
   IF @nInputKey = 1 --ENTER        
   BEGIN        
              
      SET @cWorkOrderNo = ISNULL(RTRIM(@cInField01),'')        
           
            
      IF @cWorkOrderNo = ''  
      BEGIN  
         SET @nErrNo = 113201        
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
         SET @nErrNo = 113202        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvdWorkOrder  
         SET @cWorkOrderNo = ''  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_1_Fail        
      END      
                     
                     
      SET @cSKU = ''  
      SET @cChildSerialNo = ''  
        
      -- Prepare Next Screen Variable        
      --SET @cOutField01 = @cPTSZone      
      SET @cOutField01 = ''    
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
        
      -- GOTO Next Screen        
      SET @nScn = @nScn + 1        
      SET @nStep = @nStep + 1       
        
      EXEC rdt.rdtSetFocusField @nMobile, 1  
        
      
          
              
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
        @cStorerKey  = @cStorerkey        
                
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
Step 2. Scn = 5001.         
         
   SKU            (field01, input)        
   Child SerialNo (field02, input)        
    
           
********************************************************************************/        
Step_2:        
BEGIN        
   IF @nInputKey = 1        
   BEGIN        
      SET @cSKUInput        = ISNULL(RTRIM(@cInField01),'')        
      SET @cChildSerialNo   = ISNULL(RTRIM(@cInField02),'')     
        
      --SET @cSKUInput = '939-001466'  
      --SET @cChildSerialNo = '1735FNAF175C'   
  
        
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
         SET @nErrNo = 113203        
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
         SET @nErrNo = 113204      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU    
         SET @cSKU = ''   
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_2_Fail      
      END      
        
      -- Check multi SKU barcode      
      IF @nSKUCnt > 1      
      BEGIN      
         SET @nErrNo = 113205   
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
         SET @nErrNo = 113206  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU      
         SET @cSKU = ''   
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_2_Fail    
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
        
      IF ISNULL(@cChildSerialNo,'') <>  '' 
      BEGIN
         
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'SERIALNO', @cChildSerialNo) = 0  
         BEGIN  
               SET @nErrNo = 113232  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialNo  
               --SET @cChildSerialNo = ''  
               EXEC rdt.rdtSetFocusField @nMobile, 2   
               GOTO Step_2_Fail    
         END  
           
           
         SET @cSerialNoCode = SUBSTRING(@cChildSerialNo, 5,2)  
           
         IF EXISTS ( SELECT 1 FROM dbo.Codelkup WITH (NOLOCK)  
                     WHERE ListName = 'LOGILOC'  
                     AND StorerKey = @cStorerKey  
                     AND Short = @cSerialNoCode)  
         BEGIN  
            IF NOT EXISTS (SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)   
                           WHERE StorerKey = @cStorerKey  
                           AND SKU = @cSKU   
                           AND ParentSerialNo = @cChildSerialNo )  
            BEGIN  
                IF NOT EXISTS (SELECT 1 FROM rdt.rdtSerialNoLog WITH (NOLOCK)   
                           WHERE StorerKey = @cStorerKey  
                           AND FromSKU = @cSKU   
                           AND ParentSerialNo = @cChildSerialNo  
                           AND Status <> '9')  
               BEGIN  
                  SET @nErrNo = 113228        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvSerialNo'  
                  SET @cMasterSerialNo = ''   
                  EXEC rdt.rdtSetFocusField @nMobile, 3  
                  GOTO Step_2_Fail      
               END  
                 
            END  
              
             
         END  
         ELSE  
         BEGIN  
            IF NOT EXISTS (SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)   
                           WHERE StorerKey = @cStorerKey  
                           AND SKU = @cSKU   
                           AND ParentSerialNo = @cChildSerialNo )  
            BEGIN  
               SET @nErrNo = 113233     
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvSerialNo'  
               SET @cMasterSerialNo = ''   
               EXEC rdt.rdtSetFocusField @nMobile, 3  
               GOTO Step_2_Fail      
            END  
         END  
     
     
         SET @nFromFunc = 0   
     
         SELECT TOP 1 @nFromFunc = Func   
         FROM rdt.rdtSerialNoLog WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey  
         AND FromSKU     = @cSKU  
         AND SourceKey   = @cWorkOrderNo  
         AND Status      = '5'  
         AND ParentSerialNo = @cChildSerialNo  
     
           
           
   --      IF ISNULL(@nFromFunc,0) = 0  
   --      BEGIN  
   --            SET @nErrNo = 113229  
   --            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialNo  
   --            --SET @cChildSerialNo = ''  
   --            EXEC rdt.rdtSetFocusField @nMobile, 2   
   --            GOTO Step_2_Fail    
   --      END  
           
         SET @nTotalMasterCount = @nCaseCnt / @nInnerQty  
           
         SELECT @nTempInnerCount = COUNT ( Distinct ParentSerialNo )   
         FROM rdt.rdtSerialNoLog WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey  
         AND FromSKU     = @cSKU  
         AND BatchKey2    = @cBatchKey  
         AND SourceKey   = @cWorkOrderNo  
         AND Func        = @nFromFunc  
         --AND AddWho      = @cUserName   
         AND Status      = '5'  
         --AND SerialType = @nMobile  
     
         --SELECT @nTempInnerCount '@nTempInnerCount' , @nTotalMasterCount '@nTotalMasterCount' , @cBatchKey '@cBatchKey'  
     
           
         IF @nTotalMasterCount < ISNULL(@nTempInnerCount,0)  + 1   
         BEGIN  
            SET @nErrNo = 113227      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- OverScanned      
            --SET @cChildSerialNo = ''  
            EXEC rdt.rdtSetFocusField @nMobile, 2   
            GOTO Step_2_Fail    
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
                    @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cWorkOrderNo, @nFromFunc, @cBatchKey, @cSKU, @cChildSerialNo, @nErrNo OUTPUT, @cErrMsg OUTPUT   
     
               IF @nErrNo <> 0  
                  GOTO Step_2_Fail  
            END  
         END  
         ELSE  
         BEGIN  
            IF ISNULL(@cChildSerialNo,'')  <> ''   
            BEGIN   
                 
               SET @cSerialType = RIGHT ( @cChildSerialNo , 1 )   
              
               IF @cSerialType = ( '9' )   
               BEGIN  
                  SET @nErrNo = 113207  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialType  
                  --SET @cChildSerialNo = ''   
                  EXEC rdt.rdtSetFocusField @nMobile, 2  
                  GOTO Step_2_Fail  
               END  
                
              
               IF NOT EXISTS ( SELECT 1 FROM rdt.rdtserialNoLog WITH (NOLOCK)   
                              WHERE StorerKey = @cStorerKey  
                              AND Status = '5'   
                              AND Func = @nFromFunc  
                              AND ParentSerialNo = @cChildSerialNo )    
               BEGIN  
                  SET @nErrNo = 113208      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SerialNoNotExist  
                  --SET @cChildSerialNo = ''  
                  EXEC rdt.rdtSetFocusField @nMobile, 2   
                  GOTO Step_2_Fail      
               END  
              
               IF EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)   
                                    WHERE SKU = @cSKU  
                                    AND ParentSerialNo = @cChildSerialNo  
                                    AND StorerKey = @cStorerKey  )   
               BEGIN  
                  SET @nErrNo = 113209      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialNo      
                  --SET @cChildSerialNo = ''  
                  EXEC rdt.rdtSetFocusField @nMobile, 2   
                  GOTO Step_2_Fail      
               END  
     
               IF EXISTS ( SELECT 1 FROM rdt.rdtserialNoLog WITH (NOLOCK)   
                           WHERE StorerKey = @cStorerKey  
                           AND Status = '5'   
                           AND Func = @nFromFunc  
                           AND ParentSerialNo = @cChildSerialNo  
                           AND BatchKey2 <> ''  
                           AND Func2 <> ''  )   
               BEGIN  
                  SET @nErrNo = 113220      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SerialNoScanned      
                  --SET @cChildSerialNo = ''  
                  EXEC rdt.rdtSetFocusField @nMobile, 2   
                  GOTO Step_2_Fail      
               END  
            END  
            ELSE  
            BEGIN  
               EXEC rdt.rdtSetFocusField @nMobile, 2   
               GOTO Step_2_Fail   
                 
            END  
         END  
           
         IF @nFromFunc = 0   
         BEGIN  
            SELECT TOP 1 @nFromFunc = Func   
            FROM rdt.rdtSerialNoLog WITH (NOLOCK)   
            WHERE StorerKey = @cStorerKey  
            AND FromSKU     = @cSKU  
            AND SourceKey   = @cWorkOrderNo  
            AND Status      = '5'  
            AND ParentSerialNo = @cChildSerialNo  
         END  
           
         IF EXISTS ( SELECT 1 FROM rdt.rdtSerialNoLog WITH (NOLOCK)   
                     WHERE StorerKey = @cStorerKey  
                     AND Status = '5'  
                     AND FromSKU = @cSKU  
                     AND SourceKey = @cWorkOrderNo  
                     AND Func = @nFromFunc  
                     --AND AddWho = @cUserName  
                     --AND ParentSerialNo = @cChildSerialNo  
                     --AND SerialType = @nMobile  
                     AND BatchKey2 <> ''  )   
         BEGIN  
            SELECT TOP 1 @cBatchKey = BatchKey2   
            FROM rdt.rdtSerialNoLog WITH (NOLOCK)   
            WHERE StorerKey = @cStorerKey  
            AND Status <> '9'   
            AND FromSKU = @cSKU  
            AND SourceKey = @cWorkOrderNo  
            AND Func = @nFromFunc  
            AND BatchKey2 <> ''  
            --AND SerialType = @nMobile  
            --AND AddWho = @cUserName   
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
               SET @nErrNo = 113210  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetKeyFail  
               GOTO Step_2_Fail  
            END  
              
         END    
           
           
           
         UPDATE rdt.rdtSerialNoLog WITH (ROWLOCK)   
            SET  BatchKey2 = @cBatchKey  
               , Func2 = @nFunc  
         WHERE StorerKey = @cStorerKey  
         AND FromSKU     = @cSKU  
         --AND BatchKey    = @cBatchKey  
         AND SourceKey   = @cWorkOrderNo  
         AND Func        = @nFromFunc  
         --AND AddWho      = @cUserName   
         AND Status      = '5'  
         AND ParentSerialNo = @cChildSerialNo  
           
         IF @@ERROR <> 0   
         BEGIN  
            SET @nErrNo = 113211      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdSerialLogFail      
            --SET @cChildSerialNo = ''  
            EXEC rdt.rdtSetFocusField @nMobile, 2   
            GOTO Step_2_Fail      
         END  
     
         SELECT @nScanCount = COUNT ( RowRef )   
         FROM rdt.rdtSerialNoLog WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey  
         AND FromSKU     = @cSKU  
         AND BatchKey2   = @cBatchKey  
         AND SourceKey   = @cWorkOrderNo  
         AND Func        = @nFromFunc  
         --AND AddWho      = @cUserName   
         AND Status      = '5'  
         --AND SerialType = @nMobile  
           
           
           
         IF @nInnerQty > 0   
         BEGIN  
            IF @nCaseCnt = @nScanCount --@nInnerQty = @nScanCount  
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
              
              
         END  
      
           
          
           
         SET @cOutField01 =  @cSKU  
         SET @cOutField02 =  ''  
           
           
         SELECT @nInnerCount = COUNT ( Distinct ParentSerialNo )   
         FROM rdt.rdtSerialNoLog WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey  
         AND FromSKU     = @cSKU  
         AND BatchKey2   = @cBatchKey  
         AND SourceKey   = @cWorkOrderNo  
         AND Func        = @nFromFunc  
         --AND AddWho      = @cUserName   
         AND Status      = '5'  
         --AND SerialType = @nMobile  
           
         --SET @nTotalMasterCount = @nCaseCnt / @nInnerQty  
           
      
         SET @cOutField03 =  CAST(@nInnerCount AS NVARCHAR(5))  + '/' + CAST(@nTotalMasterCount AS NVARCHAR(5))   
     
           
         EXEC rdt.rdtSetFocusField @nMobile, 2   
      END      
      ELSE
      BEGIN
         SET @cOutField01 = @cSKUInput  
         SET @cOutField02 = ''  
         
         EXEC rdt.rdtSetFocusField @nMobile, 2  
      END
       
              
   END  -- Inputkey = 1        
           
   IF @nInputKey = 0         
   BEGIN        
      
  
      IF NOT EXISTS ( SELECT 1 FROM rdt.rdtSerialNoLog WITH (NOLOCK)   
          WHERE StorerKey = @cStorerKey  
         AND FromSKU     = @cSKU  
         AND BatchKey2   = @cBatchKey  
         AND SourceKey   = @cWorkOrderNo  
         AND Func        = @nFromFunc  
         --AND AddWho      = @cUserName   
         AND Status      = '5' )   
      BEGIN  
          SET @cOutField01 = ''  
          SET @cOutField02 = ''     
            
          -- GOTO Option Screen        
          SET @nScn = @nScn - 1    
          SET @nStep = @nStep - 1   
     END  
   ELSE  
   BEGIN  
     -- Prepare Previous Screen Variable        
     SET @cOutField01 = @cSKU  
     SET @cOutField02 = ''     
                  
     -- GOTO Option Screen        
     SET @nScn = @nScn + 2      
     SET @nStep = @nStep + 2        
               
     EXEC rdt.rdtSetFocusField @nMobile, 1    
   END  
   END        
   GOTO Quit        
           
   Step_2_Fail:        
   BEGIN        
     
        
  
      -- UPDATE rdt.rdtSerialNoLog when Error  
--      UPDATE rdt.rdtSerialNoLog WITH (ROWLOCK)   
--      SET BatchKey2 = ''  
--            , Func2 = 0  
--      WHERE StorerKey = @cStorerKey  
--      AND FromSKU     = @cSKU  
--      AND BatchKey2   = @cBatchKey  
--      AND SourceKey   = @cWorkOrderNo  
--      AND Func        = @nFromFunc  
--      AND Func2       = @nFunc  
--      AND Status      = '5'  
--      AND ParentSerialNo = @cChildSerialNo  
--        
--        
--      IF @@ERROR <> 0  
--      BEGIN  
--         SET @nErrNo = 113219      
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelrdtSerailFail      
--         SET @cChildSerialNo = ''  
--         --EXEC rdt.rdtSetFocusField @nMobile, 2   
--      END  
  
      SET @cChildSerialNo = ''   
              
      -- Prepare Next Screen Variable        
      SET @cOutField01 = @cSKU     
      SET @cOutField02 = ''     
        
        
              
   END        
        
END         
GOTO QUIT     
   
/********************************************************************************        
Step 3. Scn = 5002.         
         
   SKU             (field01)        
   Master SerialNo (field02, input)        
    
           
********************************************************************************/        
Step_3:        
BEGIN        
   IF @nInputKey = 1        
   BEGIN        
      SET @cMasterSKU        = ISNULL(RTRIM(@cInField02),'')     
      SET @cMasterSerialNo   = ISNULL(RTRIM(@cInField03),'')     
        
      --SET @cMasterSerialNo = '1807FSAR779M'  
        
        
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
         SET @nErrNo = 113223        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKUReq'  
         SET @cMasterSKU = ''   
         EXEC rdt.rdtSetFocusField @nMobile, 2  
         GOTO Step_3_Fail      
      END        
        
      -- Get SKU barcode count      
      --DECLARE @nSKUCnt INT      
      EXEC rdt.rdt_GETSKUCNT      
          @cStorerKey  = @cStorerKey      
         ,@cSKU        = @cMasterSKU      
         ,@nSKUCnt     = @nSKUCnt       OUTPUT      
         ,@bSuccess    = @b_Success     OUTPUT      
         ,@nErr        = @nErrNo        OUTPUT      
         ,@cErrMsg     = @cErrMsg       OUTPUT      
        
      -- Check SKU/UPC      
      IF @nSKUCnt = 0      
      BEGIN      
         SET @nErrNo = 113224      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU    
         SET @cMasterSKU = ''   
         EXEC rdt.rdtSetFocusField @nMobile, 2  
         GOTO Step_3_Fail        
      END      
        
      -- Check multi SKU barcode      
      IF @nSKUCnt > 1      
      BEGIN      
         SET @nErrNo = 113225   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod      
         SET @cMasterSKU = ''   
         EXEC rdt.rdtSetFocusField @nMobile, 2  
         GOTO Step_3_Fail         
      END      
        
      -- Get SKU code      
      EXEC rdt.rdt_GETSKU      
          @cStorerKey  = @cStorerKey      
         ,@cSKU        = @cMasterSKU     OUTPUT      
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
         SET @nErrNo = 113226   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- WrongSKU      
         SET @cMasterSKU = ''   
         EXEC rdt.rdtSetFocusField @nMobile, 2  
         GOTO Step_3_Fail     
      END  
       
       
--      IF @cMasterSerialNo = ''        
--      BEGIN        
--         SET @nErrNo = 113212        
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ParentSerialReq'  
--         SET @cMasterSerialNo = ''   
--         EXEC rdt.rdtSetFocusField @nMobile, 3  
--         GOTO Step_3_Fail      
--      END        
      
      IF ISNULL(@cMasterSerialNo, '') <> ''
      BEGIN 
        
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'SERIALNO', @cMasterSerialNo) = 0  
         BEGIN  
               SET @nErrNo = 113231  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialNo  
               SET @cMasterSerialNo = ''   
               EXEC rdt.rdtSetFocusField @nMobile, 3  
               GOTO Step_3_Fail    
         END  
           
         SET @cSerialType = RIGHT ( @cMasterSerialNo , 1 )   
           
         IF @cSerialType <> 'M'  
         BEGIN  
            SET @nErrNo = 113213  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialType  
            GOTO Step_3_Fail  
         END  
     
         IF EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)   
                            WHERE SKU = @cSKU  
                            AND ParentSerialNo = @cMasterSerialNo  
                            AND StorerKey = @cStorerKey   )   
         BEGIN  
            SET @nErrNo = 113214      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialNo     
            SET @cMasterSerialNo = ''   
            EXEC rdt.rdtSetFocusField @nMobile, 3   
            GOTO Step_3_Fail      
         END  
           
         IF EXISTS ( SELECT 1 FROM rdt.rdtserialNoLog WITH (NOLOCK)   
                     WHERE StorerKey = @cStorerKey  
                     AND Status <> '9'   
                     AND Func = @nFromFunc   
                     AND Remarks = @cMasterSerialNo )    
         BEGIN  
            SET @nErrNo = 113215      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SerialNoScanned    
            SET @cMasterSerialNo = ''   
            EXEC rdt.rdtSetFocusField @nMobile, 3    
            GOTO Step_3_Fail      
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
                    @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cWorkOrderNo, @nFromFunc, @cBatchKey, @cSKU, @cMasterserialNo, @nErrNo OUTPUT, @cErrMsg OUTPUT   
     
               IF @nErrNo <> 0  
                  GOTO Step_3_Fail  
            END  
         END  
           
           
           
         SET @cOutField01 = ''     
         SET @cOutField02 = ''     
         SET @cOutField03 = ''    
                     
         -- GOTO Previous Screen        
         SET @nScn = @nScn - 1        
         SET @nStep = @nStep - 1      
           
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
           
   Step_3_Fail:        
   BEGIN        
        
      -- Prepare Next Screen Variable        
        
      SET @cOutField01 = @cSKU     
      SET @cOutField02 = @cMasterSKU  
      SET @cOutField03 = @cMasterSerialNo  
        
        
              
   END        
        
END    
GOTO QUIT   
  
/********************************************************************************        
Step 4. Scn = 5003.         
         
   SKU             (field01)        
   Option          (field02, input)        
    
           
********************************************************************************/        
Step_4:        
BEGIN        
   IF @nInputKey = 1        
   BEGIN        
        
      SET @cOption   = ISNULL(RTRIM(@cInField02),'')     
  
     
        
      IF @cOption = ''        
      BEGIN        
         SET @nErrNo = 113221        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OptionReq'  
         GOTO Step_4_Fail      
      END        
        
      IF @cOption NOT IN ( '1', '9' )   
      BEGIN  
         SET @nErrNo = 113222        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidOption'  
         GOTO Step_4_Fail      
      END  
        
      IF @cOption = '1'   
      BEGIN  
         SELECT @nInnerCount = COUNT ( Distinct ParentSerialNo )   
         FROM rdt.rdtSerialNoLog WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey  
         AND FromSKU     = @cSKU  
         AND BatchKey2   = @cBatchKey  
         AND SourceKey   = @cWorkOrderNo  
         AND Func        = @nFromFunc  
         --AND AddWho      = @cUserName   
         AND Status      = '5'  
         --AND SerialType = @nMobile  
           
         SET @nTotalMasterCount = @nCaseCnt / @nInnerQty  
        
         SET @cOutField01 =  @cSKU  
         SET @cOutField02 =  ''  
           
         SET @cOutField03 =  CAST(@nInnerCount AS NVARCHAR(5))  + '/' + CAST(@nTotalMasterCount AS NVARCHAR(5))   
           
         --EXEC rdt.rdtSetFocusField @nMobile, 2   
           
         SET @nScn = @nScn - 2        
         SET @nStep = @nStep - 2    
           
      END  
      ELSE IF @cOption = '9'  
      BEGIN  
           
              
         SET @cOutField01 = @cSKU     
         SET @cOutField02 = ''     
         SET @cOutField03 = ''    
         SET @cOutField04 = ''    
         SET @cOutField05 = ''    
         SET @cOutField06 = ''    
           
                  
         -- GOTO Previous Screen        
         SET @nScn = @nScn - 1        
         SET @nStep = @nStep - 1    
             
           
         EXEC rdt.rdtSetFocusField @nMobile, 1          
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
           
   Step_4_Fail:        
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
      
      V_Integer1 = @n9LQty,
      V_Integer2 = @nInnerQty,
      V_Integer3 = @nMasterQty,
      V_Integer4 = @nFromFunc,
      
      V_String1 = @cWorkOrderNo  ,      
      V_String2 = @cOption       ,      
      --V_String3 = @n9LQty        ,      
      --V_String4 = @nInnerQty     ,      
      --V_String5 = @nMasterQty    ,      
      --V_String6 = @nTotalMasterQty,  
      V_String6 = @cGenSerialSP,  
      V_String7 = @cBatchKey,  
      --V_String8 = @nFromFunc,  
      V_String9 = @cExtendedUpdateSP,  
        
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