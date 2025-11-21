SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdtfnc_MoveByLabelNo                                */  
/* Copyright      : MAERSK                                              */  
/*                                                                      */  
/* Purpose: From stock from to PackDetail.LabelNo                       */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2012-10-08 1.0  Ung      SOS257810 Created                           */  
/* 2012-11-23 1.1  Ung      SOS261923 Add ConvertQTY, CartonType        */  
/* 2016-09-30 1.2  Ung      Performance tuning                          */  
/* 2018-11-02 1.3  TungGH   Performance                                 */  
/* 2020-08-21 1.4  James    WMS-14608 Add use PackDetailDropID (james01)*/  
/* 2023-08-17 1.5  Ung      Fix confirm label screen not shown          */  
/* 2023-09-05 1.6  James    WMS23509 - Skip step2 from step 4 if user   */
/*                          keyed in everything already (james02)       */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdtfnc_MoveByLabelNo] (  
   @nMobile    INT,  
   @nErrNo     INT  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max  
) AS  
  
SET NOCOUNT ON  
SET ANSI_NULLS OFF  
SET QUOTED_IDENTIFIER OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
  
-- Misc variable  
DECLARE  
   @b_success   INT,  
   @n_err       INT,  
   @c_errmsg    NVARCHAR( 255),  
   @nCountPS    INT,   
   @nTotal      INT,  
   @cSQL        NVARCHAR(1000),   
   @cSQLParam   NVARCHAR(1000),   
   @nSKUQTY     INT,   
   @curPDSKU    CURSOR  
  
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
  
   @cSKU             NVARCHAR( 20),  
   @cDescr           NVARCHAR( 40),  
  
   @cFromLabelNo     NVARCHAR( 20),  
   @cToLabelNo       NVARCHAR( 20),  
   @cMergePLT        NVARCHAR( 1),  
   @cNewToLabelNo    NVARCHAR( 20),   
   @nQTY_Move        INT,  
   @cFromPickSlipNo  NVARCHAR( 10),  
   @cToPickSlipNo    NVARCHAR( 10),  
   @cLabelNoChkSP    NVARCHAR( 20),  
   @cDefaultQTY      NVARCHAR( 1),  
   @cDisableQTYField NVARCHAR( 1),  
   @cConvertQTYSP    NVARCHAR( 20),   
   @cCartonType      NVARCHAR( 10),   
   @cMoveByLabelNoUseDropID   NVARCHAR( 10),  
     
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
   @cLangCode   = Lang_code,  
  
   @cStorerKey  = StorerKey,  
   @cFacility   = Facility,  
   @cUserName   = UserName,  
   @cPrinter    = Printer,  
  
   @cSKU        = V_SKU,  
   @cDescr      = V_SKUDescr,  
  
   @cFromLabelNo     = V_String1,  
   @cToLabelNo       = V_String2,  
   @cMergePLT        = V_String3,  
   @cNewToLabelNo    = V_String4,  
   @cFromPickSlipNo  = V_String6,  
   @cToPickSlipNo    = V_String7,   
   @cLabelNoChkSP    = V_String8,  
   @cDefaultQTY      = V_String9,  
   @cDisableQTYField = V_String10,  
   @cConvertQTYSP    = V_String11,   
   @cCartonType      = V_String12,   
   @cMoveByLabelNoUseDropID = V_String13,  
     
   @nQTY_Move        = V_Integer1,  
  
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
IF @nFunc = 533  
BEGIN  
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 533  
   IF @nStep = 1 GOTO Step_1   -- Scn = 3250. From DropID  
   IF @nStep = 2 GOTO Step_2   -- Scn = 3251. To Drop ID, merge carton  
   IF @nStep = 3 GOTO Step_3   -- Scn = 3252. SKU, QTY  
   IF @nStep = 4 GOTO Step_4   -- Scn = 3253. Option. New To LabelNo?  
END  
RETURN -- Do nothing if incorrect step  
  
  
/********************************************************************************  
Step 0. Called from menu  
********************************************************************************/  
Step_0:  
BEGIN  
   -- Set the entry point  
   SET @nScn = 3250  
   SET @nStep = 1  
  
   -- Init var  
  
   -- Get StorerConfig  
   SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)  
   IF @cDefaultQTY = '0'  
      SET @cDefaultQTY = ''  
   SET @cDisableQTYField = rdt.RDTGetConfig( @nFunc, 'DisableQTYField', @cStorerKey)  
   IF @cDisableQTYField = '1'  
      SET @cDefaultQTY = '1'  
   SET @cLabelNoChkSP = rdt.RDTGetConfig( @nFunc, 'LabelNoChkSP', @cStorerKey)  
   IF @cLabelNoChkSP = '0'  
      SET @cLabelNoChkSP = ''  
   SET @cConvertQTYSP = rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorerKey)  
   IF @cConvertQTYSP = '0'  
      SET @cConvertQTYSP = ''  
  
   -- (james01)  
   SET @cMoveByLabelNoUseDropID = rdt.RDTGetConfig( @nFunc, 'MoveByLabelNoUseDropID', @cStorerKey)  
    
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
   SET @cFromLabelNo = ''  
   SET @cMergePLT = 1  
   SET @cOutField01 = ''  -- From DropID  
   SET @cOutField02 = '1' -- Merge Pallet  
  
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
Step 1. Screen = 3250  
   FROM LABELNO   (Field01, input)  
********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cFromLabelNo = @cInField01  
      SET @cMergePLT = @cInField02  
  
      -- Validate blank  
      IF @cFromLabelNo = ''  
      BEGIN  
         SET @nErrNo = 77601  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelNo needed  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_1_Fail  
      END  
  
      -- Get PickSlip  
      SET @cFromPickSlipNo = ''  
      SET @nCountPS = 0  
      SELECT  
         @nCountPS = COUNT( DISTINCT PH.PickSlipNo),  
         @cFromPickSlipNo = MAX( PH.PickSlipNo) -- Just to bypass SQL aggregate checking  
      FROM dbo.PackHeader PH WITH (NOLOCK)  
         INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
      WHERE PH.StorerKey = @cStorerKey  
         AND (( @cMoveByLabelNoUseDropID = '1' AND PD.DropID = @cFromLabelNo) OR ( PD.LabelNo = @cFromLabelNo))  
  
      -- Check if valid DropID  
      IF @nCountPS = 0  
      BEGIN  
         SET @nErrNo = 77602  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLabelNo  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_1_Fail  
      END  
  
      -- Check if labelno in multi PickSlip  
      IF @nCountPS > 1  
      BEGIN  
         SET @nErrNo = 77603  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelInMultiPS  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_1_Fail  
      END  
  
      SET @cNewToLabelNo = 'N'  
  
      -- Prep next screen var  
      SET @cOutField01 = @cFromLabelNo  
      SET @cOutField02 = '' -- ToLabelNo  
      SET @cOutField03 = ''  
      EXEC rdt.rdtSetFocusField @nMobile, 2 --ToLabelNo  
        
      SET @nScn  = @nScn + 1  
      SET @nStep = @nStep + 1  
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
      SET @cFromLabelNo = ''  
      SET @cOutField01 = '' --FromLabelNo  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 2. Screen = 3251  
   FROM LABELNO     (Field01)  
   TO LABELNO       (Field12, input)  
   MERGE PALLET:   (Field03, input)  
   1 = Yes 2 = No  
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cToLabelNo = @cInField02  
      SET @cMergePLT = @cInField03  
  
      IF @cInField02 <> @cOutField02  
         SET @cNewToLabelNo = 'N'  
  
      -- Validate blank  
      IF @cToLabelNo = ''  
      BEGIN  
         SET @nErrNo = 77604  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LabelNo  
         GOTO Step_2_Fail  
      END  
  
      -- Validate if From DropID = To DropID  
      IF @cFromLabelNo = @cToLabelNo  
      BEGIN  
         SET @nErrNo = 77605  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Same LabelNo  
         GOTO Step_2_Fail  
      END  
  
      -- Get ToPickSlip info  
      SET @nCountPS = 0  
      SELECT  
         @nCountPS = COUNT( DISTINCT PH.PickSlipNo),  
         @cToPickSlipNo = ISNULL( MAX( PH.PickSlipNo), '') -- Just to bypass SQL aggregate checking  
      FROM dbo.PackHeader PH WITH (NOLOCK)  
         INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
      WHERE PH.StorerKey = @cStorerKey  
         AND (( @cMoveByLabelNoUseDropID = '1' AND PD.DropID = @cToLabelNo) OR ( PD.LabelNo = @cToLabelNo))  
  
      -- Check if to labelno in multi PickSlip  
      IF @nCountPS > 1  
      BEGIN  
         SET @nErrNo = 77606  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelInMultiPS  
         GOTO Step_2_Fail  
      END  
  
      -- Check diff pickslipno  
      IF @cFromPickSlipNo <> @cToPickSlipNo AND @cToPickSlipNo <> ''  
      BEGIN  
         SET @nErrNo = 77607  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff PickSlip  
         GOTO Step_2_Fail  
      END  
  
      -- LabelNo extended validation  
      IF @cLabelNoChkSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cLabelNoChkSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC ' + RTRIM( @cLabelNoChkSP) +   
               ' @nMobile, @nFunc, @cLangCode, @cFromLabelNo, @cToLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
            SET @cSQLParam =  
               '@nMobile       INT,        ' +  
               '@nFunc         INT,        ' +  
               '@cLangCode     NVARCHAR(3),    ' +  
               '@cFromLabelNo  NVARCHAR( 20),  ' +  
               '@cToLabelNo    NVARCHAR( 20),  ' +  
               '@nErrNo        INT OUTPUT, ' +    
               '@cErrMsg       NVARCHAR( 20) OUTPUT'  
              
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,   
               @nMobile, @nFunc, @cLangCode, @cFromLabelNo, @cToLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Step_2_Fail  
         END  
      END  
  
      -- Check if new to labelno  
      IF @nCountPS = 0 AND @cNewToLabelNo = 'N'  
      BEGIN  
         -- Prep next screen var  
         SET @cOutField01 = '' -- Option  
         EXEC rdt.rdtSetFocusField @nMobile, 1 --Option  
  
         -- Go back to from labelno screen  
         SET @nScn  = @nScn + 2  
         SET @nStep = @nStep + 2  
           
         GOTO Quit  
      END  
  
      -- Retain ToLabelNo  
      SET @cOutField02 = @cToLabelNo  
  
      -- Validate Option is blank  
      IF @cMergePLT = ''  
      BEGIN  
         SET @nErrNo = 77608  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option needed  
         EXEC rdt.rdtSetFocusField @nMobile, 3  
         GOTO Quit  
      END  
  
      -- Validate Option  
      IF @cMergePLT NOT IN ('1', '2')  
      BEGIN  
         SET @nErrNo = 77609  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option  
         EXEC rdt.rdtSetFocusField @nMobile, 3  
         GOTO Quit  
      END  
  
      -- Merge by carton  
      IF @cMergePLT = '1'  
      BEGIN  
         EXECUTE rdt.rdt_MoveByLabelNo @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey,  
            @cFromPickSlipNo,  
            @cFromLabelNo,  
            @cToLabelNo,  
            @cCartonType,   
            '', -- SKU  
            0, -- QTY  
            @nErrNo OUTPUT,  
            @cErrMsg OUTPUT  -- screen limitation, 20 char max  
  
         IF @nErrNo <> 0  
            GOTO Quit  
  
         -- Event log  
         EXEC RDT.rdt_STD_EventLog  
            @cActionType   = '4', -- Move  
            @cUserID       = @cUserName,  
            @nMobileNo     = @nMobile,  
            @nFunctionID   = @nFunc,  
            @cFacility     = @cFacility,  
            @cStorerKey    = @cStorerkey,  
            @cPickSlipNo   = @cFromPickSlipNo,  
            @cLabelNo      = @cFromLabelNo,   
            @cToLabelNo    = @cToLabelNo,  
            @nStep         = @nStep  
  
         -- Prep next screen var  
         SET @cOutField01 = '' -- Option  
  
         -- Go back to from labelno screen  
         SET @nScn  = @nScn - 1  
         SET @nStep = @nStep - 1  
      END  
  
      -- Merge by SKU  
      IF @cMergePLT = '2'  
      BEGIN  
         -- Get total  
         SELECT @nTotal = ISNULL( SUM( PD.QTY), 0)  
         FROM dbo.PackDetail PD WITH (NOLOCK)  
         WHERE PD.StorerKey = @cStorerKey  
         AND (( @cMoveByLabelNoUseDropID = '1' AND PD.DropID = @cFromLabelNo) OR ( PD.LabelNo = @cFromLabelNo))  
           
         -- Convert QTY  
         IF @cConvertQTYSP <> '' AND EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConvertQTYSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC ' + RTRIM( @cConvertQTYSP) + ' @cType, @cStorer, @cSKU, @nQTY OUTPUT'  
            SET @cSQLParam =  
               '@cType   NVARCHAR( 10), ' +    
               '@cStorer NVARCHAR( 15), ' +    
               '@cSKU    NVARCHAR( 20), ' +    
               '@nQTY    INT OUTPUT'  
              
            -- Get Total  
            SET @nTotal = 0  
            SET @nSKUQTY = 0  
            SET @curPDSKU = CURSOR FOR  
               SELECT SKU, QTY  
               FROM dbo.PackDetail PD WITH (NOLOCK)  
               WHERE PD.StorerKey = @cStorerKey  
                  AND (( @cMoveByLabelNoUseDropID = '1' AND PD.DropID = @cFromLabelNo) OR ( PD.LabelNo = @cFromLabelNo))  
            OPEN @curPDSKU  
            FETCH NEXT FROM @curPDSKU INTO @cSKU, @nSKUQTY  
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorerKey, @cSKU, @nSKUQTY OUTPUT  
               SET @nTotal = @nTotal + @nSKUQTY  
               FETCH NEXT FROM @curPDSKU INTO @cSKU, @nSKUQTY  
            END  
         END  
  
         -- Disable and default QTY field  
         IF @cDisableQTYField = '1'  
            SET @cFieldAttr05 = 'O' -- QTY  
           
         -- Prep next screen var  
         SET @cSKU = ''  
         SET @nQTY_Move = 0  
  
         SET @cOutField01 = @cToLabelNo  
         SET @cOutField02 = '' -- SKU  
         SET @cOutField03 = '' -- SKU desc  
         SET @cOutField04 = '' -- SKU desc  
         SET @cOutField05 = @cDefaultQTY  
         SET @cOutField06 = '0'  
         SET @cOutField07 = '0/' + CAST( @nTotal AS NVARCHAR( 5))  
  
         -- Go to SKU/UPC screen  
         SET @nScn  = @nScn + 1  
         SET @nStep = @nStep + 1  
      END  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Prepare next screen var  
      SET @cFromLabelNo = ''  
      SET @cOutField01 = '' --FromLabelNo  
  
      -- Go to prev screen  
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
   GOTO Quit  
  
   Step_2_Fail:  
   BEGIN  
      SET @cToLabelNo = ''  
      SET @cOutField12 = '' -- To DropID  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 3. Screen 3252  
   FROM LABELNO: (Field01)  
   SKU/UPC:     (Field02, input)  
   SKU DESC1    (Field03)  
   SKU DESC2    (Field04)  
   QTY          (Field05)  
   QTY MV       (Field06)  
   QTY BAL      (Field07)  
********************************************************************************/  
Step_3:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      DECLARE @cQTY NVARCHAR(5)  
  
      -- Screen mapping  
      SET @cSKU = @cInField02  
      IF @cDisableQTYField = '1'  
         SET @cQTY = '1'  
      ELSE  
         SET @cQTY = @cInField05 -- QTY  
  
      -- Validate blank  
      IF @cSKU = ''  
      BEGIN  
         SET @nErrNo = 77610  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU/UPC needed  
         GOTO Step_3_Fail  
      END  
  
      -- Get SKU count  
      DECLARE @nSKUCnt INT  
      EXEC [RDT].[rdt_GetSKUCnt]  
          @cStorerKey  = @cStorerKey  
         ,@cSKU        = @cSKU  
         ,@nSKUCnt     = @nSKUCnt       OUTPUT  
         ,@bSuccess    = @b_Success     OUTPUT  
         ,@nErr        = @n_Err         OUTPUT  
         ,@cErrMsg     = @c_ErrMsg      OUTPUT  
  
      -- Validate SKU/UPC  
      IF @nSKUCnt = 0  
      BEGIN  
         SET @nErrNo = 77611  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'  
         GOTO Step_3_Fail  
      END  
  
      -- Validate barcode return multiple SKU  
      IF @nSKUCnt > 1  
      BEGIN  
         SET @nErrNo = 77612  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SameBarCodeSKU'  
         GOTO Step_3_Fail  
      END  
  
      -- Get SKU code thru barcode  
      EXEC [RDT].[rdt_GetSKU]  
          @cStorerKey  = @cStorerKey  
         ,@cSKU        = @cSKU          OUTPUT  
         ,@bSuccess    = @b_Success     OUTPUT  
         ,@nErr        = @n_Err         OUTPUT  
         ,@cErrMsg     = @c_ErrMsg      OUTPUT  
  
      -- Check if SKU exists in DropID  
      IF NOT EXISTS (SELECT 1  
         FROM dbo.PackDetail PD WITH (NOLOCK)  
         WHERE PD.StorerKey = @cStorerKey  
            AND PD.SKU = @cSKU  
            AND (( @cMoveByLabelNoUseDropID = '1' AND PD.DropID = @cFromLabelNo) OR ( PD.LabelNo = @cFromLabelNo)))  
      BEGIN  
         SET @nErrNo = 77613  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInLabel  
         GOTO Step_3_Fail  
      END  
  
      -- Get SKU info  
      SELECT @cDescr = S.Descr  
      FROM dbo.SKU S (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
        AND SKU = @cSKU  
  
      -- Retain SKU field  
      SET @cOutField02 = @cSKU  
      SET @cOutField03 = SUBSTRING( @cDescr,  1, 20)  
      SET @cOutField04 = SUBSTRING( @cDescr, 21, 20)  
  
      -- Validate blank QTY  
      IF @cQty = '' OR @cQty IS NULL  
      BEGIN  
         SET @nErrNo = 77614  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY Required  
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- QTY  
         GOTO Quit  
      END  
  
      -- Validate QTY  
      IF rdt.rdtIsValidQty( @cQty, 1) = 0  
      BEGIN  
         SET @nErrNo = 77615  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY  
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- QTY  
         GOTO Quit  
      END  
  
      DECLARE @nQTY INT  
      SET @nQTY = CAST( @cQTY AS INT)  
        
      -- Convert QTY  
      IF @cConvertQTYSP <> '' AND EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConvertQTYSP AND type = 'P')  
      BEGIN  
         SET @cSQL = 'EXEC ' + RTRIM( @cConvertQTYSP) + ' @cType, @cStorer, @cSKU, @nQTY OUTPUT'  
         SET @cSQLParam =  
            '@cType   NVARCHAR( 10), ' +    
            '@cStorer NVARCHAR( 15), ' +    
            '@cSKU    NVARCHAR( 20), ' +    
            '@nQTY    INT OUTPUT'  
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToBaseQTY', @cStorerKey, @cSKU, @nQTY OUTPUT  
      END  
              
      -- Validate QTY  
      IF (SELECT ISNULL( SUM( QTY), 0)   
         FROM dbo.PackDetail PD WITH (NOLOCK)   
         WHERE PD.StorerKey = @cStorerKey  
            AND (( @cMoveByLabelNoUseDropID = '1' AND PD.DropID = @cFromLabelNo) OR ( PD.LabelNo = @cFromLabelNo))   
            AND PD.SKU = @cSKU) < CAST( @nQTY AS INT)  
      BEGIN  
         SET @nErrNo = 77616  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotEnufQTYtoMV  
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- QTY  
         GOTO Quit  
      END  
        
      -- Retain QTY field  
      SET @cOutField05 = @cQTY  

      -- Move QTY  
      EXECUTE rdt.rdt_MoveByLabelNo @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey,  
         @cFromPickSlipNo,  
         @cFromLabelNo,  
         @cToLabelNo,  
         @cCartonType,   
         @cSKU,  
         @nQTY,  
         @nErrNo  OUTPUT,  
         @cErrMsg OUTPUT  -- screen limitation, 20 char max  
  
      IF @nErrNo <> 0  
         GOTO Quit  
  
      -- Event log  
      EXEC RDT.rdt_STD_EventLog  
         @cActionType   = '4', -- Move  
         @cUserID       = @cUserName,  
         @nMobileNo     = @nMobile,  
         @nFunctionID   = @nFunc,  
         @cFacility     = @cFacility,  
         @cStorerKey    = @cStorerkey,  
         @cPickSlipNo   = @cFromPickSlipNo,   
         @cSKU          = @cSKU,   
         @nQTY          = @nQTY,   
         @cLabelNo      = @cFromLabelNo,   
         @cToLabelNo    = @cToLabelNo,  
         @nStep         = @nStep  
              
      -- Get total  
      SELECT @nTotal = ISNULL( SUM( PD.QTY), 0)  
      FROM dbo.PackDetail PD WITH (NOLOCK)  
      WHERE PD.StorerKey = @cStorerKey  
         AND (( @cMoveByLabelNoUseDropID = '1' AND PD.DropID = @cFromLabelNo) OR ( PD.LabelNo = @cFromLabelNo))  
  
      -- Get total of this SKU  
      DECLARE @nQTY_SKU INT  
      SELECT @nQTY_SKU = ISNULL( SUM( PD.QTY), 0)  
      FROM dbo.PackDetail PD WITH (NOLOCK)  
      WHERE PD.StorerKey = @cStorerKey  
         AND PD.SKU = @cSKU  
         AND (( @cMoveByLabelNoUseDropID = '1' AND PD.DropID = @cFromLabelNo) OR ( PD.LabelNo = @cFromLabelNo))  
  
      -- Convert QTY  
      IF @cConvertQTYSP <> '' AND EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConvertQTYSP AND type = 'P')  
      BEGIN  
         SET @cSQL = 'EXEC ' + RTRIM( @cConvertQTYSP) + ' @cType, @cStorer, @cSKU, @nQTY OUTPUT'  
         SET @cSQLParam =  
            '@cType   NVARCHAR( 10), ' +    
            '@cStorer NVARCHAR( 15), ' +    
            '@cSKU    NVARCHAR( 20), ' +    
            '@nQTY    INT OUTPUT'  
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorerKey, @cSKU, @nQTY_SKU OUTPUT  
           
         -- Get Total  
         SET @nTotal = 0  
         SET @nSKUQTY = 0  
         SET @curPDSKU = CURSOR FOR  
            SELECT SKU, QTY  
            FROM dbo.PackDetail PD WITH (NOLOCK)  
            WHERE PD.StorerKey = @cStorerKey  
               AND (( @cMoveByLabelNoUseDropID = '1' AND PD.DropID = @cFromLabelNo) OR ( PD.LabelNo = @cFromLabelNo))  
         OPEN @curPDSKU  
         FETCH NEXT FROM @curPDSKU INTO @cSKU, @nSKUQTY  
         WHILE @@FETCH_STATUS = 0  
         BEGIN  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorerKey, @cSKU, @nSKUQTY OUTPUT  
            SET @nTotal = @nTotal + @nSKUQTY  
            FETCH NEXT FROM @curPDSKU INTO @cSKU, @nSKUQTY  
         END  
      END  
  
      SET @nQTY_Move = @nQTY_Move + CAST( @cQTY AS INT)  
  
      -- Remain in current screen  
      SET @cSKU = ''  
      SET @cOutField01 = @cToLabelNo  
      SET @cOutField02 = @cSKU  
      SET @cOutField03 = SUBSTRING( @cDescr, 1, 20)  
      SET @cOutField04 = SUBSTRING( @cDescr, 21, 20)  
      SET @cOutField05 = @cDefaultQTY  
      SET @cOutField06 = CAST( @nQTY_Move AS NVARCHAR( 5))  
      SET @cOutField07 = CAST( @nQTY_SKU AS NVARCHAR( 5)) + '/' + CAST( @nTotal AS NVARCHAR( 5))  
      EXEC rdt.rdtSetFocusField @nMobile, 2 --SKU  
        
      -- Remain in current screen  
      -- SET @nScn  = @nScn + 1  
      -- SET @nStep = @nStep + 1  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Prepare prev screen var  
      SET @cOutField01 = @cFromLabelNo  
      SET @cOutField02 = ''  
      SET @cOutField03 = @cMergePLT  
  
      SET @cFieldAttr05 = '' -- QTY  
  
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1  
  
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- FromLabelNo  
   END  
   GOTO Quit  
  
   Step_3_Fail:  
   BEGIN  
      SET @cSKU = ''  
      SET @cDescr = ''  
      SET @cOutField02 = '' -- SKU  
      SET @cOutField03 = '' -- Desc1  
      SET @cOutField04 = '' -- Desc2  
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- SKU  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 4. Screen = 3253  
   NEW LABEL NO?  
   1 = YES  
   2 = NO  
   OPTION (Field01, input)  
   CARTON TYPE (field02, input)  
********************************************************************************/  
Step_4:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      DECLARE @cOption NVARCHAR( 1)  
  
      -- Screen mapping  
      SET @cOption = @cInField01  
      SET @cCartonType = @cInField02  
  
      -- Validate blank  
      IF @cOption = ''  
      BEGIN  
         SET @nErrNo = 77617  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option needed  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Quit  
      END  
  
      -- Validate option  
      IF @cOption <> '1' AND @cOption <> '2'  
      BEGIN  
         SET @nErrNo = 77618  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Quit  
      END  
      SET @cOutField01 = @cOption  
  
      IF @cOption = '1' -- YES  
      BEGIN  
         IF @cCartonType = ''  
         BEGIN  
            SET @nErrNo = 77619  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedCartonType  
            EXEC rdt.rdtSetFocusField @nMobile, 2  
            GOTO Quit  
         END  
           
         IF NOT EXISTS( SELECT 1   
            FROM dbo.Cartonization C WITH (NOLOCK)   
               JOIN dbo.Storer WITH (NOLOCK) ON (C.CartonizationGroup = Storer.CartonGroup)  
            WHERE Storer.StorerKey = @cStorerKey  
               AND C.CartonType = @cCartonType)  
         BEGIN  
            SET @nErrNo = 77620  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CartonType  
            EXEC rdt.rdtSetFocusField @nMobile, 2  
            GOTO Quit  
         END    
         
         SET @cNewToLabelNo = 'Y'
         
         -- if everything all keyed in then skip step 2 ( james02)
         IF @cFromLabelNo <> '' AND @cToLabelNo <> '' AND @cMergePLT <> ''
         BEGIN
            -- Prepare next screen var  
            SET @cOutField01 = @cFromLabelNo  
            SET @cOutField02 = @cToLabelNo  
            SET @cOutField03 = @cMergePLT   
            SET @cInField02 = @cOutField02

            SET @nScn  = @nScn - 2  
            SET @nStep = @nStep - 2

            GOTO Step_2
         END
      
         SET @cMergePLT = ''  
         EXEC rdt.rdtSetFocusField @nMobile, 3 --MergePLT  
      END  
  
      IF @cOption = '2' -- NO  
      BEGIN  
         SET @cNewToLabelNo = 'N'  
         SET @cToLabelNo = ''  
         SET @cCartonType = ''  
         SET @cMergePLT = ''  
         EXEC rdt.rdtSetFocusField @nMobile, 2 --ToLabelNo  
      END  
      
      -- Prepare next screen var  
      SET @cOutField01 = @cFromLabelNo  
      SET @cOutField02 = @cToLabelNo  
      SET @cOutField03 = @cMergePLT   
  
      -- Back to from labelno screen  
      SET @nScn  = @nScn - 2  
      SET @nStep = @nStep - 2  
   END  
     
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Prepare next screen var  
      SET @cNewToLabelNo = 'N'  
      SET @cToLabelNo = ''  
      SET @cCartonType = ''  
      SET @cMergePLT = ''  
  
      SET @cOutField01 = @cFromLabelNo  
      SET @cOutField02 = @cToLabelNo  
      SET @cOutField03 = @cMergePLT   
      EXEC rdt.rdtSetFocusField @nMobile, 2 --ToLabelNo  
     
      -- Back to TO labelno screen  
      SET @nScn  = @nScn - 2  
      SET @nStep = @nStep - 2  
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
      -- UserName   = @cUserName,-- (Vicky06)  
      Printer    = @cPrinter,  
  
      V_SKU      = @cSKU,  
      V_SKUDescr = @cDescr,  
  
    V_String1  = @cFromLabelNo,  
      V_String2  = @cToLabelNo,  
      V_String3  = @cMergePLT,  
      V_String4  = @cNewToLabelNo,  
      V_String6  = @cFromPickSlipNo,  
      V_String7  = @cToPickSlipNo,  
      V_String8  = @cLabelNoChkSP,  
      V_String9  = @cDefaultQTY,  
      V_String10 = @cDisableQTYField,  
      V_String11 = @cConvertQTYSP,   
      V_String12 = @cCartonType,   
      V_String13 = @cMoveByLabelNoUseDropID,  
           
      V_Integer1 = @nQTY_Move,  
     
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