SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdtfnc_PostPickAudit_Reset                          */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: normal receipt                                              */  
/*                                                                      */  
/* Called from: 3                                                       */  
/*    1. From PowerBuilder                                              */  
/*    2. From scheduler                                                 */  
/*    3. From others stored procedures or triggers                      */  
/*    4. From interface program. DX, DTS                                */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2011-05-23 1.0  Ung        Created                                   */  
/* 2011-11-24 1.1  Ung        Fix PickSlipNo option, OrderKey retrieved */  
/* 22-12-2015 1.2  Leong      SOS359525 - Revise variable size.         */  
/* 30-09-2016 1.3  Ung        Performance tuning                        */  
/* 04-11-2016 1.4  Ung        WMS-612 Add PPACartonIDByPackDetailLabelNo*/  
/* 15-12-2016 1.5  ChewKP     WMS-787 Add RDT Config                    */  
/*                            "PPACartonIDByPickDetailCaseID" (ChewKP01)*/  
/* 29-06-2017 1.6  James      WMS-2297 Add ExtendedUpdateSP (james01)   */  
/* 08-10-2018 1.7  TungGH     Performance                               */  
/* 11-08-2020 1.8  James      INC1244432 - Bug fix (james02)            */  
/* 08-12-2021 1.9  James      WMS-18457 Add cfg skip step sku(james03)  */  
/* 05-04-2022 2.0  yeekung    WMS-19378 Add extendedvalidate (yeekung01)*/
/* 11-12-2022 2.1 YeeKung    WMS-21260 Add palletid/taskdetail         */
/*                            (yeekung02)                               */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdtfnc_PostPickAudit_Reset] (  
   @nMobile    int,  
   @nErrNo     int  OUTPUT,  
   @cErrMsg    NVARCHAR( 20) OUTPUT  
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
-- Misc variable  
DECLARE  
   @b_success       INT,  
   @n_err           INT,  
   @c_errmsg        NVARCHAR( 250),  
  
   @nRowRef         INT,  
   @cChkPickSlipNo  NVARCHAR( 10),  
   @dScanInDate     DATETIME,  
   @dScanOutDate    DATETIME  
  
-- rdt.rdtMobRec variable  
DECLARE  
   @nFunc           INT,  
   @nScn            INT,  
   @nStep           INT,  
   @nMenu           INT,  
   @cLangCode       NVARCHAR( 3),  
   @nInputKey       INT,  
  
   @cStorer         NVARCHAR( 15),  
   @cFacility       NVARCHAR( 5),  
   @cUserName       NVARCHAR(18),  
   @cPrinter        NVARCHAR( 10),  
  
   @cSKU            NVARCHAR( 20),  
   @cSKUDescr       NVARCHAR( 60),  
   @cLoadKey        NVARCHAR( 10),  
   @cPickSlipNo     NVARCHAR( 10),  
  
   @cRefNo          NVARCHAR( 10),  
   @cOrderKey       NVARCHAR( 10),  
   @cDropID         NVARCHAR( 20), -- SOS359525  
   @cID             NVARCHAR( 18),  --(yeekung02)
   @cTaskDetailKey  NVARCHAR( 10), --(yeekung02)
   @cStyle          NVARCHAR( 20),  
   @cColor          NVARCHAR( 10),  
   @cSize           NVARCHAR( 10), -- SOS359525  
   @cPPACartonIDByPackDetailDropID  NVARCHAR( 1),  
   @cPPACartonIDByPackDetailLabelNo NVARCHAR( 1),  
   @cPPACartonIDByPickDetailCaseID  NVARCHAR( 1), -- (ChewKP01)   
   @cExtendedUpdateSP               NVARCHAR( 20),  
   @cFlowThruStepSKU                NVARCHAR( 1),  
   @cExtendedValidateSP             NVARCHAR( 20), --(yeekung01)
   @cSkipChkPSlipMustScanOut        NVARCHAR( 1),
      
   @cWhere                          NVARCHAR( 100),  
   @cSQL                            NVARCHAR( MAX),  
   @cSQLParam                       NVARCHAR( MAX),  
  
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
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60)  
  
-- Getting Mobile information  
SELECT  
   @nFunc      = Func,  
   @nScn       = Scn,  
   @nStep      = Step,  
   @nMenu      = Menu,  
   @cLangCode  = Lang_code,  
   @nInputKey  = InputKey,  
  
   @cStorer    = StorerKey,  
   @cFacility  = Facility,  
   @cPrinter   = Printer,  
   @cUserName  = UserName,  
  
   @cSKU       = V_SKU,  
   @cSKUDescr  = V_SKUDescr,  
   @cLoadKey   = V_LoadKey,  
   @cPickSlipNo = V_PickSlipNo,  
   @cTaskDetailKey  = V_TaskDetailKey, 
   @cID         = V_ID, 
  
   @cRefNo            = V_String1,  
   @cOrderKey         = V_String2,  
   @cDropID           = V_String3,  
   @cStyle            = V_String4,  
   @cColor            = V_String5,  
   @cSize             = V_String6,  
   @cPPACartonIDByPackDetailDropID  = V_String7,  
   @cPPACartonIDByPackDetailLabelNo = V_String8,  
   @cPPACartonIDByPickDetailCaseID  = V_String9,  
   @cExtendedUpdateSP               = V_String10,  
   @cFlowThruStepSKU                = V_String11,  
   @cExtendedValidateSP             = V_String12,
   @cSkipChkPSlipMustScanOut        = V_String13,
  
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
   @cInField15 = I_Field15,   @cOutField15 = O_Field15  
  
FROM rdt.rdtMobRec WITH (NOLOCK)  
WHERE Mobile = @nMobile  
  
IF @nFunc in (848)  
BEGIN  
   IF @nStep = 0 GOTO Step_0  -- Menu. Func = 848  
   IF @nStep = 1 GOTO Step_1  -- Scn = 2830. RefNo, PickSlipNo, LoadKey, OrderKey, CartonID  
   IF @nStep = 2 GOTO Step_2  -- Scn = 2831. RefNo, PickSlipNo, LoadKey, OrderKey, CartonID, SKU  
   IF @nStep = 3 GOTO Step_3  -- Scn = 2832. RefNo, PickSlipNo, LoadKey, OrderKey, CartonID, SKU, description, style, color, size  
   IF @nStep = 4 GOTO Step_4  -- Scn = 2833. Message. Option  
END  
RETURN -- Do nothing if incorrect step  
  
  
/********************************************************************************  
Step 0. Func = 848  
********************************************************************************/  
Step_0:  
BEGIN  
   -- Get storer config  
   SET @cPPACartonIDByPackDetailDropID = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPackDetailDropID', @cStorer)  
   SET @cPPACartonIDByPackDetailLabelNo = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPackDetailLabelNo', @cStorer)  
   SET @cPPACartonIDByPickDetailCaseID = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPickDetailCaseID', @cStorer)  -- (ChewKP01)   
  
   -- (james01)  
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorer)  
   IF @cExtendedUpdateSP = '0'  
      SET @cExtendedUpdateSP = ''  

   -- (james01)  
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorer)  
   IF @cExtendedValidateSP = '0'  
      SET @cExtendedValidateSP = ''  
  
   -- (james03)  
   SET @cFlowThruStepSKU  = rdt.rdtGetConfig( @nFunc, 'FlowThruStepSKU', @cStorer)  

   SET @cSkipChkPSlipMustScanOut = rdt.rdtGetConfig( @nFunc, 'SkipChkPSlipMustScanOut', @cStorer)
  

   -- Init var
   SET @cRefNo      = ''
   SET @cPickSlipNo = ''
   SET @cLoadKey    = ''
   SET @cOrderKey   = ''
   SET @cDropID     = ''
   SET @cSKU        = ''

   -- Prepare next screen var
   SET @cOutField01 = @cRefNo
   SET @cOutField02 = @cPickSlipNo
   SET @cOutField03 = @cLoadKey
   SET @cOutField04 = @cOrderKey
   SET @cOutField05 = @cDropID
   SET @cOutField06 = @cID
   SET @cOutField07 = @cTaskDetailKey
  
   -- Go to next screen  
   SET @nScn = 2830  
   SET @nStep = 1  
  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 1. Scn = 814  
   PickSlipNo (field01, input)  
   RefNo      (field02, input)  
   LoadKey    (field03, input)  
   OrderKey   (field04, input)  
   Carton ID  (field05, input)  
   SKU        (field06, input)  
********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Screen mapping  
      SET @cRefNo      = ISNULL( @cInField01, '') -- Refno  
      SET @cPickSlipNo = ISNULL( @cInField02, '') -- PickSlipNo  
      SET @cLoadKey    = ISNULL( @cInField03, '') -- LoadKey  
      SET @cOrderKey   = ISNULL( @cInField04, '') -- OrderKey  
      SET @cDropID     = ISNULL( @cInField05, '') -- DropID
      SET @cID         = ISNULL( @cInField06, '') -- ID
      SET @cTaskDetailKey  = ISNULL( @cInField07, '') -- ID
  
      -- Validate blank
      IF @cRefNo      = '' AND
         @cPickSlipNo = '' AND
         @cLoadKey    = '' AND
         @cOrderKey   = '' AND
         @cDropID     = '' AND
         @cID         = '' AND
         @cTaskDetailKey =''
      BEGIN
         SET @nErrNo = 73216
         SET @cErrMsg = rdt.rdtgetmessage( 73216, @cLangCode,'DSP') -- Value required!
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- Validate more then 1 param
      DECLARE @i INT
      SET @i = 0
      IF @cRefNo      <> '' SET @i = @i + 1
      IF @cPickSlipNo <> '' SET @i = @i + 1
      IF @cLoadKey    <> '' SET @i = @i + 1
      IF @cOrderKey   <> '' SET @i = @i + 1
      IF @cDropID     <> '' SET @i = @i + 1
      IF @cID         <> '' SET @i = @i + 1
      IF @cTaskDetailKey <> '' SET @i = @i + 1
      IF @i > 1
      BEGIN
         SET @nErrNo = 73217
         SET @cErrMsg = rdt.rdtgetmessage( 73217, @cLangCode,'DSP') -- Key-in either 1
         GOTO Step_1_Fail
      END
  
      -- Ref No  
      IF @cRefNo <> ''  
      BEGIN  
         -- Validate load plan status  
         IF NOT EXISTS( SELECT 1  
            FROM dbo.LoadPlan WITH (NOLOCK)  
            WHERE UserDefine10 = @cRefNo  
               AND Status <= '9') -- 9=Closed  
         BEGIN  
            SET @nErrNo = 73218  
            SET @cErrMsg = rdt.rdtgetmessage( 73218, @cLangCode,'DSP') -- Invalid Ref#  
            EXEC rdt.rdtSetFocusField @nMobile, 1  
            GOTO Step_1_Fail  
         END  
  
         -- Validate all pickslip already scan in  
         IF EXISTS( SELECT 1  
            FROM dbo.LoadPlan LP WITH (NOLOCK)  
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey  
               LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey  
            WHERE LP.UserDefine10 = @cRefNo  
               AND [PI].ScanInDate IS NULL)  
         BEGIN  
            SET @nErrNo = 73219  
            SET @cErrMsg = rdt.rdtgetmessage( 73219, @cLangCode,'DSP') -- Not Scan-in  
            EXEC rdt.rdtSetFocusField @nMobile, 1  
            GOTO Step_1_Fail  
         END  
  
         -- Validate all pickslip already scan out  
         IF EXISTS( SELECT 1  
            FROM dbo.LoadPlan LP WITH (NOLOCK)  
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey  
               LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey  
            WHERE LP.UserDefine10 = @cRefNo  
               AND [PI].ScanOutDate IS NULL)  
         BEGIN  
            SET @nErrNo = 73220  
            SET @cErrMsg = rdt.rdtgetmessage( 73220, @cLangCode,'DSP') --Not Scan-out  
            EXEC rdt.rdtSetFocusField @nMobile, 1  
            GOTO Step_1_Fail  
         END  
      END  
  
      -- Pick Slip No  
      -- Pick Slip No
      IF @cPickSlipNo <> ''
      BEGIN
         -- Get pickheader info
         SELECT TOP 1
            @cChkPickSlipNo = PickHeaderKey
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @cPickSlipNo

         -- Validate pickslip no
         IF @cChkPickSlipNo = '' OR @cChkPickSlipNo IS NULL
         BEGIN
            SET @nErrNo = 73221
            SET @cErrMsg = rdt.rdtgetmessage( 73221, @cLangCode,'DSP') -- Invalid PS#
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_1_Fail
         END

         -- Get picking info
         SELECT TOP 1
            @dScanInDate = ScanInDate,
            @dScanOutDate = ScanOutDate
         FROM dbo.PickingInfo WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo

         -- Validate pickslip not scan in
         IF @dScanInDate IS NULL
         BEGIN
            SET @nErrNo = 73222
            SET @cErrMsg = rdt.rdtgetmessage( 73222, @cLangCode,'DSP') -- Not scan-in
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_1_Fail
         END

         --(yeekung01)
         IF @cSkipChkPSlipMustScanOut <> '1'
         BEGIN
            -- Validate pickslip not scan out
            IF @dScanOutDate IS NULL
            BEGIN
               SET @nErrNo = 73223
               SET @cErrMsg = rdt.rdtgetmessage( 73223, @cLangCode,'DSP') -- Not scan-out
               EXEC rdt.rdtSetFocusField @nMobile, 2
               GOTO Step_1_Fail
            END
         END
      END

  
      -- LoadKey  
      IF @cLoadKey <> '' AND @cLoadKey IS NOT NULL  
      BEGIN  
         -- Validate load plan status  
         IF NOT EXISTS( SELECT 1  
            FROM dbo.LoadPlan WITH (NOLOCK)  
            WHERE LoadKey = @cLoadKey  
               AND Status <= '9') -- 9=Closed  
         BEGIN  
            SET @nErrNo = 73224  
            SET @cErrMsg = rdt.rdtgetmessage( 73224, @cLangCode,'DSP') -- Invalid LoadKey  
            EXEC rdt.rdtSetFocusField @nMobile, 3  
            GOTO Step_1_Fail  
         END  
  
         -- Validate all pickslip already scan in  
         IF EXISTS( SELECT 1  
            FROM dbo.LoadPlan LP WITH (NOLOCK)  
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey  
               LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey  
            WHERE LP.LoadKey = @cLoadKey  
               AND [PI].ScanInDate IS NULL)  
         BEGIN  
            SET @nErrNo = 73225  
            SET @cErrMsg = rdt.rdtgetmessage( 73225, @cLangCode,'DSP') -- Not Scan-in  
            EXEC rdt.rdtSetFocusField @nMobile, 3  
            GOTO Step_1_Fail  
         END  
  
         -- Validate all pickslip already scan out  
         IF EXISTS( SELECT 1  
            FROM dbo.LoadPlan LP WITH (NOLOCK)  
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey  
               LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey  
            WHERE LP.LoadKey = @cLoadKey  
               AND [PI].ScanOutDate IS NULL)  
         BEGIN  
            SET @nErrNo = 73226  
            SET @cErrMsg = rdt.rdtgetmessage( 73226, @cLangCode,'DSP') --Not Scan-out  
            EXEC rdt.rdtSetFocusField @nMobile, 3  
            GOTO Step_1_Fail  
         END  
      END  
  
      -- OrderKey  
      IF @cOrderKey <> ''  
      BEGIN  
         -- Validate order status  
         IF NOT EXISTS( SELECT 1  
            FROM dbo.Orders WITH (NOLOCK)  
            WHERE OrderKey = @cOrderKey  
               AND StorerKey = @cStorer)  
         BEGIN  
            SET @nErrNo = 73227  
            SET @cErrMsg = rdt.rdtgetmessage( 73227, @cLangCode,'DSP') -- Inv OrderKey  
            EXEC rdt.rdtSetFocusField @nMobile, 4  
            GOTO Step_1_Fail  
         END  
  
         -- Validate pickslip already scan in  
         IF EXISTS( SELECT 1  
            FROM dbo.PickHeader PH WITH (NOLOCK)  
               LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey  
            WHERE PH.OrderKey = @cOrderKey  
               AND [PI].ScanInDate IS NULL)  
         BEGIN  
            SET @nErrNo = 73228  
            SET @cErrMsg = rdt.rdtgetmessage( 73228, @cLangCode,'DSP') -- Not Scan-in  
            EXEC rdt.rdtSetFocusField @nMobile, 4  
            GOTO Step_1_Fail  
         END  
  
         -- Validate pickslip already scan out  
         IF EXISTS( SELECT 1  
            FROM dbo.PickHeader PH WITH (NOLOCK)  
               LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey  
            WHERE PH.OrderKey = @cOrderKey  
               AND [PI].ScanOutDate IS NULL)  
         BEGIN  
            SET @nErrNo = 73229  
            SET @cErrMsg = rdt.rdtgetmessage( 73229, @cLangCode,'DSP') --Not Scan-out  
            EXEC rdt.rdtSetFocusField @nMobile, 4  
            GOTO Step_1_Fail  
         END  
      END  
  
      -- DropID  
      IF @cDropID <> '' -- (james02)  
      BEGIN  
         -- Validate drop ID status  
         IF @cPPACartonIDByPackDetailDropID = '1'  
         BEGIN  
            IF NOT EXISTS( SELECT 1  
               FROM dbo.PackHeader PH WITH (NOLOCK)  
                  INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
               WHERE PD.DropID = @cDropID  
                  AND PH.StorerKey = @cStorer)  
            BEGIN  
               SET @nErrNo = 73230  
               SET @cErrMsg = rdt.rdtgetmessage( 73230, @cLangCode,'DSP') -- Inv DropID  
               EXEC rdt.rdtSetFocusField @nMobile, 5  
               GOTO Step_1_Fail  
            END  
         END  
         ELSE  
         BEGIN   
            IF @cPPACartonIDByPackDetailLabelNo = '1'  
            BEGIN  
               IF NOT EXISTS( SELECT 1  
                  FROM dbo.PackHeader PH WITH (NOLOCK)  
                     INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
                  WHERE PD.LabelNo = @cDropID  
                     AND PH.StorerKey = @cStorer)  
               BEGIN  
                  SET @nErrNo = 73236  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Inv Carton ID  
                  EXEC rdt.rdtSetFocusField @nMobile, 5  
                  GOTO Step_1_Fail  
               END  
            END  
            ELSE   
            BEGIN  
               IF @cPPACartonIDByPickDetailCaseID = '1' -- (ChewKP01)   
               BEGIN  
                  IF NOT EXISTS( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)  
                     WHERE CaseID = @cDropID   
                     AND StorerKey = @cStorer)  
                  BEGIN  
                     SET @nErrNo = 73237  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Inv DropID  
                     EXEC rdt.rdtSetFocusField @nMobile, 5  
                     GOTO Step_1_Fail  
                  END  
               END  
               ELSE  
               BEGIN  
                  IF NOT EXISTS( SELECT 1  
                     FROM dbo.PickDetail WITH (NOLOCK)  
                     WHERE DropID = @cDropID  
                        AND StorerKey = @cStorer)  
                  BEGIN  
                     SET @nErrNo = 73231  
                     SET @cErrMsg = rdt.rdtgetmessage( 73231, @cLangCode,'DSP') -- Inv DropID  
                     EXEC rdt.rdtSetFocusField @nMobile, 5  
                     GOTO Step_1_Fail  
                  END  
               END  
            END  
         END  
      END  

      -- Pallet ID
      IF @cID <> '' AND @cID IS NOT NULL 
      BEGIN
         IF NOT EXISTS( SELECT 1
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND LLI.StorerKey = @cStorer
               AND LLI.ID = @cID
               AND LLI.QTY > 0)
         BEGIN
            SET @nErrNo = 73238
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Inv PalletID
            GOTO Step_1_Fail
         END
         
      END

      -- TaskDetailKey
      IF @cTaskDetailKey <> '' AND @cTaskDetailKey IS NOT NULL --SY01
      BEGIN

         IF NOT EXISTS (SELECT 1
                        FROM dbo.TaskDetail WITH (NOLOCK) 
                        WHERE TaskDetailKey = @cTaskDetailKey)
         BEGIN
            SET @nErrNo = 73239
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Inv TaskKey
            GOTO Step_1_Fail
         END
      END

      -- Extended validate  
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID,@cID,@cTaskdetailKey,   
                 @cSKU, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
            SET @cSQLParam =  
               '@nMobile      INT,       ' +  
               '@nFunc        INT,       ' +  
               '@cLangCode    NVARCHAR( 3),  ' +  
               '@nStep        INT,       ' +  
               '@nInputKey    INT,       '     +  
               '@cStorerKey   NVARCHAR( 15), ' +  
               '@cRefNo       NVARCHAR( 10), ' +  
               '@cPickSlipNo  NVARCHAR( 10), ' +  
               '@cLoadKey     NVARCHAR( 10), ' +  
               '@cOrderKey    NVARCHAR( 10), ' +  
               '@cDropID      NVARCHAR( 20), ' +  
               '@cID          NVARCHAR( 18), ' +
               '@cTaskdetailKey NVARCHAR( 10), ' +
               '@cSKU         NVARCHAR( 20), ' +  
               '@cOption      NVARCHAR( 1),  ' +  
               '@nErrNo       INT OUTPUT,  ' +  
               '@cErrMsg      NVARCHAR( 20) OUTPUT'  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID,@cID,@cTaskdetailKey,   
               @cSKU, '', @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO STEP_1_Fail  
         END  
      END  
  
    -- Prepare next screen var
      SET @cSKU = ''

      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadKey
      SET @cOutField04 = @cOrderKey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = @cSKU
      SET @cOutField07 = @cID
      SET @cOutField08 = @cTaskDetailKey	
  
      -- Go to next screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
        
      -- (james03)  
      IF @cFlowThruStepSKU = '1'  
      BEGIN  
         SET @cInField06 = ''  
         GOTO Step_2   
      END  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
      SET @cOutField01 = ''  
   END  
   GOTO Quit  
  
   Step_1_Fail:  
   BEGIN  
      -- Reset this screen var
      SET @cRefNo = ''
      SET @cPickSlipNo = ''
      SET @cLoadKey = ''
      SET @cOrderKey = ''
      SET @cDropID = ''

      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadKey
      SET @cOutField04 = @cOrderKey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = @cSKU
      SET @cOutField07 = @cID
      SET @cOutField08 = @cTaskDetailKey	
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 2. Scn = 2831  
   SKU (field06, input)  
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Screen mapping  
      SET @cSKU = ISNULL( @cInField06, '') -- SKU  
  
      -- SKU  
      IF @cSKU <> ''  
      BEGIN  
         -- Validate SKU exists  
         EXEC dbo.nspg_GETSKU @cStorer, @cSKU OUTPUT, @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT  
         IF @b_success = 0  
         BEGIN  
            SET @nErrNo = 73232  
            SET @cErrMsg = rdt.rdtgetmessage( 73232, @cLangCode,'DSP') -- Invalid SKU  
            EXEC rdt.rdtSetFocusField @nMobile, 6  
            GOTO Step_2_Fail  
         END  
  
         -- Get SKU details  
         SELECT  
            @cSKUDescr = SKU.DESCR,  
            @cStyle = SKU.Style,  
            @cColor = SKU.Color,  
            @cSize = SKU.Size  
         FROM dbo.SKU SKU WITH (NOLOCK)  
         WHERE SKU.StorerKey = @cStorer  
            AND SKU.SKU = @cSKU  
      END  
      ELSE  
      BEGIN  
         SET @cSKUDescr = ''  
         SET @cStyle = ''  
         SET @cColor = ''  
         SET @cSize = ''  
      END  
  
      -- Prepare next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField04 = @cStyle
      SET @cOutField05 = @cColor
      SET @cOutField06 = @cSize
  
      -- Go to next screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      -- Reset prev screen var
      SET @cRefNo = ''
      SET @cPickSlipNo = ''
      SET @cLoadKey = ''
      SET @cOrderKey = ''
      SET @cDropID = ''

      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadKey
      SET @cOutField04 = @cOrderKey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = @cSKU
      SET @cOutField07 = @cID
      SET @cOutField08 = @cTaskDetailKey	
  
      -- Go to prev screen  
      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
   GOTO Quit  
  
   Step_2_Fail:  
   BEGIN  
      SET @cOutField06 = ''  
      SET @cSKU = ''  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 3. Scn = 2832.  
********************************************************************************/  
Step_3:  
BEGIN  
   IF @nInputKey = 1 -- Yes OR Send  
   BEGIN  
      -- Set next screen var  
      DECLARE @cOption NVARCHAR( 1)  
      SET @cOption = ''  
      SET @cOutField01 = @cOption  
  
      -- Go to next screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  
  
   IF @nInputKey = 0 -- Esc OR No  
   BEGIN  
      IF @cFlowThruStepSKU = '1'  
      BEGIN  
         -- Reset prev screen var  
         SET @cRefNo = ''  
         SET @cPickSlipNo = ''  
         SET @cLoadKey = ''  
         SET @cOrderKey = ''  
         SET @cDropID = ''  
  
         SET @cOutField01 = @cRefNo
         SET @cOutField02 = @cPickSlipNo
         SET @cOutField03 = @cLoadKey
         SET @cOutField04 = @cOrderKey
         SET @cOutField05 = @cDropID
         SET @cOutField06 = @cSKU
         SET @cOutField07 = @cID
         SET @cOutField08 = @cTaskDetailKey	 
  
         -- Go to prev screen  
         SET @nScn = @nScn - 2  
         SET @nStep = @nStep - 2  
      END  
      ELSE  
      BEGIN  
         -- Reset prev screen var
         SET @cSKU = ''

         SET @cOutField01 = @cRefNo
         SET @cOutField02 = @cPickSlipNo
         SET @cOutField03 = @cLoadKey
         SET @cOutField04 = @cOrderKey
         SET @cOutField05 = @cDropID
         SET @cOutField06 = @cSKU
         SET @cOutField07 = @cID
         SET @cOutField08 = @cTaskDetailKey	

         -- Go to prev screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 4. Scn = 2833. Option screen  
   Reset PPA QTY?  
   1=YES  
   2=NO  
   OPTION (field01, input)  
********************************************************************************/  
Step_4:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Screen mapping  
      SET @cOption = @cInField01  
  
      -- Validate blank  
      IF @cOption = '' OR @cOption IS NULL  
      BEGIN  
         SET @nErrNo = 73233  
         SET @cErrMsg = rdt.rdtgetmessage( 73233, @cLangCode, 'DSP') --Option needed  
         GOTO Step_4_Fail  
      END  
  
      -- Validate option  
      IF @cOption <> '1' AND @cOption <> '2'  
      BEGIN  
         SET @nErrNo = 73234  
         SET @cErrMsg = rdt.rdtgetmessage( 73234, @cLangCode, 'DSP') --Invalid option  
         GOTO Step_4_Fail  
      END  
  
      IF @cOption = '2'  
      BEGIN  
         -- Prepare prev screen var  
         SET @cOutField01 = @cRefNo  
         SET @cOutField02 = @cPickSlipNo  
         SET @cOutField03 = @cLoadKey  
         SET @cOutField04 = @cOrderKey  
         SET @cOutField05 = @cDropID  
         SET @cOutField07 = SUBSTRING( @cSKUDescr,  1, 20)  
         SET @cOutField08 = SUBSTRING( @cSKUDescr, 21, 20)  
         SET @cOutField09 = @cStyle  
         SET @cOutField10 = @cColor  
         SET @cOutField11 = @cSize  
  
         -- Go to prev screen  
         SET @nScn = @nScn - 1  
         SET @nStep = @nStep - 1  
  
         GOTO Quit  
      END  
  
     --Remove hardcode change to standard confirm SP
      EXEC  RDT.rdt_PostPickAudit_Reset_Confirm
         @nMobile         = @nMobile       ,
         @nFunc           = @nFunc         ,
         @cLangCode       = @cLangCode     ,
         @nStep           = @nStep         ,
         @nInputKey       = @nInputKey     ,
         @cStorerKey      = @cStorer       ,
         @cRefNo          = @cRefNo        ,
         @cPickSlipNo     = @cPickSlipNo   ,
         @cLoadKey        = @cLoadKey      ,
         @cOrderKey       = @cOrderKey     ,
         @cDropID         = @cDropID       ,
         @cID             = @cID           ,
         @cTaskdetailKey  = @cTaskdetailKey,
         @cSKU            = @cSKU          ,
         @cOption         = @cOption       ,
         @nErrNo          = @nErrNo       OUTPUT,
         @cErrMsg         = @cErrMsg      OUTPUT

  
      -- Extended update  
      IF @cExtendedUpdateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID,@cID,@cTaskdetailKey,   
                 @cSKU, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
            SET @cSQLParam =  
               '@nMobile      INT,       ' +  
               '@nFunc        INT,       ' +  
               '@cLangCode    NVARCHAR( 3),  ' +  
               '@nStep        INT,       ' +  
               '@nInputKey    INT,       '     +  
               '@cStorerKey   NVARCHAR( 15), ' +  
               '@cRefNo       NVARCHAR( 10), ' +  
               '@cPickSlipNo  NVARCHAR( 10), ' +  
               '@cLoadKey     NVARCHAR( 10), ' +  
               '@cOrderKey    NVARCHAR( 10), ' +  
               '@cDropID      NVARCHAR( 20), ' + 
               '@cID          NVARCHAR( 18), ' +
               '@cTaskdetailKey NVARCHAR( 10), ' +
               '@cSKU         NVARCHAR( 20), ' +  
               '@cOption      NVARCHAR( 1),  ' +  
               '@nErrNo       INT OUTPUT,  ' +  
               '@cErrMsg      NVARCHAR( 20) OUTPUT'  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID,@cID,@cTaskdetailKey,   
               @cSKU, '', @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Step_4_Fail  
         END  
      END  
  

      -- Init screen var
      SET @cRefNo = ''
      SET @cPickSlipNo = ''
      SET @cLoadKey = ''
      SET @cOrderKey = ''
      SET @cDropID = ''
      SET @cSKU = ''
      SET @cSKUDescr = ''
      SET @cStyle = ''
      SET @cColor = ''
      SET @cSize = ''

      -- Prepare next screen var
      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadKey
      SET @cOutField04 = @cOrderKey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = @cID
      SET @cOutField07 = @cTaskDetailKey
  
      -- Set screen focus  
      EXEC rdt.rdtSetFocusField @nMobile, 1 --RefNo  
  
      -- Go to prev screen  
      SET @nScn = @nScn - 3  
      SET @nStep = @nStep - 3  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      -- Prepare next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField04 = @cStyle
      SET @cOutField05 = @cColor
      SET @cOutField06 = @cSize
  
      -- Go to prev screen  
      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
   GOTO Quit  
  
   Step_4_Fail:  
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
  
      StorerKey = @cStorer,  
      Facility  = @cFacility,  
      Printer   = @cPrinter,  
      -- UserName  = @cUserName,  
  
      V_SKU     = @cSKU,  
      V_SKUDescr= @cSKUDescr,  
      V_LoadKey = @cLoadKey,  
      V_PickSlipNo = @cPickSlipNo,
      V_TaskDetailKey = @cTaskDetailKey, 
      V_ID         = @cID, 
  
      V_String1 = @cRefNo,  
      V_String2 = @cOrderKey,  
      V_String3 = @cDropID,  
      V_String4 = @cStyle,  
      V_String5 = @cColor,  
      V_String6 = @cSize,  
      V_String7 = @cPPACartonIDByPackDetailDropID,  
      V_String8 = @cPPACartonIDByPackDetailLabelNo,  
      V_String9 = @cPPACartonIDByPickDetailCaseID,  
      V_String10 = @cExtendedUpdateSP,  
      V_String11 = @cFlowThruStepSKU,  
      V_String12 = @cExtendedValidateSP,
      V_String13 = @cSkipChkPSlipMustScanOut,
        
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
      I_Field15 = @cInField15,  O_Field15 = @cOutField15  
  
   WHERE Mobile = @nMobile  
END  

GO