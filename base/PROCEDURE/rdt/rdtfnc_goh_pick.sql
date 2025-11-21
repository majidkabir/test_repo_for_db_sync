SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: RDT GOH Picking SOS133218                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2009-04-07 1.0  James      Created                                   */
/* 2009-07-30 1.1  Vicky      Add in EventLog (Vicky06)                 */
/* 2009-10-14 1.2  James      Include Mobile when insert into           */
/*                            RDTPicklock (James01)                     */
/* 2016-09-30 1.3  Ung        Performance tuning                        */
/* 2018-01-11 1.4  Gan        Performance tuning                        */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_GOH_Pick] (
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
   @cPackUOM3           NVARCHAR( 10),
   @cReasonCode         NVARCHAR( 10),
   @cModuleName         NVARCHAR( 45),
   @cLabelLine          NVARCHAR( 5),


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
   @cID         = V_ID,
   @cPickSlipNo = V_PickSlipNo,
   @cOrderKey   = V_OrderKey,
   @cLoadKey    = V_LoadKey,
   
   @nCartonNo   = V_Cartonno,
   
   @cAutoPackConfirm    = V_Integer1,
   @nCurScn             = V_Integer2,
   @nCurStep            = V_Integer3,
   @nQtyPicked          = V_Integer4,
   @nQtyAllocated       = V_Integer5,

   @cDoor               = V_String1,
   @cLogicalLocation    = V_String2,
   @cSuggestedLoc       = V_String3,  
   @cZone               = V_String4,
   @cPickSlipType       = V_String5,
  -- @nCartonNo           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6,  5), 0) = 1 THEN LEFT( V_String6,  5) ELSE 0 END,
   @cLabelNo            = V_String7,
   @cAutoScanInPS       = V_String8,
   @cAutoScanOutPS      = V_String9,
   @cSHOWSHTPICKRSN     = V_String10,
  -- @cAutoPackConfirm    = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String11,  5), 0) = 1 THEN LEFT( V_String11,  5) ELSE 0 END,
   @cSuggestedSKU       = V_String12,
   @cPackUOM3           = V_String13,
  -- @nCurScn             = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String14,  5), 0) = 1 THEN LEFT( V_String14,  5) ELSE 0 END,
  -- @nCurStep            = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String15,  5), 0) = 1 THEN LEFT( V_String15,  5) ELSE 0 END,
  -- @nQtyPicked          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String16,  5), 0) = 1 THEN LEFT( V_String16,  5) ELSE 0 END,
  -- @nQtyAllocated       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String17,  5), 0) = 1 THEN LEFT( V_String17,  5) ELSE 0 END,

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

IF @nFunc = 1623  -- GOH Picking
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Scan And Pack
   IF @nStep = 1 GOTO Step_1   -- Scn = 1970. LOAD#, ZONE
   IF @nStep = 2 GOTO Step_2   -- Scn = 1971. DOOR, PALLET ID
   IF @nStep = 3 GOTO Step_3   -- Scn = 1972. LOC
   IF @nStep = 4 GOTO Step_4   -- Scn = 1973. SKU, QTY
   IF @nStep = 5 GOTO Step_5   -- Scn = 1974. OPTION
   IF @nStep = 6 GOTO Step_6   -- Scn = 1975. MSG
   IF @nStep = 7 GOTO Step_7   -- Scn = 1976. RSN CODE
END

--RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1623. Menu
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

   -- Clear the incompleted task for the same login
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
         SET @nErrNo = 66501
         SET @cErrMsg = rdt.rdtgetmessage( 66501, @cLangCode,'DSP') --Need LoadKey
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
         SET @nErrNo = 66502
         SET @cErrMsg = rdt.rdtgetmessage( 66502, @cLangCode,'DSP') --Invalid LOAD
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
         SET @cErrMsg1 = '66503 Load has'
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
         SET @nErrNo = 66504
         SET @cErrMsg = rdt.rdtgetmessage( 66504, @cLangCode,'DSP') --LOAD closed
         SET @cOutField01 = ''
         SET @cOutField02 = @cZone
         SET @cLoadKey = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit         
      END

      IF ISNULL(@cZone, '') = ''
      BEGIN
         SET @nErrNo = 66505
         SET @cErrMsg = rdt.rdtgetmessage( 66505, @cLangCode,'DSP') --Zone Req
         SET @cOutField01 = @cLoadKey
         SET @cOutField02 = ''
         SET @cZone = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit         
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.PutAwayZone WITH (NOLOCK) WHERE PutAwayZone = @cZone)
      BEGIN
         SET @nErrNo = 66506
         SET @cErrMsg = rdt.rdtgetmessage( 66506, @cLangCode,'DSP') --Invalid Zone
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
         WHERE PD.Status < '4'
            AND O.LoadKey = @cLoadKey
            AND O.StorerKey = @cStorerKey
            AND L.Facility = @cFacility
            AND L.PutawayZone = @cZone)
      BEGIN
         SET @nErrNo = 66507
         SET @cErrMsg = rdt.rdtgetmessage( 66507, @cLangCode,'DSP') --ZoneNotExist
         SET @cOutField01 = @cLoadKey
         SET @cOutField02 = ''
         SET @cZone = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit         
      END

      SELECT @cPickSlipNo = PickHeaderKey 
      FROM dbo.PickHeader WITH (NOLOCK) 
      WHERE ExternOrderKey = @cLoadKey
         AND Status = '0'

      BEGIN TRAN
      SAVE TRAN PickSlip_Handler

      -- Check if exists pickheader, not exists then we gen the pickslip using std pickslipno generation
      IF ISNULL(@cPickSlipNo, '') = ''
      BEGIN
         EXECUTE dbo.nspg_GetKey
            'PICKSLIP', 
            10 ,
            @cPickSlipNo       OUTPUT,
            @b_success         OUTPUT,
            @n_err             OUTPUT,
            @c_errmsg          OUTPUT

         IF @b_success <> 1
         BEGIN
            SET @nErrNo = 66508
            SET @cErrMsg = rdt.rdtgetmessage( 66508, @cLangCode, 'DSP') -- 'GetPSLipFail'
            ROLLBACK TRAN PickSlip_Handler
            GOTO Quit
         END

         INSERT INTO dbo.PICKHEADER
         (PickHeaderKey, ExternOrderKey, Zone, TrafficCop)
         VALUES
         (@cPickSlipNo, @cLoadKey, '7', '')

         IF @@ERROR <> 0
         BEGIN
				SET @nErrNo = 66509
            SET @cErrMsg = rdt.rdtgetmessage( 66509, @cLangCode, 'DSP') --'InsPiHdrFail'
            ROLLBACK TRAN PickSlip_Handler
            GOTO Quit
         END
      END

      -- Check if the pickslip already scan out
      IF EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo
            AND ScanOutDate IS NOT NULL)
      BEGIN
         SET @nErrNo = 66510
         SET @cErrMsg = rdt.rdtgetmessage( 66510, @cLangCode,'DSP') --PS Scan Out
         EXEC rdt.rdtSetFocusField @nMobile, 1
         ROLLBACK TRAN PickSlip_Handler
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
				   SET @nErrNo = 66511
               SET @cErrMsg = rdt.rdtgetmessage( 66511, @cLangCode, 'DSP') --'PSScanInFail'
               ROLLBACK TRAN PickSlip_Handler
               GOTO Quit
            END
         END
         ELSE
         BEGIN
			   SET @nErrNo = 66513
            SET @cErrMsg = rdt.rdtgetmessage( 66513, @cLangCode, 'DSP') --'PSNotScanIn'
            RollBack Tran PickSlip_Handler
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
				      SET @nErrNo = 66512
                  SET @cErrMsg = rdt.rdtgetmessage( 66512, @cLangCode, 'DSP') --'ScanInPSFail'
                  ROLLBACK TRAN PickSlip_Handler
                  GOTO Quit
               END
            END 
            ELSE
            BEGIN
				   SET @nErrNo = 66513
               SET @cErrMsg = rdt.rdtgetmessage( 66513, @cLangCode, 'DSP') --'PSNotScanIn'
               RollBack Tran PickSlip_Handler
               GOTO Quit
            END
         END
      END

      COMMIT TRAN PickSlip_Handler

      SELECT @cDoor = TrfRoom FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey

      -- Determine pickslip type, either Discrete/Consolidated
	   IF NOT EXISTS (SELECT 1 
         FROM dbo.PickHeader PH WITH (NOLOCK)
	      JOIN dbo.PickingInfo PInfo (NOLOCK) ON (PInfo.PickSlipNo = PH.PickHeaderKey) 
	      LEFT OUTER JOIN dbo.ORDERS O WITH (NOLOCK) ON (O.OrderKey = PH.OrderKey)
	      WHERE PH.PickHeaderKey = @cPickSlipNo)
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
         SET @nErrNo = 66514
         SET @cErrMsg = rdt.rdtgetmessage( 66514, @cLangCode,'DSP') --PalletID req
         GOTO Step_2_Fail         
      END

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
      ORDER BY L.LogicalLocation, L.LOC

      IF ISNULL(@cSuggestedLOC, '') = ''
      BEGIN
         SET @nErrNo = 66515
         SET @cErrMsg = rdt.rdtgetmessage( 66515, @cLangCode,'DSP') --NoMoreTask
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
            AND PD.PickSlipNo = @cPickSlipNo
            AND PD.Status < '4'
            AND L.LogicalLocation + L.LOC >   
               CONVERT(CHAR(18), ISNULL(@cLogicalLocation, '')) + CONVERT(CHAR(10), ISNULL(@cSuggestedLoc, ''))
            AND L.Facility = @cFacility
            AND L.PutAwayZone = @cZone
            AND O.LoadKey = @cLoadKey
         GROUP BY L.LogicalLocation, L.LOC  
         ORDER BY L.LogicalLocation, L.LOC  
  
         IF ISNULL(@cNewSuggestedLoc, '') = ''  
         BEGIN  
            SET @nErrNo = 66516  
            SET @cErrMsg = rdt.rdtgetmessage( 66516, @cLangCode,'DSP') --No More Rec  
            GOTO Step_2_Fail    
         END  

         SET @cSuggestedLoc = @cNewSuggestedLoc  
           
         -- Prepare next screen var  
         SET @cOutField01 = @cSuggestedLoc   -- LOC         
         SET @cOutField02 = ''   -- LOC   
         SET @cLOC = ''  
  
         GOTO Quit  
      END  
      
      IF @cLOC <> @cSuggestedLOC
      BEGIN
         SET @nErrNo = 66517
         SET @cErrMsg = rdt.rdtgetmessage( 66517, @cLangCode,'DSP') --LOC diff
         GOTO Step_3_Fail   
      END

      SELECT TOP 1 @cSuggestedSKU = SKU 
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
      WHERE PD.StorerKey = @cStorerKey  
         AND PD.Status < '4'
         AND PD.LOC = @cLOC  
         AND O.LoadKey = @cLoadKey
         AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK)
            WHERE RPL.LoadKey = @cLoadKey
              AND RPL.StorerKey = @cStorerKey
               AND PutAwayZone = @cZone
               AND LOC = @cLOC
               AND SKU = PD.SKU
               AND RPL.AddWho <> @cUserName
               AND RPL.Status = '1')
      ORDER BY SKU

      IF ISNULL(@cSuggestedSKU, '') = ''
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = '66518 LOC'
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

      -- Start lock down the task (Load + Zone + Loc + SKU)        
      IF NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND LoadKey = @cLoadKey
            AND PutAwayZone = @cZone
            AND LOC = @cLOC
            AND SKU = @cSKU
            AND Status = '1'
            AND AddWho = @cUserName)
      BEGIN
         BEGIN TRAN

         INSERT INTO RDT.RDTPickLock
         (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey, LOT, LOC, SKU, Status, AddWho, AddDate, DropID, PickSlipNo, Mobile)
         VALUES
         ('', @cLoadKey, '', '*', @cStorerKey, @cZone, '', '', '', @cLOC, @cSKU, '1', @cUserName, GETDATE(), @cID, @cPickSlipNo, @nMobile)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 66519
            SET @cErrMsg = rdt.rdtgetmessage( 66519, @cLangCode, 'DSP') --'LockTaskFail'
            ROLLBACK TRAN
            GOTO Step_3_Fail
         END

         COMMIT TRAN
      END
      ELSE
      BEGIN
         SET @nErrNo = 65911
         SET @cErrMsg = rdt.rdtgetmessage( 65911, @cLangCode, 'DSP') --'SKUAlrdLock'
         GOTO Step_3_Fail
      END

      SELECT 
         @cPackUOM3 = P.PACKUOM3,
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
         AND PD.Status < '4'
         AND PD.SKU = @cSuggestedSKU  

      -- Prepare next screen var  
      SET @cOutField01 = ISNULL(RTRIM(CAST(@nQtyPicked AS NVARCHAR( 5))), '') + '/' + CAST(@nQtyAllocated AS NVARCHAR( 5))
      SET @cOutField02 = @cSuggestedSKU 
      SET @cOutField03 = SUBSTRING(@cDescr, 1, 20)  
      SET @cOutField04 = @nQtyAllocated
      SET @cOutField05 = @cPackUOM3
  
      -- Go to next screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END

   IF @nInputKey = 0 --ESC
   BEGIN
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
   SKU             (field04)
   QTY 99999 99999 UOM (field05, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
         --screen mapping
      SET @cSKU = @cInField03
      SET @cQTY = @cInField04
      
      IF ISNULL(@cSKU, '') = ''  
      BEGIN  
         SET @cSKU = ''
         SET @nErrNo = 66520  
         SET @cErrMsg = rdt.rdtgetmessage( 66520, @cLangCode,'DSP') --SKU/UPC needed  
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit
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
         SET @cSKU = ''
         SET @nErrNo = 66521    
         SET @cErrMsg = rdt.rdtgetmessage( 66521, @cLangCode, 'DSP') --'Invalid SKU'    
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit
      END    
    
      -- Validate barcode return multiple SKU    
      IF @nSKUCnt > 1    
      BEGIN    
         SET @nErrNo = 0
         SET @cErrMsg1 = '66522 Same'
         SET @cErrMsg2 = 'Barcode in SKU'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
         END
         SET @cSKU = ''
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit  
      END    
  
      EXEC [RDT].[rdt_GETSKU]    
         @cStorerKey  = @cStorerKey,
         @cSKU        = @cSKU          OUTPUT,
         @bSuccess    = @b_Success     OUTPUT,
         @nErr        = @n_Err         OUTPUT,
         @cErrMsg     = @c_ErrMsg      OUTPUT

      IF @cSuggestedSKU <> @cSKU    
      BEGIN    
         SET @cSKU = ''
         SET @nErrNo = 66523    
         SET @cErrMsg = rdt.rdtgetmessage( 66523, @cLangCode, 'DSP') --'Different SKU'    
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit
      END    

      IF @cQty = '0'
      BEGIN
         SET @cQty = ''
         SET @nErrNo = 65937
         SET @cErrMsg = rdt.rdtgetmessage( 65937, @cLangCode, 'DSP') --'QTY needed'
         SET @cOutField03 = @cSKU
         EXEC rdt.rdtSetFocusField @nMobile, 4
         GOTO Quit
      END

      IF @cQty  = ''   SET @cQty  = '0' --'Blank taken as zero'
      IF RDT.rdtIsValidQTY( @cQty, 0) = 0
      BEGIN
         SET @cQty = ''
         SET @nErrNo = 65938
         SET @cErrMsg = rdt.rdtgetmessage( 65938, @cLangCode, 'DSP') --'Invalid QTY'
         SET @cOutField03 = @cSKU
         EXEC rdt.rdtSetFocusField @nMobile, 4
         GOTO Quit
      END

      IF (@nQtyAllocated - @nQtyPicked) < CAST(@cQty AS INT)
      BEGIN
         SET @cQty = ''
         SET @nErrNo = 65938
         SET @cErrMsg = rdt.rdtgetmessage( 65938, @cLangCode, 'DSP') --'Over Picked'
         SET @cOutField03 = @cSKU
         EXEC rdt.rdtSetFocusField @nMobile, 4
         GOTO Quit
      END

      SET @nQty = CAST(@cQty AS INT)

      BEGIN TRAN 

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
         SET @nErrNo = 66262
         SET @cErrMsg = rdt.rdtgetmessage( 66262, @cLangCode, 'DSP') --'Upd ID Fail'
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

      IF @nPickLockQty < @nPickDetailQty
      BEGIN
         INSERT INTO RDT.RDTPickLock
         (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey, LOT, LOC, SKU, Status, AddWho, AddDate, DropID, PickSlipNo, Mobile)
         VALUES
         ('', @cLoadKey, '', '**', @cStorerKey, @cZone, '', '', '', @cLOC, @cSKU, '1', @cUserName, GETDATE(), @cID, @cPickSlipNo, @nMobile)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 66519
            SET @cErrMsg = rdt.rdtgetmessage( 66519, @cLangCode, 'DSP') --'LockTaskFail'
            ROLLBACK TRAN
            GOTO Step_5_Fail
         END
      END
      ELSE
      BEGIN
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
                  SET @nErrNo = 66262
                  SET @cErrMsg = rdt.rdtgetmessage( 66262, @cLangCode, 'DSP') --'InsPHdrFail'
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
                  SET @nErrNo = 66263
                  SET @cErrMsg = rdt.rdtgetmessage( 66263, @cLangCode, 'DSP') --'InsPHdrFail'
                  ROLLBACK TRAN
                  GOTO Step_5_Fail               
               END
            END   -- @cPickSlipType = 'SINGLE'
         END   -- Check whether packheader exists


         SELECT TOP 1 @cConsigneeKey = RTRIM(O.Consigneekey), 
                      @cExternOrderKey = RTRIM(O.Externorderkey)
         FROM  dbo.PickHeader PH WITH (NOLOCK)
         JOIN  dbo.Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey)
         WHERE PH.PickHeaderKey = @cPickSlipNo

         DECLARE CUR_PACKDETAIL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT SKU, ID, PickQty FROM RDT.RDTPickLock WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LoadKey = @cLoadKey
            AND PutAwayZone = @cZone
            AND LOC = @cLOC
            AND SKU = @cSKU
            AND AddWho = @cUserName
            AND Status = '1'
         OPEN CUR_PACKDETAIL
         FETCH NEXT FROM CUR_PACKDETAIL INTO @cPD_SKU, @cPD_CartonNo, @nPD_Qty
         WHILE NOT @@FETCH_STATUS <> -1
         BEGIN
            -- Generate label here
            SELECT @cItemClass = RTRIM(SKU.Itemclass), 
                   @cBUSR5 = RTRIM(SKU.Busr5),
                   @cBUSR3 = RTRIM(SKU.BUSR3)
            FROM dbo.SKU SKU WITH (NOLOCK)
            WHERE SKU.SKU = @cPD_SKU
            AND   SKU.Storerkey = @cStorerKey
   
         	SELECT TOP 1 @cInterModalVehicle = RTRIM(ORDERS.IntermodalVehicle)
    	      FROM dbo.ORDERS ORDERS (NOLOCK)
   	      JOIN dbo.ORDERDETAIL ORDERDETAIL (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
      	   JOIN dbo.SKU SKU (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.Sku = SKU.Sku)
        		JOIN dbo.LOADPLANDETAIL LOADPLANDETAIL(NOLOCK) ON  (ORDERS.Orderkey = LOADPLANDETAIL.Orderkey)
        		WHERE LOADPLANDETAIL.Loadkey = @cLoadkey
        		AND ORDERS.Consigneekey = @cConsigneeKey
        		AND ORDERS.Externorderkey = @cExternOrderKey
        		AND SKU.Itemclass = @cItemClass
        		AND SKU.Busr5 = @cBUSR5
        		GROUP BY ORDERS.IntermodalVehicle


            SELECT @cKeyname = @cFacility + '_'+ @cInterModalVehicle
   
            BEGIN TRAN
   
   	      EXECUTE dbo.nspg_getkey
             @cKeyname
           , 6
    	     , @cLabelNo OUTPUT
     		  , @b_success OUTPUT
     		  , @n_err OUTPUT
     		  , @c_errmsg OUTPUT
   
            IF @b_success <> 1
            BEGIN
               SET @nErrNo = 66613
               SET @cErrMsg = rdt.rdtgetmessage( 66613, @cLangCode, 'DSP') -- 'GetDetKeyFail'
               ROLLBACK TRAN
               GOTO Step_3_Fail
            END

            COMMIT TRAN

           SET @cURNNo1 = LEFT(@cConsigneeKey,4) + LEFT(@cInterModalVehicle,3) + LEFT(@cLabelNo,6) +
                          ISNULL(LEFT(@cBUSR5,5),'') 
           SET @cURNNo2 = RIGHT('000'+RIGHT(ISNULL(RTRIM(@cItemClass),''),3),3) +
                          LEFT(@cExternOrderKey,6) + RIGHT('000'+RTRIM(CONVERT(char(3),@nPD_Qty)),3) + '01'

            SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE Pickslipno = @cPickSlipNo
               AND CartonNo = @nCartonNo

            -- Insert PackDetail
            INSERT INTO dbo.PackDetail 
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate)
            VALUES 
               (@cPickSlipNo, CAST(@cPD_CartonNo AS INT), @cLabelNo, @cLabelLine, @cStorerKey, @cPD_SKU, @nPD_Qty, sUser_sName(), GETDATE(), sUser_sName(), GETDATE())

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 64707
               SET @cErrMsg = rdt.rdtgetmessage( 64707, @cLangCode, 'DSP') --'InsPackDtlFail'
               RollBack Tran 
               GOTO Step_5_Fail
            END

            -- Insert PackInfo
            INSERT INTO dbo.PackInfo
              (PickSlipNo, CartonNo, AddWho, AddDate, EditWho, EditDate, CartonType, RefNo)
            VALUES 
              (@cPickSlipNo, CAST(@cPD_CartonNo AS INT), sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), @cBUSR3, RTRIM(@cURNNo1) + RTRIM(@cURNNo1))

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66529
               SET @cErrMsg = rdt.rdtgetmessage( 66529, @cLangCode, 'DSP') --'InsPackDtlFail'
               RollBack Tran 
               GOTO Step_5_Fail
            END

            FETCH NEXT FROM CUR_PACKDETAIL INTO @cPD_SKU, @cPD_CartonNo, @nPD_Qty
         END
         CLOSE CUR_PACKDETAIL
         DEALLOCATE CUR_PACKDETAIL

         EXEC RDT.rdt_GOH_Pick_ConfirmTask 
            @cStorerKey,
            @cUserName,
            @cFacility,
            @cZone,
            @cSKU,
            @cPickSlipNo,
            @cLOC,
            @cLOT,
            @nCartonNo,
            @cID,
            @cStatus,
            @cLangCode,
            @nErrNo          OUTPUT,
            @cErrMsg         OUTPUT,  -- screen limitation, 20 char max
            @nMobile, -- (Vicky06)
            @nFunc,   -- (Vicky06)
            @cPackUOM3 -- (Vicky06)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 66262
            SET @cErrMsg = rdt.rdtgetmessage( 66262, @cLangCode, 'DSP') --'InsPHdrFail'
            ROLLBACK TRAN
            GOTO Step_5_Fail
         END

         -- Confirm this pick task
         UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET 
            Status = '9' 
         WHERE StorerKey = @cStorerKey
            AND LoadKey = @cLoadKey
            AND PutAwayZone = @cZone
            AND LOC = @cLOC
            AND SKU = @cSKU
            AND AddWho = @cUserName
            AND Status = '1'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '99999 Confirm'
            SET @cErrMsg2 = 'PickLock fail!'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
               @cErrMsg1, @cErrMsg2
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
            END
            ROLLBACK TRAN 
            GOTO Step_5_Fail
         END
      END      -- IF @nPickLockQty < @nPickDetailQty

--      COMMIT TRAN

      -- Check whether got available SKU in LOAD + ZONE + LOC
      SELECT TOP 1 @cSuggestedSKU = SKU 
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
      WHERE PD.StorerKey = @cStorerKey  
         AND PD.Status < '4'
         AND PD.LOC = @cLOC  
         AND O.LoadKey = @cLoadKey
         AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK)
            WHERE RPL.LoadKey = @cLoadKey
               AND RPL.StorerKey = @cStorerKey
               AND PutAwayZone = @cZone
               AND LOC = @cLOC
               AND SKU = PD.SKU
               AND RPL.AddWho <> @cUserName
               AND RPL.Status = '1')
      ORDER BY PD.SKU  
      
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
            AND L.LOC = @cLOC
            AND L.PutAwayZone = @cZone
            AND L.Facility = @cFacility
            AND PD.Status >= '4'
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
                     SET @cErrMsg1 = '99999 '
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
                     GOTO Step_5_Fail
                  END

               END
            END   -- @cAutoPackConfirm

            -- Go to screen 7
            SET @nScn = @nScn + 2
            SET @nStep = @nStep + 2

            GOTO Quit
         END   -- IF ISNULL(@cNewSuggestedLoc, '') = ''
         ELSE  -- Got other LOC to pick then goto screen 2
         BEGIN
            SET @cSuggestedLoc = @cNewSuggestedLoc

            -- Prepare next screen var
            SET @cOutField01 = @cSuggestedLOC
            SET @cOutField02 = ''   --LOC
            SET @cLOC = ''

            -- Go to next screen
            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2
         END
      END
      ELSE  -- The same LOC got next SKU to pick, start locking
      -- Start lock down the task (Load + Zone + Loc + SKU)       
      BEGIN 
         INSERT INTO RDT.RDTPickLock
         (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey, LOT, LOC, SKU, Status, AddWho, AddDate, DropID, PickSlipNo, Mobile)
         VALUES
         ('', @cLoadKey, '', '**', @cStorerKey, @cZone, '', '', '', @cLOC, @cSuggestedSKU, '1', @cUserName, GETDATE(), @cID, @cPickSlipNo, @nMobile)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 65910
            SET @cErrMsg = rdt.rdtgetmessage( 65910, @cLangCode, 'DSP') --'LockOrdersFail'
            ROLLBACK TRAN 
            GOTO Step_5_Fail
         END

         SELECT 
            @cPackUOM3 = P.PACKUOM3, 
            @cDescr = SKU.Descr
         FROM dbo.SKU SKU WITH (NOLOCK) 
         JOIN dbo.PACK P WITH (NOLOCK) ON (SKU.PackKey = P.PackKey)
         WHERE SKU.StorerKey = @cStorerKey  
            AND SKU.SKU = @cSuggestedSKU  

         -- Getting the qtypicked
         SELECT @nQtyPicked = SUM(Qty) FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE O.StorerKey = @cStorerKey
            AND O.LoadKey = @cLoadKey
            AND L.LOC = @cLOC
            AND L.PutAwayZone = @cZone
            AND L.Facility = @cFacility
            AND PD.Status >= '4'
            AND PD.Status < '9'

         -- Getting the allocated
         SELECT @nQtyAllocated = SUM(Qty) FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE O.StorerKey = @cStorerKey
            AND O.LoadKey = @cLoadKey
            AND L.LOC = @cLOC
            AND L.PutAwayZone = @cZone
            AND L.Facility = @cFacility
            AND PD.Status = '0'

         -- Prepare next screen var  
         SET @cOutField01 = @cSuggestedSKU + CAST(@nQtyPicked AS NVARCHAR( 5)) + '/' + CAST(@nQtyAllocated AS NVARCHAR( 5))
         SET @cOutField02 = @cSuggestedSKU 
         SET @cOutField03 = SUBSTRING(@cDescr, 1, 20)  
         SET @cOutField04 = @cPackUOM3
         SET @cOutField05 = ''
     
         -- Go to next screen  
         SET @nScn = @nScn - 1  
         SET @nStep = @nStep - 1  
       --END
      END

      COMMIT TRAN

      -- Prepare next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = ''   --Case ID

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 --ESC
   BEGIN
      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      SET @cOutField01 = @cSuggestedLOC   -- Suggested LOC
      SET @cOutField02 = ''   -- LOC
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- QTY
   END

END
GOTO Quit

/********************************************************************************
Step 5. Scn = 1975. 
   OPTION        (field01, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
         --screen mapping
      SET @cOption = @cInField01  
  
      --if input is not either '1' or '2'  
      IF @cOption NOT IN ('1', '2')  
      BEGIN     
         SET @nErrNo = 65949  
         SET @cErrMsg = rdt.rdtgetmessage( 65949, @cLangCode, 'DSP') --Invalid Option  
         GOTO Step_5_Fail  
      END  

      IF @cOption = '1'
      BEGIN
         IF @cSHOWSHTPICKRSN = '1'
         BEGIN
            SET @cOutField01 = 1          
            SET @cOutField02 = @cPackUOM3 
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

         BEGIN TRAN

         -- Clear the uncompleted task for the same login
         DELETE FROM RDT.RDTPickLock WITH (ROWLOCK)
            WHERE StorerKey = @cStorerKey
               AND LoadKey = @cLoadKey
               AND PutAwayZone = @cZone
               AND LOC = @cLOC
               AND SKU = @cSKU
               AND Status = '1'
               AND AddWho = @cUserName

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 65911
            SET @cErrMsg = rdt.rdtgetmessage( 65911, @cLangCode, 'DSP') --'SKUAlrdLock'
            GOTO Quit
         END

         COMMIT TRAN

         SET @cOutField01 = @cDoor
         SET @cOutField02 = ''   -- PALLET ID
         SET @cID = ''

         -- Go to PLTID screen
         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 3
         GOTO Quit
      END
   END

   IF @nInputKey = 0 --ESC
   BEGIN
      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      SET @cCaseID = ''
      SET @cOutField02 = '' -- Case ID
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = '' -- Option
   END

END
GOTO Quit

/********************************************************************************
Step 6. Scn = 1976. 
   MSG        (field01, input)
********************************************************************************/
Step_6:
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
      SET @nScn = @nScn - 5
      SET @nStep = @nStep - 5
   END
END
GOTO Quit

/********************************************************************************
Step 7. Scn = 1977. 
   RSN        (field01, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
         --screen mapping
      SET @cReasonCode = @cInField05  
  
      IF ISNULL(@cReasonCode, '') = ''
      BEGIN
         SET @nErrNo = 60306
         SET @cErrMsg = rdt.rdtgetmessage( 60306, @cLangCode, 'DSP') --'BAD Reason'
         GOTO Step_7_Fail
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
         GOTO Step_7_Fail
      END
      ELSE
      BEGIN
         -- Initiate var
         SET @cLoadKey = ''
         SET @cZone = ''

         -- Init screen
         SET @cOutField01 = '' -- LoadKey
         SET @cOutField02 = '' -- Zone

         -- Go to screen 1
         SET @nScn = @nCurScn - 3
         SET @nStep = @nCurStep - 3
      END
   END

   IF @nInputKey = 0 --ESC
   BEGIN
      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      SET @cOutField01 = ''   -- Option
   END
   GOTO Quit

   Step_7_Fail:
   BEGIN
      SET @cReasonCode = ''
      SET @cOutField05 = '' -- RSN
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
      V_ID         = @cID,
      V_PickSlipNo = @cPickSlipNo,
      V_OrderKey   = @cOrderKey,
      V_LoadKey    = @cLoadKey,
      
      V_Cartonno   = @nCartonNo,
   
      V_Integer1   = @cAutoPackConfirm,
      V_Integer2   = @nCurScn,
      V_Integer3   = @nCurStep,
      V_Integer4   = @nQtyPicked,
      V_Integer5   = @nQtyAllocated,
      
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
      V_String13   = @cPackUOM3,
      --V_String14   = @nCurScn,
      --V_String15   = @nCurStep,
      --V_String16   = @nQtyPicked,
      --V_String17   = @nQtyAllocated,

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