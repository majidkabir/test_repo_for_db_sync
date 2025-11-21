SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: IDSUK Put To Light Order Pick SOS#269032                          */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2013-02-25 1.0  ChewKP     Created                                         */
/* 2013-06-11 1.1  ChewKP     SOS#280749 PTL Enhancement (ChewKP01)           */
/* 2014-02-27 1.2  James      SOS#303322 Add decode label (james01)           */
/* 2014-05-30 1.3  James      SOS303322 Add bypass exec dpc directly (james02)*/
/*                            Support 20 positions (james03)                  */
/*                            Add Pickzone (james04)                          */
/*                            Add customised fetch task (james05)             */
/* 2014-11-10 1.4  James      Change locking hints (james06)                  */
/* 2014-10-03 1.5  Ung        SOS318953 Chg BypassTCPSocketClient to DeviceID */
/* 2014-10-17 1.6  Ung        SOS316714 Add PTL_InsertPTLTranSP               */
/* 2015-01-19 1.7  James      SOS330799-Add config DispStyleColorSize(james07)*/
/* 2015-03-04 1.8  James      Clear variable before (james08)                 */
/* 2015-04-08 1.9  James      Performance tuning (james09)                    */
/* 2015-08-04 2.0  James      Bug fix (james10)                               */
/* 2018-10-11 2.1  TungGH     Performance                                     */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_PTL_OrderPicking] (
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

   @nError        INT,
   @b_success     INT,
   @n_err         INT,
   @c_errmsg      NVARCHAR( 250),
   @cPUOM         NVARCHAR( 10),
   @bSuccess      INT,

   @cCartID       NVARCHAR(10),
   @cOrderKey     NVARCHAR(10),
   @cLightLoc     NVARCHAR(10),
   @cToteID       NVARCHAR(20),
   @cPickSlipNo   NVARCHAR(10),

   @cSKU             NVARCHAR(20) ,
   @cSuggestedSKU    NVARCHAR(20) ,
   @cSKUDescr        NVARCHAR(60) ,
   @cLoc             NVARCHAR(10) ,
   @cLottable01      NVARCHAR(18) ,
   @cLottable02      NVARCHAR(18) ,
   @cLottable03      NVARCHAR(18) ,
   @dLottable04      DATETIME     ,
   @dLottable05      DATETIME     ,
   @nTotalOrder      INT          ,
   @nTotalQty        INT          ,
   @cLot             NVARCHAR(10),

   @cReasonCode       NVARCHAR(10),
   @cNewToteID        NVARCHAR(20),
   @cDeviceProfileKey NVARCHAR(10),
   @cOption          NVARCHAR(1),
   @cDeviceProfileLogKey NVARCHAR(10),
   @nSKUCnt          INT,
   @cPDDropID        NVARCHAR(20),
   @cPDLoc           NVARCHAR(10),
   @cPDToLoc         NVARCHAR(10),
   @cPDID            NVARCHAR(20), -- (ChewKP01)
   @cWaveKey         NVARCHAR(10), -- (ChewKP01)
   @cShowWave        NVARCHAR(1),  -- (ChewKP01)
   @cDeviceID        NVARCHAR(10),

   @cExtendedLightUpSP      NVARCHAR(20),         -- (james02)
   @cSQL             NVARCHAR( 1000),
   @cSQLParam        NVARCHAR( 1000),
   @cPickZone           NVARCHAR( 10), -- (james04)
   @cPTLPKZoneReq       NVARCHAR( 1),  -- (james04)
   @nPrevStep        INT,    -- (james04)
   @nPrevScn         INT,
   @cPTL_GetNextTaskSP     NVARCHAR( 20),    -- (james05)
   @cDispStyleColorSize    NVARCHAR( 20),    -- (james07)
   @cExtendedInfo2Disp01   NVARCHAR( 20),    -- (james07)
   @cExtendedInfo2Disp02   NVARCHAR( 20),    -- (james07)
   @cStyle                 NVARCHAR( 20),    -- (james07)
   @cColor                 NVARCHAR( 10),    -- (james07)
   @cSize                  NVARCHAR( 10),    -- (james07)

   @cResult01  NVARCHAR( 20),   @cResult02 NVARCHAR( 20), -- (james02)
   @cResult03  NVARCHAR( 20),   @cResult04 NVARCHAR( 20),
   @cResult05  NVARCHAR( 20),   @cResult06 NVARCHAR( 20),
   @cResult07  NVARCHAR( 20),   @cResult08 NVARCHAR( 20),
   @cResult09  NVARCHAR( 20),   @cResult10 NVARCHAR( 20),

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

DECLARE  -- (james01)
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),
   @c_oFieled11 NVARCHAR(20), @c_oFieled12 NVARCHAR(20),
   @c_oFieled13 NVARCHAR(20), @c_oFieled14 NVARCHAR(20),
   @c_oFieled15 NVARCHAR(20),
   @cDecodeLabelNo       NVARCHAR( 20),
   @c_LabelNo            NVARCHAR( 32)

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

   @cPUOM       = V_UOM,
 --@cOrderKey   = V_OrderKey,

   @cSKU        = V_SKU,
   @cSKUDescr   = V_SKUDescr,
   @cLoc        = V_Loc,
   @cLot        = V_Lot,
   @cLottable01 = V_Lottable01,  -- (ChewKP01)
   @cLottable02 = V_Lottable02,
   @cLottable03 = V_Lottable03,  -- (ChewKP01)
   @dLottable04 = V_Lottable04,
   @dLottable05 = V_Lottable05,  -- (ChewKP01)
   @cOrderKey   = V_OrderKey,
   @cPDID       = V_ID, -- (ChewKP01)


   @cCartID       = V_String1,
   @cSuggestedSKU = V_String2,
   @cToteID       = V_String3,
   @cDeviceProfileKey = V_String4,
   @cDeviceProfileLogKey = V_String5,
   @cPDDropID     = V_String8,
   @cPDLoc        = V_String9,
   @cPDToLoc      = V_String10,
   @cWaveKey      = V_String11,  -- (ChewKP01)
   @cShowWave     = V_String12,  -- (ChewKP01)
   @cDeviceID     = V_String13,

   @nTotalOrder   = V_Integer1,
   @nTotalQty     = V_Integer2,
      
   @cPTLPKZoneReq = V_String14,   -- (james04)
   @cPickZone     = V_String15,   -- (james04)
   @cExtendedInfo2Disp01 = V_String18,
   @cExtendedInfo2Disp02 = V_String19,

   @nPrevStep     = V_FromStep,
   @nPrevScn      = V_FromScn,
      
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



IF @nFunc = 811  -- PTL Order Pick
BEGIN

   DECLARE @nStepSKU       INT,
           @nScnSKU        INT,
           @nStepConfirm   INT,
           @nScnConfirm    INT,
           @nStepCloseTote INT,
           @nScnCloseTote  INT,
           @nStepReasonCode INT,
           @nScnReasonCode  INT

   SET @nStepSKU       = 2
   SET @nScnSKU        = 3461

   SET @nStepConfirm   = 3
   SET @nScnConfirm    = 3462

   SET @nStepCloseTote   = 4
   SET @nScnCloseTote    = 3463

   SET @nStepReasonCode   = 6
   SET @nScnReasonCode    = 3465

   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- PTL Order Unassignment
   IF @nStep = 1 GOTO Step_1   -- Scn = 3460. Cart ID
   IF @nStep = 2 GOTO Step_2   -- Scn = 3461. SKU
   IF @nStep = 3 GOTO Step_3   -- Scn = 3462. Pick Information , Close Tote Option
   IF @nStep = 4 GOTO Step_4   -- Scn = 3463. Close Tote ID
   IF @nStep = 5 GOTO Step_5   -- Scn = 3464. New Tote ID
   IF @nStep = 6 GOTO Step_6   -- Scn = 3465. Short Pick
   IF @nStep = 7 GOTO Step_7   -- Scn = 3466. Close Tote ID (variable positions)


END

--IF @nStep = 3
--BEGIN
-- SET @cErrMsg = 'STEP 3'
-- GOTO QUIT
--END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 812. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Get prefer UOM
   SET @cPUOM = ''
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

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

   SET @cPTLPKZoneReq = rdt.rdtGetConfig( @nFunc, 'PTLPicKZoneReq', @cStorerKey)
   IF @cPTLPKZoneReq = '0'
      SET @cPTLPKZoneReq = ''

   -- Init screen
   SET @cOutField01 = ''
   SET @cOutField02 = ''

   SET @cSKU        = ''
   SET @cSKUDescr   = ''
   SET @cLoc        = ''
   SET @cLot        = ''
   SET @cLottable02 = ''
   SET @dLottable04 = ''
   SET @cOrderKey   = ''
   SET @cDeviceID   = '' -- (james08)


   SET @cCartID           = ''
   SET @cSuggestedSKU     = ''
   SET @cToteID           = ''
   SET @cDeviceProfileKey = ''
   SET @cDeviceProfileLogKey = ''
   SET @nTotalOrder       = 0
   SET @nTotalQty         = 0


   -- Set the entry point
   SET @nScn = 3460
   SET @nStep = 1

   EXEC rdt.rdtSetFocusField @nMobile, 1

END
GOTO Quit


/********************************************************************************
Step 1. Scn = 3460.
   CartID (Input , Field01)

********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      SET @cCartID = ISNULL(RTRIM(@cInField01),'')
      SET @cPickZone = ISNULL(RTRIM(@cInField02),'')

      -- Validate blank
      IF ISNULL(RTRIM(@cCartID), '') = ''
      BEGIN
         SET @nErrNo = 79601
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartID req
         SET @cOutField01 = ''
         SET @cOutField02 = @cPickZone
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.DeviceProfileLog DL WITH (NOLOCK)
                     INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey
                     WHERE D.DeviceID = @cCartID
                     AND   DL.Status IN ('1','3'))
      BEGIN
         SET @nErrNo = 79602
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartNotAssign
         SET @cOutField01 = ''
         SET @cOutField02 = @cPickZone
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END
      /*
      -- Check if still got task to pick (james01)
      IF EXISTS ( SELECT 1
                  FROM dbo.DeviceProfile D WITH (NOLOCK)
                  JOIN dbo.DeviceProfileLog DL WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey
                  JOIN dbo.PTLTran PT1 WITH (NOLOCK) ON DL.OrderKey = PT1.OrderKey
                  WHERE D.DeviceID = @cCartID
                  AND   NOT EXISTS (SELECT 1 FROM dbo.PTLTran PT2 WITH (NOLOCK) WHERE PT2.Status  < '9'))
      BEGIN
         SET @nErrNo = 79625
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NO PICK TASK
         SET @cOutField01 = ''
         SET @cOutField02 = @cPickZone
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END
      */
      IF ISNULL( @cPickZone, '') = ''
      BEGIN
         IF @cPTLPKZoneReq = '1'
         BEGIN
            SET @nErrNo = 79626
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PickZone req
            SET @cOutField01 = @cCartID
            SET @cOutField02 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                         WHERE Facility = @cFacility
                         AND   PickZone = @cPickZone)
         BEGIN
            SET @nErrNo = 79627
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV PickZone
            SET @cOutField01 = @cCartID
            SET @cOutField02 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         IF NOT EXISTS ( SELECT 1
                         FROM dbo.DeviceProfileLog DL WITH (NOLOCK)
               INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey
                         WHERE D.DeviceID = @cCartID
                         AND DL.Status IN ('1','3')
                         AND DL.UserDefine10 = @cPickZone)
         BEGIN
            SET @nErrNo = 79628
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CART X IN ZONE
            SET @cOutField01 = @cCartID
            SET @cOutField02 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END
      END

      SELECT TOP 1 @cDeviceProfileLogKey = DL.DeviceProfileLogKey
      FROM dbo.DeviceProfileLog DL WITH (NOLOCK)
      INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey
      WHERE D.DeviceID = @cCartID
      AND DL.Status IN ('1','3')

      DECLARE @cPTL_InsertPTLTranSP NVARCHAR(20)
      SET @cPTL_InsertPTLTranSP = rdt.RDTGetConfig( @nFunc, 'PTL_InsertPTLTranSP', @cStorerKey)
      IF @cPTL_InsertPTLTranSP = '0'
         SET @cPTL_InsertPTLTranSP = ''
      IF @cPTL_InsertPTLTranSP <> ''
         IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPTL_InsertPTLTranSP AND type = 'P')
            SET @cPTL_InsertPTLTranSP = ''

      -- Insert PTLTran
      IF @cPTL_InsertPTLTranSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cPTL_InsertPTLTranSP) +
             ' @nMobile, @nFunc, @cFacility, @cStorerKey, @cCartID, @cUserName, @cLangCode, @cPickZone, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
             '@nMobile     INT,            ' +
             '@nFunc       INT,            ' +
             '@cFacility   NVARCHAR(5),    ' +
             '@cStorerKey  NVARCHAR( 15),  ' +
             '@cCartID     NVARCHAR( 10),  ' +
             '@cUserName   NVARCHAR( 18),  ' +
             '@cLangCode   NVARCHAR( 3),   ' +
             '@cPickZone   NVARCHAR( 10),  ' +
             '@nErrNo      INT           OUTPUT, ' +
             '@cErrMsg     NVARCHAR(250) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cFacility, @cStorerKey, @cCartID, @cUserName, @cLangCode, @cPickZone, @nErrNo OUTPUT, @cErrMsg OUTPUT
      END
      ELSE
         -- Insert Into PTLTran
         EXEC [RDT].[rdt_PTL_OrderPicking_InsertPTLTran]
              @nMobile     =  @nMobile
             ,@nFunc       =  @nFunc
             ,@cFacility   =  @cFacility
             ,@cStorerKey  =  @cStorerKey
             ,@cCartID     =  @cCartID
             ,@cUserName   =  @cUserName
             ,@cLangCode   =  @cLangCode
             ,@cPickZone   =  @cPickZone           -- (james04)
             ,@nErrNo      =  @nErrNo       OUTPUT
             ,@cErrMsg     =  @cErrMsg      OUTPUT

      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField01 = @cCartID
         SET @cOutField02 = @cPickZone
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Get Next Task
      SET @cSuggestedSKU = ''
      SET @cSKU          = ''
      SET @cSKUDescr     = ''
      SET @cLoc          = ''
      SET @nTotalOrder   = 0
      SET @nTotalQty     = 0

      -- (ChewKP01)
      SET @cLoc          = ''
      SET @cLot          = ''
      SET @cLottable01   = ''
      SET @cLottable02   = ''
      SET @cLottable03   = ''
      SET @dLottable04   = ''
      SET @dLottable05   = ''
      SET @cPDDropID     = ''
      SET @cPDLoc        = ''
      SET @cPDToLoc      = ''
      SET @cPDID         = ''
      SET @cWaveKey      = ''

      SET @cPTL_GetNextTaskSP = rdt.RDTGetConfig( @nFunc, 'PTL_GetNextTaskSP', @cStorerKey)
      IF @cPTL_GetNextTaskSP NOT IN ('0', '') AND
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPTL_GetNextTaskSP AND type = 'P')
      BEGIN
         SET @nErrNo = 0
         SET @cLoc = '' -- 1st time get from 1st Loc
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cPTL_GetNextTaskSP) +
             ' @nMobile, @nFunc, @cFacility, @cStorerKey, @cCartID, @cUserName, @cLangCode, @cPickZone,
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSKU OUTPUT, @cSKUDescr OUTPUT, @cLoc OUTPUT, @cLot OUTPUT,
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @nTotalOrder OUTPUT, @nTotalQty OUTPUT, @cPDDropID OUTPUT, @cPDLoc OUTPUT, @cPDToLoc OUTPUT,
               @cPDID OUTPUT, @cWaveKey OUTPUT '
         SET @cSQLParam =
             '@nMobile          INT, ' +
             '@nFunc            INT, ' +
             '@cFacility        NVARCHAR(5), ' +
             '@cStorerKey       NVARCHAR( 15), ' +
             '@cCartID          NVARCHAR( 10), ' +
             '@cUserName        NVARCHAR( 18), ' +
             '@cLangCode        NVARCHAR( 3), ' +
             '@cPickZone        NVARCHAR( 10), ' +
             '@nErrNo           INT           OUTPUT, ' +
             '@cErrMsg          NVARCHAR(250) OUTPUT, ' + -- screen limitation, 20 char max
             '@cSKU    NVARCHAR(20)  OUTPUT, ' +
             '@cSKUDescr        NVARCHAR(60)  OUTPUT, ' +
             '@cLoc             NVARCHAR(10)  OUTPUT, ' +
             '@cLot             NVARCHAR(10)  OUTPUT, ' +
             '@cLottable01      NVARCHAR(18)  OUTPUT, ' +
             '@cLottable02      NVARCHAR(18)  OUTPUT, ' +
             '@cLottable03      NVARCHAR(18)  OUTPUT, ' +
             '@dLottable04      DATETIME      OUTPUT, ' +
             '@dLottable05      DATETIME      OUTPUT, ' +
             '@nTotalOrder      INT           OUTPUT, ' +
             '@nTotalQty        INT           OUTPUT, ' +
             '@cPDDropID        NVARCHAR(20)  OUTPUT, ' +
             '@cPDLoc           NVARCHAR(20)  OUTPUT, ' +
             '@cPDToLoc         NVARCHAR(20)  OUTPUT, ' +
             '@cPDID            NVARCHAR(20)  OUTPUT, ' +
             '@cWaveKey         NVARCHAR(10)  OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @cFacility, @cStorerKey, @cCartID, @cUserName, @cLangCode, @cPickZone,
              @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSuggestedSKU OUTPUT, @cSKUDescr OUTPUT, @cLoc OUTPUT, @cLot OUTPUT,
              @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
              @nTotalOrder OUTPUT, @nTotalQty OUTPUT, @cPDDropID OUTPUT, @cPDLoc OUTPUT, @cPDToLoc OUTPUT,
              @cPDID OUTPUT, @cWaveKey OUTPUT
      END
      ELSE
      BEGIN
         EXEC [RDT].[rdt_PTL_OrderPicking_GetNextTask]
              @nMobile          = @nMobile
             ,@nFunc            = @nFunc
             ,@cFacility        = @cFacility
             ,@cStorerKey       = @cStorerKey
             ,@cCartID          = @cCartID
             ,@cUserName        = @cUserName
             ,@cLangCode        = @cLangCode
             ,@cPickZone        = @cPickZone    -- (james04)
             ,@nErrNo           = @nErrNo       OUTPUT
             ,@cErrMsg          = @cErrMsg      OUTPUT -- screen limitation, 20 char max
             ,@cSKU             = @cSuggestedSKU OUTPUT
             ,@cSKUDescr        = @cSKUDescr    OUTPUT
             ,@cLoc             = @cLoc         OUTPUT
             ,@cLot             = @cLot         OUTPUT
             ,@cLottable01      = @cLottable01  OUTPUT
             ,@cLottable02      = @cLottable02  OUTPUT
             ,@cLottable03      = @cLottable03  OUTPUT
             ,@dLottable04      = @dLottable04  OUTPUT
             ,@dLottable05      = @dLottable05  OUTPUT
             ,@nTotalOrder      = @nTotalOrder  OUTPUT
             ,@nTotalQty        = @nTotalQty    OUTPUT
             ,@cPDDropID        = @cPDDropID    OUTPUT
             ,@cPDLoc           = @cPDLoc       OUTPUT
             ,@cPDToLoc         = @cPDToLoc     OUTPUT
             ,@cPDID            = @cPDID        OUTPUT -- (ChewKP01)
             ,@cWaveKey         = @cWaveKey     OUTPUT -- (ChewKP01)
      END

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = 79801 -- No More Task! Goto Screen 1
         BEGIN
            -- UPDATE DeviceProfileLog.Status = 9
            UPDATE dbo.DeviceProfileLog WITH (ROWLOCK) -- (james06)
               SET Status = '9'
            FROM dbo.DeviceProfileLog DL
            INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey
            WHERE D.DeviceID = @cCartID
            AND D.Status = '3'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 79623
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDPLogFailed'
               SET @cOutField01 = @cCartID
               SET @cOutField02 = @cPickZone
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Quit
            END

            -- UPDATE DeviceProfile.Status = 9
            UPDATE dbo.DeviceProfile WITH (ROWLOCK)   -- (james06)
            SET Status = '9', DeviceProfileLogKey = ''
            WHERE DeviceID = @cCartID
              AND Status = '3'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 79622
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDPFailed'
               SET @cOutField01 = @cCartID
               SET @cOutField02 = @cPickZone
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Quit
            END

            SET @cOutField01 = @cCartID
            SET @cOutField02 = @cPickZone
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END
         ELSE
         BEGIN
--         IF @nErrNo Not Between 80451 AND  80500 -- IF It is DPC Message Range Get Message Directly
--         BEGIN
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
--         END
--         ELSE
--         BEGIN
--            SET @cErrMsg = LEFT(@cErrMsg,125)
--         END

            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            SET @cOutField01 = @cCartID
            SET @cOutField02 = @cPickZone
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END
      END

      -- (james07)
      SET @cExtendedInfo2Disp01 = ''
      SET @cExtendedInfo2Disp02 = ''
      SET @cDispStyleColorSize = rdt.RDTGetConfig( @nFunc, 'DispStyleColorSize', @cStorerKey)

      -- If not setup config, default display sku descr
      IF @cDispStyleColorSize IN ('', '0')
      BEGIN
         SET @cExtendedInfo2Disp01 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cExtendedInfo2Disp02 = SUBSTRING( @cSKUDescr, 21, 20)
      END

      -- If config setup but svalue = 1 then default display style + color + size
      IF  @cDispStyleColorSize = '1' -- (james10)
      BEGIN
         SELECT @cStyle = Style,
                @cColor = Color,
                @cSize = [Size]
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSuggestedSKU

         SET @cExtendedInfo2Disp01 = @cStyle
         SET @cExtendedInfo2Disp02 = RTRIM( @cColor) + ', ' + RTRIM( @cSize)
      END
      -- If config setup and len(svalue) > 1 then use customised sp to retrieve extended value
      ELSE
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDispStyleColorSize AND type = 'P')
         BEGIN
            SET @nErrNo = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDispStyleColorSize) +
               ' @nMobile, @nFunc, @nStep, @nInputKey, @cStorerKey, @cCartID, @cPickZone, @cLoc, @cSKU, @cLottable02, @dLottable04, @cPDDropID, ' +
               ' @c_oFieled01 OUTPUT, @c_oFieled02 OUTPUT, @c_oFieled03 OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT, ' +
               '@nFunc        INT, ' +
               '@nStep        INT, ' +
               '@nInputKey    INT, ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cCartID      NVARCHAR( 10), ' +
               '@cPickZone    NVARCHAR( 10), ' +
               '@cLoc         NVARCHAR( 10), ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@cLottable02  NVARCHAR( 18), ' +
               '@dLottable04  DATETIME,  ' +
               '@cPDDropID    NVARCHAR( 20), ' +
               '@c_oFieled01  NVARCHAR( 20)  OUTPUT, ' +
               '@c_oFieled02  NVARCHAR( 20)  OUTPUT, ' +
               '@c_oFieled03  NVARCHAR( 20)  OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @nStep, @nInputKey, @cStorerKey, @cCartID, @cPickZone, @cLoc, @cSuggestedSKU, @cLottable02, @dLottable04, @cPDDropID,
               @c_oFieled01 OUTPUT, @c_oFieled02 OUTPUT, @c_oFieled03 OUTPUT

            SET @cExtendedInfo2Disp01 = @c_oFieled01
            SET @cExtendedInfo2Disp02 = @c_oFieled02
         END
      END

      -- Prepare Next Screen Variable
      SET @cOutField01 = @cCartID
      SET @cOutField02 = @cLoc
      SET @cOutField03 = @cSuggestedSKU
      SET @cOutField04 = ''
      SET @cOutField05 = @cExtendedInfo2Disp01
      SET @cOutField06 = @cExtendedInfo2Disp02
      SET @cOutField07 = @cLottable02
      SET @cOutField08 = RDT.RDTFormatDate(@dLottable04)
      SET @cOutfield09 = @nTotalOrder
      SET @cOutfield10 = @nTotalQty
      SET @cOutfield11 = @cPDDropID

      SET @cOutfield13 = @cPDID    -- (ChewKP01)

      -- (ChewKP01)
      SET @cShowWave = ''
      SET @cShowWave = rdt.RDTGetConfig( @nFunc, 'ShowWave', @cStorerKey)

      IF @cShowWave = '1'
      BEGIN
         IF @cPDToLoc <> ''
         BEGIN
            SET @cOutfield12 = 'Wavekey: ' + @cWaveKey -- (ChewKP01)
         END
         ELSE
         BEGIN
            SET @cOutfield12 = '' -- (ChewKP01)
         END
      END
      ELSE
      BEGIN
         SET @cOutfield12 = 'PK ZONE: ' + @cPickZone -- (james04)
      END

      -- GOTO Next Screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      EXEC rdt.rdtSetFocusField @nMobile, 4
   END  -- Inputkey = 1


   IF @nInputKey = 0
   BEGIN
      -- EventLog - Sign In Function
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
      SET @cOutField02 = ''
   END
   GOTO Quit

   STEP_1_FAIL:
   BEGIN
      SET @cOutField01 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
END
GOTO QUIT

/********************************************************************************
Step 2. Scn = 3461.
   CartID   (field01)
   Loc (field02)
   Suggested SKU (field03)
   SKU           (field04, input)
   SKU Descr 1   (field05)
   SKU Descr 2   (field06)
   Lottable02    (field07)
   Lottable03    (field08)
   TotalOrder    (field09)
   TotalQty      (field10)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- (james01)
      SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)
      IF @cDecodeLabelNo = '0'
         SET @cDecodeLabelNo = ''

      IF ISNULL( @cDecodeLabelNo, '') <> '' AND ISNULL( @cInField04, '') <> ''
      BEGIN
         SET @c_LabelNo = @cInField04

         EXEC dbo.ispLabelNo_Decoding_Wrapper
             @c_SPName     = @cDecodeLabelNo
            ,@c_LabelNo    = @c_LabelNo
            ,@c_Storerkey  = @cStorerKey
            ,@c_ReceiptKey = @nMobile
            ,@c_POKey      = ''
            ,@c_LangCode   = @cLangCode
            ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU
            ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE
            ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR
            ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE
            ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY
            ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- CO#
            ,@c_oFieled07  = @c_oFieled07 OUTPUT
            ,@c_oFieled08  = @c_oFieled08 OUTPUT
            ,@c_oFieled09  = @c_oFieled09 OUTPUT
            ,@c_oFieled10  = @c_oFieled10 OUTPUT
            ,@b_Success    = @b_Success   OUTPUT
            ,@n_ErrNo      = @nErrNo      OUTPUT
            ,@c_ErrMsg     = @cErrMsg     OUTPUT

         IF ISNULL(@cErrMsg, '') <> ''
            GOTO Step_2_Fail

         SET @cSKU = @c_oFieled01
      END
      ELSE
         SET @cSKU = ISNULL(RTRIM(@cInField04),'')

      -- if rdt config turned on then should regard it as user scan the expected 2D barcode and go to next screen,
      -- this is due to when picking, if one SKU has 0 qty in the location to be scanned,
      -- we need to have a way to skip the scanning of this location & SKU then operation can continue the picking
      -- for other location & SKU, in addition, operation also want to know this SKU affects which totes,
      -- they need to collect the information from screen 3
      IF rdt.RDTGetConfig( @nFunc, 'PTLAllowSKipTask', @cStorerKey) = 1 AND ISNULL( @cInField04, '') = ''
      BEGIN
         IF rdt.RDTGetConfig( @nFunc, 'PTLSKipTaskWithReasonCode', @cStorerKey) = 1
         BEGIN
            SET @cExtendedLightUpSP = rdt.RDTGetConfig( @nFunc, 'ExtendedLightUp_SP', @cStorerKey)
            IF @cExtendedLightUpSP NOT IN ('0', '')
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedLightUpSP AND type = 'P')
               BEGIN
                  SET @cSKU = @cSuggestedSKU
                  SET @cResult01   = ''
                  SET @cResult02   = ''
                  SET @cResult03   = ''
                  SET @cResult04   = ''
                  SET @cResult05   = ''
                  SET @cResult06   = ''
                  SET @cResult07   = ''
                  SET @cResult08   = ''
                  SET @cResult09   = ''
                  SET @cResult10   = ''

                  SET @nErrNo = 0
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedLightUpSP) +
                     ' @nMobile, @nFunc, @cFacility, @cStorerKey, @cCartID, @cSKU, @cLoc, @cLot, @cPDDropID, @cPDLoc,
                       @cPDToLoc, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, @cPDID, @cWaveKey,
                       @cResult01 OUTPUT, @cResult02 OUTPUT, @cResult03 OUTPUT, @cResult04 OUTPUT, @cResult05 OUTPUT,
                       @cResult06 OUTPUT, @cResult07 OUTPUT, @cResult08 OUTPUT, @cResult09 OUTPUT, @cResult10 OUTPUT,
                       @cUserName, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT '
                  SET @cSQLParam =
                     '@nMobile     INT, ' +
                     '@nFunc       INT, ' +
                     '@cFacility   NVARCHAR( 5),  ' +
                     '@cStorerKey  NVARCHAR( 15), ' +
                     '@cCartID     NVARCHAR( 10), ' +
      '@cSKU        NVARCHAR( 20), ' +
                     '@cLoc        NVARCHAR( 10), ' +
                     '@cLot        NVARCHAR( 10), ' +
                     '@cPDDropID   NVARCHAR( 20), ' +
                     '@cPDLoc      NVARCHAR( 10), ' +
                     '@cPDToLoc    NVARCHAR( 10), ' +
                     '@cLottable01 NVARCHAR( 18), ' +
                     '@cLottable02 NVARCHAR( 18), ' +
                     '@cLottable03 NVARCHAR( 18), ' +
                     '@dLottable04 DATETIME, ' +
                     '@dLottable05 DATETIME, ' +
                     '@cPDID       NVARCHAR( 18), ' +
                     '@cWaveKey    NVARCHAR( 10), ' +
                     '@cResult01   NVARCHAR( 20) OUTPUT, ' +
                     '@cResult02   NVARCHAR( 20) OUTPUT, ' +
                     '@cResult03   NVARCHAR( 20) OUTPUT, ' +
                     '@cResult04   NVARCHAR( 20) OUTPUT, ' +
                     '@cResult05   NVARCHAR( 20) OUTPUT, ' +
                     '@cResult06   NVARCHAR( 20) OUTPUT, ' +
                     '@cResult07   NVARCHAR( 20) OUTPUT, ' +
                     '@cResult08   NVARCHAR( 20) OUTPUT, ' +
                     '@cResult09   NVARCHAR( 20) OUTPUT, ' +
                     '@cResult10   NVARCHAR( 20) OUTPUT, ' +
                     '@cUserName   NVARCHAR( 18), ' +
                     '@cLangCode   NVARCHAR( 3),  ' +
                     '@nErrNo      INT OUTPUT, ' +
                     '@cErrMsg     NVARCHAR( 20) OUTPUT '

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cFacility, @cStorerKey, @cCartID, @cSKU, @cLoc, @cLot, @cPDDropID, @cPDLoc,
                     @cPDToLoc, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, @cPDID, @cWaveKey,
                     @cResult01 OUTPUT, @cResult02 OUTPUT, @cResult03 OUTPUT, @cResult04 OUTPUT, @cResult05 OUTPUT,
                     @cResult06 OUTPUT, @cResult07 OUTPUT, @cResult08 OUTPUT, @cResult09 OUTPUT, @cResult10 OUTPUT,
                     @cUserName, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                  BEGIN
                     SET @cErrMsg = LEFT (@cErrMsg,1024)
                     GOTO Step_2_Fail
                  END

                  EXEC RDT.rdt_STD_EventLog
                    @cActionType = '3',
                    @cUserID     = @cUserName,
                    @nMobileNo   = @nMobile,
                    @nFunctionID = @nFunc,
                    @cFacility   = @cFacility,
                    @cStorerKey  = @cStorerkey,
                    @cDeviceID   = @cCartID,
                    @cSKU        = @cSKU,
                    @nStep       = @nStep

                  -- Prepare Next Screen Variable
                  SET @cOutField01 = ''
                  SET @cOutField02 = @cResult01
                  SET @cOutField03 = @cResult02
                  SET @cOutField04 = @cResult03
                  SET @cOutField05 = @cResult04
                  SET @cOutField06 = @cResult05
                  SET @cOutField07 = @cResult06
                  SET @cOutField08 = @cResult07
                  SET @cOutField09 = @cResult08
                  SET @cOutField10 = @cResult09
                  SET @cOutField11 = @cResult10

                  -- Remember current step & scn
                  SET @nPrevScn = @nScn
                  SET @nPrevStep = @nStep

                  -- GOTO Next Screen
                  SET @nScn  = @nScnReasonCode
                  SET @nStep = @nStepReasonCode

                  GOTO Quit
               END
            END
         END
         ELSE     -- skip task without reason code
         BEGIN
            SET @nErrNo = 0
            SET @cPTL_GetNextTaskSP = rdt.RDTGetConfig( @nFunc, 'PTL_GetNextTaskSP', @cStorerKey)
            IF @cPTL_GetNextTaskSP NOT IN ('0', '') AND
               EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPTL_GetNextTaskSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cPTL_GetNextTaskSP) +
                   ' @nMobile, @nFunc, @cFacility, @cStorerKey, @cCartID, @cUserName, @cLangCode, @cPickZone,
                     @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSKU OUTPUT, @cSKUDescr OUTPUT, @cLoc OUTPUT, @cLot OUTPUT,
                     @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
                     @nTotalOrder OUTPUT, @nTotalQty OUTPUT, @cPDDropID OUTPUT, @cPDLoc OUTPUT, @cPDToLoc OUTPUT,
                     @cPDID OUTPUT, @cWaveKey OUTPUT '
               SET @cSQLParam =
                   '@nMobile          INT, ' +
                   '@nFunc            INT, ' +
                   '@cFacility        NVARCHAR(5), ' +
                   '@cStorerKey       NVARCHAR( 15), ' +
                   '@cCartID          NVARCHAR( 10), ' +
                   '@cUserName        NVARCHAR( 18), ' +
                   '@cLangCode        NVARCHAR( 3), ' +
                   '@cPickZone        NVARCHAR( 10), ' +
                   '@nErrNo           INT           OUTPUT, ' +
                   '@cErrMsg          NVARCHAR(250) OUTPUT, ' + -- screen limitation, 20 char max
                   '@cSKU    NVARCHAR(20)  OUTPUT, ' +
                   '@cSKUDescr        NVARCHAR(60)  OUTPUT, ' +
                   '@cLoc             NVARCHAR(10)  OUTPUT, ' +
                   '@cLot             NVARCHAR(10)  OUTPUT, ' +
                   '@cLottable01      NVARCHAR(18)  OUTPUT, ' +
                   '@cLottable02      NVARCHAR(18)  OUTPUT, ' +
                   '@cLottable03      NVARCHAR(18)  OUTPUT, ' +
                   '@dLottable04      DATETIME      OUTPUT, ' +
                   '@dLottable05      DATETIME      OUTPUT, ' +
                   '@nTotalOrder      INT           OUTPUT, ' +
                   '@nTotalQty        INT           OUTPUT, ' +
                   '@cPDDropID        NVARCHAR(20)  OUTPUT, ' +
                   '@cPDLoc           NVARCHAR(20)  OUTPUT, ' +
                   '@cPDToLoc         NVARCHAR(20)  OUTPUT, ' +
                   '@cPDID            NVARCHAR(20)  OUTPUT, ' +
                   '@cWaveKey         NVARCHAR(10)  OUTPUT '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                    @nMobile, @nFunc, @cFacility, @cStorerKey, @cCartID, @cUserName, @cLangCode, @cPickZone,
                    @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSuggestedSKU OUTPUT, @cSKUDescr OUTPUT, @cLoc OUTPUT, @cLot OUTPUT,
                    @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
                    @nTotalOrder OUTPUT, @nTotalQty OUTPUT, @cPDDropID OUTPUT, @cPDLoc OUTPUT, @cPDToLoc OUTPUT,
                    @cPDID OUTPUT, @cWaveKey OUTPUT
            END
            ELSE
            BEGIN
               SET @cSKU = @cSuggestedSKU
               EXEC [RDT].[rdt_PTL_OrderPicking_GetNextTask]
                    @nMobile          = @nMobile
                   ,@nFunc            = @nFunc
                   ,@cFacility        = @cFacility
                   ,@cStorerKey       = @cStorerKey
                   ,@cCartID          = @cCartID
                   ,@cUserName        = @cUserName
                   ,@cLangCode        = @cLangCode
                   ,@cPickZone        = @cPickZone    -- (james04)
                   ,@nErrNo           = @nErrNo       OUTPUT
                   ,@cErrMsg          = @cErrMsg      OUTPUT -- screen limitation, 20 char max
                   ,@cSKU             = @cSuggestedSKU OUTPUT
                   ,@cSKUDescr        = @cSKUDescr    OUTPUT
                   ,@cLoc             = @cLoc         OUTPUT
                   ,@cLot           = @cLot         OUTPUT
                   ,@cLottable01      = @cLottable01  OUTPUT
                   ,@cLottable02      = @cLottable02  OUTPUT
                   ,@cLottable03      = @cLottable03  OUTPUT
                   ,@dLottable04      = @dLottable04  OUTPUT
                   ,@dLottable05      = @dLottable05  OUTPUT
                   ,@nTotalOrder      = @nTotalOrder  OUTPUT
                   ,@nTotalQty        = @nTotalQty    OUTPUT
                   ,@cPDDropID        = @cPDDropID    OUTPUT
                   ,@cPDLoc           = @cPDLoc       OUTPUT
                   ,@cPDToLoc         = @cPDToLoc     OUTPUT
                   ,@cPDID            = @cPDID        OUTPUT -- (ChewKP01)
                   ,@cWaveKey         = @cWaveKey     OUTPUT -- (ChewKP01)
            END

            IF @nErrNo <> 0
            BEGIN
               IF @nErrNo = 79801 -- No More Task! Goto Screen 1
               BEGIN
                  -- UPDATE DeviceProfileLog.Status = 9
                  UPDATE dbo.DeviceProfileLog WITH (ROWLOCK)  -- (james06)
                     SET Status = '9'
                  FROM dbo.DeviceProfileLog DL
                  INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey
                  WHERE D.DeviceID = @cCartID
                  AND D.Status = '3'

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 79623
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDPLogFailed'
                     SET @cOutField01 = @cCartID
                     SET @cOutField02 = @cPickZone
                     EXEC rdt.rdtSetFocusField @nMobile, 1
                     GOTO Quit
                  END

                  -- UPDATE DeviceProfile.Status = 9
                  UPDATE dbo.DeviceProfile WITH (ROWLOCK)   -- (james06)
                  SET Status = '9', DeviceProfileLogKey = ''
                  WHERE DeviceID = @cCartID
                    AND Status = '3'

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 79622
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDPFailed'
                     SET @cOutField01 = @cCartID
                     SET @cOutField02 = @cPickZone
                     EXEC rdt.rdtSetFocusField @nMobile, 1
                     GOTO Quit
                  END

                  SET @cOutField01 = @cCartID
                  SET @cOutField02 = @cPickZone
                  EXEC rdt.rdtSetFocusField @nMobile, 1
                  GOTO Quit
               END
               ELSE
               BEGIN
      --         IF @nErrNo Not Between 80451 AND  80500 -- IF It is DPC Message Range Get Message Directly
      --         BEGIN
      --            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
      --         END
      --         ELSE
      --         BEGIN
      --            SET @cErrMsg = LEFT(@cErrMsg,125)
      --         END

                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  SET @cOutField01 = @cCartID
                  SET @cOutField02 = @cPickZone
                  EXEC rdt.rdtSetFocusField @nMobile, 1
                  GOTO Quit
               END
            END

            -- (james07)
            SET @cExtendedInfo2Disp01 = ''
            SET @cExtendedInfo2Disp02 = ''
            SET @cDispStyleColorSize = rdt.RDTGetConfig( @nFunc, 'DispStyleColorSize', @cStorerKey)

            -- If not setup config, default display sku descr
            IF @cDispStyleColorSize IN ('', '0')
            BEGIN
               SET @cExtendedInfo2Disp01 = SUBSTRING( @cSKUDescr, 1, 20)
               SET @cExtendedInfo2Disp02 = SUBSTRING( @cSKUDescr, 21, 20)
            END

            -- If config setup but svalue = 1 then default display style + color + size
            IF @cDispStyleColorSize = '1'
            BEGIN
               SELECT @cStyle = Style,
                      @cColor = Color,
                      @cSize = [Size]
               FROM dbo.SKU WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   SKU = @cSuggestedSKU

               SET @cExtendedInfo2Disp01 = @cStyle
               SET @cExtendedInfo2Disp02 = RTRIM( @cColor) + ', ' + RTRIM( @cSize)
            END
            -- If config setup and len(svalue) > 1 then use customised sp to retrieve extended value
            ELSE
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDispStyleColorSize AND type = 'P')
               BEGIN
                  SET @nErrNo = 0
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cDispStyleColorSize) +
                     ' @nMobile, @nFunc, @nStep, @nInputKey, @cStorerKey, @cCartID, @cPickZone, @cLoc, @cSKU, @cLottable02, @dLottable04, @cPDDropID, ' +
                     ' @c_oFieled01 OUTPUT, @c_oFieled02 OUTPUT, @c_oFieled03 OUTPUT'
                  SET @cSQLParam =
                     '@nMobile      INT, ' +
                     '@nFunc        INT, ' +
                     '@nStep        INT, ' +
                     '@nInputKey    INT, ' +
                     '@cStorerKey   NVARCHAR( 15), ' +
                     '@cCartID      NVARCHAR( 10), ' +
                     '@cPickZone    NVARCHAR( 10), ' +
                     '@cLoc         NVARCHAR( 10), ' +
                     '@cSKU         NVARCHAR( 20), ' +
                     '@cLottable02  NVARCHAR( 18), ' +
                     '@dLottable04  DATETIME,  ' +
                     '@cPDDropID    NVARCHAR( 20), ' +
                     '@c_oFieled01  NVARCHAR( 20)  OUTPUT, ' +
                     '@c_oFieled02  NVARCHAR( 20)  OUTPUT, ' +
                     '@c_oFieled03  NVARCHAR( 20)  OUTPUT '

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @nStep, @nInputKey, @cStorerKey, @cCartID, @cPickZone, @cLoc, @cSuggestedSKU, @cLottable02, @dLottable04, @cPDDropID,
                     @c_oFieled01 OUTPUT, @c_oFieled02 OUTPUT, @c_oFieled03 OUTPUT

                  SET @cExtendedInfo2Disp01 = @cExtendedInfo2Disp01
                  SET @cExtendedInfo2Disp02 = @cExtendedInfo2Disp02
               END
            END

            -- Prepare Next Screen Variable
            SET @cOutField01 = @cCartID
            SET @cOutField02 = @cLoc
            SET @cOutField03 = @cSuggestedSKU
            SET @cOutField04 = ''
            SET @cOutField05 = SUBSTRING( @cSKUDescr, 1, 20)
            SET @cOutField06 = SUBSTRING( @cSKUDescr, 21, 20)
            SET @cOutField07 = @cLottable02
            SET @cOutField08 = RDT.RDTFormatDate(@dLottable04)
            SET @cOutfield09 = @nTotalOrder
            SET @cOutfield10 = @nTotalQty
            SET @cOutfield11 = @cPDDropID

            SET @cOutfield13 = @cPDID    -- (ChewKP01)

            -- (ChewKP01)
            SET @cShowWave = ''
            SET @cShowWave = rdt.RDTGetConfig( @nFunc, 'ShowWave', @cStorerKey)

            IF @cShowWave = '1'
            BEGIN
               IF @cPDToLoc <> ''
               BEGIN
                  SET @cOutfield12 = 'Wavekey: ' + @cWaveKey -- (ChewKP01)
               END
               ELSE
               BEGIN
                  SET @cOutfield12 = '' -- (ChewKP01)
               END
            END
            ELSE
            BEGIN
               SET @cOutfield12 = 'PK ZONE: ' + @cPickZone -- (james04)
            END

            EXEC rdt.rdtSetFocusField @nMobile, 4
         END
      END

      IF ISNULL(@cSKU, '') = ''
      BEGIN
         SET @nErrNo = 79603
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU Req'
         GOTO Step_2_Fail
      END

      EXEC rdt.rdt_GETSKUCNT
          @cStorerkey  = @cStorerKey
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Check SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 79620
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
         GOTO Step_2_Fail
      END

      EXEC dbo.nspg_GETSKU
         @cStorerKey
         ,  @cSKU       OUTPUT
         ,              @b_Success  OUTPUT
         ,              @nErrNo     OUTPUT
         ,              @cErrMsg    OUTPUT

      IF @b_success = 0
      BEGIN
         SET @nErrNo = 79621
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_2_Fail
      END

      IF @cSKU <> @cSuggestedSKU
      BEGIN
         SET @nErrNo = 79604
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_2_Fail
      END

      SET @cExtendedLightUpSP = rdt.RDTGetConfig( @nFunc, 'ExtendedLightUp_SP', @cStorerKey)
      IF @cExtendedLightUpSP NOT IN ('0', '')
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedLightUpSP AND type = 'P')
         BEGIN
            SET @cResult01   = ''
            SET @cResult02   = ''
            SET @cResult03   = ''
            SET @cResult04   = ''
            SET @cResult05   = ''
            SET @cResult06   = ''
            SET @cResult07   = ''
            SET @cResult08   = ''
            SET @cResult09   = ''
            SET @cResult10   = ''

            SET @nErrNo = 0

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedLightUpSP) +
               ' @nMobile, @nFunc, @cFacility, @cStorerKey, @cCartID, @cSKU, @cLoc, @cLot, @cPDDropID, @cPDLoc,
                 @cPDToLoc, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, @cPDID, @cWaveKey,
                 @cResult01 OUTPUT, @cResult02 OUTPUT, @cResult03 OUTPUT, @cResult04 OUTPUT, @cResult05 OUTPUT,
                 @cResult06 OUTPUT, @cResult07 OUTPUT, @cResult08 OUTPUT, @cResult09 OUTPUT, @cResult10 OUTPUT,
                 @cUserName, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile     INT, ' +
               '@nFunc       INT, ' +
               '@cFacility   NVARCHAR( 5),  ' +
               '@cStorerKey  NVARCHAR( 15), ' +
               '@cCartID     NVARCHAR( 10), ' +
               '@cSKU        NVARCHAR( 20), ' +
               '@cLoc        NVARCHAR( 10), ' +
               '@cLot        NVARCHAR( 10), ' +
               '@cPDDropID   NVARCHAR( 20), ' +
               '@cPDLoc      NVARCHAR( 10), ' +
               '@cPDToLoc    NVARCHAR( 10), ' +
               '@cLottable01 NVARCHAR( 18), ' +
               '@cLottable02 NVARCHAR( 18), ' +
               '@cLottable03 NVARCHAR( 18), ' +
               '@dLottable04 DATETIME, ' +
               '@dLottable05 DATETIME, ' +
               '@cPDID       NVARCHAR( 18), ' +
               '@cWaveKey    NVARCHAR( 10), ' +
               '@cResult01   NVARCHAR( 20) OUTPUT, ' +
               '@cResult02   NVARCHAR( 20) OUTPUT, ' +
               '@cResult03   NVARCHAR( 20) OUTPUT, ' +
               '@cResult04   NVARCHAR( 20) OUTPUT, ' +
               '@cResult05   NVARCHAR( 20) OUTPUT, ' +
               '@cResult06   NVARCHAR( 20) OUTPUT, ' +
               '@cResult07   NVARCHAR( 20) OUTPUT, ' +
               '@cResult08   NVARCHAR( 20) OUTPUT, ' +
               '@cResult09   NVARCHAR( 20) OUTPUT, ' +
               '@cResult10   NVARCHAR( 20) OUTPUT, ' +
               '@cUserName   NVARCHAR( 18), ' +
               '@cLangCode   NVARCHAR( 3),  ' +
               '@nErrNo      INT OUTPUT, ' +
               '@cErrMsg     NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cFacility, @cStorerKey, @cCartID, @cSKU, @cLoc, @cLot, @cPDDropID, @cPDLoc,
               @cPDToLoc, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, @cPDID, @cWaveKey,
               @cResult01 OUTPUT, @cResult02 OUTPUT, @cResult03 OUTPUT, @cResult04 OUTPUT, @cResult05 OUTPUT,
               @cResult06 OUTPUT, @cResult07 OUTPUT, @cResult08 OUTPUT, @cResult09 OUTPUT, @cResult10 OUTPUT,
               @cUserName, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = LEFT (@cErrMsg,1024)
               GOTO Step_2_Fail
            END

            EXEC RDT.rdt_STD_EventLog
              @cActionType = '3',
              @cUserID     = @cUserName,
              @nMobileNo   = @nMobile,
              @nFunctionID = @nFunc,
              @cFacility   = @cFacility,
              @cStorerKey  = @cStorerkey,
              @cDeviceID   = @cCartID,
              @cSKU        = @cSKU,
              @nStep       = @nStep


            SET @cOutField01 = @cSKU
            SET @cOutField02 = @cResult01
            SET @cOutField03 = @cResult02
            SET @cOutField04 = @cResult03
            SET @cOutField05 = @cResult04
            SET @cOutField06 = @cResult05
            SET @cOutField07 = @cResult06
            SET @cOutField08 = @cResult07
            SET @cOutField09 = @cResult08
            SET @cOutField10 = @cResult09
            SET @cOutField11 = @cResult10
            SET @cOutField12 = ''

            -- GOTO Previous Screen
            SET @nScn = @nScn + 5
            SET @nStep = @nStep + 5

            EXEC rdt.rdtSetFocusField @nMobile, 12

            GOTO Quit
         END
      END
      ELSE
      BEGIN
         -- Initial Light Command Start
         EXEC [RDT].[rdt_PTL_OrderPicking_LightUp]
            @nMobile     = @nMobile
           ,@nFunc       = @nFunc
           ,@cFacility   = @cFacility
           ,@cStorerKey  = @cStorerKey
           ,@cCartID     = @cCartID
           ,@cSKU        = @cSKU
           ,@cLoc        = @cLoc
           ,@cLot        = @cLot
           ,@cPDDropID   = @cPDDropID
           ,@cPDLoc      = @cPDLoc
           ,@cPDToLoc    = @cPDToLoc
           ,@cLottable01 = @cLottable01  -- (ChewKP01)
           ,@cLottable02 = @cLottable02  -- (ChewKP01)
           ,@cLottable03 = @cLottable03  -- (ChewKP01)
           ,@dLottable04 = @dLottable04  -- (ChewKP01)
           ,@dLottable05 = @dLottable05  -- (ChewKP01)
           ,@cPDID       = @cPDID        -- (CheWKP01)
           ,@cWaveKey    = @cWaveKey     -- (ChewKP01)
           ,@cResult01   = @cResult01      OUTPUT
           ,@cResult02   = @cResult02      OUTPUT
           ,@cResult03   = @cResult03      OUTPUT
           ,@cResult04   = @cResult04      OUTPUT
           ,@cResult05   = @cResult05      OUTPUT
           ,@cResult06   = @cResult06      OUTPUT
           ,@cResult07   = @cResult07      OUTPUT
           ,@cResult08   = @cResult08      OUTPUT
           ,@cResult09   = @cResult09      OUTPUT
           ,@cResult10   = @cResult10      OUTPUT
           ,@cUserName   = @cUserName
           ,@cLangCode   = @cLangCode
           ,@nErrNo      = @nErrNo         OUTPUT
           ,@cErrMsg     = @cErrMsg        OUTPUT -- screen limitation, 20 char max

         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = LEFT (@cErrMsg,1024)
         GOTO Step_2_Fail
         END

         -- Prepare Next Screen Variable
         -- (ChewKP01)
         IF @cShowWave = '1'
         BEGIN
            IF @cPDToLoc <> ''
            BEGIN
               SET @cOutField01 = 'Wavekey: ' + @cWaveKey
            END
            ELSE
            BEGIN
               SET @cOutfield01 = '' -- (ChewKP01)
            END
         END
         ELSE
         BEGIN
             SET @cOutfield01 = ''
         END

         SET @cOutField02 = @cLoc
         SET @cOutField03 = @cSKU
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField06 = @cLottable02
         SET @cOutField07 = RDT.RDTFormatDate(@dLottable04)
         SET @cOutField08 = @cResult01
         SET @cOutField09 = @cResult02
         SET @cOutField10 = @cResult03
         SET @cOutField11 = ''
         SET @cOutField12 = @cPDDropID
         SET @cOutField13 = @cPDID -- (ChewKP01)

         -- GOTO Previous Screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         EXEC rdt.rdtSetFocusField @nMobile, 12
      END
   END  -- Inputkey = 1

   IF @nInputKey = 0
   BEGIN
      -- Prepare Previous Screen Variable
      SET @cOutField01 = ''
      SET @cOutField02 = ''

      -- GOTO Previous Screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
   GOTO Quit

   STEP_2_FAIL:
   BEGIN
      SET @cOutField01 = @cCartID
      SET @cOutField02 = @cLoc
      SET @cOutField03 = @cSuggestedSKU
      SET @cOutField04 = ''
      SET @cOutField05 = @cExtendedInfo2Disp01
      SET @cOutField06 = @cExtendedInfo2Disp02
      SET @cOutField07 = @cLottable02
      SET @cOutField08 = RDT.RDTFormatDate(@dLottable04)
      SET @cOutfield09 = @nTotalOrder
      SET @cOutfield10 = @nTotalQty
      SET @cOutfield11 = @cPDDropID

      EXEC rdt.rdtSetFocusField @nMobile, 4
   END
END
GOTO QUIT


/********************************************************************************
Step 3. Scn = 3462.
   CartID   (field01)
   Loc (field02)
   SKU (field03)
   SKU Descr 1   (field04)
   SKU Descr 2   (field05)
   Lottable02    (field06)
   Lottable03    (field07)
   Lv1           (field08)
   Lv2           (field09)
   Lv3           (field10)
   Option        (field11, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1
   BEGIN

      SET @cOption = ISNULL(RTRIM(@cInField12),'')


--    IF ISNULL(@cOption, '') = ''
--      BEGIN
--         SET @nErrNo = 79605
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option Req'
--         GOTO Step_3_Fail
--      END

      IF @cOption <> ''
      BEGIN
         IF @cOption <> '1'
         BEGIN
            SET @nErrNo = 79606
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidOption'
            GOTO Step_3_Fail
         END

         IF @cOption = '1'
         BEGIN
            -- Prepare Next Screen Variable
            SET @cOutField01 = ''

            -- GOTO Next Screen
            SET @nScn  = @nScnCloseTote
            SET @nStep = @nStepCloseTote

            EXEC rdt.rdtSetFocusField @nMobile, 1

            GOTO QUIT

         END
      END

      -- (james02)
      -- Update ptltran record if config turn on. For those who wanna do simulation without cart
      IF @cDeviceID = ''
      BEGIN
         UPDATE PTL WITH (ROWLOCK) SET
            PTL.Status = '9',
            PTL.Qty = ExpectedQty
         FROM dbo.PtlTran PTL
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PTL.SourceKey = PD.PickDetailKey)  -- (james06)
     WHERE PTL.DeviceID = @cCartID
         AND   PTL.SKU      = @cSKU
         AND   PTL.Loc      = @cLoc
         AND   PTL.Lot      = @cLot
         AND   PD.ID        = @cPDID
         AND   PTL.Status      <= '1'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 79624
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PTLTR FAIL'
            GOTO Step_3_Fail
         END
      END

      -- Check If All Pick Done before Proceed to Next Location / Action
      IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)
                      WHERE DeviceID = @cCartID
                      AND   SKU      = @cSKU
                      AND   Loc      = @cLoc
                      AND   Lot      = @cLot
                      AND   Status = '1' )
      BEGIN
         SET @nErrNo = 79607
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PickNotComplete'
         GOTO Step_3_Fail
      END

      -- If there is any short pick , goto Reason Screen
      IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)
                  WHERE DeviceID = @cCartID
                      AND   SKU      = @cSKU
                      AND   Loc      = @cLoc
                      AND   Lot      = @cLot
                      AND   Status   IN ('5','9')
                      AND   ExpectedQty <> Qty
                      AND   DeviceProfileLogKey = @cDeviceProfileLogKey )
      BEGIN
            -- Prepare Next Screen Variable
            SET @cOutField01 = ''

            -- GOTO Next Screen
            SET @nScn  = @nScnReasonCode
            SET @nStep = @nStepReasonCode

            GOTO QUIT

      END

      -- Get Next Task

      --SET @cSuggestedSKU = ''
      SET @cSKU          = ''
      SET @cSKUDescr     = ''
      --SET @cLoc          = ''

      SET @nTotalOrder   = 0
      SET @nTotalQty     = 0

      -- (ChewKP01)
      SET @cLoc          = ''
      SET @cLot          = ''
      SET @cLottable01   = ''
      SET @cLottable02   = ''
      SET @cLottable03   = ''
      SET @dLottable04   = NULL
      SET @dLottable05   = NULL
      SET @cPDDropID     = ''
      SET @cPDLoc        = ''
      SET @cPDToLoc      = ''
      SET @cPDID         = ''
      SET @cWaveKey      = ''

      SET @nErrNo = 0
      SET @cPTL_GetNextTaskSP = rdt.RDTGetConfig( @nFunc, 'PTL_GetNextTaskSP', @cStorerKey)
      IF @cPTL_GetNextTaskSP NOT IN ('0', '') AND
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPTL_GetNextTaskSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cPTL_GetNextTaskSP) +
             ' @nMobile, @nFunc, @cFacility, @cStorerKey, @cCartID, @cUserName, @cLangCode, @cPickZone,
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSKU OUTPUT, @cSKUDescr OUTPUT, @cLoc OUTPUT, @cLot OUTPUT,
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @nTotalOrder OUTPUT, @nTotalQty OUTPUT, @cPDDropID OUTPUT, @cPDLoc OUTPUT, @cPDToLoc OUTPUT,
               @cPDID OUTPUT, @cWaveKey OUTPUT '
         SET @cSQLParam =
             '@nMobile          INT, ' +
             '@nFunc            INT, ' +
             '@cFacility        NVARCHAR(5), ' +
             '@cStorerKey       NVARCHAR( 15), ' +
             '@cCartID          NVARCHAR( 10), ' +
             '@cUserName        NVARCHAR( 18), ' +
             '@cLangCode        NVARCHAR( 3), ' +
             '@cPickZone        NVARCHAR( 10), ' +
             '@nErrNo           INT           OUTPUT, ' +
             '@cErrMsg          NVARCHAR(250) OUTPUT, ' + -- screen limitation, 20 char max
             '@cSKU    NVARCHAR(20)  OUTPUT, ' +
             '@cSKUDescr        NVARCHAR(60)  OUTPUT, ' +
             '@cLoc             NVARCHAR(10)  OUTPUT, ' +
             '@cLot             NVARCHAR(10)  OUTPUT, ' +
             '@cLottable01      NVARCHAR(18)  OUTPUT, ' +
             '@cLottable02      NVARCHAR(18)  OUTPUT, ' +
             '@cLottable03      NVARCHAR(18)  OUTPUT, ' +
             '@dLottable04      DATETIME      OUTPUT, ' +
             '@dLottable05      DATETIME      OUTPUT, ' +
             '@nTotalOrder      INT           OUTPUT, ' +
             '@nTotalQty        INT           OUTPUT, ' +
             '@cPDDropID        NVARCHAR(20)  OUTPUT, ' +
             '@cPDLoc           NVARCHAR(20)  OUTPUT, ' +
             '@cPDToLoc         NVARCHAR(20)  OUTPUT, ' +
             '@cPDID            NVARCHAR(20)  OUTPUT, ' +
             '@cWaveKey         NVARCHAR(10)  OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @cFacility, @cStorerKey, @cCartID, @cUserName, @cLangCode, @cPickZone,
              @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSuggestedSKU OUTPUT, @cSKUDescr OUTPUT, @cLoc OUTPUT, @cLot OUTPUT,
              @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
              @nTotalOrder OUTPUT, @nTotalQty OUTPUT, @cPDDropID OUTPUT, @cPDLoc OUTPUT, @cPDToLoc OUTPUT,
              @cPDID OUTPUT, @cWaveKey OUTPUT
      END
      ELSE
      BEGIN
         EXEC [RDT].[rdt_PTL_OrderPicking_GetNextTask]
              @nMobile          = @nMobile
             ,@nFunc            = @nFunc
             ,@cFacility        = @cFacility
             ,@cStorerKey       = @cStorerKey
             ,@cCartID          = @cCartID
             ,@cUserName        = @cUserName
             ,@cLangCode        = @cLangCode
             ,@cPickZone        = @cPickZone    -- (james04)
             ,@nErrNo           = @nErrNo       OUTPUT
             ,@cErrMsg          = @cErrMsg      OUTPUT -- screen limitation, 20 char max
             ,@cSKU             = @cSuggestedSKU OUTPUT
             ,@cSKUDescr        = @cSKUDescr    OUTPUT
             ,@cLoc             = @cLoc         OUTPUT
             ,@cLot             = @cLot         OUTPUT
             ,@cLottable01      = @cLottable01  OUTPUT
             ,@cLottable02      = @cLottable02  OUTPUT
             ,@cLottable03      = @cLottable03  OUTPUT
             ,@dLottable04      = @dLottable04  OUTPUT
             ,@dLottable05      = @dLottable05  OUTPUT
             ,@nTotalOrder      = @nTotalOrder  OUTPUT
             ,@nTotalQty        = @nTotalQty    OUTPUT
             ,@cPDDropID        = @cPDDropID    OUTPUT
             ,@cPDLoc           = @cPDLoc       OUTPUT
             ,@cPDToLoc         = @cPDToLoc     OUTPUT
             ,@cPDID            = @cPDID        OUTPUT -- (ChewKP01)
             ,@cWaveKey         = @cWaveKey     OUTPUT -- (ChewKP01)
      END

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = 79801 -- No More Task! Goto Screen 1
         BEGIN
            -- UPDATE DeviceProfileLog.Status = 9
            UPDATE dbo.DeviceProfileLog WITH (ROWLOCK) -- (james06)
               SET Status = '9'
            FROM dbo.DeviceProfileLog DL
            INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey
            WHERE D.DeviceID = @cCartID
            AND D.Status = '3'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 79617
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDPLogFailed'
               GOTO Step_3_Fail
            END

            -- UPDATE DeviceProfile.Status = 9
            UPDATE dbo.DeviceProfile WITH (ROWLOCK)   -- (james06)
            SET Status = '9', DeviceProfileLogKey = ''
            WHERE DeviceID = @cCartID
              AND Status = '3'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 79616
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDPFailed'
               GOTO Step_3_Fail
            END


            SET @cOutField01 = ''
            SET @cOutField02 = ''

            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2

            GOTO QUIT

         END
         ELSE
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_3_Fail
         END
      END

      -- (james07)
      SET @cExtendedInfo2Disp01 = ''
      SET @cExtendedInfo2Disp02 = ''
      SET @cDispStyleColorSize = rdt.RDTGetConfig( @nFunc, 'DispStyleColorSize', @cStorerKey)

      -- If not setup config, default display sku descr
      IF @cDispStyleColorSize IN ('', '0')
      BEGIN
         SET @cExtendedInfo2Disp01 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cExtendedInfo2Disp02 = SUBSTRING( @cSKUDescr, 21, 20)
      END

      -- If config setup but svalue = 1 then default display style + color + size
      IF @cDispStyleColorSize = '1'
      BEGIN
         SELECT @cStyle = Style,
                @cColor = Color,
                @cSize = [Size]
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSuggestedSKU

         SET @cExtendedInfo2Disp01 = @cStyle
         SET @cExtendedInfo2Disp02 = RTRIM( @cColor) + ', ' + RTRIM( @cSize)
      END
      -- If config setup and len(svalue) > 1 then use customised sp to retrieve extended value
      ELSE
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDispStyleColorSize AND type = 'P')
         BEGIN
            SET @nErrNo = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDispStyleColorSize) +
               ' @nMobile, @nFunc, @nStep, @nInputKey, @cStorerKey, @cCartID, @cPickZone, @cLoc, @cSKU, @cLottable02, @dLottable04, @cPDDropID, ' +
               ' @c_oFieled01 OUTPUT, @c_oFieled02 OUTPUT, @c_oFieled03 OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT, ' +
               '@nFunc        INT, ' +
               '@nStep        INT, ' +
               '@nInputKey    INT, ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cCartID      NVARCHAR( 10), ' +
               '@cPickZone    NVARCHAR( 10), ' +
               '@cLoc         NVARCHAR( 10), ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@cLottable02  NVARCHAR( 18), ' +
               '@dLottable04  DATETIME,  ' +
               '@cPDDropID    NVARCHAR( 20), ' +
               '@c_oFieled01  NVARCHAR( 20)  OUTPUT, ' +
               '@c_oFieled02  NVARCHAR( 20)  OUTPUT, ' +
               '@c_oFieled03  NVARCHAR( 20)  OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @nStep, @nInputKey, @cStorerKey, @cCartID, @cPickZone, @cLoc, @cSuggestedSKU, @cLottable02, @dLottable04, @cPDDropID,
               @c_oFieled01 OUTPUT, @c_oFieled02 OUTPUT, @c_oFieled03 OUTPUT

            SET @cExtendedInfo2Disp01 = @c_oFieled01
            SET @cExtendedInfo2Disp02 = @c_oFieled02
         END
      END

      -- Prepare Next Screen Variable
      SET @cOutField01 = @cCartID
      SET @cOutField02 = @cLoc
      SET @cOutField03 = @cSuggestedSKU
      SET @cOutField04 = ''
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField06 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField07 = @cLottable02
      SET @cOutField08 = RDT.RDTFormatDate(@dLottable04)
      SET @cOutfield09 = @nTotalOrder
      SET @cOutfield10 = @nTotalQty
      SET @cOutfield11 = @cPDDropID

      SET @cOutfield13 = @cPDID    -- (ChewKP01)

  -- (ChewKP01)
      IF @cShowWave = '1'
      BEGIN
         IF @cPDToLoc <> ''
         BEGIN
            SET @cOutfield12 = 'Wavekey: ' + @cWaveKey -- (ChewKP01)
         END
         ELSE
         BEGIN
            SET @cOutfield12 = '' -- (ChewKP01)
         END
      END
      ELSE
      BEGIN
          SET @cOutfield12 = '' -- (ChewKP01)
      END

      -- GOTO Previous Screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      EXEC rdt.rdtSetFocusField @nMobile, 4

   END  -- Inputkey = 1

   IF @nInputKey = 0
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)
                    WHERE DeviceID = @cCartID
                    AND Status = '1'
                    AND DeviceProfileLogKey = @cDeviceProfileLogKey )
      BEGIN

       -- Update PTLTran
       UPDATE dbo.PTLTran WITH (ROWLOCK) -- (james06)
       SET Status = '0'
       WHERE DeviceID = @cCartID AND Status = '1'

      END

      SET @cOutField01 = @cCartID
      SET @cOutField02 = @cLoc
      SET @cOutField03 = @cSuggestedSKU
      SET @cOutField04 = ''
      SET @cOutField05 = @cExtendedInfo2Disp01
      SET @cOutField06 = @cExtendedInfo2Disp02
      SET @cOutField07 = @cLottable02
      SET @cOutField08 = @dLottable04
      SET @cOutfield09 = @nTotalOrder
      SET @cOutfield10 = @nTotalQty

      SET @cOutfield11 = @cPDDropID

      SET @cOutfield13 = @cPDID    -- (ChewKP01)

      -- (ChewKP01)
      IF @cShowWave = '1'
      BEGIN
         IF @cPDToLoc <> ''
         BEGIN
            SET @cOutField12 = 'Wavekey: ' + @cWaveKey
         END
         ELSE
         BEGIN
            SET @cOutfield12 = '' -- (ChewKP01)
         END
      END
      ELSE
      BEGIN
         SET @cOutfield12 = ''
      END

      EXEC rdt.rdtSetFocusField @nMobile, 4

      -- GOTO Previous Screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      -- (james02)
      IF @cDeviceID <> ''
      BEGIN
         -- Initialize LightModules
         EXEC [dbo].[isp_DPC_TerminateAllLight]
            @cStorerKey
            ,@cCartID
            ,@b_Success    OUTPUT
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT

         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = LEFT(@cErrMsg,1024)
            GOTO Quit
         END
      END


   END
   GOTO Quit

   STEP_3_FAIL:
   BEGIN
      SET @cOutField11 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 11
   END
END
GOTO QUIT


/********************************************************************************
Step 4 Scn = 3463.
   Close ToteID        (field01, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1
   BEGIN

      SET @cToteID = ISNULL(RTRIM(@cInField01),'')


      IF ISNULL(@cToteID, '') = ''
      BEGIN
         SET @nErrNo = 79608
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Tote Req'
         GOTO Step_4_Fail
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.DeviceProfileLog DL WITH (NOLOCK)
                     INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey
                     WHERE D.DeviceID = @cCartID
                     AND DL.DropID = @cToteID
                     AND DL.Status = '3' )
      BEGIN
         SET @nErrNo = 79609
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidTote'
         GOTO Step_4_Fail
      END

      SET @cDeviceProfileKey = ''
      SET @cOrderKey         = ''

      SELECT @cDeviceProfileKey = DL.DeviceProfileKey
           , @cOrderKey         = DL.OrderKey
      FROM dbo.DeviceProfileLog DL WITH (NOLOCK)
      INNER JOIN dbo.DeviceProfile D WITH (NOLOCK)  ON D.DeviceProfileKey = DL.DeviceProfileKey
      WHERE D.DeviceID = @cCartID
      AND DL.DropID = @cToteID
      AND DL.Status = '3'

      -- Prepare Next Screen Variable
      SET @cOutField01 = ''

      -- GOTO Next Screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      EXEC rdt.rdtSetFocusField @nMobile, 1

   END  -- Inputkey = 1

   IF @nInputKey = 0
   BEGIN
       -- Prepare Previous Screen Variable
       SET @cOutField01 = @cCartID
       SET @cOutField02 = @cLoc
       SET @cOutField03 = @cSuggestedSKU
       SET @cOutField04 = @cExtendedInfo2Disp01
       SET @cOutField05 = @cExtendedInfo2Disp02
       SET @cOutField06 = @cLottable02
       SET @cOutField07 = RDT.RDTFormatDate(@dLottable04)

       SET @cOutField11 = ''
       EXEC rdt.rdtSetFocusField @nMobile, 11

       -- GOTO Previous Screen
       SET @nScn = @nScn - 1
       SET @nStep = @nStep - 1
   END
   GOTO Quit

   STEP_4_FAIL:
   BEGIN
      SET @cOutField01 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1
   END

END
GOTO QUIT


/********************************************************************************
Step 5 Scn = 3464.
  New ToteID        (field01, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1
   BEGIN

      SET @cNewToteID = ISNULL(RTRIM(@cInField01),'')


      IF ISNULL(@cNewToteID, '') = ''
      BEGIN
         SET @nErrNo = 79610
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Tote Req'
         GOTO Step_5_Fail
      END

      IF EXISTS (SELECT 1 FROM dbo.DeviceProfileLog DL WITH (NOLOCK)
                 INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey
                 WHERE DL.DropID = @cNewToteID
                 AND DL.Status IN ( '0','1','3')
                 AND D.DeviceID <> @cCartID )
      BEGIN
            SET @nErrNo = 79611
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToteAssigned'
            GOTO Step_5_Fail

      END

      IF EXISTS (SELECT 1 FROM dbo.DeviceProfileLog DL WITH (NOLOCK)
                 INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey
                 WHERE DL.DropID = @cNewToteID
                 AND DL.Status IN ( '0','1','3','9')
                 AND D.DeviceID = @cCartID
                 AND DL.DeviceProfileLogKey = @cDeviceProfileLogKey  )
      BEGIN
            SET @nErrNo = 79618
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToteAssigned'
            GOTO Step_5_Fail
      ENd


      -- Update DeviceProfileLog
      UPDATE dbo.DeviceProfileLog WITH (ROWLOCK)   -- (james06)
      SET  UserDefine01 = 'FULL'
          , Status       = '9'
      WHERE DeviceProfileKey = @cDeviceProfileKey
      AND Status = '3'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 79612
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDPLogFail'
         GOTO Step_5_Fail
      END


      -- Insert into LightLoc_Detail Table
      INSERT INTO DeviceProfileLog(DeviceProfileKey, OrderKey, DropID, Status, DeviceProfileLogKey)
      VALUES ( @cDeviceProfileKey, @cOrderKey, @cNewToteID, '3', @cDeviceProfileLogKey)

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 79613
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsLightLocFail'
         GOTO Step_5_Fail
      END

      -- (james09)
      DECLARE @nPTLTranKey BIGINT
      DECLARE CUR_UPDATE_PTLTRAN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PTLKey
      FROM dbo.PTLTran WITH (NOLOCK)
      WHERE DeviceID = @cCartID
      AND DropID = @cToteID
      AND Status <> '9'
      AND DeviceProfileLogKey = @cDeviceProfileLogKey
      OPEN CUR_UPDATE_PTLTRAN
      FETCH NEXT FROM CUR_UPDATE_PTLTRAN INTO @nPTLTranKey
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- Update PTLTran to correct DropID
         UPDATE dbo.PTLTran WITH (ROWLOCK) SET
            DropID = @cNewToteID,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE PTLKey = @nPTLTranKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 79619
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPTLTranFail'
            CLOSE CUR_UPDATE_PTLTRAN
            DEALLOCATE CUR_UPDATE_PTLTRAN
            GOTO Step_5_Fail
         END
         FETCH NEXT FROM CUR_UPDATE_PTLTRAN INTO @nPTLTranKey
      END
      CLOSE CUR_UPDATE_PTLTRAN
      DEALLOCATE CUR_UPDATE_PTLTRAN

/* commented by (james09)
      -- Update PTLTran to correct DropID
      UPDATE PTLTran WITH (ROWLOCK) -- (james06)
      SET DropID = @cNewToteID
      WHERE DeviceID = @cCartID
      AND DropID = @cToteID
      AND Status <> '9'
      AND DeviceProfileLogKey = @cDeviceProfileLogKey

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 79619
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPTLTranFail'
         GOTO Step_5_Fail
      END
*/

      -- Prepare Next Screen Variable
--      SET @cOutField01 = @cCartID
--      SET @cOutField02 = @cLoc
--      SET @cOutField03 = @cSuggestedSKU
--      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
--    SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
--    SET @cOutField06 = @cLottable02
--    SET @cOutField07 = RDT.RDTFormatDate(@dLottable04)
--
--    SET @cOutField11 = ''

      -- (ChewKP01)
      IF @cShowWave = '1'
      BEGIN
         IF @cPDToLoc <> ''
         BEGIN
            SET @cOutField01 = 'Wavekey: ' + @cWaveKey
         END
         ELSE
         BEGIN
            SET @cOutfield01 = '' -- (ChewKP01)
         END
      END
      ELSE
      BEGIN
          SET @cOutfield01 = ''
      END

      SET @cOutField02 = @cLoc
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField06 = @cLottable02
      SET @cOutField07 = RDT.RDTFormatDate(@dLottable04)

      SET @cOutField11 = ''
      SET @cOutField12 = @cPDDropID
      SET @cOutField13 = @cPDID -- (ChewKP01)


      -- GOTO Next Screen
      SET @nScn  = @nScnConfirm
      SET @nStep = @nStepConfirm

      EXEC rdt.rdtSetFocusField @nMobile, 11

   END  -- Inputkey = 1

   IF @nInputKey = 0
   BEGIN
       -- Prepare Previous Screen Variable
       SET @cOutField01 = ''



       -- GOTO Previous Screen
       SET @nScn = @nScn - 1
       SET @nStep = @nStep - 1
   END
   GOTO Quit

   STEP_5_FAIL:
   BEGIN
      SET @cOutField01 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1
   END

END
GOTO QUIT


/********************************************************************************
Step 6 Scn = 3465.
   Reason Code (field01, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1
   BEGIN

      SET @cReasonCode = ISNULL(RTRIM(@cInField01),'')


      IF ISNULL(@cReasonCode, '') = ''
      BEGIN
         SET @nErrNo = 79614
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ReasonCode Req'
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_6_Fail
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.TaskManagerReason WITH (NOLOCK)
                      WHERE TaskManagerReasonKey = @cReasonCode )
      BEGIN
         SET @nErrNo = 79615
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Reason'
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_6_Fail
      END

      -- (james02)
      -- Update ptltran record if config turn on. For those who wanna do simulation without cart
      IF @cDeviceID = ''
      BEGIN
         UPDATE PTL WITH (ROWLOCK) SET
            PTL.Status = '9',
            PTL.Qty = 0
         FROM dbo.PtlTran PTL
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PTL.SourceKey = PD.PickDetailKey)  -- (james06)
         WHERE PTL.DeviceID = @cCartID
         AND   PTL.SKU      = @cSKU
         AND   PTL.Loc      = @cLoc
         AND   PTL.Lot      = @cLot
         AND   PD.ID        = @cPDID
         AND   PTL.Status  <= '1'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 79634
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PTLTR FAIL'
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_6_Fail
         END
      END

      -- Generate Alert
       EXEC [RDT].[rdt_PTL_OrderPicking_GenAlert]
           @nMobile      = @nMobile
          ,@nFunc        = @nFunc
          ,@cFacility    = @cFacility
          ,@cStorerKey   = @cStorerKey
          ,@cCartID      = @cCartID
          ,@cUserName    = @cUserName
          ,@cLangCode    = @cLangCode
          ,@nErrNo       = @nErrNo       OUTPUT
          ,@cErrMsg      = @cErrMsg      OUTPUT -- screen limitation, 20 char max
          ,@cSKU         = @cSKU
          ,@cLoc         = @cLoc
          ,@cLot         = @cLot
          ,@cReasonCode  = @cReasonCode

      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Reason'
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_6_Fail
      END

      -- Get Next Task

      --SET @cSuggestedSKU = ''
      SET @cSKU          = ''
      SET @cSKUDescr     = ''
      --SET @cLoc          = ''
      SET @nTotalOrder   = 0
      SET @nTotalQty     = 0

      -- (ChewKP01)
      SET @cLoc          = ''
      SET @cLot          = ''
      SET @cLottable01   = ''
      SET @cLottable02   = ''
      SET @cLottable03   = ''
      SET @dLottable04   = ''
      SET @dLottable05   = ''
      SET @cPDDropID     = ''
      SET @cPDLoc        = ''
      SET @cPDToLoc      = ''
      SET @cPDID         = ''
      SET @cWaveKey      = ''

      SET @nErrNo = 0
      SET @cPTL_GetNextTaskSP = rdt.RDTGetConfig( @nFunc, 'PTL_GetNextTaskSP', @cStorerKey)
      IF @cPTL_GetNextTaskSP NOT IN ('0', '') AND
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPTL_GetNextTaskSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cPTL_GetNextTaskSP) +
             ' @nMobile, @nFunc, @cFacility, @cStorerKey, @cCartID, @cUserName, @cLangCode, @cPickZone,
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSKU OUTPUT, @cSKUDescr OUTPUT, @cLoc OUTPUT, @cLot OUTPUT,
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @nTotalOrder OUTPUT, @nTotalQty OUTPUT, @cPDDropID OUTPUT, @cPDLoc OUTPUT, @cPDToLoc OUTPUT,
               @cPDID OUTPUT, @cWaveKey OUTPUT '
         SET @cSQLParam =
             '@nMobile          INT, ' +
             '@nFunc            INT, ' +
             '@cFacility        NVARCHAR(5), ' +
             '@cStorerKey       NVARCHAR( 15), ' +
             '@cCartID          NVARCHAR( 10), ' +
             '@cUserName        NVARCHAR( 18), ' +
             '@cLangCode       NVARCHAR( 3), ' +
             '@cPickZone        NVARCHAR( 10), ' +
             '@nErrNo           INT           OUTPUT, ' +
             '@cErrMsg          NVARCHAR(250) OUTPUT, ' + -- screen limitation, 20 char max
             '@cSKU    NVARCHAR(20)  OUTPUT, ' +
             '@cSKUDescr        NVARCHAR(60)  OUTPUT, ' +
             '@cLoc             NVARCHAR(10)  OUTPUT, ' +
             '@cLot             NVARCHAR(10)  OUTPUT, ' +
             '@cLottable01      NVARCHAR(18)  OUTPUT, ' +
             '@cLottable02      NVARCHAR(18)  OUTPUT, ' +
             '@cLottable03      NVARCHAR(18)  OUTPUT, ' +
             '@dLottable04      DATETIME      OUTPUT, ' +
             '@dLottable05      DATETIME      OUTPUT, ' +
             '@nTotalOrder      INT           OUTPUT, ' +
             '@nTotalQty        INT           OUTPUT, ' +
             '@cPDDropID        NVARCHAR(20)  OUTPUT, ' +
             '@cPDLoc           NVARCHAR(20)  OUTPUT, ' +
             '@cPDToLoc         NVARCHAR(20)  OUTPUT, ' +
             '@cPDID            NVARCHAR(20)  OUTPUT, ' +
             '@cWaveKey         NVARCHAR(10)  OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @cFacility, @cStorerKey, @cCartID, @cUserName, @cLangCode, @cPickZone,
              @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSuggestedSKU OUTPUT, @cSKUDescr OUTPUT, @cLoc OUTPUT, @cLot OUTPUT,
              @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
              @nTotalOrder OUTPUT, @nTotalQty OUTPUT, @cPDDropID OUTPUT, @cPDLoc OUTPUT, @cPDToLoc OUTPUT,
              @cPDID OUTPUT, @cWaveKey OUTPUT
      END
      ELSE
      BEGIN
         EXEC [RDT].[rdt_PTL_OrderPicking_GetNextTask]
              @nMobile          = @nMobile
             ,@nFunc            = @nFunc
             ,@cFacility        = @cFacility
             ,@cStorerKey       = @cStorerKey
             ,@cCartID          = @cCartID
             ,@cUserName        = @cUserName
             ,@cLangCode        = @cLangCode
             ,@cPickZone        = @cPickZone    -- (james04)
             ,@nErrNo           = @nErrNo       OUTPUT
             ,@cErrMsg          = @cErrMsg      OUTPUT -- screen limitation, 20 char max
             ,@cSKU             = @cSuggestedSKU OUTPUT
             ,@cSKUDescr        = @cSKUDescr    OUTPUT
             ,@cLoc             = @cLoc         OUTPUT
             ,@cLot             = @cLot         OUTPUT
             ,@cLottable01      = @cLottable01  OUTPUT
             ,@cLottable02      = @cLottable02  OUTPUT
             ,@cLottable03      = @cLottable03  OUTPUT
             ,@dLottable04      = @dLottable04  OUTPUT
             ,@dLottable05      = @dLottable05  OUTPUT
             ,@nTotalOrder      = @nTotalOrder  OUTPUT
             ,@nTotalQty        = @nTotalQty    OUTPUT
             ,@cPDDropID        = @cPDDropID    OUTPUT
             ,@cPDLoc           = @cPDLoc       OUTPUT
             ,@cPDToLoc         = @cPDToLoc     OUTPUT
             ,@cPDID            = @cPDID        OUTPUT -- (ChewKP01)
             ,@cWaveKey         = @cWaveKey     OUTPUT -- (ChewKP01)
      END

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = 79801 -- No More Task! Goto Screen 1
         BEGIN
            -- UPDATE DeviceProfileLog.Status = 9
            UPDATE dbo.DeviceProfileLog WITH (ROWLOCK)  -- (james06)
               SET Status = '9'
            FROM dbo.DeviceProfileLog DL
            INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey
            WHERE D.DeviceID = @cCartID
            AND D.Status = '3'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 79617
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDPLogFailed'
      EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Step_6_Fail
            END

            -- UPDATE DeviceProfile.Status = 9
            UPDATE dbo.DeviceProfile WITH (ROWLOCK)
            SET Status = '9'
            WHERE DeviceID = @cCartID
              AND Status = '3'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 79616
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDPFailed'
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Step_6_Fail
            END

            SET @cOutField01 = ''
            SET @cOutField02 = ''

            SET @nScn = @nScn - 5
            SET @nStep = @nStep - 5

            GOTO QUIT
         END
         ELSE
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_6_Fail
         END
      END


      -- Prepare Next Screen Variable
      SET @cOutField01 = @cCartID
      SET @cOutField02 = @cLoc
      SET @cOutField03 = @cSuggestedSKU
      SET @cOutField04 = ''
      SET @cOutField05 = @cExtendedInfo2Disp01
      SET @cOutField06 = @cExtendedInfo2Disp02
      SET @cOutField07 = @cLottable02
      SET @cOutField08 = RDT.RDTFormatDate(@dLottable04)
      SET @cOutfield09 = @nTotalOrder
      SET @cOutfield10 = @nTotalQty
      SET @cOutfield11 = @cPDDropID

      SET @cOutfield13 = @cPDID    -- (ChewKP01)

      -- (ChewKP01)
      IF @cShowWave = '1'
      BEGIN
         IF @cPDToLoc <> ''
         BEGIN
            SET @cOutfield12 = 'Wavekey: ' + @cWaveKey -- (ChewKP01)
         END
         ELSE
         BEGIN
            SET @cOutfield12 = '' -- (ChewKP01)
         END
      END
      ELSE
      BEGIN
          SET @cOutfield12 = 'PK ZONE: ' + @cPickZone -- (james04)
      END

      -- GOTO Previous Screen
      SET @nScn  = @nScnSKU
      SET @nStep = @nStepSKU

      EXEC rdt.rdtSetFocusField @nMobile, 4

      EXEC RDT.rdt_STD_EventLog
        @cActionType = '3',
        @cUserID     = @cUserName,
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorerkey,
        @cDeviceID   = @cCartID,
        @cReasonKey  = @cReasonCode,
        @nStep       = @nStep
        




   END  -- Inputkey = 1

   IF @nInputKey = 0
   BEGIN
      -- If not light picking then can go back prev screen
      IF @cDeviceID = ''
      BEGIN
         -- Prepare Next Screen Variable
         SET @cOutField01 = @cCartID
         SET @cOutField02 = @cLoc
         SET @cOutField03 = @cSuggestedSKU
         SET @cOutField04 = ''
         SET @cOutField05 = @cExtendedInfo2Disp01
         SET @cOutField06 = @cExtendedInfo2Disp02
         SET @cOutField07 = @cLottable02
         SET @cOutField08 = RDT.RDTFormatDate(@dLottable04)
         SET @cOutfield09 = @nTotalOrder
         SET @cOutfield10 = @nTotalQty
         SET @cOutfield11 = @cPDDropID

         SET @cOutfield13 = @cPDID    -- (ChewKP01)

         -- (ChewKP01)
         SET @cShowWave = ''
         SET @cShowWave = rdt.RDTGetConfig( @nFunc, 'ShowWave', @cStorerKey)

         IF @cShowWave = '1'
         BEGIN
            IF @cPDToLoc <> ''
            BEGIN
               SET @cOutfield12 = 'Wavekey: ' + @cWaveKey -- (ChewKP01)
            END
            ELSE
            BEGIN
               SET @cOutfield12 = '' -- (ChewKP01)
            END
         END
         ELSE
         BEGIN
            SET @cOutfield12 = 'PK ZONE: ' + @cPickZone -- (james04)
         END

         -- Remember current step & scn
         SET @nScn = @nPrevScn
         SET @nStep = @nPrevStep
      END
   END
   GOTO Quit

   STEP_6_FAIL:
   BEGIN
      SET @cOutField01 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1

   END

END
GOTO QUIT


/********************************************************************************
Step 7. Scn = 3466.
   CartID   (field01)
   Loc (field02)
   SKU (field03)
   SKU Descr 1   (field04)
   SKU Descr 2   (field05)
   Lottable02    (field06)
   Lottable03    (field07)
   Lv1           (field08)
   Lv2           (field09)
   Lv3           (field10)
   Option        (field11, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1
   BEGIN
      SET @cOption = ISNULL(RTRIM(@cInField12),'')

      IF ISNULL( @cOption, '') <> ''
      BEGIN
         IF @cOption <> '1'
         BEGIN
            SET @nErrNo = 79629
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidOption'
            GOTO Step_3_Fail
         END

         IF @cOption = '1'
         BEGIN
            -- Prepare Next Screen Variable
            SET @cOutField01 = ''

            -- GOTO Next Screen
            SET @nScn  = @nScnCloseTote
            SET @nStep = @nStepCloseTote

            EXEC rdt.rdtSetFocusField @nMobile, 1

            GOTO QUIT
         END
      END

      -- (james02)
      -- Update ptltran record if config turn on. For those who wanna do simulation without cart
      IF @cDeviceID = ''
      BEGIN
         UPDATE PTL WITH (ROWLOCK) SET -- (james06)
            PTL.Status = '9',
            PTL.Qty = ExpectedQty
         FROM dbo.PtlTran PTL
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PTL.SourceKey = PD.PickDetailKey)
         WHERE PTL.DeviceID = @cCartID
         AND   PTL.SKU      = @cSKU
         AND   PTL.Loc      = @cLoc
         AND   PTL.Lot      = @cLot
         AND   PD.ID        = @cPDID
         AND   PTL.Status      <= '1'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 79630
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PTLTR FAIL'
            GOTO Step_7_Fail
         END
      END

      -- Check If All Pick Done before Proceed to Next Location / Action
      IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)
                      WHERE DeviceID = @cCartID
                      AND   SKU      = @cSKU
                      AND   Loc      = @cLoc
                      AND   Lot      = @cLot
                      AND   Status = '1' )
      BEGIN
         SET @nErrNo = 79631
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PickNotComplete'
         GOTO Step_7_Fail
      END

      -- If there is any short pick , goto Reason Screen
      IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)
                  WHERE DeviceID = @cCartID
                      AND   SKU      = @cSKU
                      AND   Loc      = @cLoc
                      AND   Lot      = @cLot
                      AND   Status   IN ('5','9')
                      AND   ExpectedQty <> Qty
                      AND   DeviceProfileLogKey = @cDeviceProfileLogKey )
      BEGIN
         -- Prepare Next Screen Variable
         SET @cOutField01 = ''

         -- GOTO Next Screen
         SET @nScn  = @nScnReasonCode
         SET @nStep = @nStepReasonCode

         GOTO QUIT
      END

      -- Get Next Task
      SET @cSKU          = ''
      SET @cSKUDescr     = ''
      SET @nTotalOrder   = 0
      SET @nTotalQty     = 0
      SET @cLoc          = ''
      SET @cLot          = ''
      SET @cLottable01   = ''
      SET @cLottable02   = ''
      SET @cLottable03   = ''
      SET @dLottable04   = NULL
      SET @dLottable05   = NULL
      SET @cPDDropID     = ''
  SET @cPDLoc        = ''
      SET @cPDToLoc      = ''
      SET @cPDID         = ''
      SET @cWaveKey      = ''

      SET @nErrNo = 0
      SET @cPTL_GetNextTaskSP = rdt.RDTGetConfig( @nFunc, 'PTL_GetNextTaskSP', @cStorerKey)
      IF @cPTL_GetNextTaskSP NOT IN ('0', '') AND
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPTL_GetNextTaskSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cPTL_GetNextTaskSP) +
             ' @nMobile, @nFunc, @cFacility, @cStorerKey, @cCartID, @cUserName, @cLangCode, @cPickZone,
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSKU OUTPUT, @cSKUDescr OUTPUT, @cLoc OUTPUT, @cLot OUTPUT,
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @nTotalOrder OUTPUT, @nTotalQty OUTPUT, @cPDDropID OUTPUT, @cPDLoc OUTPUT, @cPDToLoc OUTPUT,
               @cPDID OUTPUT, @cWaveKey OUTPUT '
         SET @cSQLParam =
             '@nMobile          INT, ' +
             '@nFunc            INT, ' +
             '@cFacility        NVARCHAR(5), ' +
             '@cStorerKey       NVARCHAR( 15), ' +
             '@cCartID          NVARCHAR( 10), ' +
             '@cUserName        NVARCHAR( 18), ' +
             '@cLangCode        NVARCHAR( 3), ' +
             '@cPickZone        NVARCHAR( 10), ' +
             '@nErrNo           INT           OUTPUT, ' +
             '@cErrMsg          NVARCHAR(250) OUTPUT, ' + -- screen limitation, 20 char max
             '@cSKU    NVARCHAR(20)  OUTPUT, ' +
             '@cSKUDescr        NVARCHAR(60)  OUTPUT, ' +
             '@cLoc             NVARCHAR(10)  OUTPUT, ' +
             '@cLot             NVARCHAR(10)  OUTPUT, ' +
             '@cLottable01      NVARCHAR(18)  OUTPUT, ' +
             '@cLottable02      NVARCHAR(18)  OUTPUT, ' +
             '@cLottable03      NVARCHAR(18)  OUTPUT, ' +
             '@dLottable04      DATETIME      OUTPUT, ' +
             '@dLottable05      DATETIME      OUTPUT, ' +
             '@nTotalOrder      INT           OUTPUT, ' +
             '@nTotalQty        INT           OUTPUT, ' +
             '@cPDDropID        NVARCHAR(20)  OUTPUT, ' +
             '@cPDLoc           NVARCHAR(20)  OUTPUT, ' +
             '@cPDToLoc         NVARCHAR(20)  OUTPUT, ' +
             '@cPDID            NVARCHAR(20)  OUTPUT, ' +
             '@cWaveKey         NVARCHAR(10)  OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @cFacility, @cStorerKey, @cCartID, @cUserName, @cLangCode, @cPickZone,
              @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSuggestedSKU OUTPUT, @cSKUDescr OUTPUT, @cLoc OUTPUT, @cLot OUTPUT,
              @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
              @nTotalOrder OUTPUT, @nTotalQty OUTPUT, @cPDDropID OUTPUT, @cPDLoc OUTPUT, @cPDToLoc OUTPUT,
              @cPDID OUTPUT, @cWaveKey OUTPUT
      END
      ELSE
      BEGIN
         EXEC [RDT].[rdt_PTL_OrderPicking_GetNextTask]
              @nMobile          = @nMobile
             ,@nFunc            = @nFunc
             ,@cFacility        = @cFacility
             ,@cStorerKey       = @cStorerKey
             ,@cCartID          = @cCartID
             ,@cUserName        = @cUserName
             ,@cLangCode        = @cLangCode
             ,@cPickZone        = @cPickZone       -- (james04)
             ,@nErrNo           = @nErrNo          OUTPUT
             ,@cErrMsg          = @cErrMsg         OUTPUT -- screen limitation, 20 char max
             ,@cSKU             = @cSuggestedSKU   OUTPUT
             ,@cSKUDescr        = @cSKUDescr       OUTPUT
             ,@cLoc             = @cLoc            OUTPUT
             ,@cLot             = @cLot            OUTPUT
             ,@cLottable01      = @cLottable01     OUTPUT
             ,@cLottable02      = @cLottable02     OUTPUT
             ,@cLottable03      = @cLottable03     OUTPUT
             ,@dLottable04      = @dLottable04     OUTPUT
             ,@dLottable05      = @dLottable05     OUTPUT
             ,@nTotalOrder      = @nTotalOrder     OUTPUT
             ,@nTotalQty        = @nTotalQty       OUTPUT
             ,@cPDDropID        = @cPDDropID       OUTPUT
             ,@cPDLoc           = @cPDLoc          OUTPUT
             ,@cPDToLoc         = @cPDToLoc        OUTPUT
             ,@cPDID            = @cPDID           OUTPUT -- (ChewKP01)
             ,@cWaveKey         = @cWaveKey        OUTPUT -- (ChewKP01)
      END

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = 79801 -- No More Task! Goto Screen 1
         BEGIN
            -- UPDATE DeviceProfileLog.Status = 9
            UPDATE dbo.DeviceProfileLog WITH (ROWLOCK)
               SET [Status] = '9'
            FROM dbo.DeviceProfileLog DL
            INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey  -- (james06)
            WHERE D.DeviceID = @cCartID
            AND   D.Status = '3'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 79633
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDPLogFailed'
               GOTO Step_7_Fail
            END

            -- UPDATE DeviceProfile.Status = 9
            UPDATE dbo.DeviceProfile WITH (ROWLOCK)
               SET [Status] = '9',
                   DeviceProfileLogKey = ''
            WHERE DeviceID = @cCartID
            AND   Status = '3'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 79632
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDPFailed'
               GOTO Step_7_Fail
            END

            SET @cOutField01 = ''
            SET @cOutField02 = ''

            SET @nScn = @nScn - 6
            SET @nStep = @nStep - 6

            GOTO QUIT
         END
         ELSE
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_7_Fail
         END
      END

      -- (james07)
      SET @cExtendedInfo2Disp01 = ''
      SET @cExtendedInfo2Disp02 = ''
      SET @cDispStyleColorSize = rdt.RDTGetConfig( @nFunc, 'DispStyleColorSize', @cStorerKey)

      -- If not setup config, default display sku descr
      IF @cDispStyleColorSize IN ('', '0')
      BEGIN
         SET @cExtendedInfo2Disp01 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cExtendedInfo2Disp02 = SUBSTRING( @cSKUDescr, 21, 20)
      END

      -- If config setup but svalue = 1 then default display style + color + size
      IF @cDispStyleColorSize = '1'
      BEGIN
         SELECT @cStyle = Style,
                @cColor = Color,
                @cSize = [Size]
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSuggestedSKU

         SET @cExtendedInfo2Disp01 = @cStyle
         SET @cExtendedInfo2Disp02 = RTRIM( @cColor) + ', ' + RTRIM( @cSize)
      END
      -- If config setup and len(svalue) > 1 then use customised sp to retrieve extended value
      ELSE
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDispStyleColorSize AND type = 'P')
         BEGIN
            SET @nErrNo = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDispStyleColorSize) +
               ' @nMobile, @nFunc, @nStep, @nInputKey, @cStorerKey, @cCartID, @cPickZone, @cLoc, @cSKU, @cLottable02, @dLottable04, @cPDDropID, ' +
               ' @c_oFieled01 OUTPUT, @c_oFieled02 OUTPUT, @c_oFieled03 OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT, ' +
               '@nFunc        INT, ' +
               '@nStep        INT, ' +
               '@nInputKey    INT, ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cCartID      NVARCHAR( 10), ' +
               '@cPickZone    NVARCHAR( 10), ' +
               '@cLoc         NVARCHAR( 10), ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@cLottable02  NVARCHAR( 18), ' +
               '@dLottable04  DATETIME,  ' +
               '@cPDDropID    NVARCHAR( 20), ' +
               '@c_oFieled01  NVARCHAR( 20)  OUTPUT, ' +
               '@c_oFieled02  NVARCHAR( 20)  OUTPUT, ' +
               '@c_oFieled03  NVARCHAR( 20)  OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @nStep, @nInputKey, @cStorerKey, @cCartID, @cPickZone, @cLoc, @cSuggestedSKU, @cLottable02, @dLottable04, @cPDDropID,
               @c_oFieled01 OUTPUT, @c_oFieled02 OUTPUT, @c_oFieled03 OUTPUT

            SET @cExtendedInfo2Disp01 = @c_oFieled01
            SET @cExtendedInfo2Disp02 = @c_oFieled02
         END
      END

      -- Prepare Next Screen Variable
      SET @cOutField01 = @cCartID
      SET @cOutField02 = @cLoc
      SET @cOutField03 = @cSuggestedSKU
      SET @cOutField04 = ''
      SET @cOutField05 = @cExtendedInfo2Disp01
      SET @cOutField06 = @cExtendedInfo2Disp02
      SET @cOutField07 = @cLottable02
      SET @cOutField08 = RDT.RDTFormatDate(@dLottable04)
      SET @cOutfield09 = @nTotalOrder
      SET @cOutfield10 = @nTotalQty
      SET @cOutfield11 = @cPDDropID
      SET @cOutfield13 = @cPDID    -- (ChewKP01)

      -- (ChewKP01)
      IF @cShowWave = '1'
      BEGIN
         IF @cPDToLoc <> ''
         BEGIN
            SET @cOutfield12 = 'Wavekey: ' + @cWaveKey -- (ChewKP01)
         END
         ELSE
         BEGIN
            SET @cOutfield12 = '' -- (ChewKP01)
         END
      END
      ELSE
      BEGIN
         SET @cOutfield12 = 'PK ZONE: ' + @cPickZone -- (james04)
      END

      -- GOTO Previous Screen
      SET @nScn = @nScn - 5
      SET @nStep = @nStep - 5

      EXEC rdt.rdtSetFocusField @nMobile, 4
   END  -- Inputkey = 1

   IF @nInputKey = 0
   BEGIN
     IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)
                 WHERE DeviceID = @cCartID
                 AND   Status = '1'
                 AND   DeviceProfileLogKey = @cDeviceProfileLogKey )
      BEGIN
          -- Update PTLTran
          UPDATE dbo.PTLTran WITH (ROWLOCK)
          SET [Status] = '0'
          WHERE DeviceID = @cCartID
          AND   Status = '1'
       END

       -- Prepare Previous Screen Variable
       SET @cOutField01 = @cCartID
       SET @cOutField02 = @cLoc
       SET @cOutField03 = @cSuggestedSKU
       SET @cOutField04 = ''
       SET @cOutField05 = @cExtendedInfo2Disp01
       SET @cOutField06 = @cExtendedInfo2Disp02
       SET @cOutField07 = @cLottable02
       SET @cOutField08 = @dLottable04
       SET @cOutfield09 = @nTotalOrder
       SET @cOutfield10 = @nTotalQty
       SET @cOutfield11 = @cPDDropID
       SET @cOutfield13 = @cPDID    -- (ChewKP01)

        -- (ChewKP01)
       IF @cShowWave = '1'
       BEGIN
          IF @cPDToLoc <> ''
          BEGIN
             SET @cOutField12 = 'Wavekey: ' + @cWaveKey
          END
          ELSE
          BEGIN
             SET @cOutfield12 = '' -- (ChewKP01)
          END
       END
       ELSE
       BEGIN
         SET @cOutfield12 = 'PK ZONE: ' + @cPickZone -- (james04)
       END

       EXEC rdt.rdtSetFocusField @nMobile, 4

       -- GOTO Previous Screen
       SET @nScn = @nScn - 5
       SET @nStep = @nStep - 5

      -- (james02)
      IF @cDeviceID <> ''
      BEGIN
         -- Initialize LightModules
         EXEC [dbo].[isp_DPC_TerminateAllLight]
          @cStorerKey
            ,@cCartID
            ,@b_Success    OUTPUT
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT

         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = LEFT(@cErrMsg,1024)
            GOTO Quit
         END
      END
   END
   GOTO Quit

   STEP_7_FAIL:
   BEGIN
      SET @cOutField11 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 11
   END
END
GOTO QUIT


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
      --UserName  = @cUserName,
      InputKey  = @nInputKey,


      V_UOM = @cPUOM,
      V_SKU         = @cSKU,
      V_SKUDescr    = @cSKUDescr,
      V_Loc         = @cLoc,
      V_Lot         = @cLot,
      V_Lottable01  = @cLottable01, -- (ChewKP01)
      V_Lottable02  = @cLottable02,
      V_Lottable03  = @cLottable03, -- (ChewKP01)
      V_Lottable04  = @dLottable04,
      V_Lottable05  = @dLottable05, -- (ChewKP01)

      V_OrderKey    = @cOrderKey,
      V_ID          = @cPDID, -- (ChewKP01)

      V_String1 = @cCartID,
      V_String2 = @cSuggestedSKU,
      V_String3 = @cToteID,
      V_String4 = @cDeviceProfileKey,
      V_String5 = @cDeviceProfileLogKey,
      V_String8 = @cPDDropID,
      V_String9 = @cPDLoc,
      V_String10 = @cPDToLoc,
      V_String11 = @cWaveKey, -- (ChewKP01)
      V_String12 = @cShowWave, -- (ChewKP01)
      V_String13 = @cDeviceID,  -- (james02)
      V_String14 = @cPTLPKZoneReq,   -- (james04)
      V_String15 = @cPickZone,       -- (james04)
      V_String18 = @cExtendedInfo2Disp01,
      V_String19 = @cExtendedInfo2Disp02,
      
      V_Integer1 = @nTotalOrder,
      V_Integer2 = @nTotalQty,

      V_FromStep = @nPrevStep,
      V_FromScn  = @nPrevScn,
      
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