SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************/      
/* Store procedure: rdtfnc_CartonInquiry                                     */      
/* Copyright      : LFL                                                      */      
/*                                                                           */      
/* Purpose: ANF Carton Inquiry                                               */      
/*                                                                           */      
/* Modifications log:                                                        */      
/*                                                                           */      
/* Date       Rev  Author   Purposes                                         */      
/* 2014-03-24 1.0  Chee     SOS#297234 Created                               */     
/* 2014-05-14 1.1  ChewKP   SubString C.Description to avoid data truncation */  
/*                          in RDT (ChewKP01)                                */     
/* 2014-06-06 1.2  ChewKP   Retrieve only latest Tote information (ChewKP02) */
/* 2014-07-07 1.3  ChewKP   Add in DropIDType = 'PP', 'STOTE' (ChewKP03)     */
/* 2014-09-08 1.4  ChewKP   SOS#318855 -- Add Multis / Singles (ChewKP04)    */
/* 2016-04-19 1.5  ChewKP   SOS#368661 -Add New Inquiry DropIDType (ChewKP05)*/
/* 2016-09-30 1.6  Ung      Performance tuning                               */
/* 2018-10-09 1.7  Gan      Performance tuning                               */
/* 2019-12-20 1.8  James    WMS-11213 Bug fix on var usage rdtmobrec(james01)*/
/* 2021-02-19 1.9  James    WMS-15661 Add custom retrieve info sp (james02)  */
/*****************************************************************************/      
CREATE PROC [RDT].[rdtfnc_CartonInquiry](      
   @nMobile    INT,      
   @nErrNo     INT  OUTPUT,      
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max      
) AS      
      
-- Misc variable      
DECLARE      
   @bSuccess           INT,
   @cSQL               NVARCHAR( MAX),
   @cSQLParam          NVARCHAR( MAX)
              
-- Define a variable      
DECLARE        
   @nFunc               INT,      
   @nScn                INT,      
   @nStep               INT,      
   @cLangCode           NVARCHAR(3),      
   @nMenu               INT,      
   @nInputKey           NVARCHAR(3),      
   @cPrinter            NVARCHAR(10),      
   @cUserName           NVARCHAR(18),      
      
   @cStorerKey          NVARCHAR(15),      
   @cFacility           NVARCHAR(5),      
      
   @cDropID             NVARCHAR(20),      
   @cWaveKey            NVARCHAR(10),      
   @cLoadKey            NVARCHAR(10),      
   @cStore              NVARCHAR(20),      
   @cCartonStatus       NVARCHAR(20),      
   @cLastLoc            NVARCHAR(10),      
   @cDropIDType         NVARCHAR(20),      
   @cCaseID             NVARCHAR(20),      
   @nTotalSKU           INT,      
   @nLastSKU            INT,      
   @cOrderGroup         NVARCHAR(20),      
   @cSectionKey         NVARCHAR(10),      
   @cPickDetailStatus   NVARCHAR(20),      
   @cConsigneeKey       NVARCHAR(15),
   @cShipToCountry      NVARCHAR(20),
   @cShipToCompany      NVARCHAR(20),
   @nFromScn            INT,
   @nFromStep           INT,
   @cExtendedInquirySP  NVARCHAR( 20), -- (james02)
   @cSKU                NVARCHAR( 20), -- (james02)
   @nQTY                INT,           -- (james02)
   @cUDF01              NVARCHAR( 20), -- (james02)
   @cUDF02              NVARCHAR( 20), -- (james02)
   @cUDF03              NVARCHAR( 20), -- (james02)
   @cUDF04              NVARCHAR( 20), -- (james02)
   @cUDF05              NVARCHAR( 20), -- (james02)
   @cType               NVARCHAR( 10), -- (james02)
   @cSKUDescr           NVARCHAR( 60), -- (james02)
   
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
  
DECLARE   
   @nPTSQty       INT,         @cTaskDetailKey NVARCHAR(10),  
   @nAllocatedQty INT,         @nShortPickQty  INT,   
   @cExtraStatus  NVARCHAR(20),@cPTSZone       NVARCHAR(20)     
                          
DECLARE @tCartonSKUDetail TABLE (      
   SeqNo            INT IDENTITY(1,1),      
   SKU              NVARCHAR(20),      
   SKUDescr         NVARCHAR(40),     
   Qty              INT,      
   PickDetailStatus NVARCHAR(20)      
)      
               
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
   @cUserName        = UserName,      
   @cSKU             = V_SKU,      
   @nQTY             = V_QTY,      
   -- (james01)
   @nFromScn         = V_FromScn,
   @nFromStep        = V_FromStep,
   @nTotalSKU        = V_Integer1,
   @nLastSKU         = V_Integer2,
   
   @cDropID          = V_String1,      
   @cWaveKey         = V_String2,      
   @cLoadKey         = V_String3,      
   @cStore           = V_String4,      
   @cCartonStatus    = V_String5,      
   @cLastLoc         = V_String6,      
   @cDropIDType      = V_String7,      
   @cOrderGroup      = V_String10,      
   @cSectionKey      = V_String11,      
   @cConsigneeKey    = V_String12,
   @cShipToCountry   = V_String13,
   @cShipToCompany   = V_String14,
   @cExtendedInquirySP = V_String15,
   @cUDF01           = V_String16,
   @cUDF01           = V_String17,
   @cUDF01           = V_String18,
   @cUDF01           = V_String19,
   @cUDF01           = V_String20,
   
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
IF @nFunc = 1807      
BEGIN      
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1807      
   IF @nStep = 1 GOTO Step_1   -- Scn = 3800  Scan Carton ID      
   IF @nStep = 2 GOTO Step_2   -- Scn = 3801  Show Details      
   IF @nStep = 3 GOTO Step_3   -- Scn = 3802  SKU Info      
   IF @nStep = 4 GOTO Step_4   -- Scn = 3803  Show Details 2 
END      
      
RETURN -- Do nothing if incorrect step      
      
/********************************************************************************      
Step 0. Called from menu (func = 1807)      
********************************************************************************/      
Step_0:      
BEGIN      
   -- Set the entry point      
   SET @nScn  = 3800      
   SET @nStep = 1      

   SET @cExtendedInquirySP = rdt.RDTGetConfig( @nFunc, 'ExtendedInquirySP', @cStorerKey)
   IF @cExtendedInquirySP IN ( '', '0')
        SET @cExtendedInquirySP = ''
  
      
   -- initialise all variable      
   SET @cDropID = ''      
   SET @cWaveKey = ''      
   SET @cLoadKey = ''      
   SET @cStore = ''      
   SET @cCartonStatus = ''      
   SET @cLastLoc = ''      
   SET @cDropIDType = ''      
   SET @nTotalSKU = 0      
   SET @nLastSKU = 0      
   SET @cOrderGroup = ''      
   SET @cSectionKey = ''      
   SET @cConsigneeKey = ''
   SET @cShipToCompany = ''
   SET @cShipToCountry = ''
   SET @nFromScn = 0
   SET @nFromStep = 0 
      
   -- Prep next screen var       
   SET @cOutField01 = ''       
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
END      
GOTO Quit      
      
/********************************************************************************      
Step 1. screen = 3800      
   CARTON INQUIRY      
      
   CARTON ID:       
   (Field01, input)      
********************************************************************************/      
Step_1:      
BEGIN      
   IF @nInputKey = 1 -- ENTER      
   BEGIN      
      -- Reset mapping      
      SET @cDropID = @cInField01      
      
      -- Check DropID      
      IF ISNULL(@cDropID, '') = ''      
      BEGIN      
         SET @nErrNo = 86201      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NEED CARTONID        
         GOTO Step_1_Fail        
      END      

      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInquirySP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInquirySP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cType, @cDropID, ' + 
            ' @cWaveKey    OUTPUT, @cLoadKey    OUTPUT, @cStore         OUTPUT, @cCartonStatus  OUTPUT, @cLastLoc       OUTPUT, ' + 
            ' @cOrderGroup OUTPUT, @cSectionKey OUTPUT, @cShipToCountry OUTPUT, @cShipToCompany OUTPUT, @cConsigneeKey  OUTPUT, ' + 
            ' @cSKU        OUTPUT, @nQTY        OUTPUT, @cUDF01         OUTPUT, @cUDF02         OUTPUT, @cUDF03         OUTPUT, ' + 
            ' @cUDF04      OUTPUT, @cUDF05      OUTPUT, @cDropIDType    OUTPUT, @nLastSKU       OUTPUT, ' + 
            ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT '
         SET @cSQLParam =
            '@nMobile         INT, ' +
            '@nFunc           INT, ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT, ' +
            '@nInputKey       INT, ' +
            '@cUserName       NVARCHAR( 18), ' +
            '@cFacility       NVARCHAR( 5),  ' +
            '@cStorerKey      NVARCHAR( 15), ' +
            '@cType           NVARCHAR( 10), ' +
            '@cDropID         NVARCHAR( 20), ' +
            '@cWaveKey        NVARCHAR( 10) OUTPUT, ' +
            '@cLoadKey        NVARCHAR( 10) OUTPUT, ' +
            '@cStore          NVARCHAR( 20) OUTPUT, ' +
            '@cCartonStatus   NVARCHAR( 20) OUTPUT, ' +
            '@cLastLoc        NVARCHAR( 10) OUTPUT, ' +
            '@cOrderGroup     NVARCHAR( 20) OUTPUT, ' +
            '@cSectionKey     NVARCHAR( 10) OUTPUT, ' +
            '@cShipToCountry  NVARCHAR( 20) OUTPUT, ' +
            '@cShipToCompany  NVARCHAR( 20) OUTPUT, ' +
            '@cConsigneeKey   NVARCHAR( 15) OUTPUT, ' +
            '@cSKU            NVARCHAR( 20) OUTPUT, ' +
            '@nQTY            INT           OUTPUT, ' +
            '@cUDF01          NVARCHAR( 20) OUTPUT, ' +
            '@cUDF02          NVARCHAR( 20) OUTPUT, ' +
            '@cUDF03          NVARCHAR( 20) OUTPUT, ' +
            '@cUDF04          NVARCHAR( 20) OUTPUT, ' +
            '@cUDF05          NVARCHAR( 20) OUTPUT, ' +
            '@cDropIDType     NVARCHAR( 20) OUTPUT, ' +
            '@nLastSKU        INT           OUTPUT, ' +
            '@nErrNo          INT           OUTPUT, ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cType, @cDropID, 
            @cWaveKey    OUTPUT, @cLoadKey    OUTPUT, @cStore         OUTPUT, @cCartonStatus  OUTPUT, @cLastLoc       OUTPUT, 
            @cOrderGroup OUTPUT, @cSectionKey OUTPUT, @cShipToCountry OUTPUT, @cShipToCompany OUTPUT, @cConsigneeKey  OUTPUT,  
            @cSKU        OUTPUT, @nQTY        OUTPUT, @cUDF01         OUTPUT, @cUDF02         OUTPUT, @cUDF03         OUTPUT,  
            @cUDF04      OUTPUT, @cUDF05      OUTPUT, @cDropIDType    OUTPUT, @nLastSKU       OUTPUT, 
            @nErrNo      OUTPUT, @cErrMsg     OUTPUT 

         IF @nErrNo <> 0
            GOTO Step_1_Fail
            
         -- Prep next screen var       
         SET @cOutField01 = @cWaveKey      
         SET @cOutField02 = @cLoadKey      
         SET @cOutField03 = @cStore      
         SET @cOutField04 = @cCartonStatus      
         SET @cOutField05 = @cLastLoc      
         SET @cOutField06 = @cOrderGroup      
         SET @cOutField07 = @cSectionKey      
         
         SET @nScn = @nScn + 1      
         SET @nStep = @nStep + 1      

         GOTO Quit
      END
            
      SELECT TOP 1      
         @cDropIDType = DropIDType,      
         @cLastLoc = DropLoc,       
         @cCartonStatus = Status,       
         @cLoadKey = ISNULL(LoadKey, '')      
      FROM dbo.DropID WITH (NOLOCK)         
      WHERE DropID = @cDropID        
      ORDER BY AddDate DESC      
      
      SELECT @cCartonStatus = [Description]      
      FROM dbo.Codelkup WITH (NOLOCK)      
      WHERE LISTNAME = 'DROPSTATUS'      
        AND Code = @cCartonStatus      
      
      -- Make sure dropid from Sort & Pack       
      IF @cDropIDType = '0' AND (@cLastLoc <> '' OR @cLoadKey = '')      
         SET @cDropIDType = ''      
      
      IF EXISTS(SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cDropID AND StorerKey = @cStorerKey)      
      BEGIN      
         SELECT      
            @cDropIDType = 'UCC',      
            @cCartonStatus = Status      
         FROM dbo.UCC WITH (NOLOCK)       
         WHERE UCCNo = @cDropID       
           AND StorerKey = @cStorerKey      
      
         SELECT @cCartonStatus = [Description]      
         FROM dbo.Codelkup WITH (NOLOCK)      
         WHERE LISTNAME = 'UCCStatus'      
           AND Code = @cCartonStatus      
      END      
      
      -- Check DropID valid        
      IF ISNULL(@cDropIDType, '') = ''       
      BEGIN        
         SET @nErrNo = 86202        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV CARTONID        
         GOTO Step_1_Fail        
      END        
      
      IF @cDropIDType NOT IN ('CART', 'PTS', '0', 'UCC', 'PP', 'STOTE', 'SINGLES', 'MULTIS', '1','2','FCP') -- (ChewKP03) -- (ChewKP04) -- (ChewKP05)
      BEGIN      
         SET @nErrNo = 86203        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV CARTONID        
         GOTO Step_1_Fail        
      END      
      
      IF @cDropIDType IN ('CART', 'UCC', 'PP', 'STOTE', 'SINGLES', 'MULTIS', '1','2','FCP') -- (ChewKP03) -- (ChewKP04)      
      BEGIN      

           SELECT TOP 1  
               @cWaveKey = PD.WaveKey,      
               @cStore = CASE WHEN @cDropIDType NOT IN ('SINGLES', 'MULTIS' ) THEN OD.UserDefine02 ELSE '' END,      -- (ChewKP04)
               @cOrderGroup = CASE WHEN @cDropIDType NOT IN ('SINGLES', 'MULTIS' ) THEN O.OrderGroup ELSE '' END,    -- (ChewKP04)  
               @cSectionKey = CASE WHEN @cDropIDType NOT IN ('SINGLES', 'MULTIS' ) THEN O.SectionKey ELSE '' END,    -- (ChewKP04)  
               @cLoadKey = LPD.Loadkey,      
               @cShipToCountry = O.C_Country,
               @cShipToCompany = O.C_Company,
               @cConsigneeKey       = O.Consigneekey
            FROM PickDetail PD WITH (NOLOCK)      
            JOIN OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber      
            JOIN ORDERS O WITH (NOLOCK) ON OD.OrderKey = O.OrderKey      
            JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey      
            WHERE PD.StorerKey = @cStorerKey      
              AND PD.DropID = @cDropID      
              AND LPD.LoadKey = CASE WHEN @cDropIDType = 'UCC' THEN LPD.Loadkey ELSE @cLoadKey END      
            ORDER BY PD.EditDate DESC -- (ChewKP02) 
            
            
      END      
      ELSE IF @cDropIDType IN ('PTS', '0')      
      BEGIN       
         SELECT @cCaseID = LabelNo      
         FROM PackDetail WITH (NOLOCK)      
         WHERE StorerKey = @cStorerKey      
           AND @cDropID IN (DropID, RefNo)       
      
         SELECT       
            @cWaveKey = PD.WaveKey,      
            @cStore = OD.UserDefine02,      
            @cOrderGroup = O.OrderGroup,      
            @cSectionKey = O.SectionKey      
         FROM PickDetail PD WITH (NOLOCK)      
         JOIN OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber      
         JOIN ORDERS O WITH (NOLOCK) ON OD.OrderKey = O.OrderKey      
         JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey      
         WHERE PD.StorerKey = @cStorerKey      
           AND PD.CaseID = @cCaseID      
           AND LPD.LoadKey = @cLoadKey      
      END      
      
      IF @cDropIDType <> '1' 
      BEGIN 
         -- Prep next screen var       
         SET @cOutField01 = @cWaveKey      
         SET @cOutField02 = @cLoadKey      
         SET @cOutField03 = @cStore      
         SET @cOutField04 = @cCartonStatus      
         SET @cOutField05 = @cLastLoc      
         SET @cOutField06 = @cOrderGroup      
         SET @cOutField07 = @cSectionKey      
         
         SET @nScn = @nScn + 1      
         SET @nStep = @nStep + 1      
      END
      ELSE
      BEGIN
         -- Prep next screen var       
         SET @cOutField01 = @cWaveKey      
         SET @cOutField02 = @cLoadKey      
         SET @cOutField03 = @cStore      
         SET @cOutField04 = @cCartonStatus      
         SET @cOutField05 = @cShipToCountry      
         SET @cOutField06 = @cShipToCompany      
         SET @cOutField07 = @cConsigneeKey      
         
         SET @nScn = @nScn + 3    
         SET @nStep = @nStep + 3   
      END
   END      
      
   IF @nInputKey = 0 -- ESC      
   BEGIN      
      -- Back to menu      
      SET @nFunc = @nMenu      
      SET @nScn  = @nMenu      
      SET @nStep = 0       
      
      SET @cDropID = ''      
      SET @cWaveKey = ''      
      SET @cLoadKey = ''      
      SET @cStore = ''      
      SET @cCartonStatus = ''      
      SET @cLastLoc = ''      
      SET @cDropIDType = ''      
      SET @nTotalSKU = 0      
      SET @nLastSKU = 0      
      SET @cOrderGroup = ''      
      SET @cSectionKey = ''      
   END      
   GOTO Quit      
      
   Step_1_Fail:      
   BEGIN      
      SET @cDropID = ''      
      SET @cWaveKey = ''      
      SET @cLoadKey = ''      
      SET @cStore = ''      
      SET @cCartonStatus = ''      
      SET @cLastLoc = ''      
      SET @cDropIDType = ''      
      SET @nTotalSKU = 0      
      SET @nLastSKU = 0      
      SET @cOrderGroup = ''      
      SET @cSectionKey = ''      
      
      SET @cOutField01 = ''       
   END      
      
END      
GOTO Quit      
      
/********************************************************************************      
Step 2. screen = 3801      
   CARTON INQUIRY      
      
   WAVEKEY: (Field01, display)      
   LOADKEY: (Field02, display)        
   STORE:       
   (Field03, display)       
   CARTON STATUS:      
   (Field04, display)       
   LAST LOC: (Field05, display)      
********************************************************************************/      
Step_2:      
BEGIN      
   IF @nInputKey = 1 -- ENTER      
   BEGIN      
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInquirySP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInquirySP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cType, @cDropID, ' + 
            ' @cWaveKey    OUTPUT, @cLoadKey    OUTPUT, @cStore         OUTPUT, @cCartonStatus  OUTPUT, @cLastLoc       OUTPUT, ' + 
            ' @cOrderGroup OUTPUT, @cSectionKey OUTPUT, @cShipToCountry OUTPUT, @cShipToCompany OUTPUT, @cConsigneeKey  OUTPUT, ' + 
            ' @cSKU        OUTPUT, @nQTY        OUTPUT, @cUDF01         OUTPUT, @cUDF02         OUTPUT, @cUDF03         OUTPUT, ' + 
            ' @cUDF04      OUTPUT, @cUDF05      OUTPUT, @cDropIDType    OUTPUT, @nLastSKU       OUTPUT, ' + 
            ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT '
         SET @cSQLParam =
            '@nMobile         INT, ' +
            '@nFunc           INT, ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT, ' +
            '@nInputKey       INT, ' +
            '@cUserName       NVARCHAR( 18), ' +
            '@cFacility       NVARCHAR( 5),  ' +
            '@cStorerKey      NVARCHAR( 15), ' +
            '@cType           NVARCHAR( 10), ' +
            '@cDropID         NVARCHAR( 20), ' +
            '@cWaveKey        NVARCHAR( 10) OUTPUT, ' +
            '@cLoadKey        NVARCHAR( 10) OUTPUT, ' +
            '@cStore          NVARCHAR( 20) OUTPUT, ' +
            '@cCartonStatus   NVARCHAR( 20) OUTPUT, ' +
            '@cLastLoc        NVARCHAR( 10) OUTPUT, ' +
            '@cOrderGroup     NVARCHAR( 20) OUTPUT, ' +
            '@cSectionKey     NVARCHAR( 10) OUTPUT, ' +
            '@cShipToCountry  NVARCHAR( 20) OUTPUT, ' +
            '@cShipToCompany  NVARCHAR( 20) OUTPUT, ' +
            '@cConsigneeKey   NVARCHAR( 15) OUTPUT, ' +
            '@cSKU            NVARCHAR( 20) OUTPUT, ' +
            '@nQTY            INT           OUTPUT, ' +
            '@cUDF01          NVARCHAR( 20) OUTPUT, ' +
            '@cUDF02          NVARCHAR( 20) OUTPUT, ' +
            '@cUDF03          NVARCHAR( 20) OUTPUT, ' +
            '@cUDF04          NVARCHAR( 20) OUTPUT, ' +
            '@cUDF05          NVARCHAR( 20) OUTPUT, ' +
            '@cDropIDType     NVARCHAR( 20) OUTPUT, ' +
            '@nLastSKU        INT           OUTPUT, ' +
            '@nErrNo          INT           OUTPUT, ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cType, @cDropID, 
            @cWaveKey    OUTPUT, @cLoadKey    OUTPUT, @cStore         OUTPUT, @cCartonStatus  OUTPUT, @cLastLoc       OUTPUT, 
            @cOrderGroup OUTPUT, @cSectionKey OUTPUT, @cShipToCountry OUTPUT, @cShipToCompany OUTPUT, @cConsigneeKey  OUTPUT,  
            @cSKU        OUTPUT, @nQTY        OUTPUT, @cUDF01         OUTPUT, @cUDF02         OUTPUT, @cUDF03         OUTPUT,  
            @cUDF04      OUTPUT, @cUDF05      OUTPUT, @cDropIDType    OUTPUT, @nLastSKU       OUTPUT, 
            @nErrNo      OUTPUT, @cErrMsg     OUTPUT 

         IF @nErrNo <> 0
            GOTO Step_2_Fail

         SELECT @cSKUDescr = DESCR
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   Sku = @cSKU
         
         -- Prep next screen var       
         SET @cOutField01 = @cSKU      
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)      
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)      
         SET @cOutField04 = @nQTY      
         SET @cOutField05 = @cCartonStatus      
         SET @cOutField06 = @cOrderGroup
         
         SET @nScn = @nScn + 1      
         SET @nStep = @nStep + 1      

         GOTO Quit
      END
          
      IF @cDropIDType IN ('CART', 'UCC' , 'PP', 'STOTE', 'SINGLES', 'MULTIS', '1','2','FCP') -- (ChewKP03) -- (ChewKP04) -- (ChewKP05)     
      BEGIN      
         INSERT INTO @tCartonSKUDetail       
         SELECT      
            SKU.SKU, SUBSTRING(SKU.DESCR, 1, 40), PD.Qty,       
            CASE WHEN ISNULL(C.Description, '') <> '' THEN SUBSTRING(C.Description, 1, 20)  ELSE PD.Status END  -- (ChewKP01)     
         FROM PickDetail PD WITH (NOLOCK)      
         JOIN SKU WITH (NOLOCK) ON (SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey)      
         JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey      
         LEFT OUTER JOIN CODELKUP C WITH (NOLOCK) ON (C.Listname = 'ORDRSTATUS' AND C.Code = PD.Status)      
         WHERE PD.StorerKey = @cStorerKey      
           AND PD.DropID = @cDropID      
           AND LPD.LoadKey = @cLoadKey      
         ORDER BY PD.OrderLineNumber      
  
      END      
      ELSE IF @cDropIDType IN ('PTS', '0')      
      BEGIN       
         INSERT INTO @tCartonSKUDetail       
         SELECT SKU, Descr, Qty, CASE WHEN ISNULL(C.Description, '') <> '' THEN SUBSTRING(C.Description, 1, 20) ELSE T.Status END -- (ChewKP01)    
         FROM (      
            SELECT PD.LabelLine, SKU.SKU, SUBSTRING(SKU.DESCR, 1, 40) AS 'Descr', PD.Qty, PiD.Status      
            FROM PackDetail PD WITH (NOLOCK)      
            JOIN PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)      
            JOIN SKU WITH (NOLOCK) ON (SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey)      
            JOIN PickDetail PiD WITH (NOLOCK) ON (PD.PickSlipNo = PiD.PickSlipNo AND PD.SKU = PiD.SKU       
                                                  AND PD.StorerKey = PiD.StorerKey AND PD.LabelNo = PiD.CaseID)      
            WHERE PD.StorerKey = @cStorerKey      
              AND @cDropID IN (PD.DropID, PD.RefNo)       
              AND PH.LoadKey = @cLoadKey      
            GROUP BY PD.LabelLine, SKU.SKU, SUBSTRING(SKU.DESCR, 1, 40), PD.Qty, PiD.Status      
         ) AS T      
         LEFT OUTER JOIN CODELKUP C WITH (NOLOCK) ON (C.Listname = 'ORDRSTATUS' AND C.Code = T.Status)      
         ORDER BY LabelLine      
      END      
      
      SELECT @nTotalSKU = COUNT(1)      
      FROM @tCartonSKUDetail      
      
      IF @nTotalSKU > 0      
      BEGIN      
         -- Prep next screen var       
         SELECT TOP 1      
            @cOutField01 = SKU,      
            @cOutField02 = SUBSTRING(SKUDescr, 1, 20),      
            @cOutField03 = SUBSTRING(SKUDescr, 21, 20),      
            @cOutField04 = CAST(Qty AS NCHAR(10)) + CAST(SeqNo AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR),      
            @nLastSKU = SeqNo,      
            @cOutField05 = PickDetailStatus  
         FROM @tCartonSKUDetail       
         WHERE SeqNo > @nLastSKU      
         ORDER BY SeqNo      
  
         SET @cCartonStatus = ''  
         IF @cDropIDType IN ('CART', 'UCC', 'PP', 'STOTE', 'SINGLES', 'MULTIS', '1','2','FCP') -- (ChewKP03) -- (ChewKP04) -- (ChewKP05)  
         BEGIN  
            SET @nPTSQty = 0  
            SET @cTaskDetailKey =  ''  
              
            SELECT @nPTSQty = SUM(CASE WHEN PD.CaseID <> '' THEN QTY ELSE 0 END),   
                   @cTaskDetailKey = MAX(PD.TaskDetailKey),   
                   @nShortPickQty = SUM(CASE WHEN PD.[Status]='4' THEN QTY ELSE 0 END),   
                   @nAllocatedQty = SUM(Qty)      
            FROM PickDetail PD WITH (NOLOCK)      
            JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey      
            WHERE PD.StorerKey = @cStorerKey      
              AND PD.DropID = @cDropID      
              AND PD.Sku = @cOutField01   
              AND LPD.LoadKey = @cLoadKey      
   
            SET @cPTSZone = ''  
            SELECT TOP 1 @cPTSZone = Loc.PutawayZone   
            FROM dbo.StoreToLocDetail STL WITH (NOLOCK)   
            INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.UserDefine02 = STL.ConsigneeKey  
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey  
            INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = O.OrderKey  
            INNER JOIN dbo.Loc LOC WITH (NOLOCK) ON LOC.Loc = STL.Loc  
            WHERE PD.DropID = @cDropID  
            --AND   PD.PickSlipNo = @cPickSlipNo  
            AND   O.LoadKey = @cLoadKey  
            AND   PD.Status = '3'  
            AND   PD.CaseID = ''  
            AND   STL.StoreGroup = CASE WHEN O.Type = 'N' THEN RTRIM(O.OrderGroup) + RTRIM(O.SectionKey) ELSE 'OTHERS' END  
             
            IF @nShortPickQty > 0  
            BEGIN  
               SET @cExtraStatus = '<Short Picked>'                   
            END    
            ELSE IF ISNULL(RTRIM(@cTaskDetailKey),'') <> '' AND @nPTSQty=0  
            BEGIN  
               IF EXISTS(SELECT 1 FROM TaskDetail WITH (NOLOCK)  
                         WHERE TaskDetailKey = @cTaskDetailKey  
                         AND  [Status]='5')  
               BEGIN  
                  SET @cExtraStatus = '<Replen In Progress>'                   
               END  
               ELSE  
                  SET @cExtraStatus = '<PTS In Progress>'  
            END  
            ELSE IF ( @nPTSQty <> @nAllocatedQty AND @nPTSQty > 0 )  OR @nPTSQty = 0  
            BEGIN  
               SET @cExtraStatus = '<PTS In Progress>'                                             
            END  
            ELSE IF @nPTSQty = @nAllocatedQty AND @nPTSQty > 0   
            BEGIN  
               SET @cExtraStatus = '<To Putaway>'  
            END  
         END    
         /*
         IF ISNULL(RTRIM(@cExtraStatus),'') <> ''   
            SET @cOutField06 =  @cExtraStatus  
         ELSE   
            SET @cOutField06 = ''  
              
         --@cPTSZone  
         IF ISNULL(RTRIM(@cPTSZone),'') <> ''   
            SET @cOutField07 =  'PTS ZONE: ' + RTRIM(@cPTSZone)  
         ELSE   
            SET @cOutField07 = ''  
         */            
         SET @nScn = @nScn + 1      
         SET @nStep = @nStep + 1      
      END      
      ELSE      
      BEGIN      
         -- Prep next screen var       
         SET @cOutField01 = @cWaveKey      
         SET @cOutField02 = @cLoadKey      
         SET @cOutField03 = @cStore      
         SET @cOutField04 = @cCartonStatus      
         SET @cOutField05 = @cLastLoc     
         SET @cOutField06 = @cOrderGroup      
         SET @cOutField07 = @cSectionKey                
      
         SET @nScn = @nScn      
         SET @nStep = @nStep      
      END      
   END      
      
   IF @nInputKey = 0 -- ESC      
   BEGIN      
      SET @nScn = @nScn - 1      
      SET @nStep = @nStep - 1      
      
      SET @cDropID = ''      
      SET @cWaveKey = ''      
      SET @cLoadKey = ''      
      SET @cStore = ''      
      SET @cCartonStatus = ''      
      SET @cLastLoc = ''      
      SET @cDropIDType = ''      
      SET @nTotalSKU = 0      
      SET @nLastSKU = 0      
      SET @cOrderGroup = ''      
      SET @cSectionKey = ''      
      
      SET @cOutField01 = ''       
      SET @cOutField06 = ''      
      SET @cOutField07 = ''      
              
   END      
   GOTO Quit      
      
   Step_2_Fail:      
   GOTO Quit        
END      
GOTO Quit      
      
/********************************************************************************      
Step 3. screen = 3802      
   SKU:      
   (Field01, display)      
   (Field02, display)      
   (Field03, display)      
   QTY: (Field04, display)      
********************************************************************************/      
Step_3:      
BEGIN      
   IF @nInputKey = 1  -- ENTER      
   BEGIN      
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInquirySP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInquirySP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cType, @cDropID, ' + 
            ' @cWaveKey    OUTPUT, @cLoadKey    OUTPUT, @cStore         OUTPUT, @cCartonStatus  OUTPUT, @cLastLoc       OUTPUT, ' + 
            ' @cOrderGroup OUTPUT, @cSectionKey OUTPUT, @cShipToCountry OUTPUT, @cShipToCompany OUTPUT, @cConsigneeKey  OUTPUT, ' + 
            ' @cSKU        OUTPUT, @nQTY        OUTPUT, @cUDF01         OUTPUT, @cUDF02         OUTPUT, @cUDF03         OUTPUT, ' + 
            ' @cUDF04      OUTPUT, @cUDF05      OUTPUT, @cDropIDType    OUTPUT, @nLastSKU       OUTPUT, ' + 
            ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT '
         SET @cSQLParam =
            '@nMobile         INT, ' +
            '@nFunc           INT, ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT, ' +
            '@nInputKey       INT, ' +
            '@cUserName       NVARCHAR( 18), ' +
            '@cFacility       NVARCHAR( 5),  ' +
            '@cStorerKey      NVARCHAR( 15), ' +
            '@cType           NVARCHAR( 10), ' +
            '@cDropID         NVARCHAR( 20), ' +
            '@cWaveKey        NVARCHAR( 10) OUTPUT, ' +
            '@cLoadKey        NVARCHAR( 10) OUTPUT, ' +
            '@cStore          NVARCHAR( 20) OUTPUT, ' +
            '@cCartonStatus   NVARCHAR( 20) OUTPUT, ' +
            '@cLastLoc        NVARCHAR( 10) OUTPUT, ' +
            '@cOrderGroup     NVARCHAR( 20) OUTPUT, ' +
            '@cSectionKey     NVARCHAR( 10) OUTPUT, ' +
            '@cShipToCountry  NVARCHAR( 20) OUTPUT, ' +
            '@cShipToCompany  NVARCHAR( 20) OUTPUT, ' +
            '@cConsigneeKey   NVARCHAR( 15) OUTPUT, ' +
            '@cSKU            NVARCHAR( 20) OUTPUT, ' +
            '@nQTY            INT           OUTPUT, ' +
            '@cUDF01          NVARCHAR( 20) OUTPUT, ' +
            '@cUDF02          NVARCHAR( 20) OUTPUT, ' +
            '@cUDF03          NVARCHAR( 20) OUTPUT, ' +
            '@cUDF04          NVARCHAR( 20) OUTPUT, ' +
            '@cUDF05          NVARCHAR( 20) OUTPUT, ' +
            '@cDropIDType     NVARCHAR( 20) OUTPUT, ' +
            '@nLastSKU        INT           OUTPUT, ' +
            '@nErrNo          INT           OUTPUT, ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cType, @cDropID, 
            @cWaveKey    OUTPUT, @cLoadKey    OUTPUT, @cStore         OUTPUT, @cCartonStatus  OUTPUT, @cLastLoc       OUTPUT, 
            @cOrderGroup OUTPUT, @cSectionKey OUTPUT, @cShipToCountry OUTPUT, @cShipToCompany OUTPUT, @cConsigneeKey  OUTPUT,  
            @cSKU        OUTPUT, @nQTY        OUTPUT, @cUDF01         OUTPUT, @cUDF02         OUTPUT, @cUDF03         OUTPUT,  
            @cUDF04      OUTPUT, @cUDF05      OUTPUT, @cDropIDType    OUTPUT, @nLastSKU       OUTPUT, 
            @nErrNo      OUTPUT, @cErrMsg     OUTPUT 

         IF @nErrNo <> 0
            GOTO Step_2_Fail

         SELECT @cSKUDescr = DESCR
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   Sku = @cSKU
         
         -- Prep next screen var       
         SET @cOutField01 = @cSKU      
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)      
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)      
         SET @cOutField04 = @nQTY      
         SET @cOutField05 = @cCartonStatus      
         SET @cOutField06 = @cOrderGroup
         
         GOTO Quit
      END
      
      IF @nLastSKU <> @nTotalSKU      
      BEGIN      
         IF @cDropIDType IN ('CART', 'UCC','PP', 'STOTE', 'SINGLES', 'MULTIS', '1','2','FCP') -- (ChewKP03) -- (ChewKP04)      
         BEGIN      
            INSERT INTO @tCartonSKUDetail       
            SELECT       
               SKU.SKU, SUBSTRING(SKU.DESCR, 1, 40), PD.Qty,       
               CASE WHEN ISNULL(C.Description, '') <> '' THEN SUBSTRING(C.Description, 1, 20) ELSE PD.Status END  -- (ChewKP01)    
            FROM PickDetail PD WITH (NOLOCK)      
            JOIN SKU WITH (NOLOCK) ON (SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey)      
            JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey      
            LEFT OUTER JOIN CODELKUP C WITH (NOLOCK) ON (C.Listname = 'ORDRSTATUS' AND C.Code = PD.Status)      
            WHERE PD.StorerKey = @cStorerKey      
              AND PD.DropID = @cDropID      
              AND LPD.LoadKey = @cLoadKey      
            ORDER BY PD.OrderLineNumber      
         END      
         ELSE IF @cDropIDType IN ('PTS', '0')      
         BEGIN       
            INSERT INTO @tCartonSKUDetail       
            SELECT SKU, Descr, Qty, CASE WHEN ISNULL(C.Description, '') <> '' THEN SUBSTRING(C.Description, 1, 20) ELSE T.Status END -- (ChewKP01)    
            FROM (      
               SELECT PD.LabelLine, SKU.SKU, SUBSTRING(SKU.DESCR, 1, 40) AS 'Descr', PD.Qty, PiD.Status      
               FROM PackDetail PD WITH (NOLOCK)      
               JOIN PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)      
               JOIN SKU WITH (NOLOCK) ON (SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey)      
               JOIN PickDetail PiD WITH (NOLOCK) ON (PD.PickSlipNo = PiD.PickSlipNo AND PD.SKU = PiD.SKU       
                                                     AND PD.StorerKey = PiD.StorerKey AND PD.LabelNo = PiD.CaseID)      
               WHERE PD.StorerKey = @cStorerKey      
                 AND @cDropID IN (PD.DropID, PD.RefNo)       
                 AND PH.LoadKey = @cLoadKey      
               GROUP BY PD.LabelLine, SKU.SKU, SUBSTRING(SKU.DESCR, 1, 40), PD.Qty, PiD.Status      
            ) AS T      
            LEFT OUTER JOIN CODELKUP C WITH (NOLOCK) ON (C.Listname = 'ORDRSTATUS' AND C.Code = T.Status)      
            ORDER BY LabelLine      
         END      
      
         -- Prep next screen var       
         SELECT TOP 1      
            @cOutField01 = SKU,      
            @cOutField02 = SUBSTRING(SKUDescr, 1, 20),      
            @cOutField03 = SUBSTRING(SKUDescr, 21, 20),      
            @cOutField04 = CAST(Qty AS NCHAR(10)) + CAST(SeqNo AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR),      
            @nLastSKU = SeqNo,      
            @cOutField05 = PickDetailStatus   
         FROM @tCartonSKUDetail       
         WHERE SeqNo > @nLastSKU      
         ORDER BY SeqNo      
  
         SET @cCartonStatus = ''  
         IF @cDropIDType IN ('CART', 'UCC', 'PP', 'STOTE', 'SINGLES', 'MULTIS', '1','2','FCP') -- (ChewKP03) -- (ChewKP04)        
         BEGIN  
            SET @nPTSQty = 0  
            SET @cTaskDetailKey =  ''  
              
            SELECT @nPTSQty = SUM(CASE WHEN PD.CaseID <> '' THEN QTY ELSE 0 END),   
                   @cTaskDetailKey = MAX(PD.TaskDetailKey),   
                   @nShortPickQty = SUM(CASE WHEN PD.[Status]='4' THEN QTY ELSE 0 END),   
                   @nAllocatedQty = SUM(Qty)       
            FROM PickDetail PD WITH (NOLOCK)      
            JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey      
            WHERE PD.StorerKey = @cStorerKey      
              AND PD.DropID = @cDropID      
              AND PD.Sku = @cOutField01   
              AND LPD.LoadKey = @cLoadKey      
   
            SET @cPTSZone = ''  
            SELECT TOP 1 @cPTSZone = Loc.PutawayZone   
            FROM dbo.StoreToLocDetail STL WITH (NOLOCK)   
            INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.UserDefine02 = STL.ConsigneeKey  
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey  
            INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = O.OrderKey  
            INNER JOIN dbo.Loc LOC WITH (NOLOCK) ON LOC.Loc = STL.Loc  
            WHERE PD.DropID = @cDropID  
            --AND   PD.PickSlipNo = @cPickSlipNo  
            AND   O.LoadKey = @cLoadKey  
            AND   PD.Status = '3'  
            AND   PD.CaseID = ''  
            AND   STL.StoreGroup = CASE WHEN O.Type = 'N' THEN RTRIM(O.OrderGroup) + RTRIM(O.SectionKey) ELSE 'OTHERS' END  
             
            IF @nShortPickQty > 0  
            BEGIN  
               SET @cExtraStatus = '<Short Picked>'                   
            END    
            ELSE IF ISNULL(RTRIM(@cTaskDetailKey),'') <> '' AND @nPTSQty=0  
            BEGIN  
               IF EXISTS(SELECT 1 FROM TaskDetail WITH (NOLOCK)  
                         WHERE TaskDetailKey = @cTaskDetailKey  
                         AND  [Status]='5')  
               BEGIN  
                  SET @cExtraStatus = '<Replen In Progress>'                   
               END  
               ELSE  
                  SET @cExtraStatus = '<PTS In Progress>'  
            END  
            ELSE IF ( @nPTSQty <> @nAllocatedQty AND @nPTSQty > 0 ) OR @nPTSQty = 0  
            BEGIN  
               SET @cExtraStatus = '<PTS In Progress>'                                             
            END  
            ELSE IF @nPTSQty = @nAllocatedQty AND @nPTSQty > 0   
            BEGIN  
               SET @cExtraStatus = '<To Putaway>'  
            END  
         END    
         IF ISNULL(RTRIM(@cExtraStatus),'') <> ''   
            SET @cOutField06 =  @cExtraStatus  
         ELSE   
            SET @cOutField06 = ''     
         --@cPTSZone  
         IF ISNULL(RTRIM(@cPTSZone),'') <> ''   
            SET @cOutField07 =  'PTS ZONE: ' + @cPTSZone  
         ELSE  
            SET @cOutField07 = ''  
                          
      END -- IF @nLastSKU <> @nTotalSKU      
   END      
      
   IF @nInputKey = 0 -- ESC      
   BEGIN      
      IF @nLastSKU = 1      
      BEGIN      
         SET @nLastSKU = 0      
      
         -- Prep next screen var     
         
         IF ISNULL(@cDropIDType,'')  <> '1'   
         BEGIN
            SET @cOutField01 = @cWaveKey      
            SET @cOutField02 = @cLoadKey      
            SET @cOutField03 = @cStore      
            SET @cOutField04 = @cCartonStatus      
            SET @cOutField05 = @cLastLoc    
            SET @cOutField06 = @cOrderGroup      
            SET @cOutField07 = @cSectionKey        
            
            SET @nScn = @nScn - 1      
            SET @nStep = @nStep - 1      
         END
         ELSE
         BEGIN
            SET @cOutField01 = @cWaveKey      
            SET @cOutField02 = @cLoadKey      
            SET @cOutField03 = @cStore      
            SET @cOutField04 = @cCartonStatus      
            SET @cOutField05 = @cShipToCountry      
            SET @cOutField06 = @cShipToCompany      
            SET @cOutField07 = @cConsigneeKey   
             
            SET @nScn = @nScn + 1      
            SET @nStep = @nStep + 1   
         END
      END      
      ELSE      
      BEGIN      
         IF @cDropIDType IN ('CART', 'UCC', 'PP', 'STOTE', 'SINGLES', 'MULTIS' ,'1','2','FCP') -- (ChewKP03) -- (ChewKP04) -- (ChewKP05)      
         BEGIN      
            INSERT INTO @tCartonSKUDetail       
            SELECT       
               SKU.SKU, SUBSTRING(SKU.DESCR, 1, 40), PD.Qty,       
               CASE WHEN ISNULL(C.Description, '') <> '' THEN SUBSTRING(C.Description, 1, 20) ELSE PD.Status END  -- (ChewKP01)    
            FROM PickDetail PD WITH (NOLOCK)      
            JOIN SKU WITH (NOLOCK) ON (SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey)      
            JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey      
            LEFT OUTER JOIN CODELKUP C WITH (NOLOCK) ON (C.Listname = 'ORDRSTATUS' AND C.Code = PD.Status)      
            WHERE PD.StorerKey = @cStorerKey      
              AND PD.DropID = @cDropID      
              AND LPD.LoadKey = @cLoadKey      
            ORDER BY PD.OrderLineNumber      
                    
         END      
         ELSE IF @cDropIDType IN ('PTS', '0')      
         BEGIN       
            INSERT INTO @tCartonSKUDetail       
            SELECT SKU, Descr, Qty, CASE WHEN ISNULL(C.Description, '') <> '' THEN SUBSTRING(C.Description, 1, 20) ELSE T.Status END -- (ChewKP01)    
            FROM (      
               SELECT PD.LabelLine, SKU.SKU, SUBSTRING(SKU.DESCR, 1, 40) AS 'Descr', PD.Qty, PiD.Status      
               FROM PackDetail PD WITH (NOLOCK)      
               JOIN PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)      
               JOIN SKU WITH (NOLOCK) ON (SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey)      
               JOIN PickDetail PiD WITH (NOLOCK) ON (PD.PickSlipNo = PiD.PickSlipNo AND PD.SKU = PiD.SKU       
                                                     AND PD.StorerKey = PiD.StorerKey AND PD.LabelNo = PiD.CaseID)      
               WHERE PD.StorerKey = @cStorerKey      
                 AND @cDropID IN (PD.DropID, PD.RefNo)       
                 AND PH.LoadKey = @cLoadKey      
               GROUP BY PD.LabelLine, SKU.SKU, SUBSTRING(SKU.DESCR, 1, 40), PD.Qty, PiD.Status      
            ) AS T      
            LEFT OUTER JOIN CODELKUP C WITH (NOLOCK) ON (C.Listname = 'ORDRSTATUS' AND C.Code = T.Status)      
            ORDER BY LabelLine      
         END      
      
         -- Prep next screen var       
         SELECT TOP 1      
            @cOutField01 = SKU,      
            @cOutField02 = SUBSTRING(SKUDescr, 1, 20),      
            @cOutField03 = SUBSTRING(SKUDescr, 21, 20),      
            @cOutField04 = CAST(Qty AS NCHAR(10)) + CAST(SeqNo AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR),      
            @nLastSKU = SeqNo,      
            @cOutField05 = PickDetailStatus      
         FROM @tCartonSKUDetail       
         WHERE SeqNo < @nLastSKU      
         ORDER BY SeqNo DESC      
  
         SET @cCartonStatus = ''  
         IF @cDropIDType IN ('CART', 'UCC', 'PP', 'STOTE', 'SINGLES', 'MULTIS' ,'1','2','FCP') -- (ChewKP03) -- (ChewKP04) -- (ChewKP05)     
         BEGIN  
            SET @nPTSQty = 0  
            SET @cTaskDetailKey =  ''  
              
            SELECT @nPTSQty = SUM(CASE WHEN PD.CaseID <> '' THEN QTY ELSE 0 END),   
                   @cTaskDetailKey = MAX(PD.TaskDetailKey),   
                   @nShortPickQty = SUM(CASE WHEN PD.[Status]='4' THEN QTY ELSE 0 END),   
                   @nAllocatedQty = SUM(Qty)       
            FROM PickDetail PD WITH (NOLOCK)      
            JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey      
            WHERE PD.StorerKey = @cStorerKey      
              AND PD.DropID = @cDropID      
              AND PD.Sku = @cOutField01   
              AND LPD.LoadKey = @cLoadKey      
   
            SET @cPTSZone = ''  
            SELECT TOP 1 @cPTSZone = Loc.PutawayZone   
            FROM dbo.StoreToLocDetail STL WITH (NOLOCK)   
            INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.UserDefine02 = STL.ConsigneeKey  
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey  
            INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = O.OrderKey  
            INNER JOIN dbo.Loc LOC WITH (NOLOCK) ON LOC.Loc = STL.Loc  
            WHERE PD.DropID = @cDropID  
            --AND   PD.PickSlipNo = @cPickSlipNo  
            AND   O.LoadKey = @cLoadKey  
            AND   PD.Status = '3'  
            AND   PD.CaseID = ''  
            AND   STL.StoreGroup = CASE WHEN O.Type = 'N' THEN RTRIM(O.OrderGroup) + RTRIM(O.SectionKey) ELSE 'OTHERS' END  
             
            IF @nShortPickQty > 0  
            BEGIN  
               SET @cExtraStatus = '<Short Picked>'                   
            END    
            ELSE IF ISNULL(RTRIM(@cTaskDetailKey),'') <> '' AND @nPTSQty=0  
            BEGIN  
               IF EXISTS(SELECT 1 FROM TaskDetail WITH (NOLOCK)  
                         WHERE TaskDetailKey = @cTaskDetailKey  
                         AND  [Status]='5')  
               BEGIN  
                  SET @cExtraStatus = '<Replen In Progress>'                   
               END  
               ELSE  
                  SET @cExtraStatus = '<PTS In Progress>'  
            END  
            ELSE IF ( @nPTSQty <> @nAllocatedQty AND @nPTSQty > 0 )  OR @nPTSQty = 0   
            BEGIN  
               SET @cExtraStatus = '<PTS In Progress>'                                             
            END  
            ELSE IF @nPTSQty = @nAllocatedQty AND @nPTSQty > 0   
            BEGIN  
               SET @cExtraStatus = '<To Putaway>'  
            END  
         END    
         IF ISNULL(RTRIM(@cExtraStatus),'') <> ''   
            SET @cOutField06 =  @cExtraStatus  
         ELSE   
            SET @cOutField06 = ''     
         --@cPTSZone  
         IF ISNULL(RTRIM(@cPTSZone),'') <> ''   
            SET @cOutField07 =  'PTS ZONE: ' + @cPTSZone  
         ELSE  
            SET @cOutField07 = ''        
                          
      END      
   END        
   GOTO Quit      
         
   Step_3_Fail:      
   GOTO Quit         
END      
GOTO Quit      

/********************************************************************************      
Step 4. screen = 3803      
   CARTON INQUIRY      
      
   WAVEKEY: (Field01, display)      
   LOADKEY: (Field02, display)        
   STORE:       
   (Field03, display)       
   CARTON STATUS:      
   (Field04, display)       
   LAST LOC: (Field05, display)      
********************************************************************************/      
Step_4:      
BEGIN      
   IF @nInputKey = 1 -- ENTER      
   BEGIN      
        
    
      IF @cDropIDType IN ('CART', 'UCC' , 'PP', 'STOTE', 'SINGLES', 'MULTIS', '1','2','FCP') -- (ChewKP03) -- (ChewKP04) -- (ChewKP05)     
      BEGIN      
         INSERT INTO @tCartonSKUDetail       
         SELECT      
            SKU.SKU, SUBSTRING(SKU.DESCR, 1, 40), PD.Qty,       
            CASE WHEN ISNULL(C.Description, '') <> '' THEN SUBSTRING(C.Description, 1, 20)  ELSE PD.Status END  -- (ChewKP01)     
         FROM PickDetail PD WITH (NOLOCK)      
         JOIN SKU WITH (NOLOCK) ON (SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey)      
         JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey      
         LEFT OUTER JOIN CODELKUP C WITH (NOLOCK) ON (C.Listname = 'ORDRSTATUS' AND C.Code = PD.Status)      
         WHERE PD.StorerKey = @cStorerKey      
           AND PD.DropID = @cDropID      
           AND LPD.LoadKey = @cLoadKey      
         ORDER BY PD.OrderLineNumber      
  
      END      
      ELSE IF @cDropIDType IN ('PTS', '0')      
      BEGIN       
         INSERT INTO @tCartonSKUDetail       
         SELECT SKU, Descr, Qty, CASE WHEN ISNULL(C.Description, '') <> '' THEN SUBSTRING(C.Description, 1, 20) ELSE T.Status END -- (ChewKP01)    
         FROM (      
            SELECT PD.LabelLine, SKU.SKU, SUBSTRING(SKU.DESCR, 1, 40) AS 'Descr', PD.Qty, PiD.Status      
            FROM PackDetail PD WITH (NOLOCK)      
            JOIN PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)      
            JOIN SKU WITH (NOLOCK) ON (SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey)      
            JOIN PickDetail PiD WITH (NOLOCK) ON (PD.PickSlipNo = PiD.PickSlipNo AND PD.SKU = PiD.SKU       
                                                  AND PD.StorerKey = PiD.StorerKey AND PD.LabelNo = PiD.CaseID)      
            WHERE PD.StorerKey = @cStorerKey      
              AND @cDropID IN (PD.DropID, PD.RefNo)       
              AND PH.LoadKey = @cLoadKey      
            GROUP BY PD.LabelLine, SKU.SKU, SUBSTRING(SKU.DESCR, 1, 40), PD.Qty, PiD.Status      
         ) AS T      
         LEFT OUTER JOIN CODELKUP C WITH (NOLOCK) ON (C.Listname = 'ORDRSTATUS' AND C.Code = T.Status)      
         ORDER BY LabelLine      
      END      
      
      SELECT @nTotalSKU = COUNT(1)      
      FROM @tCartonSKUDetail      
      
      IF @nTotalSKU > 0      
      BEGIN      
         -- Prep next screen var       
         SELECT TOP 1      
            @cOutField01 = SKU,      
            @cOutField02 = SUBSTRING(SKUDescr, 1, 20),      
            @cOutField03 = SUBSTRING(SKUDescr, 21, 20),      
            @cOutField04 = CAST(Qty AS NCHAR(10)) + CAST(SeqNo AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR),      
            @nLastSKU = SeqNo,      
            @cOutField05 = PickDetailStatus  
         FROM @tCartonSKUDetail       
         WHERE SeqNo > @nLastSKU      
         ORDER BY SeqNo      
  
         SET @cCartonStatus = ''  
         IF @cDropIDType IN ('CART', 'UCC', 'PP', 'STOTE', 'SINGLES', 'MULTIS', '1','2','FCP') -- (ChewKP03) -- (ChewKP04) -- (ChewKP05)  
         BEGIN  
            SET @nPTSQty = 0  
            SET @cTaskDetailKey =  ''  
              
            SELECT @nPTSQty = SUM(CASE WHEN PD.CaseID <> '' THEN QTY ELSE 0 END),   
                   @cTaskDetailKey = MAX(PD.TaskDetailKey),   
                   @nShortPickQty = SUM(CASE WHEN PD.[Status]='4' THEN QTY ELSE 0 END),   
                   @nAllocatedQty = SUM(Qty)      
            FROM PickDetail PD WITH (NOLOCK)      
            JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey      
            WHERE PD.StorerKey = @cStorerKey      
              AND PD.DropID = @cDropID      
              AND PD.Sku = @cOutField01   
              AND LPD.LoadKey = @cLoadKey      
   
            SET @cPTSZone = ''  
            SELECT TOP 1 @cPTSZone = Loc.PutawayZone   
            FROM dbo.StoreToLocDetail STL WITH (NOLOCK)   
            INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.UserDefine02 = STL.ConsigneeKey  
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey  
            INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = O.OrderKey  
            INNER JOIN dbo.Loc LOC WITH (NOLOCK) ON LOC.Loc = STL.Loc  
            WHERE PD.DropID = @cDropID  
            --AND   PD.PickSlipNo = @cPickSlipNo  
            AND   O.LoadKey = @cLoadKey  
            AND   PD.Status = '3'  
            AND   PD.CaseID = ''  
            AND   STL.StoreGroup = CASE WHEN O.Type = 'N' THEN RTRIM(O.OrderGroup) + RTRIM(O.SectionKey) ELSE 'OTHERS' END  
             
            IF @nShortPickQty > 0  
            BEGIN  
               SET @cExtraStatus = '<Short Picked>'                   
            END    
            ELSE IF ISNULL(RTRIM(@cTaskDetailKey),'') <> '' AND @nPTSQty=0  
            BEGIN  
               IF EXISTS(SELECT 1 FROM TaskDetail WITH (NOLOCK)  
                         WHERE TaskDetailKey = @cTaskDetailKey  
                         AND  [Status]='5')  
               BEGIN  
                  SET @cExtraStatus = '<Replen In Progress>'                   
               END  
               ELSE  
                  SET @cExtraStatus = '<PTS In Progress>'  
            END  
            ELSE IF ( @nPTSQty <> @nAllocatedQty AND @nPTSQty > 0 )  OR @nPTSQty = 0  
            BEGIN  
               SET @cExtraStatus = '<PTS In Progress>'                                             
            END  
            ELSE IF @nPTSQty = @nAllocatedQty AND @nPTSQty > 0   
            BEGIN  
               SET @cExtraStatus = '<To Putaway>'  
            END  
         END    
         IF ISNULL(RTRIM(@cExtraStatus),'') <> ''   
            SET @cOutField06 =  @cExtraStatus  
         ELSE   
            SET @cOutField06 = ''  
              
         --@cPTSZone  
         IF ISNULL(RTRIM(@cPTSZone),'') <> ''   
            SET @cOutField07 =  'PTS ZONE: ' + RTRIM(@cPTSZone)  
         ELSE   
            SET @cOutField07 = ''  
         
         IF @cDropIDType <> '1' 
         BEGIN            
            SET @nScn = @nScn + 1      
            SET @nStep = @nStep + 1      
         END
         ELSE
         BEGIN
            SET @nFromScn = @nScn
            SET @nFromStep = @nStep 

            SET @nScn = @nScn - 1
            SET @nStep = @nStep - 1      
         END
      END      
      ELSE      
      BEGIN      
         
         -- Prep next screen var       
         SET @cOutField01 = @cWaveKey      
         SET @cOutField02 = @cLoadKey      
         SET @cOutField03 = @cStore      
         SET @cOutField04 = @cCartonStatus      
         SET @cOutField05 = @cShipToCountry      
         SET @cOutField06 = @cShipToCompany      
         SET @cOutField07 = @cConsigneeKey              
      
         SET @nScn = @nScn      
         SET @nStep = @nStep      
      END      
   END      
      
   IF @nInputKey = 0 -- ESC      
   BEGIN      
      SET @nScn = @nScn - 3     
      SET @nStep = @nStep - 3     
      
      SET @cDropID = ''      
      SET @cWaveKey = ''      
      SET @cLoadKey = ''      
      SET @cStore = ''      
      SET @cCartonStatus = ''      
      SET @cLastLoc = ''      
      SET @cDropIDType = ''      
      SET @nTotalSKU = 0      
      SET @nLastSKU = 0      
      SET @cOrderGroup = ''      
      SET @cSectionKey = ''      
      
      SET @cOutField01 = ''       
      SET @cOutField06 = ''      
      SET @cOutField07 = ''      
              
   END      
   GOTO Quit      
      
   Step_4_Fail:      
   GOTO Quit        
END      
GOTO Quit      
      
/********************************************************************************      
Quit. Update back to I/O table, ready to be pick up by JBOSS      
********************************************************************************/      
Quit:      
BEGIN      
   UPDATE RDTMOBREC WITH (ROWLOCK) SET      
      EditDate      = GETDATE(), 
      ErrMsg        = @cErrMsg,       
      Func          = @nFunc,      
      Step          = @nStep,                  
      Scn           = @nScn,      
      
      StorerKey     = @cStorerKey,      
      Facility      = @cFacility,       
      Printer       = @cPrinter,          
      -- UserName      = @cUserName,      
      V_SKU         = @cSKU,      
      V_QTY         = @nQTY,
   
      V_FromScn     = @nFromScn,
      V_FromStep    = @nFromStep,
      V_Integer1    = @nTotalSKU,
      V_Integer2    = @nLastSKU,
   
      V_String1     = @cDropID,        
      V_String2     = @cWaveKey,      
      V_String3     = @cLoadKey,         
      V_String4     = @cStore,      
      V_String5     = @cCartonStatus,      
      V_String6     = @cLastLoc,      
      V_String7     = @cDropIDType,      
      V_String10    = @cOrderGroup,      
      V_String11    = @cSectionKey,      
      V_String12    = @cConsigneeKey,
      V_String13    = @cShipToCountry,
      V_String14    = @cShipToCompany,
      V_String15    = @cExtendedInquirySP,
      V_String16    = @cUDF01,
      V_String17    = @cUDF02,
      V_String18    = @cUDF03,
      V_String19    = @cUDF04,
      V_String20    = @cUDF05,
      
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