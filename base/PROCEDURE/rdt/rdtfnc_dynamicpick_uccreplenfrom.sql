SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: UCC Replenishment From (Dynamic Pick) SOS87843              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2007-10-16 1.0  FKLIM      Created                                   */
/* 2008-08-07 1.1  James      Update PackDetail.QTY = UCC.QTY           */
/*                            when confirm Wave FCP                     */
/* 2008-08-15 1.1  James      For FCP, update UCC Status = '6'          */
/*                            when confirm replenishment (james01)      */
/* 2008-10-22 1.2  James      SOS119812 - Add archivecop to prevent     */
/*                            user from doing workstation PnP (james02) */
/* 2008-11-10 1.3  James      Add in Event Log (james03)                */
/* 2009-01-29 1.4  James      SOS127398 - Add in LoadKey to restrict    */
/*                            user to do replenishment based on loadkey */
/*                            scanned (james04)                         */
/* 2009-08-26 1.5  Vicky      Replace current EventLog with Standard    */
/*                            EventLog (Vicky06)                        */
/* 2013-07-04 1.6  ChewKP     SOS#281895 - TBL Enhancement (ChewKP01)   */
/* 2013-11-13 1.7  ChewKP     Update Pickslipno for FCP (ChewKP02)      */
/* 2015-05-20 1.8  ChewKP     SOS#342071 Add Extended Update Config     */
/*                            (ChewKP03)                                */
/* 2016-09-30 1.9  Ung        Performance tuning                        */
/* 2018-01-16 2.0  ChewKP     WMS-3767-Call rdt.rdtPrintJob (ChewKP04)  */
/* 2018-10-31 2.1  Gan        Performance tuning                        */
/* 2019-10-09 2.2  Chermaine  WMS-10777 Eventlog (cc01)                 */
/* 2020-10-08 2.3  James      WMS-15412 Add ExtendedInfoSP (james05)    */
/* 2023-06-02 2.4  Ung        WMS-22563 Add UCCWithMultiSKU             */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_DynamicPick_UCCReplenFrom] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @cOption     NVARCHAR( 1),
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
   @cPrinter   NVARCHAR( 10),

   @nKeyCount  INT,
   @nError     INT,
   @i          INT,
   @b_success  INT,
   @n_err      INT,
   @c_errmsg   NVARCHAR( 250),

   @cReplenGroup  NVARCHAR( 10),
   @cLOC          NVARCHAR( 10),
   @cUCC          NVARCHAR( 20),
   @cConsigneeKey NVARCHAR( 15),
   @cC_Company    NVARCHAR( 20),
   @cOrderKey     NVARCHAR( 10),
   @cCartonNo     NVARCHAR( 5),

   @cSku                NVARCHAR( 20),
   @nQty                INT,
   @nUCCQty             INT,
   @nPDQTY              INT,
   @cLottable01         NVARCHAR( 18),
   @cLottable02         NVARCHAR( 18),
   @cLottable03         NVARCHAR( 18),
   @dLottable04         DATETIME,
   @cUCCLoc             NVARCHAR( 10),
   @cUCCLot             NVARCHAR( 10),
   @cID                 NVARCHAR( 18),
   @cPickDetailKey      NVARCHAR( 18),
   @cNewUCC             NVARCHAR( 20),
   @cStatus             NVARCHAR( 10),
   @cReplenishmentKey   NVARCHAR( 10),
   @cToLoc              NVARCHAR( 10),
   @nCartonNo           INT,
   @cPickSlipNo         NVARCHAR( 10),
   @cCartonGroup        NVARCHAR( 8),
   @cDataWindow         NVARCHAR( 50),
   @cTargetDB           NVARCHAR( 10),
   @cLabelNo            NVARCHAR( 10),
   @cWaveKey            NVARCHAR( 10),
   @nRowRef             INT,  -- (james03)
   @cUserName           NVARCHAR( 15),  -- (james03)
   @cUOM                NVARCHAR( 10), -- (james03)
   @c_LoadKey            NVARCHAR( 10), -- (james03)
   @cRemark             NVARCHAR( 20), -- (james03)
   @cLoadKey            NVARCHAR( 10), -- (james04)
   @cSuggestedFromLoc   NVARCHAR( 10), -- (ChewKP01)
   @cPrintLabel         NVARCHAR(  1), -- (ChewKP01)
   @cSwapUCCSP          NVARCHAR(20),  -- (ChewKP03)
   @cSQL                NVARCHAR(1000),-- (ChewKP03)
   @cSQLParam           NVARCHAR(1000),-- (ChewKP03)
   @cExtendedInfoSP     NVARCHAR( 20), -- (james05)
   @cExtendedInfo       NVARCHAR( 20), -- (james05)
   @tExtInfoVar         VARIABLETABLE, -- (james05)

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
   @cLoadKey   = V_LoadKey,

   @cCartonNo  = V_Cartonno,

   @nRowRef    = V_Integer1,

   @cReplenGroup  = V_String1,
   @cLOC          = V_String2,
   @cUCC          = V_String3,
   @cConsigneeKey = V_String4,
   @cC_Company    = V_String5,
   @cOrderKey     = V_String6,
   @cExtendedInfoSP  = V_String7,
   @cWaveKey         = V_String8,
  -- @nRowRef       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String9, 5), 0) = 1 THEN LEFT( V_String9, 5) ELSE 0 END,
   @cSwapUCCSP       = V_String10,

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

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 940  -- UCC Replenishment From (Dynamic Pick)
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- UCC Replenishment From (Dynamic Pick)
   IF @nStep = 1 GOTO Step_1   -- Scn = 1610. Replen Group
   IF @nStep = 2 GOTO Step_2   -- Scn = 1611. Replen Group, LoadKey  (james04)
   IF @nStep = 3 GOTO Step_3   -- Scn = 1612. Replen Group, LoadKey, From Loc (james04)
   IF @nStep = 4 GOTO Step_4   -- Scn = 1613. From Loc, UCC, Consignee, Company, OrderKey, CartonNo
END

--RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 932. Menu
********************************************************************************/
Step_0:
BEGIN
   -- (ChewKP03)
   SET @cSwapUCCSP = rdt.RDTGetConfig( @nFunc, 'SwapUCCSP', @cStorerKey)
   IF @cSwapUCCSP = '0'
   BEGIN
      SET @cSwapUCCSP = ''
   END

   -- (james05)
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerkey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   -- Set the entry point
   SET @nScn = 1610
   SET @nStep = 1

   -- Initiate var
   SET @cReplenGroup = ''

   -- Init screen
   SET @cOutField01 = '' -- Replen Group

   -- (Vicky06) EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @cRemark     = @cRemark

END
GOTO Quit

/********************************************************************************
Step 1. Scn = 1610. Replen Group
   Replen Group      (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
         --screen mapping
      SET @cReplenGroup = @cInField01

      -- Validate blank
      IF @cReplenGroup = '' OR @cReplenGroup IS NULL
      BEGIN
         SET @nErrNo = 63651
         SET @cErrMsg = rdt.rdtgetmessage( 63651, @cLangCode,'DSP') --Need REPLENGRP
         GOTO Step_1_Fail
      END

      --validate replenGroup
      IF NOT EXISTS (SELECT 1
         FROM dbo.Replenishment WITH (NOLOCK)
         WHERE ReplenishmentGroup = @cReplenGroup
            AND StorerKey = @cStorerKey
            AND Confirmed = 'N')  -- (ChewKP01)
      BEGIN
        SET @nErrNo = 63652
        SET @cErrMsg = rdt.rdtgetmessage( 63652, @cLangCode,'DSP') --No replen task
        GOTO Step_1_Fail
      END

-- (ChewKP01)
--      IF NOT EXISTS (SELECT 1
--         FROM   dbo.Replenishment RPL WITH (NOLOCK)
--         JOIN   dbo.WAVEDETAIL WD WITH (NOLOCK) ON RPL.Replenno = WD.WaveKey
--         JOIN   dbo.LOADPLANDETAIL LPD WITH (NOLOCK) ON WD.OrderKey = LPD.OrderKey
--         WHERE  RPL.ReplenishmentGroup = @cReplenGroup)
--      BEGIN
--         SET @nErrNo = 63678
--         SET @cErrMsg = rdt.rdtgetmessage( 63678, @cLangCode, 'DSP') --LoadNotExists
--         GOTO Step_1_Fail
--      END

      SELECT TOP 1
         @cWaveKey = ReplenNo,
         @cRemark  = Remark   -- (james03)
      FROM dbo.Replenishment WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ReplenishmentGroup = @cReplenGroup

      -- Prepare next screen var
      SET @cOutField01 = @cReplenGroup
      SET @cOutField02 = ''--LOC
      SET @cLoadKey = ''

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      -- Start insert into eventlog (james03)
--      EXEC RDT.RDT_EventLog
--         @nRowRef     = @nRowRef OUTPUT,
--         @cUserID     = @cUserName,
--         @cActivity   = @cRemark,
--         @nFucntionID = @nFunc
   END

   IF @nInputKey = 0 --ESC
   BEGIN
     -- (Vicky06) EventLog - Sign Out Function
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerKey

      --go to main menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cReplenGroup = ''
      SET @cOutField01 = '' -- ReplenGroup
   END

END
GOTO Quit

/********************************************************************************
Step 2. Scn = 1611. Replen Group, LoadKey
   REPLEN GROUP   (field01)
   LoadKey        (filed02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      --screen mapping
      SET @cLoadKey = @cInField02

      IF @cLoadKey <> '' AND @cLoadKey IS NOT NULL
      BEGIN
         --validate LoadKey
         IF NOT EXISTS (SELECT 1
            FROM dbo.LoadPlan WITH (NOLOCK)
            WHERE LoadKey = @cLoadKey)
         BEGIN
            SET @nErrNo = 63681
            SET @cErrMsg = rdt.rdtgetmessage( 63681, @cLangCode,'DSP') --Invalid LoadKey
            GOTO Step_2_Fail
         END

         --Validate if LoadKey in same wave
         IF NOT EXISTS (SELECT 1
            FROM dbo.Orders WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND UserDefine09 = @cWaveKey
               AND LoadKey = @cLoadKey
               AND Facility = @cFacility)
         BEGIN
            SET @nErrNo = 63682
            SET @cErrMsg = rdt.rdtgetmessage( 63682, @cLangCode,'DSP') --LoadNotInWave
            GOTO Step_2_Fail
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = @cReplenGroup
      SET @cOutField02 = @cLoadKey



      SET @cOutField03 = ''
      SET @cLOC = ''

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = ''  -- ReplenGroup
      SET @cReplenGroup = ''

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cLoadKey = '' -- LoadKey
      SET @cOutField02 = ''
   END

END
GOTO Quit

/********************************************************************************
Step 3. Scn = 1612. Replen Group, LoadKey, LOC
   REPLEN GROUP   (field01)
   LOADKEY        (field02)
   FROM LOC       (filed03, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      --screen mapping
      SET @cLOC = @cInField03

      IF @cLOC <> '' AND @cLOC IS NOT NULL
      BEGIN
         --validate LOC
         IF NOT EXISTS (SELECT 1
            FROM dbo.Loc WITH (NOLOCK)
            WHERE LOC = @cLOC)
         BEGIN
            SET @nErrNo = 63653
            SET @cErrMsg = rdt.rdtgetmessage( 63653, @cLangCode,'DSP') --Invalid LOC
            GOTO Step_3_Fail
         END

         --Validate if LOC in same facility
         IF NOT EXISTS (SELECT 1
            FROM dbo.Loc WITH (NOLOCK)
            WHERE Loc = @cLOC
               AND Facility = @cFacility)
         BEGIN
            SET @nErrNo = 63654
            SET @cErrMsg = rdt.rdtgetmessage( 63654, @cLangCode,'DSP') --Diff facility
            GOTO Step_3_Fail
         END


         --check if any uncompleted replenish task
         IF ISNULL(RTRIM(@cLoadKey),'')  <> '' --OR @cLoadKey IS NOT NULL -- (ChewKP03)
         BEGIN


            IF NOT EXISTS (SELECT 1
               FROM dbo.Replenishment R WITH (NOLOCK)
               JOIN dbo.Orders O WITH (NOLOCK) ON (R.StorerKey = O.StorerKey AND R.ReplenNo = O.Userdefine09)
               WHERE R.FromLoc = @cLoc
                  AND R.ReplenishmentGroup = @cReplenGroup
                  AND R.StorerKey = @cStorerKey
                  AND R.Confirmed = 'W'
                  AND O.StorerKey = @cStorerKey
                  AND O.LoadKey = @cLoadKey
                  AND O.Facility = @cFacility)
            BEGIN
               SET @nErrNo = 63683
               SET @cErrMsg = rdt.rdtgetmessage( 63683, @cLangCode,'DSP') --No replen task
               GOTO Step_3_Fail
            END
         END
         ELSE
         BEGIN
            IF NOT EXISTS (SELECT 1
               FROM dbo.Replenishment WITH (NOLOCK)
               WHERE FromLoc = @cLoc
                  AND ReplenishmentGroup = @cReplenGroup
                  AND StorerKey = @cStorerKey
                  AND Confirmed = 'N')  -- (ChewKP01)
            BEGIN
               SET @nErrNo = 63655
               SET @cErrMsg = rdt.rdtgetmessage( 63655, @cLangCode,'DSP') --No replen task
               GOTO Step_3_Fail
            END
         END
      END

      -- (james05)
      -- Extended info
      SET @cExtendedInfo = ''
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cReplenGroup, @cLoadKey, @cLOC, @cUCC,' +
               ' @tExtInfoVar, @cExtendedInfo OUTPUT '
            SET @cSQLParam =
               '@nMobile          INT,           ' +
               '@nFunc            INT,           ' +
               '@cLangCode        NVARCHAR( 3),  ' +
               '@nStep            INT,           ' +
               '@nAfterStep       INT,           ' +
               '@nInputKey        INT,           ' +
               '@cStorerkey       NVARCHAR( 15), ' +
               '@cReplenGroup     NVARCHAR( 10), ' +
               '@cLoadKey         NVARCHAR( 10), ' +
               '@cLOC             NVARCHAR( 10), ' +
               '@cUCC             NVARCHAR( 20), ' +
               '@tExtInfoVar      VariableTable READONLY, ' +
               '@cExtendedInfo    NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                 @nMobile, @nFunc, @cLangCode, @nStep, 4, @nInputKey, @cStorerkey, @cReplenGroup, @cLoadKey, @cLOC, @cUCC,
                 @tExtInfoVar, @cExtendedInfo OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = @cLOC
      SET @cUCC = ''
      SET @cOutField02 = '' --ucc
      SET @cTOLOC = ''
      SET @cOutField03 = '' --TOLOC
      SET @cPickSlipNo = ''
      SET @cOutField04 = '' --PKSLIPNO
      SET @cOrderKey = ''
      SET @cOutField05 = '' --OrderKey
      SET @cCartonNo = ''
      SET @cOutField06 = '' --CartonNo
      SET @cConsigneeKey = ''
      SET @cOutField07 = '' --consigneeKey
      SET @cC_Company = ''
      SET @cOutField08 = '' --C_Company

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cReplenGroup
      SET @cOutField02 = ''   --LoadKey
      SET @cLoadKey = ''

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cLOC = '' -- LOC
      SET @cOutField03 = ''
   END

END
GOTO Quit

/********************************************************************************
Step 4. Scn = 1613. From Loc, UCC, Consignee, Company, OrderKey, CartonNo
   FROM LOC       (field01)
   UCC            (field02, input)
   ConsigneeKey   (field03)
   C_Company      (field04)
   OrderKey       (field05)
   CartonNo       (field06)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      --screen mapping
      SET @cUCC = @cInField02

      IF @cUCC = '' OR @cUCC IS NULL
      BEGIN
         SET @nErrNo = 63656
         SET @cErrMsg = rdt.rdtgetmessage( 63656, @cLangCode,'DSP') --Need UCC
         GOTO Step_4_Fail
      END

      -- Check if UCC scanned exists within the same loadkey
      IF ISNULL(@cLoadKey, '') <> ''
      BEGIN
         SELECT @cSKU = SKU FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCC

         IF NOT EXISTS (SELECT 1 FROM dbo.Orders O WITH (NOLOCK)
          JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
            WHERE O.StorerKey = @cStorerKey
               AND O.LoadKey = @cLoadKey
               AND O.UserDefine09 = @cWaveKey
               AND OD.SKU = @cSKU)
         BEGIN
            SET @nErrNo = 63684
            SET @cErrMsg = rdt.rdtgetmessage( 63684, @cLangCode,'DSP') --SKUNotInLoad
            GOTO Step_4_Fail
         END
      END

      SET @nCount = 0
      IF @cLOC IS NOT NULL AND @cLOC <> ''
      BEGIN
         SELECT @nCount = COUNT(1)
         FROM dbo.Replenishment WITH (NOLOCK)
         WHERE ReplenishmentGroup = @cReplenGroup
            AND FromLoc = @cLOC
            AND RefNo = @cUCC
            AND StorerKey = @cStorerKey
            AND Confirmed = 'N'  -- (ChewKP01)
      END
      ELSE
      BEGIN
         SELECT @nCount = COUNT(1)
         FROM dbo.Replenishment WITH (NOLOCK)
         WHERE ReplenishmentGroup = @cReplenGroup
            AND RefNo = @cUCC
            AND StorerKey = @cStorerKey
            AND Confirmed = 'N'  -- (ChewKP01)
      END

      -- (ChewKP03)
      IF @cSwapUCCSP <> ''
      BEGIN
          IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSwapUCCSP AND type = 'P')
          BEGIN

             SET @cSQL = 'EXEC rdt.' + RTRIM( @cSwapUCCSP) +
                ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @nStep, @cUCC, @cReplenGroup, @cLoadKey, @cLOC, @cNewUCC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
             SET @cSQLParam =
                '@nMobile          INT, ' +
                '@nFunc            INT, ' +
                '@cLangCode        NVARCHAR( 3),  ' +
                '@cUserName        NVARCHAR( 18), ' +
                '@cFacility        NVARCHAR( 5),  ' +
                '@cStorerKey       NVARCHAR( 15), ' +
                '@nStep            INT,           ' +
                '@cUCC             NVARCHAR( 20), ' +
                '@cReplenGroup     NVARCHAR( 10), ' +
                '@cLoadKey         NVARCHAR( 10), ' +
                '@cLOC             NVARCHAR( 10) , ' +
                '@cNewUCC          NVARCHAR( 20) OUTPUT, ' +
                '@nErrNo           INT           OUTPUT, ' +
                '@cErrMsg          NVARCHAR( 20) OUTPUT'


             EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                 @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @nStep, @cUCC, @cReplenGroup, @cLoadKey, @cLOC, @cNewUCC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

             IF @nErrNo <> 0
                GOTO Step_4_Fail

             --get the uccNo if the swap ucc has been performed
             IF @cNewUCC <> '' AND @cNewUCC IS NOT NULL
             BEGIN
               SET @cUCC = @cNewUCC
               SET @nCount = 1
             END
          END
      END

      IF @nCount = 0
      BEGIN
         SET @nErrNo = 63685
         SET @cErrMsg = rdt.rdtgetmessage( 63685, @cLangCode,'DSP') --InvalidUCC
         GOTO Step_4_Fail
      END

      --get ReplenishmentKey and ToLoc
      SELECT @cReplenishmentKey = '', @cToLoc = ''
      IF @cLOC IS NOT NULL AND @cLOC <> ''
      BEGIN
         SELECT @cReplenishmentKey = ReplenishmentKey,
                @cToLoc            = ToLoc
         FROM dbo.Replenishment WITH (NOLOCK)
         WHERE ReplenishmentGroup = @cReplenGroup
            AND FromLoc = @cLOC
            AND RefNo = @cUCC
            AND StorerKey = @cStorerKey
            AND Confirmed = 'N' -- (ChewKP01)
      END
      ELSE
      BEGIN
         SELECT @cReplenishmentKey = ReplenishmentKey,
                @cToLoc            = ToLoc
         FROM dbo.Replenishment WITH (NOLOCK)
         WHERE ReplenishmentGroup = @cReplenGroup
            AND RefNo = @cUCC
            AND StorerKey = @cStorerKey
            AND Confirmed = 'N' -- (ChewKP01)
      END

      --for FCP(Replenishment.ToLoc = 'PICK')
      IF RTRIM(@cToLoc) = 'PICK'
      BEGIN
         SET @nQTY = 0
         
         BEGIN TRAN

         DECLARE @curUCC CURSOR
         SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT SKU, QTY, LOT, LOC, PickDetailKey
            FROM dbo.UCC WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND UCCNo = @cUCC
               AND STATUS = '3'
         OPEN @curUCC
         FETCH NEXT FROM @curUCC INTO @cSku, @nUCCQTY, @cUCCLot, @cUCCLoc, @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            SET @nQTY += @nUCCQTY

            SELECT @cOrderKey = OrderKey
            FROM dbo.Pickdetail WITH (NOLOCK)
            WHERE PickDetailKey = @cPickDetailKey -- (ChewKP01)
            ORDER BY PickdetailKey

            IF ISNULL(@cPickDetailKey, '') = ''
            BEGIN
               SET @nErrNo = 63679
               SET @cErrMsg = rdt.rdtgetmessage( 63679, @cLangCode,'DSP') --OffsetPDtlFail
               ROLLBACK TRAN
               GOTO Step_4_Fail
            END

            IF ISNULL(@cPickDetailKey, '') <> ''
            BEGIN
               --Get PickSlipNo and Update to PickDetail -- (ChewKP02)
               SET @cPickSlipNo = ''
               SELECT @cPickSlipNo = PickHeaderKey
               FROM dbo.PickHeader WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey

               UPDATE dbo.PICKDETAIL WITH (ROWLOCK) SET
                  Status = '5', -- (ChewKP01)
                  AltSKU = @cUCC,
                  PickSlipNo = CASE WHEN ISNULL(PickSlipNo,'') = '' THEN @cPickSlipNo ELSE PickSlipNo END -- (ChewKP02)
                  --TrafficCop = NULL, EditWho = sUser_sName(), EditDate = GetDate()    -- (ChewKP01)
               WHERE PickdetailKey = @cPickDetailKey

               SELECT @nError = @@ERROR, @nRowCount = @@ROWCOUNT

               IF @nError <> 0
               BEGIN
                  SET @nErrNo = 63666
                  SET @cErrMsg = rdt.rdtgetmessage( 63666, @cLangCode,'DSP') --Upd PKDtl fail
                  ROLLBACK TRAN
                  GOTO Step_4_Fail
               END

               IF @nRowCount <> 1
               BEGIN
                  SET @nErrNo = 63667
                  SET @cErrMsg = rdt.rdtgetmessage( 63667, @cLangCode,'DSP') --Task Changed
                  ROLLBACK TRAN
                  GOTO Step_4_Fail
               END
            END

            -- Update PackDetail.Qty = UCC.Qty as allocation of FCP will only insert PackDetail.Qty = 0
            -- To prevent user forget to scan FCP and directly goto workstation P&P to confirm
            -- Update will make the AllocatedQty = PickedQty
            UPDATE dbo.PackDetail WITH (ROWLOCK) SET --(james02)
               ArchiveCop = NULL,
               EditWho = 'rdt.' + sUser_sName(),
               EditDate = GETDATE(),
               QTY = @nUCCQTY
            WHERE StorerKey = @cStorerkey
              AND RefNo = @cUCC
              AND SKU = @cSKU
              AND QTY = 0

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 63680
               SET @cErrMsg = rdt.rdtgetmessage( 63680, @cLangCode,'DSP') --UpdPackQtyFail
               ROLLBACK TRAN
               GOTO Step_4_Fail
            END
         
            FETCH NEXT FROM @curUCC INTO @cSku, @nUCCQTY, @cUCCLot, @cUCCLoc, @cPickDetailKey
         END

         Update dbo.Replenishment WITH (ROWLOCK)
         SET Confirmed = 'S',  -- (ChewKP01)
             EditWho = sUser_sName(),
             EditDate = GETDATE(),
             ArchiveCop = NULL
         WHERE ReplenishmentGroup = @cReplenGroup
            AND RefNo = @cUCC
            AND StorerKey = @cStorerKey
            AND Confirmed = 'N' -- (ChewKP01)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 63670
            SET @cErrMsg = rdt.rdtgetmessage( 63670, @cLangCode,'DSP') --UpdRepConffail
            ROLLBACK TRAN
            GOTO Step_4_Fail
         END

         Update dbo.UCC WITH (ROWLOCK)
         SET Status = '5', -- (james01)  -- (ChewKP01)
         EditDate = GETDATE(),
         EditWho = sUSER_sNAME()
         WHERE UCCNo = @cUCC
            AND StorerKey = @cStorerKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 63671
            SET @cErrMsg = rdt.rdtgetmessage( 63671, @cLangCode,'DSP') --UpdUCCPickfail
            ROLLBACK TRAN
            GOTO Step_4_Fail
         END

         --print carton label process (start)
         --if RDT user login with printer, auto print out the carton label for that label/ucc
         -- (ChewKP01)
         SET @cPrintLabel = ''
         SET @cPrintLabel = rdt.RDTGetConfig( @nFunc, 'PrintLabel', @cStorerKey)

         IF @cPrintLabel = '1'
         BEGIN
            IF ISNULL(@cPrinter, '') <> ''
            BEGIN
               SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                      @cTargetDB = ISNULL(RTRIM(TargetDB), '')
               FROM RDT.RDTReport WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND ReportType = 'CARTONLBL'

               IF ISNULL(@cDataWindow, '') = ''
               BEGIN
                  SET @nErrNo = 63674
                  SET @cErrMsg = rdt.rdtgetmessage( 63674, @cLangCode, 'DSP') --DWNOTSetup
                  ROLLBACK TRAN
                  GOTO Step_4_Fail
               END

               IF ISNULL(@cTargetDB, '') = ''
               BEGIN
                  SET @nErrNo = 63675
                  SET @cErrMsg = rdt.rdtgetmessage( 63675, @cLangCode, 'DSP') --TgetDB Not Set
                  ROLLBACK TRAN
                  GOTO Step_4_Fail
               END

               --get pickSlipNo, CartonNo
               SET @cPickSlipNo = '' -- (ChewKP02)

               SELECT @nCartonNo   = CartonNo,
                      @cPickSlipNo = PickSlipNo,
                      @cLabelNo = Labelno
               FROM dbo.PackDetail WITH (NOLOCK) --, INDEX(IX_PackDetail_StorerKey_RefNo))
               WHERE StorerKey = @cStorerKey
               AND   RefNo = @cUCC

               -- (ChewKP04)
               -- Call printing spooler
               --INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Parm3, Parm4, Parm5, Printer, NoOfCopy, Mobile, TargetDB)
               --VALUES('PRINTCARTONLBL', 'CARTONLBL', '0', @cDataWindow, 5, @cPickSlipNo, @nCartonNo, @nCartonNo, @cLabelNo, @cLabelNo, @cPrinter, 1, @nMobile, @cTargetDB)

               EXEC RDT.rdt_BuiltPrintJob
                  @nMobile,
                  @cStorerKey,
                  'CARTONLBL',
                  'PRINTCARTONLBL',
                  @cDataWindow,
                  @cPrinter,
                  @cTargetDB,
                  @cLangCode,
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT,
                  @cPickSlipNo,
                  @nCartonNo,
                  @nCartonNo,
                  @cLabelNo,
                  @cLabelNo

               IF @nErrNo <> 0
               BEGIN
                  ROLLBACK TRAN

                  SET @nErrNo = 63676
                  SET @cErrMsg = rdt.rdtgetmessage( 63676, @cLangCode, 'DSP') --'InsertPRTFail'
                  ROLLBACK TRAN
                  GOTO Step_4_Fail
               END
            END
         END
         --print carton label process (end)

         COMMIT TRAN

         SELECT TOP 1
                @c_LoadKey = LoadKey,
                @cUOM = UOM
         FROM dbo.OrderDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND OrderKey = @cOrderKey
            AND SKU = @cSKU

         IF @nQTY <> @nUCCQTY
            SET @cSKU = 'MULTI'

         -- EventLog
         EXEC RDT.rdt_STD_EventLog
           @cActionType   = '5', -- Replen
           @cUserID       = @cUserName,
           @nMobileNo     = @nMobile,
           @nFunctionID   = @nFunc,
           @cFacility     = @cFacility,
           @cStorerKey    = @cStorerKey,
           @cSKU          = @cSKU,
           @cUOM          = @cUOM,
           @nQTY          = @nQTY,
           @cLoadkey      = @c_Loadkey,
           @clocation     = @cLOC, --(cc01)
           @ctoLocation   = @cToLoc, --(cc01)
           @cUCC          = @cUCC, --(cc01)
           @cReplenishmentGroup = @cReplenGroup --(cc01)
      END
      
      ELSE--for Non FCP(Replenishment.ToLoc <> 'PICK')
      BEGIN
         BEGIN TRAN

         Update dbo.Replenishment WITH (ROWLOCK)
         SET Confirmed = 'S',
             EditWho = sUser_sName(),
             EditDate = GETDATE(),
             ArchiveCop = NULL
         WHERE ReplenishmentGroup = @cReplenGroup
            AND RefNo = @cUCC
            AND StorerKey = @cStorerKey
            AND Confirmed = 'N'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 63672
            SET @cErrMsg = rdt.rdtgetmessage( 63672, @cLangCode,'DSP') --UpdRepConffail
            ROLLBACK TRAN
            GOTO Step_4_Fail
         END

         Update dbo.UCC WITH (ROWLOCK)
--         SET Status = '6',
         -- Changed from 6 to 4 coz the loadplan allocation only cater for ucc.status in ('3', '4')
         -- If use 6 then there will be many many record and cause performance issue
         SET Status = '6',   -- (ChewKP01)
         EditDate = GETDATE(),
         EditWho = sUSER_sNAME()
         WHERE UCCNo = @cUCC
            AND StorerKey = @cStorerKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 63673
            SET @cErrMsg = rdt.rdtgetmessage( 63673, @cLangCode,'DSP') --UpdUCCReplfail
            ROLLBACK TRAN
            GOTO Step_4_Fail
         END

         COMMIT TRAN

         SELECT @cSKU = '', @cUOM = '', @nUCCQty = 0
         SELECT TOP 1
            @cSKU = SKU,
            @cUOM = UOM,
            @nUCCQty = QTY
         FROM dbo.Replenishment WITH (NOLOCK)
         WHERE ReplenishmentKey = @cReplenishmentKey

        -- EventLog
        EXEC RDT.rdt_STD_EventLog
           @cActionType   = '5', -- Replen
           @cUserID       = @cUserName,
           @nMobileNo     = @nMobile,
           @nFunctionID   = @nFunc,
           @cFacility     = @cFacility,
           @cStorerKey    = @cStorerKey,
           @cSKU          = @cSKU,
           @cUOM          = @cUOM,
           @nQTY          = @nUCCQty,
           @cWaveKey      = @cWaveKey,
           @clocation     = @cLOC, --(cc01)
           @ctoLocation   = @cToLoc, --(cc01)
           @cUCC          = @cUCC, --(cc01)
           @cReplenishmentGroup = @cReplenGroup --(cc01)
      END

      --get pickSlipNo, CartonNo, OrderKey, C_Company, ConsigneeKey
      SELECT @cPickSlipNo = '', @nCartonNo = 0, @cOrderKey = '', @cC_Company = '', @cConsigneeKey = ''

      SELECT TOP 1
             @cOrderKey = O.OrderKey,
             @cPickSlipNo = PH.PickHeaderKey,
             @cConsigneeKey = O.ConsigneeKey,
             @cC_Company = O.C_Company
      FROM dbo.UCC UCC WITH (NOLOCK)
      INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.PickDetailKey = UCC.PickDetailKey
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
      INNER JOIN dbo.Pickheader PH WITH (NOLOCK) ON PH.OrderKey = O.OrderKey
      WHERE O.StorerKey = @cStorerKey
      AND   UCC.UCCNo = @cUCC

      -- Extended info
      SET @cExtendedInfo = ''
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cReplenGroup, @cLoadKey, @cLOC, @cUCC,' +
               ' @tExtInfoVar, @cExtendedInfo OUTPUT '
            SET @cSQLParam =
               '@nMobile          INT,           ' +
               '@nFunc            INT,           ' +
               '@cLangCode        NVARCHAR( 3),  ' +
               '@nStep            INT,           ' +
               '@nAfterStep       INT,           ' +
               '@nInputKey        INT,           ' +
               '@cStorerkey       NVARCHAR( 15), ' +
               '@cReplenGroup     NVARCHAR( 10), ' +
               '@cLoadKey         NVARCHAR( 10), ' +
               '@cLOC             NVARCHAR( 10), ' +
               '@cUCC             NVARCHAR( 20), ' +
               '@tExtInfoVar      VariableTable READONLY, ' +
               '@cExtendedInfo    NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                 @nMobile, @nFunc, @cLangCode, @nStep, 4, @nInputKey, @cStorerkey, @cReplenGroup, @cLoadKey, @cLOC, @cUCC,
                 @tExtInfoVar, @cExtendedInfo OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END

      --prepare next screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = '' --ucc
      SET @cOutField03 = @cTOLOC --TOLOC
      SET @cOutField04 = @cPickSlipNo --PKSLIPNO
      SET @cOutField05 = @cOrderKey --OrderKey
      SET @cOutField06 = CONVERT(CHAR, @nCartonNo) --CartonNo
      SET @cOutField07 = SUBSTRING(@cConsigneeKey, 1, 15) --consigneeKey
      SET @cOutField08 = SUBSTRING(@cC_Company,1, 20) --C_Company
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cReplenGroup
      SET @cOutField02 = @cLoadKey
      SET @cOutField03 = ''  --LOC
      SET @cLOC = ''

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cUCC = ''
      SET @cOutField02 = '' --UCC
      SET @cOutField03 = '' --TOLOC
      SET @cOutField04 = '' --PKSLIPNO
      SET @cOutField05 = '' --OrderKey
      SET @cOutField06 = '' --CartonNo
      SET @cOutField07 = '' --consigneeKey
      SET @cOutField08 = '' --C_Company
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

      StorerKey = @cStorerKey,
      Facility  = @cFacility,
      Printer   = @cPrinter,
      -- UserName  = @cUserName,

      V_LoadKey = @cLoadKey,

      V_Cartonno = @cCartonNo,

      V_Integer1 = @nRowRef,

      V_String1 = @cReplenGroup,
      V_String2 = @cLOC,
      V_String3 = @cUCC,
      V_String4 = @cConsigneeKey,
      V_String5 = @cC_Company,
      V_String6 = @cOrderKey,
      V_String7 = @cExtendedInfoSP,
      V_String8 = @cWaveKey,
      --V_String9 = @nRowRef,
      V_String10 = @cSwapUCCSP, 

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