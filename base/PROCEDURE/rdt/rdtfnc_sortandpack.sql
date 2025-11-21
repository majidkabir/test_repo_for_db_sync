SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Store procedure: rdtfnc_SortAndPack                                  */    
/* Copyright      : LFL                                                 */    
/*                                                                      */    
/* Purpose: Sort, then pick and pack                                    */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2012-10-02 1.0  Ung      SOS257627 Created                           */    
/* 2012-11-09 1.1  James    Bug fix (james01)                           */    
/* 2012-11-25 1.2  James    SOS262231 Show/Use qty from SKU.Busr10      */
/*                                    Add Carton Type screen (james02)  */
/* 2012-12-20 1.3  James    Add custom fetch task SP (james03)          */
/*                          Add extended info & do not pack confirm if  */
/*                          sostatus = 'HOLD'                           */
/* 2013-02-05 1.4  James    Set consignee = '' to prevent get task      */
/*                          error (james04)                             */
/* 2013-03-27 1.5  James    SOS273489 - Add customized stored proc to   */
/*                          get carton type to display (james05)        */
/* 2013-08-27 1.6  James    SOS287522 - Clear label no field if not pass*/
/*                          validation (james06)                        */
/*                          Exclude Orders with UD04 = 'M'              */
/* 2013-11-13 1.7  ChewKP   Addtional Validation (ChewKP01)             */
/* 2013-11-20 1.8  James    Change ext info SP parameters (james07)     */
/* 2014-01-02 1.9  James    SOS299487 - Add decode label (james08)      */
/* 2014-01-03 2.0  James    SOS299153 - Modify to make compatible with  */
/*                          IDX TEMPE goods (james09)                   */
/* 2014-01-16 2.1  James    Clear orderkey for each new sku to get      */
/*                          correct loc seq (james10)                   */
/* 2014-03-20 1.2  TLTING   Bug fix                                     */
/* 2014-04-01 2.2  Chee     OUTPUT LabelNo from ExtendedInfo SOS#307177 */
/*                          Fix @cRemoveConsigneePrefix Bug             */
/*                          Get PickSlipNo by LoadKey                   */
/*                          Added Close Carton Function                 */
/*                          Added rdt.StorerConfig - PreventManualInput */
/*                          to prevent input into Labelno field         */
/*                          Added UCC Field in Screen 2                 */
/*                          Additional Error output parameters for      */
/*                          ExtendedInfoSP (Chee01)                     */
/* 2014-05-14 2.3  ChewKP   Fixed data truncation on RDTSTDEVENTLOG     */
/*                          (ChewKP01)                                  */
/* 2014-05-21 2.4  Chee     Add ExtendedValidateSP                      */
/*                          Add Mobile parameter in ExtInfoSP (Chee02)  */
/* 2014-07-27 2.5  Chee     Add new @nFunc = 547 for ANF (Chee03)       */
/* 2014-09-23 2.6  Chee     Bug Fix (Chee04)                            */
/* 2016-09-30 2.7  Ung      Performance tuning                          */   
/* 2017-01-16 2.8  James    WMS907 - Change RDT config (james11)        */
/*                          ShowcartonTypeScreen to stored proc enabled */
/* 2017-05-16 2.9  CheeMun  IN00346713 - Extend Field size.             */
/* 2018-03-26 3.0  James    WMS4203-Enable sort and pack on multiple    */
/*                          loadkey (james12)                           */
/* 2018-10-08 3.1  Gan      Performance tuning                          */
/* 2020-06-09 3.2  Ung      WMS-13538 Fix DisableSKUField               */
/* 2019-08-20 3.3  James    WMS-10124 Add eventlog @ step 8 (james13)   */  
/* 2021-02-19 3.4  James    WMS-15660 Add Auto generate LabelNo(james14)*/
/* 2021-08-12 3.5  James    Fix carton closed but still prompt old      */
/*                          labelno (james15)                           */
/************************************************************************/    
    
CREATE PROC [RDT].[rdtfnc_SortAndPack] (    
   @nMobile    INT,    
   @nErrNo     INT  OUTPUT,    
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max    
) AS    
    
SET NOCOUNT ON    
SET ANSI_NULLS OFF    
SET QUOTED_IDENTIFIER OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    
    
-- Misc variable    
DECLARE 
   @b_Success     INT,     
   @cExtendedInfo NVARCHAR(20),    
   @cSQL          NVARCHAR(1000),     
   @cSQLParam     NVARCHAR(1000)    
    
-- RDT.RDTMobRec variable    
DECLARE    
   @nFunc       INT,    
   @nScn        INT,    
   @nStep       INT,    
   @cLangCode   NVARCHAR( 3),    
   @nInputKey   INT,    
   @nMenu       INT,    
    
   @cStorerKey  NVARCHAR( 15),    
   @cFacility   NVARCHAR( 5),    
   @cUserName   NVARCHAR(18),    
   @cPrinter    NVARCHAR(10),    
    
   @cLoadKey      NVARCHAR( 10),    
   @cSKU          NVARCHAR( 20),    
   @cSKUDescr     NVARCHAR( 60),    
   @cConsigneeKey NVARCHAR( 15),    
   @cOrderKey     NVARCHAR( 10),     
   @cLabelNo      NVARCHAR( 20),    
   @nExpQTY       INT,    
    
   @nConsCNT_Total   INT,     
   @nConsCNT_Bal     INT,     
   @nConsQTY_Total   INT,     
   @nConsQTY_Bal     INT,     
   @nOrderQTY_Total  INT,     
   @nOrderQTY_Bal    INT,     
   @nSKUQTY_Total    INT,     
   @nSKUQTY_Bal      INT,     
   @cLabelNoChkSP    NVARCHAR( 20),    
   @cPackByType      NVARCHAR( 10),    
   @nPackQTY         INT,    
   @cDefaultQTY      NVARCHAR( 5),     
   @cDisableQTYField NVARCHAR( 1),    
   @cDisableSKUField NVARCHAR( 1),    
   @cExtendedInfoSP  NVARCHAR(20),     
   @cAllowSkipTask   NVARCHAR( 1),     
   @cExtendedInfo2   NVARCHAR(20),     
   
   -- (james02)
   @cRemoveConsigneePrefix    NVARCHAR( 5), 
   @cBUSR10                   NVARCHAR(30), 
   @cCartonType               NVARCHAR(10), 
   @cPickSlipNo               NVARCHAR(10), 
   @cDefaultCartonType        NVARCHAR(10), 
   @nTranCount                INT, 
   @nCartonNo                 INT, 
   @nPrevScn                  INT, 
   @nPrevStp                  INT, 
   @nTActQTY                  INT,
   @nTExpQTY                  INT,
   @nTPackQTY                 INT,
   @nSumPicked                INT,              -- (james03)
   @nSumPacked                INT,              -- (james03)
   
   @cSortAndPackGetNextTask_SP   NVARCHAR( 20),  -- (james03)
   @cPrevOrderKey                NVARCHAR( 10),  -- (james03)    
   @cSortAndPackGetCtnType_SP    NVARCHAR( 20),  -- (james05)
   
   @cDecodeSKU       NVARCHAR(20),  -- (james08)
   
   @cSortAndPackConfirmTask_SP   NVARCHAR( 20),  -- (james09)

   @cExtendedUpdateSP   NVARCHAR(20),  -- (Chee01)
   @cOption             NVARCHAR( 1),  -- (Chee01)   
   @cUCCNo              NVARCHAR(20),  -- (Chee01)   
   @c_SKU               NVARCHAR(20),  -- (Chee01) 
   @cExtendedValidateSP NVARCHAR(20),  -- (Chee02)  
   @cConvertQtySP       NVARCHAR(20),  -- (Chee04)

   @cShowCartonTypeScreen     NVARCHAR(20),  -- (james11)
   @cShowCartonTypeScreenSP   NVARCHAR(20),  -- (james11)
   @nQTY                      INT,           -- (james11)
   @cCloseCarton              NVARCHAR( 1),  -- (james11)
   @cAutoGenerateLabelNo      NVARCHAR( 1),  -- (james14)
   @cExtendedLabelNoSP        NVARCHAR( 20), -- (james14)
   @bSuccess                  INT,           -- (james14)
   
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),
   @c_oFieled11 NVARCHAR(20), @c_oFieled12 NVARCHAR(20),
   @c_oFieled13 NVARCHAR(20), @c_oFieled14 NVARCHAR(20),
   @c_oFieled15 NVARCHAR(20),

   @c_ExecStatements          NVARCHAR(4000),
   @c_ExecArguments           NVARCHAR(4000),

   @cLastLoadKey              NVARCHAR( 10),
   @cSortnPackByLoadLevel     NVARCHAR( 1),
   @cSortnPackPieceScan       NVARCHAR( 1),
   @nLoadScannedCount         INT,
   @cSortnPackFilterUOM       NVARCHAR(1),
   @cSkipPack                 NVARCHAR(1),
   @nActQTY                   INT,  
   @nIsUCC                    INT,
   
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
   @nFunc       = Func,    
   @nScn        = Scn,    
   @nStep       = Step,    
   @nInputKey   = InputKey,    
   @nMenu       = Menu,    
   @cLangCode = Lang_code,    
    
   @cStorerKey  = StorerKey,    
   @cFacility   = Facility,    
   @cUserName   = UserName,    
   @cPrinter    = Printer,    
    
   @cLoadKey      = V_LoadKey,    
   @cSKU          = V_SKU,    
   @cSKUDescr     = V_SKUDescr,    
   @cConsigneeKey = V_ConsigneeKey,    
   @cOrderKey     = V_OrderKey,     
   @cLabelNo      = V_CaseID, 
   
   @nCartonNo     = V_Cartonno,   
   
   @nExpQTY           = V_Integer1,
   @nConsCNT_Total    = V_Integer2,
   @nConsCNT_Bal      = V_Integer3,
   @nConsQTY_Total    = V_Integer4,
   @nConsQTY_Bal      = V_Integer5,
   @nOrderQTY_Total   = V_Integer6,
   @nOrderQTY_Bal     = V_Integer7,
   @nSKUQTY_Total     = V_Integer8,
   @nSKUQTY_Bal       = V_Integer9,
   @nPackQTY          = V_Integer10,
   @nLoadScannedCount = V_Integer11,
   @nActQTY           = V_Integer12,  
   @nIsUCC            = V_Integer13,
      
   @cAutoGenerateLabelNo = V_String1,
   @cLabelNoChkSP    = V_String10,    
   @cPackByType      = V_String11,    
   @cDefaultQTY      = V_String12,    
   @cDisableQTYField = V_String13,    
   @cDisableSKUField = V_String14,    
   @cExtendedInfoSP  = V_String15,     
   @cAllowSkipTask   = V_String16,     

   
   @cRemoveConsigneePrefix = V_String17, 
   @cPickSlipNo            = V_String18, 
   @cCartonType            = V_String20, 
   @cDefaultCartonType     = V_String21, 
   @cExtendedInfo          = V_String22, 
   @cExtendedUpdateSP      = V_String23, -- (Chee01)
   @cUCCNo                 = V_String24, -- (Chee01)
   @cExtendedValidateSP    = V_String25, -- (Chee02)
   @cShowCartonTypeScreenSP= V_String26, -- (james11)
   @cExtendedInfo2         = V_String27, -- (james11)
   @cShowCartonTypeScreen  = V_String28, -- (james11)
   @cCloseCarton           = V_String29, -- (james11)
   @cLastLoadKey           = V_String30, -- (james12)
   @cSortnPackByLoadLevel  = V_String31, -- (james12)
   @cSortnPackPieceScan    = V_String33, -- (james12)
   @cSortnPackFilterUOM    = V_String34, -- (james12)
   @cSkipPack              = V_String35, -- (james12)

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
    
FROM RDTMOBREC (NOLOCK)    
WHERE Mobile = @nMobile    
    
-- Redirect to respective screen    
IF @nFunc IN (540, 541, 543, 547)    -- 540=normal pick n pack; 541=piece pick n pack; 543=tempe pick n pack, 547=ANF sort and pack
BEGIN    
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 540    
   IF @nStep = 1 GOTO Step_1   -- Scn = 3230. LoadKey    
   IF @nStep = 2 GOTO Step_2   -- Scn = 3231. SKU    
   IF @nStep = 3 GOTO Step_3   -- Scn = 3232. Label    
   IF @nStep = 4 GOTO Step_4   -- Scn = 3233. QTY    
   IF @nStep = 5 GOTO Step_5   -- Scn = 3234. Message. SKU completed    
   IF @nStep = 6 GOTO Step_6   -- Scn = 3235. Option. Exit packing?    
   IF @nStep = 7 GOTO Step_7   -- Scn = 3236. Carton Type    
   IF @nStep = 8 GOTO Step_8   -- Scn = 3237. Option. Exit packing? Close Carton  

END    
RETURN -- Do nothing if incorrect step    
    
    
/********************************************************************************    
Step 0. Called from menu    
********************************************************************************/    
Step_0:    
BEGIN    
   -- Set the entry point    
   SET @nScn = 3230    
   SET @nStep = 1    

   -- Get StorerConfig    
   SET @cAllowSkipTask = rdt.RDTGetConfig( @nFunc, 'AllowSkipTask', @cStorerKey)    
   SET @cPackByType = rdt.RDTGetConfig( @nFunc, 'PackByType', @cStorerKey)    
   SET @cLabelNoChkSP = rdt.RDTGetConfig( @nFunc, 'LabelNoChkSP', @cStorerKey)    
   IF @cLabelNoChkSP = '0'    
      SET @cLabelNoChkSP = ''    
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)    
   IF @cExtendedInfoSP = '0'    
      SET @cExtendedInfoSP = ''    
   SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)    
   SET @cDisableQTYField = rdt.RDTGetConfig( @nFunc, 'DisableQTYField', @cStorerKey)    
   SET @cDisableSKUField = rdt.RDTGetConfig( @nFunc, 'DisableSKUField', @cStorerKey)    

   -- (james02)
   SET @cRemoveConsigneePrefix = rdt.RDTGetConfig( @nFunc, 'RemoveConsigneePrefix', @cStorerKey)
   -- (Chee01)
   IF @cRemoveConsigneePrefix = '0'
      SET @cRemoveConsigneePrefix = ''

   SET @cDefaultCartonType = rdt.RDTGetConfig( @nFunc, 'DefaultCartonType', @cStorerKey)
   IF @cDefaultCartonType = '0'    
      SET @cDefaultCartonType = '' 

   -- (Chee01)
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)  
   IF @cExtendedUpdateSP = '0'  
      SET @cExtendedUpdateSP = ''  

   -- (Chee02)
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)  
   IF @cExtendedValidateSP = '0'  
      SET @cExtendedValidateSP = ''  

   -- (james11)
   SET @cShowCartonTypeScreenSP =  rdt.RDTGetConfig( @nFunc, 'SHOWCARTONTYPESCREEN', @cStorerKey)
   IF @cShowCartonTypeScreenSP = '0'
      SET @cShowCartonTypeScreenSP = ''

   -- (james11)
   SET @cCloseCarton =  rdt.RDTGetConfig( @nFunc, 'CloseCarton', @cStorerKey)

   -- (james12)
   SET @cSortnPackByLoadLevel =  rdt.RDTGetConfig( @nFunc, 'SortnPackByLoadLevel', @cStorerKey)

   -- (james12)
   SET @cSortnPackPieceScan =  rdt.RDTGetConfig( @nFunc, 'SortnPackPieceScan', @cStorerKey)
   SET @cSortnPackFilterUOM =  rdt.RDTGetConfig( @nFunc, 'SortnPackFilterUOM', @cStorerKey)
   SET @cSkipPack =  rdt.RDTGetConfig( @nFunc, 'SkipPack', @cStorerKey)

   -- (james14)
   SET @cAutoGenerateLabelNo = rdt.RDTGetConfig( @nFunc, 'AutoGenerateLabelNo', @cStorerKey)

   -- Clear previous stored record
   DELETE FROM RDT.rdtSortAndPackLog
   WHERE AddWho = @cUserName
         
   -- Logging    
   EXEC RDT.rdt_STD_EventLog    
      @cActionType = '1', -- Sign in function    
      @cUserID     = @cUserName,    
      @nMobileNo   = @nMobile,    
      @nFunctionID = @nFunc,    
      @cFacility   = @cFacility,    
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   -- Prep next screen var   
   SET @cLoadKey         = ''   
   SET @cSKU             = ''
   SET @cSKUDescr        = ''
   SET @cConsigneeKey    = ''
   SET @cOrderKey        = ''
   SET @cLabelNo         = ''
   SET @cPickSlipNo      = ''
   SET @cUCCNo           = ''
   SET @cCartonType      = ''
   SET @cExtendedInfo    = ''
   SET @nExpQTY          = 0
   SET @nConsCNT_Total   = 0
   SET @nConsCNT_Bal     = 0
   SET @nConsQTY_Total   = 0
   SET @nConsQTY_Bal     = 0
   SET @nOrderQTY_Total  = 0
   SET @nOrderQTY_Bal    = 0
   SET @nSKUQTY_Total    = 0
   SET @nSKUQTY_Bal      = 0
   SET @nPackQTY         = 0
   SET @nCartonNo        = 0
   SET @cShowCartonTypeScreen = ''
   SET @cLastLoadKey = ''
   SET @nLoadScannedCount = 0
   SET @cExtendedInfo2 = ''

   SET @cOutField01 = ''  -- LoadKey  
   SET @cOutField02 = ''    
   SET @cOutField03 = ''    
   SET @cOutField04 = ''    
   SET @cOutField05 = ''    
   SET @cOutField06 = ''    
   SET @cOutField07 = ''    
   SET @cOutField08 = ''    
   SET @cOutField09 = ''    
   SET @cOutField10 = ''    
   SET @cOutField11 = ''    
   SET @cOutField12 = ''    
   SET @cOutField13 = ''   

   SET @cFieldAttr01 = ''    
   SET @cFieldAttr02 = ''    
   SET @cFieldAttr03 = ''    
   SET @cFieldAttr04 = ''    
   SET @cFieldAttr05 = ''    
   SET @cFieldAttr06 = ''    
   SET @cFieldAttr07 = ''    
   SET @cFieldAttr08 = ''    
   SET @cFieldAttr09 = ''    
   SET @cFieldAttr10 = ''    
   SET @cFieldAttr11 = ''    
   SET @cFieldAttr12 = ''    
   SET @cFieldAttr13 = ''    
   SET @cFieldAttr14 = ''    
   SET @cFieldAttr15 = ''    
    
   EXEC rdt.rdtSetFocusField @nMobile, 1    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 1. Screen = 3230    
   LOADKEY   (Field01, input)    
********************************************************************************/    
Step_1:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cLoadKey = @cInField01    
    
      -- Check blank    
      IF @cLoadKey = ''    
      BEGIN    
         IF ISNULL( @cLastLoadKey, '') = ''
         BEGIN
            SET @nErrNo = 77351    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Need LoadKey    
            GOTO Step_1_Fail    
         END
         ELSE
         BEGIN
            -- Prep next screen var    
            SET @cOutField01 = @cLoadKey    
            SET @cOutField02 = '' -- SKU    
            SET @cOutField03 = '' -- UCC    

            EXEC rdt.rdtSetFocusField @nMobile, 2
    
            SET @nScn  = @nScn + 1    
            SET @nStep = @nStep + 1    

            GOTO Quit
         END
      END    
    
      -- Check valid    
      IF NOT EXISTS( SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey)    
      BEGIN    
         SET @nErrNo = 77352    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InvalidLoadKey    
         GOTO Step_1_Fail    
      END    

      -- (ChewKP01)
      IF NOT EXISTS ( SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey AND Facility = @cFacility ) 
      BEGIN
         SET @nErrNo = 77371    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- DiffFacility    
         GOTO Step_1_Fail  
      END
      
      -- (ChewKP01) 
      IF NOT EXISTS ( SELECT 1 FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = LPD.OrderKey
                      WHERE LPD.LoadKey = @cLoadKey
                      AND O.StorerKey = @cStorerKey ) 
      BEGIN
         SET @nErrNo = 77372    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- DiffStorer    
         GOTO Step_1_Fail  
      END

      -- Check load plan status    
      IF EXISTS( SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey AND Status = '9') -- 9=Closed    
      BEGIN    
         SET @nErrNo = 77353    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- LoadKey Closed    
         GOTO Step_1_Fail    
      END    

      IF EXISTS ( SELECT 1 FROM rdt.rdtSortAndPackLog WITH (NOLOCK) 
                  WHERE LoadKey = @cLoadKey
                  AND   AddWho = @cUserName
                  AND   Status < '9')    
      BEGIN
         SET @nErrNo = 77376    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Load Scanned    
         GOTO Step_1_Fail   
      END
      ELSE
      BEGIN
         INSERT INTO rdt.rdtSortAndPackLog (	Mobile, Username,	StorerKey, LoadKey, [Status])
         VALUES
         (@nMobile, @cUserName, @cStorerKey, @cLoadKey, '0')

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 77377    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InsertLog Fail    
            GOTO Step_1_Fail   
         END

         SET @nLoadScannedCount = @nLoadScannedCount + 1

         IF @cSortnPackByLoadLevel = '1'
         BEGIN
            -- Remain in same screen for continuous   loadkey scanning
            SET @cLastLoadKey = @cLoadKey
            SET @cExtendedInfo = ''
            SET @cExtendedInfo2 = ''

            SET @cOutField01 = ''  -- LoadKey  
            SET @cOutField02 = @cLastLoadKey
            SET @cOutField03 = @nLoadScannedCount

            GOTO Quit
         END
         ELSE
         BEGIN
            -- Prep next screen var    
            SET @cOutField01 = @cLoadKey    
            SET @cOutField02 = '' -- SKU    
            SET @cOutField03 = '' -- UCC    

            EXEC rdt.rdtSetFocusField @nMobile, 2
    
            SET @nScn  = @nScn + 1    
            SET @nStep = @nStep + 1    

            GOTO Quit
         END
      END
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Logging    
      EXEC RDT.rdt_STD_EventLog    
         @cActionType = '9', -- Sign Out function    
         @cUserID     = @cUserName,    
         @nMobileNo   = @nMobile,    
         @nFunctionID = @nFunc,    
         @cFacility   = @cFacility,    
         @cStorerKey  = @cStorerkey,
         @nStep       = @nStep
    
      -- Back to menu    
      SET @nFunc = @nMenu    
      SET @nScn  = @nMenu    
      SET @nStep = 0    
      SET @cOutField01 = '' -- Clean up for menu option    
      SET @cLastLoadKey = ''
      
      SET @cFieldAttr01 = ''    
      SET @cFieldAttr02 = ''    
      SET @cFieldAttr03 = ''    
      SET @cFieldAttr04 = ''    
      SET @cFieldAttr05 = ''          
      SET @cFieldAttr06 = ''    
      SET @cFieldAttr07 = ''    
      SET @cFieldAttr08 = ''    
      SET @cFieldAttr09 = ''    
      SET @cFieldAttr10 = ''    
      SET @cFieldAttr11 = ''    
      SET @cFieldAttr12 = ''    
      SET @cFieldAttr13 = ''    
      SET @cFieldAttr14 = ''    
      SET @cFieldAttr15 = ''    
   END    
   GOTO Quit    
    
   Step_1_Fail:    
   BEGIN    
      SET @cLoadKey = ''    
      SET @cOutField01 = ''    
   END    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 2. Screen = 3231    
   LOADKEY   (Field01)    
   SKU       
   (Field02, input)  
   UCC
   (Field03, input)          
********************************************************************************/    
Step_2:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cSKU = @cInField02    
      SET @cUCCNo = @cInField03 -- Chee01
    
      -- Check blank    
      IF @cSKU = '' AND @cUCCNo = ''
      BEGIN    
         SET @nErrNo = 77354    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU    
         GOTO Step_2_Fail    
      END    

      IF @cSKU <> ''
      BEGIN
         SET @nIsUCC = 0

         -- Decode SKU (james08)
         SET @cDecodeSKU = ''    
         SET @cDecodeSKU = rdt.RDTGetConfig( @nFunc, 'DecodeSKU', @cStorerkey)    

         IF ISNULL(@cDecodeSKU,'') NOT IN ('', '0')
         BEGIN    
            EXEC dbo.ispLabelNo_Decoding_Wrapper    
             @c_SPName     = @cDecodeSKU    
            ,@c_LabelNo    = @cSKU    
            ,@c_Storerkey  = @cStorerkey    
            ,@c_ReceiptKey = @nMobile    
            ,@c_POKey      = ''    
            ,@c_LangCode   = @cLangCode    
            ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU    
            ,@c_oFieled02  = @c_oFieled02 OUTPUT       
            ,@c_oFieled03  = @c_oFieled03 OUTPUT       
            ,@c_oFieled04  = @c_oFieled04 OUTPUT       
            ,@c_oFieled05  = @c_oFieled05 OUTPUT        
            ,@c_oFieled06  = @c_oFieled06 OUTPUT        
            ,@c_oFieled07  = @c_oFieled07 OUTPUT    
            ,@c_oFieled08  = @c_oFieled08 OUTPUT    
            ,@c_oFieled09  = @c_oFieled09 OUTPUT    
            ,@c_oFieled10  = @c_oFieled10 OUTPUT    
            ,@b_Success    = @b_Success   OUTPUT    
            ,@n_ErrNo      = @nErrNo      OUTPUT    
            ,@c_ErrMsg     = @cErrMsg     OUTPUT   
       
            IF ISNULL(@cErrMsg, '') <> ''    
            BEGIN    
               SET @cErrMsg = @cErrMsg    
               GOTO Step_2_Fail    
            END    
       
            SET @cSKU = @c_oFieled01      -- assign output to sku code
            SET @c_oFieled01 = ''         -- Reinitiase the variable
         END    

         -- Get SKU count    
         DECLARE @nSKUCnt INT    
         EXEC [RDT].[rdt_GETSKUCNT]    
             @cStorerKey  = @cStorerKey    
            ,@cSKU        = @cSKU    
            ,@nSKUCnt     = @nSKUCnt       OUTPUT    
            ,@bSuccess    = @b_Success     OUTPUT    
            ,@nErr        = @nErrNo        OUTPUT    
            ,@cErrMsg     = @cErrMsg       OUTPUT    
       
         -- Validate SKU/UPC    
         IF @nSKUCnt = 0    
         BEGIN    
            SET @nErrNo = 77355    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU    
            GOTO Step_2_Fail    
         END    
       
         -- Validate barcode return multiple SKU    
         IF @nSKUCnt > 1    
         BEGIN    
            SET @nErrNo = 77356    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameBarCodeSKU    
            GOTO Step_2_Fail    
         END    
       
         -- Get SKU    
         EXEC [RDT].[rdt_GETSKU]    
             @cStorerKey  = @cStorerKey    
            ,@cSKU        = @cSKU          OUTPUT    
            ,@bSuccess    = @b_Success     OUTPUT    
            ,@nErr        = @nErrNo        OUTPUT    
            ,@cErrMsg     = @cErrMsg       OUTPUT    
       
         -- Check SKU in load plan    
         /*IF NOT EXISTS( SELECT TOP 1 1     
            FROM dbo.PickDetail PD WITH (NOLOCK)    
               JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
            WHERE PD.StorerKey = @cStorerKey    
               AND PD.SKU = @cSKU    
               AND LPD.LoadKey = @cLoadKey)    */
         IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
                         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                         JOIN rdt.rdtSortAndPackLog SAP WITH (NOLOCK) ON ( O.LoadKey = SAP.LoadKey)
                         WHERE PD.StorerKey = @cStorerKey
                         AND   PD.SKU = @cSKU
                         --AND   O.LoadKey = @cLoadKey
                         AND   ISNULL(OD.UserDefine04, '') <> 'M' -- (james06)
                         AND   SAP.UserName = @cUserName
                         AND SAP.Status = '0')
         BEGIN    
            SET @nErrNo = 77357    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotIn Load    
            GOTO Step_2_Fail    
         END    
       
         -- Check if same SKU more then 1 user handle    
         DECLARE @cOtherUserName NVARCHAR( 18)    
         SET @cOtherUserName = ''    
         SELECT TOP 1 @cOtherUserName = UserName  -- (james01)  
         FROM rdt.rdtMobRec WITH (NOLOCK)    
         WHERE Func = @nFunc    
            AND StorerKey = @cStorerKey    
            AND V_LoadKey = @cLoadKey    
            AND V_SKU = @cSKU    
            AND UserName <> @cUserName    
            AND Step > 2    
         ORDER BY EditDate DESC    
         IF @cOtherUserName <> ''    
         BEGIN    
            SET @nErrNo = 77358    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKULockByUser    
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg, @cOtherUserName    
            GOTO Step_2_Fail    
         END    
       
         -- Get SKU info    
         SELECT 
            @cSKUDescr = Descr, 
            @cBUSR10 = BUSR10    -- (james02)
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
         AND   SKU = @cSKU    
       
   /*    
         -- Auto scan-in    
         IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE  PickSlipNo = @cPickSlipNo)    
         BEGIN    
            EXEC dbo.isp_ScanInPickslip    
               @c_PickSlipNo = @cPickSlipNo,    
               @c_PickerID   = @cUserName,    
               @n_err        = @nErrNo     OUTPUT,    
               @c_errmsg     = @cErrMsg     OUTPUT    
            IF @nErrNo <> 0    
            BEGIN    
               SET @nErrNo = 77358    
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Scan In Fail    
               GOTO Step_2_Fail    
             END    
         END    
   */    

         -- Get next task    
         -- (james03)
         SET @nErrNo = 0
         SET @cConsigneeKey = '' -- (james04)
         SET @cOrderKey = ''     -- (james10)
         SET @cSortAndPackGetNextTask_SP = rdt.RDTGetConfig( @nFunc, 'SortAndPackGetNextTask_SP', @cStorerKey)
         IF ISNULL(@cSortAndPackGetNextTask_SP, '') NOT IN ('', '0')
         BEGIN
            EXEC RDT.RDT_SortAndPackGetNextTask_Wrapper
                @n_Mobile        = @nMobile
               ,@n_Func          = @nFunc
               ,@c_LangCode      = @cLangCode
               ,@c_SPName        = @cSortAndPackGetNextTask_SP
               ,@c_PackByType    = @cPackByType
               ,@c_Type          = 'NEXT'
               ,@c_LoadKey       = @cLoadKey
               ,@c_Storerkey     = @cStorerKey
               ,@c_SKU           = @cSKU
               ,@c_ConsigneeKey  = @cConsigneeKey  OUTPUT
               ,@c_OrderKey      = @cOrderKey      OUTPUT
               ,@c_oFieled01     = @c_oFieled01    OUTPUT
               ,@c_oFieled02     = @c_oFieled02    OUTPUT
               ,@c_oFieled03     = @c_oFieled03    OUTPUT
               ,@c_oFieled04     = @c_oFieled04    OUTPUT
               ,@c_oFieled05     = @c_oFieled05    OUTPUT
               ,@c_oFieled06     = @c_oFieled06    OUTPUT
               ,@c_oFieled07     = @c_oFieled07    OUTPUT
               ,@c_oFieled08     = @c_oFieled08    OUTPUT
               ,@c_oFieled09     = @c_oFieled09    OUTPUT
               ,@c_oFieled10     = @c_oFieled10    OUTPUT
               ,@c_oFieled11     = @c_oFieled11    OUTPUT
               ,@c_oFieled12     = @c_oFieled12    OUTPUT
               ,@c_oFieled13     = @c_oFieled13    OUTPUT
               ,@c_oFieled14     = @c_oFieled14    OUTPUT
               ,@c_oFieled15     = @c_oFieled15    OUTPUT
               ,@b_Success       = @b_Success      OUTPUT
               ,@n_ErrNo         = @nErrNo         OUTPUT
               ,@c_ErrMsg        = @cErrMsg        OUTPUT

               SET @nExpQTY         = CAST(@c_oFieled01 AS INT)
               SET @nConsCNT_Total  = CAST(@c_oFieled02 AS INT)
               SET @nConsCNT_Bal    = CAST(@c_oFieled03 AS INT)
               SET @nConsQTY_Total  = CAST(@c_oFieled04 AS INT)
               SET @nConsQTY_Bal    = CAST(@c_oFieled05 AS INT)
               SET @nOrderQTY_Total = CAST(@c_oFieled06 AS INT)
               SET @nOrderQTY_Bal   = CAST(@c_oFieled07 AS INT)
               SET @nSKUQTY_Total   = CAST(@c_oFieled08 AS INT)
               SET @nSKUQTY_Bal     = CAST(@c_oFieled09 AS INT)
               SET @cLabelNo        = @c_oFieled11
         END
         ELSE
         BEGIN
            EXEC rdt.rdt_SortAndPack_GetTask @nMobile, @nFunc, @cLangCode, @cPackByType, 'NEXT', @cLoadKey, @cStorerKey, @cSKU    
            ,@cConsigneeKey   OUTPUT    
            ,@cOrderKey       OUTPUT    
            ,@nExpQTY         OUTPUT    
            ,@nConsCNT_Total  OUTPUT    
            ,@nConsCNT_Bal    OUTPUT    
            ,@nConsQTY_Total  OUTPUT    
            ,@nConsQTY_Bal    OUTPUT    
            ,@nOrderQTY_Total OUTPUT    
            ,@nOrderQTY_Bal   OUTPUT    
            ,@nSKUQTY_Total   OUTPUT    
            ,@nSKUQTY_Bal     OUTPUT    
            ,@nErrNo          OUTPUT    
            ,@cErrMsg         OUTPUT    
         END
               
         IF @nErrNo <> 0    
            GOTO Step_2_Fail    

         -- Extended info    
         IF @cExtendedInfoSP <> ''    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
            BEGIN    
               SET @cExtendedInfo = ''    

               SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +     
                  ' @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT' +
                  ' ,@cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT' + -- (Chee01)
                  ' ,@nMobile' -- (Chee02)
    
               SET @cSQLParam =    
                  '@cLoadKey        NVARCHAR( 10), ' +    
                  '@cOrderKey       NVARCHAR( 10), ' +   -- (james07)
                  '@cConsigneeKey   NVARCHAR( 15), ' +    
                  '@cLabelNo        NVARCHAR( 20), ' +    
                  '@cStorer         NVARCHAR( 15), ' +      
                  '@cSKU            NVARCHAR( 20), ' +      
                  '@nExpQTY         INT,       ' +      
                  '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
                  '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +
                  '@cLangCode       NVARCHAR( 3),         ' + -- (Chee01)
                  '@bSuccess        INT           OUTPUT, ' + -- (Chee01)
                  '@nErrNo          INT           OUTPUT, ' + -- (Chee01)
                  '@cErrMsg         NVARCHAR( 20) OUTPUT, ' + -- (Chee01)
                  '@nMobile         INT '  -- (Chee02)

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                  @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT
                  , @cLangCode, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT  -- (Chee01)
                  , @nMobile -- (Chee02)

               -- (Chee01)
               IF @nErrNo <> 0    
                  GOTO Step_2_Fail 
       
               -- Prepare extended fields    
               IF @cExtendedInfo <> '' SET @cOutField07 = @cExtendedInfo    
            END    
         END    
      END -- @cSKU <> ''
      ELSE
      BEGIN
         -- Pass UCCNO in @c_oFieled10 field
         SET @c_oFieled10 = @cUCCNo
         SET @nIsUCC = 1
         
         SET @cSortAndPackGetNextTask_SP = rdt.RDTGetConfig( @nFunc, 'SortAndPackGetNextTask_SP', @cStorerKey)
         IF ISNULL(@cSortAndPackGetNextTask_SP, '') NOT IN ('', '0')
         BEGIN
            EXEC RDT.RDT_SortAndPackGetNextTask_Wrapper
                @n_Mobile        = @nMobile
               ,@n_Func          = @nFunc
               ,@c_LangCode      = @cLangCode
               ,@c_SPName        = @cSortAndPackGetNextTask_SP
               ,@c_PackByType    = @cPackByType
               ,@c_Type          = 'UCC'
               ,@c_LoadKey       = @cLoadKey
               ,@c_Storerkey     = @cStorerKey
               ,@c_SKU           = @cSKU
               ,@c_ConsigneeKey  = @cConsigneeKey  OUTPUT
               ,@c_OrderKey      = @cOrderKey      OUTPUT
               ,@c_oFieled01     = @c_oFieled01    OUTPUT
               ,@c_oFieled02     = @c_oFieled02    OUTPUT
               ,@c_oFieled03     = @c_oFieled03    OUTPUT
               ,@c_oFieled04     = @c_oFieled04    OUTPUT
               ,@c_oFieled05     = @c_oFieled05    OUTPUT
               ,@c_oFieled06     = @c_oFieled06    OUTPUT
               ,@c_oFieled07     = @c_oFieled07    OUTPUT
               ,@c_oFieled08     = @c_oFieled08    OUTPUT
               ,@c_oFieled09     = @c_oFieled09    OUTPUT
               ,@c_oFieled10     = @c_oFieled10    OUTPUT
               ,@c_oFieled11     = @c_oFieled11    OUTPUT
               ,@c_oFieled12     = @c_oFieled12    OUTPUT
               ,@c_oFieled13     = @c_oFieled13    OUTPUT
               ,@c_oFieled14     = @c_oFieled14    OUTPUT
               ,@c_oFieled15     = @c_oFieled15    OUTPUT
               ,@b_Success       = @b_Success      OUTPUT
               ,@n_ErrNo         = @nErrNo         OUTPUT
               ,@c_ErrMsg        = @cErrMsg        OUTPUT

            SET @nExpQTY         = CAST(@c_oFieled01 AS INT)
            SET @nConsCNT_Total  = CAST(@c_oFieled02 AS INT)
            SET @nConsCNT_Bal    = CAST(@c_oFieled03 AS INT)
            SET @nConsQTY_Total  = CAST(@c_oFieled04 AS INT)
            SET @nConsQTY_Bal    = CAST(@c_oFieled05 AS INT)
            SET @nOrderQTY_Total = CAST(@c_oFieled06 AS INT)
            SET @nOrderQTY_Bal   = CAST(@c_oFieled07 AS INT)
            SET @nSKUQTY_Total   = CAST(@c_oFieled08 AS INT)
            SET @nSKUQTY_Bal     = CAST(@c_oFieled09 AS INT)
            SET @cSKU            = @c_oFieled10
            SET @cLabelNo        = @c_oFieled11
         END
         ELSE
         BEGIN
            -- Get next task    
            EXEC rdt.rdt_SortAndPack_GetTask @nMobile, @nFunc, @cLangCode, @cPackByType, 'NEXT', @cLoadKey, @cStorerKey, @cSKU    
               ,@cConsigneeKey   OUTPUT    
               ,@cOrderKey       OUTPUT    
               ,@nExpQTY         OUTPUT    
               ,@nConsCNT_Total  OUTPUT    
               ,@nConsCNT_Bal    OUTPUT    
               ,@nConsQTY_Total  OUTPUT    
               ,@nConsQTY_Bal    OUTPUT    
               ,@nOrderQTY_Total OUTPUT    
               ,@nOrderQTY_Bal   OUTPUT    
               ,@nSKUQTY_Total   OUTPUT    
               ,@nSKUQTY_Bal     OUTPUT    
               ,@nErrNo          OUTPUT    
               ,@cErrMsg         OUTPUT    
         END
         
         IF @nErrNo <> 0    
            GOTO Step_2_Fail    

         -- Get SKU info    
         SELECT 
            @cSKUDescr = Descr, 
            @cBUSR10 = BUSR10    -- (james02)
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
         AND   SKU = @cSKU    

         -- Extended info (Get Gen Label)
         IF @cExtendedInfoSP <> ''    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
            BEGIN    
               SET @cExtendedInfo = @cUCCNo -- (Chee02)    
                
               SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +     
                  ' @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo OUTPUT, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT' +
                  ' ,@cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT' + -- (Chee01)
                  ' ,@nMobile' -- (Chee02)
    
               SET @cSQLParam =    
                  '@cLoadKey        NVARCHAR( 10), ' +   
                  '@cOrderKey       NVARCHAR( 10), ' + 
                  '@cConsigneeKey   NVARCHAR( 15), ' +    
                  '@cLabelNo        NVARCHAR( 20) OUTPUT, ' +  
                  '@cStorer         NVARCHAR( 15), ' +      
                  '@cSKU            NVARCHAR( 20), ' +      
                  '@nExpQTY         INT,       ' +      
                  '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
                  '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +
                  '@cLangCode       NVARCHAR( 3),         ' + -- (Chee01)
                  '@bSuccess        INT           OUTPUT, ' + -- (Chee01)
                  '@nErrNo          INT           OUTPUT, ' + -- (Chee01)
                  '@cErrMsg         NVARCHAR( 20) OUTPUT, ' + -- (Chee01)
                  '@nMobile         INT '  -- (Chee02)

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                  @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo OUTPUT, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT
                  , @cLangCode, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT   -- (Chee01)
                  , @nMobile -- (Chee02)

               -- (Chee01)
               IF @nErrNo <> 0    
                  GOTO Step_2_Fail 
       
               -- Prepare extended fields    
               IF @cExtendedInfo <> '' SET @cOutField07 = @cExtendedInfo    
            END    
         END  
      END -- IF @cSKU = ''

      IF @cAutoGenerateLabelNo = '1'
      BEGIN
         SET @cExtendedLabelNoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedLabelNoSP', @cStorerKey)
         IF @cExtendedLabelNoSP NOT IN ('0', '') AND 
            EXISTS( SELECT 1 FROM sys.sysobjects WHERE name = @cExtendedLabelNoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedLabelNoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cLoadKey, @cOrderKey, @cPickSlipNo, @cSKU, @nCartonNo, ' +
               ' @cLabelNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               '@nMobile                   INT,           ' +
               '@nFunc                     INT,           ' +
               '@cLangCode                 NVARCHAR( 3),  ' +
               '@nStep                     INT,           ' +
               '@nInputKey                 INT,           ' +
               '@cStorerkey                NVARCHAR( 15), ' +
               '@cLoadKey                  NVARCHAR( 10), ' +   
               '@cOrderKey                 NVARCHAR( 10), ' + 
               '@cPickSlipNo               NVARCHAR( 10), ' +      
               '@cSKU                      NVARCHAR( 20), ' +
               '@nCartonNo                 INT,           ' +
               '@cLabelNo                  NVARCHAR( 20) OUTPUT,  ' +                     
               '@nErrNo                    INT           OUTPUT,  ' +
               '@cErrMsg                   NVARCHAR( 20) OUTPUT   '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cLoadKey, @cOrderKey, @cPickSlipNo, @cSKU, @nCartonNo, 
               @cLabelNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = 77378
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GET LABEL Fail'
               GOTO Step_2_Fail
            END
         END
         ELSE
         BEGIN
            -- Get new LabelNo
            EXECUTE isp_GenUCCLabelNo
                     @cStorerKey,
                     @cLabelNo     OUTPUT,
                     @bSuccess     OUTPUT,
                     @nErrNo       OUTPUT,
                     @cErrMsg      OUTPUT

            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 77379
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GET LABEL Fail'
               GOTO Step_2_Fail
            END
         END

         IF ISNULL( @cLabelNo, '') = ''
         BEGIN
            SET @nErrNo = 77380
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GET LABEL Fail'
            GOTO Step_2_Fail
         END
      END
            
      -- Prepare next screen var    
      SET @cOutField01 = @cSKU    
      SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)    
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)    
      -- (james02)
      SET @cOutField04 = CASE WHEN ISNULL(@cRemoveConsigneePrefix, '') > '' THEN REPLACE(RTRIM(@cConsigneeKey), RTRIM(@cRemoveConsigneePrefix), '') ELSE @cConsigneeKey END
      SET @cOutField05 = @cOrderKey    
      SET @cOutField06 = '' --LabelNo

      IF @nFunc IN (540, 541, 547) -- (Chee03)
      BEGIN
         IF @cSortnPackByLoadLevel = '1'
         BEGIN
            SET @cOutField07 = ''
            SET @cOutField08 = 'SKU  BAL: ' + CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
            SET @cOutField09 = @cExtendedInfo
            SET @cOutField10 = ''
            SET @cOutField11 = @cExtendedInfo2
         END
         ELSE
         BEGIN
            SET @cOutField07 = 'STOR BAL: ' + CAST( @nConsCNT_Bal AS NVARCHAR(5)) + '/' + CAST( @nConsCNT_Total AS NVARCHAR(5))    
            SET @cOutField08 = 'SKU  BAL: ' + CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
            SET @cOutField09 = @cExtendedInfo
            SET @cOutField10 = 'STOR QTY: ' + CAST( @nConsQTY_Bal AS NVARCHAR(10)) + '/' + CAST( @nConsQTY_Total AS NVARCHAR(10))       --IN00346713 
            SET @cOutField11 = @cExtendedInfo2
         END
      END
      ELSE IF @nFunc = 543
      BEGIN
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = @cExtendedInfo
         SET @cOutField10 = ''
         SET @cOutField11 = @cExtendedInfo2
      END
      
      -- Chee01 
      IF ISNULL(@cLabelNo, '') <> ''
         SET @cOutField06 = @cLabelNo

      -- Go to labelno screen    
      SET @nScn  = @nScn + 1    
      SET @nStep = @nStep + 1  
   END  -- IF @nInputKey = 1 -- ENTER  
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Prepare next screen var    
      SET @cLoadKey = ''    
      SET @cOutField01 = '' --LoadKey    
    
      -- Go to prev screen    
      SET @nScn  = @nScn - 1    
      SET @nStep = @nStep - 1    
   END    
   GOTO Quit    
    
   Step_2_Fail:    
   BEGIN    
      SET @cSKU = ''  
      SET @cUCCNo = ''
      SET @cLabelNo = ''
      SET @cOutField02 = '' --SKU    
      SET @cOutField03 = '' --UCC    
   END    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 3. Screen 3232    
   SKU      (Field01)    
   DESC1    (Field02)    
   DESC2    (Field03)    
   STORE    (Field04)    
   ORDERKEY (Field05)    
   LABELNO  (Field06, input)    
   STOR BAL (Field07)    
   SKU  BAL (Field08)    
********************************************************************************/    
Step_3:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Chee01
      IF rdt.RDTGetConfig( @nFunc, 'PreventManualInput', @cStorerKey) = '1'
      BEGIN
         IF ISNULL(@cInField06, '') <> '' AND @cLabelNo <> @cInField06
         BEGIN
            SET @nErrNo = 77375    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Label  
            GOTO Step_3_Fail 
         END
      END

      -- Screen mapping    
      SET @cLabelNo = @cInField06    

      -- Get next task    
      IF @cLabelNo = ''    
      BEGIN    
         IF @cAllowSkipTask = '0'    
         BEGIN    
            SET @nErrNo = 77359    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Label No    
            GOTO Step_3_Fail    
         END    

         -- (james03)
         SET @nErrNo = 0
         SET @cSortAndPackGetNextTask_SP = rdt.RDTGetConfig( @nFunc, 'SortAndPackGetNextTask_SP', @cStorerKey)
         IF ISNULL(@cSortAndPackGetNextTask_SP, '') NOT IN ('', '0')
         BEGIN
            EXEC RDT.RDT_SortAndPackGetNextTask_Wrapper
                @n_Mobile        = @nMobile
               ,@n_Func          = @nFunc
               ,@c_LangCode      = @cLangCode
               ,@c_SPName        = @cSortAndPackGetNextTask_SP
               ,@c_PackByType    = @cPackByType
               ,@c_Type          = 'NEXT'
               ,@c_LoadKey       = @cLoadKey
               ,@c_Storerkey     = @cStorerKey
               ,@c_SKU           = @cSKU
               ,@c_ConsigneeKey  = @cConsigneeKey  OUTPUT
               ,@c_OrderKey      = @cOrderKey      OUTPUT
               ,@c_oFieled01     = @c_oFieled01    OUTPUT
               ,@c_oFieled02     = @c_oFieled02    OUTPUT
               ,@c_oFieled03     = @c_oFieled03    OUTPUT
               ,@c_oFieled04     = @c_oFieled04    OUTPUT
               ,@c_oFieled05     = @c_oFieled05    OUTPUT
               ,@c_oFieled06     = @c_oFieled06    OUTPUT
               ,@c_oFieled07     = @c_oFieled07    OUTPUT
               ,@c_oFieled08     = @c_oFieled08    OUTPUT
               ,@c_oFieled09     = @c_oFieled09    OUTPUT
               ,@c_oFieled10     = @c_oFieled10    OUTPUT
               ,@c_oFieled11     = @c_oFieled11    OUTPUT
               ,@c_oFieled12     = @c_oFieled12    OUTPUT
               ,@c_oFieled13     = @c_oFieled13    OUTPUT
               ,@c_oFieled14     = @c_oFieled14    OUTPUT
               ,@c_oFieled15     = @c_oFieled15    OUTPUT
               ,@b_Success       = @b_Success      OUTPUT
               ,@n_ErrNo         = @nErrNo         OUTPUT
               ,@c_ErrMsg        = @cErrMsg        OUTPUT

            SET @nExpQTY         = CAST(@c_oFieled01 AS INT)
            SET @nConsCNT_Total  = CAST(@c_oFieled02 AS INT)
            SET @nConsCNT_Bal    = CAST(@c_oFieled03 AS INT)
            SET @nConsQTY_Total  = CAST(@c_oFieled04 AS INT)
            SET @nConsQTY_Bal    = CAST(@c_oFieled05 AS INT)
            SET @nOrderQTY_Total = CAST(@c_oFieled06 AS INT)
            SET @nOrderQTY_Bal   = CAST(@c_oFieled07 AS INT)
            SET @nSKUQTY_Total   = CAST(@c_oFieled08 AS INT)
            SET @nSKUQTY_Bal     = CAST(@c_oFieled09 AS INT)
         END
         ELSE
         BEGIN
            -- Get next task    
            EXEC rdt.rdt_SortAndPack_GetTask @nMobile, @nFunc, @cLangCode, @cPackByType, 'NEXT', @cLoadKey, @cStorerKey, @cSKU    
               ,@cConsigneeKey   OUTPUT    
               ,@cOrderKey       OUTPUT    
               ,@nExpQTY         OUTPUT    
               ,@nConsCNT_Total  OUTPUT    
               ,@nConsCNT_Bal    OUTPUT    
               ,@nConsQTY_Total  OUTPUT    
               ,@nConsQTY_Bal    OUTPUT    
               ,@nOrderQTY_Total OUTPUT    
               ,@nOrderQTY_Bal   OUTPUT    
               ,@nSKUQTY_Total   OUTPUT    
               ,@nSKUQTY_Bal     OUTPUT    
               ,@nErrNo          OUTPUT    
               ,@cErrMsg         OUTPUT    
         END
         
         IF @nErrNo <> 0    
            GOTO Step_3_Fail    

         -- Extended info    
         IF @cExtendedInfoSP <> ''    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
            BEGIN    
               SET @cExtendedInfo = ''    
                   
               SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +     
                  ' @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo OUTPUT, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT' +
                  ' ,@cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT' + -- (Chee01)
                  ' ,@nMobile' -- (Chee02)
     
               SET @cSQLParam =    
                  '@cLoadKey        NVARCHAR( 10), ' +   
                  '@cOrderKey       NVARCHAR( 10), ' +   -- (james07)
                  '@cConsigneeKey   NVARCHAR( 15), ' +    
                  '@cLabelNo        NVARCHAR( 20) OUTPUT, ' +  -- (Chee01) 
                  '@cStorer         NVARCHAR( 15), ' +      
                  '@cSKU            NVARCHAR( 20), ' +      
                  '@nExpQTY         INT,       ' +      
                  '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
                  '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +
                  '@cLangCode       NVARCHAR( 3),         ' + -- (Chee01)
                  '@bSuccess        INT           OUTPUT, ' + -- (Chee01)
                  '@nErrNo          INT           OUTPUT, ' + -- (Chee01)
                  '@cErrMsg         NVARCHAR( 20) OUTPUT, ' + -- (Chee01)
                  '@nMobile         INT '  -- (Chee02)  
                   
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                  @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo OUTPUT, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT
                  , @cLangCode, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT   -- (Chee01)
                  , @nMobile -- (Chee02)

               -- (Chee01)
               IF @nErrNo <> 0    
                  GOTO Step_3_Fail  
       
               -- Prepare extended fields    
               IF @cExtendedInfo <> '' SET @cOutField07 = @cExtendedInfo    
            END    
         END    

         -- Prepare next screen var    
         SET @cOutField01 = @cSKU    
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)    
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)    
         SET @cOutField04 = CASE WHEN ISNULL(@cRemoveConsigneePrefix, '') > '' THEN REPLACE(RTRIM(@cConsigneeKey), RTRIM(@cRemoveConsigneePrefix), '') ELSE @cConsigneeKey END
         SET @cOutField05 = @cOrderKey    
         SET @cOutField06 = '' --LabelNo    

         IF @nFunc IN (540, 541, 547) -- (Chee03)
         BEGIN
            IF @cSortnPackByLoadLevel = '1'
            BEGIN
               SET @cOutField07 = ''
               SET @cOutField08 = 'SKU  BAL: ' + CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
               SET @cOutField09 = @cExtendedInfo
               SET @cOutField10 = ''
               SET @cOutField11 = @cExtendedInfo2
            END
            ELSE
            BEGIN
               SET @cOutField07 = 'STOR BAL: ' + CAST( @nConsCNT_Bal AS NVARCHAR(5)) + '/' + CAST( @nConsCNT_Total AS NVARCHAR(5))    
               SET @cOutField08 = 'SKU  BAL: ' + CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
               SET @cOutField09 = @cExtendedInfo
               SET @cOutField10 = 'STOR QTY: ' + CAST( @nConsQTY_Bal AS NVARCHAR(10)) + '/' + CAST( @nConsQTY_Total AS NVARCHAR(10))       --IN00346713 
               SET @cOutField11 = @cExtendedInfo2
            END
         END
         ELSE IF @nFunc = 543
         BEGIN
            SET @cOutField07 = ''
            SET @cOutField08 = ''
            SET @cOutField09 = @cExtendedInfo
            SET @cOutField10 = ''
            SET @cOutField11 = @cExtendedInfo2
         END
      
         -- Chee01 
         IF ISNULL(@cLabelNo, '') <> ''
            SET @cOutField06 = @cLabelNo

         GOTO Quit    
      END    
          
      -- LabelNo extended validation    
      IF @cLabelNoChkSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cLabelNoChkSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo = ''    
                
            SET @cSQL = 'EXEC ' + RTRIM( @cLabelNoChkSP) +     
               ' @nMobile, @nFunc, @cLangCode, @cLoadKey, @cConsigneeKey, @cStorerKey, @cSKU, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile       INT,        ' +    
               '@nFunc         INT,        ' +    
               '@cLangCode     NVARCHAR(3),    ' +    
               '@cLoadKey      NVARCHAR( 10),  ' +    
               '@cConsigneeKey NVARCHAR( 15),  ' +    
               '@cStorerKey    NVARCHAR(15),   ' +    
               '@cSKU          NVARCHAR(20),   ' +    
               '@cLabelNo      NVARCHAR( 20),  ' +    
               '@nErrNo        INT OUTPUT, ' +      
               '@cErrMsg       NVARCHAR( 20) OUTPUT'    
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @cLoadKey, @cConsigneeKey, @cStorerKey, @cSKU, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
            BEGIN    
               SET @cOutfield06 = ''   -- (james06)
               SET @nErrNo = 77360    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLabelNo    
               GOTO Step_3_Fail    
            END    
         END    
      END    

      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +   
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cSKU, @cLoadKey, @cConsigneeKey, @cPickSlipNo, @cOrderKey, @cLabelNo, ' +   
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'  
            SET @cSQLParam =  
               '@nMobile        INT,            ' +  
               '@nFunc          INT,            ' +  
               '@cLangCode      NVARCHAR(3),    ' +  
               '@nStep          INT,            ' +  
               '@cUserName      NVARCHAR( 18),  ' +   
               '@cFacility      NVARCHAR( 5),   ' +   
               '@cStorerKey     NVARCHAR( 15),  ' +   
               '@cSKU           NVARCHAR( 20),  ' +   
               '@cLoadKey       NVARCHAR( 10),  ' +  
               '@cConsigneeKey  NVARCHAR( 15),  ' +   
               '@cPickSlipNo    NVARCHAR( 10),  ' +   
               '@cOrderKey      NVARCHAR( 10),  ' +   
               '@cLabelNo       NVARCHAR( 20),  ' +   
               '@nErrNo         INT OUTPUT, ' +    
               '@cErrMsg        NVARCHAR( 20) OUTPUT'  
                 
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,   
               @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cSKU, @cLoadKey, @cConsigneeKey, @cPickSlipNo, @cOrderKey, @cLabelNo, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT  
        
            IF @nErrNo <> 0  
               GOTO Step_3_Fail  
         END  
      END  -- IF @cExtendedValidateSP <> ''  

      -- (james12)
      SET @nErrNo = 0
      SET @cSortAndPackGetNextTask_SP = rdt.RDTGetConfig( @nFunc, 'SortAndPackGetNextTask_SP', @cStorerKey)
      IF ISNULL(@cSortAndPackGetNextTask_SP, '') NOT IN ('', '0')
      BEGIN
         SET @c_oFieled01 = @nExpQTY
         SET @c_oFieled06 = @nOrderQTY_Total 
         SET @c_oFieled07 = @nOrderQTY_Bal
         
         EXEC RDT.RDT_SortAndPackGetNextTask_Wrapper
               @n_Mobile        = @nMobile
            ,@n_Func          = @nFunc
            ,@c_LangCode      = @cLangCode
            ,@c_SPName        = @cSortAndPackGetNextTask_SP
            ,@c_PackByType    = @cPackByType
            ,@c_Type          = 'REFRESH'
            ,@c_LoadKey       = @cLoadKey
            ,@c_Storerkey     = @cStorerKey
            ,@c_SKU           = @cSKU
            ,@c_ConsigneeKey  = @cConsigneeKey  OUTPUT
            ,@c_OrderKey      = @cOrderKey      OUTPUT
            ,@c_oFieled01     = @c_oFieled01    OUTPUT
            ,@c_oFieled02     = @c_oFieled02    OUTPUT
            ,@c_oFieled03     = @c_oFieled03    OUTPUT
            ,@c_oFieled04     = @c_oFieled04    OUTPUT
            ,@c_oFieled05     = @c_oFieled05    OUTPUT
            ,@c_oFieled06     = @c_oFieled06    OUTPUT
            ,@c_oFieled07     = @c_oFieled07    OUTPUT
            ,@c_oFieled08     = @c_oFieled08    OUTPUT
            ,@c_oFieled09     = @c_oFieled09    OUTPUT
            ,@c_oFieled10     = @c_oFieled10    OUTPUT
            ,@c_oFieled11     = @c_oFieled11    OUTPUT
            ,@c_oFieled12     = @c_oFieled12    OUTPUT
            ,@c_oFieled13     = @c_oFieled13    OUTPUT
            ,@c_oFieled14     = @c_oFieled14    OUTPUT
            ,@c_oFieled15     = @c_oFieled15    OUTPUT
            ,@b_Success       = @b_Success      OUTPUT
            ,@n_ErrNo         = @nErrNo         OUTPUT
            ,@c_ErrMsg        = @cErrMsg        OUTPUT

         SET @nExpQTY         = CAST(@c_oFieled01 AS INT)
         SET @nOrderQTY_Total = CAST(@c_oFieled06 AS INT)
         SET @nOrderQTY_Bal   = CAST(@c_oFieled07 AS INT)
      END
      ELSE
      BEGIN
         -- Get next task    
         EXEC rdt.rdt_SortAndPack_GetTask @nMobile, @nFunc, @cLangCode, @cPackByType, 'REFRESH', @cLoadKey, @cStorerKey, @cSKU    
            ,@cConsigneeKey   OUTPUT    
            ,@cOrderKey       OUTPUT    
            ,@nExpQTY         OUTPUT    
            ,@nConsCNT_Total  OUTPUT    
            ,@nConsCNT_Bal    OUTPUT    
            ,@nConsQTY_Total  OUTPUT    
            ,@nConsQTY_Bal    OUTPUT    
            ,@nOrderQTY_Total OUTPUT    
            ,@nOrderQTY_Bal   OUTPUT    
            ,@nSKUQTY_Total   OUTPUT    
            ,@nSKUQTY_Bal     OUTPUT    
            ,@nErrNo          OUTPUT    
            ,@cErrMsg         OUTPUT    
      END
         
      IF @nErrNo <> 0    
         GOTO Step_3_Fail    

      -- (james11)
      IF @cShowCartonTypeScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cShowCartonTypeScreenSP AND type = 'P')    
         BEGIN    
            SET @cShowCartonTypeScreen = ''
            SET @cSQL = 'EXEC RDT.' + RTRIM( @cShowCartonTypeScreenSP) +     
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cLoadKey, @cOrderKey, ' + 
               ' @cConsigneeKey, @cLabelNo, @cSKU, @nQTY, @cShowCtTypeScn OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT' 

            SET @cSQLParam =    
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT, ' +
               '@nInputKey       INT, ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cLoadKey        NVARCHAR( 10), ' +    
               '@cOrderKey       NVARCHAR( 10), ' +   
               '@cConsigneeKey   NVARCHAR( 15), ' +    
               '@cLabelNo        NVARCHAR( 20), ' +    
               '@cSKU            NVARCHAR( 20), ' +      
               '@nQTY            INT,           ' +      
               '@cShowCtTypeScn  NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' + 
               '@cErrMsg         NVARCHAR( 20) OUTPUT  ' 
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cLoadKey, @cOrderKey, 
               @cConsigneeKey, @cLabelNo, @cSKU, @nQTY, @cShowCartonTypeScreen OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT   

            IF @nErrNo <> 0    
               GOTO Step_3_Fail 
         END
      END

      -- Extended info    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo = ''    
                
            SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +     
               ' @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT' +
               ' ,@cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT' + -- (Chee01)
               ' ,@nMobile' -- (Chee02)

            SET @cSQLParam =    
               '@cLoadKey        NVARCHAR( 10), ' +    
               '@cOrderKey       NVARCHAR( 10), ' +   -- (james07)
               '@cConsigneeKey   NVARCHAR( 15), ' +    
               '@cLabelNo        NVARCHAR( 20), ' +    
               '@cStorer         NVARCHAR( 15), ' +      
               '@cSKU            NVARCHAR( 20), ' +      
               '@nExpQTY         INT,       ' +      
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
               '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +
               '@cLangCode       NVARCHAR( 3),         ' + -- (Chee01)
               '@bSuccess        INT           OUTPUT, ' + -- (Chee01)
               '@nErrNo          INT           OUTPUT, ' + -- (Chee01)
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' + -- (Chee01)
               '@nMobile         INT '  -- (Chee02)
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT 
               , @cLangCode, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT   -- (Chee01)  
               , @nMobile -- (Chee02)

            -- (Chee01)
            IF @nErrNo <> 0    
               GOTO Step_3_Fail 
    
            -- Prepare extended fields    
            -- IF @cExtendedInfo <> '' SET @cOutField07 = @cExtendedInfo    
         END    
      END    

      -- (james02)
      IF @cPackByType = 'CONSO'  
         SET @cOrderKey = ''  
  
      -- Get PickSlipNo (PickHeader)  
      SET @cPickSlipNo = ''  
      SELECT @cPickSlipNo = PH.PickHeaderKey  
      FROM dbo.PickHeader PH WITH (NOLOCK)  
      JOIN rdt.rdtSortAndPackLog SAP WITH (NOLOCK) ON ( PH.ExternOrderKey = SAP.LoadKey)
      WHERE OrderKey = @cOrderKey  
         AND SAP.UserName = @cUserName
         AND SAP.Status = '0'

      IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)  
      BEGIN  
         -- Get PickSlipNo (PackHeader)  
         DECLARE @cPSNO NVARCHAR( 10)  
         SET @cPSNO = ''  
         SELECT @cPSNO = PH.PickSlipNo  
         FROM dbo.PackHeader PH WITH (NOLOCK)  
         JOIN rdt.rdtSortAndPackLog SAP WITH (NOLOCK) ON ( PH.LoadKey = SAP.LoadKey)
         WHERE OrderKey = @cOrderKey  
            AND SAP.UserName = @cUserName
            AND SAP.Status = '0'

         IF @cPSNO <> ''  
            SET @cPickSlipNo = @cPSNO  
      END

      -- Chee01
      DECLARE @cPSNO1 NVARCHAR( 10)  
      IF @cPickSlipNo = '' 
         SELECT @cPSNO1 = PH.PickSlipNo  
         FROM dbo.PackHeader PH WITH (NOLOCK)  
         JOIN rdt.rdtSortAndPackLog SAP WITH (NOLOCK) ON ( PH.LoadKey = SAP.LoadKey)
         WHERE SAP.UserName = @cUserName
            AND SAP.Status = '0'


      IF ISNULL(@cPSNO1, '') <> ''  
         SET @cPickSlipNo = @cPSNO1  

      -- Tempe goods and default qty setup then insert pack here (james09)
      IF @nFunc = 543 AND (@cDefaultQTY NOT IN ('', '0')) 
      BEGIN
         SET @nErrNo = 0
         SET @cSortAndPackConfirmTask_SP = rdt.RDTGetConfig( @nFunc, 'SortAndPackConfirmTask_SP', @cStorerKey)
         IF ISNULL(@cSortAndPackConfirmTask_SP, '') NOT IN ('', '0')
         BEGIN
            SET @nErrNo = 0
            SET @cSortAndPackGetCtnType_SP = rdt.RDTGetConfig( @nFunc, 'SortAndPackGetCtnType_SP', @cStorerKey)
            IF ISNULL(@cSortAndPackGetCtnType_SP, '') NOT IN ('', '0')
            BEGIN
               SET @cDefaultCartonType = ''
               EXEC RDT.RDT_SortAndPackGetCtnType_Wrapper
                   @n_Mobile        = @nMobile
                  ,@n_Func          = @nFunc
                  ,@c_LangCode      = @cLangCode
                  ,@c_SPName        = @cSortAndPackGetCtnType_SP
                  ,@c_PackByType    = @cPackByType
                  ,@c_Type          = 'NEXT'
                  ,@c_LoadKey       = @cLoadKey
                  ,@c_Storerkey     = @cStorerKey
                  ,@c_SKU           = @cSKU
                  ,@c_ConsigneeKey  = @cConsigneeKey  OUTPUT
                  ,@c_OrderKey      = @cOrderKey      OUTPUT
                  ,@c_oFieled01     = @c_oFieled01    OUTPUT
                  ,@c_oFieled02     = @c_oFieled02    OUTPUT
                  ,@c_oFieled03     = @c_oFieled03    OUTPUT
                  ,@c_oFieled04     = @c_oFieled04    OUTPUT
                  ,@c_oFieled05     = @c_oFieled05    OUTPUT
                  ,@c_oFieled06     = @c_oFieled06    OUTPUT
                  ,@c_oFieled07     = @c_oFieled07    OUTPUT
                  ,@c_oFieled08     = @c_oFieled08    OUTPUT
                  ,@c_oFieled09     = @c_oFieled09    OUTPUT
                  ,@c_oFieled10     = @c_oFieled10    OUTPUT
                  ,@c_oFieled11     = @c_oFieled11    OUTPUT
                  ,@c_oFieled12     = @c_oFieled12    OUTPUT
                  ,@c_oFieled13     = @c_oFieled13    OUTPUT
                  ,@c_oFieled14     = @c_oFieled14    OUTPUT
                  ,@c_oFieled15     = @c_oFieled15    OUTPUT
                  ,@b_Success       = @b_Success      OUTPUT
                  ,@n_ErrNo         = @nErrNo         OUTPUT
                  ,@c_ErrMsg        = @cErrMsg        OUTPUT

               SET @cDefaultCartonType = @c_oFieled01 
            END
            ELSE
            BEGIN
               SET @cDefaultCartonType = ''
               SET @cDefaultCartonType = rdt.RDTGetConfig( @nFunc, 'DefaultCartonType', @cStorerkey)
            END

            EXEC RDT.RDT_SortAndPackConfirmTask_Wrapper
                @n_Mobile        = @nMobile
               ,@n_Func          = @nFunc
               ,@c_LangCode      = @cLangCode
               ,@c_SPName        = @cSortAndPackConfirmTask_SP
               ,@c_PackByType    = @cPackByType
               ,@c_LoadKey       = @cLoadKey
               ,@c_OrderKey      = @cOrderKey      
               ,@c_ConsigneeKey  = @cConsigneeKey  
               ,@c_Storerkey     = @cStorerKey
               ,@c_SKU           = @cSKU
               ,@n_Qty           = @cDefaultQTY
               ,@c_PickSlipNo    = @cPickSlipNo
               ,@c_LabelNo       = @cLabelNo
               ,@c_CartonType    = @cDefaultCartonType
               ,@b_Success       = @b_Success      OUTPUT
               ,@n_ErrNo         = @nErrNo         OUTPUT
               ,@c_ErrMsg        = @cErrMsg        OUTPUT
               ,@c_UCCNo         = @cUCCNo         -- Chee01

            IF @nErrNo <> 0    
               GOTO Step_3_Fail    
         END
         ELSE
         BEGIN
            EXEC rdt.rdt_SortAndPack_Confirm @nMobile, @nFunc, @cLangCode, @cPackByType, @cLoadKey, @cOrderKey, @cConsigneeKey, @cStorerKey, @cSKU, @cDefaultQTY, @cLabelNo, @cCartonType     
               ,@nErrNo        OUTPUT    
               ,@cErrMsg       OUTPUT  

            IF @nErrNo <> 0    
               GOTO Step_3_Fail    
         END

         -- Get next task    
         SET @nErrNo = 0
         SET @cSortAndPackGetNextTask_SP = rdt.RDTGetConfig( @nFunc, 'SortAndPackGetNextTask_SP', @cStorerKey)
         IF ISNULL(@cSortAndPackGetNextTask_SP, '') NOT IN ('', '0')
         BEGIN
            EXEC RDT.RDT_SortAndPackGetNextTask_Wrapper
                @n_Mobile        = @nMobile
               ,@n_Func          = @nFunc
               ,@c_LangCode      = @cLangCode
               ,@c_SPName        = @cSortAndPackGetNextTask_SP
               ,@c_PackByType    = @cPackByType
               ,@c_Type          = 'NEXT'
               ,@c_LoadKey       = @cLoadKey
               ,@c_Storerkey     = @cStorerKey
               ,@c_SKU           = @cSKU
               ,@c_ConsigneeKey  = @cConsigneeKey  OUTPUT
               ,@c_OrderKey      = @cOrderKey      OUTPUT
               ,@c_oFieled01     = @c_oFieled01    OUTPUT
               ,@c_oFieled02     = @c_oFieled02    OUTPUT
               ,@c_oFieled03     = @c_oFieled03    OUTPUT
               ,@c_oFieled04     = @c_oFieled04    OUTPUT
               ,@c_oFieled05     = @c_oFieled05    OUTPUT
               ,@c_oFieled06     = @c_oFieled06    OUTPUT
               ,@c_oFieled07     = @c_oFieled07    OUTPUT
               ,@c_oFieled08     = @c_oFieled08    OUTPUT
               ,@c_oFieled09     = @c_oFieled09    OUTPUT
               ,@c_oFieled10     = @c_oFieled10    OUTPUT
               ,@c_oFieled11     = @c_oFieled11    OUTPUT
               ,@c_oFieled12     = @c_oFieled12    OUTPUT
               ,@c_oFieled13     = @c_oFieled13    OUTPUT
               ,@c_oFieled14     = @c_oFieled14    OUTPUT
               ,@c_oFieled15     = @c_oFieled15    OUTPUT
               ,@b_Success       = @b_Success      OUTPUT
               ,@n_ErrNo         = @nErrNo         OUTPUT
               ,@c_ErrMsg        = @cErrMsg        OUTPUT

            SET @nExpQTY         = CAST(@c_oFieled01 AS INT)
            SET @nConsCNT_Total  = CAST(@c_oFieled02 AS INT)
            SET @nConsCNT_Bal    = CAST(@c_oFieled03 AS INT)
            SET @nConsQTY_Total  = CAST(@c_oFieled04 AS INT)
            SET @nConsQTY_Bal    = CAST(@c_oFieled05 AS INT)
            SET @nOrderQTY_Total = CAST(@c_oFieled06 AS INT)
            SET @nOrderQTY_Bal   = CAST(@c_oFieled07 AS INT)
            SET @nSKUQTY_Total   = CAST(@c_oFieled08 AS INT)
            SET @nSKUQTY_Bal     = CAST(@c_oFieled09 AS INT)

            -- Go to SKU completed screen    
            IF @nSKUQTY_Total = @nSKUQTY_Bal
            BEGIN            
               SET @cErrMsg = ''

               -- (Chee03)
               IF @nFunc = 547
               BEGIN
                  SET @nScn  = @nScn + 5   
                  SET @nStep = @nStep + 5
               END
               ELSE
               BEGIN
                  SET @nScn  = @nScn + 2   
                  SET @nStep = @nStep + 2 
               END 
               
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            -- Get next task    
            EXEC rdt.rdt_SortAndPack_GetTask @nMobile, @nFunc, @cLangCode, @cPackByType, 'NEXT', @cLoadKey, @cStorerKey, @cSKU    
               ,@cConsigneeKey   OUTPUT    
               ,@cOrderKey       OUTPUT    
               ,@nExpQTY         OUTPUT    
               ,@nConsCNT_Total  OUTPUT    
               ,@nConsCNT_Bal    OUTPUT    
               ,@nConsQTY_Total  OUTPUT    
               ,@nConsQTY_Bal    OUTPUT    
               ,@nOrderQTY_Total OUTPUT    
               ,@nOrderQTY_Bal   OUTPUT    
               ,@nSKUQTY_Total   OUTPUT    
               ,@nSKUQTY_Bal     OUTPUT    
               ,@nErrNo          OUTPUT    
               ,@cErrMsg         OUTPUT    
         END
         
         IF @nErrNo <> 0    
            GOTO Step_3_Fail    

         -- Extended info    
         IF @cExtendedInfoSP <> ''    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
            BEGIN    
               SET @cExtendedInfo = ''    
                   
               SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +     
                  ' @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT'  +
                  ' ,@cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT' + -- (Chee01)
                  ' ,@nMobile' -- (Chee02)
      
               SET @cSQLParam =    
                  '@cLoadKey        NVARCHAR( 10), ' +   
                  '@cOrderKey       NVARCHAR( 10), ' +   -- (james07)
                  '@cConsigneeKey   NVARCHAR( 15), ' +    
                  '@cLabelNo        NVARCHAR( 20), ' +    
                  '@cStorer         NVARCHAR( 15), ' +      
                  '@cSKU            NVARCHAR( 20), ' +      
                  '@nExpQTY         INT,       ' +      
                  '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
                  '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +
                  '@cLangCode       NVARCHAR( 3),         ' + -- (Chee01)
                  '@bSuccess        INT           OUTPUT, ' + -- (Chee01)
                  '@nErrNo          INT           OUTPUT, ' + -- (Chee01)
                  '@cErrMsg         NVARCHAR( 20) OUTPUT, ' + -- (Chee01)
                  '@nMobile         INT '  -- (Chee02)
                   
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                  @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT
                  , @cLangCode, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT   -- (Chee01)
                  , @nMobile -- (Chee02)
       
               -- (Chee01)
               IF @nErrNo <> 0    
                  GOTO Step_3_Fail 

               -- Prepare extended fields    
               IF @cExtendedInfo <> '' SET @cOutField07 = @cExtendedInfo    
            END    
         END    

         -- Prepare next screen var    
         SET @cOutField01 = @cSKU    
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)    
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)    
         SET @cOutField04 = CASE WHEN ISNULL(@cRemoveConsigneePrefix, '') > '' THEN REPLACE(RTRIM(@cConsigneeKey), RTRIM(@cRemoveConsigneePrefix), '') ELSE @cConsigneeKey END
         SET @cOutField05 = @cOrderKey    
         SET @cOutField06 = '' --LabelNo    

      -- Chee01
--         IF @nFunc IN (540, 541)
--         BEGIN
--            SET @cOutField07 = CAST( @nConsCNT_Bal AS NVARCHAR(5)) + '/' + CAST( @nConsCNT_Total AS NVARCHAR(5))    
--            SET @cOutField08 = CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
--            SET @cOutField09 = @cExtendedInfo
--            SET @cOutField10 = CAST( @nConsQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nConsQTY_Total AS NVARCHAR(5))    
--            SET @cOutField11 = @cExtendedInfo2
--         END
         IF @nFunc IN (540, 541, 547) -- (Chee03)
         BEGIN
            IF @cSortnPackByLoadLevel = '1'
            BEGIN
               SET @cOutField07 = ''
               SET @cOutField08 = 'SKU  BAL: ' + CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
               SET @cOutField09 = @cExtendedInfo
               SET @cOutField10 = ''
               SET @cOutField11 = @cExtendedInfo2
            END
            ELSE
            BEGIN
               SET @cOutField07 = 'STOR BAL: ' + CAST( @nConsCNT_Bal AS NVARCHAR(5)) + '/' + CAST( @nConsCNT_Total AS NVARCHAR(5))    
               SET @cOutField08 = 'SKU  BAL: ' + CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
               SET @cOutField09 = @cExtendedInfo
               SET @cOutField10 = 'STOR QTY: ' + CAST( @nConsQTY_Bal AS NVARCHAR(10)) + '/' + CAST( @nConsQTY_Total AS NVARCHAR(10))       --IN00346713 
               SET @cOutField11 = @cExtendedInfo2
            END
         END
         ELSE IF @nFunc = 543
         BEGIN
            SET @cOutField07 = ''
            SET @cOutField08 = ''
            SET @cOutField09 = @cExtendedInfo
            SET @cOutField10 = ''
            SET @cOutField11 = @cExtendedInfo2
         END
      
         GOTO Quit    
      END
      
      SET @nCartonNo = 0
      SELECT TOP 1 @nCartonNo = ISNULL(CartonNo, 0)
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE PickSlipNo = @cPickSlipNo
      AND   LabelNo = @cLabelNo
      AND   StorerKey = @cStorerKey
      
      -- james05
      IF @cShowCartonTypeScreenSP <> ''
      BEGIN
         IF @cShowCartonTypeScreen = '1'
         BEGIN
            SET @nErrNo = 0
            SET @cSortAndPackGetCtnType_SP = rdt.RDTGetConfig( @nFunc, 'SortAndPackGetCtnType_SP', @cStorerKey)
            IF ISNULL(@cSortAndPackGetCtnType_SP, '') NOT IN ('', '0')
            BEGIN
               SET @cDefaultCartonType = ''
               EXEC RDT.RDT_SortAndPackGetCtnType_Wrapper
                   @n_Mobile        = @nMobile
                  ,@n_Func          = @nFunc
                  ,@c_LangCode      = @cLangCode
                  ,@c_SPName        = @cSortAndPackGetCtnType_SP
                  ,@c_PackByType    = @cPackByType
                  ,@c_Type          = 'NEXT'
                  ,@c_LoadKey       = @cLoadKey
                  ,@c_Storerkey     = @cStorerKey
                  ,@c_SKU           = @cSKU
                  ,@c_ConsigneeKey  = @cConsigneeKey  OUTPUT
                  ,@c_OrderKey      = @cOrderKey      OUTPUT
                  ,@c_oFieled01     = @c_oFieled01    OUTPUT
                  ,@c_oFieled02     = @c_oFieled02    OUTPUT
                  ,@c_oFieled03     = @c_oFieled03    OUTPUT
                  ,@c_oFieled04     = @c_oFieled04    OUTPUT
                  ,@c_oFieled05     = @c_oFieled05    OUTPUT
                  ,@c_oFieled06     = @c_oFieled06    OUTPUT
                  ,@c_oFieled07     = @c_oFieled07    OUTPUT
                  ,@c_oFieled08     = @c_oFieled08    OUTPUT
                  ,@c_oFieled09     = @c_oFieled09    OUTPUT
                  ,@c_oFieled10     = @c_oFieled10    OUTPUT
                  ,@c_oFieled11     = @c_oFieled11    OUTPUT
                  ,@c_oFieled12     = @c_oFieled12    OUTPUT
                  ,@c_oFieled13     = @c_oFieled13    OUTPUT
                  ,@c_oFieled14     = @c_oFieled14    OUTPUT
                  ,@c_oFieled15     = @c_oFieled15    OUTPUT
                  ,@b_Success       = @b_Success      OUTPUT
                  ,@n_ErrNo         = @nErrNo         OUTPUT
                  ,@c_ErrMsg        = @cErrMsg        OUTPUT

               SET @cDefaultCartonType = @c_oFieled01 
            END
         
            -- Remember current screen
            SET @nPrevScn = @nScn
            SET @nPrevStp = @nStep

            -- Prepare next screen
            SET @cOutField01 = @cOrderKey    
            SET @cOutField02 = @cLabelNo    
            SET @cOutField03 = CASE WHEN ISNULL(@cDefaultCartonType, '') NOT IN ('0', '') THEN @cDefaultCartonType ELSE '' END 
            SET @cOutField04 = @cExtendedInfo    
            SET @cOutField05 = @cExtendedInfo2
            SET @cOutField06 = ''    
            SET @cOutField07 = ''    
            SET @cOutField08 = ''    
            SET @cOutField09 = ''    
            SET @cOutField10 = ''    
            SET @cOutField11 = ''    
            SET @cOutField12 = ''    
            SET @cOutField13 = ''    
      
            -- Go to capture carton type screen    
            SET @nScn  = @nScn + 4    
            SET @nStep = @nStep + 4
         
            GOTO Quit    
         END
      END
      ELSE
      BEGIN
         -- If packinfo not exists then goto capture carton type screen
         IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) 
                        WHERE PickSlipNo = @cPickSlipNo 
                        AND   CartonNo = @nCartonNo)
         BEGIN
            -- Remember current screen
            SET @nPrevScn = @nScn
            SET @nPrevStp = @nStep

            -- Prepare next screen
            SET @cOutField01 = @cOrderKey    
            SET @cOutField02 = @cLabelNo    
            SET @cOutField03 = CASE WHEN ISNULL(@cDefaultCartonType, '') <> '' THEN @cDefaultCartonType ELSE '' END 
            SET @cOutField04 = @cExtendedInfo
            SET @cOutField05 = @cExtendedInfo2
            SET @cOutField06 = ''    
            SET @cOutField07 = ''    
            SET @cOutField08 = ''    
            SET @cOutField09 = ''    
            SET @cOutField10 = ''    
            SET @cOutField11 = ''    
            SET @cOutField12 = ''    
            SET @cOutField13 = ''    
         
            -- Go to capture carton type screen    
            SET @nScn  = @nScn + 4    
            SET @nStep = @nStep + 4
            
            GOTO Quit    
         END
      END
      
      -- Get SKU info    
      SELECT 
         @cSKUDescr = Descr, 
         @cBUSR10 = BUSR10    -- (james02)
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
      AND   SKU = @cSKU   

      -- Prepare next screen var    
      SET @nPackQTY = 0    
      SET @cOutField01 = CASE WHEN ISNULL(@cRemoveConsigneePrefix, '') > '' THEN REPLACE(RTRIM(@cConsigneeKey), RTRIM(@cRemoveConsigneePrefix), '') ELSE @cConsigneeKey END
      SET @cOutField02 = @cOrderKey    
      SET @cOutField03 = @cLabelNo    
      SET @cOutField04 = CASE WHEN @cDisableSKUField = '1' THEN @cSKU ELSE '' END    
      SET @cOutField05 = @nExpQTY    
      SET @cOutField06 = CASE WHEN @cDefaultQTY = '1' THEN CASE WHEN @cSortnPackPieceScan = '1' THEN '1' ELSE CAST( @nExpQTY AS NVARCHAR( 5)) END ELSE '' END --ActQTY    
--      SET @cOutField07 = CAST( @nConsQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nConsQTY_Total AS NVARCHAR(5))    
      SET @cOutField08 = CASE WHEN @cPackByType = 'CONSO'     
                              THEN CAST( @nConsQTY_Bal AS NVARCHAR(10)) + '/' + CAST( @nConsQTY_Total AS NVARCHAR(10))        --IN00346713 
                              ELSE CAST( @nOrderQTY_Bal AS NVARCHAR(10)) + '/' + CAST( @nOrderQTY_Total AS NVARCHAR(10)) END    --IN00346713
      SET @cOutField09 = @cExtendedInfo    
      SET @cOutField10 = @cExtendedInfo2    
      SET @cOutField11 = @cSKU    
          
      -- Enable / disable SKU QTY field    
      SET @cFieldAttr04 = CASE WHEN @cDisableSKUField = '1' THEN 'O' ELSE '' END --SKU    
      SET @cFieldAttr06 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END --QTY    
             
      -- Go to QTY screen    
      SET @nScn  = @nScn + 1    
      SET @nStep = @nStep + 1    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Extended info    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo = ''    
                   
            SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +     
               ' @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo OUTPUT, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT' +
               ' ,@cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT' + -- (Chee01)
               ' ,@nMobile' -- (Chee02)
     
            SET @cSQLParam =    
               '@cLoadKey        NVARCHAR( 10), ' +   
               '@cOrderKey       NVARCHAR( 10), ' +   -- (james07)
               '@cConsigneeKey   NVARCHAR( 15), ' +    
               '@cLabelNo        NVARCHAR( 20) OUTPUT, ' +  -- (Chee01) 
               '@cStorer         NVARCHAR( 15), ' +      
               '@cSKU            NVARCHAR( 20), ' +      
               '@nExpQTY         INT,       ' +      
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
               '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +
               '@cLangCode       NVARCHAR( 3),         ' + -- (Chee01)
               '@bSuccess        INT           OUTPUT, ' + -- (Chee01)
               '@nErrNo          INT           OUTPUT, ' + -- (Chee01)
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' + -- (Chee01)
               '@nMobile         INT '  -- (Chee02)  
                   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo OUTPUT, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT
               , @cLangCode, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT   -- (Chee01)
               , @nMobile -- (Chee02)

            -- (Chee01)
            IF @nErrNo <> 0    
               GOTO Step_3_Fail  
       
            -- Prepare extended fields    
            IF @cExtendedInfo <> '' SET @cOutField07 = @cExtendedInfo    
         END    
      END    

      -- Check if pack completed for this SKU    
      IF @nExpQTY <> 0 AND @cSkipPack = '0'
      BEGIN    
         -- Prepare prev screen var    
         SET @cOutField01 = '' --Option    

         -- Go to Exit packing screen    
         SET @nScn  = @nScn + 3    
         SET @nStep = @nStep + 3    

         -- (Chee03)
         IF @nFunc = 547 OR ( @nFunc = 540 AND @cCloseCarton = '1')
            SET @cOutField02 = '3 = CLOSE CARTON'
         ELSE
            SET @cOutField02 = ''
      END    
      ELSE    
      BEGIN    
         SET @cConsigneeKey = ''    
             
         -- Prepare prev screen var    
         SET @cOutField01 = @cLoadKey    
         SET @cOutField02 = '' --SKU    
         SET @cOutField03 = '' --UCC

         -- Reset variable when finish packing the SKU
         SET @cOrderKey = ''
         SET @cSKU = ''
         -- Chee01
         SET @cUCCNo = ''
         SET @cLabelNo = ''
    
         -- Go to SKU screen    
         SET @nScn  = @nScn - 1    
         SET @nStep = @nStep - 1    
      END    
   END    
   GOTO Quit    
    
   Step_3_Fail:    
   BEGIN
      SET @cLabelNo = ''
   END
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 4. Screen 3233    
   STORE    (Field01)    
   ORDERKEY (Field02)    
   LABELNO  (Field03)    
   SKU      (Field04)    
   EXP  QTY (Field05)    
   PACK QTY (Field06, input)    
   STOR QTY (Field07)    
   ORD  QTY (Field08)    
   EXT INFO (Field09)    
********************************************************************************/    
Step_4:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      DECLARE @cActQTY NVARCHAR(5)    
      DECLARE @cActSKU NVARCHAR(20)    
          
      -- Screen mapping    
      --SET @cActSKU = CASE WHEN @nFunc = 547 OR @cDisableSKUField = '1' THEN @cOutField04 ELSE @cInField04 END 
      SET @cActSKU = CASE WHEN @cDisableSKUField = '1' THEN @cOutField04 ELSE @cInField04 END
      SET @cActQTY = @cInField06    

      -- Decode SKU (james08)
      SET @cDecodeSKU = ''    
      SET @cDecodeSKU = rdt.RDTGetConfig( @nFunc, 'DecodeSKU', @cStorerkey)    

      IF ISNULL(@cDecodeSKU,'') NOT IN ('', '0')
      BEGIN    
         EXEC dbo.ispLabelNo_Decoding_Wrapper    
             @c_SPName     = @cDecodeSKU    
            ,@c_LabelNo    = @cInField04    
            ,@c_Storerkey  = @cStorerkey    
            ,@c_ReceiptKey = @nMobile    
            ,@c_POKey      = ''    
            ,@c_LangCode   = @cLangCode    
            ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU    
            ,@c_oFieled02  = @c_oFieled02 OUTPUT       
            ,@c_oFieled03  = @c_oFieled03 OUTPUT       
            ,@c_oFieled04  = @c_oFieled04 OUTPUT       
            ,@c_oFieled05  = @c_oFieled05 OUTPUT        
            ,@c_oFieled06  = @c_oFieled06 OUTPUT        
            ,@c_oFieled07  = @c_oFieled07 OUTPUT    
            ,@c_oFieled08  = @c_oFieled08 OUTPUT    
            ,@c_oFieled09  = @c_oFieled09 OUTPUT    
            ,@c_oFieled10  = @c_oFieled10 OUTPUT    
            ,@b_Success    = @b_Success   OUTPUT    
            ,@n_ErrNo      = @nErrNo      OUTPUT    
            ,@c_ErrMsg     = @cErrMsg     OUTPUT   
       
         IF ISNULL(@cErrMsg, '') <> ''    
         BEGIN    
            SET @cErrMsg = @cErrMsg    
            GOTO Step_4_Fail    
         END    
       
         SET @cActSKU = @c_oFieled01      -- assign output to sku code
         SET @c_oFieled01 = ''         -- Reinitiase the variable
      END    

      -- Get SKU count    
      EXEC [RDT].[rdt_GETSKUCNT]    
          @cStorerKey  = @cStorerKey    
         ,@cSKU        = @cActSKU    
         ,@nSKUCnt     = @nSKUCnt       OUTPUT    
         ,@bSuccess    = @b_Success     OUTPUT    
         ,@nErr        = @nErrNo        OUTPUT    
         ,@cErrMsg     = @cErrMsg       OUTPUT    
       
      -- Validate SKU/UPC    
      IF @nSKUCnt = 0    
      BEGIN    
         SET @nErrNo = 77355    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU    
         GOTO Step_4_Fail    
      END    
       
      -- Validate barcode return multiple SKU    
      IF @nSKUCnt > 1    
      BEGIN    
         INSERT INTO traceinfo (TraceName, TimeIn, Col1, Col2, Col3) VALUES ('123', GETDATE(), @cActSKU, @nSKUCnt, @cOutField04)
         SET @nErrNo = 77356    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameBarCodeSKU    
         GOTO Step_4_Fail    
      END    
       
      -- Get SKU    
      EXEC [RDT].[rdt_GETSKU]    
          @cStorerKey  = @cStorerKey    
         ,@cSKU        = @cActSKU       OUTPUT    
         ,@bSuccess    = @b_Success     OUTPUT    
         ,@nErr        = @nErrNo        OUTPUT    
         ,@cErrMsg     = @cErrMsg       OUTPUT    
       
      -- Get SKU info    
      SELECT 
         @cSKUDescr = Descr, 
         @cBUSR10 = BUSR10    -- (james02)
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
      AND   SKU = @cActSKU    

      -- Extended Validate
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +   
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cSKU, @cLoadKey, @cConsigneeKey, @cPickSlipNo, @cOrderKey, @cLabelNo, ' +   
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'  
            SET @cSQLParam =  
               '@nMobile        INT,            ' +  
               '@nFunc          INT,            ' +  
               '@cLangCode      NVARCHAR(3),    ' +  
               '@nStep          INT,            ' +  
               '@cUserName      NVARCHAR( 18),  ' +   
               '@cFacility      NVARCHAR( 5),   ' +   
               '@cStorerKey     NVARCHAR( 15),  ' +   
               '@cSKU           NVARCHAR( 20),  ' +   
               '@cLoadKey       NVARCHAR( 10),  ' +  
               '@cConsigneeKey  NVARCHAR( 15),  ' +   
               '@cPickSlipNo    NVARCHAR( 10),  ' +   
               '@cOrderKey      NVARCHAR( 10),  ' +   
               '@cLabelNo       NVARCHAR( 20),  ' +   
               '@nErrNo         INT OUTPUT, ' +    
               '@cErrMsg        NVARCHAR( 20) OUTPUT'  
                 
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,   
               @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cActSKU, @cLoadKey, @cConsigneeKey, @cPickSlipNo, @cOrderKey, @cLabelNo, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT  
        
            IF @nErrNo <> 0  
               GOTO Step_4_Fail  
         END  
      END  -- IF @cExtendedValidateSP <> ''  

      --Piece scanning    
      IF @cDisableQTYField = '1'     
      BEGIN    
         -- Check SKU blank    
         IF @cActSKU = '' AND @nPackQTY = 0    
         BEGIN    
            SET @nErrNo = 77361    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU    
            GOTO Step_4_Fail    
         END    
       
         -- Check diff SKU    
         IF @cActSKU <> @cSKU    
         BEGIN    
            SET @nErrNo = 77362    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Different SKU    
            GOTO Step_4_Fail    
         END    
         SET @cActQTY = 1    
      END    

      -- Check valid QTY    
      IF rdt.rdtIsValidQty( @cActQty, 1) = 0    
      BEGIN    
         SET @nErrNo = 77363    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY    
         EXEC rdt.rdtSetFocusField @nMobile, 7 --QTY    
         GOTO Step_4_Fail    
      END    

      -- Chee04
      SET @cConvertQtySP = rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorerKey)  
      IF @cConvertQtySP = '0'  
         SET @cConvertQtySP = ''  

      -- Check if Pack > Exp    
      --IF ISNULL(rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorerKey), '') <> ''
      IF ISNULL(@cConvertQtySP, '') <> ''
      BEGIN
         SET @nTActQTY = CAST( @cActQTY AS INT)
         SET @nTExpQTY = @nExpQTY
         SET @nTPackQTY = CASE WHEN @nPackQTY > 0 THEN @nPackQTY ELSE 0 END
         EXEC ispInditexConvertQTY 'ToBaseQTY', @cStorerkey, @cSKU, @nTActQTY OUTPUT
         EXEC ispInditexConvertQTY 'ToBaseQTY', @cStorerkey, @cSKU, @nTExpQTY OUTPUT
         EXEC ispInditexConvertQTY 'ToBaseQTY', @cStorerkey, @cSKU, @nTPackQTY OUTPUT

         IF @nTActQTY <= 0 OR @nTExpQTY <= 0 
         BEGIN
            SET @nErrNo = 77369    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty    
            EXEC rdt.rdtSetFocusField @nMobile, 7 --QTY    
            GOTO Step_4_Fail    
         END

         IF @nTPackQTY + @nTActQTY > @nTExpQTY    
         BEGIN    
            SET @nErrNo = 77370    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pack > ExpQTY    
            EXEC rdt.rdtSetFocusField @nMobile, 7 --QTY    
            GOTO Step_4_Fail    
         END    
         ELSE
         BEGIN
            -- Convert to base qty
            SET @nPackQTY = @nTPackQTY
            SET @cActQTY = @nTActQTY
            SET @nExpQTY = @nTExpQTY
         END

      END
      ELSE
      IF @nPackQTY + CAST( @cActQTY AS INT) > @nExpQTY    
      BEGIN    
         SET @nErrNo = 77364    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pack > ExpQTY    
         EXEC rdt.rdtSetFocusField @nMobile, 7 --QTY    
         GOTO Step_4_Fail    
      END    
      SET @nActQTY = @cActQTY    
          
      -- Piece scanning    
      IF @cDisableQTYField = '1'     
      BEGIN    
         -- Check condition for confirm    
         IF ((@nPackQTY + @nActQTY) = @nExpQTY) OR         -- 1) PackQTY = ExpQTY          (scan until last piece) or    
            ((@nPackQTY + @nActQTY) > 0 AND @cSKU = '')    -- 2) PackQTY > 0 and SKU blank (scan until carton full, and press ENTER with SKU blank)    
         BEGIN    
            -- Set actual QTY for posting    
            SET @nActQTY = @nPackQTY + @nActQTY    
         END    
         ELSE    
         BEGIN    
            -- Increase screen QTY only and exit    
            SET @nPackQTY = @nPackQTY + @nActQTY      

            -- Extended info    
            IF @cExtendedInfoSP <> ''    
            BEGIN    
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
               BEGIN    
                  SET @cExtendedInfo = ''    

                  SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +     
                     ' @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT' +
                     ' ,@cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT' + -- (Chee01)
                     ' ,@nMobile' -- (Chee02)
    
                  SET @cSQLParam =    
                     '@cLoadKey        NVARCHAR( 10), ' +    
                     '@cOrderKey       NVARCHAR( 10), ' +   -- (james07)
                     '@cConsigneeKey   NVARCHAR( 15), ' +    
                     '@cLabelNo        NVARCHAR( 20), ' +    
                     '@cStorer         NVARCHAR( 15), ' +      
                     '@cSKU            NVARCHAR( 20), ' +      
                     '@nExpQTY         INT,       ' +      
                     '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
                     '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +
                     '@cLangCode       NVARCHAR( 3),         ' + -- (Chee01)
                     '@bSuccess        INT           OUTPUT, ' + -- (Chee01)
                     '@nErrNo          INT           OUTPUT, ' + -- (Chee01)
                     '@cErrMsg         NVARCHAR( 20) OUTPUT, ' + -- (Chee01)
                     '@nMobile         INT '  -- (Chee02)
                      
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                     @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT 
                     , @cLangCode, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT   -- (Chee01)  
                     , @nMobile -- (Chee02)
          
                  -- (Chee01)
                  IF @nErrNo <> 0    
                     GOTO Step_4_Fail 

                  -- Prepare extended fields    
                  IF @cExtendedInfo <> '' SET @cOutField09 = @cExtendedInfo    
               END    
            END    

            -- Prepare next screen var    
            SET @cOutField01 = CASE WHEN ISNULL(@cRemoveConsigneePrefix, '') > '' THEN REPLACE(RTRIM(@cConsigneeKey), RTRIM(@cRemoveConsigneePrefix), '') ELSE @cConsigneeKey END
            SET @cOutField02 = @cOrderKey    
            SET @cOutField03 = @cLabelNo    
            SET @cOutField04 = CASE WHEN @cDisableQTYField = '1' THEN '' ELSE @cSKU END    
            SET @cOutField05 = @nExpQTY    
            SET @cOutField06 = @nPackQTY    
--            SET @cOutField07 = CAST( @nConsQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nConsQTY_Total AS NVARCHAR(5))    
            SET @cOutField08 = CASE WHEN @cPackByType = 'CONSO'     
                                    THEN CAST( @nConsQTY_Bal AS NVARCHAR(10)) + '/' + CAST( @nConsQTY_Total AS NVARCHAR(10))        --IN00346713 
                                    ELSE CAST( @nOrderQTY_Bal AS NVARCHAR(10)) + '/' + CAST( @nOrderQTY_Total AS NVARCHAR(10)) END    --IN00346713
            SET @cOutField09 = @cExtendedInfo    
            SET @cOutField10 = @cExtendedInfo2
            SET @cOutField11 = @cSKU
            GOTO Quit    
         END    
      END  

      -- Customised confirm task sp (james09)
      SET @nErrNo = 0
      SET @cSortAndPackConfirmTask_SP = rdt.RDTGetConfig( @nFunc, 'SortAndPackConfirmTask_SP', @cStorerKey)
      IF ISNULL(@cSortAndPackConfirmTask_SP, '') NOT IN ('', '0')
      BEGIN
         SET @nErrNo = 0
         SET @cSortAndPackGetCtnType_SP = rdt.RDTGetConfig( @nFunc, 'SortAndPackGetCtnType_SP', @cStorerKey)
         IF ISNULL(@cSortAndPackGetCtnType_SP, '') NOT IN ('', '0')
         BEGIN
            SET @cDefaultCartonType = ''
            EXEC RDT.RDT_SortAndPackGetCtnType_Wrapper
                @n_Mobile        = @nMobile
               ,@n_Func          = @nFunc
               ,@c_LangCode      = @cLangCode
               ,@c_SPName        = @cSortAndPackGetCtnType_SP
               ,@c_PackByType    = @cPackByType
               ,@c_Type          = 'NEXT'
               ,@c_LoadKey       = @cLoadKey
               ,@c_Storerkey     = @cStorerKey
               ,@c_SKU           = @cSKU
               ,@c_ConsigneeKey  = @cConsigneeKey  OUTPUT
               ,@c_OrderKey      = @cOrderKey      OUTPUT
               ,@c_oFieled01     = @c_oFieled01    OUTPUT
               ,@c_oFieled02     = @c_oFieled02    OUTPUT
               ,@c_oFieled03     = @c_oFieled03    OUTPUT
               ,@c_oFieled04     = @c_oFieled04    OUTPUT
               ,@c_oFieled05     = @c_oFieled05    OUTPUT
               ,@c_oFieled06     = @c_oFieled06    OUTPUT
               ,@c_oFieled07     = @c_oFieled07    OUTPUT
               ,@c_oFieled08     = @c_oFieled08    OUTPUT
               ,@c_oFieled09     = @c_oFieled09    OUTPUT
               ,@c_oFieled10     = @c_oFieled10    OUTPUT
               ,@c_oFieled11     = @c_oFieled11    OUTPUT
               ,@c_oFieled12     = @c_oFieled12    OUTPUT
               ,@c_oFieled13     = @c_oFieled13    OUTPUT
               ,@c_oFieled14     = @c_oFieled14    OUTPUT
               ,@c_oFieled15     = @c_oFieled15    OUTPUT
               ,@b_Success       = @b_Success      OUTPUT
               ,@n_ErrNo         = @nErrNo         OUTPUT
               ,@c_ErrMsg        = @cErrMsg        OUTPUT

            SET @cDefaultCartonType = @c_oFieled01 
         END
         ELSE
         BEGIN
            SET @cDefaultCartonType = ''
            SET @cDefaultCartonType = rdt.RDTGetConfig( @nFunc, 'DefaultCartonType', @cStorerkey)
            
            IF @cDefaultCartonType IN ('', '0')
               SET @cDefaultCartonType = @cCartonType
         END

         -- (Chee01)
         IF @cDefaultQTY IN ('', '0')
            EXEC RDT.RDT_SortAndPackConfirmTask_Wrapper
                @n_Mobile        = @nMobile
               ,@n_Func          = @nFunc
               ,@c_LangCode      = @cLangCode
               ,@c_SPName        = @cSortAndPackConfirmTask_SP
               ,@c_PackByType    = @cPackByType
               ,@c_LoadKey       = @cLoadKey
               ,@c_OrderKey      = @cOrderKey      
               ,@c_ConsigneeKey  = @cConsigneeKey  
               ,@c_Storerkey     = @cStorerKey
               ,@c_SKU           = @cSKU
               ,@n_Qty           = @nActQTY 
               ,@c_PickSlipNo    = @cPickSlipNo
               ,@c_LabelNo       = @cLabelNo
               ,@c_CartonType    = @cDefaultCartonType
               ,@b_Success       = @b_Success      OUTPUT
               ,@n_ErrNo         = @nErrNo         OUTPUT
               ,@c_ErrMsg        = @cErrMsg        OUTPUT
               ,@c_UCCNo         = @cUCCNo         -- Chee01               
         ELSE
            EXEC RDT.RDT_SortAndPackConfirmTask_Wrapper
                @n_Mobile        = @nMobile
               ,@n_Func          = @nFunc
               ,@c_LangCode      = @cLangCode
               ,@c_SPName        = @cSortAndPackConfirmTask_SP
               ,@c_PackByType    = @cPackByType
               ,@c_LoadKey       = @cLoadKey
               ,@c_OrderKey      = @cOrderKey      
               ,@c_ConsigneeKey  = @cConsigneeKey  
               ,@c_Storerkey     = @cStorerKey
               ,@c_SKU           = @cSKU
               ,@n_Qty           = @cDefaultQTY 
               ,@c_PickSlipNo    = @cPickSlipNo
               ,@c_LabelNo       = @cLabelNo
               ,@c_CartonType    = @cDefaultCartonType
               ,@b_Success       = @b_Success      OUTPUT
               ,@n_ErrNo         = @nErrNo         OUTPUT
               ,@c_ErrMsg        = @cErrMsg        OUTPUT
               ,@c_UCCNo         = @cUCCNo         -- Chee01

         IF @nErrNo <> 0    
            GOTO Step_4_Fail    
      END
      ELSE
      BEGIN
         -- Confirm task    
         EXEC rdt.rdt_SortAndPack_Confirm @nMobile, @nFunc, @cLangCode, @cPackByType, @cLoadKey, @cOrderKey, @cConsigneeKey, @cStorerKey, @cSKU, @nActQTY, @cLabelNo, @cCartonType     
            ,@nErrNo        OUTPUT    
            ,@cErrMsg       OUTPUT    
         IF @nErrNo <> 0    
            GOTO Step_4_Fail    
      END

      -- Event log    
      EXEC RDT.rdt_STD_EventLog    
         @cActionType   = '3', -- Picking    
         @cUserID       = @cUserName,    
         @nMobileNo     = @nMobile,    
         @nFunctionID   = @nFunc,    
         @cFacility     = @cFacility,    
         @cStorerKey    = @cStorerkey,    
         @cSKU          = @cSKU,    
         @nQTY          = @nActQTY,    
         @cLoadKey      = @cLoadKey,    
         --@cDropID       = @cLabelNo    
         --@cRefNo1       = @cLabelNo -- (ChewKP01),
         @cLabelNo      = @cLabelNo,
         @nStep         = @nStep

      IF @cPackByType = 'CONSO'  
         SET @cOrderKey = ''  
  
      
      DECLARE @cType NVARCHAR(4)    
      SET @cType = CASE WHEN @nExpQTY = @nActQTY THEN 'NEXT' ELSE '' END             

      -- Remember the current orderkey b4 try to get next task    -- (james03)
      SET @cPrevOrderKey = @cOrderKey
    
      -- Get next task 
      -- (james03)
      SET @nErrNo = 0
      SET @cSortAndPackGetNextTask_SP = rdt.RDTGetConfig( @nFunc, 'SortAndPackGetNextTask_SP', @cStorerKey)
      IF ISNULL(@cSortAndPackGetNextTask_SP, '') NOT IN ('', '0')
      BEGIN
         EXEC RDT.RDT_SortAndPackGetNextTask_Wrapper
             @n_Mobile        = @nMobile
            ,@n_Func          = @nFunc
            ,@c_LangCode      = @cLangCode
            ,@c_SPName        = @cSortAndPackGetNextTask_SP
            ,@c_PackByType    = @cPackByType
            ,@c_Type          = @cType
            ,@c_LoadKey       = @cLoadKey
            ,@c_Storerkey     = @cStorerKey
            ,@c_SKU           = @cSKU
            ,@c_ConsigneeKey  = @cConsigneeKey  OUTPUT
            ,@c_OrderKey      = @cOrderKey      OUTPUT
            ,@c_oFieled01     = @c_oFieled01    OUTPUT
            ,@c_oFieled02     = @c_oFieled02    OUTPUT
            ,@c_oFieled03     = @c_oFieled03    OUTPUT
            ,@c_oFieled04     = @c_oFieled04    OUTPUT
            ,@c_oFieled05     = @c_oFieled05    OUTPUT
            ,@c_oFieled06     = @c_oFieled06    OUTPUT
            ,@c_oFieled07     = @c_oFieled07    OUTPUT
            ,@c_oFieled08     = @c_oFieled08    OUTPUT
            ,@c_oFieled09     = @c_oFieled09    OUTPUT
            ,@c_oFieled10     = @c_oFieled10    OUTPUT
            ,@c_oFieled11     = @c_oFieled11    OUTPUT
            ,@c_oFieled12     = @c_oFieled12    OUTPUT
            ,@c_oFieled13     = @c_oFieled13    OUTPUT
            ,@c_oFieled14     = @c_oFieled14    OUTPUT
            ,@c_oFieled15     = @c_oFieled15    OUTPUT
            ,@b_Success       = @b_Success      OUTPUT
            ,@n_ErrNo         = @nErrNo         OUTPUT
            ,@c_ErrMsg        = @cErrMsg        OUTPUT

         SET @nExpQTY         = CAST(@c_oFieled01 AS INT)
         SET @nConsCNT_Total  = CAST(@c_oFieled02 AS INT)
         SET @nConsCNT_Bal    = CAST(@c_oFieled03 AS INT)
         SET @nConsQTY_Total  = CAST(@c_oFieled04 AS INT)
         SET @nConsQTY_Bal    = CAST(@c_oFieled05 AS INT)
         SET @nOrderQTY_Total = CAST(@c_oFieled06 AS INT)
         SET @nOrderQTY_Bal   = CAST(@c_oFieled07 AS INT)
         SET @nSKUQTY_Total   = CAST(@c_oFieled08 AS INT)
         SET @nSKUQTY_Bal     = CAST(@c_oFieled09 AS INT)
         SET @cLabelNo        = @c_oFieled11
      END
      ELSE
      BEGIN
         EXEC rdt.rdt_SortAndPack_GetTask @nMobile, @nFunc, @cLangCode, @cPackByType, @cType, @cLoadKey, @cStorerKey, @cSKU    
            ,@cConsigneeKey   OUTPUT    
            ,@cOrderKey       OUTPUT    
            ,@nExpQTY         OUTPUT    
            ,@nConsCNT_Total  OUTPUT    
            ,@nConsCNT_Bal    OUTPUT    
            ,@nConsQTY_Total  OUTPUT    
            ,@nConsQTY_Bal    OUTPUT    
            ,@nOrderQTY_Total OUTPUT    
            ,@nOrderQTY_Bal   OUTPUT    
            ,@nSKUQTY_Total   OUTPUT    
            ,@nSKUQTY_Bal     OUTPUT    
            ,@nErrNo          OUTPUT    
            ,@cErrMsg         OUTPUT    
      END
      
      IF @nErrNo = 0 -- More task    
      BEGIN    
         -- Extended info    
         IF @cExtendedInfoSP <> ''    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
            BEGIN    
               SET @cExtendedInfo = ''    
                   
               SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +     
                  ' @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT' +
                  ' ,@cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT' + -- (Chee01)
                  ' ,@nMobile' -- (Chee02)
  
               SET @cSQLParam =    
                  '@cLoadKey        NVARCHAR( 10), ' +    
                  '@cOrderKey       NVARCHAR( 10), ' +   -- (james07)
                  '@cConsigneeKey   NVARCHAR( 15), ' +    
                  '@cLabelNo        NVARCHAR( 20), ' +    
                  '@cStorer         NVARCHAR( 15), ' +      
                  '@cSKU            NVARCHAR( 20), ' +      
                  '@nExpQTY         INT,       ' +      
                  '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
                  '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +
                  '@cLangCode       NVARCHAR( 3),         ' + -- (Chee01)
                  '@bSuccess        INT           OUTPUT, ' + -- (Chee01)
                  '@nErrNo          INT           OUTPUT, ' + -- (Chee01)
                  '@cErrMsg         NVARCHAR( 20) OUTPUT, ' + -- (Chee01)
                  '@nMobile         INT '  -- (Chee02)
                   
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                  @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT  
                  , @cLangCode, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT   -- (Chee01)
                  , @nMobile -- (Chee02)

               -- (Chee01)
               IF @nErrNo <> 0    
                  GOTO STEP_4_Fail 
       
               -- Prepare extended fields    
               IF @cExtendedInfo <> '' SET @cOutField07 = @cExtendedInfo    
            END    
         END    

         -- Prepare next screen var    
         SET @cOutField01 = @cSKU    
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)    
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)    
         SET @cOutField04 = CASE WHEN ISNULL(@cRemoveConsigneePrefix, '') > '' THEN REPLACE(RTRIM(@cConsigneeKey), RTRIM(@cRemoveConsigneePrefix), '') ELSE @cConsigneeKey END
         SET @cOutField05 = @cOrderKey    
         
         IF @cLabelNo <> ''
            SET @cOutField06 = @cLabelNo
         ELSE
            SET @cOutField06 = '' --LabelNo    

         IF @nFunc IN (540, 541, 547) -- (Chee03)
         BEGIN
            IF @cSortnPackByLoadLevel = '1'
            BEGIN
               SET @cOutField07 = ''
               SET @cOutField08 = 'SKU  BAL: ' + CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
               SET @cOutField09 = @cExtendedInfo
               SET @cOutField10 = ''
               SET @cOutField11 = @cExtendedInfo2
            END
            ELSE
            BEGIN
               SET @cOutField07 = 'STOR BAL: ' + CAST( @nConsCNT_Bal AS NVARCHAR(5)) + '/' + CAST( @nConsCNT_Total AS NVARCHAR(5))    
               SET @cOutField08 = 'SKU  BAL: ' + CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
               SET @cOutField09 = @cExtendedInfo
               SET @cOutField10 = 'STOR QTY: ' + CAST( @nConsQTY_Bal AS NVARCHAR(10)) + '/' + CAST( @nConsQTY_Total AS NVARCHAR(10))       --IN00346713 
               SET @cOutField11 = @cExtendedInfo2
            END
         END
         ELSE IF @nFunc = 543
         BEGIN
            SET @cOutField07 = ''
            SET @cOutField08 = ''
            SET @cOutField09 = @cExtendedInfo
            SET @cOutField10 = ''
            SET @cOutField11 = @cExtendedInfo2
         END
         
         -- Go to LabelNo screen    
         SET @nScn  = @nScn - 1    
         SET @nStep = @nStep - 1    
      END    
          
      IF @nErrNo <> 0 -- No more task    
      BEGIN    
         -- Reset error 'No more task'    
         SET @nErrNo = 0    
         SET @cErrMsg = ''    
    
         -- Get balance QTY of this SKU    
         SELECT @nExpQTY = ISNULL( SUM( PD.QTY), 0)    
         FROM dbo.PickDetail PD WITH (NOLOCK)    
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
            JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)    
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)    
            JOIN rdt.rdtSortAndPackLog SAP WITH (NOLOCK) ON ( LPD.LoadKey = SAP.LoadKey)
         WHERE PD.StorerKey = @cStorerKey    
            AND PD.SKU = @cSKU    
            AND PD.Status = '0'    
            AND ISNULL(OD.UserDefine04, '') <> 'M' -- (james06)
            AND PD.UOM = CASE WHEN @cSortnPackFilterUOM <> '' THEN @cSortnPackFilterUOM ELSE PD.UOM END
            AND EXISTS ( SELECT 1 FROM rdt.rdtSortAndPackLog SAP WITH (NOLOCK) 
                         WHERE LPD.LoadKey = SAP.LoadKey 
                         AND   SAP.Username = @cUserName 
                         AND   SAP.Status = '0')
    
         -- Check if pack completed for this SKU    
         IF @nExpQTY = 0    
         BEGIN    
            IF ISNULL(@cLoadKey, '') = ''
            BEGIN
               SELECT TOP 1 @cLoadKey = LoadKey 
               FROM dbo.Orders WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   OrderKey = @cPrevOrderKey
            END
            
            -- Check if Order.SOStatus = 'HOLD' (any one orders under this current load)
            IF EXISTS (SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                       WHERE StorerKey = @cStorerKey
                       AND   LoadKey = @cLoadKey
                       AND   SOStatus = 'HOLD')
            BEGIN
               SELECT @nSumPicked = ISNULL(SUM( QTY), 0) 
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   OrderKey = @cPrevOrderKey
               AND Status <> '4'

               SELECT @nSumPacked = ISNULL(SUM( PD.QTY), 0)
               FROM dbo.PackDetail PD WITH (NOLOCK) 
               JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
               WHERE PH.StorerKey = @cStorerKey
               AND   PH.OrderKey = @cPrevOrderKey
               AND   PH.Status <> '9'

               IF @nSumPicked = @nSumPacked
               BEGIN
                  SET @cOutField01 = 'Order status is hold'
               END
               ELSE
               BEGIN
                  SELECT @nSumPicked = ISNULL(SUM( PD.QTY), 0) 
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.OrderDetail OD WITH (NOLOCK) ON PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber
                  JOIN Orders O WITH (NOLOCK) ON OD.OrderKey = O.OrderKey
                  WHERE O.StorerKey = @cStorerKey
                  AND   O.LoadKey = @cLoadKey
                  AND   O.Status = '5'

                  SELECT @nSumPacked = ISNULL(SUM( PD.QTY), 0)
                  FROM dbo.PackDetail PD WITH (NOLOCK) 
                  JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
                  JOIN dbo.Orders O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey
                  WHERE O.StorerKey = @cStorerKey
                  AND   O.LoadKey = @cLoadKey
                  AND   O.Status = '5'

                  IF @nSumPicked = @nSumPacked
                  BEGIN
                     SET @cOutField01 = 'Order status is hold'
                  END
                  ELSE
                  BEGIN
                     SET @cOutField01 = ''
                  END
               END
            END
            ELSE
            BEGIN
               SET @cOutField01 = ''
            END

            -- (Chee01)
            SET @cOutField02 = '' 

            -- Go to SKU completed screen  (Chee03)
            IF @nFunc = 547 OR ( @nFunc = 540 AND @cCloseCarton = '1')
            BEGIN
               SET @nScn  = @nScn + 4    
               SET @nStep = @nStep + 4
            END
            ELSE
            BEGIN
               SET @nScn  = @nScn + 1    
               SET @nStep = @nStep + 1
            END
         END    
         ELSE    
         BEGIN    
            -- (james03)
            SET @nErrNo = 0
            SET @cSortAndPackGetNextTask_SP = rdt.RDTGetConfig( @nFunc, 'SortAndPackGetNextTask_SP', @cStorerKey)
            IF ISNULL(@cSortAndPackGetNextTask_SP, '') NOT IN ('', '0')
            BEGIN
               EXEC RDT.RDT_SortAndPackGetNextTask_Wrapper
                   @n_Mobile        = @nMobile
                  ,@n_Func          = @nFunc
                  ,@c_LangCode      = @cLangCode
                  ,@c_SPName        = @cSortAndPackGetNextTask_SP
                  ,@c_PackByType    = @cPackByType
                  ,@c_Type          = @cType
                  ,@c_LoadKey       = @cLoadKey
                  ,@c_Storerkey     = @cStorerKey
                  ,@c_SKU           = @cSKU
                  ,@c_ConsigneeKey  = @cConsigneeKey  OUTPUT
                  ,@c_OrderKey      = @cOrderKey      OUTPUT
                  ,@c_oFieled01     = @c_oFieled01    OUTPUT
                  ,@c_oFieled02     = @c_oFieled02    OUTPUT
                  ,@c_oFieled03     = @c_oFieled03    OUTPUT
                  ,@c_oFieled04     = @c_oFieled04    OUTPUT
                  ,@c_oFieled05     = @c_oFieled05    OUTPUT
                  ,@c_oFieled06     = @c_oFieled06    OUTPUT
                  ,@c_oFieled07     = @c_oFieled07    OUTPUT
                  ,@c_oFieled08     = @c_oFieled08    OUTPUT
                  ,@c_oFieled09     = @c_oFieled09    OUTPUT
                  ,@c_oFieled10     = @c_oFieled10    OUTPUT
                  ,@c_oFieled11     = @c_oFieled11    OUTPUT
                  ,@c_oFieled12     = @c_oFieled12    OUTPUT
                  ,@c_oFieled13     = @c_oFieled13    OUTPUT
                  ,@c_oFieled14     = @c_oFieled14    OUTPUT
                  ,@c_oFieled15     = @c_oFieled15    OUTPUT
                  ,@b_Success       = @b_Success      OUTPUT
                  ,@n_ErrNo         = @nErrNo         OUTPUT
                  ,@c_ErrMsg        = @cErrMsg        OUTPUT

               SET @nExpQTY         = CAST(@c_oFieled01 AS INT)
               SET @nConsCNT_Total  = CAST(@c_oFieled02 AS INT)
               SET @nConsCNT_Bal    = CAST(@c_oFieled03 AS INT)
               SET @nConsQTY_Total  = CAST(@c_oFieled04 AS INT)
               SET @nConsQTY_Bal    = CAST(@c_oFieled05 AS INT)
               SET @nOrderQTY_Total = CAST(@c_oFieled06 AS INT)
               SET @nOrderQTY_Bal   = CAST(@c_oFieled07 AS INT)
               SET @nSKUQTY_Total   = CAST(@c_oFieled08 AS INT)
               SET @nSKUQTY_Bal     = CAST(@c_oFieled09 AS INT)
            END
            ELSE
            BEGIN
               -- Get skipped task from begining    
               SET @cConsigneeKey = ''    
               EXEC rdt.rdt_SortAndPack_GetTask @nMobile, @nFunc, @cLangCode, @cPackByType, @cType, @cLoadKey, @cStorerKey, @cSKU    
                  ,@cConsigneeKey   OUTPUT    
                  ,@cOrderKey       OUTPUT    
                  ,@nExpQTY         OUTPUT    
                  ,@nConsCNT_Total  OUTPUT    
                  ,@nConsCNT_Bal    OUTPUT    
                  ,@nConsQTY_Total  OUTPUT    
                  ,@nConsQTY_Bal    OUTPUT    
                  ,@nOrderQTY_Total OUTPUT    
                  ,@nOrderQTY_Bal   OUTPUT    
                  ,@nSKUQTY_Total   OUTPUT    
                  ,@nSKUQTY_Bal     OUTPUT    
                  ,@nErrNo          OUTPUT    
                  ,@cErrMsg         OUTPUT    
            END
            
            IF @nErrNo <> 0
               GOTO STEP_4_Fail

            -- Extended info    
            IF @cExtendedInfoSP <> ''    
            BEGIN    
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
               BEGIN    
                  SET @cExtendedInfo = ''    
                      
                  SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +     
                     ' @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT' +
                     ' ,@cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT' + -- (Chee01)
                     ' ,@nMobile' -- (Chee02)
    
                  SET @cSQLParam =    
                     '@cLoadKey        NVARCHAR( 10), ' +    
                     '@cOrderKey       NVARCHAR( 10), ' +   -- (james07)
                     '@cConsigneeKey   NVARCHAR( 15), ' +    
                     '@cLabelNo        NVARCHAR( 20), ' +    
                     '@cStorer         NVARCHAR( 15), ' +      
                     '@cSKU            NVARCHAR( 20), ' +      
                     '@nExpQTY         INT,       ' +      
                     '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
                     '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +
                     '@cLangCode       NVARCHAR( 3),         ' + -- (Chee01)
                     '@bSuccess        INT           OUTPUT, ' + -- (Chee01)
                     '@nErrNo          INT           OUTPUT, ' + -- (Chee01)
                     '@cErrMsg         NVARCHAR( 20) OUTPUT, ' + -- (Chee01)
                     '@nMobile         INT '  -- (Chee02)
                         
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                     @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT 
                     , @cLangCode, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT   -- (Chee01)  
                     , @nMobile -- (Chee02)
          
                  -- (Chee01)
                  IF @nErrNo <> 0    
                     GOTO STEP_4_Fail 

                  -- Prepare extended fields    
                  IF @cExtendedInfo <> '' SET @cOutField07 = @cExtendedInfo    
               END    
            END    

            -- Prepare next screen var    
            SET @cOutField01 = @cSKU    
            SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)    
            SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)    
            SET @cOutField04 = CASE WHEN ISNULL(@cRemoveConsigneePrefix, '') > '' THEN REPLACE(RTRIM(@cConsigneeKey), RTRIM(@cRemoveConsigneePrefix), '') ELSE @cConsigneeKey END
            SET @cOutField05 = @cOrderKey    

            IF @cLabelNo <> ''
               SET @cOutField06 = @cLabelNo
            ELSE
               SET @cOutField06 = '' --LabelNo    

            IF @nFunc IN (540, 541, 547) -- (Chee03)
            BEGIN
               IF @cSortnPackByLoadLevel = '1'
               BEGIN
                  SET @cOutField07 = ''
                  SET @cOutField08 = 'SKU  BAL: ' + CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
                  SET @cOutField09 = @cExtendedInfo
                  SET @cOutField10 = ''
                  SET @cOutField11 = @cExtendedInfo2
               END
               ELSE
               BEGIN
                  SET @cOutField07 = 'STOR BAL: ' + CAST( @nConsCNT_Bal AS NVARCHAR(5)) + '/' + CAST( @nConsCNT_Total AS NVARCHAR(5))    
                  SET @cOutField08 = 'SKU  BAL: ' + CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
                  SET @cOutField09 = @cExtendedInfo
                  SET @cOutField10 = 'STOR QTY: ' + CAST( @nConsQTY_Bal AS NVARCHAR(10)) + '/' + CAST( @nConsQTY_Total AS NVARCHAR(10))       --IN00346713 
                  SET @cOutField11 = @cExtendedInfo2
               END
            END
            ELSE IF @nFunc = 543
            BEGIN
               SET @cOutField07 = ''
               SET @cOutField08 = ''
               SET @cOutField09 = @cExtendedInfo
               SET @cOutField10 = ''
               SET @cOutField11 = @cExtendedInfo2
            END
            
            -- Go to LabelNo screen    
            SET @nScn  = @nScn - 1    
            SET @nStep = @nStep - 1    
         END    
      END    
    
      -- Enable field    
      SET @cFieldAttr04 = '' --SKU    
      SET @cFieldAttr06 = '' --QTY    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      IF @cDisableQTYField = '1' AND @nPackQTY > 0    
      BEGIN    
         -- Confirm task    
         EXEC rdt.rdt_SortAndPack_Confirm @nMobile, @nFunc, @cLangCode, @cPackByType, @cLoadKey, @cOrderKey, @cConsigneeKey, @cStorerKey, @cSKU, @nPackQTY, @cLabelNo, @cCartonType    
            ,@nErrNo        OUTPUT    
            ,@cErrMsg       OUTPUT    
         IF @nErrNo <> 0    
            GOTO Step_4_Fail    
    
         -- Get next task    
         -- (james03)
         SET @nErrNo = 0
         SET @cSortAndPackGetNextTask_SP = rdt.RDTGetConfig( @nFunc, 'SortAndPackGetNextTask_SP', @cStorerKey)
         IF ISNULL(@cSortAndPackGetNextTask_SP, '') NOT IN ('', '0')
         BEGIN
            EXEC RDT.RDT_SortAndPackGetNextTask_Wrapper
                @n_Mobile        = @nMobile
               ,@n_Func          = @nFunc
               ,@c_LangCode      = @cLangCode
               ,@c_SPName        = @cSortAndPackGetNextTask_SP
               ,@c_PackByType    = @cPackByType
               ,@c_Type          = @cType
               ,@c_LoadKey       = @cLoadKey
               ,@c_Storerkey     = @cStorerKey
               ,@c_SKU           = @cSKU
               ,@c_ConsigneeKey  = @cConsigneeKey  OUTPUT
               ,@c_OrderKey      = @cOrderKey      OUTPUT
               ,@c_oFieled01     = @c_oFieled01    OUTPUT
               ,@c_oFieled02     = @c_oFieled02    OUTPUT
               ,@c_oFieled03     = @c_oFieled03    OUTPUT
               ,@c_oFieled04     = @c_oFieled04    OUTPUT
               ,@c_oFieled05     = @c_oFieled05    OUTPUT
               ,@c_oFieled06     = @c_oFieled06    OUTPUT
               ,@c_oFieled07     = @c_oFieled07    OUTPUT
               ,@c_oFieled08     = @c_oFieled08    OUTPUT
               ,@c_oFieled09     = @c_oFieled09    OUTPUT
               ,@c_oFieled10     = @c_oFieled10    OUTPUT
               ,@c_oFieled11     = @c_oFieled11    OUTPUT
               ,@c_oFieled12     = @c_oFieled12    OUTPUT
               ,@c_oFieled13     = @c_oFieled13    OUTPUT
               ,@c_oFieled14     = @c_oFieled14    OUTPUT
               ,@c_oFieled15     = @c_oFieled15    OUTPUT
               ,@b_Success       = @b_Success      OUTPUT
               ,@n_ErrNo         = @nErrNo         OUTPUT
               ,@c_ErrMsg        = @cErrMsg        OUTPUT

            SET @nExpQTY         = CAST(@c_oFieled01 AS INT)
            SET @nConsCNT_Total  = CAST(@c_oFieled02 AS INT)
            SET @nConsCNT_Bal    = CAST(@c_oFieled03 AS INT)
            SET @nConsQTY_Total  = CAST(@c_oFieled04 AS INT)
            SET @nConsQTY_Bal    = CAST(@c_oFieled05 AS INT)
            SET @nOrderQTY_Total = CAST(@c_oFieled06 AS INT)
            SET @nOrderQTY_Bal   = CAST(@c_oFieled07 AS INT)
            SET @nSKUQTY_Total   = CAST(@c_oFieled08 AS INT)
            SET @nSKUQTY_Bal     = CAST(@c_oFieled09 AS INT)
         END
         ELSE
         BEGIN
            EXEC rdt.rdt_SortAndPack_GetTask @nMobile, @nFunc, @cLangCode, @cPackByType, @cType, @cLoadKey, @cStorerKey, @cSKU    
               ,@cConsigneeKey   OUTPUT    
               ,@cOrderKey       OUTPUT    
               ,@nExpQTY         OUTPUT    
               ,@nConsCNT_Total  OUTPUT    
               ,@nConsCNT_Bal    OUTPUT    
               ,@nConsQTY_Total  OUTPUT    
               ,@nConsQTY_Bal    OUTPUT    
               ,@nOrderQTY_Total OUTPUT    
               ,@nOrderQTY_Bal   OUTPUT    
               ,@nSKUQTY_Total   OUTPUT    
               ,@nSKUQTY_Bal     OUTPUT    
               ,@nErrNo          OUTPUT    
               ,@cErrMsg         OUTPUT    
         END
         
         IF @nErrNo <> 0
            GOTO STEP_4_Fail
      END    

      -- Extended info    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo = ''    
            SET @cExtendedInfo2 = ''

            SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +     
               ' @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT' +
               ' ,@cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT' + -- (Chee01)
               ' ,@nMobile' -- (Chee02)
    
            SET @cSQLParam =    
               '@cLoadKey        NVARCHAR( 10), ' +    
               '@cOrderKey       NVARCHAR( 10), ' +   -- (james07)
               '@cConsigneeKey   NVARCHAR( 15), ' +    
               '@cLabelNo        NVARCHAR( 20), ' +    
               '@cStorer         NVARCHAR( 15), ' +      
               '@cSKU            NVARCHAR( 20), ' +      
               '@nExpQTY         INT,       ' +      
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
               '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +
               '@cLangCode       NVARCHAR( 3),         ' + -- (Chee01)
               '@bSuccess        INT           OUTPUT, ' + -- (Chee01)
               '@nErrNo          INT           OUTPUT, ' + -- (Chee01)
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' + -- (Chee01)
               '@nMobile         INT '  -- (Chee02)
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT  
               , @cLangCode, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT   -- (Chee01) 
               , @nMobile -- (Chee02)

            -- (Chee01)
            IF @nErrNo <> 0    
               GOTO Step_4_Fail 
    
            -- Prepare extended fields    
            IF @cExtendedInfo <> '' SET @cOutField07 = @cExtendedInfo    
         END    
      END    

      -- Prepare prev screen var    
      SET @cOutField01 = @cSKU    
      SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)    
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)    
      SET @cOutField04 = CASE WHEN ISNULL(@cRemoveConsigneePrefix, '') > '' THEN REPLACE(RTRIM(@cConsigneeKey), RTRIM(@cRemoveConsigneePrefix), '') ELSE @cConsigneeKey END  
      SET @cOutField05 = @cOrderKey    

      IF @cLabelNo <> ''
         SET @cOutField06 = @cLabelNo
      ELSE
         SET @cOutField06 = '' --LabelNo    
            
      IF @nFunc IN (540, 541, 547) -- (Chee03)
      BEGIN
         IF @cSortnPackByLoadLevel = '1'
         BEGIN
            SET @cOutField07 = ''
            SET @cOutField08 = 'SKU  BAL: ' + CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
            SET @cOutField09 = @cExtendedInfo
            SET @cOutField10 = ''
            SET @cOutField11 = @cExtendedInfo2
         END
         ELSE
         BEGIN
            SET @cOutField07 = 'STOR BAL: ' + CAST( @nConsCNT_Bal AS NVARCHAR(5)) + '/' + CAST( @nConsCNT_Total AS NVARCHAR(5))    
            SET @cOutField08 = 'SKU  BAL: ' + CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
            SET @cOutField09 = @cExtendedInfo
            SET @cOutField10 = 'STOR QTY: ' + CAST( @nConsQTY_Bal AS NVARCHAR(10)) + '/' + CAST( @nConsQTY_Total AS NVARCHAR(10))       --IN00346713 
            SET @cOutField11 = @cExtendedInfo2
         END
      END
      ELSE IF @nFunc = 543
      BEGIN
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = @cExtendedInfo
         SET @cOutField10 = ''
         SET @cOutField11 = @cExtendedInfo2
      END

      SET @cFieldAttr04 = '' --SKU    
      SET @cFieldAttr06 = '' --QTY    
    
      -- Go to label screen    
      SET @nScn  = @nScn - 1    
      SET @nStep = @nStep - 1    
   END    
   GOTO Quit    
    
   Step_4_Fail:    
   BEGIN
      SET @nExpQTY = @cOutField05
   END
END    
GOTO Quit    

/********************************************************************************    
Step 5. Screen 3234    
   PACKING COMPLETED    
   (Field01) 

   PRESS ESC for next 
   SKU packing
********************************************************************************/    
Step_5:    
BEGIN     
   SET @cConsigneeKey = ''

   -- Prepare prev screen var    
   SET @cOutField01 = @cLoadKey    
   SET @cOutField02 = '' --SKU    
   SET @cOutField03 = '' --UCC    
   
   -- Reset variable when finish packing the SKU
   SET @cOrderKey = ''
   SET @cSKU = ''
   SET @cLabelNo = ''
   
   -- Back to SKU screen    
   SET @nScn  = @nScn - 3    
   SET @nStep = @nStep - 3    
END    
GOTO Quit

/********************************************************************************    
Step 6. Screen 3235    
   EXIT PACKING?    
   1=YES    
   2=NO  
   3=CLOSE CARTON 
   OPTION:   (Field01)    
********************************************************************************/    
Step_6:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cOption = @cInField01    
    
      -- Validate blank    
      IF @cOption = ''    
      BEGIN    
         SET @nErrNo = 77365    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option needed    
         GOTO Step_6_Fail    
      END    
    
      -- Check option valid    
      IF @cOption NOT IN ('1', '2', '3')  -- Chee01
      BEGIN    
         SET @nErrNo = 77366    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option    
         GOTO Step_6_Fail    
      END    
    
      IF @cOption = '1' --YES    
      BEGIN    
        IF @cExtendedUpdateSP <> ''  
         BEGIN  
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
            BEGIN  
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +   
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cLabelPrinter, @cCloseCartonID, @cLoadKey, @cLabelNo, ' +   
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT'  
               SET @cSQLParam =  
                  '@nMobile        INT,            ' +  
                  '@nFunc          INT,            ' +  
                  '@cLangCode      NVARCHAR(3),    ' +  
                  '@nStep          INT,            ' +  
                  '@cUserName      NVARCHAR( 18),  ' +   
                  '@cFacility      NVARCHAR( 5),   ' +   
                  '@cStorerKey     NVARCHAR( 15),  ' +   
                  '@cLabelPrinter  NVARCHAR( 10),  ' +   
                  '@cCloseCartonID NVARCHAR( 20),  ' +   
                  '@cLoadKey       NVARCHAR( 10),  ' +   
                  '@cLabelNo       NVARCHAR( 20),  ' +   
                  '@nErrNo         INT OUTPUT, ' +    
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'  
                 
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,   
                  @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cPrinter, @cLabelNo, @cLoadKey, @cLabelNo,  
                  @nErrNo OUTPUT, @cErrMsg OUTPUT  
        
               IF @nErrNo <> 0  
                  GOTO Step_6_Fail  
            END  
         END  -- IF @cExtendedUpdateSP <> ''  
         
         SET @cConsigneeKey = ''    
             
         -- Prepare prev screen var    
         SET @cOutField01 = @cLoadKey    
         SET @cOutField02 = '' --SKU  
         SET @cOutField03 = '' --UCC 

         -- Reset variable when finish packing the SKU
         SET @cOrderKey = ''
         SET @cSKU = ''
         -- Chee01
         SET @cUCCNo = ''
         SET @cLabelNo = ''

         -- Back to SKU screen    
         SET @nScn  = @nScn - 4    
         SET @nStep = @nStep - 4    
      END    
    
      IF @cOption = '2' --NO    
      BEGIN    
         -- Extended info    
         IF @cExtendedInfoSP <> ''    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
            BEGIN    
               SET @cExtendedInfo = ''    

               SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +     
                  ' @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT'  +
                  ' ,@cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT' + -- (Chee01)
                  ' ,@nMobile' -- (Chee02)
   
               SET @cSQLParam =    
                  '@cLoadKey        NVARCHAR( 10), ' +    
                  '@cOrderKey       NVARCHAR( 10), ' +   -- (james07)
                  '@cConsigneeKey   NVARCHAR( 15), ' +    
                  '@cLabelNo        NVARCHAR( 20), ' +    
                  '@cStorer         NVARCHAR( 15), ' +      
                  '@cSKU            NVARCHAR( 20), ' +      
                  '@nExpQTY         INT,       ' +      
                  '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
                  '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +
                  '@cLangCode       NVARCHAR( 3),         ' + -- (Chee01)
                  '@bSuccess        INT           OUTPUT, ' + -- (Chee01)
                  '@nErrNo          INT           OUTPUT, ' + -- (Chee01)
                  '@cErrMsg         NVARCHAR( 20) OUTPUT, ' + -- (Chee01)
                  '@nMobile         INT '  -- (Chee02)
                   
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                  @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT  
                  , @cLangCode, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT   -- (Chee01)
                  , @nMobile -- (Chee02)
        
               -- (Chee01)
               IF @nErrNo <> 0    
                  GOTO Step_6_Fail 

               -- Prepare extended fields    
               IF @cExtendedInfo <> '' SET @cOutField07 = @cExtendedInfo    
            END    
         END    
      
         -- Prepare next screen var    
         SET @cOutField01 = @cSKU    
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)    
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)    
         SET @cOutField04 = CASE WHEN ISNULL(@cRemoveConsigneePrefix, '') > '' THEN REPLACE(RTRIM(@cConsigneeKey), RTRIM(@cRemoveConsigneePrefix), '') ELSE @cConsigneeKey END  
         SET @cOutField05 = @cOrderKey
         SET @cOutField06 = '' --LabelNo   
         IF @nFunc IN (540, 541, 547) -- (Chee03)
         BEGIN
            IF @cSortnPackByLoadLevel = 1
            BEGIN
               SET @cOutField07 = ''
               SET @cOutField08 = 'SKU  BAL: ' + CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
               SET @cOutField09 = @cExtendedInfo
               SET @cOutField10 = ''
               SET @cOutField11 = @cExtendedInfo2
            END
            ELSE
            BEGIN
               SET @cOutField07 = 'STOR BAL: ' + CAST( @nConsCNT_Bal AS NVARCHAR(5)) + '/' + CAST( @nConsCNT_Total AS NVARCHAR(5))    
               SET @cOutField08 = 'SKU  BAL: ' + CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
               SET @cOutField09 = @cExtendedInfo
               SET @cOutField10 = 'STOR QTY: ' + CAST( @nConsQTY_Bal AS NVARCHAR(10)) + '/' + CAST( @nConsQTY_Total AS NVARCHAR(10))       --IN00346713 
               SET @cOutField11 = @cExtendedInfo2
            END
         END
         ELSE IF @nFunc = 543
         BEGIN
            SET @cOutField07 = ''
            SET @cOutField08 = ''
            SET @cOutField09 = @cExtendedInfo
            SET @cOutField10 = ''
            SET @cOutField11 = @cExtendedInfo2
         END

         -- Back to label no screen    
         SET @nScn  = @nScn - 3    
         SET @nStep = @nStep - 3    
      END    
      
      -- (Chee01)
      IF @cOption = '3' -- CLOSE CARTON   
      BEGIN
         IF @cExtendedUpdateSP <> ''  
         BEGIN  
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
            BEGIN  
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +   
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cLabelPrinter, @cCloseCartonID, @cLoadKey, @cLabelNo, ' +   
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT'  
               SET @cSQLParam =  
                  '@nMobile        INT,            ' +  
                  '@nFunc          INT,            ' +  
                  '@cLangCode      NVARCHAR(3),    ' +  
                  '@nStep          INT,            ' +  
                  '@cUserName      NVARCHAR( 18),  ' +   
                  '@cFacility      NVARCHAR( 5),   ' +   
                  '@cStorerKey     NVARCHAR( 15),  ' +   
                  '@cLabelPrinter  NVARCHAR( 10),  ' +   
                  '@cCloseCartonID NVARCHAR( 20),  ' +   
                  '@cLoadKey       NVARCHAR( 10),  ' +   
                  '@cLabelNo       NVARCHAR( 20),  ' +   
                  '@nErrNo         INT OUTPUT, ' +    
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'  
                 
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,   
                  @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cPrinter, @cLabelNo, @cLoadKey, @cLabelNo,  
                  @nErrNo OUTPUT, @cErrMsg OUTPUT  
        
               IF @nErrNo <> 0  
                  GOTO Step_6_Fail  
            END  
         END  -- IF @cExtendedUpdateSP <> ''  

         -- Extended info    
         IF @cExtendedInfoSP <> ''    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
            BEGIN    
               SET @cExtendedInfo = ''    

               SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +     
                  ' @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT' +
                  ' ,@cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT' + -- (Chee01)
                  ' ,@nMobile' -- (Chee02)
    
               SET @cSQLParam =    
                  '@cLoadKey        NVARCHAR( 10), ' +    
                  '@cOrderKey       NVARCHAR( 10), ' +   -- (james07)
                  '@cConsigneeKey   NVARCHAR( 15), ' +    
                  '@cLabelNo        NVARCHAR( 20), ' +    
                  '@cStorer         NVARCHAR( 15), ' +      
                  '@cSKU            NVARCHAR( 20), ' +      
                  '@nExpQTY         INT,       ' +      
                  '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
                  '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +
                  '@cLangCode       NVARCHAR( 3),         ' + -- (Chee01)
                  '@bSuccess        INT           OUTPUT, ' + -- (Chee01)
                  '@nErrNo          INT           OUTPUT, ' + -- (Chee01)
                  '@cErrMsg         NVARCHAR( 20) OUTPUT, ' + -- (Chee01)
                  '@nMobile         INT '  -- (Chee02)
                   
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                  @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT    
                  , @cLangCode, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT   -- (Chee01)
                  , @nMobile -- (Chee02)
       
               -- (Chee01)
               IF @nErrNo <> 0    
                  GOTO Step_6_Fail 

               -- Prepare extended fields    
               IF @cExtendedInfo <> '' SET @cOutField07 = @cExtendedInfo    
            END    
         END    

         IF @cAutoGenerateLabelNo IN ('1', '2')-- (james15)
         BEGIN
            SET @cExtendedLabelNoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedLabelNoSP', @cStorerKey)
            IF @cExtendedLabelNoSP NOT IN ('0', '') AND 
               EXISTS( SELECT 1 FROM sys.sysobjects WHERE name = @cExtendedLabelNoSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedLabelNoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cLoadKey, @cOrderKey, @cPickSlipNo, @cSKU, @nCartonNo, ' +
                  ' @cLabelNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

               SET @cSQLParam =
                  '@nMobile                   INT,           ' +
                  '@nFunc                     INT,           ' +
                  '@cLangCode                 NVARCHAR( 3),  ' +
                  '@nStep                     INT,           ' +
                  '@nInputKey                 INT,           ' +
                  '@cStorerkey                NVARCHAR( 15), ' +
                  '@cLoadKey                  NVARCHAR( 10), ' +   
                  '@cOrderKey                 NVARCHAR( 10), ' + 
                  '@cPickSlipNo               NVARCHAR( 10), ' +      
                  '@cSKU                      NVARCHAR( 20), ' +
                  '@nCartonNo                 INT,           ' +
                  '@cLabelNo                  NVARCHAR( 20) OUTPUT,  ' +                     
                  '@nErrNo                    INT           OUTPUT,  ' +
                  '@cErrMsg                   NVARCHAR( 20) OUTPUT   '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cLoadKey, @cOrderKey, @cPickSlipNo, @cSKU, @nCartonNo, 
                  @cLabelNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 77381
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GET LABEL Fail'
                  GOTO Step_6_Fail
               END
            END
            ELSE
            BEGIN
               -- Get new LabelNo
               EXECUTE isp_GenUCCLabelNo
                        @cStorerKey,
                        @cLabelNo     OUTPUT,
                        @bSuccess     OUTPUT,
                        @nErrNo       OUTPUT,
                        @cErrMsg      OUTPUT

               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 77382
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GET LABEL Fail'
                  GOTO Step_6_Fail
               END
            END

            IF ISNULL( @cLabelNo, '') = ''
            BEGIN
               SET @nErrNo = 77383
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GET LABEL Fail'
               GOTO Step_6_Fail
            END
         END
      
         -- Prepare next screen var    
         SET @cOutField01 = @cSKU    
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)    
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)    
         SET @cOutField04 = CASE WHEN ISNULL(@cRemoveConsigneePrefix, '') > '' THEN REPLACE(RTRIM(@cConsigneeKey), RTRIM(@cRemoveConsigneePrefix), '') ELSE @cConsigneeKey END  
         SET @cOutField05 = @cOrderKey
         
         IF ISNULL( @cLabelNo, '') <> ''
            SET @cOutField06 = @cLabelNo
         ELSE
            SET @cOutField06 = '' --LabelNo   

         IF @nFunc IN (540, 541, 547) -- (Chee03)
         BEGIN
            IF @cSortnPackByLoadLevel = '1'
            BEGIN
               SET @cOutField07 = ''
               SET @cOutField08 = 'SKU  BAL: ' + CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
               SET @cOutField09 = @cExtendedInfo
               SET @cOutField10 = ''
               SET @cOutField11 = @cExtendedInfo2
            END
            ELSE
            BEGIN
               SET @cOutField07 = 'STOR BAL: ' + CAST( @nConsCNT_Bal AS NVARCHAR(5)) + '/' + CAST( @nConsCNT_Total AS NVARCHAR(5))    
               SET @cOutField08 = 'SKU  BAL: ' + CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
               SET @cOutField09 = @cExtendedInfo
               SET @cOutField10 = 'STOR QTY: ' + CAST( @nConsQTY_Bal AS NVARCHAR(10)) + '/' + CAST( @nConsQTY_Total AS NVARCHAR(10))       --IN00346713 
               SET @cOutField11 = @cExtendedInfo2
            END
         END
         ELSE IF @nFunc = 543
         BEGIN
            SET @cOutField07 = ''
            SET @cOutField08 = ''
            SET @cOutField09 = @cExtendedInfo
            SET @cOutField10 = ''
            SET @cOutField11 = @cExtendedInfo2
         END

         -- Back to label no screen    
         SET @nScn  = @nScn - 3    
         SET @nStep = @nStep - 3   
      END -- IF @cOption = '3' 
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Extended info    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo = ''    

            SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +     
               ' @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT'  +
               ' ,@cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT' + -- (Chee01)
               ' ,@nMobile' -- (Chee02)
     
            SET @cSQLParam =    
               '@cLoadKey        NVARCHAR( 10), ' +    
               '@cOrderKey       NVARCHAR( 10), ' +   -- (james07)
               '@cConsigneeKey   NVARCHAR( 15), ' +    
               '@cLabelNo        NVARCHAR( 20), ' +    
               '@cStorer         NVARCHAR( 15), ' +      
               '@cSKU            NVARCHAR( 20), ' +      
               '@nExpQTY         INT,       ' +      
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
               '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +
               '@cLangCode       NVARCHAR( 3),         ' + -- (Chee01)
               '@bSuccess        INT           OUTPUT, ' + -- (Chee01)
               '@nErrNo          INT           OUTPUT, ' + -- (Chee01)
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' + -- (Chee01)
               '@nMobile         INT '  -- (Chee02)
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT 
               , @cLangCode, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT   -- (Chee01)
               , @nMobile -- (Chee02)
   
            -- (Chee01)
            IF @nErrNo <> 0    
               GOTO Step_6_Fail 
    
            -- Prepare extended fields    
            IF @cExtendedInfo <> '' SET @cOutField07 = @cExtendedInfo    
         END    
      END    
         
      -- Prepare next screen var    
      SET @cOutField01 = @cSKU    
      SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)    
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)    
      SET @cOutField04 = CASE WHEN ISNULL(@cRemoveConsigneePrefix, '') > '' THEN REPLACE(RTRIM(@cConsigneeKey), RTRIM(@cRemoveConsigneePrefix), '') ELSE @cConsigneeKey END
      SET @cOutField05 = @cOrderKey    
      SET @cOutField06 = '' --LabelNo   
      IF @nFunc IN (540, 541, 547) -- (Chee03)
      BEGIN
         IF @cSortnPackByLoadLevel = '1'
         BEGIN
            SET @cOutField07 = ''
            SET @cOutField08 = 'SKU  BAL: ' + CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
            SET @cOutField09 = @cExtendedInfo
            SET @cOutField10 = ''
            SET @cOutField11 = @cExtendedInfo2
         END
         ELSE
         BEGIN
            SET @cOutField07 = 'STOR BAL: ' + CAST( @nConsCNT_Bal AS NVARCHAR(5)) + '/' + CAST( @nConsCNT_Total AS NVARCHAR(5))    
            SET @cOutField08 = 'SKU  BAL: ' + CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
            SET @cOutField09 = @cExtendedInfo
            SET @cOutField10 = 'STOR QTY: ' + CAST( @nConsQTY_Bal AS NVARCHAR(10)) + '/' + CAST( @nConsQTY_Total AS NVARCHAR(10))       --IN00346713 
            SET @cOutField11 = @cExtendedInfo2
         END
      END
      ELSE IF @nFunc = 543
      BEGIN
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = @cExtendedInfo
         SET @cOutField10 = ''
         SET @cOutField11 = @cExtendedInfo2
      END
      
      -- Back to LabelNo screen    
      SET @nScn  = @nScn - 3    
      SET @nStep = @nStep - 3    
   END    
   GOTO Quit    
    
   Step_6_Fail:    
   BEGIN    
      SET @cOption = ''    
      SET @cOutField01 = '' -- Option    
   END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 7. Screen = 3236    
   OrderKey       (Field01)    
   Label No       (Field02)    
   Carton Type    (Field03, input)    
********************************************************************************/    
Step_7:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cCartonType = @cInField03    

      IF NOT EXISTS (SELECT 1 FROM Cartonization CZ WITH (NOLOCK) 
                     JOIN Storer ST WITH (NOLOCK) ON CZ.CartonizationGroup = ST.CartonGroup
                     WHERE CartonType = @cCartonType
                     AND   ST.StorerKey = @cStorerKey)
      BEGIN  
         SET @nErrNo = 77367  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INV CTN TYPE'  
         GOTO Step_7_Fail  
      END  

      -- Get SKU info    
      SELECT 
         @cSKUDescr = Descr, 
         @cBUSR10 = BUSR10    -- (james02)
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
      AND   SKU = @cSKU   

      -- IF UCCNo is not null, do pack confirm
      IF ISNULL(@cUCCNo, '') <> ''
      BEGIN
         -- Pack Confirm 
         SET @cSortAndPackConfirmTask_SP = rdt.RDTGetConfig( @nFunc, 'SortAndPackConfirmTask_SP', @cStorerKey)
         IF ISNULL(@cSortAndPackConfirmTask_SP, '') NOT IN ('', '0')
         BEGIN
            SET @nErrNo = 0
            SET @cSortAndPackGetCtnType_SP = rdt.RDTGetConfig( @nFunc, 'SortAndPackGetCtnType_SP', @cStorerKey)
            IF ISNULL(@cSortAndPackGetCtnType_SP, '') NOT IN ('', '0')
            BEGIN
               SET @cDefaultCartonType = ''
               EXEC RDT.RDT_SortAndPackGetCtnType_Wrapper
                   @n_Mobile        = @nMobile
                  ,@n_Func          = @nFunc
                  ,@c_LangCode      = @cLangCode
                  ,@c_SPName        = @cSortAndPackGetCtnType_SP
                  ,@c_PackByType    = @cPackByType
                  ,@c_Type          = 'NEXT'
                  ,@c_LoadKey       = @cLoadKey
                  ,@c_Storerkey     = @cStorerKey
                  ,@c_SKU           = @cSKU
                  ,@c_ConsigneeKey  = @cConsigneeKey  OUTPUT
                  ,@c_OrderKey      = @cOrderKey      OUTPUT
                  ,@c_oFieled01     = @c_oFieled01    OUTPUT
                  ,@c_oFieled02     = @c_oFieled02    OUTPUT
                  ,@c_oFieled03     = @c_oFieled03    OUTPUT
                  ,@c_oFieled04     = @c_oFieled04    OUTPUT
                  ,@c_oFieled05     = @c_oFieled05    OUTPUT
                  ,@c_oFieled06     = @c_oFieled06    OUTPUT
                  ,@c_oFieled07     = @c_oFieled07    OUTPUT
                  ,@c_oFieled08     = @c_oFieled08    OUTPUT
                  ,@c_oFieled09     = @c_oFieled09    OUTPUT
                  ,@c_oFieled10     = @c_oFieled10    OUTPUT
                  ,@c_oFieled11     = @c_oFieled11    OUTPUT
                  ,@c_oFieled12     = @c_oFieled12    OUTPUT
                  ,@c_oFieled13     = @c_oFieled13    OUTPUT
                  ,@c_oFieled14     = @c_oFieled14    OUTPUT
                  ,@c_oFieled15     = @c_oFieled15    OUTPUT
                  ,@b_Success       = @b_Success      OUTPUT
                  ,@n_ErrNo         = @nErrNo         OUTPUT
                  ,@c_ErrMsg        = @cErrMsg        OUTPUT

               SET @cDefaultCartonType = @c_oFieled01 
            END
            ELSE
            BEGIN
               SET @cDefaultCartonType = ''
               SET @cDefaultCartonType = rdt.RDTGetConfig( @nFunc, 'DefaultCartonType', @cStorerkey)
            END

            IF @cDefaultQTY IN ('', '0')
               EXEC RDT.RDT_SortAndPackConfirmTask_Wrapper
                   @n_Mobile        = @nMobile
                  ,@n_Func          = @nFunc
                  ,@c_LangCode      = @cLangCode
                  ,@c_SPName        = @cSortAndPackConfirmTask_SP
                  ,@c_PackByType    = @cPackByType
                  ,@c_LoadKey       = @cLoadKey
                  ,@c_OrderKey      = @cOrderKey      
                  ,@c_ConsigneeKey  = @cConsigneeKey  
                  ,@c_Storerkey     = @cStorerKey
                  ,@c_SKU           = @cSKU
                  ,@n_Qty           = @nExpQTY 
                  ,@c_PickSlipNo    = @cPickSlipNo
                  ,@c_LabelNo       = @cLabelNo
                  ,@c_CartonType    = @cDefaultCartonType
                  ,@b_Success       = @b_Success      OUTPUT
                  ,@n_ErrNo         = @nErrNo         OUTPUT
                  ,@c_ErrMsg        = @cErrMsg        OUTPUT
                  ,@c_UCCNo         = @cUCCNo         -- Chee01
            ELSE
               EXEC RDT.RDT_SortAndPackConfirmTask_Wrapper
                   @n_Mobile        = @nMobile
                  ,@n_Func          = @nFunc
                  ,@c_LangCode      = @cLangCode
                  ,@c_SPName        = @cSortAndPackConfirmTask_SP
                  ,@c_PackByType    = @cPackByType
                  ,@c_LoadKey       = @cLoadKey
                  ,@c_OrderKey      = @cOrderKey      
                  ,@c_ConsigneeKey  = @cConsigneeKey  
                  ,@c_Storerkey     = @cStorerKey
                  ,@c_SKU           = @cSKU
                  ,@n_Qty           = @cDefaultQTY 
                  ,@c_PickSlipNo    = @cPickSlipNo
                  ,@c_LabelNo       = @cLabelNo
                  ,@c_CartonType    = @cDefaultCartonType
                  ,@b_Success       = @b_Success      OUTPUT
                  ,@n_ErrNo         = @nErrNo         OUTPUT
                  ,@c_ErrMsg        = @cErrMsg        OUTPUT
                  ,@c_UCCNo         = @cUCCNo         -- Chee01

            IF @nErrNo <> 0    
               GOTO Step_7_Fail    
         END
         ELSE
         BEGIN
            EXEC rdt.rdt_SortAndPack_Confirm @nMobile, @nFunc, @cLangCode, @cPackByType, @cLoadKey, @cOrderKey, @cConsigneeKey, @cStorerKey, @cSKU, @nExpQTY, @cLabelNo, @cCartonType     
               ,@nErrNo        OUTPUT    
               ,@cErrMsg       OUTPUT  

            IF @nErrNo <> 0    
               GOTO Step_7_Fail    
         END

         SET @cOutField01 = @cUCCNo
         SET @cOutField02 = '' 

         -- Go to SKU completed screen  (Chee03)
         IF @nFunc = 547
         BEGIN
            SET @nScn  = @nScn + 1   
            SET @nStep = @nStep + 1
         END
         ELSE
         BEGIN
            SET @nScn  = @nScn - 2   
            SET @nStep = @nStep - 2 
         END
            
         GOTO Quit
      END -- IF ISNULL(@cUCCNo, '') <> '' 

      -- Extended info    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo = ''    

            SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +     
               ' @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT' +
               ' ,@cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT' + -- (Chee01)
               ' ,@nMobile' -- (Chee02)
  
            SET @cSQLParam =    
               '@cLoadKey        NVARCHAR( 10), ' +    
               '@cOrderKey       NVARCHAR( 10), ' +   -- (james07)
               '@cConsigneeKey   NVARCHAR( 15), ' +    
               '@cLabelNo        NVARCHAR( 20), ' +    
               '@cStorer         NVARCHAR( 15), ' +      
               '@cSKU            NVARCHAR( 20), ' +      
               '@nExpQTY         INT,       ' +      
               '@cExtendedInfo   NVARCHAR( 20)   OUTPUT, ' +
               '@cExtendedInfo2  NVARCHAR( 20)   OUTPUT, ' +
               '@cLangCode       NVARCHAR( 3),         ' + -- (Chee01)
               '@bSuccess        INT             OUTPUT, ' + -- (Chee01)
               '@nErrNo          INT             OUTPUT, ' + -- (Chee01)
               '@cErrMsg         NVARCHAR( 20)   OUTPUT, ' + -- (Chee01)
               '@nMobile         INT '  -- (Chee02)
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT 
               , @cLangCode, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT   -- (Chee01)
               , @nMobile -- (Chee02)
    
            -- (Chee01)
            IF @nErrNo <> 0    
               GOTO Step_7_Fail 

            -- Prepare extended fields    
            IF @cExtendedInfo <> '' SET @cOutField07 = @cExtendedInfo    
         END    
      END    

      -- Prepare next screen var    
      SET @nPackQTY = 0    
      SET @cOutField01 = CASE WHEN ISNULL(@cRemoveConsigneePrefix, '') > '' THEN REPLACE(RTRIM(@cConsigneeKey), RTRIM(@cRemoveConsigneePrefix), '') ELSE @cConsigneeKey END
      SET @cOutField02 = @cOrderKey    
      SET @cOutField03 = @cLabelNo    
      SET @cOutField04 = CASE WHEN @cDisableSKUField = '1' THEN @cSKU ELSE '' END    
      SET @cOutField05 = @nExpQTY    
      SET @cOutField06 = CASE WHEN @cDefaultQTY = '1' THEN CASE WHEN @cSortnPackPieceScan = '1' THEN '1' ELSE CAST( @nExpQTY AS NVARCHAR( 5)) END ELSE '' END --ActQTY    
--      SET @cOutField07 = CAST( @nConsQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nConsQTY_Total AS NVARCHAR(5))    
      SET @cOutField08 = CASE WHEN @cPackByType = 'CONSO'     
                              THEN CAST( @nConsQTY_Bal AS NVARCHAR(10)) + '/' + CAST( @nConsQTY_Total AS NVARCHAR(10))        --IN00346713 
                              ELSE CAST( @nOrderQTY_Bal AS NVARCHAR(10)) + '/' + CAST( @nOrderQTY_Total AS NVARCHAR(10)) END    --IN00346713
      SET @cOutField09 = @cExtendedInfo    
      SET @cOutField10 = @cExtendedInfo2    
      SET @cOutField11 = @cSKU
          
      -- Enable / disable SKU QTY field    
      SET @cFieldAttr04 = CASE WHEN @cDisableSKUField = '1' THEN 'O' ELSE '' END --SKU    
      SET @cFieldAttr06 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END --QTY    
             
      -- Go to QTY screen    
      SET @nScn  = @nScn - 3    
      SET @nStep = @nStep - 3   
 
   END

   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Extended info    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo = ''    

            SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +     
               ' @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT' +
               ' ,@cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT' + -- (Chee01)
               ' ,@nMobile' -- (Chee02)
  
            SET @cSQLParam =    
               '@cLoadKey        NVARCHAR( 10), ' +    
               '@cOrderKey       NVARCHAR( 10), ' +   -- (james07)
               '@cConsigneeKey   NVARCHAR( 15), ' +    
               '@cLabelNo        NVARCHAR( 20), ' +    
               '@cStorer         NVARCHAR( 15), ' +      
               '@cSKU            NVARCHAR( 20), ' +      
               '@nExpQTY         INT,       ' +      
               '@cExtendedInfo   NVARCHAR( 20)   OUTPUT, ' +
               '@cExtendedInfo2  NVARCHAR( 20)   OUTPUT, ' +
               '@cLangCode       NVARCHAR( 3),         ' + -- (Chee01)
               '@bSuccess        INT             OUTPUT, ' + -- (Chee01)
               '@nErrNo          INT             OUTPUT, ' + -- (Chee01)
               '@cErrMsg         NVARCHAR( 20)   OUTPUT, ' + -- (Chee01)
               '@nMobile         INT '  -- (Chee02)
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT 
               , @cLangCode, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT   -- (Chee01)
               , @nMobile -- (Chee02)
    
            -- (Chee01)
            IF @nErrNo <> 0    
               GOTO Step_7_Fail 

            -- Prepare extended fields    
            IF @cExtendedInfo <> '' SET @cOutField07 = @cExtendedInfo    
         END    
      END    

      -- Prepare next screen var    
      SET @cOutField01 = @cSKU    
      SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)    
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)    
      SET @cOutField04 = CASE WHEN ISNULL(@cRemoveConsigneePrefix, '') > '' THEN REPLACE(RTRIM(@cConsigneeKey), RTRIM(@cRemoveConsigneePrefix), '') ELSE @cConsigneeKey END  
      SET @cOutField05 = @cOrderKey    
      SET @cOutField06 = '' --LabelNo    
      IF @nFunc IN (540, 541, 547) -- (Chee03)
      BEGIN
         IF @cSortnPackByLoadLevel = '1'
         BEGIN
            SET @cOutField07 = ''
            SET @cOutField08 = 'SKU  BAL: ' + CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
            SET @cOutField09 = @cExtendedInfo
            SET @cOutField10 = ''
            SET @cOutField11 = @cExtendedInfo2
         END
         ELSE
         BEGIN
            SET @cOutField07 = 'STOR BAL: ' + CAST( @nConsCNT_Bal AS NVARCHAR(5)) + '/' + CAST( @nConsCNT_Total AS NVARCHAR(5))    
            SET @cOutField08 = 'SKU  BAL: ' + CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
            SET @cOutField09 = @cExtendedInfo
            SET @cOutField10 = 'STOR QTY: ' + CAST( @nConsQTY_Bal AS NVARCHAR(10)) + '/' + CAST( @nConsQTY_Total AS NVARCHAR(10))       --IN00346713 
            SET @cOutField11 = @cExtendedInfo2
         END
      END
      ELSE IF @nFunc = 543
      BEGIN
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = @cExtendedInfo
         SET @cOutField10 = ''
         SET @cOutField11 = @cExtendedInfo2
      END
      
      -- Back to LabelNo screen    
      SET @nScn  = @nScn - 4    
      SET @nStep = @nStep - 4    
   END    
   GOTO Quit    
   
   Step_7_Fail:    
   BEGIN    
      SET @cCartonType = ''
      SET @cOutField03 = ''  

      IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_UCC')) >=0 
      BEGIN
         CLOSE CURSOR_UCC      
         DEALLOCATE CURSOR_UCC
      END   
   END    
END    
GOTO Quit   

/********************************************************************************    
Step 8. Screen 3237    
   PACKING COMPLETED    
   (Field01) 

   PRESS ESC for next 
   SKU packing

   CLOSE CARTON?'
   1 = YES'
   2 = NO'
   OPTION:   (Field02)  
********************************************************************************/    
Step_8:    
BEGIN     
   -- (Chee01)
   -- Screen mapping    
   SET @cOption = @cInField02    
 
   IF @nInputKey = 1 -- ENTER    
   BEGIN  
      -- Validate blank    
      IF @cOption = ''    
      BEGIN    
         SET @nErrNo = 77373    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option needed    
         GOTO Step_8_Fail    
      END    
    
      -- Check option valid    
      IF @cOption NOT IN ('1', '2')
      BEGIN    
         SET @nErrNo = 77374    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option    
         GOTO Step_8_Fail    
      END    
    
      IF @cOption = '1' --YES    
      BEGIN   
         IF @cExtendedUpdateSP <> ''  
         BEGIN  
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
            BEGIN  
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +   
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cLabelPrinter, @cCloseCartonID, @cLoadKey, @cLabelNo, ' +   
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT'  
               SET @cSQLParam =  
                  '@nMobile        INT,            ' +  
                  '@nFunc          INT,            ' +  
                  '@cLangCode      NVARCHAR(3),    ' +  
                  '@nStep          INT,            ' +  
                  '@cUserName      NVARCHAR( 18),  ' +   
                  '@cFacility      NVARCHAR( 5),   ' +   
                  '@cStorerKey     NVARCHAR( 15),  ' +   
                  '@cLabelPrinter  NVARCHAR( 10),  ' +   
                  '@cCloseCartonID NVARCHAR( 20),  ' +   
                  '@cLoadKey       NVARCHAR( 10),  ' +   
                  '@cLabelNo       NVARCHAR( 20),  ' +   
                  '@nErrNo         INT OUTPUT, ' +    
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'  
                 
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,   
                  @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cPrinter, @cLabelNo, @cLoadKey, @cLabelNo,  
                  @nErrNo OUTPUT, @cErrMsg OUTPUT  
        
               IF @nErrNo <> 0  
                  GOTO Step_8_Fail  
            END  
         END  -- IF @cExtendedUpdateSP <> ''  
      END -- IF @cOption = '1'
      ELSE
      BEGIN
         -- ExtendedValidateSP (Chee02)
         IF @cExtendedValidateSP <> ''  
         BEGIN  
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
            BEGIN  
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +   
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cSKU, @cLoadKey, @cConsigneeKey, @cPickSlipNo, @cOrderKey, @cLabelNo, ' +   
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT'  
               SET @cSQLParam =  
                  '@nMobile        INT,            ' +  
                  '@nFunc          INT,            ' +  
                  '@cLangCode      NVARCHAR(3),    ' +  
                  '@nStep          INT,            ' +  
                  '@cUserName      NVARCHAR( 18),  ' +   
                  '@cFacility      NVARCHAR( 5),   ' +   
                  '@cStorerKey     NVARCHAR( 15),  ' +   
                  '@cSKU           NVARCHAR( 20),  ' +   
                  '@cLoadKey       NVARCHAR( 10),  ' +  
                  '@cConsigneeKey  NVARCHAR( 15),  ' +   
                  '@cPickSlipNo    NVARCHAR( 10),  ' +   
                  '@cOrderKey      NVARCHAR( 10),  ' +   
                  '@cLabelNo       NVARCHAR( 20),  ' +   
                  '@nErrNo         INT OUTPUT, ' +    
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'  
                 
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,   
                  @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cSKU, @cLoadKey, @cConsigneeKey, @cPickSlipNo, @cOrderKey, @cLabelNo, 
                  @nErrNo OUTPUT, @cErrMsg OUTPUT  
        
               IF @nErrNo <> 0  
                  GOTO Step_8_Fail  
            END  
         END  -- IF @cExtendedValidateSP <> ''  
      END

      -- Reset ConsigneeKey and get task to decide which screen to go
      SET @cConsigneeKey = ''
      SET @cUCCNo = ''
      SET @nErrNo = 0
      SET @cSortAndPackGetNextTask_SP = rdt.RDTGetConfig( @nFunc, 'SortAndPackGetNextTask_SP', @cStorerKey)
      IF ISNULL(@cSortAndPackGetNextTask_SP, '') NOT IN ('', '0')
      BEGIN
         EXEC RDT.RDT_SortAndPackGetNextTask_Wrapper
             @n_Mobile        = @nMobile
            ,@n_Func          = @nFunc
            ,@c_LangCode      = @cLangCode
            ,@c_SPName        = @cSortAndPackGetNextTask_SP
            ,@c_PackByType    = @cPackByType
            ,@c_Type          = @cType
            ,@c_LoadKey       = @cLoadKey
            ,@c_Storerkey     = @cStorerKey
            ,@c_SKU           = @cSKU
            ,@c_ConsigneeKey  = @cConsigneeKey  OUTPUT
            ,@c_OrderKey      = @cOrderKey      OUTPUT
            ,@c_oFieled01     = @c_oFieled01    OUTPUT
            ,@c_oFieled02     = @c_oFieled02    OUTPUT
            ,@c_oFieled03     = @c_oFieled03    OUTPUT
            ,@c_oFieled04     = @c_oFieled04    OUTPUT
            ,@c_oFieled05     = @c_oFieled05    OUTPUT
            ,@c_oFieled06     = @c_oFieled06    OUTPUT
            ,@c_oFieled07     = @c_oFieled07    OUTPUT
            ,@c_oFieled08     = @c_oFieled08    OUTPUT
            ,@c_oFieled09     = @c_oFieled09    OUTPUT
            ,@c_oFieled10     = @c_oFieled10    OUTPUT
            ,@c_oFieled11     = @c_oFieled11    OUTPUT
            ,@c_oFieled12     = @c_oFieled12    OUTPUT
            ,@c_oFieled13     = @c_oFieled13    OUTPUT
            ,@c_oFieled14     = @c_oFieled14    OUTPUT
            ,@c_oFieled15     = @c_oFieled15    OUTPUT
            ,@b_Success       = @b_Success      OUTPUT
            ,@n_ErrNo         = @nErrNo         OUTPUT
            ,@c_ErrMsg        = @cErrMsg        OUTPUT

         SET @nExpQTY         = CAST(@c_oFieled01 AS INT)
         SET @nConsCNT_Total  = CAST(@c_oFieled02 AS INT)
         SET @nConsCNT_Bal    = CAST(@c_oFieled03 AS INT)
         SET @nConsQTY_Total  = CAST(@c_oFieled04 AS INT)
         SET @nConsQTY_Bal    = CAST(@c_oFieled05 AS INT)
         SET @nOrderQTY_Total = CAST(@c_oFieled06 AS INT)
         SET @nOrderQTY_Bal   = CAST(@c_oFieled07 AS INT)
         SET @nSKUQTY_Total   = CAST(@c_oFieled08 AS INT)
         SET @nSKUQTY_Bal     = CAST(@c_oFieled09 AS INT)
      END
      ELSE
      BEGIN
         EXEC rdt.rdt_SortAndPack_GetTask @nMobile, @nFunc, @cLangCode, @cPackByType, @cType, @cLoadKey, @cStorerKey, @cSKU    
            ,@cConsigneeKey   OUTPUT    
            ,@cOrderKey       OUTPUT    
            ,@nExpQTY         OUTPUT    
            ,@nConsCNT_Total  OUTPUT    
            ,@nConsCNT_Bal    OUTPUT    
            ,@nConsQTY_Total  OUTPUT    
            ,@nConsQTY_Bal    OUTPUT    
            ,@nOrderQTY_Total OUTPUT    
            ,@nOrderQTY_Bal   OUTPUT    
            ,@nSKUQTY_Total   OUTPUT    
            ,@nSKUQTY_Bal     OUTPUT    
            ,@nErrNo          OUTPUT    
            ,@cErrMsg         OUTPUT    
      END
      
      IF @nErrNo = 0 -- More task    
      BEGIN
         -- Extended info    
         IF @cExtendedInfoSP <> ''    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
            BEGIN    
               SET @cExtendedInfo = ''    
                   
               SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +     
                  ' @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo OUTPUT, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT' +
                  ' ,@cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT' + -- (Chee01)
                  ' ,@nMobile' -- (Chee02)
 
               SET @cSQLParam =    
                  '@cLoadKey        NVARCHAR( 10), ' +    
                  '@cOrderKey       NVARCHAR( 10), ' +   -- (james07)
                  '@cConsigneeKey   NVARCHAR( 15), ' +    
                  '@cLabelNo        NVARCHAR( 20) OUTPUT, ' +    
                  '@cStorer         NVARCHAR( 15), ' +      
                  '@cSKU            NVARCHAR( 20), ' +      
                  '@nExpQTY         INT,       ' +      
                  '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
                  '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +
                  '@cLangCode       NVARCHAR( 3),         ' + -- (Chee01)
                  '@bSuccess        INT           OUTPUT, ' + -- (Chee01)
                  '@nErrNo          INT           OUTPUT, ' + -- (Chee01)
                  '@cErrMsg         NVARCHAR( 20) OUTPUT, ' + -- (Chee01)
                  '@nMobile         INT '  -- (Chee02)
                   
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                  @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo OUTPUT, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT  
                  , @cLangCode, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT   -- (Chee01)
                  , @nMobile -- (Chee02)

               -- (Chee01)
               IF @nErrNo <> 0    
                  GOTO Step_8_Fail 
       
               -- Prepare extended fields    
               IF @cExtendedInfo <> '' SET @cOutField07 = @cExtendedInfo    
            END    
         END    

         -- Prepare next screen var    
         SET @cOutField01 = @cSKU    
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)    
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)    
         SET @cOutField04 = CASE WHEN ISNULL(@cRemoveConsigneePrefix, '') > '' THEN REPLACE(RTRIM(@cConsigneeKey), RTRIM(@cRemoveConsigneePrefix), '') ELSE @cConsigneeKey END
         SET @cOutField05 = @cOrderKey    

         IF ISNULL( @cLabelNo, '') <> ''
            SET @cOutField06 = @cLabelNo
         ELSE
            SET @cOutField06 = '' --LabelNo    

         IF @nFunc IN (540, 541, 547) -- (Chee03)
         BEGIN
            IF @cSortnPackByLoadLevel = '1'
            BEGIN
               SET @cOutField07 = ''
               SET @cOutField08 = 'SKU  BAL: ' + CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
               SET @cOutField09 = @cExtendedInfo
               SET @cOutField10 = ''
               SET @cOutField11 = @cExtendedInfo2
            END
            ELSE
            BEGIN
               SET @cOutField07 = 'STOR BAL: ' + CAST( @nConsCNT_Bal AS NVARCHAR(5)) + '/' + CAST( @nConsCNT_Total AS NVARCHAR(5))    
               SET @cOutField08 = 'SKU  BAL: ' + CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))   
               SET @cOutField09 = @cExtendedInfo
               SET @cOutField10 = 'STOR QTY: ' + CAST( @nConsQTY_Bal AS NVARCHAR(10)) + '/' + CAST( @nConsQTY_Total AS NVARCHAR(10))       --IN00346713 
               SET @cOutField11 = @cExtendedInfo2
            END
         END
         ELSE IF @nFunc = 543
         BEGIN
            SET @cOutField07 = ''
            SET @cOutField08 = ''
            SET @cOutField09 = @cExtendedInfo
            SET @cOutField10 = ''
            SET @cOutField11 = @cExtendedInfo2
         END
         
         -- Go to LabelNo screen    
         SET @nScn  = @nScn - 5
         SET @nStep = @nStep - 5
         GOTO Quit    
      END    
   END -- IF @nInputKey = 1 

   -- (james13)  
   -- Event log      
   EXEC RDT.rdt_STD_EventLog    
      @cActionType   = '3', -- Picking      
      @cUserID       = @cUserName,      
      @nMobileNo     = @nMobile,      
      @nFunctionID   = @nFunc,      
      @cFacility     = @cFacility,      
      @cStorerKey    = @cStorerkey,      
      @cSKU          = @cSKU,      
      @nQTY          = @nActQTY,      
      @cLoadKey      = @cLoadKey,      
      @cUCC          = @cUCCNo,  
      @cLabelNo      = @cLabelNo,  
      @cCartonType   = @cCartonType,  
      @nStep         = @nStep  

   -- ExtendedValidateSP (Chee02)
   IF @cExtendedValidateSP <> ''  
   BEGIN  
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
      BEGIN  
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +   
            ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cSKU, @cLoadKey, @cConsigneeKey, @cPickSlipNo, @cOrderKey, @cLabelNo, ' +   
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT'  
         SET @cSQLParam =  
            '@nMobile        INT,            ' +  
            '@nFunc          INT,            ' +  
            '@cLangCode      NVARCHAR(3),    ' +  
            '@nStep          INT,            ' +  
            '@cUserName      NVARCHAR( 18),  ' +   
            '@cFacility      NVARCHAR( 5),   ' +   
            '@cStorerKey     NVARCHAR( 15),  ' +   
            '@cSKU           NVARCHAR( 20),  ' +   
            '@cLoadKey       NVARCHAR( 10),  ' +  
            '@cConsigneeKey  NVARCHAR( 15),  ' +   
            '@cPickSlipNo    NVARCHAR( 10),  ' +   
            '@cOrderKey      NVARCHAR( 10),  ' +   
            '@cLabelNo       NVARCHAR( 20),  ' +   
            '@nErrNo         INT OUTPUT, ' +    
            '@cErrMsg        NVARCHAR( 20) OUTPUT'  
           
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,   
            @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cSKU, @cLoadKey, @cConsigneeKey, @cPickSlipNo, @cOrderKey, @cLabelNo, 
            @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
         IF @nErrNo <> 0  
            GOTO Step_8_Fail  
      END  
   END  -- IF @cExtendedValidateSP <> ''  

   SET @cConsigneeKey = ''

   -- Prepare prev screen var    
   SET @cOutField01 = @cLoadKey    
   SET @cOutField02 = '' --SKU    
   SET @cOutField03 = '' --UCC    
   
   -- Reset variable when finish packing the SKU
   SET @cOrderKey = ''
   SET @cSKU = ''
   -- Chee01
   SET @cLabelNo = ''
   
   -- Back to SKU screen    
   SET @nScn  = @nScn - 6    
   SET @nStep = @nStep - 6    

   GOTO Quit    
    
   Step_8_Fail:    
   BEGIN    
      SET @cOption = ''    
      SET @cOutField02 = '' -- Option    
   END    
END    
GOTO Quit    
 
/********************************************************************************    
Quit. Update back to I/O table, ready to be pick up by JBOSS    
********************************************************************************/    
Quit:    
BEGIN    
   UPDATE RDTMOBREC WITH (ROWLOCK) SET    
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,    
      Func   = @nFunc,    
      Step   = @nStep,    
      Scn    = @nScn,    
    
      StorerKey  = @cStorerKey,    
      Facility   = @cFacility,    
      -- UserName   = @cUserName,    
      Printer    = @cPrinter,    
    
      V_LoadKey  = @cLoadKey,    
      V_SKU      = @cSKU,    
      V_SKUDescr = @cSKUDescr,    
      V_ConsigneeKey = @cConsigneeKey,    
      V_OrderKey = @cOrderKey,     
      V_CaseID   = @cLabelNo,    
      --V_QTY      = @nExpQTY,    
      
      @nCartonNo     = V_Cartonno,   
   
      V_Integer1         = @nExpQTY,
      V_Integer2         = @nConsCNT_Total,
      V_Integer3         = @nConsCNT_Bal,
      V_Integer4         = @nConsQTY_Total,
      V_Integer5         = @nConsQTY_Bal,
      V_Integer6         = @nOrderQTY_Total,
      V_Integer7         = @nOrderQTY_Bal,
      V_Integer8         = @nSKUQTY_Total,
      V_Integer9         = @nSKUQTY_Bal,
      V_Integer10        = @nPackQTY,
      V_Integer11        = @nLoadScannedCount,
      V_Integer12        = @nActQTY,  
      V_Integer13        = @nIsUCC,

      V_String1  = @cAutoGenerateLabelNo,
      V_String10 = @cLabelNoChkSP,    
      V_String11 = @cPackByType,    
      V_String12 = @cDefaultQTY,    
      V_String13 = @cDisableQTYField,    
      V_String14 = @cDisableSKUField,    
      V_String15 = @cExtendedInfoSP,     
      V_String16 = @cAllowSkipTask,     
      V_String17 = @cRemoveConsigneePrefix,  
      V_String18 = @cPickSlipNo, 

      V_String20 = @cCartonType, 
      V_String21 = @cDefaultCartonType, 
      V_String22 = @cExtendedInfo,
      V_String23 = @cExtendedUpdateSP, -- (Chee01)
      V_String24 = @cUCCNo, -- (Chee01)
      V_String25 = @cExtendedValidateSP, -- (Chee02)
      V_String26 = @cShowCartonTypeScreenSP, -- (james11)
      V_String27 = @cExtendedInfo2,          -- (james11)
      V_String28 = @cShowCartonTypeScreen,   -- (james11)
      V_String29 = @cCloseCarton,            -- (james11)
      V_String30 = @cLastLoadKey,            -- (james12)
      V_String31 = @cSortnPackByLoadLevel,   -- (james12)
      --V_String32 = @nLoadScannedCount,       -- (james12)
      V_String33 = @cSortnPackPieceScan,     -- (james12)
      V_String34 = @cSortnPackFilterUOM,     -- (james12)
      V_String35 = @cSkipPack,               -- (james12)
   
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