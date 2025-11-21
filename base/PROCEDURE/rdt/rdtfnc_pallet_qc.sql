SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_Pallet_QC                                         */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#248014 - Pallet QC (Non TM)                                  */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2012-06-26 1.0  James    Created                                          */
/* 2012-09-21 1.1  James    Remove update dropid status and update pallet    */
/*                          check status into rdtqclog table (james01)       */
/* 2012-09-25 1.2  James    SOS257014 - Only allow pallet qc to start when   */
/*                          CLOSEPALLET msg received (james02)               */
/* 2016-09-30 1.3  Ung      Performance tuning                               */
/* 2018-11-12 1.4  Gan      Performance tuning                               */
/*****************************************************************************/

CREATE PROC [RDT].[rdtfnc_Pallet_QC](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON			-- SQL 2005 Standard
SET QUOTED_IDENTIFIER OFF	
SET ANSI_NULLS OFF   
SET CONCAT_NULL_YIELDS_NULL OFF        

-- Misc variable
DECLARE @b_Success      INT

-- Define a variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR(3),
   @cPrinter            NVARCHAR(10),
   @cPrinter_Paper      NVARCHAR(10),
   @cUserName           NVARCHAR(18),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),

   @cLoadKey            NVARCHAR( 10),
   
   @cSpecialHandling    NVARCHAR( 1),
   @cLOC                NVARCHAR( 10),
   @cLOC_Facility       NVARCHAR( 5),
   @cDropLoc            NVARCHAR( 10),
   @cID                 NVARCHAR( 18), 
   @cDropID             NVARCHAR( 18), 
   @cOption             NVARCHAR( 1), 
   @cStatus             NVARCHAR( 10), 
   @cLoadKey_MC         NVARCHAR( 10), 
   @cLOCAssigned        NVARCHAR( 10), 
   @cErrMsg1            NVARCHAR( 20),
   @cErrMsg2            NVARCHAR( 20),
   @cErrMsg3            NVARCHAR( 20),
   @cErrMsg4            NVARCHAR( 20),
   @cErrMsg5            NVARCHAR( 20),
   @cTempErrMsg1        NVARCHAR( 20),
   @cTempErrMsg2        NVARCHAR( 20),
   @cTempErrMsg3        NVARCHAR( 20),
   @cTempErrMsg4        NVARCHAR( 20),
   @cTempErrMsg5        NVARCHAR( 20),
   @cCartonID           NVARCHAR( 20),
   @cMissingCtn01       NVARCHAR( 20),
   @cMissingCtn02       NVARCHAR( 20),
   @cMissingCtn03       NVARCHAR( 20),
   @cMissingCtn04       NVARCHAR( 20),
   @cMissingCtn05       NVARCHAR( 20),
   @cMissingCtn06       NVARCHAR( 20),
   @cMissingCtn07       NVARCHAR( 20),
   @cMissingCtn08       NVARCHAR( 20),
   @cErrorMsg           NVARCHAR( 20),
   @ErrMsgNextScreen    NVARCHAR( 1),
   @cMBOL_Status        NVARCHAR( 10),
   @cLastCartonID       NVARCHAR( 20),
   @cMinPltShipDate     NVARCHAR( 10),
   @cCheckWeightLess1lb NVARCHAR( 1),
   @cNotes              NVARCHAR( 255),
   @cQC_Status          NVARCHAR( 10),    -- (james01)
   @cPalletRegExp       NVARCHAR( 20),    -- (james02)
   @cCartonIDRegExp     NVARCHAR( 20),    -- (james02)
   @cMissingCtn         NVARCHAR( 120),   -- (james02)

   @nErrorNo            INT, 
   @nCountLoadKey       INT, 
   @nCountLoadKey_MC    INT, 
   @nCnt                INT, 
   @nTtlPageCnt         INT, 
   @nTranCount          INT,
   @nLastScanNo         INT, 
   @nScanNo             INT, 
   @nCurPageCnt         INT, 
   @nSeqNo              INT, 
   @nTtl_MissingCtn     INT, 
   @nPrevScn            INT,
   @nPrevStep           INT,

   
   @dShipDate           DATETIME, 
   
   
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
   @cFieldAttr15 NVARCHAR( 1),

   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)

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
   @cPrinter_Paper   = Printer_Paper,
   @cUserName        = UserName,

   @cID              = V_ID,
   @cLoadKey         = V_LoadKey, 
   
   @nPrevScn         = V_FromScn,
   @nPrevStep        = V_FromStep,
   
   @ErrMsgNextScreen    = V_Integer1,
   @nCurPageCnt         = V_Integer2,
   @nTtlPageCnt         = V_Integer3,
   @cMinPltShipDate     = V_Integer4,
   @cCheckWeightLess1lb = V_Integer5,
   
   @cOption          = V_String1,
  -- @ErrMsgNextScreen = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String2, 5), 0) = 1 THEN LEFT( V_String2, 5) ELSE 0 END, 
  -- @nCurPageCnt      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3, 5), 0) = 1 THEN LEFT( V_String3, 5) ELSE 0 END, 
  -- @nTtlPageCnt      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4, 5), 0) = 1 THEN LEFT( V_String4, 5) ELSE 0 END, 
  -- @cMinPltShipDate  = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5, 5), 0) = 1 THEN LEFT( V_String5, 5) ELSE 0 END, 
  -- @nPrevScn         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6, 5), 0) = 1 THEN LEFT( V_String6, 5) ELSE 0 END, 
  -- @nPrevStep        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String7, 5), 0) = 1 THEN LEFT( V_String7, 5) ELSE 0 END, 
   
  -- @cCheckWeightLess1lb = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String8, 5), 0) = 1 THEN LEFT( V_String8, 5) ELSE 0 END, 
   @cPalletRegExp    = V_String9, 
   @cCartonIDRegExp  = V_String10, 


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
IF @nFunc = 1715
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1715
   IF @nStep = 1 GOTO Step_1   -- Scn = 3140 OPTION
   IF @nStep = 2 GOTO Step_2   -- Scn = 3141 PALLET ID
   IF @nStep = 3 GOTO Step_3   -- Scn = 3142 PALLET ID
   IF @nStep = 4 GOTO Step_4   -- Scn = 3143 PALLET ID, CARTON ID
   IF @nStep = 5 GOTO Step_5   -- Scn = 3144 MESSAGE
   IF @nStep = 6 GOTO Step_6   -- Scn = 3145 MESSAGE
   IF @nStep = 7 GOTO Step_7   -- Scn = 3146 AUDIT FAILED
   IF @nStep = 8 GOTO Step_8   -- Scn = 3147 MOVE TO TRIAGE
   IF @nStep = 9 GOTO Step_9   -- Scn = 3148 CARTON ID NOT FOUND
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1715)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 3140
   SET @nStep = 1

   SET @ErrMsgNextScreen = ''
   SET @ErrMsgNextScreen = rdt.RDTGetConfig( @nFunc, 'ErrMsgNextScreen', @cStorerkey)

   SET @cMinPltShipDate = ''
   SET @cMinPltShipDate = rdt.RDTGetConfig( @nFunc, 'MinPltShipDate', @cStorerKey)  

   SET @cCheckWeightLess1lb = ''
   SET @cCheckWeightLess1lb = rdt.RDTGetConfig( @nFunc, 'CheckWeightLess1lb', @cStorerKey)  

   SET @cPalletRegExp = ''
   SET @cPalletRegExp = rdt.RDTGetConfig( @nFunc, 'PalletRegularExp', @cStorerKey)  
   
   SET @cCartonIDRegExp = ''
   SET @cCartonIDRegExp = rdt.RDTGetConfig( @nFunc, 'CartonIDRegularExp', @cStorerKey)  

   -- initialise all variable
   SET @cOption = ''

   -- Prep next screen var
   SET @cOutField01 = ''
END
GOTO Quit

/********************************************************************************
Step 1. screen = 3140
   Option: (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      --Check if it is blank
      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 76551
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req
         GOTO Step_1_Fail
      END

      --Check if it is blank
      IF @cOption NOT IN ('1', '2', '3')
      BEGIN
         SET @nErrNo = 76552
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_1_Fail
      END
      
      IF @cOption IN ('1', '3')
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField02 = ''

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField02 = ''

         SET @cOption = ''
         SET @cLoadKey = ''
         
         EXEC rdt.rdtSetFocusField @nMobile, 1

         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2
      END

      -- insert to Eventlog
      EXEC RDT.rdt_STD_EventLog
        @cActionType   = '1', -- SignIn
        @cUserID       = @cUserName,
        @nMobileNo     = @nMobile,
        @nFunctionID   = @nFunc,
        @cFacility     = @cFacility,
        @cStorerKey    = @cStorerkey,
        @nStep         = @nStep
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Set the complete flag to 'Y' if user exit without complete audit
      IF EXISTS (SELECT 1 FROM rdt.rdtQCLog WITH (NOLOCK) 
                 WHERE StorerKey = @cStorerKey
                 AND PalletID = @cID
                 AND Completed = 'N')
      BEGIN
         SET @nTranCount = @@TRANCOUNT

         BEGIN TRAN
         SAVE TRAN rdt_InsQCLog
         
         UPDATE rdt.rdtQCLog WITH (ROWLOCK) SET 
            Completed = 'Y'
         WHERE StorerKey = @cStorerKey
            AND PalletID = @cID
            AND Completed = 'N'
            
         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN rdt_InsQCLog
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN rdt_InsQCLog
            SET @nErrNo = 76590
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS QCLog Fail'
            GOTO Quit
         END
   
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN rdt_InsQCLog
      END
      
      EXEC RDT.rdt_STD_EventLog
      @cActionType   = '9', -- SignOut
      @cUserID       = @cUserName,
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerkey,
      @nStep         = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      SET @cOutField01 = ''
      SET @cOption = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 2. screen = 3141
   PALLET ID   (Field01, Input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cID = @cInField02

      IF ISNULL(@cID, '') = '' AND @cOutField01 = ''
      BEGIN
         SET @nErrNo = 76553
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PLT ID req
         GOTO Step_2_Fail
      END

      IF rdt.rdtIsRegExMatch(@cPalletRegExp,ISNULL(RTRIM(@cID),'')) <> 1  
      BEGIN
         SET @nErrNo = 77251
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID PLT ID
         GOTO Step_2_Fail
      END    
      
      IF ISNULL(@cID, '') <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                        WHERE DropID = @cID)
--                        AND DropIDType = 'PALLET') 
         BEGIN
            SET @nErrNo = 76554
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PLT NOT EXISTS
            GOTO Step_2_Fail
         END
      END

      IF ISNULL(@cID, '') = ''
         SET @cID = @cOutField01

      -- Get LoadKey for normal carton
      SELECT
         @nCountLoadKey = COUNT( DISTINCT ISNULL( PH.LoadKey, '')),
         @cLoadKey = ISNULL( MAX( PH.LoadKey), '') -- Just to bypass SQL aggregate check
      FROM dbo.DropIDDetail DD WITH (NOLOCK)
         INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (DD.ChildID = PD.LabelNo)
         INNER JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
      WHERE DD.DropID = @cID

      -- Get LoadKey for master carton (which contain children) (ung01)
      SELECT
         @nCountLoadKey_MC = COUNT( DISTINCT ISNULL( PH.LoadKey, '')),
         @cLoadKey_MC = ISNULL( MAX( PH.LoadKey), '') -- Just to bypass SQL aggregate check
      FROM dbo.DropIDDetail DD WITH (NOLOCK)
         INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (DD.ChildID = PD.RefNo2)
         INNER JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
      WHERE DD.DropID = @cID

      SET @nCountLoadKey = @nCountLoadKey + @nCountLoadKey_MC
      IF @cLoadKey = ''
         SET @cLoadKey = @cLoadKey_MC

      IF @cOption = '3'
      BEGIN
         --GOTO PALLET_INQUIRY
         SET @cOutField01 = @cID
         
         -- Get Pallet QC status (james01)
         SELECT TOP 1 @cQC_Status = ISNULL([STATUS], '')
         FROM rdt.rdtQCLog WITH (NOLOCK) 
         WHERE PalletID = @cID
         AND   TranType = 'P'
         AND   Completed = 'Y'
         ORDER BY ScanNo DESC
         
         IF ISNULL(@cQC_Status, '') = ''
         BEGIN
            SET @nErrNo = 76563
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NOT AUDITED
            SET @cTempErrMsg1 = @cErrMsg
            --GOTO Step_2_Fail
            --GOTO CHECK_STAGING_LANE_2
         END

         IF ISNULL(@cQC_Status, '') = '5'
         BEGIN
            SET @nErrNo = 76571
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --AUDIT FAILED
            SET @cTempErrMsg1 = @cErrMsg
            --GOTO Step_2_Fail
            --GOTO CHECK_STAGING_LANE_2
         END
         
         IF ISNULL(@cQC_Status, '') = '9'
         BEGIN
            SET @nErrNo = 76568
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --AUDIT PASSED
            SET @cTempErrMsg1 = @cErrMsg
            --GOTO Step_2_Fail
            --GOTO CHECK_STAGING_LANE_2
         END

         IF @ErrMsgNextScreen = '1'
         BEGIN
            SET @cErrMsg1 = CASE WHEN ISNULL(@cTempErrMsg1, '') <> '' THEN @cTempErrMsg1 ELSE '' END
            SET @cErrMsg2 = CASE WHEN ISNULL(@cTempErrMsg2, '') <> '' THEN @cTempErrMsg2 ELSE '' END
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END
            
            SET @nErrNo = 0
            SET @cErrMsg = ''
         END
      
         SET @cOption = '3'
         SET @cOutField01 = ''
         
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
         GOTO Quit
      END
      
      IF ISNULL(@cOutField01, '') <> @cID AND ISNULL(@cID, '') <> ''
      BEGIN
         SET @cOutField01 = @cID
         
         SELECT @cStatus = Status FROM dbo.DropID WITH (NOLOCK) 
         WHERE DropID = @cID
         --AND DropIDType = 'PALLET'

         -- Get Pallet QC status (james01)
         SELECT TOP 1 @cQC_Status = ISNULL([STATUS], '')
         FROM rdt.rdtQCLog WITH (NOLOCK) 
         WHERE PalletID = @cID
         AND   TranType = 'P'
         AND   Completed = 'Y'
         ORDER BY ScanNo DESC
         
         IF ISNULL(@cStatus, '') = ''
         BEGIN
            SET @nErrNo = 76555
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Status
            SET @cTempErrMsg1 = @cErrMsg
            --GOTO Step_2_Fail
            --GOTO CHECK_STAGING_LANE_2
         END

         IF @cStatus = '0'
         BEGIN
            SET @nErrNo = 76556
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Build
            SET @cTempErrMsg1 = @cErrMsg
            --GOTO Step_2_Fail
            --GOTO CHECK_STAGING_LANE_2
         END
/*
         IF @cStatus = '1'
         BEGIN
            SET @nErrNo = 76557
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Audit Failed
            SET @cTempErrMsg1 = @cErrMsg
            --GOTO Step_2_Fail
            --GOTO CHECK_STAGING_LANE_2
         END

         IF @cStatus = '2'
         BEGIN
            SET @nErrNo = 76558
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Audit Done
            SET @cTempErrMsg1 = @cErrMsg
            --GOTO Step_2_Fail
            --GOTO CHECK_STAGING_LANE_2
         END

         IF @cQC_Status = '2' -- (james01)
         BEGIN
            SET @nErrNo = 76558
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Audit Done
            SET @cTempErrMsg1 = @cErrMsg
            --GOTO Step_2_Fail
            --GOTO CHECK_STAGING_LANE_2
         END
*/
         IF @cStatus = '3'
         BEGIN
            SET @nErrNo = 76559
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet P&H
            SET @cTempErrMsg1 = @cErrMsg
            --GOTO Step_2_Fail
            --GOTO CHECK_STAGING_LANE_2
         END

         IF @cStatus = '5'
         BEGIN
            SET @nErrNo = 76560
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Staged
            SET @cTempErrMsg1 = @cErrMsg
            --GOTO Step_2_Fail
            --GOTO CHECK_STAGING_LANE_2
         END

         IF @cStatus = '9'
         BEGIN
            SET @nErrNo = 76561
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Shipped
            SET @cTempErrMsg1 = @cErrMsg
            --GOTO Step_2_Fail
            --GOTO CHECK_STAGING_LANE_2
         END

         -- If the pallet happened to be audit(james01)
         IF @cQC_Status = '5' 
         BEGIN
            SET @nErrNo = 76557
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Audit Failed
            IF ISNULL(@cTempErrMsg1, '') = ''
            BEGIN
               SET @cTempErrMsg1 = @cErrMsg
            END
            ELSE
            BEGIN
               SET @cTempErrMsg2 = @cErrMsg
            END
            --GOTO Step_2_Fail
            --GOTO CHECK_STAGING_LANE_2
         END
         
         -- If the pallet happened to be audit(james01)
         IF @cQC_Status = '9' 
         BEGIN
            SET @nErrNo = 76558
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Audit Done
            IF ISNULL(@cTempErrMsg1, '') = ''
            BEGIN
               SET @cTempErrMsg1 = @cErrMsg
            END
            ELSE
            BEGIN
               SET @cTempErrMsg2 = @cErrMsg
            END
            --GOTO Step_2_Fail
            --GOTO CHECK_STAGING_LANE_2
         END
      END

      -- Check if pallet no LoadKey
      IF @nCountLoadKey = 0 OR @cLoadKey = ''
      BEGIN
         SET @nErrNo = 76562
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID no LoadKey
         GOTO Step_2_Fail
      END
/*
      -- Check if pallet has multi LoadKey
      IF @nCountLoadKey > 1 AND ISNULL(@cLoadKey, '') <> ISNULL(@cLoadKey_MC, '')
      BEGIN
         SET @nErrNo = 76563
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- IDMultiLoadKey
         GOTO Step_2_Fail
      END

      commented because 1 loadplan can be populated into multiple mbols (james01)
      -- Check whether Loadkey of the Pallet ID scanned has been shipped (MBOL.Status = 9)
      SELECT TOP 1 @cMBOL_Status = M.STATUS 
      FROM dbo.MBOLDetail MD WITH (NOLOCK) 
      JOIN dbo.MBOL M WITH (NOLOCK) ON MD.MbolKey = M.MbolKey
      WHERE MD.LoadKey = @cLoadKey
      
      IF ISNULL(@cMBOL_Status, '') = '9'
*/
      IF EXISTS (SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey AND STATUS = '9')
      BEGIN
         SET @nErrNo = 76594
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Load Shipped
         SET @cTempErrMsg2 = @cErrMsg
         --GOTO Step_2_Fail
         --GOTO CHECK_STAGING_LANE_2
      END

      CHECK_STAGING_LANE_2:
      -- Get lane assigned
      SET @cLOCAssigned = ''
      SELECT @cLOCAssigned = LOC
      FROM dbo.LoadPlanLaneDetail WITH (NOLOCK)
      WHERE LoadKey = @cLoadKey
         AND Status = '0' -- 0=Assigned, 9=Released

      IF ISNULL(@cLOCAssigned, '') = '' AND @cStatus < '3'  -- Not in Pack&Hold
      BEGIN
         -- Get Order ship date.
         -- not consider weekend (Saturday and Sunday)
         SELECT @dShipDate = 
            CASE DATEPART( dw, MIN(OrderDate))    
               WHEN 1 THEN DATEADD(day, 1, MIN(OrderDate)) -- if Sun, set to Mon    
               WHEN 7 THEN DATEADD(day, 2, MIN(OrderDate)) -- if Sat, set to Mon    
               ELSE MIN(OrderDate)     
            END         
         FROM dbo.Orders WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND LoadKey = @cLoadKey

         IF (DATEDIFF(d, GETDATE(), @dShipDate) < CAST( @cMinPltShipDate AS INT))
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '76564^NO STAGING'
            SET @cErrMsg2 = 'LANE ASSIGNED. GOTO'
            SET @cErrMsg3 = 'SHIPPING OFFICE.'
            SET @cErrMsg4 = CASE WHEN ISNULL(@cTempErrMsg1, '') <> '' THEN @cTempErrMsg1 ELSE '' END
            SET @cErrMsg5 = CASE WHEN ISNULL(@cTempErrMsg2, '') <> '' THEN @cTempErrMsg2 ELSE '' END
            SET @cErrMsg = ''
            SET @cTempErrMsg1 = ''
            SET @cTempErrMsg2 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END

            SET @cOption = '1'
            SET @cOutField01 = ''
            
            SET @nScn = @nScn - 1
            SET @nStep = @nStep - 1
            
            GOTO Quit
         END
      END

      -- If OPT = 1 and Press ENTER, go to Screen 9 to display message. 
      -- When press ENTER from Screen 9 go back to Screen 1 
      -- as this is just for getting the status of the Pallet
      IF @cOption = '1'
      BEGIN
         IF @ErrMsgNextScreen = '1'
         BEGIN
            SET @cErrMsg1 = CASE WHEN ISNULL(@cTempErrMsg1, '') <> '' THEN @cTempErrMsg1 ELSE '' END
            SET @cErrMsg2 = CASE WHEN ISNULL(@cTempErrMsg2, '') <> '' THEN @cTempErrMsg2 ELSE '' END
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END
            
            SET @nErrNo = 0
            SET @cErrMsg = ''
         END
      
         SET @cOption = '1'
         SET @cOutField01 = ''
         
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
      /*ELSE  -- If OPT = 3 and Press ENTER, go to screen 9 to inquire the missing cartons
      BEGIN
         PALLET_INQUIRY:
         -- Get the last scan no
         SET @nLastScanNo = 0
         SELECT TOP 1 
            @nLastScanNo = ScanNo, 
            @nSeqNo = SeqNo 
         FROM rdt.rdtQCLog WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND PalletID = @cID
            AND TranType = 'P'
            AND Completed = 'Y'
         ORDER BY SeqNo DESC

         IF EXISTS (SELECT 1  
                    FROM rdt.rdtQCLog QC WITH (NOLOCK)
                    WHERE StorerKey = @cStorerKey
                    AND PalletID = @cID
                    --AND Status = '5'    (james01)
                    AND MissingCtn = 'Y'
                    AND TranType = 'C'
                    AND SeqNo > @nSeqNo)
         BEGIN
            SET @nTtl_MissingCtn = 0
            SELECT @nTtl_MissingCtn = COUNT( DISTINCT( CartonID))
            FROM rdt.rdtQCLog QC WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND PalletID = @cID
               --AND Status = '5'      (james01)
               AND MissingCtn = 'Y'
               AND TranType = 'C'
               AND SeqNo > @nSeqNo

            SET @nCnt = 1
            -- Log all missing cartons to the RDTQCLOG table
            DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT DISTINCT CartonID 
            FROM rdt.rdtQCLog QC WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND PalletID = @cID
               --AND Status = '5'      (james01)
               AND MissingCtn = 'Y'
               AND TranType = 'C'
               AND SeqNo > @nSeqNo
            ORDER BY CartonID
            OPEN CUR_LOOP
            FETCH NEXT FROM CUR_LOOP INTO @cCartonID
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF @nCnt > 8
                  BREAK
               IF @nCnt = 1
                  SET @cMissingCtn01 = @cCartonID
               IF @nCnt = 2
                  SET @cMissingCtn02 = @cCartonID
               IF @nCnt = 3
                  SET @cMissingCtn03 = @cCartonID
               IF @nCnt = 4
                  SET @cMissingCtn04 = @cCartonID
               IF @nCnt = 5
                  SET @cMissingCtn05 = @cCartonID
               IF @nCnt = 6
                  SET @cMissingCtn06 = @cCartonID
               IF @nCnt = 7
                  SET @cMissingCtn07 = @cCartonID
               IF @nCnt = 8
                  SET @cMissingCtn08 = @cCartonID
                  
               SET @nCnt = @nCnt + 1
               
               FETCH NEXT FROM CUR_LOOP INTO @cCartonID
            END
            CLOSE CUR_LOOP
            DEALLOCATE CUR_LOOP

            IF ISNULL(@cMissingCtn01, '') <> ''
            BEGIN
               -- Clear prev screen variables
               SET @cOutField01 = ''
               SET @cOutField02 = ''
               SET @cOutField03 = ''
               SET @cOutField04 = ''
               SET @cOutField05 = ''
               SET @cOutField06 = ''
               SET @cOutField07 = ''
               SET @cOutField08 = ''
               SET @cOutField09 = ''
               
               SET @nTtlPageCnt = 0
               SET @nCurPageCnt = 1
               -- Prepare next screen variable
               IF @nTtl_MissingCtn % 8 = 0
                  SET @nTtlPageCnt = @nTtl_MissingCtn/8
               ELSE
                  SET @nTtlPageCnt = (@nTtl_MissingCtn/8) + 1

               SET @cOutField01 = RTRIM(CAST(@nCurPageCnt AS NVARCHAR(2))) + '/' + LTRIM(CAST(@nTtlPageCnt AS NVARCHAR(2)))
               SET @cOutField02 = @cMissingCtn01
               SET @cOutField03 = @cMissingCtn02
               SET @cOutField04 = @cMissingCtn03
               SET @cOutField05 = @cMissingCtn04
               SET @cOutField06 = @cMissingCtn05
               SET @cOutField07 = @cMissingCtn06
               SET @cOutField08 = @cMissingCtn07
               SET @cOutField09 = @cMissingCtn08
            END
         END
         ELSE
         BEGIN
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            SET @cOutField04 = ''
            SET @cOutField05 = ''
            SET @cOutField06 = ''
            SET @cOutField07 = ''
            SET @cOutField08 = ''

            SET @nErrNo = 0
            SET @cErrMsg1 = 'NO MISSING CARTON'
            SET @cErrMsg2 = 'ON PALLET '
            SET @cErrMsg3 = @cID
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            SET @cErrMsg = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END

            SET @cOption = '1'
            SET @cOutField01 = ''
            
            SET @nScn = @nScn - 1
            SET @nStep = @nStep - 1
            
            GOTO Quit
         END
         
         SET @nScn = @nScn + 7
         SET @nStep = @nStep + 7
      END*/
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cID = ''
      SET @cOutField01 = ''
      SET @cOutField02 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 3. screen = 3142
   PALLET ID   (Field01, Input)
   OPTION      (Field02, Input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cID = @cInField01
      SET @cOption = @cInField02
      SET @cNotes = ''
      
      IF ISNULL(@cID, '') = ''
      BEGIN
         SET @nErrNo = 76565
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PLT ID req
         SET @cNotes = ''
         GOTO Step_3_Fail
      END

      IF rdt.rdtIsRegExMatch(@cPalletRegExp,ISNULL(RTRIM(@cID),'')) <> 1  
      BEGIN
         SET @nErrNo = 77252
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID PLT ID
         SET @cNotes = ''
         GOTO Step_3_Fail
      END    

      IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                     WHERE DropID = @cID)
                     --AND DropIDType = 'PALLET')
      BEGIN
         SET @nErrNo = 76566
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PLT NOT EXISTS
         SET @cNotes = ''
         GOTO Step_3_Fail
      END

      IF EXISTS (SELECT 1 FROM rdt.rdtQCLog WITH (NOLOCK) 
                 WHERE PalletID = @cID 
                 AND Completed <> 'Y'
                 AND TranType = 'P')
      BEGIN
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN
         SAVE TRAN rdt_UPDQCLog
         
         UPDATE rdt.rdtQCLog WITH (ROWLOCK) SET 
            Completed = 'Y'
         WHERE PalletID = @cID 
         AND Completed <> 'Y'
         
         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN rdt_UPDQCLog
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN rdt_UPDQCLog

            SET @nErrNo = 76599
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD QCLOG FAIL
            SET @cNotes = ''
            GOTO Step_3_Fail
         END

         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN rdt_UPDQCLog
      END
      
      IF ISNULL(@cOption, '') <> ''
      BEGIN
         IF @cOption <> '1'
         BEGIN
            SET @nErrNo = 76573
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Option
            SET @cNotes = ''
            GOTO Step_3_Fail
         END

         SELECT @cStatus = Status FROM dbo.DropID WITH (NOLOCK) 
         WHERE DropID = @cID
         --AND DropIDType = 'PALLET'
      
         IF @cStatus = '9'
         BEGIN
            SET @nErrNo = 76569
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Shipped
            SET @cNotes = @cErrMsg
            SET @cTempErrMsg1 = @cErrMsg
            GOTO Step_3_Fail
         END
      
         EXEC [RDT].[rdt_InsQCLog] 
            @nMobile       , 
            @nFunc         , 
            @cUserName     , 
            @cStorerKey    , 
            @cID           , 
            ''             , 
            'P'            , 
            'Y'            , 
            '9'            ,
            ''             , 
            ''             ,
            'N'            ,
            @cLangCode     , 
            @nErrorNo        OUTPUT, 
            @cErrorMsg       OUTPUT 

         IF @nErrorNo <> 0
         BEGIN
            SET @nErrNo = @nErrorNo
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Ins QCLOG Fail
         END

         SET @cOutField01 = ''

         SET @nPrevScn = @nScn
         SET @nPrevStep = @nStep
         
         SET @nScn = @nScn + 5
         SET @nStep = @nStep + 5

         GOTO Quit
      END

      -- Get LoadKey for normal carton
      SELECT
         @nCountLoadKey = COUNT( DISTINCT ISNULL( PH.LoadKey, '')),
         @cLoadKey = ISNULL( MAX( PH.LoadKey), '') -- Just to bypass SQL aggregate check
      FROM dbo.DropIDDetail DD WITH (NOLOCK)
         INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (DD.ChildID = PD.LabelNo)
         INNER JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
      WHERE DD.DropID = @cID

      -- Get LoadKey for master carton (which contain children) (ung01)
      SELECT
         @nCountLoadKey_MC = COUNT( DISTINCT ISNULL( PH.LoadKey, '')),
         @cLoadKey_MC = ISNULL( MAX( PH.LoadKey), '') -- Just to bypass SQL aggregate check
      FROM dbo.DropIDDetail DD WITH (NOLOCK)
         INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (DD.ChildID = PD.RefNo2)
         INNER JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
      WHERE DD.DropID = @cID

      SET @nCountLoadKey = @nCountLoadKey + @nCountLoadKey_MC
      IF @cLoadKey = ''
         SET @cLoadKey = @cLoadKey_MC
         
      SELECT @cStatus = Status FROM dbo.DropID WITH (NOLOCK) 
      WHERE DropID = @cID
      --AND DropIDType = 'PALLET'

      IF ISNULL(@cStatus, '') = ''
      BEGIN
         SET @nErrNo = 76567
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Status
         SET @cNotes = @cErrMsg
         SET @cTempErrMsg1 = @cErrMsg
         --GOTO Step_3_Fail
         --GOTO CHECK_STAGING_LANE_3
      END
/*
      IF @cStatus = '2'
      BEGIN
         SET @nErrNo = 76568
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Audit Done
         SET @cNotes = @cErrMsg
         SET @cTempErrMsg1 = @cErrMsg
         --GOTO Step_3_Fail
         --GOTO CHECK_STAGING_LANE_3
      END
*/
      IF @cStatus = '9'
      BEGIN
         SET @nErrNo = 76569
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Shipped
         SET @cNotes = @cErrMsg
         SET @cTempErrMsg1 = @cErrMsg
         --GOTO Step_3_Fail
         --GOTO CHECK_STAGING_LANE_3
      END

      -- Check if pallet no LoadKey
      IF @nCountLoadKey = 0 OR @cLoadKey = ''
      BEGIN
         SET @nErrNo = 76570
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID no LoadKey
         SET @cNotes = ''
         GOTO Step_3_Fail
      END
/*
      -- Check if pallet has multi LoadKey
      IF @nCountLoadKey > 1 AND ISNULL(@cLoadKey, '') <> ISNULL(@cLoadKey_MC, '')
      BEGIN
         SET @nErrNo = 76571
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- IDMultiLoadKey
         SET @cNotes = ''
         GOTO Step_3_Fail
      END

      commented because 1 loadplan can be populated into multiple mbols (james01)
      -- Check whether Loadkey of the Pallet ID scanned has been shipped (MBOL.Status = 9)
      SELECT TOP 1 @cMBOL_Status = M.STATUS 
      FROM dbo.MBOLDetail MD WITH (NOLOCK) 
      JOIN dbo.MBOL M WITH (NOLOCK) ON MD.MbolKey = M.MbolKey
      WHERE MD.LoadKey = @cLoadKey

      IF ISNULL(@cMBOL_Status, '') = '9'

      IF EXISTS (SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey AND STATUS = '9')
      BEGIN
         SET @nErrNo = 76595
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Load Shipped
         SET @cTempErrMsg2 = @cErrMsg
         --GOTO Step_3_Fail
         --GOTO CHECK_STAGING_LANE_3
      END
*/
      CHECK_STAGING_LANE_3:
      -- Get lane assigned
      SET @cLOCAssigned = ''
      SELECT @cLOCAssigned = LOC
      FROM dbo.LoadPlanLaneDetail WITH (NOLOCK)
      WHERE LoadKey = @cLoadKey
         AND Status = '0' -- 0=Assigned, 9=Released

      IF ISNULL(@cLOCAssigned, '') = '' AND @cStatus < '3'  -- Not in Pack&Hold
      BEGIN
         -- Get Order ship date.
         -- not consider weekend (Saturday and Sunday)
         SELECT @dShipDate = 
            CASE DATEPART( dw, MIN(OrderDate))    
               WHEN 1 THEN DATEADD(day, 1, MIN(OrderDate)) -- if Sun, set to Mon    
               WHEN 7 THEN DATEADD(day, 2, MIN(OrderDate)) -- if Sat, set to Mon    
               ELSE MIN(OrderDate)     
            END         
         FROM dbo.Orders WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND LoadKey = @cLoadKey
            
         IF (DATEDIFF(d, GETDATE(), @dShipDate) < CAST( @cMinPltShipDate AS INT)) 
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '76572^NO STAGING'
            SET @cErrMsg2 = 'LANE ASSIGNED. GOTO'
            SET @cErrMsg3 = 'SHIPPING OFFICE.'
            SET @cErrMsg4 = CASE WHEN ISNULL(@cTempErrMsg1, '') <> '' THEN @cTempErrMsg1 ELSE '' END
            SET @cErrMsg5 = CASE WHEN ISNULL(@cTempErrMsg2, '') <> '' THEN @cTempErrMsg2 ELSE '' END
            SET @cErrMsg = ''
            SET @cTempErrMsg1 = ''
            SET @cTempErrMsg2 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cNotes = RTRIM(SUBSTRING(@cErrMsg1, 7, LEN(RTRIM(@cErrMsg1)) - 6)) + ' ' + @cErrMsg2 + ' ' + @cErrMsg3 
               IF ISNULL(@cErrMsg4, '') <> ''  
               BEGIN
                  SET @cNotes = RTRIM(@cNotes) + ', ' + RTRIM(SUBSTRING(@cErrMsg4, 7, LEN(RTRIM(@cErrMsg4)) - 6))  
                  
                  IF ISNULL(@cErrMsg5, '') <> ''
                  BEGIN
                     SET @cNotes = RTRIM(@cNotes) + ', ' + RTRIM(SUBSTRING(@cErrMsg5, 7, LEN(RTRIM(@cErrMsg5)) - 6)) 
                  END
               END
               
               IF ISNULL(@cErrMsg5, '') <> ''
               BEGIN
                  IF ISNULL(@cErrMsg4, '') = '' 
                  BEGIN
                     SET @cNotes = RTRIM(@cNotes) + ', ' + RTRIM(SUBSTRING(@cErrMsg5, 7, LEN(RTRIM(@cErrMsg5)) - 6)) 
                  END
               END
            
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END

            EXEC [RDT].[rdt_InsQCLog] 
               @nMobile       , 
               @nFunc         , 
               @cUserName     , 
               @cStorerKey    , 
               @cID           , 
               ''             , 
               'P'            , 
               'N'            , 
               '5'            ,
               ''             , 
               @cNotes        ,
               'Y'            ,
               @cLangCode     , 
               @nErrorNo        OUTPUT, 
               @cErrorMsg       OUTPUT 

            IF @nErrorNo <> 0
            BEGIN
               SET @nErrNo = @nErrorNo
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Ins QCLOG Fail
            END

            SET @cID = ''
            SET @cOption = ''
            
            SET @cOutField01 = ''
            SET @cOutField02 = ''

            EXEC rdt.rdtSetFocusField @nMobile, 1
      
            GOTO Quit
         END
      END

      IF ISNULL(@cErrMsg, '') <> ''
      BEGIN
         IF ISNULL(@cStatus, '') <> '2'
         BEGIN
            GOTO Step_3_Fail
         END
         ELSE
         BEGIN
            -- Pallet scanned with Status = 2 (Audit Passed) should be logged in 
            -- RDTQCLOG table as RDTQCLOG.Status = 9 since it's not a problem pallet
            SET @nErrNo = 0
            SET @cErrMsg1 = CASE WHEN ISNULL(@cTempErrMsg1, '') <> '' THEN @cTempErrMsg1 ELSE '' END
            SET @cErrMsg2 = CASE WHEN ISNULL(@cTempErrMsg2, '') <> '' THEN @cTempErrMsg2 ELSE '' END
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            SET @cErrMsg = ''
            SET @cTempErrMsg1 = ''
            SET @cTempErrMsg2 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               IF ISNULL(@cErrMsg1, '') <> ''  
               BEGIN
                  SET @cNotes = RTRIM(SUBSTRING(@cErrMsg1, 7, LEN(RTRIM(@cErrMsg1)) - 6))  
                  
                  IF ISNULL(@cErrMsg2, '') <> ''
                  BEGIN
                     SET @cNotes = RTRIM(@cNotes) + ', ' + RTRIM(SUBSTRING(@cErrMsg2, 7, LEN(RTRIM(@cErrMsg2)) - 6)) 
                  END
               END
               
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END
         
            EXEC [RDT].[rdt_InsQCLog] 
               @nMobile       , 
               @nFunc         , 
               @cUserName     , 
               @cStorerKey    , 
               @cID           , 
               ''             , 
               'P'            , 
               'N'            , 
               '9'            ,
               ''             , 
               @cNotes        ,
               'Y'            ,
               @cLangCode     , 
               @nErrorNo        OUTPUT, 
               @cErrorMsg       OUTPUT 

            IF @nErrorNo <> 0
            BEGIN
               SET @nErrNo = @nErrorNo
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Ins QCLOG Fail
            END
         
            SET @cID = ''
            SET @cOption = ''
            
            SET @cOutField01 = ''
            SET @cOutField02 = ''

            EXEC rdt.rdtSetFocusField @nMobile, 1
            
            GOTO Quit
         END
      END
      
      EXEC [RDT].[rdt_InsQCLog] 
         @nMobile       , 
         @nFunc         , 
         @cUserName     , 
         @cStorerKey    , 
         @cID           , 
         ''             , 
         'P'            , 
         'N'            , 
--         '9'            ,
         '0'            ,     -- 0 = started (james01)
         ''             , 
         ''             ,
         'N'            ,
         @cLangCode     , 
         @nErrorNo        OUTPUT, 
         @cErrorMsg       OUTPUT 

      IF @nErrorNo <> 0
      BEGIN
         SET @nErrNo = @nErrorNo
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Ins QCLOG Fail

         SET @cID = ''
         SET @cOption = ''
         
         SET @cOutField01 = ''
         SET @cOutField02 = ''

         EXEC rdt.rdtSetFocusField @nMobile, 1
         
         GOTO Quit
      END
         
      SET @cOutField01 = @cID
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1
      
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = ''
      
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      IF ISNULL(@cNotes, '') <> ''
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = CASE WHEN ISNULL(@cTempErrMsg1, '') <> '' THEN @cTempErrMsg1 ELSE '' END
         SET @cErrMsg2 = CASE WHEN ISNULL(@cTempErrMsg2, '') <> '' THEN @cTempErrMsg2 ELSE '' END
         SET @cErrMsg3 = ''
         SET @cErrMsg4 = ''
         SET @cErrMsg5 = ''
         SET @cErrMsg = ''
         SET @cTempErrMsg1 = ''
         SET @cTempErrMsg2 = ''
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
            @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
         IF @nErrNo = 1
         BEGIN
            IF ISNULL(@cErrMsg1, '') <> ''  
            BEGIN
               SET @cNotes = RTRIM(SUBSTRING(@cErrMsg1, 7, LEN(RTRIM(@cErrMsg1)) - 6))  
               
               IF ISNULL(@cErrMsg2, '') <> ''
               BEGIN
                  SET @cNotes = RTRIM(@cNotes) + ', ' + RTRIM(SUBSTRING(@cErrMsg2, 7, LEN(RTRIM(@cErrMsg2)) - 6)) 
               END
            END
            
            IF ISNULL(@cErrMsg2, '') <> ''
            BEGIN
               IF ISNULL(@cErrMsg1, '') = '' 
               BEGIN
                  SET @cNotes = RTRIM(SUBSTRING(@cErrMsg2, 7, LEN(RTRIM(@cErrMsg2)) - 6)) 
               END
            END
            
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
         END

         EXEC [RDT].[rdt_InsQCLog] 
            @nMobile       , 
            @nFunc         , 
            @cUserName     , 
            @cStorerKey    , 
            @cID           , 
            ''             , 
            'P'            , 
            'N'            , 
            '5'            ,
            ''             , 
            @cNotes        ,
            'Y'            ,
            @cLangCode     , 
            @nErrorNo        OUTPUT, 
            @cErrorMsg       OUTPUT 
         
         IF @nErrorNo <> 0
         BEGIN
            SET @nErrNo = @nErrorNo
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Ins QCLOG Fail
         END
      END
      
      SET @cID = ''
      SET @cOption = ''
      
      SET @cOutField01 = ''
      SET @cOutField02 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
END
GOTO Quit

/********************************************************************************
Step 4. screen = 3143
   PALLET ID   (Field01)
   CARTON ID   (Field02, Input)
   OPTION      (Field03, Input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cCartonID = @cInField02
      SET @cOption = @cInField03
      SET @cNotes = ''
      
      IF ISNULL(@cOption, '') <> ''
      BEGIN
         IF @cOption <> '1'
         BEGIN
            SET @nErrNo = 76581
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Option
            SET @cNotes = ''
            GOTO Step_4_Fail
         END

         -- Check if pallet contains missing carton
         IF EXISTS (SELECT 1  
            FROM dbo.DropIDDetail DD WITH (NOLOCK)
            JOIN dbo.DropID D WITH (NOLOCK) ON DD.DropID = D.DropID
            WHERE D.DropID = @cID
               --AND D.LoadKey = @cLoadKey
               --AND D.DropIDType = 'PALLET'
               AND NOT EXISTS 
               (SELECT 1 FROM rdt.rdtQCLog QC WITH (NOLOCK) 
                WHERE DD.DropID = QC.PalletID
                AND DD.ChildID = QC.CartonID
                AND QC.StorerKey = @cStorerKey
                AND QC.Completed = 'N')
                -- ignore those inner pack for master pacck
                AND NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                          WHERE StorerKey = @cStorerKey
                          AND   LabelNo = DD.ChildID
                          AND   ISNULL(Refno2, '') <> ''))
         BEGIN
            -- Log all missing cartons to the RDTQCLOG table
            DECLARE CUR_INS CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT DISTINCT DD.ChildID 
            FROM dbo.DropIDDetail DD WITH (NOLOCK)
            JOIN dbo.DropID D WITH (NOLOCK) ON DD.DropID = D.DropID
            WHERE D.DropID = @cID
               --AND D.LoadKey = @cLoadKey
               --AND D.DropIDType = 'PALLET'
               AND NOT EXISTS 
               (SELECT 1 FROM rdt.rdtQCLog QC WITH (NOLOCK) 
                WHERE DD.DropID = QC.PalletID
                AND DD.ChildID = QC.CartonID
                AND QC.StorerKey = @cStorerKey
                AND QC.Completed = 'N')
                -- ignore those inner pack for master pacck
                AND NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                          WHERE StorerKey = @cStorerKey
                          AND   LabelNo = DD.ChildID
                          AND   ISNULL(Refno2, '') <> '')
            ORDER BY DD.ChildID
            OPEN CUR_INS
            FETCH NEXT FROM CUR_INS INTO @cCartonID
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               SET @cMissingCtn = 'MISSING CARTON ' + RTRIM(@cCartonID) + ' on Pallet ID ' + @cID
               SET @nErrorNo = 0
               EXEC [RDT].[rdt_InsQCLog] 
                  @nMobile          , 
                  @nFunc            , 
                  @cUserName        , 
                  @cStorerKey       , 
                  @cID              , 
                  @cCartonID        , 
                  'C'               , 
                  'N'               , 
                  '5'               ,
                  'Y'               , 
--                  'MISSING CARTON'  ,
                  @cMissingCtn      ,
                  'Y'               ,
                  @cLangCode        , 
                  @nErrorNo         OUTPUT, 
                  @cErrorMsg        OUTPUT 
               
               IF @nErrorNo <> 0
               BEGIN
                  SET @nErrNo = @nErrorNo
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Ins QCLOG Fail
               END
               
               FETCH NEXT FROM CUR_INS INTO @cCartonID
            END
            CLOSE CUR_INS
            DEALLOCATE CUR_INS
         END
         
         EXEC [RDT].[rdt_InsQCLog] 
            @nMobile       , 
            @nFunc         , 
            @cUserName     , 
            @cStorerKey    , 
            @cID           , 
            ''     , 
            'C'            , 
            'Y'            , 
            '9'            ,
            ''             , 
            ''             ,
            'N'            ,
            @cLangCode     , 
            @nErrorNo        OUTPUT, 
            @cErrorMsg       OUTPUT 

         IF @nErrorNo <> 0
         BEGIN
            SET @nErrNo = @nErrorNo
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Ins QCLOG Fail
            
            SET @cCartonID = ''
            SET @cOption = ''
            
            SET @cOutField02 = ''
            SET @cOutField03 = ''

            EXEC rdt.rdtSetFocusField @nMobile, 2
            
            GOTO Quit
         END

         SET @cOutField01 = ''

         SET @nPrevScn = @nScn
         SET @nPrevStep = @nStep

         SET @nScn = @nScn + 4
         SET @nStep = @nStep + 4

         GOTO Quit
      END

      -- Check if empty carton
      IF ISNULL(@cCartonID, '') = ''
      BEGIN
         SET @nErrNo = 76574
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Carton ID Req'
         SET @cNotes = ''
         GOTO Step_4_Fail
      END

      -- Check regular expression
      IF rdt.rdtIsRegExMatch(@cCartonIDRegExp,ISNULL(RTRIM(@cCartonID),'')) <> 1  
      BEGIN
         SET @nErrNo = 77253
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID CTN ID
         SET @cNotes = ''
         GOTO Step_4_Fail
      END    

      -- Check if carton been removed from packdetail/cancelled
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND   @cCartonID IN (LabelNo, RefNo2) )
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = '76578 CARTON DOES'
         SET @cErrMsg2 = 'NOT EXISTS!!!'
         SET @cErrMsg3 = ''
         SET @cErrMsg4 = 'USE WCS TO CHECK.'
         SET @cErrMsg5 = ''
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
            @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
         IF @nErrNo = 1
         BEGIN
            SET @cNotes = ISNULL(RTRIM(@cErrMsg1), '') + ' ' + ISNULL(RTRIM(@cErrMsg2), '') + ' ' + ISNULL(RTRIM(@cErrMsg3), '')
            SET @cNotes = RTRIM(@cNotes) + ' ' + ISNULL(RTRIM(@cErrMsg4), '') + ' ' + ISNULL(RTRIM(@cErrMsg5), '') 
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
         END

         GOTO Step_4_Fail
      END

      -- Check duplicate carton
      SET @nLastScanNo = 0
      SELECT TOP 1 
         @nLastScanNo = ScanNo 
      FROM rdt.rdtQCLog WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND PalletID = @cID
         AND TranType = 'P'
         AND Completed <> 'Y'
      ORDER BY SeqNo DESC

      IF EXISTS (SELECT 1 FROM rdt.rdtQCLog WITH (NOLOCK) 
                 WHERE StorerKey = @cStorerKey
                    AND PalletID = @cID
                    AND CartonID = @cCartonID
                    AND TranType = 'C'
                    AND ScanNo = @nLastScanNo)
      BEGIN
         SET @nErrNo = 76598
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Carton scanned
         SET @cNotes = ''
         GOTO Step_4_Fail
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.DropIDDetail DD WITH (NOLOCK) 
                     JOIN dbo.DropID D WITH (NOLOCK) ON DD.DropID = D.DropID
                     WHERE D.DropID = @cID
                     --AND D.DropIDType = 'PALLET'
                     AND DD.ChildID = @cCartonID)
      BEGIN
         SELECT @cDropID = D.DropID, 
                @cStatus = D.Status, 
                @cDropLoc = D.DropLoc 
         FROM dbo.DropIDDetail DD WITH (NOLOCK) 
         JOIN dbo.DropID D WITH (NOLOCK) ON DD.DropID = D.DropID
         --WHERE D.DropIDType = 'PALLET'
         WHERE DD.ChildID = @cCartonID

         -- If Carton does not exist in DropID at all, prompt ôCarton Not Exists. Use WCS To Checkö
         IF ISNULL(@cDropID, '') = ''
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '76575 CARTON NOT'
            SET @cErrMsg2 = 'EXISTS!!!'
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = 'USE WCS TO CHECK.'
            SET @cErrMsg5 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cNotes = ISNULL(RTRIM(@cErrMsg1), '') + ' ' + ISNULL(RTRIM(@cErrMsg2), '') + ' ' + ISNULL(RTRIM(@cErrMsg3), '')
               SET @cNotes = RTRIM(@cNotes) + ' ' + ISNULL(RTRIM(@cErrMsg4), '') + ' ' + ISNULL(RTRIM(@cErrMsg5), '') 
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END

            GOTO Step_4_Fail
         END
         
         -- If carton is shipped
         IF ISNULL(@cStatus, '') = '9'
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '76576 CARTON SHIPPED'
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = 'SEE SUPERVISOR.'
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cNotes = ISNULL(RTRIM(@cErrMsg1), '') + ' ' + ISNULL(RTRIM(@cErrMsg2), '') + ' ' + ISNULL(RTRIM(@cErrMsg3), '')
               SET @cNotes = RTRIM(@cNotes) + ' ' + ISNULL(RTRIM(@cErrMsg4), '') + ' ' + ISNULL(RTRIM(@cErrMsg5), '') 
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END

            GOTO Step_4_Fail
         END
         
         -- Prompt the dropid that carton belong to
         SET @nErrNo = 0
         SET @cErrMsg1 = '76577 CARTON BELONGS'
         SET @cErrMsg2 = 'TO PALLET ID'
         SET @cErrMsg3 = @cDropID
         SET @cErrMsg4 = 'AT LOC ' + @cDropLoc
         SET @cErrMsg5 = ''
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
            @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
         IF @nErrNo = 1
         BEGIN
            SET @cNotes = ISNULL(RTRIM(@cErrMsg1), '') + ' ' + ISNULL(RTRIM(@cErrMsg2), '') + ' ' + ISNULL(RTRIM(@cErrMsg3), '')
            SET @cNotes = RTRIM(@cNotes) + ' ' + ISNULL(RTRIM(@cErrMsg4), '') + ' ' + ISNULL(RTRIM(@cErrMsg5), '') 
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
         END

         GOTO Step_4_Fail
      END

/*
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND @cCartonID IN (LabelNo, Refno2)) -- (james01)
      BEGIN
         BEGIN
            SET @nErrNo = 76578
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv Carton ID'
            SET @cNotes = ''
            GOTO Step_4_Fail
         END
      END
*/
      IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                 WHERE StorerKey = @cStorerKey
                 AND   LabelNo = @cCartonID
                 AND   ISNULL(Refno2, '') <> '')
      BEGIN
         SET @nErrNo = 76600
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SCAN MASTERPCK'
         SET @cNotes = ''
         GOTO Step_4_Fail
      END
      
      SELECT TOP 1 @cSpecialHandling = O.SpecialHandling 
      FROM dbo.Orders O WITH (NOLOCK)
      JOIN dbo.StorerConfig SC WITH (NOLOCK) ON O.StorerKey = SC.StorerKey
      WHERE O.StorerKey = @cStorerKey
         AND O.LoadKey = @cLoadKey
         AND SC.ConfigKey = 'CheckCarrierRequirement'

      IF ISNULL(@cSpecialHandling, '') IN ('U', 'X', 'D')
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK) 
                    JOIN dbo.PackInfo PIF WITH (NOLOCK) 
                       ON (PD.PickSlipNo = PIF.PickSlipNo AND PD.CartonNo = PIF.CartonNo)
                    WHERE PD.StorerKey = @cStorerKey
                    AND @cCartonID IN (PD.LabelNo, PD.Refno2)  -- (james01)
                    AND ISNULL(PIF.Weight, 0) <= 0)
         BEGIN
            SET @nErrNo = 76579
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Missing Weight'
            SET @cNotes = @cErrMsg
            GOTO Step_4_Fail
         END
         
         IF ISNULL(@cCheckWeightLess1lb, '') = '1'
         BEGIN
            IF EXISTS (SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK) 
                       JOIN dbo.PackInfo PIF WITH (NOLOCK) 
                          ON (PD.PickSlipNo = PIF.PickSlipNo AND PD.CartonNo = PIF.CartonNo)
                       WHERE PD.StorerKey = @cStorerKey
                       AND @cCartonID IN (PD.LabelNo, PD.Refno2)
                       AND ISNULL(PIF.Weight, 0) > 0
                       AND ISNULL(PIF.Weight, 0) < 1)
            BEGIN
               SET @nErrNo = 76593
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Weight <1 lb'
               SET @cNotes = @cErrMsg
               GOTO Step_4_Fail
            END
         END
         
         IF EXISTS (SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK)
                    JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
                    WHERE PD.StorerKey = @cStorerKey
                    AND @cCartonID IN (PD.LabelNo, PD.Refno2)  -- (james01)
                    AND ISNULL(PD.UPC, '') = ''
                    AND PH.LoadKey = @cLoadKey)
         BEGIN
            SET @nErrNo = 76580
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Missing Track#'
            SET @cNotes = @cErrMsg
            GOTO Step_4_Fail
         END
      END

      EXEC [RDT].[rdt_InsQCLog] 
         @nMobile       , 
         @nFunc         , 
         @cUserName     , 
         @cStorerKey    , 
         @cID           , 
         @cCartonID     , 
         'C'            , 
         'N'            , 
         '9'            ,
         ''             , 
         ''             ,
         'N'            ,
         @cLangCode     , 
         @nErrorNo        OUTPUT, 
         @cErrorMsg       OUTPUT 

      IF @nErrorNo <> 0
      BEGIN
         SET @nErrNo = @nErrorNo
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Ins QCLOG Fail
         
         SET @cCartonID = ''
         SET @cOption = ''
         
         SET @cOutField02 = ''
         SET @cOutField03 = ''

         EXEC rdt.rdtSetFocusField @nMobile, 2
         
         GOTO Quit
      END
   END

   IF @nInputKey = 0 -- ENTER
   BEGIN
      SET @coption = ''
      SET @cOutField01 = ''

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END
   GOTO Quit
   
   Step_4_Fail:
   BEGIN
      IF ISNULL(@cNotes, '') <> ''
      BEGIN
         EXEC [RDT].[rdt_InsQCLog] 
            @nMobile       , 
            @nFunc         , 
            @cUserName     , 
            @cStorerKey    , 
            @cID           , 
            @cCartonID     , 
            'C'            , 
            'N'            , 
            '5'            ,
            ''             , 
            @cNotes        ,
            'N'            ,
            @cLangCode     , 
            @nErrorNo        OUTPUT, 
            @cErrorMsg       OUTPUT 

         IF @nErrorNo <> 0
         BEGIN
            SET @nErrNo = @nErrorNo
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Ins QCLOG Fail
            
            SET @cCartonID = ''
            SET @cOption = ''
            
            SET @cOutField02 = ''
            SET @cOutField03 = ''

            EXEC rdt.rdtSetFocusField @nMobile, 2
            
            GOTO Quit
         END
      END
      
      SET @cCartonID = ''
      SET @cOption = ''
      
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 2
   END
END
GOTO Quit

/********************************************************************************
Step 5. screen = 3144
   Audit Complete ?? (field01, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cOption = @cInfield01

      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 76582
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Option Req
         GOTO Step_5_Fail
      END

      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 76583
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Option
         GOTO Step_5_Fail
      END

      IF @cOption = '1'
      BEGIN
         -- Get the current scan no to determine which batch of audit should use
--         SET @nScanNo = 0
--         SELECT @nScanNo =  MAX( ScanNo) FROM rdt.rdtQCLog QC WITH (NOLOCK)
--         WHERE QC.StorerKey = @cStorerKey
--            AND QC.PalletID = @cID
--            AND QC.AddWho = @cUserName
            
         -- Check if pallet contains missing carton
         IF EXISTS (SELECT 1  
            FROM dbo.DropIDDetail DD WITH (NOLOCK)
            JOIN dbo.DropID D WITH (NOLOCK) ON DD.DropID = D.DropID
            WHERE D.DropID = @cID
               --AND D.LoadKey = @cLoadKey
               --AND D.DropIDType = 'PALLET'
               AND NOT EXISTS 
               (SELECT 1 FROM rdt.rdtQCLog QC WITH (NOLOCK) 
                WHERE DD.DropID = QC.PalletID
                AND DD.ChildID = QC.CartonID
                AND QC.StorerKey = @cStorerKey
                AND QC.Completed = 'N')
                -- ignore those inner pack for master pack  -- (james01)
                AND NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                          WHERE StorerKey = @cStorerKey
                          AND   LabelNo = DD.ChildID
                          AND   ISNULL(Refno2, '') <> ''))
         BEGIN
            SET @nCnt = 1
            -- Log all missing cartons to the RDTQCLOG table
            DECLARE CUR_INS CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT DISTINCT DD.ChildID 
            FROM dbo.DropIDDetail DD WITH (NOLOCK)
            JOIN dbo.DropID D WITH (NOLOCK) ON DD.DropID = D.DropID
            WHERE D.DropID = @cID
               --AND D.LoadKey = @cLoadKey
               --AND D.DropIDType = 'PALLET'
               AND NOT EXISTS 
               (SELECT 1 FROM rdt.rdtQCLog QC WITH (NOLOCK) 
                WHERE DD.DropID = QC.PalletID
                AND DD.ChildID = QC.CartonID
                AND QC.StorerKey = @cStorerKey
                AND QC.Completed = 'N')
                -- ignore those inner pack for master pack  -- (james01)
                AND NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                          WHERE StorerKey = @cStorerKey
                          AND   LabelNo = DD.ChildID
                          AND   ISNULL(Refno2, '') <> '')
            ORDER BY DD.ChildID
            OPEN CUR_INS
            FETCH NEXT FROM CUR_INS INTO @cCartonID
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               -- Check if it is part of the master pack (james01)
--               IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
--                          WHERE StorerKey = @cStorerKey
--                          AND   LabelNo = @cCartonID
--                          AND   ISNULL(Refno2, '') <> '')
--                          AND   Refno2 IN (SELECT CartonID FROM rdt.rdtQCLog WITH (NOLOCK) 
--                                           WHERE PalletID = @cID
--                                           AND   TranType = 'C'
--                                           AND   Completed <> 'Y'))
--               BEGIN           
                  SET @cMissingCtn = 'MISSING CARTON ' + @cCartonID + ' on Pallet ID ' + @cID
                  SET @nErrorNo = 0
                  EXEC [RDT].[rdt_InsQCLog] 
                     @nMobile          , 
                     @nFunc            , 
                     @cUserName        , 
                     @cStorerKey       , 
                     @cID              , 
                     @cCartonID        , 
                     'C'               , 
                     'N'               , 
                     '5'               ,
                     'Y'               , 
--                     'MISSING CARTON'  ,
                     @cMissingCtn      ,
                     'Y'               ,
                     @cLangCode        , 
                     @nErrorNo         OUTPUT, 
                     @cErrorMsg        OUTPUT 
                  
                  IF @nErrorNo <> 0
                  BEGIN
                     SET @nErrNo = @nErrorNo
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Ins QCLOG Fail
                  END
                  
                  IF @nCnt = 1
                     SET @cMissingCtn01 = @cCartonID
                  IF @nCnt = 2
                     SET @cMissingCtn02 = @cCartonID
                  IF @nCnt = 3
                     SET @cMissingCtn03 = @cCartonID
                  IF @nCnt = 4
                     SET @cMissingCtn04 = @cCartonID
                  IF @nCnt = 5
                     SET @cMissingCtn05 = @cCartonID

                  SET @nCnt = @nCnt + 1
--               END
               
               FETCH NEXT FROM CUR_INS INTO @cCartonID
            END
            CLOSE CUR_INS
            DEALLOCATE CUR_INS

            -- Clear prev screen variables
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            SET @cOutField04 = ''
            SET @cOutField05 = ''
            SET @cOutField06 = ''
            SET @cOutField07 = ''
            SET @cOutField08 = ''

            SET @nCnt = @nCnt - 1
            SET @nCurPageCnt = 1
            SET @nTtlPageCnt = 0
            
            -- Prepare next screen variable
            IF @nCnt % 5 = 0
               SET @nTtlPageCnt = @nCnt/5
            ELSE
               SET @nTtlPageCnt = (@nCnt/5) + 1

            SET @cOutField01 = RTRIM(CAST(@nCurPageCnt AS NVARCHAR(2))) + '/' + LTRIM(CAST(@nTtlPageCnt AS NVARCHAR(2)))
            SET @cOutField02 = @cMissingCtn01
            SET @cOutField03 = @cMissingCtn02
            SET @cOutField04 = @cMissingCtn03
            SET @cOutField05 = @cMissingCtn04
            SET @cOutField06 = @cMissingCtn05
            SET @cOutField07 = ''
            SET @cOutField08 = 'Carton IDs Not Found'
            
            SET @nScn = @nScn + 2
            SET @nStep = @nStep + 2
         END   -- If pallet contains missing or extra cartons or doesnÆt pass other validations
         ELSE
         BEGIN
            -- Check if any invalid carton id scanned
            IF EXISTS (SELECT 1 FROM rdt.rdtQCLog WITH (NOLOCK) 
                       WHERE StorerKey = @cStorerKey
                       AND PalletID = @cID
                       AND TranType = 'C'
                       AND Completed = 'N'
                       AND datalength(Notes) > 0 )
                       --AND Status = '5')   -- (james01)
            BEGIN
               SET @cOutField01 = ''
               SET @cOutField02 = ''
               SET @cOutField03 = ''
               SET @cOutField04 = ''
               SET @cOutField05 = ''
               SET @cOutField06 = ''
               SET @cOutField07 = ''
               SET @cOutField08 = ''

               SET @nScn = @nScn + 2
               SET @nStep = @nStep + 2
            END
            ELSE
            BEGIN
               SET @nTranCount = @@TRANCOUNT
               BEGIN TRAN
               SAVE TRAN UPD_QCLog

               -- If complete QC with no error then update rdtQCLog.status = '2' (Audit Done)               
               UPDATE rdt.rdtQCLog WITH (ROWLOCK) SET 
                  Completed = 'Y', 
                  [STATUS] = '9',       -- Audit Done (james01) 
                  Notes = CASE WHEN TranType = 'P' THEN 'AUDIT PASS' ELSE Notes END 
               WHERE StorerKey = @cStorerKey
                  AND PalletID = @cID
                  AND Completed = 'N'
                  
               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN UPD_QCLog
                  WHILE @@TRANCOUNT > @nTranCount
                     COMMIT TRAN
                  SET @nErrNo = 76584
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Upd QCLog Fail
                  GOTO Step_5_Fail
               END
               
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN

               SET @nScn = @nScn + 1
               SET @nStep = @nStep + 1
            END
         END
      END   -- @cOption = '1'
      ELSE
      BEGIN
         -- Go back to scan carton id again
         SET @cOutField01 = @cID
         SET @cOutField02 = ''
         SET @cOutField03 = ''

         EXEC rdt.rdtSetFocusField @nMobile, 1
         
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
   END
   GOTO Quit
      
   Step_5_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 6. screen = 3145
   Audit Is Successful (field01, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
   /*
      -- Only Update the DropID.Status = 2 for those Palllet with Status < 3. We can't be 
      -- reversing the Status of a Pallet in Staging Lane and Pack & Hold if the Audit Pass
      IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                 WHERE DropID = @cID
                 AND DropIDType = 'PALLET'
                 AND Status < '3')
      BEGIN
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN
         SAVE TRAN UPD_DROPID

         UPDATE dbo.DROPID WITH (ROWLOCK) SET 
            Status = '2'   -- Audit done
         WHERE DropID = @cID
            --AND LoadKey = @cLoadKey
            AND DropIDType = 'PALLET'
            --AND Status <> '2'
            
         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN UPD_DROPID
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN
            SET @nErrNo = 76585
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Upd QCLog Fail
            GOTO Quit
         END

         WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN
      END
      */
      SET @cOption = ''
      SET @cOutField01 = ''
      
      SET @nScn = @nScn - 5
      SET @nStep = @nStep - 5
   END
END
GOTO Quit

/********************************************************************************
Step 7. screen = 3146
   MESSAGE (field01, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cOption = @cInField07
      
      IF ISNULL(@cOption, '') <> ''
      BEGIN
         IF @cOption <> '1'
         BEGIN
            SET @nErrNo = 76586
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Invalid Option
            GOTO Step_7_Fail
         END

         EXEC [RDT].[rdt_InsQCLog] 
            @nMobile       , 
            @nFunc         , 
            @cUserName     , 
            @cStorerKey    , 
            @cID           , 
            ''     , 
            'C'            , 
            'Y'            , 
            '9'            ,
            ''             , 
            ''             ,
            'N'            ,
            @cLangCode     , 
            @nErrorNo        OUTPUT, 
            @cErrorMsg       OUTPUT 

         IF @nErrorNo <> 0
         BEGIN
            SET @nErrNo = @nErrorNo
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Ins QCLOG Fail
            
            SET @cCartonID = ''
            SET @cOption = ''
            
            SET @cOutField02 = ''
            SET @cOutField03 = ''

            EXEC rdt.rdtSetFocusField @nMobile, 2
            
            GOTO Quit
         END

         SET @cOutField01 = ''

         SET @nPrevScn = @nScn
         SET @nPrevStep = @nStep

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO Quit
      END

      IF ISNULL(@cOutField06, '') = ''
      BEGIN
         SET @nErrNo = 76591
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --No more rec
         GOTO Step_7_Fail
      END
      
      -- Get the current scan no to determine which batch of audit should use
      SET @nScanNo = 0
      SELECT @nScanNo =  MAX( ScanNo) FROM rdt.rdtQCLog QC WITH (NOLOCK)
      WHERE QC.StorerKey = @cStorerKey
         AND QC.PalletID = @cID

      SET @nCnt = 1
      -- Log all missing cartons to the RDTQCLOG table
      DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT DISTINCT CartonID
      FROM rdt.rdtQCLog WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PalletID = @cID
         AND CartonID > @cOutField06
         AND ScanNo = @nScanNo
         --AND Status = '5'   (james01)
         AND MissingCtn = 'Y'
         AND TranType = 'C'
      ORDER BY CartonID
      OPEN CUR_LOOP
      FETCH NEXT FROM CUR_LOOP INTO @cCartonID 
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @nCnt > 5
            BREAK
         IF @nCnt = 1
            SET @cMissingCtn01 = @cCartonID
         IF @nCnt = 2
            SET @cMissingCtn02 = @cCartonID
         IF @nCnt = 3
            SET @cMissingCtn03 = @cCartonID
         IF @nCnt = 4
            SET @cMissingCtn04 = @cCartonID
         IF @nCnt = 5
            SET @cMissingCtn05 = @cCartonID

         SET @nCnt = @nCnt + 1
         
         FETCH NEXT FROM CUR_LOOP INTO @cCartonID
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP

      IF ISNULL(@cMissingCtn01, '') <> ''
      BEGIN
         -- Clear prev screen variables
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''
         SET @cOutField07 = ''
            
         SET @nCurPageCnt = @nCurPageCnt + 1
         
         -- Prepare next screen variable
         SET @cOutField01 = RTRIM(CAST(@nCurPageCnt AS NVARCHAR(2))) + '/' + LTRIM(CAST(@nTtlPageCnt AS NVARCHAR(2)))
         SET @cOutField02 = @cMissingCtn01
         SET @cOutField03 = @cMissingCtn02
         SET @cOutField04 = @cMissingCtn03
         SET @cOutField05 = @cMissingCtn04
         SET @cOutField06 = @cMissingCtn05
         
         GOTO Quit
      END
      ELSE
      BEGIN
         SET @nErrNo = 76591
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --No more rec
         GOTO Step_7_Fail
      END
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN UPD_DROPID
      /*
      -- If Pallet is not at Staging Lane or Pack & Hold Location (DropID.Status < 3 and < 5) and OPT = Blank
      IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                 WHERE DropID = @cID
                 --AND LoadKey = @cLoadKey
                 AND DropIDType = 'PALLET'
                 --AND Status NOT IN ('1', '3', '5'))
                 AND Status <> '1')
      BEGIN
         UPDATE dbo.DROPID WITH (ROWLOCK) SET 
            Status = '1'   -- Audit fail
         WHERE DropID = @cID
            --AND LoadKey = @cLoadKey
            AND DropIDType = 'PALLET'
            --AND Status NOT IN ('1', '3', '5')   -- 1=audit fail; 3=packnhold; 5=staged
            AND Status <> '1'
            
         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN UPD_DROPID
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN
            SET @nErrNo = 76585
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Upd Dropid Fail
            GOTO Quit
         END
      END
      */
      UPDATE rdt.rdtQCLog WITH (ROWLOCK) SET 
         Completed = 'Y', 
         [STATUS] = '5',    -- Audit failed (james01)
         Notes = CASE WHEN TranType = 'P' THEN 'AUDIT FAIL' ELSE Notes END 
      WHERE StorerKey = @cStorerKey
         AND PalletID = @cID
         AND Completed = 'N'

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN UPD_DROPID
         WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN
         SET @nErrNo = 76596
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Upd QCLog Fail
         GOTO Quit
      END

      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN      
            
      SET @cOption = ''
      SET @cOutField01 = ''
      
      SET @nScn = @nScn - 6
      SET @nStep = @nStep - 6
   END
   GOTO Quit
   
   Step_7_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField07 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 8. screen = 3147
   TRIAGE LOC (field01, input)
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cLOC = @cInField01
      
      IF ISNULL(@cLOC, '') = ''
      BEGIN
         SET @nErrNo = 76587
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Triage Loc Req
         GOTO Step_8_Fail
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cLOC)
      BEGIN
         SET @nErrNo = 76588
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Inv Triage Loc 
         GOTO Step_8_Fail
      END
      
      SELECT @cLOC_Facility = Facility 
      FROM dbo.LOC WITH (NOLOCK) 
      WHERE LOC = @cLOC
      
      IF ISNULL(@cFacility, '') <> ISNULL(@cLOC_Facility, '')
      BEGIN
         SET @nErrNo = 76589 
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Diff fac
         GOTO Step_8_Fail
      END
      
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN UPD_DROPID
      
      UPDATE dbo.DROPID WITH (ROWLOCK) SET 
      /* -- (james01)
         Status = CASE WHEN Status < '1' THEN '1'
                       ELSE Status END,   -- Audit fail
      */
         DropLoc = @cLOC 
      WHERE DropID = @cID
         --AND LoadKey = @cLoadKey
         --AND DropIDType = 'PALLET'
      
      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN UPD_DROPID
         WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN
         SET @nErrNo = 76585
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Upd Dropid Fail
         GOTO Quit
      END

      -- Complete the pallet audit
      UPDATE rdt.rdtQCLog WITH (ROWLOCK) SET 
         Completed = 'Y', 
         [STATUS] = '5',       -- Audit failed (james01)
         Notes = CASE WHEN TranType = 'P' THEN 'AUDIT FAIL' ELSE Notes END 
      WHERE StorerKey = @cStorerKey
         AND PalletID = @cID
         AND Completed = 'N'

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN UPD_DROPID
         WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN
         SET @nErrNo = 76597
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Upd QCLog Fail
         GOTO Quit
      END
      
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN     

      SET @nErrNo = 0
      SET @cErrMsg1 = 'PALLET SUCCESSFULLY'
      SET @cErrMsg2 = 'MOVE TO TRIAGE LOC'
      SET @cErrMsg3 = @cLOC
      SET @cErrMsg4 = ''
      SET @cErrMsg5 = ''
      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
         @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
      IF @nErrNo = 1
      BEGIN
         SET @cNotes = ISNULL(RTRIM(@cErrMsg1), '') + ' ' + ISNULL(RTRIM(@cErrMsg2), '') + ' ' + ISNULL(RTRIM(@cErrMsg3), '')
         SET @cNotes = RTRIM(@cNotes) + ' ' + ISNULL(RTRIM(@cErrMsg4), '') + ' ' + ISNULL(RTRIM(@cErrMsg5), '') 
         SET @cErrMsg1 = ''
         SET @cErrMsg2 = ''
         SET @cErrMsg3 = ''
         SET @cErrMsg4 = ''
         SET @cErrMsg5 = ''
      END

      SET @cOption = ''
      SET @cOutField01 = ''
      
      SET @nScn = @nScn - 7
      SET @nStep = @nStep - 7
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF ISNULL(@nPrevStep, 0) = 3
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField02 = ''

         SET @cOption = ''
         SET @cLoadKey = ''
         
         EXEC rdt.rdtSetFocusField @nMobile, 1

         SET @nScn = @nPrevScn
         SET @nStep = @nPrevStep
         
         GOTO Quit
      END
      
      IF ISNULL(@nPrevStep, 0) = 4
      BEGIN
         SET @cOutField01 = @cID
         SET @cOutField02 = ''
         SET @cOutField03 = ''

         EXEC rdt.rdtSetFocusField @nMobile, 1

         SET @nScn = @nPrevScn
         SET @nStep = @nPrevStep
         
         GOTO Quit
      END
      ELSE
      BEGIN
         SET @cOption = ''
         SET @cOutField01 = ''
      
         SET @nScn = @nScn - 7
         SET @nStep = @nStep - 7
      END
   END
   GOTO Quit
      
   Step_8_Fail:
   BEGIN
      SET @cLOC = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 9. screen = 3148
   MESSAGE (field01, input)
********************************************************************************/
Step_9:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Get the last scan no
      SET @nLastScanNo = 0
      SELECT TOP 1 
         @nLastScanNo = ScanNo 
      FROM rdt.rdtQCLog WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND PalletID = @cID
         AND TranType = 'P'
         AND Completed = 'Y'
      ORDER BY SeqNo DESC

      SET @nCnt = 1
      -- Log all missing cartons to the RDTQCLOG table
      DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT DISTINCT CartonID 
      FROM rdt.rdtQCLog WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PalletID = @cID
         AND ScanNo = @nLastScanNo
         AND CartonID > @cOutField09
         --AND Status = '5'   (james01)
         AND MissingCtn = 'Y'
      ORDER BY CartonID
      OPEN CUR_LOOP
      FETCH NEXT FROM CUR_LOOP INTO @cCartonID
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @nCnt > 8
            BREAK
         IF @nCnt = 1
            SET @cMissingCtn01 = @cCartonID
         IF @nCnt = 2
            SET @cMissingCtn02 = @cCartonID
         IF @nCnt = 3
            SET @cMissingCtn03 = @cCartonID
         IF @nCnt = 4
            SET @cMissingCtn04 = @cCartonID
         IF @nCnt = 5
            SET @cMissingCtn05 = @cCartonID
         IF @nCnt = 6
            SET @cMissingCtn06 = @cCartonID
         IF @nCnt = 7
            SET @cMissingCtn07 = @cCartonID
         IF @nCnt = 8
            SET @cMissingCtn08 = @cCartonID
            
         SET @nCnt = @nCnt + 1
         
         FETCH NEXT FROM CUR_LOOP INTO @cCartonID
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP

      IF ISNULL(@cMissingCtn01, '') <> ''
      BEGIN
         -- Clear prev screen variables
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         
         SET @nCurPageCnt = @nCurPageCnt + 1
         -- Prepare next screen variable
         SET @cOutField01 = RTRIM(CAST(@nCurPageCnt AS NVARCHAR(2))) + '/' + LTRIM(CAST(@nTtlPageCnt AS NVARCHAR(2)))
         SET @cOutField02 = @cMissingCtn01
         SET @cOutField03 = @cMissingCtn02
         SET @cOutField04 = @cMissingCtn03
         SET @cOutField05 = @cMissingCtn04
         SET @cOutField06 = @cMissingCtn05
         SET @cOutField07 = @cMissingCtn06
         SET @cOutField08 = @cMissingCtn07
         SET @cOutField09 = @cMissingCtn08
         
         GOTO Quit
      END
      ELSE
      BEGIN
         SET @nErrNo = 76592
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --No more rec
         GOTO Step_9_Fail
      END
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = ''
      
      SET @nScn = @nScn - 8
      SET @nStep = @nStep - 8
   END
   GOTO Quit
   
   Step_9_Fail:

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
       Printer_Paper = @cPrinter_Paper,
       -- UserName      = @cUserName,

       V_ID          = @cID,
       V_LoadKey     = @cLoadKey, 
       
       V_FromScn     = @nPrevScn,
       V_FromStep    = @nPrevStep,
   
       V_Integer1    = @ErrMsgNextScreen,
       V_Integer2    = @nCurPageCnt,
       V_Integer3    = @nTtlPageCnt,
       V_Integer4    = @cMinPltShipDate,
       V_Integer5    = @cCheckWeightLess1lb,
   
       V_String1     = @cOption,
       --V_String2     = @ErrMsgNextScreen, 
       --V_String3     = @nCurPageCnt, 
       --V_String4     = @nTtlPageCnt, 
       --V_String5     = @cMinPltShipDate, 
       --V_String6     = @nPrevScn,
       --V_String7     = @nPrevStep,
       --V_String8     = @cCheckWeightLess1lb, 
       V_String9     = @cPalletRegExp,  
       V_String10    = @cCartonIDRegExp, 
       
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