SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_PostPickAudit_Inquiry                        */
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
/* 26-05-2011 1.0  Ung        Created                                   */
/* 12-01-2012 1.1  Leong      SOS# 233768 - Convert char to int         */
/* 22-12-2015 1.2  Leong      SOS359525 - Revise variable size.         */
/* 30-09-2016 1.3  Ung        Performance tuning                        */
/* 04-11-2016 1.4  ChewKP     WMS-611 Add RDT Config                    */
/*                            "PPACartonIDByPickDetailCaseID"           */
/*                            "DisplayStyleColorSize"                   */
/*                            Support User Preferred UOM (ChewKP01)     */
/* 07-11-2018 1.5  Gan        Performance tuning                        */
/* 05-12-2018 1.6  James      WMS7191 - Add support filter by           */
/*                            packdetail.labelno (james01)              */
/* 11-08-2020 1.7  James      INC1244432 - Bug fix (james02)            */
/* 09-08-2022 1.8  YeeKung    Add Extededinfosp (yeekung01)             */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_PostPickAudit_Inquiry] (
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

   @cChkPickSlipNo  NVARCHAR( 10),
   @dScanInDate     DATETIME,
   @dScanOutDate    DATETIME,
   @cTally          NVARCHAR( 1) ,
   @nTotSKU_Pick    INT,
   @nTotQTY_Pick    INT,
   @nTotSKU_PPA     INT,
   @nTotQTY_PPA     INT,
   @nQTY_Pick       INT,
   @nQTY_PPA        INT,
   @cNextSKU        NVARCHAR( 20),
   @cStyle          NVARCHAR( 20),
   @cColor          NVARCHAR( 10),
   @cSize           NVARCHAR( 10), -- SOS359525
   @cSQL            NVARCHAR(4000),
   @cSQLParam       NVARCHAR(MAX)

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

   @cUOM            NVARCHAR( 10),
   @cSKU            NVARCHAR( 20),
   @cSKUDescr       NVARCHAR( 60),
   @cLoadKey        NVARCHAR( 10),
   @cPickSlipNo     NVARCHAR( 10),

   @cRefNo          NVARCHAR( 10),
   @cOrderKey       NVARCHAR( 10),
   @cDropID         NVARCHAR( 20), -- SOS359525
   @cCurrentSKU     NVARCHAR( 20),
   @nRec            INT,
   @nTotRec         INT,

   @cPPACartonIDByPackDetailDropID NVARCHAR( 1),
   @cPPACartonIDByPickDetailCaseID NVARCHAR( 1), -- (ChewKP01) 
   @cSKUInfo                       NVARCHAR(20), -- (ChewKP01) 
   @nPUOM_Div                      INT, -- UOM divider    
   @cPUOM_Desc                     NVARCHAR( 5),    
   @cMUOM_Desc                     NVARCHAR( 5),    
   @nPQTY                          INT, -- Preferred UOM QTY    
   @nMQTY                          INT, -- Master unit QTY    
   @nPQTYPPA                       INT, -- Preferred UOM QTY    
   @nMQTYPPA                       INT, -- Master unit QTY  
   @cDispStyleColorSize            NVARCHAR(1) , 
   @cPUOM                          NVARCHAR( 10),    
   @cPPACartonIDByPackDetailLabelNo NVARCHAR( 1),
   @cExtendedInfo                   NVARCHAR( 20), --(yeekung01)
   @cExtendedInfoSP                 NVARCHAR( 20),  --(yeekung01)

   @tExtInfo                        VARIABLETABLE, --(yeekung01)

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

   @cUOM       = V_UOM,
   @cSKU       = V_SKU,
   @cSKUDescr  = V_SKUDescr,
   @cLoadKey   = V_LoadKey,
   @cPickSlipNo = V_PickSlipNo,

   @nRec        = V_Integer1,
   @nTotRec     = V_Integer2, 
   
   @cRefNo      = V_String1,
   @cOrderKey   = V_String2,
   @cDropID     = V_String3,
   @cCurrentSKU = V_String4,
--   @nRec        = CASE WHEN rdt.rdtIsValidQTY(LEFT(V_String5, 5), 0) = 1 THEN LEFT(V_String5, 5) ELSE 0 END, -- SOS# 233768
--   @nTotRec     = CASE WHEN rdt.rdtIsValidQTY(LEFT(V_String6, 5), 0) = 1 THEN LEFT(V_String6, 5) ELSE 0 END, -- SOS# 233768

   @cPPACartonIDByPackDetailDropID = V_String7,
   @cPPACartonIDByPickDetailCaseID = V_String8,
   @cDispStyleColorSize            = V_String9,
   @cPPACartonIDByPackDetailLabelNo= V_String10,
   @cPUOM       = V_String11,
   @cExtendedInfoSP                 = V_String12, --(yeekung01)

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

IF @nFunc in (849)
BEGIN
   IF @nStep = 0 GOTO Step_0  -- Menu. Func = 849
   IF @nStep = 1 GOTO Step_1  -- Scn = 2840. RefNo, PickSlipNo, LoadKey, OrderKey, CartonID
   IF @nStep = 2 GOTO Step_2  -- Scn = 2841. RefNo, PickSlipNo, LoadKey, OrderKey, CartonID, SKU
   IF @nStep = 3 GOTO Step_3  -- Scn = 2842. Total SKU, QTY for Pick and PPA
   IF @nStep = 4 GOTO Step_4  -- Scn = 2843. Total SKU, QTY for Pick and PPA and SKU details
END
RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Func = 849
********************************************************************************/
Step_0:
BEGIN
   -- Get storer config
   SET @cPPACartonIDByPackDetailDropID = rdt.rdtGetConfig( 0, 'PPACartonIDByPackDetailDropID', @cStorer)
   SET @cPPACartonIDByPickDetailCaseID = rdt.rdtGetConfig( 0, 'PPACartonIDByPickDetailCaseID', @cStorer)  -- (ChewKP01) 
   SET @cDispStyleColorSize = rdt.rdtGetConfig( @nFunc, 'DispStyleColorSize', @cStorer)  -- (ChewKP01) 
   SET @cPPACartonIDByPackDetailLabelNo = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPackDetailLabelNo', @cStorer)   -- (james01)

   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorer)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
   JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

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
   SET @cOutField06 = @cSKU

   -- Go to next screen
   SET @nScn = 2840
   SET @nStep = 1

END
GOTO Quit

/********************************************************************************
Step 1. Scn = 2840
   PickSlipNo (field01, input)
   RefNo      (field02, input)
   LoadKey    (field03, input)
   OrderKey   (field04, input)
   Carton ID  (field05, input)
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

      -- Validate blank
      IF @cRefNo      = '' AND
         @cPickSlipNo = '' AND
         @cLoadKey    = '' AND
         @cOrderKey   = '' AND
         @cDropID     = ''
      BEGIN
         SET @nErrNo = 73251
         SET @cErrMsg = rdt.rdtgetmessage( 73251, @cLangCode,'DSP') -- Value required!
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
      IF @i > 1
      BEGIN
         SET @nErrNo = 73252
         SET @cErrMsg = rdt.rdtgetmessage( 73252, @cLangCode,'DSP') -- Key-in either 1
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
            SET @nErrNo = 73253
            SET @cErrMsg = rdt.rdtgetmessage( 73253, @cLangCode,'DSP') -- Invalid Ref#
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
            SET @nErrNo = 73254
            SET @cErrMsg = rdt.rdtgetmessage( 73254, @cLangCode,'DSP') -- Not Scan-in
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
            SET @nErrNo = 73255
            SET @cErrMsg = rdt.rdtgetmessage( 73255, @cLangCode,'DSP') --Not Scan-out
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END
      END

      -- Pick Slip No
      IF @cPickSlipNo <> ''
      BEGIN
         SET @cOrderKey = ''  -- (james02)
         -- Get pickheader info
         SELECT TOP 1
            @cChkPickSlipNo = PickHeaderKey,
            @cOrderKey = OrderKey
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @cPickSlipNo

         -- Validate pickslip no
         IF @cChkPickSlipNo = '' OR @cChkPickSlipNo IS NULL
         BEGIN
            SET @nErrNo = 73256
            SET @cErrMsg = rdt.rdtgetmessage( 73256, @cLangCode,'DSP') -- Invalid PS#
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
            SET @nErrNo = 73257
            SET @cErrMsg = rdt.rdtgetmessage( 73257, @cLangCode,'DSP') -- Not scan-in
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_1_Fail
         END

         -- Validate pickslip not scan out
         IF @dScanOutDate IS NULL
         BEGIN
            SET @nErrNo = 73258
            SET @cErrMsg = rdt.rdtgetmessage( 73258, @cLangCode,'DSP') -- Not scan-out
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_1_Fail
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
            SET @nErrNo = 73259
            SET @cErrMsg = rdt.rdtgetmessage( 73259, @cLangCode,'DSP') -- Invalid LoadKey
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
            SET @nErrNo = 73260
            SET @cErrMsg = rdt.rdtgetmessage( 73260, @cLangCode,'DSP') -- Not Scan-in
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
            SET @nErrNo = 73261
            SET @cErrMsg = rdt.rdtgetmessage( 73261, @cLangCode,'DSP') --Not Scan-out
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
            SET @nErrNo = 73262
            SET @cErrMsg = rdt.rdtgetmessage( 73262, @cLangCode,'DSP') -- Inv OrderKey
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
            SET @nErrNo = 73263
            SET @cErrMsg = rdt.rdtgetmessage( 73263, @cLangCode,'DSP') -- Not Scan-in
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
            SET @nErrNo = 73264
            SET @cErrMsg = rdt.rdtgetmessage( 73264, @cLangCode,'DSP') --Not Scan-out
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
               SET @nErrNo = 73265
               SET @cErrMsg = rdt.rdtgetmessage( 73265, @cLangCode,'DSP') -- Inv DropID
               EXEC rdt.rdtSetFocusField @nMobile, 5
               GOTO Step_1_Fail
            END
         END
         ELSE
         BEGIN
            IF @cPPACartonIDByPackDetailLabelNo = '1' -- (james01)
            BEGIN
               IF NOT EXISTS( SELECT 1
                  FROM dbo.PackHeader PH WITH (NOLOCK)
                     INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
                  WHERE PD.LabelNo = @cDropID
                     AND PH.StorerKey = @cStorer)
               BEGIN
                  SET @nErrNo = 73270
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
                     SET @nErrNo = 73269
                     SET @cErrMsg = rdt.rdtgetmessage( 73269, @cLangCode,'DSP') -- Inv DropID
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
                     SET @nErrNo = 73266
                     SET @cErrMsg = rdt.rdtgetmessage( 73266, @cLangCode,'DSP') -- Inv DropID
                     EXEC rdt.rdtSetFocusField @nMobile, 5
                     GOTO Step_1_Fail
                  END
               END
            END
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

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
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
   END
END
GOTO Quit

/********************************************************************************
Step 2. Scn = 2841
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
            SET @nErrNo = 73267
            SET @cErrMsg = rdt.rdtgetmessage( 73267, @cLangCode,'DSP') -- Invalid SKU
            EXEC rdt.rdtSetFocusField @nMobile, 6
            GOTO Step_2_Fail
         END
      END

      -- Get Pick vs PPA stat
      SET @cCurrentSKU = ''
      EXECUTE rdt.rdt_PostPickAudit_Inquiry_GetStat @nMobile, @nFunc,
         @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @cStorer, @cUOM, @cCurrentSKU, @cPPACartonIDByPackDetailDropID,
         @cTally       OUTPUT,
         @nTotSKU_Pick OUTPUT,
         @nTotQTY_Pick OUTPUT,
         @nTotSKU_PPA  OUTPUT,
         @nTotQTY_PPA  OUTPUT,
         @nQTY_Pick    OUTPUT,
         @nQTY_PPA     OUTPUT,
         @cNextSKU     OUTPUT,
         @cSKUDescr    OUTPUT,
         @cSKUInfo     OUTPUT,
         --@cColor       OUTPUT,
         --@cSize        OUTPUT,
         @nRec         OUTPUT,
         @nTotRec      OUTPUT
      SET @cCurrentSKU = @cNextSKU
      
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tExtInfo (Variable, Value) VALUES 
               ('@cRefNo',       @cRefNo), 
               ('@cPickSlipNo',  @cPickSlipNo), 
               ('@cLoadKey',     @cLoadKey), 
               ('@cOrderKey',    @cOrderKey), 
               ('@cDropID',      @cDropID), 
               ('@cSKU',         @cCurrentSKU), 
               ('@cTally',       @cTally),
               ('@nTotSKU_Pick',  CAST( @nTotSKU_Pick AS NVARCHAR( 10))), 
               ('@nTotQTY_Pick',  CAST( @nTotQTY_Pick AS NVARCHAR( 10))), 
               ('@nTotSKU_PPA',   CAST( @nTotSKU_PPA AS NVARCHAR( 10))), 
               ('@nTotQTY_PPA',   CAST( @nTotQTY_PPA AS NVARCHAR( 10))), 
               ('@nQTY_Pick',     CAST( @nQTY_Pick AS NVARCHAR( 10))),
               ('@cSKUInfo',      CAST( @cSKUInfo AS NVARCHAR( 20))), 
               ('@nRec',          CAST( @nRec AS NVARCHAR( 20))), 
               ('@nTotRec',       CAST( @nTotRec AS NVARCHAR( 20)))
            
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @tExtInfo, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tExtInfo       VariableTable READONLY, ' + 
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer, @tExtInfo, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         
            SET @cOutField15 = @cExtendedInfo
         END
      END
      
      
      -- (ChewKP01) 
      -- Get Pack info    
      SELECT    
         @cMUOM_Desc = Pack.PackUOM3,
         @cPUOM_Desc =    
            CASE @cPUOM    
               WHEN '2' THEN Pack.PackUOM1 -- Case    
               WHEN '3' THEN Pack.PackUOM2 -- Inner pack    
               WHEN '6' THEN Pack.PackUOM3 -- Master unit    
               WHEN '1' THEN Pack.PackUOM4 -- Pallet    
               WHEN '4' THEN Pack.PackUOM8 -- Other unit 1    
               WHEN '5' THEN Pack.PackUOM9 -- Other unit 2    
            END,    
         @nPUOM_Div = CAST( IsNULL(    
            CASE @cPUOM    
               WHEN '2' THEN Pack.CaseCNT    
               WHEN '3' THEN Pack.InnerPack    
               WHEN '6' THEN Pack.QTY    
               WHEN '1' THEN Pack.Pallet    
               WHEN '4' THEN Pack.OtherUnit1    
               WHEN '5' THEN Pack.OtherUnit2    
            END, 1) AS INT)    
      FROM dbo.SKU SKU WITH (NOLOCK)    
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)    
      WHERE SKU.StorerKey = @cStorer    
         AND ( ( ISNULL( @cNextSKU, '') <> '' AND SKU.SKU = @cNextSKU ) OR ( ISNULL( @cSKU, '') <> '' AND SKU.SKU = @cSKU))
         
      -- Convert to prefer UOM QTY    
      IF @cPUOM = '6' OR -- When preferred UOM = master unit    
         @nPUOM_Div = 0  -- UOM not setup    
      BEGIN    
         SET @cPUOM_Desc = ''    
         SET @nPQTY = 0    
         SET @nMQTY = @nQTY_Pick    
         SET @nPQTYPPA = 0    
         SET @nMQTYPPA = @nQTY_PPA    
         SET @cOutField11 = '1:1            ' + @cMUOM_Desc
         SET @cOutField05 = ''
         SET @cOutField12 = ''
      END    
      ELSE    
      BEGIN    
         SET @nPQTY = @nQTY_Pick / @nPUOM_Div  -- Calc QTY in preferred UOM    
         SET @nMQTY = @nQTY_Pick % @nPUOM_Div  -- Calc the remaining in master unit    
         SET @nPQTYPPA = @nQTY_PPA / @nPUOM_Div  -- Calc QTY in preferred UOM    
         SET @nMQTYPPA = @nQTY_PPA % @nPUOM_Div  -- Calc the remaining in master unit    
         SET @cOutField11 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + RIGHT('     ' + CAST(@cPUOM_Desc AS VARCHAR(5)), 5) + ' ' + @cMUOM_Desc   
         SET @cOutField05 = @nPQTY
         SET @cOutField12 = @nPQTYPPA
      END       
      
      -- Prepare next screen var
      SET @cOutField01 = @nTotSKU_Pick
      SET @cOutField02 = @nTotQTY_Pick
      SET @cOutField03 = @nTotSKU_PPA
      SET @cOutField04 = @nTotQTY_PPA
      
      SET @cOutField06 = @nMQTY
      SET @cOutField14 = @nMQTYPPA
      
      SET @cOutField07 = @cCurrentSKU
      SET @cOutField08 = SUBSTRING( @cSKUDescr,  1, 20)
      SET @cOutField09 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField10 = CASE WHEN @cSKUInfo <> '' THEN @cSKUInfo ELSE '' END
      --SET @cOutField11 = @cColor
      --SET @cOutField12 = @cSize
      SET @cOutField13 = CAST( @nRec AS NVARCHAR( 5)) + '/' + CAST( @nTotRec AS NVARCHAR( 5))

      IF @cTally = 'Y'
      BEGIN
         -- Go to tally screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         -- Go to not tally screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      IF @cRefNo      <> '' EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE
      IF @cPickSlipNo <> '' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE
      IF @cLoadKey    <> '' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE
      IF @cOrderKey   <> '' EXEC rdt.rdtSetFocusField @nMobile, 4 ELSE
      IF @cDropID     <> '' EXEC rdt.rdtSetFocusField @nMobile, 5 

      -- Reset prev screen var
      SET @cRefNo = ''
      SET @cPickSlipNo = ''
      SET @cLoadKey = ''
      SET @cOrderKey = ''
      SET @cDropID = ''

      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''

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
Step 3. Scn = 2842. Total SKU, QTY for PICK and PPA
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes OR Send
   BEGIN
      -- Reamin in current screen
      SET @nScn = @nScn
      SET @nStep = @nStep
   END

   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      -- Reset prev screen var
      SET @cSKU = ''
      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadKey
      SET @cOutField04 = @cOrderKey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = @cSKU

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/********************************************************************************
Step 4. Scn = 2843. Total SKU, QTY for PICK and PPA

********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      IF @nRec = @nTotRec
      BEGIN
         SET @nErrNo = 73268
         SET @cErrMsg = rdt.rdtgetmessage( 73268, @cLangCode,'DSP') --Last record
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Step_4_Fail
      END

      -- Get Pick vs PPA stat
      EXECUTE rdt.rdt_PostPickAudit_Inquiry_GetStat @nMobile, @nFunc,
         @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @cStorer, @cUOM, @cCurrentSKU, @cPPACartonIDByPackDetailDropID,
         @cTally       OUTPUT,
         @nTotSKU_Pick OUTPUT,
         @nTotQTY_Pick OUTPUT,
         @nTotSKU_PPA  OUTPUT,
         @nTotQTY_PPA  OUTPUT,
         @nQTY_Pick    OUTPUT,
         @nQTY_PPA     OUTPUT,
         @cNextSKU     OUTPUT,
         @cSKUDescr    OUTPUT,
         @cSKUInfo     OUTPUT,
         --@cColor       OUTPUT,
         --@cSize        OUTPUT,
         @nRec         OUTPUT,
         @nTotRec      OUTPUT
         
      SET @cCurrentSKU = @cNextSKU

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tExtInfo (Variable, Value) VALUES 
               ('@cRefNo',       @cRefNo), 
               ('@cPickSlipNo',  @cPickSlipNo), 
               ('@cLoadKey',     @cLoadKey), 
               ('@cOrderKey',    @cOrderKey), 
               ('@cDropID',      @cDropID), 
               ('@cSKU',         @cCurrentSKU), 
               ('@cTally',       @cTally),
               ('@nTotSKU_Pick',  CAST( @nTotSKU_Pick AS NVARCHAR( 10))), 
               ('@nTotQTY_Pick',  CAST( @nTotQTY_Pick AS NVARCHAR( 10))), 
               ('@nTotSKU_PPA',   CAST( @nTotSKU_PPA AS NVARCHAR( 10))), 
               ('@nTotQTY_PPA',   CAST( @nTotQTY_PPA AS NVARCHAR( 10))), 
               ('@nQTY_Pick',     CAST( @nQTY_Pick AS NVARCHAR( 10))),
               ('@cSKUInfo',      CAST( @cSKUInfo AS NVARCHAR( 20))), 
               ('@nRec',          CAST( @nRec AS NVARCHAR( 20))), 
               ('@nTotRec',       CAST( @nTotRec AS NVARCHAR( 20)))
            
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @tExtInfo, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tExtInfo       VariableTable READONLY, ' + 
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer, @tExtInfo, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         
            SET @cOutField15 = @cExtendedInfo
         END
      END
      

      SELECT    
         @cMUOM_Desc = Pack.PackUOM3,
         @cPUOM_Desc =    
            CASE @cPUOM    
               WHEN '2' THEN Pack.PackUOM1 -- Case    
               WHEN '3' THEN Pack.PackUOM2 -- Inner pack    
               WHEN '6' THEN Pack.PackUOM3 -- Master unit    
               WHEN '1' THEN Pack.PackUOM4 -- Pallet    
               WHEN '4' THEN Pack.PackUOM8 -- Other unit 1    
               WHEN '5' THEN Pack.PackUOM9 -- Other unit 2    
            END,    
         @nPUOM_Div = CAST( IsNULL(    
            CASE @cPUOM    
               WHEN '2' THEN Pack.CaseCNT    
               WHEN '3' THEN Pack.InnerPack    
               WHEN '6' THEN Pack.QTY    
               WHEN '1' THEN Pack.Pallet    
               WHEN '4' THEN Pack.OtherUnit1    
               WHEN '5' THEN Pack.OtherUnit2    
            END, 1) AS INT)    
      FROM dbo.SKU SKU WITH (NOLOCK)    
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)    
      WHERE SKU.StorerKey = @cStorer    
         AND ( ( ISNULL( @cNextSKU, '') <> '' AND SKU.SKU = @cNextSKU ) OR ( ISNULL( @cSKU, '') <> '' AND SKU.SKU = @cSKU))
         
      -- Convert to prefer UOM QTY    
      IF @cPUOM = '6' OR -- When preferred UOM = master unit    
         @nPUOM_Div = 0  -- UOM not setup    
      BEGIN    
         SET @cPUOM_Desc = ''    
         SET @nPQTY = 0    
         SET @nMQTY = @nQTY_Pick    
         SET @nPQTYPPA = 0    
         SET @nMQTYPPA = @nQTY_PPA    
         SET @cOutField11 = '1:1            ' + @cMUOM_Desc
         SET @cOutField05 = ''
         SET @cOutField12 = ''
      END    
      ELSE    
      BEGIN    
         SET @nPQTY = @nQTY_Pick / @nPUOM_Div  -- Calc QTY in preferred UOM    
         SET @nMQTY = @nQTY_Pick % @nPUOM_Div  -- Calc the remaining in master unit    
         SET @nPQTYPPA = @nQTY_PPA / @nPUOM_Div  -- Calc QTY in preferred UOM    
         SET @nMQTYPPA = @nQTY_PPA % @nPUOM_Div  -- Calc the remaining in master unit    
         SET @cOutField11 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + RIGHT('     ' + CAST(@cPUOM_Desc AS VARCHAR(5)), 5) + ' ' + @cMUOM_Desc   
         SET @cOutField05 = @nPQTY
         SET @cOutField12 = @nPQTYPPA
      END       
      
      -- Prepare next screen var
      SET @cOutField01 = @nTotSKU_Pick
      SET @cOutField02 = @nTotQTY_Pick
      SET @cOutField03 = @nTotSKU_PPA
      SET @cOutField04 = @nTotQTY_PPA
      
      SET @cOutField06 = @nMQTY
      SET @cOutField14 = @nMQTYPPA
      
      SET @cOutField07 = @cCurrentSKU
      SET @cOutField08 = SUBSTRING( @cSKUDescr,  1, 20)
      SET @cOutField09 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField10 = CASE WHEN @cSKUInfo <> '' THEN @cSKUInfo ELSE '' END
      --SET @cOutField11 = @cColor
      --SET @cOutField12 = @cSize
      SET @cOutField13 = CAST( @nRec AS NVARCHAR( 5)) + '/' + CAST( @nTotRec AS NVARCHAR( 5))

      -- Remain in current screen
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cSKU = ''
      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadKey
      SET @cOutField04 = @cOrderKey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = @cSKU

      -- Go to prev screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
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

      V_UOM     = @cUOM,
      V_SKU     = @cSKU,
      V_SKUDescr= @cSKUDescr,
      V_LoadKey = @cLoadKey,
      V_PickSlipNo = @cPickSlipNo,

      V_Integer1 = @nRec,
      V_Integer2 = @nTotRec,

      V_String1 = @cRefNo,
      V_String2 = @cOrderKey,
      V_String3 = @cDropID,
      V_String4 = @cCurrentSKU,
--      V_String5 = @nRec,
--      V_String6 = @nTotRec,
      V_String7 = @cPPACartonIDByPackDetailDropID,
      V_String8 = @cPPACartonIDByPickDetailCaseID,
      V_String9 = @cDispStyleColorSize,
      V_String10= @cPPACartonIDByPackDetailLabelNo,
      V_String11= @cPUOM,
      V_String12= @cExtendedInfoSP,

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