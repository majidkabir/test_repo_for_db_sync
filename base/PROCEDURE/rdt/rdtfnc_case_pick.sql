SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: RDT Case Picking SOS133214                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2009-04-07 1.0  James      Created                                   */
/* 2009-06-23 1.1  Vicky      UOM should consider the PD.UOM            */
/*                            either PackUOM4 or PackUOM1 (Vicky01)     */
/* 2009-07-30 1.2  Vicky      Add in EventLog (Vicky06)                 */
/* 2009-08-27 1.3  James      SOS146207 - Change URN ncounter to        */
/*                            Intermodalvehicle (james01)               */
/* 2009-09-29 1.4  Leong      SOS#149188 - Clear incomplete data before */
/*                                         proceed                      */
/* 2009-10-14 1.5  James      Include Mobile when insert into           */
/*                            RDTPicklock (James01)                     */
/* 2009-10-25 1.6  James      SOS151572 - Bug fix (james02)             */
/* 2010-03-03 1.7  James      SOS162367 - If SKU.Size exists, display   */
/*                            else display SKU.Descr (james03)          */
/* 2010-03-18 1.8  James      SOS162367 - Add SKU.Style (james04)       */
/* 2011-02-14 1.9  James      SOS204018 - Add validation on Case ID     */
/*                                        scanned (james05)             */
/* 2012-05-16 2.0  ChewKP     Begin Tran and Commit Tran issues.        */
/*                            (ChewKP01)                                */
/* 2013-11-11 2.1  James      SOS# 294711 - Bug Fix Begin/Commit Tran.  */
/* 2014-03-11 2.2  James      SOS305558-Allow key qty to pick (james06) */
/* 2014-04-01 2.3  James      Add Config to allow pick case (james07)   */
/* 2015-11-27 2.4  James      Deadlock tuning (james08)                 */
/* 2016-09-30 2.5  Ung        Performance tuning                        */
/* 2018-10-31 2.6  Gan        Performance tuning                        */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_Case_Pick] (  
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
   @nCurScn    INT,  -- Current screen variable
   @nStep      INT,
   @nCurStep   INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,

   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5),
   @cPrinter   NVARCHAR( 10),
   @cUserName  NVARCHAR( 18),

   @nError     INT,
   @b_success  INT,
   @n_err      INT,
   @c_errmsg   NVARCHAR( 250),

   @cOrderKey           NVARCHAR( 10),
   @cLoadKey            NVARCHAR( 10),
   @cWaveKey            NVARCHAR( 10),

   @cSKU                NVARCHAR( 20),
   @cPD_SKU             NVARCHAR( 20),
   @cSuggestedSKU       NVARCHAR( 20),
   @cDescr              NVARCHAR( 60),
   @nQty                INT,
   @cPickDetailKey      NVARCHAR( 18),
   @cStatus             NVARCHAR( 10),
   @cPickSlipNo         NVARCHAR( 10),
   @cLOC                NVARCHAR( 10),
   @cLOT                NVARCHAR( 10),
   @cID                 NVARCHAR( 18),
   @cZone               NVARCHAR( 10),
   @cSuggestedLOC       NVARCHAR( 10),
   @cNewSuggestedLOC    NVARCHAR( 10),
   @cLogicalLocation    NVARCHAR( 18),
   @cCaseID             NVARCHAR( 10),
   @cPickSlipType       NVARCHAR( 10),
   @nCartonNo           INT,
   @cLabelNo            NVARCHAR( 20),
   @cQty                NVARCHAR( 5),
   @cDoor               NVARCHAR( 10),
   @cPD_CartonNo        NVARCHAR( 18),
   @cOrderLineNumber    NVARCHAR( 5),

   @nPickDSKUQty        INT,
   @nPackDSKUQty        INT,
   @nTotalLoc           INT,
   @nPickedLoc          INT,
   @nRemainingTask      INT,
   @nSKUCnt             INT,
   @cPUOM               NVARCHAR( 1),
   @nPackDQty           INT,
   @nPickDQty           INT,
   @cCheckPickB4Pack    NVARCHAR( 1),
   @cPrepackByBOM       NVARCHAR( 1),
   @cAutoPackConfirm    NVARCHAR( 1),
   @cAutoScanInPS       NVARCHAR( 1),
   @cAutoScanOutPS      NVARCHAR( 1),
   @cSHOWSHTPICKRSN     NVARCHAR( 1),
   @cCasePackDefaultQty NVARCHAR( 5),
   @cPackUOM1           NVARCHAR( 10),
   @cReasonCode         NVARCHAR( 10),
   @cModuleName         NVARCHAR( 45),
   @cLabelLine          NVARCHAR( 5),
   @cPickUOM            NVARCHAR( 10), -- (Vicky01)
   @cPickUOMDescr       NVARCHAR( 10), -- (Vicky01)
   @nPickUOMQty         INT, -- (Vicky01)

   @cInterModalVehicle  NVARCHAR(30),
   @cURNNo1             NVARCHAR(20),
   @cURNNo2             NVARCHAR(20),
   @cConsigneeKey       NVARCHAR(15),
   @cExternOrderKey     NVARCHAR(30),
   @cItemClass          NVARCHAR(10),
   @cBUSR5              NVARCHAR(30),
   @cBUSR3              NVARCHAR(30),
   @cKeyname            NVARCHAR(30),

   @nCasePackDefaultQty INT,
   @nQtyPicked          INT,
   @nQtyAllocated       INT,
   @nCnt                INT,
   @nQtyAlloced4SKU     INT,
   @nQtyPacked4SKU      INT,
   @nPickLockQty        INT,
   @nPickDetailQty      INT,
   @nQtyPacked          INT,
   @nPD_Qty             INT,
   @nShortPickedQty     INT,

   -- Lottables
   @cLottable01         NVARCHAR( 18),
   @cLottable02         NVARCHAR( 18),
   @cLottable03         NVARCHAR( 18),
   @dLottable04         DATETIME,
   @dLottable05         DATETIME,

   @cErrMsg1            NVARCHAR( 20),
   @cErrMsg2            NVARCHAR( 20),
   @cErrMsg3            NVARCHAR( 20),
   @cErrMsg4            NVARCHAR( 20),

   @cSize               NVARCHAR( 5),      --(james03)
   @cStyle              NVARCHAR( 20),     --(james04)

   --(james05)
   @cSQLStatement       nVARCHAR(2000),
   @cSQLParms           nVARCHAR(2000),
   @cCheckCaseID_SP     nVARCHAR(20),
   @nValid              INT,
   @nTranCount          INT,        -- SOS# 294711
   
   @nPickedUOMQty       INT,              -- (james06)
   @cPickConfirm_SP     NVARCHAR(60),     -- (james06)
   @cDefaultPickByCase  NVARCHAR(1),      -- (james07)
   @nRowRef             INT,              -- (james08)

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

   @cPUOM       = V_UOM,
   @nQTY        = V_QTY,
   @cSKU        = V_SKU,
   @cDescr      = V_SKUDescr,
   @cLOC        = V_LOC,
   @cLOT        = V_LOT,
   @cID         = V_ID,
   @cPickSlipNo = V_PickSlipNo,
   @cOrderKey   = V_OrderKey,
   @cLoadKey    = V_LoadKey,
   
   @nCartonNo   = V_Cartonno,
   
   @cAutoPackConfirm    = V_Integer1,
   @nCurScn             = V_Integer2,
   @nCurStep            = V_Integer3,
   @nPickUOMQty         = V_Integer4,
   @cDefaultPickByCase  = V_Integer5,

   @cDoor               = V_String1,
   @cLogicalLocation    = V_String2,
   @cSuggestedLoc       = V_String3,
   @cZone               = V_String4,
   @cPickSlipType       = V_String5,
  -- @nCartonNo           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6,  5), 0) = 1 THEN LEFT( V_String6,  5) ELSE 0 END,
   @cLabelNo            = V_String7,
   @cAutoScanInPS       = V_String8,     @cAutoScanOutPS      = V_String9,
   @cSHOWSHTPICKRSN     = V_String10,
  -- @cAutoPackConfirm    = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String11,  5), 0) = 1 THEN LEFT( V_String11,  5) ELSE 0 END,
   @cSuggestedSKU       = V_String12,
   @cPackUOM1           = V_String13,
  -- @nCurScn             = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String14,  5), 0) = 1 THEN LEFT( V_String14,  5) ELSE 0 END,
  -- @nCurStep            = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String15,  5), 0) = 1 THEN LEFT( V_String15,  5) ELSE 0 END,
   @cPickUOM            = V_String16, -- (Vicky01)
   @cPickUOMDescr       = V_String17, -- (Vicky01)
  -- @nPickUOMQty         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String18,  5), 0) = 1 THEN LEFT( V_String18,  5) ELSE 0 END, -- (Vicky01)
  -- @cDefaultPickByCase  = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String19,  5), 0) = 1 THEN LEFT( V_String19,  5) ELSE 0 END, -- (james07)

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

IF @nFunc = 1622  -- Case Picking
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Scan And Pack
   IF @nStep = 1 GOTO Step_1   -- Scn = 1960. LOAD#, ZONE
   IF @nStep = 2 GOTO Step_2   -- Scn = 1961. DOOR, PALLET ID
   IF @nStep = 3 GOTO Step_3   -- Scn = 1962. LOC
   IF @nStep = 4 GOTO Step_4   -- Scn = 1963. SKU, QTY
   IF @nStep = 5 GOTO Step_5   -- Scn = 1964. SKU, CASE ID
   IF @nStep = 6 GOTO Step_6   -- Scn = 1965. OPTION
   IF @nStep = 7 GOTO Step_7   -- Scn = 1966. MSG
   IF @nStep = 8 GOTO Step_8   -- Scn = 2010. RSN CODE
   IF @nStep = 9 GOTO Step_9   -- Scn = 1967. SKU, QTY
   IF @nStep = 10 GOTO Step_10 -- Scn = 1968. OPTION
END

--RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1622. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Get prefer UOM
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   -- Get RDT function name
   SELECT @cModuleName = StoredProcName FROM RDT.RDTMSG WITH (NOLOCK) WHERE Message_ID = @nFunc

   SET @cAutoScanInPS = rdt.RDTGetConfig( @nFunc, 'AutoScanInPS', @cStorerKey)
   SET @cAutoScanOutPS = rdt.RDTGetConfig( @nFunc, 'AutoScanOutPS', @cStorerKey)
   SET @cAutoPackConfirm = rdt.RDTGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey)
   SET @cSHOWSHTPICKRSN = rdt.RDTGetConfig( @nFunc, 'SHOWSHTPICKRSN', @cStorerKey)
   SET @cDefaultPickByCase = rdt.RDTGetConfig( @nFunc, 'DefaultPickByCase', @cStorerKey)  -- (james07)
   IF @cDefaultPickByCase IN ('0', '')
      SET @cDefaultPickByCase = ''

    -- (Vicky06) EventLog - Sign In Function
    EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerKey,
     @nStep       = @nStep

   -- Set the entry point
   SET @nScn = 1960
   SET @nStep = 1

   -- Initiate var
   SET @cLoadKey = ''
   SET @cZone = ''

   -- Init screen
   SET @cOutField01 = '' -- LoadKey
   SET @cOutField02 = '' -- Zone

   -- Clear any umcompleted task for the current user (only for current module)
   DELETE FROM RPL WITH (ROWLOCK)
   FROM RDT.RDTPickLock RPL 
   JOIN RDT.RDTMOBREC MOB ON RPL.Mobile = MOB.Mobile
   WHERE RPL.Status = '1'
   AND   RPL.AddWho = @cUserName
   AND   MOB.Func = @nFunc

/*
   --SOS#149188 Start: Clear the incompleted task for the same login
   DELETE FROM RDT.RDTPickLock WITH (ROWLOCK)
   WHERE Status = '1'
   AND AddWho = @cUserName

   IF @@ERROR <> 0
   BEGIN
      ROLLBACK TRAN
      SET @nErrNo = 66423
      SET @cErrMsg = rdt.rdtgetmessage( 66423, @cLangCode, 'DSP') --'UnlockLOCFail'
      GOTO Quit
   END
   --SOS#149188 End
*/
END
GOTO Quit

/********************************************************************************
Step 1. Scn = 1960.
   LOAD#     (field01, input)
   ZONE      (field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
         --screen mapping
      SET @cLoadKey = @cInField01
      SET @cZone = @cInField02

      -- Validate blank
      IF ISNULL(@cLoadKey, '') = ''
      BEGIN
         SET @nErrNo = 66401
         SET @cErrMsg = rdt.rdtgetmessage( 66401, @cLangCode,'DSP') --Need LoadKey
         SET @cOutField01 = ''
         SET @cOutField02 = @cZone
         SET @cLoadKey = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Check if Loadkey exists in Loadplan table
      IF NOT EXISTS (SELECT 1 FROM dbo.LOADPLAN WITH (NOLOCK)
         WHERE LOADKEY = @CLoadKey)
      BEGIN
         SET @nErrNo = 66402
         SET @cErrMsg = rdt.rdtgetmessage( 66402, @cLangCode,'DSP') --Invalid LOAD
         SET @cOutField01 = ''
         SET @cOutField02 = @cZone
         SET @cLoadKey = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Check If the Loadplan consists of multi-storer
      SELECT @nCnt = COUNT( DISTINCT StorerKey) FROM dbo.Orders WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LoadKey = @cLoadKey

      IF @nCnt > 1
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = '66403 Load has'
         SET @cErrMsg2 = 'more than'
         SET @cErrMsg3 = '1 Storer'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
            @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END
         SET @cOutField01 = ''
         SET @cOutField02 = @cZone
         SET @cLoadKey = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Check if loadplan closed
      IF EXISTS (SELECT 1 FROM dbo.LOADPLAN WITH (NOLOCK)
         WHERE LOADKEY = @cLoadKey
            AND Status = '9')
      BEGIN
         SET @nErrNo = 66404
         SET @cErrMsg = rdt.rdtgetmessage( 66404, @cLangCode,'DSP') --LOAD closed
         SET @cOutField01 = ''
         SET @cOutField02 = @cZone
         SET @cLoadKey = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      IF ISNULL(@cZone, '') = ''
      BEGIN
         SET @nErrNo = 66405
         SET @cErrMsg = rdt.rdtgetmessage( 66405, @cLangCode,'DSP') --Zone Req
         SET @cOutField01 = @cLoadKey
         SET @cOutField02 = ''
         SET @cZone = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.PutAwayZone WITH (NOLOCK) WHERE PutAwayZone = @cZone)
      BEGIN
         SET @nErrNo = 66406
         SET @cErrMsg = rdt.rdtgetmessage( 66406, @cLangCode,'DSP') --Invalid Zone
         SET @cOutField01 = @cLoadKey
         SET @cOutField02 = ''
         SET @cZone = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END

      -- Check If Zone is within the range of the allocated location of the Loadkey
      IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON PD.LOC = L.LOC
         -- WHERE PD.Status < '4'
         WHERE O.LoadKey = @cLoadKey
            AND O.StorerKey = @cStorerKey
            AND L.Facility = @cFacility
            AND L.PutawayZone = @cZone)
      BEGIN
         SET @nErrNo = 66407
         SET @cErrMsg = rdt.rdtgetmessage( 66407, @cLangCode,'DSP') --ZoneNotExist
         SET @cOutField01 = @cLoadKey
         SET @cOutField02 = ''
         SET @cZone = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END

      SET @cPickSlipNo = ''
      SELECT @cPickSlipNo = PickHeaderKey
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE ExternOrderKey = @cLoadKey
         AND Status = '0'

      SET @nTranCount = @@TRANCOUNT -- SOS# 294711
      BEGIN TRAN
      SAVE TRAN PickSlip_Handler

      -- Check if exists pickheader, not exists then we gen the pickslip using std pickslipno generation
      IF ISNULL(@cPickSlipNo, '') = ''
      BEGIN
         EXECUTE dbo.nspg_GetKey
            'PICKSLIP',
            9 ,
            @cPickSlipNo       OUTPUT,
            @b_success         OUTPUT,
            @n_err             OUTPUT,
            @c_errmsg          OUTPUT

         IF @b_success <> 1
         BEGIN
            SET @nErrNo = 66408
            SET @cErrMsg = rdt.rdtgetmessage( 66408, @cLangCode, 'DSP') -- 'GetPSLipFail'
            ROLLBACK TRAN PickSlip_Handler
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN
            GOTO Quit
         END

         SELECT @cPickSlipNo = 'P' + @cPickSlipNo

         INSERT INTO dbo.PICKHEADER
         (PickHeaderKey, ExternOrderKey, Zone, TrafficCop)
         VALUES
         (@cPickSlipNo, @cLoadKey, '7', '')

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 66409
            SET @cErrMsg = rdt.rdtgetmessage( 66409, @cLangCode, 'DSP') --'InsPiHdrFail'
            ROLLBACK TRAN PickSlip_Handler
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN
            GOTO Quit
         END
      END

      -- Check if the pickslip already scan out
      IF EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND ScanOutDate IS NOT NULL)
      BEGIN
         SET @nErrNo = 66410
         SET @cErrMsg = rdt.rdtgetmessage( 66410, @cLangCode,'DSP') --PS Scan Out
         EXEC rdt.rdtSetFocusField @nMobile, 1
         ROLLBACK TRAN PickSlip_Handler
         WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN
         GOTO Quit
      END

      -- Check if the pickslip already scan in
      -- If not exists then we scan in & scan out together
      IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
      BEGIN
         IF @cAutoScanInPS = '1'
         BEGIN
            INSERT INTO dbo.PickingInfo
            (PickSlipNo, ScanInDate, PickerID, ScanOutDate, AddWho)
            VALUES
            (@cPickSlipNo, GETDATE(), sUser_sName(), NULL, sUser_sName())

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66411
               SET @cErrMsg = rdt.rdtgetmessage( 66411, @cLangCode, 'DSP') --'PSScanInFail'
               ROLLBACK TRAN PickSlip_Handler
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 66413
            SET @cErrMsg = rdt.rdtgetmessage( 66413, @cLangCode, 'DSP') --'PSNotScanIn'
            ROLLBACK TRAN PickSlip_Handler
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN
            GOTO Quit
         END
      END
      ELSE  -- pickslip already in pickinginfo
      BEGIN
         -- Check if it scanned in
         IF EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND ScanInDate IS NULL)
         BEGIN
            IF @cAutoScanInPS = '1'
            BEGIN
               UPDATE dbo.PickingInfo SET
                  ScanInDate = GETDATE(),
                  AddWho = sUser_sName()
               WHERE PickSlipNo = @cPickSlipNo

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 66412
                  SET @cErrMsg = rdt.rdtgetmessage( 66412, @cLangCode, 'DSP') --'ScanInPSFail'
                  ROLLBACK TRAN PickSlip_Handler
                  WHILE @@TRANCOUNT > @nTranCount
                     COMMIT TRAN
                  GOTO Quit
               END
            END
            ELSE
            BEGIN
               SET @nErrNo = 66413
               SET @cErrMsg = rdt.rdtgetmessage( 66413, @cLangCode, 'DSP') --'PSNotScanIn'
               ROLLBACK TRAN PickSlip_Handler
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN
               GOTO Quit
            END
         END
      END

      -- COMMIT TRAN PickSlip_Handler -- SOS# 294711
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN PickSlip_Handler

      SELECT @cDoor = TrfRoom FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey

      -- Determine pickslip type, either Discrete/Consolidated
      IF EXISTS ( SELECT 1
                  FROM dbo.PickHeader PH WITH (NOLOCK)
                  JOIN dbo.PickingInfo PInfo (NOLOCK) ON (PInfo.PickSlipNo = PH.PickHeaderKey)
                  LEFT OUTER JOIN dbo.ORDERS O WITH (NOLOCK) ON (O.OrderKey = PH.OrderKey)
                  WHERE PH.PickHeaderKey = @cPickSlipNo )
         SET @cPickSlipType = 'CONSO'
      ELSE
         SET @cPickSlipType = 'SINGLE'

      -- Prepare next screen var
      SET @cOutField01 = @cDoor
      SET @cOutField02 = ''   -- PALLET ID
      SET @cID = ''

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      -- Clear any umcompleted task for the current user (only for current module)
      DELETE FROM RPL WITH (ROWLOCK)
      FROM RDT.RDTPickLock RPL 
      JOIN RDT.RDTMOBREC MOB ON RPL.Mobile = MOB.Mobile
      WHERE RPL.Status = '1'
      AND   RPL.AddWho = @cUserName
      AND   MOB.Func = @nFunc
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
       @cStorerKey  = @cStorerkey,
       @nStep       = @nStep

      --go to main menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
      SET @cOutField02 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 2. Scn = 1961.
   DOOR           (field01, input)
   PALLET ID      (field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
         --screen mapping
      SET @cID = @cInField02

      -- Validate blank
      IF ISNULL(@cID, '') = ''
      BEGIN
         SET @nErrNo = 66414
         SET @cErrMsg = rdt.rdtgetmessage( 66414, @cLangCode,'DSP') --PalletID req
         GOTO Step_2_Fail
      END

      SET @cLogicalLocation = ''
      SET @cSuggestedLOC = ''

      -- Look for the available LOC + Zone
      SELECT DISTINCT TOP 1
         @cLogicalLocation = L.LogicalLocation,
         @cSuggestedLOC = L.LOC
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
      WHERE PD.StorerKey = @cStorerKey
         AND PD.Status < '4'
         AND L.Facility = @cFacility
         AND L.PutawayZone = @cZone
         AND O.LoadKey = @cLoadKey
         AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK)
            WHERE RPL.LoadKey = @cLoadKey
               AND RPL.StorerKey = @cStorerKey
               AND RPL.PutAwayZone = @cZone
               AND RPL.LOC = PD.LOC
               AND RPL.AddWho <> @cUserName
               AND RPL.Status = '1')
      ORDER BY L.LogicalLocation, L.LOC

      IF ISNULL(@cSuggestedLOC, '') = ''
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = '66415 Zone has'
         SET @cErrMsg2 = 'no more task.'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
            @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
         END
         SET @cID = ''
         SET @cOutField02 = '' -- PALLET ID
         GOTO Quit
--         SET @nErrNo = 66415
--         SET @cErrMsg = rdt.rdtgetmessage( 66415, @cLangCode,'DSP') --NoMoreTask
--         GOTO Step_2_Fail
      END

      -- Start lock down the task (Load + Zone + Loc)
      IF NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LoadKey = @cLoadKey
            AND PutAwayZone = @cZone
            AND LOC = @cSuggestedLOC
            AND Status = '1')
      BEGIN
         --BEGIN TRAN  -- (ChewKP01)

         INSERT INTO RDT.RDTPickLock
         (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey, LOT, LOC, SKU, Status, AddWho, AddDate, DropID, PickSlipNo, UOM, Mobile) -- (Vicky01)
         VALUES
         ('', @cLoadKey, '', '', @cStorerKey, @cZone, '', '', '', @cSuggestedLOC, '', '1', @cUserName, GETDATE(), @cID, @cPickSlipNo, '', @nMobile)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 66416
            SET @cErrMsg = rdt.rdtgetmessage( 66416, @cLangCode, 'DSP') --'LockLOCFail'
            --ROLLBACK TRAN  -- (ChewKP01)
            GOTO Step_2_Fail
         END

         --COMMIT TRAN  -- (ChewKP01)
      END
      ELSE
      BEGIN
         SET @nErrNo = 66417
         SET @cErrMsg = rdt.rdtgetmessage( 66417, @cLangCode, 'DSP') --'LOC Locked'
         --ROLLBACK TRAN  -- (ChewKP01)
         GOTO Step_2_Fail
      END

      -- Prepare next screen var
      SET @cOutField01 = @cSuggestedLOC
      SET @cOutField02 = ''   --LOC
      SET @cLOC = ''

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 --ESC
   BEGIN
      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      SET @cOutField01 = ''   -- Load#
      SET @cOutField02 = ''   -- Zone
      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cID = ''
      SET @cOutField02 = '' -- PALLET ID
   END

END
GOTO Quit

/********************************************************************************
Step 3. Scn = 1962.
   LOC           (field01)
   LOC           (field02, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
         --screen mapping
      SET @cLOC = @cInField02

      IF ISNULL(@cLOC, '') = ''
      BEGIN
         SELECT TOP 1
            @cLogicalLocation = L.LogicalLocation,
            @cNewSuggestedLoc = L.LOC
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         WHERE PD.StorerKey = @cStorerKey
--            AND PD.PickSlipNo = @cPickSlipNo
            AND PD.Status < '4'
            AND L.LogicalLocation + L.LOC >
--               CONVERT(CHAR(18), ISNULL(RTRIM(@cLogicalLocation), '')) + CONVERT(CHAR(10), ISNULL(RTRIM(@cSuggestedLoc), ''))
               CONVERT(CHAR(18), ISNULL(RTRIM(@cLogicalLocation), '') + ISNULL(@cSuggestedLoc, ''))
            AND L.Facility = @cFacility
            AND L.PutAwayZone = @cZone
            AND O.LoadKey = @cLoadKey
            AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK)
               WHERE RPL.LoadKey = @cLoadKey
                  AND RPL.StorerKey = @cStorerKey
                  AND RPL.PutAwayZone = @cZone
                  AND RPL.LOC = PD.LOC
                  AND RPL.AddWho <> @cUserName
                  AND RPL.Status = '1')
         GROUP BY L.LogicalLocation, L.LOC
         ORDER BY L.LogicalLocation, L.LOC

         IF ISNULL(@cNewSuggestedLoc, '') = ''
         BEGIN
            SET @nErrNo = 66418
            SET @cErrMsg = rdt.rdtgetmessage( 66418, @cLangCode,'DSP') --No More Rec
            GOTO Step_3_Fail
         END

         -- User changed LOC, update the LOC to rdt.rdtPickLock
         -- Assumption: One LOC locked by 1 picker
         --BEGIN TRAN  -- (ChewKP01)

         UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
            LOC = @cNewSuggestedLoc
         WHERE LoadKey = @cLoadKey
            AND StorerKey = @cStorerKey
            AND PutAwayZone = @cZone
            AND AddWho = @cUserName
            AND Status = '1'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 66419
            SET @cErrMsg = rdt.rdtgetmessage( 66419, @cLangCode, 'DSP') --'LockLOCFail'
            -- ROLLBACK TRAN -- (ChewKP01)
            GOTO Step_3_Fail
         END

         -- COMMIT TRAN  -- (ChewKP01)

         SET @cSuggestedLoc = @cNewSuggestedLoc

         -- Prepare next screen var
         SET @cOutField01 = @cSuggestedLoc   -- LOC
         SET @cOutField02 = ''   -- LOC
         SET @cLOC = ''

         GOTO Quit
      END

      IF @cLOC <> @cSuggestedLOC
      BEGIN
         SET @nErrNo = 66420
         SET @cErrMsg = rdt.rdtgetmessage( 66420, @cLangCode,'DSP') --LOC diff
         GOTO Step_3_Fail
      END

      SET @cSuggestedSKU = ''
      SET @cLOT = ''
      SET @cOrderKey = ''
      SET @cOrderLineNumber = ''
      SET @cPickUOM = ''

      SELECT TOP 1
         @cSuggestedSKU = SKU,
         @cLOT = LOT,
         @cOrderKey = PD.OrderKey,
         @cOrderLineNumber = PD.OrderLineNumber,
         @cPickUOM = CASE WHEN @cDefaultPickByCase = '1' THEN '2' ELSE PD.UOM END -- (Vicky01)/(james07)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
      WHERE PD.StorerKey = @cStorerKey
         AND PD.Status < '4'
         AND PD.LOC = @cLOC
         AND O.LoadKey = @cLoadKey
      ORDER BY PD.SKU, PD.UOM

      IF ISNULL(@cSuggestedSKU, '') = ''
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = '66421 LOC'
         SET @cErrMsg2 = 'has no more'
         SET @cErrMsg3 = 'pick task!'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
            @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END
         GOTO Step_3_Fail
      END

      SELECT
        -- @cPackUOM1 = P.PACKUOM1,
         -- (Vicky01) - Start
         @cPickUOMDescr = CASE WHEN @cDefaultPickByCase = '1' THEN RTRIM(P.PackUOM1) 
                          ELSE CASE WHEN @cPickUOM = '1' THEN RTRIM(P.PackUOM4)
                                    WHEN @cPickUOM = '2' THEN RTRIM(P.PackUOM1)
                                    ELSE '' END END,
         @nPickUOMQty = CASE WHEN @cDefaultPickByCase = '1' THEN P.CaseCnt 
                        ELSE CASE WHEN @cPickUOM = '1' THEN P.Pallet
                                  WHEN @cPickUOM = '2' THEN P.CaseCnt
                                  ELSE P.QTY END END,
         -- (Vicky01) - End
         @cDescr = SKU.Descr
      FROM dbo.SKU SKU WITH (NOLOCK)
      JOIN dbo.PACK P WITH (NOLOCK) ON (SKU.PackKey = P.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSuggestedSKU

      --BEGIN TRAN  -- (ChewKP01)

      UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
         OrderKey = @cOrderKey,
         OrderLineNumber = @cOrderLineNumber,
         LOT = @cLOT,
         SKU = @cSuggestedSKU,
         UOM = @cPickUOM
      WHERE LoadKey = @cLoadKey
         AND StorerKey = @cStorerKey
         AND PutAwayZone = @cZone
         AND LOC = @cLOC
         AND AddWho = @cUserName
         AND Status = '1'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 66422
         SET @cErrMsg = rdt.rdtgetmessage( 66422, @cLangCode, 'DSP') --'LockLOCFail'
         --ROLLBACK TRAN  -- (ChewKP01)
         GOTO Step_3_Fail
      END

      --COMMIT TRAN  -- (ChewKP01)

      -- Getting the qtypicked
      SELECT @nQtyPicked = ISNULL(SUM(Qty), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      WHERE O.StorerKey = @cStorerKey
         AND O.LoadKey = @cLoadKey
         AND L.LOC = @cLOC
         AND L.PutAwayZone = @cZone
         AND L.Facility = @cFacility
         AND PD.Status >= '4' -- '4' consider picked but not confirm picked
         AND PD.SKU = @cSuggestedSKU

      -- Getting the allocated
      SELECT @nQtyAllocated = ISNULL(SUM(Qty), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      WHERE O.StorerKey = @cStorerKey
         AND O.LoadKey = @cLoadKey
         AND L.LOC = @cLOC
         AND L.PutAwayZone = @cZone
         AND L.Facility = @cFacility
         AND PD.SKU = @cSuggestedSKU

      -- Retrieve size (james03) & (james04)
      SELECT @cSize = '', @cStyle = ''
      SELECT @cSize = [Size], @cStyle = Style FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSuggestedSKU

      -- (jamesxxxxx)
      IF rdt.RDTGetConfig( @nFunc, 'CASEPICKALLOWKEYINQTY', @cStorerKey) <> '1'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = ISNULL(RTRIM(CAST(@nQtyPicked AS NVARCHAR( 5))), '0') + '/' + CAST(@nQtyAllocated AS NVARCHAR( 5))
         SET @cOutField02 = @cSuggestedSKU

         -- If SKU.size & SKU.Style is blank then display SKU.Descr else display SKU.Size (james03) & (james04)
         IF ISNULL(@cSize, '') = '' AND ISNULL(@cStyle, '') = ''
            SET @cOutField03 = SUBSTRING(@cDescr, 1, 20)
         ELSE
            SET @cOutField03 = CASE WHEN ISNULL(@cStyle, '') = '' THEN SPACE(13) + @cSize
            ELSE SUBSTRING(@cStyle, 1, 12) + SPACE(1) + @cSize
            END

         SET @cOutField04 = @cPickUOMDescr + CAST(@nPickUOMQty AS NVARCHAR( 5))  --@cPackUOM1 -- (Vicky01)
         SET @cOutField05 = ''

         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         SET @nPickedUOMQty = 0
         SET @nPickUOMQty = 0

         SELECT
         @nPickedUOMQty = CASE WHEN @cDefaultPickByCase = '1' THEN ISNULL( SUM( PD.QTY), 0) / P.CaseCnt -- (james07)
                          ELSE CASE WHEN @cPickUOM = '1' THEN ISNULL( SUM( PD.QTY), 0) / P.Pallet
                                    WHEN @cPickUOM = '2' THEN ISNULL( SUM( PD.QTY), 0) / P.CaseCnt
                                    ELSE ISNULL( SUM( PD.QTY), 0) END END 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)
         JOIN dbo.PACK P WITH (NOLOCK) ON (SKU.PackKey = P.PackKey)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSuggestedSKU
            AND PD.LOC = @cLOC
            AND LPD.LoadKey = @cLoadKey
            AND PD.Status = '5'
            AND PD.UOM = CASE WHEN @cDefaultPickByCase = '1' THEN PD.UOM ELSE @cPickUOM END
         GROUP BY P.Pallet, P.CaseCnt

         SELECT 
         @nPickUOMQty = CASE WHEN @cDefaultPickByCase = '1' THEN ISNULL( SUM( PD.QTY), 0) / P.CaseCnt -- (james07)
                        ELSE CASE WHEN @cPickUOM = '1' THEN ISNULL( SUM( PD.QTY), 0) / P.Pallet
                                  WHEN @cPickUOM = '2' THEN ISNULL( SUM( PD.QTY), 0) / P.CaseCnt
                                  ELSE ISNULL( SUM( PD.QTY), 0) END END
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)
         JOIN dbo.PACK P WITH (NOLOCK) ON (SKU.PackKey = P.PackKey)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSuggestedSKU
            AND PD.LOC = @cLOC
            AND LPD.LoadKey = @cLoadKey
            AND PD.Status = '0'
            AND PD.UOM = CASE WHEN @cDefaultPickByCase = '1' THEN PD.UOM ELSE @cPickUOM END
         GROUP BY P.Pallet, P.CaseCnt

         
         SET @cOutField01 = @cSuggestedSKU

         -- If SKU.size & SKU.Style is blank then display SKU.Descr else display SKU.Size (james03) & (james04)
         IF ISNULL(@cSize, '') = '' AND ISNULL(@cStyle, '') = ''
            SET @cOutField02 = SUBSTRING(@cDescr, 1, 20)
         ELSE
            SET @cOutField02 = CASE WHEN ISNULL(@cStyle, '') = '' THEN SPACE(13) + @cSize
            ELSE SUBSTRING(@cStyle, 1, 12) + SPACE(1) + @cSize END

         SET @cOutField03 = ''
         SET @cOutField04 = @cPickUOMDescr 
         SET @cOutField05 = CASE WHEN @nPickUOMQty = 0 THEN '0' ELSE CAST( @nPickUOMQty AS NVARCHAR( 5)) END
         SET @cOutField06 = CASE WHEN @nPickedUOMQty = 0 THEN '0' ELSE CAST( @nPickedUOMQty AS NVARCHAR( 5)) END
         SET @cOutField07 = ''

         EXEC rdt.rdtSetFocusField @nMobile, 1

         -- Go to next screen
         SET @nScn = @nScn + 5
         SET @nStep = @nStep + 6
      END
   END

   IF @nInputKey = 0 --ESC
   BEGIN
      --BEGIN TRAN  -- (ChewKP01)

      -- Clear the uncompleted task for the same login
      DELETE FROM RDT.RDTPickLock WITH (ROWLOCK)
      WHERE StorerKey = @cStorerKey
         AND LoadKey = @cLoadKey
         AND PutAwayZone = @cZone
         AND Status = '1'
         AND AddWho = @cUserName

      IF @@ERROR <> 0
      BEGIN
         --ROLLBACK TRAN  -- (ChewKP01)
         SET @nErrNo = 66423
         SET @cErrMsg = rdt.rdtgetmessage( 66423, @cLangCode, 'DSP') --'UnlockLOCFail'
         GOTO Quit
      END

      --COMMIT TRAN  -- (ChewKP01)

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      SET @cOutField01 = @cDoor   -- Door
      SET @cOutField02 = ''   -- PALLET ID
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cLOC = ''
      SET @cOutField02 = '' -- LOC
   END

END
GOTO Quit

/********************************************************************************
Step 4. Scn = 1963.
   SKU 99999/99999 (field01)
   SKU             (field02)
   DESCR           (field03)
   QTY             (field04)
   SKU             (field05, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
         --screen mapping
      SET @cSKU = @cInField05

      IF ISNULL(@cSKU, '') = ''
      BEGIN
         SET @nErrNo = 66424
         SET @cErrMsg = rdt.rdtgetmessage( 66424, @cLangCode,'DSP') --SKU/UPC needed
         GOTO Step_4_Fail
      END

      EXEC [RDT].[rdt_GETSKUCNT]
         @cStorerKey  = @cStorerKey,
         @cSKU        = @cSKU,
         @nSKUCnt     = @nSKUCnt       OUTPUT,
         @bSuccess    = @b_Success     OUTPUT,
         @nErr        = @n_Err         OUTPUT,
         @cErrMsg     = @c_ErrMsg      OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 66425
         SET @cErrMsg = rdt.rdtgetmessage( 66425, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_4_Fail
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = '66426 Same'
         SET @cErrMsg2 = 'Barcode in SKU'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
            @cErrMsg1, @cErrMsg2
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
         END
         GOTO Step_4_Fail
      END

      EXEC [RDT].[rdt_GETSKU]
         @cStorerKey  = @cStorerKey,
         @cSKU        = @cSKU          OUTPUT,
         @bSuccess    = @b_Success     OUTPUT,
         @nErr        = @n_Err         OUTPUT,
         @cErrMsg     = @c_ErrMsg      OUTPUT

      IF @cSuggestedSKU <> @cSKU
      BEGIN
         SET @nErrNo = 66427
         SET @cErrMsg = rdt.rdtgetmessage( 66427, @cLangCode, 'DSP') --'Different SKU'
         GOTO Step_4_Fail
      END

      -- Prepare next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = ''   --Case ID

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 --ESC
   BEGIN
         --For short pick purpose, system need to know which sku to short pick
         SET @cSKU = @cOutField02

         SET @nCurScn = 1963
         SET @nCurStep = 4

         -- Go to skip task screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2

         SET @cOutField01 = ''   -- Option
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cSKU = ''
      SET @cOutField05 = '' -- SKU
   END

END
GOTO Quit

/********************************************************************************
Step 5. Scn = 1964.
   SKU           (field01)
   CASE ID       (field02, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
         --screen mapping
      SET @cCaseID = @cInField02

      -- Validate blank
      IF ISNULL(@cCaseID, '') = ''
      BEGIN
         SET @nErrNo = 66428
         SET @cErrMsg = rdt.rdtgetmessage( 66428, @cLangCode,'DSP') --Case ID req
         GOTO Step_5_Fail
      END

      IF RDT.rdtIsValidQTY( @cCaseID, 0) = 0
      BEGIN
         SET @nErrNo = 66429
         SET @cErrMsg = rdt.rdtgetmessage( 66429, @cLangCode,'DSP') --Bad Case ID
         GOTO Step_5_Fail
      END

      --(james05)
      -- Stored Proc to validate Case ID
      SET @cCheckCaseID_SP = rdt.RDTGetConfig( @nFunc, 'CheckCaseID_SP', @cStorerKey)

      IF ISNULL(@cCheckCaseID_SP, '') NOT IN ('', '0')
      BEGIN
         SET @cSQLStatement = N'EXEC rdt.' + RTRIM(@cCheckCaseID_SP) +
                               ' @cStorerkey, @cSKU, @cCaseID, @nValid OUTPUT, @nErrNo OUTPUT,  @cErrMsg OUTPUT'

         SET @cSQLParms = N'@cStorerkey   NVARCHAR( 15),        ' +
                           '@cSKU         NVARCHAR( 20),        ' +
                           '@cCaseID      NVARCHAR( 10),        ' +
                           '@nValid       INT      OUTPUT,  ' +
                           '@nErrNo       INT      OUTPUT,  ' +
                           '@cErrMsg      NVARCHAR(20) OUTPUT '

         EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,
                              @cStorerKey,
                              @cSKU,
                              @cCaseID,
                              @nValid  OUTPUT,
                              @nErrNo  OUTPUT,
                              @cErrMsg OUTPUT

         IF @nErrNo <> 0
         BEGIN
            GOTO Step_5_Fail
         END

         IF @nValid = 0
         BEGIN
            SET @nErrNo = 66451
            SET @cErrMsg = rdt.rdtgetmessage( 66451, @cLangCode, 'DSP') --BAD Case ID
            GOTO Step_5_Fail
         END
      END--(james05)

      SET @nCartonNo = CAST(@cCaseID AS INT)

--       SELECT @nQTY = ISNULL(P.CaseCnt, 0)
--       FROM dbo.SKU SKU WITH (NOLOCK)
--       JOIN dbo.Pack P WITH (NOLOCK) ON (SKU.PackKey = P.PackKey)
--       WHERE SKU.StorerKey = @cStorerKey
--          AND SKU.SKU = @cSKU
      -- (Vicky01) - Start
      SELECT @nQTY = CASE WHEN @cPickUOM = '1' THEN ISNULL(P.Pallet, 0)
                          WHEN @cPickUOM = '2' THEN ISNULL(P.CaseCnt, 0)
                          ELSE P.QTY END
      FROM dbo.SKU SKU WITH (NOLOCK)
      JOIN dbo.Pack P WITH (NOLOCK) ON (SKU.PackKey = P.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU
      -- (Vicky01) - End


      IF RDT.rdtIsValidQTY( @nQTY, 1) = 0
      BEGIN
         SET @nErrNo = 66430
         SET @cErrMsg = rdt.rdtgetmessage( 66430, @cLangCode,'DSP') --Bad Case CNT
         GOTO Step_5_Fail
      END

      IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo)
      BEGIN
         SET @nErrNo = 66431
         SET @cErrMsg = rdt.rdtgetmessage( 66431, @cLangCode,'DSP') --Dup Case ID
         GOTO Step_5_Fail
      END

      -- Update CaseID to rdtpicklock
      BEGIN TRAN

      UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
         ID = @nCartonNo,
         PickQty = @nQty
      WHERE StorerKey = @cStorerKey
         AND LoadKey = @cLoadKey
         AND PutAwayZone = @cZone
         AND LOC = @cLOC
         AND SKU = @cSKU
         AND Status = '1'
         AND AddWho = @cUserName

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 66432
         SET @cErrMsg = rdt.rdtgetmessage( 66432, @cLangCode, 'DSP') --'Upd ID Fail'
         ROLLBACK TRAN
         GOTO Step_5_Fail
      END

      -- Getting sum pickqty from rdtpicklock for this load + zone + loc + sku
      SELECT @nPickLockQty = ISNULL(SUM( PickQty), 0)
      FROM RDT.RDTPickLock WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LoadKey = @cLoadKey
         AND PutAwayZone = @cZone
         AND LOC = @cLOC
         AND SKU = @cSKU
         AND Status = '1'
         AND AddWho = @cUserName

      -- Getting sum qty from pickdetail (allocated) for this load + zone + loc + sku
      SELECT @nPickDetailQty = ISNULL(SUM( Qty), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      WHERE O.StorerKey = @cStorerKey
         AND O.LoadKey = @cLoadKey
         AND L.LOC = @cLOC
         AND L.PutAwayZone = @cZone
         AND L.Facility = @cFacility
         AND PD.Status < '4'
         AND PD.SKU = @cSKU

      -- Check whether packheader exists
      IF NOT EXISTS (SELECT 1 FROM dbo.PACKHEADER WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
      BEGIN
         -- Conso Pickslipno
         IF @cPickSlipType = 'CONSO'
         BEGIN
            INSERT INTO dbo.PackHeader
            (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
             SELECT DISTINCT ISNULL(LP.Route,''), '', '', LP.LoadKey, '', @cStorerKey, @cPickSlipNo
             FROM  dbo.LOADPLANDETAIL LPD WITH (NOLOCK)
             JOIN  dbo.LOADPLAN LP WITH (NOLOCK) ON (LP.LoadKey = LPD.LoadKey)
             JOIN  dbo.ORDERS O WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
             JOIN  dbo.PICKHEADER PH WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
             WHERE PH.PickHeaderKey = @cPickSlipNo

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66433
               SET @cErrMsg = rdt.rdtgetmessage( 66433, @cLangCode, 'DSP') --'InsPHdrFail'
               ROLLBACK TRAN
               GOTO Step_5_Fail
            END
         END   -- @cPickSlipType = 'CONSO'
         ELSE
         BEGIN
            INSERT INTO dbo.PackHeader
            (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
            SELECT O.Route, O.OrderKey, O.ExternOrderKey, O.LoadKey, O.ConsigneeKey, O.Storerkey, @cPickSlipNo
            FROM  dbo.PickHeader PH WITH (NOLOCK)
            JOIN  dbo.Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey)
            WHERE PH.PickHeaderKey = @cPickSlipNo

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66434
               SET @cErrMsg = rdt.rdtgetmessage( 66434, @cLangCode, 'DSP') --'InsPHdrFail'
               ROLLBACK TRAN
               GOTO Step_5_Fail
            END
         END   -- @cPickSlipType = 'SINGLE'
      END   -- Check whether packheader exists


      -- Remove the insert packdetail, packinfo & create URN part (james02)
      EXEC RDT.rdt_Case_Pick_ConfirmTask
         @cStorerKey,
         @cUserName,
         @cFacility,
         @cZone,
         @cSKU,
         @cLoadKey,
         @cLOC,
         @cLOT,
         @cID,
         '5',
         @cPickSlipNo,
         @cLangCode,
         @cPickUOM, -- (Vicky01)
         @nErrNo          OUTPUT,
         @cErrMsg         OUTPUT,  -- screen limitation, 20 char max
         @nMobile, -- (Vicky06)
         @nFunc    -- (Vicky06)

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 66438
         SET @cErrMsg = rdt.rdtgetmessage( 66438, @cLangCode, 'DSP') --'CfmTaskFail'
         ROLLBACK TRAN
         GOTO Step_5_Fail
      END

      -- use primary key to update (james08)
      DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT RowRef FROM RDT.RDTPickLock WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   LoadKey = @cLoadKey
      AND   PutAwayZone = @cZone
      AND   LOC = @cLOC
      AND   SKU = @cSKU
      AND   AddWho = @cUserName
      AND   Status = '5'
      OPEN CUR_UPD
      FETCH NEXT FROM CUR_UPD INTO @nRowRef
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- Confirm this pick task
         UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
            Status = '9'
         WHERE RowRef = @nRowRef

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 66439
            SET @cErrMsg = rdt.rdtgetmessage( 66439, @cLangCode, 'DSP') --'CfmPLockFail'
            ROLLBACK TRAN
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
            GOTO Step_5_Fail
         END

         FETCH NEXT FROM CUR_UPD INTO @nRowRef
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD
         
      SET @cSuggestedSKU = ''
      SET @cLOT = ''
      SET @cOrderKey = ''
      SET @cOrderLineNumber = ''
      SET @cPickUOM = ''

      -- Check whether got available SKU in LOAD + ZONE + LOC
      SELECT TOP 1
         @cSuggestedSKU = SKU,
         @cLOT = LOT,
         @cOrderKey = PD.OrderKey,
         @cOrderLineNumber = PD.OrderLineNumber,
         @cPickUOM = CASE WHEN @cDefaultPickByCase = '1' THEN '2' ELSE PD.UOM END -- (Vicky01)/(james07)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
      WHERE PD.StorerKey = @cStorerKey
         AND PD.Status < '4'
         AND PD.LOC = @cLOC
         AND O.LoadKey = @cLoadKey
--         AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK)
--            WHERE RPL.LoadKey = @cLoadKey
--               AND RPL.StorerKey = @cStorerKey
--               AND PutAwayZone = @cZone
--               AND LOC = @cLOC
--               AND SKU = PD.SKU
--               AND RPL.AddWho <> @cUserName
--               AND RPL.Status = '1')
      ORDER BY PD.SKU, PD.UOM

      -- If this LOC got no more SKU to pick then goto next LOC
      IF ISNULL(@cSuggestedSKU, '') = ''
      BEGIN
         SELECT TOP 1
            @cLogicalLocation = L.LogicalLocation,
            @cNewSuggestedLoc = L.LOC
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.Status < '4'
            AND L.LogicalLocation + L.LOC >
               CONVERT(CHAR(18), ISNULL(@cLogicalLocation, '')) + CONVERT(CHAR(10), ISNULL(@cSuggestedLoc, ''))
            AND L.Facility = @cFacility
            AND L.PutawayZone = @cZone
            AND O.LoadKey = @cLoadKey
            AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK)
               WHERE RPL.LoadKey = @cLoadKey
                  AND RPL.StorerKey = @cStorerKey
                  AND RPL.PutAwayZone = @cZone
                  AND RPL.LOC = PD.LOC
                  AND RPL.AddWho <> @cUserName
                  AND RPL.Status = '1')
         GROUP BY L.LogicalLocation, L.LOC
         ORDER BY L.LogicalLocation, L.LOC

         -- Getting the QTY Packed
         SELECT @nQtyPacked = ISNULL(SUM(PAD.Qty), 0)
         FROM dbo.PackDetail PAD WITH (NOLOCK)
         JOIN dbo.PackHeader PAH WITH (NOLOCK) ON (PAD.PickSlipNo = PAH.PickSlipNo)
         JOIN dbo.PickHeader PIH WITH (NOLOCK) ON (PAH.PickSlipNo = PIH.PickHeaderKey)
         WHERE PIH.ExternOrderKey = @cLoadKey
            AND PIH.Status = '0'

         -- Getting the QTY Picked
         SELECT @nQtyAllocated = ISNULL(SUM(PD.Qty), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE O.StorerKey = @cStorerKey
            AND O.LoadKey = @cLoadKey
--            AND L.LOC = @cLOC
--            AND L.PutAwayZone = @cZone
            AND L.Facility = @cFacility
--            AND PD.Status >= '4'
            AND PD.Status < '9'

         -- If no more LOC to pick then goto screen 7
         IF ISNULL(@cNewSuggestedLoc, '') = ''
         BEGIN
            IF @cAutoPackConfirm = '1' AND (@nQtyPacked = @nQtyAllocated)
            BEGIN
               IF EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo)
               BEGIN
                  UPDATE dbo.PackHeader WITH (ROWLOCK) SET
                     Status = '9'
                  WHERE PickSlipNo = @cPickSlipNo

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 66440
                     SET @cErrMsg = rdt.rdtgetmessage( 66440, @cLangCode, 'DSP') --'CfmPHdrFail'
                     ROLLBACK TRAN
                     GOTO Step_5_Fail
                  END
               END
            END   -- @cAutoPackConfirm

            -- Go to screen 7
            SET @nScn = @nScn + 2
            SET @nStep = @nStep + 2

            COMMIT TRAN -- (ChewKP01)

            GOTO Quit
         END   -- IF ISNULL(@cNewSuggestedLoc, '') = ''
         ELSE  -- Got other LOC to pick then goto screen 2
         BEGIN
            -- Start lock down the task (Load + Zone + Loc)
            IF NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND LoadKey = @cLoadKey
                  AND PutAwayZone = @cZone
                  AND LOC = @cSuggestedLOC
                  AND Status = '1')
            BEGIN
               --BEGIN TRAN  -- (ChewKP01)

               INSERT INTO RDT.RDTPickLock
               (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey, LOT, LOC, SKU, Status, AddWho, AddDate, DropID, PickSlipNo, UOM, Mobile) -- (Vicky01)
               VALUES
               ('', @cLoadKey, '', '', @cStorerKey, @cZone, '', '', '', @cNewSuggestedLoc, '', '1', @cUserName, GETDATE(), @cID, @cPickSlipNo, '', @nMobile)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 66416
                  SET @cErrMsg = rdt.rdtgetmessage( 66416, @cLangCode, 'DSP') --'LockLOCFail'
                  ROLLBACK TRAN
                  GOTO Step_5_Fail
               END

               -- COMMIT TRAN  -- (ChewKP01)
            END
            ELSE
            BEGIN
               SET @nErrNo = 66417
               SET @cErrMsg = rdt.rdtgetmessage( 66417, @cLangCode, 'DSP') --'LOC Locked'
               ROLLBACK TRAN
               GOTO Step_5_Fail
            END

            SET @cSuggestedLoc = @cNewSuggestedLoc

            -- Prepare next screen var
            SET @cOutField01 = @cSuggestedLOC
            SET @cOutField02 = ''   --LOC
            SET @cLOC = ''

            -- Go to next screen
            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2

            COMMIT TRAN -- (ChewKP01)

            GOTO Quit
         END
      END
      ELSE  -- The same LOC got next SKU to pick, start locking
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND LoadKey = @cLoadKey
               AND PutAwayZone = @cZone
               AND LOC = @cLOC
               AND Status = '1')
         BEGIN
            INSERT INTO RDT.RDTPickLock
            (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey, LOT, LOC, SKU, Status, AddWho, AddDate, DropID, PickSlipNo, UOM, Mobile) -- (Vicky01)
            VALUES
            ('', @cLoadKey, @cOrderKey, @cOrderLineNumber, @cStorerKey, @cZone, '', '', @cLOT, @cLOC, @cSuggestedSKU, '1', @cUserName, GETDATE(), @cID, @cPickSlipNo, @cPickUOM, @nMobile)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66416
               SET @cErrMsg = rdt.rdtgetmessage( 66416, @cLangCode, 'DSP') --'LockLOCFail'
               ROLLBACK TRAN
               GOTO Step_5_Fail
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 66417
            SET @cErrMsg = rdt.rdtgetmessage( 66417, @cLangCode, 'DSP') --'LOC Locked'
            ROLLBACK TRAN
            GOTO Step_5_Fail
         END

         SELECT
            --@cPackUOM1 = P.PACKUOM1,
            -- (Vicky01) - Start
            @cPickUOMDescr = CASE WHEN @cDefaultPickByCase = '1' THEN RTRIM(P.PackUOM1) 
                             ELSE CASE WHEN @cPickUOM = '1' THEN RTRIM(P.PackUOM4)
                                       WHEN @cPickUOM = '2' THEN RTRIM(P.PackUOM1)
                                       ELSE '' END END,
            @nPickUOMQty = CASE WHEN @cDefaultPickByCase = '1' THEN P.CaseCnt 
                           ELSE CASE WHEN @cPickUOM = '1' THEN P.Pallet
                                     WHEN @cPickUOM = '2' THEN P.CaseCnt
                                     ELSE P.QTY END END,
           -- (Vicky01) - End
            @cDescr = SKU.Descr
         FROM dbo.SKU SKU WITH (NOLOCK)
         JOIN dbo.PACK P WITH (NOLOCK) ON (SKU.PackKey = P.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cSuggestedSKU

         -- Getting the qtypicked
         SELECT @nQtyPicked = ISNULL(SUM(Qty), 0) FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE O.StorerKey = @cStorerKey
            AND O.LoadKey = @cLoadKey
            AND L.LOC = @cLOC
            AND L.PutAwayZone = @cZone
            AND L.Facility = @cFacility
            AND PD.Status >= '4'
            AND PD.Status < '9'
            AND PD.SKU = @cSuggestedSKU

         -- Getting the allocated
         SELECT @nQtyAllocated = ISNULL(SUM(Qty), 0) FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE O.StorerKey = @cStorerKey
            AND O.LoadKey = @cLoadKey
            AND L.LOC = @cLOC
            AND L.PutAwayZone = @cZone
            AND L.Facility = @cFacility
            AND PD.SKU = @cSuggestedSKU

         -- Retrieve size (james03) & (james04)
         SELECT @cSize = '', @cStyle = ''
         SELECT @cSize = [Size], @cStyle = Style FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSuggestedSKU

         -- Prepare next screen var
         SET @cOutField01 = ISNULL(RTRIM(CAST(@nQtyPicked AS NVARCHAR( 5))), '0') + '/' + CAST(@nQtyAllocated AS NVARCHAR( 5))
         SET @cOutField02 = @cSuggestedSKU

         -- If SKU.size is blank then display SKU.Descr else display SKU.Size (james03) & (james04)
         IF ISNULL(@cSize, '') = '' AND ISNULL(@cStyle, '') = ''
            SET @cOutField03 = SUBSTRING(@cDescr, 1, 20)
         ELSE
            SET @cOutField03 = CASE WHEN ISNULL(@cStyle, '') = '' THEN SPACE(13) + @cSize
            ELSE SUBSTRING(@cStyle, 1, 12) + SPACE(1) + @cSize
            END


         SET @cOutField04 = @cPickUOMDescr + CAST(@nPickUOMQty AS NVARCHAR( 5)) --@cPackUOM1 -- (Vicky01)
         SET @cOutField05 = ''

         -- Go to next screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1

         COMMIT TRAN

         GOTO Quit
      END

      COMMIT TRAN

      -- Prepare next screen var
      SET @cOutField01 = @cSuggestedLOC
      SET @cOutField02 = ''   --LOC
      SET @cLOC = ''

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 --ESC
   BEGIN
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      SET @nCurScn = 1964
      SET @nCurStep = 5

      SET @cOutField01 = ''   -- Option
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cCaseID = ''
      SET @cOutField02 = '' -- Case ID
   END

END
GOTO Quit

/********************************************************************************
Step 6. Scn = 1965.
   OPTION        (field01, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
         --screen mapping
      SET @cOption = @cInField01

      --if input is not either '1' or '2'
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 66441
         SET @cErrMsg = rdt.rdtgetmessage( 66441, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_6_Fail
      END

      IF @cOption = '1'
      BEGIN
         IF @cSHOWSHTPICKRSN = '1'
         BEGIN
            SET @cOutField01 = 1          -- case picking, default is 1 case
            SET @cOutField02 = @cPickUOMDescr --@cPackUOM1 -- case picking -- (Vicky01)
            SET @cOutField03 = ''
            SET @cOutField04 = ''
            SET @cOutField05 = ''

            -- Save current screen no
            SET @nCurScn = @nScn
            SET @nCurStep = @nStep

            -- Go to STD short pick screen
            SET @nScn = 2010
            SET @nStep = @nStep + 2
         END
         GOTO Quit
      END

      IF @cOption = '2'
      BEGIN

         --BEGIN TRAN  --(ChewKP01)

         -- Clear the uncompleted task for the same login
         DELETE FROM RDT.RDTPickLock WITH (ROWLOCK)
         WHERE StorerKey = @cStorerKey
            AND LoadKey = @cLoadKey
            AND PutAwayZone = @cZone
            AND Status = '1'
            AND AddWho = @cUserName

         IF @@ERROR <> 0
         BEGIN
            --ROLLBACK TRAN  --(ChewKP01)
            SET @nErrNo = 66442
            SET @cErrMsg = rdt.rdtgetmessage( 62442, @cLangCode, 'DSP') --'UnLockFail'
            GOTO Quit
         END

         --COMMIT TRAN  --(ChewKP01)

         SET @cOutField01 = @cDoor
         SET @cOutField02 = ''   -- PALLET ID
         SET @cID = ''

         -- Go to PLTID screen
         SET @nScn = @nScn - 4
         SET @nStep = @nStep - 4
         GOTO Quit
      END
   END

   IF @nInputKey = 0 --ESC
  BEGIN
      IF @nCurStep = 5
      BEGIN
         -- Go to case id screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1

         SET @cOutField01 = @cSKU
         SET @cOutField02 = '' -- Case ID
      END
      ELSE
      BEGIN
         SELECT TOP 1 @cSuggestedSKU = SKU, 
                      @cLOT = LOT, 
                      @cOrderKey = PD.OrderKey, 
                      @cPickUOM = CASE WHEN @cDefaultPickByCase = '1' THEN '2' ELSE PD.UOM END -- (Vicky01)/(james07)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.Status < '4'
            AND PD.LOC = @cLOC
            AND O.LoadKey = @cLoadKey
         ORDER BY PD.SKU, PD.UOM

         SELECT
            --@cPackUOM1 = P.PACKUOM1,
           -- (Vicky01) - Start
            @cPickUOMDescr = CASE WHEN @cDefaultPickByCase = '1' THEN RTRIM(P.PackUOM1) -- (james07)
                             ELSE CASE WHEN @cPickUOM = '1' THEN RTRIM(P.PackUOM4)
                                       WHEN @cPickUOM = '2' THEN RTRIM(P.PackUOM1)
                                       ELSE '' END END,
            @nPickUOMQty = CASE WHEN @cDefaultPickByCase = '1' THEN P.CaseCnt -- (james07)
                           ELSE CASE WHEN @cPickUOM = '1' THEN P.Pallet
                                     WHEN @cPickUOM = '2' THEN P.CaseCnt
                                     ELSE P.QTY END END,
           -- (Vicky01) - End
            @cDescr = SKU.Descr
         FROM dbo.SKU SKU WITH (NOLOCK)
         JOIN dbo.PACK P WITH (NOLOCK) ON (SKU.PackKey = P.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cSuggestedSKU

         -- Getting the qtypicked
         SELECT @nQtyPicked = ISNULL(SUM(Qty), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE O.StorerKey = @cStorerKey
            AND O.LoadKey = @cLoadKey
            AND L.LOC = @cLOC
            AND L.PutAwayZone = @cZone
            AND L.Facility = @cFacility
            AND PD.Status >= '4' -- '4' consider picked but not confirm picked
            AND PD.SKU = @cSuggestedSKU

         -- Getting the allocated
         SELECT @nQtyAllocated = ISNULL(SUM(Qty), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE O.StorerKey = @cStorerKey
            AND O.LoadKey = @cLoadKey
            AND L.LOC = @cLOC
            AND L.PutAwayZone = @cZone
            AND L.Facility = @cFacility
            AND PD.SKU = @cSuggestedSKU

         -- Retrieve size (james03) & (james04)
         SELECT @cSize = '', @cStyle = ''
         SELECT @cSize = [Size], @cStyle = Style FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSuggestedSKU

         -- Prepare next screen var
         SET @cOutField01 = ISNULL(RTRIM(CAST(@nQtyPicked AS NVARCHAR( 5))), '0') + '/' + CAST(@nQtyAllocated AS NVARCHAR( 5))
         SET @cOutField02 = @cSuggestedSKU

         -- If SKU.size & SKU.Style is blank then display SKU.Descr else display SKU.Size (james03) & (james04)
         IF ISNULL(@cSize, '') = '' AND ISNULL(@cStyle, '') = ''
            SET @cOutField03 = SUBSTRING(@cDescr, 1, 20)
         ELSE
            SET @cOutField03 = CASE WHEN ISNULL(@cStyle, '') = '' THEN SPACE(13) + @cSize
            ELSE SUBSTRING(@cStyle, 1, 12) + SPACE(1) + @cSize
            END

         SET @cOutField04 = @cPickUOMDescr + CAST(@nPickUOMQty AS NVARCHAR( 5)) --@cPackUOM1 -- (Vicky01)
         SET @cOutField05 = ''

         -- Go to sku screen
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
      END
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
Step 7. Scn = 1966.
   MSG        (field01, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey IN (0, 1) --ENTER/ESC
   BEGIN
      -- Initiate var
      SET @cLoadKey = ''
      SET @cZone = ''

      -- Init screen
      SET @cOutField01 = '' -- LoadKey
      SET @cOutField02 = '' -- Zone

      -- Go to screen 1
      SET @nScn = @nScn - 6
      SET @nStep = @nStep - 6
   END
END
GOTO Quit

/********************************************************************************
Step 8. Scn = 1967.
   RSN        (field01, input)
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
         --screen mapping
      SET @cReasonCode = @cInField05

      IF ISNULL(@cReasonCode, '') = ''
      BEGIN
         SET @nErrNo = 66443
         SET @cErrMsg = rdt.rdtgetmessage( 66443, @cLangCode, 'DSP') --'BAD Reason'
         GOTO Step_8_Fail
      END

      SELECT @cModuleName = StoredProcName FROM RDT.RDTMsg WITH (NOLOCK) WHERE Message_id = @nFunc

      EXEC rdt.rdt_STD_Short_Pick
         @nFunc,
         @nMobile,
         @cLangCode,
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT, -- screen limitation, 20 char max
         @cStorerKey,
         @cFacility,
         @cPickSlipNo,
         @cLoadKey,
         @cWaveKey,
         @cOrderKey,
         @cLOC,
         @cID,
         @cSKU,
         @cPUOM,
         @nQTY,       -- In master unit
         @cLottable01,
         @cLottable02,
         @cLottable03,
         @dLottable04,
         @dLottable05,
         @cReasonCode,
         @cUserName,
         @cModuleName

      IF @nErrNo <> 0
      BEGIN
         GOTO Step_8_Fail
      END

      -- Short Pick hadling start
      BEGIN TRAN

      -- If short pick need then need to short pick all qty in same load + zone + loc + sku
      SELECT @nShortPickedQty = SUM(PD.QTY) FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
      JOIN dbo.LOC L WITH (NOLOCK) ON PD.LOC = L.LOC
      WHERE PD.StorerKey = @cStorerKey
         AND PD.SKU = @cSKU
         AND PD.Status < '4'
         AND O.LoadKey = @cLoadKey
         AND L.PutawayZone = @cZone
         AND L.LOC = @cLOC

      UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
         PickQty = @nShortPickedQty
      WHERE StorerKey = @cStorerKey
         AND LoadKey = @cLoadKey
         AND PutAwayZone = @cZone
         AND LOC = @cLOC
         AND SKU = @cSKU
         AND Status = '1'
         AND AddWho = @cUserName

      EXEC RDT.rdt_Case_Pick_ConfirmTask
         @cStorerKey,
         @cUserName,
         @cFacility,
         @cZone,
         @cSKU,
         @cLoadKey,
         @cLOC,
         @cLOT,
         @cID,
         '4',
         @cPickSlipNo,
         @cLangCode,
         @cPickUOM, -- (Vicky01)
         @nErrNo          OUTPUT,
         @cErrMsg         OUTPUT,  -- screen limitation, 20 char max
         @nMobile, -- (Vicky06)
         @nFunc    -- (Vicky06)

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 66444
         SET @cErrMsg = rdt.rdtgetmessage( 66444, @cLangCode, 'DSP') --'CfmTaskFail'
         ROLLBACK TRAN
         GOTO Step_8_Fail
      END

      -- use primary key to update (james08)
      DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT RowRef FROM RDT.RDTPickLock WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   LoadKey = @cLoadKey
      AND   PutAwayZone = @cZone
      AND   LOC = @cLOC
      AND   SKU = @cSKU
      AND   AddWho = @cUserName
      AND   Status = '5'
      OPEN CUR_UPD
      FETCH NEXT FROM CUR_UPD INTO @nRowRef
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- Confirm this pick task
         UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
            Status = '9'
         WHERE RowRef = @nRowRef

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '66445 Confirm'
            SET @cErrMsg2 = 'PickLock fail!'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
            END
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
            ROLLBACK TRAN
            GOTO Step_8_Fail
         END

         FETCH NEXT FROM CUR_UPD INTO @nRowRef
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD

      SET @cSuggestedSKU = ''
      SET @cLOT = ''

      -- Check whether got available SKU in LOAD + ZONE + LOC
      SELECT TOP 1
         @cSuggestedSKU = SKU,
         @cLOT = LOT,
         @cOrderKey = PD.OrderKey,
         @cOrderLineNumber = PD.OrderLineNumber,
         @cPickUOM = CASE WHEN @cDefaultPickByCase = '1' THEN '2' ELSE PD.UOM END -- (Vicky01)/(james07)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
      WHERE PD.StorerKey = @cStorerKey
         AND PD.Status < '4'
         AND PD.LOC = @cLOC
         AND O.LoadKey = @cLoadKey
      ORDER BY PD.SKU, PD.UOM

      -- If this LOC got no more SKU to pick then goto next LOC
      IF ISNULL(@cSuggestedSKU, '') = ''
      BEGIN
         SELECT TOP 1
            @cLogicalLocation = L.LogicalLocation,
            @cNewSuggestedLoc = L.LOC
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.Status < '4'
            AND L.LogicalLocation + L.LOC >
               CONVERT(CHAR(18), ISNULL(@cLogicalLocation, '')) + CONVERT(CHAR(10), ISNULL(@cSuggestedLoc, ''))
            AND L.Facility = @cFacility
            AND L.PutawayZone = @cZone
            AND O.LoadKey = @cLoadKey
            AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK)
               WHERE RPL.LoadKey = @cLoadKey
                  AND RPL.StorerKey = @cStorerKey
                  AND RPL.PutAwayZone = @cZone
                  AND RPL.LOC = PD.LOC
                  AND RPL.AddWho <> @cUserName
                  AND RPL.Status = '1')
         GROUP BY L.LogicalLocation, L.LOC
         ORDER BY L.LogicalLocation, L.LOC

         -- Getting the QTY Packed
         SELECT @nQtyPacked = ISNULL(SUM(PAD.Qty), 0)
         FROM dbo.PackDetail PAD WITH (NOLOCK)
         JOIN dbo.PackHeader PAH WITH (NOLOCK) ON (PAD.PickSlipNo = PAH.PickSlipNo)
         JOIN dbo.PickHeader PIH WITH (NOLOCK) ON (PAH.PickSlipNo = PIH.PickHeaderKey)
         WHERE PIH.ExternOrderKey = @cLoadKey
            AND PIH.Status = '0'

         -- Getting the QTY Picked
         SELECT @nQtyAllocated = ISNULL(SUM(PD.Qty), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE O.StorerKey = @cStorerKey
            AND O.LoadKey = @cLoadKey
--            AND L.LOC = @cLOC
--            AND L.PutAwayZone = @cZone
            AND L.Facility = @cFacility
--            AND PD.Status >= '4'
            AND PD.Status < '9'

         -- If no more LOC to pick then goto screen 7
         IF ISNULL(@cNewSuggestedLoc, '') = ''
         BEGIN
            IF @cAutoPackConfirm = '1' AND (@nQtyPacked = @nQtyAllocated)
            BEGIN
               IF EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)
             WHERE PickSlipNo = @cPickSlipNo)
               BEGIN
                  UPDATE dbo.PackHeader WITH (ROWLOCK) SET
                     Status = '9'
                  WHERE PickSlipNo = @cPickSlipNo

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 0
                     SET @cErrMsg1 = '66446 '
                     SET @cErrMsg2 = 'PackHeader'
                     SET @cErrMsg3 = 'confirm fail!'
                     EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
                        @cErrMsg1, @cErrMsg2, @cErrMsg3
                     IF @nErrNo = 1
                     BEGIN
                        SET @cErrMsg1 = ''
                        SET @cErrMsg2 = ''
                        SET @cErrMsg3 = ''
                     END
                     ROLLBACK TRAN
                     GOTO Step_8_Fail
                  END
               END
            END   -- @cAutoPackConfirm

            -- Go to screen 7
            SET @nScn = @nCurScn + 1
            SET @nStep = @nCurStep + 1

            COMMIT TRAN

            GOTO Quit
         END   -- IF ISNULL(@cNewSuggestedLoc, '') = ''
         ELSE  -- Got other LOC to pick then goto screen 2
         BEGIN
            -- Start lock down the task (Load + Zone + Loc)
            IF NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND LoadKey = @cLoadKey
                  AND PutAwayZone = @cZone
                  AND LOC = @cSuggestedLOC
                  AND Status = '1')
            BEGIN
               --BEGIN TRAN  --(ChewKP01)

               INSERT INTO RDT.RDTPickLock
               (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey, LOT, LOC, SKU, Status, AddWho, AddDate, DropID, PickSlipNo, UOM, Mobile) -- (Vicky01)
               VALUES
               ('', @cLoadKey, '', '', @cStorerKey, @cZone, '', '', '', @cNewSuggestedLoc, '', '1', @cUserName, GETDATE(), @cID, @cPickSlipNo, '', @nMobile)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 66447
                  SET @cErrMsg = rdt.rdtgetmessage( 66416, @cLangCode, 'DSP') --'LockLOCFail'
                  ROLLBACK TRAN
                  GOTO Step_8_Fail
               END

               --COMMIT TRAN  --(ChewKP01)
            END
            ELSE
            BEGIN
               SET @nErrNo = 66448
               SET @cErrMsg = rdt.rdtgetmessage( 66448, @cLangCode, 'DSP') --'LOC Locked'
               ROLLBACK TRAN
               GOTO Step_8_Fail
            END

            SET @cSuggestedLoc = @cNewSuggestedLoc

            -- Prepare next screen var
            SET @cOutField01 = @cSuggestedLOC
            SET @cOutField02 = ''   --LOC
            SET @cLOC = ''

            -- Go to next screen
            SET @nScn = @nCurScn - 3
            SET @nStep = @nCurStep - 3

            COMMIT TRAN

            GOTO Quit
         END
      END
      ELSE  -- The same LOC got next SKU to pick, start locking
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND LoadKey = @cLoadKey
               AND PutAwayZone = @cZone
               AND LOC = @cLOC
               AND Status = '1')
         BEGIN
            INSERT INTO RDT.RDTPickLock
            (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey, LOT, LOC, SKU, Status, AddWho, AddDate, DropID, PickSlipNo, UOM, Mobile) -- (Vicky01)
            VALUES
            ('', @cLoadKey, @cOrderKey, @cOrderLineNumber, @cStorerKey, @cZone, '', '', @cLOT, @cLOC, @cSuggestedSKU, '1', @cUserName, GETDATE(), @cID, @cPickSlipNo, @cPickUOM, @nMobile)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66449
               SET @cErrMsg = rdt.rdtgetmessage( 66416, @cLangCode, 'DSP') --'LockLOCFail'
               ROLLBACK TRAN
               GOTO Step_8_Fail
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 66450
            SET @cErrMsg = rdt.rdtgetmessage( 66450, @cLangCode, 'DSP') --'LOC Locked'
            ROLLBACK TRAN
            GOTO Step_8_Fail
         END

         SELECT
            --@cPackUOM1 = P.PACKUOM1,
           -- (Vicky01) - Start
            @cPickUOMDescr = CASE WHEN @cDefaultPickByCase = '1' THEN P.PackUOM1    -- (james07)
                             ELSE CASE WHEN @cPickUOM = '1' THEN RTRIM(P.PackUOM4)
                                       WHEN @cPickUOM = '2' THEN RTRIM(P.PackUOM1)
                                       ELSE '' END END,
            @nPickUOMQty = CASE WHEN @cDefaultPickByCase = '1' THEN P.CaseCnt       -- (james07)
                           ELSE CASE WHEN @cPickUOM = '1' THEN P.Pallet
                                     WHEN @cPickUOM = '2' THEN P.CaseCnt
                                     ELSE P.QTY END END,             -- (Vicky01) - End
            @cDescr = SKU.Descr
         FROM dbo.SKU SKU WITH (NOLOCK)
         JOIN dbo.PACK P WITH (NOLOCK) ON (SKU.PackKey = P.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cSuggestedSKU

         -- Getting the qtypicked
         SELECT @nQtyPicked = ISNULL(SUM(Qty), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE O.StorerKey = @cStorerKey
            AND O.LoadKey = @cLoadKey
            AND L.LOC = @cLOC
            AND L.PutAwayZone = @cZone
            AND L.Facility = @cFacility
            AND PD.Status >= '4' -- '4' consider picked but not confirm picked
            AND PD.SKU = @cSuggestedSKU

         -- Getting the allocated
         SELECT @nQtyAllocated = ISNULL(SUM(Qty), 0) FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE O.StorerKey = @cStorerKey
            AND O.LoadKey = @cLoadKey
            AND L.LOC = @cLOC
            AND L.PutAwayZone = @cZone
            AND L.Facility = @cFacility
            AND PD.SKU = @cSuggestedSKU

         -- Retrieve size (james03) & (james04)
         SELECT @cSize = '', @cStyle = ''
         SELECT @cSize = [Size], @cStyle = Style FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSuggestedSKU

         -- Prepare next screen var
         SET @cOutField01 = ISNULL(RTRIM(CAST(@nQtyPicked AS NVARCHAR( 5))), '0') + '/' + CAST(@nQtyAllocated AS NVARCHAR( 5))
         SET @cOutField02 = @cSuggestedSKU

         -- If SKU.size & SKU.Style is blank then display SKU.Descr else display SKU.Size (james03) & (james04)
         IF ISNULL(@cSize, '') = '' AND ISNULL(@cStyle, '') = ''
            SET @cOutField03 = SUBSTRING(@cDescr, 1, 20)
         ELSE
            SET @cOutField03 = CASE WHEN ISNULL(@cStyle, '') = '' THEN SPACE(13) + @cSize
            ELSE SUBSTRING(@cStyle, 1, 12) + SPACE(1) + @cSize
            END

         SET @cOutField04 = @cPickUOMDescr + CAST(@nPickUOMQty AS NVARCHAR( 5)) --@cPackUOM1 -- (Vicky01)
         SET @cOutField05 = ''

         -- Go to next screen
         SET @nScn = @nCurScn - 2
         SET @nStep = @nCurStep - 2

         COMMIT TRAN

         GOTO Quit
      END
   END

   IF @nInputKey = 0 --ESC
   BEGIN
      SELECT
         --@cPackUOM1 = P.PACKUOM1,
 -- (Vicky01) - Start
          @cPickUOMDescr = CASE WHEN @cDefaultPickByCase = '1' THEN P.PackUOM1 
                           ELSE CASE WHEN @cPickUOM = '1' THEN RTRIM(P.PackUOM4)
                                     WHEN @cPickUOM = '2' THEN RTRIM(P.PackUOM1)
                                     ELSE '' END END,
          @nPickUOMQty = CASE WHEN @cDefaultPickByCase = '1' THEN P.CaseCnt 
                         ELSE CASE WHEN @cPickUOM = '1' THEN P.Pallet
                                   WHEN @cPickUOM = '2' THEN P.CaseCnt
                                   ELSE P.QTY END END,
           -- (Vicky01) - End
         @cDescr = SKU.Descr
      FROM dbo.SKU SKU WITH (NOLOCK)
      JOIN dbo.PACK P WITH (NOLOCK) ON (SKU.PackKey = P.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU

      -- Getting the qtypicked
      SELECT @nQtyPicked = ISNULL(SUM(Qty), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      WHERE O.StorerKey = @cStorerKey
         AND O.LoadKey = @cLoadKey
         AND L.LOC = @cLOC
         AND L.PutAwayZone = @cZone
         AND L.Facility = @cFacility
         AND PD.Status >= '4' -- '4' consider picked but not confirm picked
         AND PD.SKU = @cSKU

      -- Getting the allocated
      SELECT @nQtyAllocated = ISNULL(SUM(Qty), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      WHERE O.StorerKey = @cStorerKey
         AND O.LoadKey = @cLoadKey
         AND L.LOC = @cLOC
         AND L.PutAwayZone = @cZone
         AND L.Facility = @cFacility
--         AND PD.Status < '4'
         AND PD.SKU = @cSKU

      -- Retrieve size (james03) & (james04)
      SELECT @cSize = '', @cStyle = ''
      SELECT @cSize = [Size], @cStyle = Style FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSuggestedSKU

      -- Go to prev screen
      SET @cOutField01 = ISNULL(RTRIM(CAST(@nQtyPicked AS NVARCHAR( 5))), '0') + '/' + CAST(@nQtyAllocated AS NVARCHAR( 5))
      SET @cOutField02 = @cSuggestedSKU

      -- If SKU.size & SKU.Style is blank then display SKU.Descr else display SKU.Size (james03) & (james04)
      IF ISNULL(@cSize, '') = '' AND ISNULL(@cStyle, '') = ''
         SET @cOutField03 = SUBSTRING(@cDescr, 1, 20)
      ELSE
         SET @cOutField03 = CASE WHEN ISNULL(@cStyle, '') = '' THEN SPACE(13) + @cSize
         ELSE SUBSTRING(@cStyle, 1, 12) + SPACE(1) + @cSize
         END

      SET @cOutField04 = @cPickUOMDescr + CAST(@nPickUOMQty AS NVARCHAR( 5)) -- @cPackUOM1 -- (Vicky01)
      SET @cOutField05 = ''

      SET @nScn = @nCurScn - 2
      SET @nStep = @nCurStep - 2
   END
   GOTO Quit

   Step_8_Fail:
   BEGIN
      SET @cReasonCode = ''
      SET @cOutField05 = '' -- RSN
   END

END
GOTO Quit

/********************************************************************************
Step 9. Scn = 1967.
   SKU 99999/99999 (field01)
   SKU             (field02)
   DESCR           (field03)
   QTY             (field04)
   SKU             (field05, input)
********************************************************************************/
Step_9:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
         --screen mapping
      SET @cSKU = @cInField03
      SET @cQty = @cInField07

      IF ISNULL(@cSKU, '') = ''
      BEGIN
         SET @cOutField01 = @cLoadKey
         SET @cOutField02 = @cZone
         SET @cOutField03 = @cLOC
         SET @cOutField04 = @cSuggestedSKU
         SET @cOutField05 = @cPickUOMDescr
         SET @cOutField06 = @nPickUOMQty
         SET @cOutField07 = ''
         
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
         
         GOTO Quit
--         SET @nErrNo = 66452
--         SET @cErrMsg = rdt.rdtgetmessage( 66424, @cLangCode,'DSP') --SKU/UPC needed
--         GOTO Step_9_SKU_Fail
      END

      EXEC [RDT].[rdt_GETSKUCNT]
         @cStorerKey  = @cStorerKey,
         @cSKU        = @cSKU,
         @nSKUCnt     = @nSKUCnt       OUTPUT,
         @bSuccess    = @b_Success     OUTPUT,
         @nErr        = @n_Err         OUTPUT,
         @cErrMsg     = @c_ErrMsg      OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 66453
         SET @cErrMsg = rdt.rdtgetmessage( 66425, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_9_SKU_Fail
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = '66454 Same'
         SET @cErrMsg2 = 'Barcode in SKU'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
            @cErrMsg1, @cErrMsg2
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
         END
         GOTO Step_9_SKU_Fail
      END

      EXEC [RDT].[rdt_GETSKU]
         @cStorerKey  = @cStorerKey,
         @cSKU        = @cSKU          OUTPUT,
         @bSuccess    = @b_Success     OUTPUT,
         @nErr        = @n_Err         OUTPUT,
         @cErrMsg     = @c_ErrMsg      OUTPUT

      IF @cSuggestedSKU <> @cSKU
      BEGIN
         SET @nErrNo = 66455
         SET @cErrMsg = rdt.rdtgetmessage( 66427, @cLangCode, 'DSP') --'Different SKU'
         GOTO Step_9_SKU_Fail
      END

      IF ISNULL( @cQty, '0') = '0'
      BEGIN
         SET @nErrNo = 66456
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Qty'
         GOTO Step_9_Qty_Fail
      END
      
      IF RDT.rdtIsValidQTY( @cQty, 1) = 0
      BEGIN
         SET @nErrNo = 66457
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --'Invalid Qty'
         GOTO Step_9_Qty_Fail
      END


      SELECT @nQTY = CASE WHEN @cDefaultPickByCase = '1' THEN ISNULL(CAST( @cQty AS INT) * P.CaseCnt, 0) -- (james07)
                     ELSE CASE WHEN @cPickUOM = '1' THEN ISNULL(CAST( @cQty AS INT) * P.Pallet, 0)
                               WHEN @cPickUOM = '2' THEN ISNULL(CAST( @cQty AS INT) * P.CaseCnt, 0)
                               ELSE P.QTY END END
      FROM dbo.SKU SKU WITH (NOLOCK)
      JOIN dbo.Pack P WITH (NOLOCK) ON (SKU.PackKey = P.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU

      IF RDT.rdtIsValidQTY( @nQTY, 1) = 0
      BEGIN
         SET @nErrNo = 66458
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --'Invalid Qty'
         GOTO Step_9_Qty_Fail
      END

      -- Getting sum pickqty from rdtpicklock for this load + zone + loc + sku
      SELECT @nPickLockQty = ISNULL(SUM( PickQty), 0)
      FROM RDT.RDTPickLock WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LoadKey = @cLoadKey
         AND PutAwayZone = @cZone
         AND LOC = @cLOC
         AND SKU = @cSKU
         AND Status = '1'
         AND AddWho = @cUserName

      -- Getting sum qty from pickdetail (allocated) for this load + zone + loc + sku
      SELECT @nPickDetailQty = ISNULL(SUM( Qty), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      WHERE O.StorerKey = @cStorerKey
         AND O.LoadKey = @cLoadKey
         AND L.LOC = @cLOC
         AND L.PutAwayZone = @cZone
         AND L.Facility = @cFacility
         AND PD.Status < '4'
         AND PD.SKU = @cSKU

      -- Check for over picking
      IF (@nPickLockQty + @nQTY) > @nPickDetailQty
      BEGIN
         SET @nErrNo = 66459
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --'Over Pick'
         GOTO Step_9_Qty_Fail
      END
      
      SET @nTranCount = @@TRANCOUNT 
      BEGIN TRAN
      SAVE TRAN STEP_9_HANDLER
      
      UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
         PickQty = @nQty
      WHERE StorerKey = @cStorerKey
         AND LoadKey = @cLoadKey
         AND PutAwayZone = @cZone
         AND LOC = @cLOC
         AND SKU = @cSKU
         AND Status = '1'
         AND AddWho = @cUserName

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 66460
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd PLock Fail'
         ROLLBACK TRAN STEP_9_HANDLER
         WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN
         GOTO Step_9_Qty_Fail
      END

--      -- receive if fully pick
--      IF (@nPickLockQty + @nQTY) = @nPickDetailQty
--      BEGIN
         SET @cPickConfirm_SP = rdt.RDTGetConfig( @nFunc, 'PickConfirm_SP', @cStorerKey)
         IF ISNULL(@cPickConfirm_SP, '') NOT IN ('', '0')
         BEGIN
            EXEC RDT.rdt_CasePick_ConfirmTask_Wrapper
                @n_Mobile        = @nMobile
               ,@n_Func          = @nFunc
               ,@c_LangCode      = @cLangCode
               ,@c_SPName        = @cPickConfirm_SP
               ,@c_StorerKey     = @cStorerKey 
               ,@c_UserName      = @cUserName
               ,@c_Facility      = @cFacility
               ,@c_Zone          = @cZone
               ,@c_SKU           = @cSKU 
               ,@c_LoadKey       = @cLoadKey
               ,@c_LOC           = @cLOC
               ,@c_LOT           = @cLOT
               ,@c_ID            = @cID
               ,@c_Status        = '5'
               ,@c_PickSlipNo    = @cPickSlipNo
               ,@c_PickUOM       = @cPickUOM
               ,@b_Success       = @b_Success   OUTPUT
               ,@n_ErrNo         = @nErrNo      OUTPUT
               ,@c_ErrMsg        = @cErrMsg     OUTPUT
         END
         ELSE
         BEGIN
            -- Remove the insert packdetail, packinfo & create URN part (james02)
            EXEC RDT.rdt_Case_Pick_ConfirmTask
               @cStorerKey,
               @cUserName,
               @cFacility,
               @cZone,
               @cSKU,
               @cLoadKey,
               @cLOC,
               @cLOT,
               @cID,
               '5',
               @cPickSlipNo,
               @cLangCode,
               @cPickUOM, -- (Vicky01)
               @nErrNo          OUTPUT,
               @cErrMsg         OUTPUT,  -- screen limitation, 20 char max
               @nMobile, -- (Vicky06)
               @nFunc    -- (Vicky06)
         END
         
         IF @nErrNo <> 0
         BEGIN
            SET @nErrNo = 66438
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CfmTaskFail'
            ROLLBACK TRAN STEP_9_HANDLER
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN
            GOTO Step_9_Qty_Fail
         END

         -- use primary key to update (james08)
         DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT RowRef FROM RDT.RDTPickLock WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   LoadKey = @cLoadKey
         AND   PutAwayZone = @cZone
         AND   LOC = @cLOC
         AND   SKU = @cSKU
         AND   AddWho = @cUserName
         AND   Status = '5'
         OPEN CUR_UPD
         FETCH NEXT FROM CUR_UPD INTO @nRowRef
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            -- Confirm this pick task
            UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
               Status = '9'
            WHERE RowRef = @nRowRef

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66462
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CfmPLockFail'
               CLOSE CUR_UPD
               DEALLOCATE CUR_UPD
               ROLLBACK TRAN STEP_9_HANDLER
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN
               GOTO Step_9_Qty_Fail
            END

            FETCH NEXT FROM CUR_UPD INTO @nRowRef
         END
         CLOSE CUR_UPD
         DEALLOCATE CUR_UPD
      
         SET @cSuggestedSKU = ''
         SET @cLOT = ''
         SET @cOrderKey = ''
         SET @cOrderLineNumber = ''
         SET @cPickUOM = ''

         -- Check whether got available SKU in LOAD + ZONE + LOC
         SELECT TOP 1
            @cSuggestedSKU = SKU,
            @cLOT = LOT,
            @cOrderKey = PD.OrderKey,
            @cOrderLineNumber = PD.OrderLineNumber,
            @cPickUOM = CASE WHEN @cDefaultPickByCase = '1' THEN '2' ELSE PD.UOM END -- (Vicky01)/(james07)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.Status < '4'
            AND PD.LOC = @cLOC
            AND O.LoadKey = @cLoadKey
         ORDER BY PD.SKU, PD.UOM

         -- If this LOC got no more SKU to pick then goto next LOC
         IF ISNULL(@cSuggestedSKU, '') = ''
         BEGIN
            SELECT TOP 1
               @cLogicalLocation = L.LogicalLocation,
               @cNewSuggestedLoc = L.LOC
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
            JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
            WHERE PD.StorerKey = @cStorerKey
               AND PD.Status < '4'
               AND L.LogicalLocation + L.LOC >
                  CONVERT(CHAR(18), ISNULL(@cLogicalLocation, '')) + CONVERT(CHAR(10), ISNULL(@cSuggestedLoc, ''))
               AND L.Facility = @cFacility
               AND L.PutawayZone = @cZone
               AND O.LoadKey = @cLoadKey
               AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK)
                  WHERE RPL.LoadKey = @cLoadKey
                     AND RPL.StorerKey = @cStorerKey
                     AND RPL.PutAwayZone = @cZone
                     AND RPL.LOC = PD.LOC
                     AND RPL.AddWho <> @cUserName
                     AND RPL.Status = '1')
            GROUP BY L.LogicalLocation, L.LOC
            ORDER BY L.LogicalLocation, L.LOC

            -- Getting the QTY Packed
            SELECT @nQtyPacked = ISNULL(SUM(PAD.Qty), 0)
            FROM dbo.PackDetail PAD WITH (NOLOCK)
            JOIN dbo.PackHeader PAH WITH (NOLOCK) ON (PAD.PickSlipNo = PAH.PickSlipNo)
            JOIN dbo.PickHeader PIH WITH (NOLOCK) ON (PAH.PickSlipNo = PIH.PickHeaderKey)
            WHERE PIH.ExternOrderKey = @cLoadKey
               AND PIH.Status = '0'

            -- Getting the QTY Picked
            SELECT @nQtyAllocated = ISNULL(SUM(PD.Qty), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
            JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
            WHERE O.StorerKey = @cStorerKey
               AND O.LoadKey = @cLoadKey
               AND L.Facility = @cFacility
               AND PD.Status < '9'

            -- If no more LOC to pick then goto screen 7
            IF ISNULL(@cNewSuggestedLoc, '') = ''
            BEGIN
               -- Go to screen 7
               SET @nScn = @nScn - 1
               SET @nStep = @nStep - 2

               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN

               GOTO Quit
            END   -- IF ISNULL(@cNewSuggestedLoc, '') = ''
            ELSE  -- Got other LOC to pick then goto screen 2
            BEGIN
               -- Start lock down the task (Load + Zone + Loc)
               IF NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND LoadKey = @cLoadKey
                     AND PutAwayZone = @cZone
                     AND LOC = @cSuggestedLOC
                     AND Status = '1')
               BEGIN
                  --BEGIN TRAN  -- (ChewKP01)

                  INSERT INTO RDT.RDTPickLock
                  (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey, LOT, LOC, SKU, Status, AddWho, AddDate, DropID, PickSlipNo, UOM, Mobile) -- (Vicky01)
                  VALUES
                  ('', @cLoadKey, '', '', @cStorerKey, @cZone, '', '', '', @cNewSuggestedLoc, '', '1', @cUserName, GETDATE(), @cID, @cPickSlipNo, '', @nMobile)

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 66463
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LockLOCFail'
                     ROLLBACK TRAN STEP_9_HANDLER
                     WHILE @@TRANCOUNT > @nTranCount
                        COMMIT TRAN
                     GOTO Step_9_Qty_Fail
                  END

                  -- COMMIT TRAN  -- (ChewKP01)
               END
               ELSE
               BEGIN
                  SET @nErrNo = 66464
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LOC Locked'
                  ROLLBACK TRAN STEP_9_HANDLER
                  WHILE @@TRANCOUNT > @nTranCount
                     COMMIT TRAN
                  GOTO Step_9_Qty_Fail
               END

               SET @cSuggestedLoc = @cNewSuggestedLoc

               -- Prepare next screen var
               SET @cOutField01 = @cSuggestedLOC
               SET @cOutField02 = ''   --LOC
               SET @cLOC = ''

               -- Go to next screen
               SET @nScn = @nScn - 5
               SET @nStep = @nStep - 6

               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN

               GOTO Quit
            END
         END
         ELSE  -- The same LOC got next SKU to pick, start locking
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND LoadKey = @cLoadKey
                  AND PutAwayZone = @cZone
                  AND LOC = @cLOC
                  AND Status = '1')
            BEGIN
               INSERT INTO RDT.RDTPickLock
               (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey, LOT, LOC, SKU, Status, AddWho, AddDate, DropID, PickSlipNo, UOM, Mobile) -- (Vicky01)
               VALUES
               ('', @cLoadKey, @cOrderKey, @cOrderLineNumber, @cStorerKey, @cZone, '', '', @cLOT, @cLOC, @cSuggestedSKU, '1', @cUserName, GETDATE(), @cID, @cPickSlipNo, @cPickUOM, @nMobile)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 66465
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LockLOCFail'
                  ROLLBACK TRAN STEP_9_HANDLER
                  WHILE @@TRANCOUNT > @nTranCount
                     COMMIT TRAN
                  GOTO Step_9_Qty_Fail
               END
            END
            ELSE
            BEGIN
               SET @nErrNo = 66466
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LOC Locked'
               ROLLBACK TRAN STEP_9_HANDLER
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN
               GOTO Step_9_Qty_Fail
            END

            SELECT
               --@cPackUOM1 = P.PACKUOM1,
               -- (Vicky01) - Start
               @cPickUOMDescr = CASE WHEN @cDefaultPickByCase = '1' THEN RTRIM(P.PackUOM1) -- (james07)
                                ELSE CASE WHEN @cPickUOM = '1' THEN RTRIM(P.PackUOM4)
                                          WHEN @cPickUOM = '2' THEN RTRIM(P.PackUOM1)
                                          ELSE '' END END,
               @nPickUOMQty = CASE WHEN @cDefaultPickByCase = '1' THEN RTRIM(P.CaseCnt) -- (james07)
                              ELSE CASE WHEN @cPickUOM = '1' THEN P.Pallet
                                        WHEN @cPickUOM = '2' THEN P.CaseCnt
                                        ELSE P.QTY END END,
              -- (Vicky01) - End
               @cDescr = SKU.Descr
            FROM dbo.SKU SKU WITH (NOLOCK)
            JOIN dbo.PACK P WITH (NOLOCK) ON (SKU.PackKey = P.PackKey)
            WHERE SKU.StorerKey = @cStorerKey
               AND SKU.SKU = @cSuggestedSKU

            -- Getting the qtypicked
            SELECT @nQtyPicked = ISNULL(SUM(Qty), 0) FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
            JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
            WHERE O.StorerKey = @cStorerKey
               AND O.LoadKey = @cLoadKey
               AND L.LOC = @cLOC
               AND L.PutAwayZone = @cZone
               AND L.Facility = @cFacility
               AND PD.Status >= '4'
               AND PD.Status < '9'
               AND PD.SKU = @cSuggestedSKU

            -- Getting the allocated
            SELECT @nQtyAllocated = ISNULL(SUM(Qty), 0) FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
            JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
            WHERE O.StorerKey = @cStorerKey
               AND O.LoadKey = @cLoadKey
               AND L.LOC = @cLOC
               AND L.PutAwayZone = @cZone
               AND L.Facility = @cFacility
               AND PD.SKU = @cSuggestedSKU

            -- Retrieve size (james03) & (james04)
            SELECT @cSize = '', @cStyle = ''
            SELECT @cSize = [Size], @cStyle = Style FROM dbo.SKU WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSuggestedSKU


            SET @nPickedUOMQty = 0
            SET @nPickUOMQty = 0
            SELECT
            @nPickedUOMQty = CASE WHEN @cDefaultPickByCase = '1' THEN ISNULL( SUM( PD.QTY), 0) / P.CaseCnt 
                             ELSE CASE WHEN @cPickUOM = '1' THEN ISNULL( SUM( PD.QTY), 0) / P.Pallet
                                       WHEN @cPickUOM = '2' THEN ISNULL( SUM( PD.QTY), 0) / P.CaseCnt
                                       ELSE ISNULL( SUM( PD.QTY), 0) END END 
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)
            JOIN dbo.PACK P WITH (NOLOCK) ON (SKU.PackKey = P.PackKey)
            WHERE PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSuggestedSKU
               AND PD.LOC = @cLOC
               AND LPD.LoadKey = @cLoadKey
               AND PD.Status = '5'
               AND PD.UOM = CASE WHEN @cDefaultPickByCase = '1' THEN PD.UOM ELSE @cPickUOM END
            GROUP BY P.Pallet, P.CaseCnt

            SELECT 
            @nPickUOMQty = CASE WHEN @cDefaultPickByCase = '1' THEN ISNULL( SUM( PD.QTY), 0) / P.CaseCnt 
                           ELSE CASE WHEN @cPickUOM = '1' THEN ISNULL( SUM( PD.QTY), 0) / P.Pallet
                                     WHEN @cPickUOM = '2' THEN ISNULL( SUM( PD.QTY), 0) / P.CaseCnt
                                     ELSE ISNULL( SUM( PD.QTY), 0) END END 
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)
            JOIN dbo.PACK P WITH (NOLOCK) ON (SKU.PackKey = P.PackKey)
            WHERE PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSuggestedSKU
               AND PD.LOC = @cLOC
               AND LPD.LoadKey = @cLoadKey
               AND PD.Status = '0'
               AND PD.UOM = CASE WHEN @cDefaultPickByCase = '1' THEN PD.UOM ELSE @cPickUOM END
            GROUP BY P.Pallet, P.CaseCnt
            
            SET @cOutField01 = @cSuggestedSKU

            -- If SKU.size & SKU.Style is blank then display SKU.Descr else display SKU.Size (james03) & (james04)
            IF ISNULL(@cSize, '') = '' AND ISNULL(@cStyle, '') = ''
               SET @cOutField02 = SUBSTRING(@cDescr, 1, 20)
            ELSE
               SET @cOutField02 = CASE WHEN ISNULL(@cStyle, '') = '' THEN SPACE(13) + @cSize
               ELSE SUBSTRING(@cStyle, 1, 12) + SPACE(1) + @cSize END

            SET @cOutField03 = ''
            SET @cOutField04 = @cPickUOMDescr 
            SET @cOutField05 = CASE WHEN @nPickUOMQty = 0 THEN '0' ELSE CAST( @nPickUOMQty AS NVARCHAR( 5)) END
            SET @cOutField06 = CASE WHEN @nPickedUOMQty = 0 THEN '0' ELSE CAST( @nPickedUOMQty AS NVARCHAR( 5)) END
            SET @cOutField07 = ''
         END
--      END
--      ELSE
--      BEGIN
--         SET @nPickedUOMQty = @nPickLockQty + @nQTY
--         SET @cOutField03 = ''
--         SET @cOutField06 = CASE WHEN @nPickedUOMQty = 0 THEN '0' ELSE CAST( @nPickedUOMQty AS NVARCHAR( 5)) END
--         SET @cOutField07 = ''
--      END

      EXEC rdt.rdtSetFocusField @nMobile, 1

      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN
   END

   IF @nInputKey = 0 --ESC
   BEGIN
         --For short pick purpose, system need to know which sku to short pick
         SET @cSKU = @cOutField02

         SET @nCurScn = 1967
         SET @nCurStep = 9

         -- Go to skip task screen
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 3

         SET @cOutField01 = ''   -- Option
   END
   GOTO Quit

   Step_9_SKU_Fail:
   BEGIN
      SET @cSKU = ''
      SET @cOutField03 = '' -- SKU
      SET @cOutField07 = @cQty
      EXEC rdt.rdtSetFocusField @nMobile, 3
      GOTO Quit
   END

   Step_9_Qty_Fail:
   BEGIN
      SET @cQty = ''
      SET @cOutField03 = @cSKU
      SET @cOutField07 = '' -- Qty
      EXEC rdt.rdtSetFocusField @nMobile, 7
      GOTO Quit
   END
END
GOTO Quit

/********************************************************************************
Step 10. Scn = 1968.
   Option     (field01, input)
********************************************************************************/
Step_10:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      --screen mapping
      SET @cOption = @cInField07
      SET @cSKU = @cOutField04

      IF ISNULL( @cOption, '') = ''
      BEGIN
         SET @nErrNo = 66467
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option req'
         GOTO Step_10_Fail
      END

      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 66468
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv Option'
         GOTO Step_10_Fail
      END

      -- Confirm short pick
      IF @cOption = '1'
      BEGIN      
         SET @nTranCount = @@TRANCOUNT 
         BEGIN TRAN
         SAVE TRAN STEP_10_HANDLER
         
         DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT PickDetailKey
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE O.StorerKey = @cStorerKey
            AND O.LoadKey = @cLoadKey
            AND L.LOC = @cLOC
            AND L.PutAwayZone = @cZone
            AND L.Facility = @cFacility
            AND PD.Status < '4'
            AND PD.SKU = @cSKU
         OPEN CUR_LOOP
         FETCH NEXT FROM CUR_LOOP INTO @cPickDetailKey
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE dbo.PickDetail SET 
               Status = '4'
            WHERE PickDetailKey = @cPickDetailKey
            
            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN STEP_10_HANDLER
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN
               CLOSE CUR_LOOP
               DEALLOCATE CUR_LOOP
               GOTO Step_10_Fail
            END

            FETCH NEXT FROM CUR_LOOP INTO @cPickDetailKey
         END
         CLOSE CUR_LOOP
         DEALLOCATE CUR_LOOP

         -- use primary key to update (james08)
         DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT RowRef FROM RDT.RDTPickLock WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   LoadKey = @cLoadKey
         AND   PutAwayZone = @cZone
         AND   LOC = @cLOC
         AND   SKU = @cSKU
         AND   AddWho = @cUserName
         AND   Status = '5'
         OPEN CUR_UPD
         FETCH NEXT FROM CUR_UPD INTO @nRowRef
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            -- Confirm this pick task
            UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
               Status = '9'
            WHERE RowRef = @nRowRef

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66462
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CfmPLockFail'
               CLOSE CUR_UPD
               DEALLOCATE CUR_UPD
               ROLLBACK TRAN STEP_9_HANDLER
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN
               GOTO Step_10_Fail
            END

            FETCH NEXT FROM CUR_UPD INTO @nRowRef
         END
         CLOSE CUR_UPD
         DEALLOCATE CUR_UPD
      
         SET @cSuggestedSKU = ''
         SET @cLOT = ''
         SET @cOrderKey = ''
         SET @cOrderLineNumber = ''
         SET @cPickUOM = ''

         -- Check whether got available SKU in LOAD + ZONE + LOC
         SELECT TOP 1
            @cSuggestedSKU = SKU,
            @cLOT = LOT,
            @cOrderKey = PD.OrderKey,
            @cOrderLineNumber = PD.OrderLineNumber,
            @cPickUOM = CASE WHEN @cDefaultPickByCase = '1' THEN '2' ELSE PD.UOM END -- (Vicky01)/(james07)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.Status < '4'
            AND PD.LOC = @cLOC
            AND O.LoadKey = @cLoadKey
         ORDER BY PD.SKU, PD.UOM

         -- If this LOC got no more SKU to pick then goto next LOC
         IF ISNULL(@cSuggestedSKU, '') = ''
         BEGIN
            SELECT TOP 1
               @cLogicalLocation = L.LogicalLocation,
               @cNewSuggestedLoc = L.LOC
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
            JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
            WHERE PD.StorerKey = @cStorerKey
               AND PD.Status < '4'
               AND L.LogicalLocation + L.LOC >
                  CONVERT(CHAR(18), ISNULL(@cLogicalLocation, '')) + CONVERT(CHAR(10), ISNULL(@cSuggestedLoc, ''))
               AND L.Facility = @cFacility
               AND L.PutawayZone = @cZone
               AND O.LoadKey = @cLoadKey
               AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK)
                  WHERE RPL.LoadKey = @cLoadKey
                     AND RPL.StorerKey = @cStorerKey
                     AND RPL.PutAwayZone = @cZone
                     AND RPL.LOC = PD.LOC
                     AND RPL.AddWho <> @cUserName
                     AND RPL.Status = '1')
            GROUP BY L.LogicalLocation, L.LOC
            ORDER BY L.LogicalLocation, L.LOC

            -- Getting the QTY Packed
            SELECT @nQtyPacked = ISNULL(SUM(PAD.Qty), 0)
            FROM dbo.PackDetail PAD WITH (NOLOCK)
            JOIN dbo.PackHeader PAH WITH (NOLOCK) ON (PAD.PickSlipNo = PAH.PickSlipNo)
            JOIN dbo.PickHeader PIH WITH (NOLOCK) ON (PAH.PickSlipNo = PIH.PickHeaderKey)
            WHERE PIH.ExternOrderKey = @cLoadKey
               AND PIH.Status = '0'

            -- Getting the QTY Picked
            SELECT @nQtyAllocated = ISNULL(SUM(PD.Qty), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
            JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
            WHERE O.StorerKey = @cStorerKey
               AND O.LoadKey = @cLoadKey
               AND L.Facility = @cFacility
               AND PD.Status < '9'

            -- If no more LOC to pick then goto screen 7
            IF ISNULL(@cNewSuggestedLoc, '') = ''
            BEGIN
               -- Go to screen 7
               SET @nScn = @nScn - 2
               SET @nStep = @nStep - 3

               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN

               GOTO Quit
            END   -- IF ISNULL(@cNewSuggestedLoc, '') = ''
            ELSE  -- Got other LOC to pick then goto screen 2
            BEGIN
               -- Start lock down the task (Load + Zone + Loc)
               IF NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND LoadKey = @cLoadKey
                     AND PutAwayZone = @cZone
                     AND LOC = @cNewSuggestedLoc--@cSuggestedLOC
                     AND Status = '1')
               BEGIN
                  INSERT INTO RDT.RDTPickLock
                  (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey, LOT, LOC, SKU, Status, AddWho, AddDate, DropID, PickSlipNo, UOM, Mobile) -- (Vicky01)
                  VALUES
                  ('', @cLoadKey, '', '', @cStorerKey, @cZone, '', '', '', @cNewSuggestedLoc, '', '1', @cUserName, GETDATE(), @cID, @cPickSlipNo, '', @nMobile)

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 66463
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LockLOCFail'
                     ROLLBACK TRAN STEP_10_HANDLER
                     WHILE @@TRANCOUNT > @nTranCount
                        COMMIT TRAN
                     GOTO Step_10_Fail
                  END
               END
               ELSE
               BEGIN
                  SET @nErrNo = 66464
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LOC Locked'
                  ROLLBACK TRAN STEP_10_HANDLER
                  WHILE @@TRANCOUNT > @nTranCount
                     COMMIT TRAN
                  GOTO Step_10_Fail
               END

               SET @cSuggestedLoc = @cNewSuggestedLoc

               -- Prepare next screen var
               SET @cOutField01 = @cSuggestedLOC
               SET @cOutField02 = ''   --LOC
               SET @cLOC = ''

               -- Go to next screen
               SET @nScn = @nScn - 6
               SET @nStep = @nStep - 7

               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN

               GOTO Quit
            END
         END
         ELSE  -- The same LOC got next SKU to pick, start locking
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND LoadKey = @cLoadKey
                  AND PutAwayZone = @cZone
                  AND LOC = @cLOC
                  AND Status = '1')
            BEGIN
               INSERT INTO RDT.RDTPickLock
               (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey, LOT, LOC, SKU, Status, AddWho, AddDate, DropID, PickSlipNo, UOM, Mobile) -- (Vicky01)
               VALUES
               ('', @cLoadKey, @cOrderKey, @cOrderLineNumber, @cStorerKey, @cZone, '', '', @cLOT, @cLOC, @cSuggestedSKU, '1', @cUserName, GETDATE(), @cID, @cPickSlipNo, @cPickUOM, @nMobile)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 66465
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LockLOCFail'
                  ROLLBACK TRAN STEP_10_HANDLER
                  WHILE @@TRANCOUNT > @nTranCount
                     COMMIT TRAN
                  GOTO Step_10_Fail
               END
            END
            ELSE
            BEGIN
               SET @nErrNo = 66466
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LOC Locked'
               ROLLBACK TRAN STEP_10_HANDLER
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN
               GOTO Step_10_Fail
            END

            SELECT
               --@cPackUOM1 = P.PACKUOM1,
               -- (Vicky01) - Start
               @cPickUOMDescr = CASE WHEN @cDefaultPickByCase = '1' THEN RTRIM(P.PackUOM1) -- (james07)
                                ELSE CASE WHEN @cPickUOM = '1' THEN RTRIM(P.PackUOM4)
                                          WHEN @cPickUOM = '2' THEN RTRIM(P.PackUOM1)
                                          ELSE '' END END,
               @nPickUOMQty = CASE WHEN @cDefaultPickByCase = '1' THEN P.CaseCnt -- (james07)
                              ELSE CASE WHEN @cPickUOM = '1' THEN P.Pallet
                                        WHEN @cPickUOM = '2' THEN P.CaseCnt
                                        ELSE P.QTY END END,
              -- (Vicky01) - End
               @cDescr = SKU.Descr
            FROM dbo.SKU SKU WITH (NOLOCK)
            JOIN dbo.PACK P WITH (NOLOCK) ON (SKU.PackKey = P.PackKey)
            WHERE SKU.StorerKey = @cStorerKey
               AND SKU.SKU = @cSuggestedSKU

            -- Getting the qtypicked
            SELECT @nQtyPicked = ISNULL(SUM(Qty), 0) FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
            JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
            WHERE O.StorerKey = @cStorerKey
               AND O.LoadKey = @cLoadKey
               AND L.LOC = @cLOC
               AND L.PutAwayZone = @cZone
               AND L.Facility = @cFacility
               AND PD.Status >= '4'
               AND PD.Status < '9'
               AND PD.SKU = @cSuggestedSKU

            -- Getting the allocated
            SELECT @nQtyAllocated = ISNULL(SUM(Qty), 0) FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
            JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
            WHERE O.StorerKey = @cStorerKey
               AND O.LoadKey = @cLoadKey
               AND L.LOC = @cLOC
               AND L.PutAwayZone = @cZone
               AND L.Facility = @cFacility
               AND PD.SKU = @cSuggestedSKU

            -- Retrieve size (james03) & (james04)
            SELECT @cSize = '', @cStyle = ''
            SELECT @cSize = [Size], @cStyle = Style FROM dbo.SKU WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSuggestedSKU


            SET @nPickedUOMQty = 0
            SET @nPickUOMQty = 0
            SELECT
            @nPickedUOMQty = CASE WHEN @cDefaultPickByCase = '1' THEN ISNULL( SUM( PD.QTY), 0) / P.CaseCnt -- (james07)
                             ELSE CASE WHEN @cPickUOM = '1' THEN ISNULL( SUM( PD.QTY), 0) / P.Pallet
                                  WHEN @cPickUOM = '2' THEN ISNULL( SUM( PD.QTY), 0) / P.CaseCnt
                                  ELSE ISNULL( SUM( PD.QTY), 0) END END 
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)
            JOIN dbo.PACK P WITH (NOLOCK) ON (SKU.PackKey = P.PackKey)
            WHERE PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSuggestedSKU
               AND PD.LOC = @cLOC
               AND LPD.LoadKey = @cLoadKey
               AND PD.Status = '5'
               AND PD.UOM = CASE WHEN @cDefaultPickByCase = '1' THEN PD.UOM ELSE @cPickUOM END
            GROUP BY P.Pallet, P.CaseCnt

            SELECT 
            @nPickUOMQty = CASE WHEN @cDefaultPickByCase = '1' THEN ISNULL( SUM( PD.QTY), 0) / P.CaseCnt -- (james07)
                           ELSE CASE WHEN @cPickUOM = '1' THEN ISNULL( SUM( PD.QTY), 0) / P.Pallet
                                     WHEN @cPickUOM = '2' THEN ISNULL( SUM( PD.QTY), 0) / P.CaseCnt
                                     ELSE ISNULL( SUM( PD.QTY), 0) END END 
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)
            JOIN dbo.PACK P WITH (NOLOCK) ON (SKU.PackKey = P.PackKey)
            WHERE PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSuggestedSKU
               AND PD.LOC = @cLOC
               AND LPD.LoadKey = @cLoadKey
               AND PD.Status = '0'
               AND PD.UOM = CASE WHEN @cDefaultPickByCase = '1' THEN PD.UOM ELSE @cPickUOM END 
            GROUP BY P.Pallet, P.CaseCnt
            
            SET @cOutField01 = @cSuggestedSKU

            -- If SKU.size & SKU.Style is blank then display SKU.Descr else display SKU.Size (james03) & (james04)
            IF ISNULL(@cSize, '') = '' AND ISNULL(@cStyle, '') = ''
               SET @cOutField02 = SUBSTRING(@cDescr, 1, 20)
            ELSE
               SET @cOutField02 = CASE WHEN ISNULL(@cStyle, '') = '' THEN SPACE(13) + @cSize
               ELSE SUBSTRING(@cStyle, 1, 12) + SPACE(1) + @cSize END

            SET @cOutField03 = ''
            SET @cOutField04 = @cPickUOMDescr 
            SET @cOutField05 = CASE WHEN @nPickUOMQty = 0 THEN '0' ELSE CAST( @nPickUOMQty AS NVARCHAR( 5)) END
            SET @cOutField06 = CASE WHEN @nPickedUOMQty = 0 THEN '0' ELSE CAST( @nPickedUOMQty AS NVARCHAR( 5)) END
            SET @cOutField07 = ''
         END
   --      END
   --      ELSE
   --      BEGIN
   --         SET @nPickedUOMQty = @nPickLockQty + @nQTY
   --         SET @cOutField03 = ''
   --         SET @cOutField06 = CASE WHEN @nPickedUOMQty = 0 THEN '0' ELSE CAST( @nPickedUOMQty AS NVARCHAR( 5)) END
   --         SET @cOutField07 = ''
   --      END

         WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN

         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
      ELSE
      BEGIN
         GOTO BACK_TO_STEP9
      END
   END

   IF @nInputKey = 0 --ESC
   BEGIN
      BACK_TO_STEP9:
      -- Getting the qtypicked
      SELECT @nQtyPicked = ISNULL(SUM(Qty), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      WHERE O.StorerKey = @cStorerKey
         AND O.LoadKey = @cLoadKey
         AND L.LOC = @cLOC
         AND L.PutAwayZone = @cZone
         AND L.Facility = @cFacility
         AND PD.Status >= '4' -- '4' consider picked but not confirm picked
         AND PD.SKU = @cSuggestedSKU

      -- Getting the allocated
      SELECT @nQtyAllocated = ISNULL(SUM(Qty), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      WHERE O.StorerKey = @cStorerKey
         AND O.LoadKey = @cLoadKey
         AND L.LOC = @cLOC
         AND L.PutAwayZone = @cZone
         AND L.Facility = @cFacility
         AND PD.SKU = @cSuggestedSKU

      -- Retrieve size (james03) & (james04)
      SELECT @cSize = '', @cStyle = ''
      SELECT @cSize = [Size], @cStyle = Style FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSuggestedSKU

      -- (jamesxxxxx)
      IF rdt.RDTGetConfig( @nFunc, 'CASEPICKALLOWKEYINQTY', @cStorerKey) <> '1'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = ISNULL(RTRIM(CAST(@nQtyPicked AS NVARCHAR( 5))), '0') + '/' + CAST(@nQtyAllocated AS NVARCHAR( 5))
         SET @cOutField02 = @cSuggestedSKU

         -- If SKU.size & SKU.Style is blank then display SKU.Descr else display SKU.Size (james03) & (james04)
         IF ISNULL(@cSize, '') = '' AND ISNULL(@cStyle, '') = ''
            SET @cOutField03 = SUBSTRING(@cDescr, 1, 20)
         ELSE
            SET @cOutField03 = CASE WHEN ISNULL(@cStyle, '') = '' THEN SPACE(13) + @cSize
            ELSE SUBSTRING(@cStyle, 1, 12) + SPACE(1) + @cSize
            END

         SET @cOutField04 = @cPickUOMDescr + CAST(@nPickUOMQty AS NVARCHAR( 5))  --@cPackUOM1 -- (Vicky01)
         SET @cOutField05 = ''

         -- Go to next screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
      ELSE
      BEGIN
         SET @nPickedUOMQty = 0
         SET @nPickUOMQty = 0
         SELECT
         @nPickedUOMQty = CASE WHEN @cDefaultPickByCase = '1' THEN ISNULL( SUM( PD.QTY), 0) / P.CaseCnt  -- (james07) 
                          ELSE CASE WHEN @cPickUOM = '1' THEN ISNULL( SUM( PD.QTY), 0) / P.Pallet
                                    WHEN @cPickUOM = '2' THEN ISNULL( SUM( PD.QTY), 0) / P.CaseCnt
                                    ELSE ISNULL( SUM( PD.QTY), 0) END END 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)
         JOIN dbo.PACK P WITH (NOLOCK) ON (SKU.PackKey = P.PackKey)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSuggestedSKU
            AND PD.LOC = @cLOC
            AND LPD.LoadKey = @cLoadKey
            AND PD.Status = '5'
            AND PD.UOM = CASE WHEN @cDefaultPickByCase = '1' THEN PD.UOM ELSE @cPickUOM END
         GROUP BY P.Pallet, P.CaseCnt

         SELECT 
         @nPickUOMQty = CASE WHEN @cDefaultPickByCase = '1' THEN ISNULL( SUM( PD.QTY), 0) / P.CaseCnt 
                        ELSE CASE WHEN @cPickUOM = '1' THEN ISNULL( SUM( PD.QTY), 0) / P.Pallet
                                  WHEN @cPickUOM = '2' THEN ISNULL( SUM( PD.QTY), 0) / P.CaseCnt
                                  ELSE ISNULL( SUM( PD.QTY), 0) END END 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)
         JOIN dbo.PACK P WITH (NOLOCK) ON (SKU.PackKey = P.PackKey)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSuggestedSKU
            AND PD.LOC = @cLOC
            AND LPD.LoadKey = @cLoadKey
            AND PD.Status = '0'
            AND PD.UOM = CASE WHEN @cDefaultPickByCase = '1' THEN PD.UOM ELSE @cPickUOM END 
         GROUP BY P.Pallet, P.CaseCnt

         SET @cOutField01 = @cSuggestedSKU

         -- If SKU.size & SKU.Style is blank then display SKU.Descr else display SKU.Size (james03) & (james04)
         IF ISNULL(@cSize, '') = '' AND ISNULL(@cStyle, '') = ''
            SET @cOutField02 = SUBSTRING(@cDescr, 1, 20)
         ELSE
            SET @cOutField02 = CASE WHEN ISNULL(@cStyle, '') = '' THEN SPACE(13) + @cSize
            ELSE SUBSTRING(@cStyle, 1, 12) + SPACE(1) + @cSize END

         SET @cOutField03 = ''
         SET @cOutField04 = @cPickUOMDescr 
         SET @cOutField05 = CASE WHEN @nPickUOMQty = 0 THEN '0' ELSE CAST( @nPickUOMQty AS NVARCHAR( 5)) END
         SET @cOutField06 = CASE WHEN @nPickedUOMQty = 0 THEN '0' ELSE CAST( @nPickedUOMQty AS NVARCHAR( 5)) END
         SET @cOutField07 = ''

         -- Go to next screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
   END
   GOTO Quit
   
   Step_10_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField07 = ''
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate     = GETDATE(), 
      ErrMsg       = @cErrMsg,
      Func         = @nFunc,
      Step         = @nStep,
      Scn          = @nScn,

      StorerKey    = @cStorerKey,
      Facility     = @cFacility,
      Printer      = @cPrinter,
      -- UserName     = @cUserName,

      V_UOM        = @cPUOM,
      V_QTY        = @nQTY,
      V_SKU        = @cSKU,
      V_SKUDescr   = @cDescr,
      V_LOC        = @cLOC,
      V_LOT        = @cLOT,
      V_ID         = @cID,
      V_PickSlipNo = @cPickSlipNo,
      V_OrderKey   = @cOrderKey,
      V_LoadKey    = @cLoadKey,
      
      V_Cartonno   = @nCartonNo,
   
      V_Integer1   = @cAutoPackConfirm,
      V_Integer2   = @nCurScn,
      V_Integer3   = @nCurStep,
      V_Integer4   = @nPickUOMQty,
      V_Integer5   = @cDefaultPickByCase,

      V_String1    = @cDoor,
      V_String2    = @cLogicalLocation,
      V_String3    = @cSuggestedLoc,
      V_String4    = @cZone,
      V_String5    = @cPickSlipType,
      --V_String6    = @nCartonNo,
      V_String7    = @cLabelNo,
      V_String8    = @cAutoScanInPS,
      V_String9    = @cAutoScanOutPS,
      V_String10   = @cSHOWSHTPICKRSN,
      --V_String11   = @cAutoPackConfirm,
      V_String12   = @cSuggestedSKU,
      V_String13   = @cPackUOM1,
      --V_String14   = @nCurScn,
      --V_String15   = @nCurStep,
      V_String16   = @cPickUOM, -- (Vicky01)
      V_String17   = @cPickUOMDescr, -- (Vicky01)
      --V_String18   = @nPickUOMQty, --(Vicky01)
      --V_String19   = @cDefaultPickByCase,       -- (james07)

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