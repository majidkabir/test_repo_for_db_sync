SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_TrackNo_SortToPallet_CloseLane               */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Sort trackno to pallet close lane                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2022-09-15   1.0  James    WMS-20667. Created                        */
/* 2022-12-01   1.1  AAY      Auto MBOL Patch                           */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_TrackNo_SortToPallet_CloseLane] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(125) OUTPUT
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- RDT.RDTMobRec variable
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @nAfterStep  INT,
   @cLangCode   NVARCHAR( 3),
   @nInputKey   INT,
   @nMenu       INT,
   @nMorePage   INT,
   @bSuccess    INT,
   @nTranCount  INT,

   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cSKU        NVARCHAR( 20),
   @cUserName           NVARCHAR( 18),
   @cOrderKey           NVARCHAR( 10),
   @cSQL                NVARCHAR( MAX),
   @cSQLParam           NVARCHAR( MAX),

   @cExtendedInfo       NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @tExtValidVar        VariableTable,
   @tExtUpdateVar       VariableTable,
   @tExtInfoVar         VariableTable,
   @tSplitMBOLVar       VariableTable,
   @cMBOLKey            NVARCHAR( 10),
   @cOption             NVARCHAR( 1),
   @cPalletLineNumber   NVARCHAR( 5),
   @nQty_Picked         INT,
   @nQty_Packed         INT,
   @cLane               NVARCHAR( 20),
   @bReturnCode         INT = 0,
   @cStatus             NVARCHAR( 10),
   @cErrMsg1            NVARCHAR( 20),
   @cErrMsg2            NVARCHAR( 20),
   @cErrMsg3            NVARCHAR( 20),
   @cErrMsg4            NVARCHAR( 20),
   @cErrMsg5            NVARCHAR( 20),
   @cCloseLaneSplitMbol NVARCHAR( 1),
   @nHasFullScannedOrder   INT,
   @nHasPickedPackedOrder  INT,
   
   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),    @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),    @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),    @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),    @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),    @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),    @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),    @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),    @cFieldAttr08 NVARCHAR( 1),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),    @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),    @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),    @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),    @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),    @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),    @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),    @cFieldAttr15 NVARCHAR( 1)

-- Getting Mobile information
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
   @cOrderKey   = V_OrderKey,

   @cMBOLKey               = V_String1,
   @cLane                  = V_String2,
   @cExtendedInfoSP        = V_String3,
   @cExtendedValidateSP    = V_String4,
   @cExtendedUpdateSP      = V_String5,
   @cCloseLaneSplitMbol    = V_String6,
   
   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01 = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02 = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03 = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04 = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05 = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06 = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07 = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08 = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09 = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10 = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11 = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12 = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13 = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14 = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15 = FieldAttr15

FROM rdt.RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_CloseLane        INT,  @nScn_CloseLane          INT,
   @nStep_ConfirmClose     INT,  @nScn_ConfirmClose       INT,
   @nStep_Message          INT,  @nScn_Message            INT,
   @nStep_SplitLane        INT,  @nScn_SplitLane          INT,
   @nStep_CloseNewLane     INT,  @nScn_CloseNewLane       INT

SELECT
   @nStep_CloseLane        = 1,   @nScn_CloseLane        = 6130,
   @nStep_ConfirmClose     = 2,   @nScn_ConfirmClose     = 6131,
   @nStep_Message          = 3,   @nScn_Message          = 6132,
   @nStep_SplitLane        = 4,   @nScn_SplitLane        = 6133,
   @nStep_CloseNewLane     = 5,   @nScn_CloseNewLane     = 6134


IF @nFunc = 1654 -- TrackNo Sort To Pallet Close Lane
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0
   IF @nStep = 1 GOTO Step_CloseLane         -- Scn = 6130. CLOSE LANE
   IF @nStep = 2 GOTO Step_ConfirmClose      -- Scn = 6131. OPTION
   IF @nStep = 3 GOTO Step_Message           -- Scn = 6132. MESSAGE
   IF @nStep = 4 GOTO Step_SplitLane         -- Scn = 6133. SPLIT LANE
   IF @nStep = 5 GOTO Step_CloseNewLane      -- Scn = 6134. CLOSE NEW LANE
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1654. Menu
********************************************************************************/
Step_0:
BEGIN
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerkey)
   IF @cExtendedInfoSP IN ('0', '')
      SET @cExtendedInfoSP = ''

   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerkey)
   IF @cExtendedValidateSP IN ('0', '')
      SET @cExtendedValidateSP = ''

   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerkey)
   IF @cExtendedUpdateSP IN ('0', '')
      SET @cExtendedUpdateSP = ''

   SET @cCloseLaneSplitMbol = rdt.RDTGetConfig( @nFunc, 'CloseLaneSplitMbol', @cStorerkey)
      
   -- Initialize value
   SET @cLane = ''

   -- Prep next screen var
   SET @cOutField01 = '' -- Track No

   SET @nScn = @nScn_CloseLane
   SET @nStep = @nStep_CloseLane

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 6130
   LANE    (field01, input)
********************************************************************************/
Step_CloseLane:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cLane = @cInField01

      IF ISNULL( @cLane, '') = ''
      BEGIN
         SET @nErrNo = 191251
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Lane
         GOTO Step_CloseLane_Fail
      END

      SELECT 
         @cMBOLKey = MbolKey,
         @cStatus = [Status]
      FROM dbo.MBOL WITH (NOLOCK)
      WHERE ExternMbolKey = @cLane
      
      IF @@ROWCOUNT = 0
      BEGIN 
         SET @nErrNo = 191261
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lane
         GOTO Step_CloseLane_Fail
      END 
      
      IF @cStatus >= '5'
      BEGIN 
         SET @nErrNo = 191263
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lane Closed
         GOTO Step_CloseLane_Fail
      END 

      -- User chooses to close lane (FN1654), at this point there could be:
      --	Not all cartons are scanned to the lane, OR
      --	Not all orders are fully packed. 
      --	Hence, user can still close the lane because multiple lanes will get clogged up 
      --	if they are not allowed to do so, while more and more orders are packed. In that case, split MBOL when closing lane. 
      IF @cCloseLaneSplitMbol = '1'
      BEGIN
         SET @nHasFullScannedOrder = 0
         SELECT @nHasFullScannedOrder = 1 
         FROM dbo.MBOL M WITH (NOLOCK)  
         JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON ( MD.MBOLKey = M.MBOLKey)  
         OUTER APPLY (  
             SELECT LabelNo, CaseID, PD.StorerKey 
             FROM PackDetail PD WITH (NOLOCK)  
             JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PH.PickSlipNo = PD.PickSlipNo)   
             LEFT JOIN dbo.PalletDetail PLD WITH (NOLOCK) ON   
                 ( PLD.CaseID = PD.LabelNo AND PLD.StorerKey = PD.StorerKey AND   
                 PLD.UserDefine01 = PH.OrderKey AND PLD.UserDefine03 = M.ExternMBOLKey)  
             WHERE PH.OrderKey = MD.OrderKey  
         ) PLD  
         WHERE M.ExternMBOLKey = @cLane
         AND   PLD.StorerKey = @cStorerKey
         GROUP BY MD.OrderKey 
         HAVING COUNT(DISTINCT PLD.LabelNo) = COUNT(DISTINCT PLD.CaseID)

         SET @nHasPickedPackedOrder = 0
         SELECT @nHasPickedPackedOrder = 1 
         FROM dbo.MBOL M WITH (NOLOCK)  
         JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON ( MD.MBOLKey = M.MBOLKey)  
         JOIN dbo.Orders O WITH (NOLOCK) ON ( O.OrderKey = MD.OrderKey AND O.MBOLKey = M.MBOLKey)
         WHERE M.ExternMBOLKey = @cLane
         AND   StorerKey = @cStorerKey
         AND   O.Status = '5'

         IF @nHasFullScannedOrder = 1 AND @nHasPickedPackedOrder = 1 AND
            EXISTS ( SELECT 1
                     FROM dbo.MBOL M WITH (NOLOCK)    
                     JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON ( MD.MBOLKey = M.MBOLKey)    
                     JOIN dbo.Orders O WITH (NOLOCK) ON ( O.OrderKey = MD.OrderKey AND O.MBOLKey = M.MBOLKey)  
                     WHERE M.ExternMBOLKey = @cLane  
                     AND   StorerKey = @cStorerKey  
                     AND   O.Status < '5')  
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = ''   -- Option
         
            -- Goto scan pallet screen
            SET @nScn  = @nScn_SplitLane
            SET @nStep = @nStep_SplitLane
            
            GOTO Quit
         END

      END
      
      IF EXISTS ( SELECT 1 
                  FROM dbo.PALLETDETAIL PD WITH (NOLOCK)
                  JOIN dbo.PALLET P WITH (NOLOCK) ON ( PD.PalletKey = P.PalletKey)
                  WHERE PD.StorerKey = @cStorerKey
                  AND   PD.UserDefine03 = @cLane
                  AND   P.Status = '0')
      BEGIN 
         SET @nErrNo = 191252
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LaneHasOpenPlt
         GOTO Step_CloseLane_Fail
      END 

      IF EXISTS ( SELECT 1 FROM dbo.ORDERS O WITH (NOLOCK)
                  JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON ( O.MBOLKey = MD.MbolKey)
                  JOIN dbo.MBOL M WITH (NOLOCK) ON ( MD.MbolKey = M.MbolKey)
                  WHERE M.ExternMbolKey = @cLane
                  AND   O.StorerKey <> @cStorerKey)
      BEGIN 
         SET @nErrNo = 191262
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Other Storer
         GOTO Step_CloseLane_Fail
      END 
      
      SET @nQty_Picked = 0
      SET @nQty_Packed = 0
      SELECT @nQty_Picked = ISNULL( SUM( PD.Qty), 0) 
      FROM dbo.PICKDETAIL PD WITH (NOLOCK)
      JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)
      WHERE O.StorerKey = @cStorerKey
      AND   O.MBOLKey = @cMBOLKey
 
      SELECT @nQty_Packed = ISNULL( SUM( PD.Qty), 0) 
      FROM dbo.PackDetail PD WITH (NOLOCK)
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo) 
      JOIN dbo.Orders O WITH (NOLOCK) ON ( PH.OrderKey = O.OrderKey)
      WHERE O.StorerKey = @cStorerKey
      AND   O.MBOLKey = @cMBOLKey
 
      IF @nQty_Picked <> @nQty_Packed
      BEGIN 
         SET @nErrNo = 191253
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PickPackXMatch
         GOTO Step_CloseLane_Fail
      END 

      IF EXISTS (
          SELECT 1 FROM dbo.MBOL M WITH (NOLOCK)
          JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON ( MD.MBOLKey = M.MBOLKey)
          OUTER APPLY (
              SELECT LabelNo, CaseID, PD.StorerKey FROM PackDetail PD (NOLOCK)
              JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo 
              LEFT JOIN dbo.PalletDetail PLD WITH (NOLOCK) ON 
               ( PLD.CaseID = PD.LabelNo AND PLD.StorerKey = PD.StorerKey AND 
               PLD.UserDefine01 = PH.OrderKey AND PLD.UserDefine03 = M.ExternMBOLKey)
              WHERE PH.OrderKey = MD.OrderKey
          ) PLD
          WHERE M.ExternMBOLKey = @cLane
          AND StorerKey = @cStorerKey
          AND ISNULL( PLD.CaseID, '') = '' 
      )
      BEGIN
         SET @cErrMsg1 = rdt.rdtgetmessage( 191258, @cLangCode, 'DSP') --Not All Cartons
         SET @cErrMsg2 = rdt.rdtgetmessage( 191259, @cLangCode, 'DSP') --Are Scanned To Lane
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
         END   

         SET @nErrNo = 191260
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not All Scan
         GOTO Step_CloseLane_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cLane, @cOption, @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cLane          NVARCHAR( 20), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtValidVar   VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cLane, @cOption, @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_CloseLane_Fail
         END
      END


   	SET @cOption = ''

      -- Prep next screen var
      SET @cOutField01 = @cLane
      SET @cOutField02 = ''
         
      -- Goto scan pallet screen
      SET @nScn  = @nScn_ConfirmClose
      SET @nStep = @nStep_ConfirmClose
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-Out
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_CloseLane_Fail:
   BEGIN
      SET @cLane = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 6131.
   LANE           (field01)
   OPTION         (field02, input)
********************************************************************************/
Step_ConfirmClose:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Initialize value
      SET @cOption = @cInField02

      IF ISNULL( @cOption, '') = ''
      BEGIN
         SET @nErrNo = 191254
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option
         GOTO Step_ConfirmClose_Fail
      END

      IF @cOption NOT IN ( '1', '2')
      BEGIN
         SET @nErrNo = 191255
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_ConfirmClose_Fail
      END
      
      IF @cOption = '2'
      BEGIN
         -- Initialize value
         SET @cLane = ''

         -- Prep next screen var
         SET @cOutField01 = '' -- Track No

         SET @nScn = @nScn_CloseLane
         SET @nStep = @nStep_CloseLane
         
         GOTO Quit
      END
      
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cLane, @cOption, @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cLane          NVARCHAR( 20), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtValidVar   VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cLane, @cOption, @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_ConfirmClose_Fail
         END
      END

      -- Put this outside of tran block
      -- in order to insert record into MBOLErrorReport
      -- (rollback will not insert record)
      SET @bReturnCode = 0
      EXEC [dbo].[isp_ValidateMBOL]            
           @c_MBOLKey = @cMBOLKey,            
           @b_ReturnCode = @bReturnCode  OUTPUT, 
           @n_err        = @nErrNo       OUTPUT,            
           @c_errmsg     = @cErrMsg      OUTPUT,     
           @n_CBOLKey    = 0,        
           @c_CallFrom   = ''  

      IF @bReturnCode <> 0  
      BEGIN          
         SET @nErrNo = 191256          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ValidateMBOLEr      
         GOTO Step_ConfirmClose_Fail    
      END   

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_ShipMbol -- For rollback or commit only our own transaction

      UPDATE dbo.Mbol SET     
         [Status] = '7',     
         ValidatedFlag = 'Y',    
         EditDate = GETDATE(),    
         EditWho = SUSER_SNAME()    
      WHERE MbolKey = @cMBOLKey    
      AND Status <= '5' -- AAY Auto MBOL Patch 2022-12-01  
                    
      IF @@ERROR <> 0  
      BEGIN          
         SET @nErrNo = 191257          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL Ship Fail      
         GOTO RollBackTran_ShipMbol    
      END   
                  
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cLane, @cOption, @tExtUpdateVar, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cLane          NVARCHAR( 20), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtUpdateVar  VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cLane, @cOption, @tExtUpdateVar,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO RollBackTran_ShipMbol
         END
      END
      
      COMMIT TRAN rdt_ShipMbol

      GOTO Commit_ShipMbol

      RollBackTran_ShipMbol:
         ROLLBACK TRAN rdt_ShipMbol -- Only rollback change made here
      Commit_ShipMbol:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

      IF @nErrNo <> 0
         GOTO Quit

      SET @cOutField01 = @cLane

      SET @nScn = @nScn_Message
      SET @nStep = @nStep_Message
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Initialize value
      SET @cLane = ''

      -- Prep next screen var
      SET @cOutField01 = '' -- Track No

      SET @nScn = @nScn_CloseLane
      SET @nStep = @nStep_CloseLane
   END

   GOTO Quit

   Step_ConfirmClose_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = @cLane
      SET @cOutField02 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 3. Scn = 6132.
   MESSAGE
********************************************************************************/
Step_Message:
BEGIN
   IF @nInputKey IN ( 0, 1) -- ENTER or ESC
   BEGIN
      -- Initialize value
      SET @cLane = ''

      -- Prep next screen var
      SET @cOutField01 = '' -- Track No

      SET @nScn = @nScn_CloseLane
      SET @nStep = @nStep_CloseLane
   END
END
GOTO Quit

/********************************************************************************
Step 4. Scn = 6133.
   LANE           (field01)
   OPTION         (field02, input)
********************************************************************************/
Step_SplitLane:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Initialize value
      SET @cOption = @cInField01

      IF ISNULL( @cOption, '') = ''
      BEGIN
         SET @nErrNo = 191264
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option
         GOTO Step_SplitLane_Fail
      END

      IF @cOption NOT IN ( '1', '2')
      BEGIN
         SET @nErrNo = 191265
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_SplitLane_Fail
      END
      
      IF @cOption = '2'
      BEGIN
         -- Initialize value
         SET @cLane = ''

         -- Prep next screen var
         SET @cOutField01 = '' -- Track No

         SET @nScn = @nScn_CloseLane
         SET @nStep = @nStep_CloseLane
         
         GOTO Quit
      END
      
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cLane, @cOption, @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cLane          NVARCHAR( 20), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtValidVar   VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cLane, @cOption, @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_SplitLane_Fail
         END
      END

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_SplitMbol -- For rollback or commit only our own transaction

      SET @nErrNo = 0
      EXEC [RDT].[rdt_TrackNo_SortToPallet_SplitMbol]
         @nMobile       = @nMobile,
         @nFunc         = @nFunc,
         @cLangCode     = @cLangCode,
         @nStep         = @nStep,
         @nInputKey     = @nInputKey,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerKey,
         @cLane         = @cLane OUTPUT,
         @tSplitMBOLVar = @tSplitMBOLVar,
         @nErrNo        = @nErrNo      OUTPUT,
         @cErrMsg       = @cErrMsg     OUTPUT

      IF @nErrNo <> 0
         GOTO RollBackTran_SplitMbol

      IF ISNULL( @cLane, '') = ''
      BEGIN
         SET @nErrNo = 191272
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Split Lane Fail
         GOTO RollBackTran_SplitMbol
      END
      
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cLane, @cOption, @tExtUpdateVar, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cLane          NVARCHAR( 20), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtUpdateVar  VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cLane, @cOption, @tExtUpdateVar,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO RollBackTran_SplitMbol
         END
      END
      
      COMMIT TRAN rdt_SplitMbol

      GOTO Commit_SplitMbol

      RollBackTran_SplitMbol:
         ROLLBACK TRAN rdt_SplitMbol -- Only rollback change made here
      Commit_SplitMbol:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

      IF @nErrNo <> 0
         GOTO Quit

      SELECT 
         @cMBOLKey = MbolKey
      FROM dbo.MBOL WITH (NOLOCK)
      WHERE ExternMbolKey = @cLane
      
      SET @cOutField01 = @cLane
      SET @cOutField02 = ''

      SET @nScn = @nScn_CloseNewLane
      SET @nStep = @nStep_CloseNewLane
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Initialize value
      SET @cLane = ''

      -- Prep next screen var
      SET @cOutField01 = '' -- Track No

      SET @nScn = @nScn_CloseLane
      SET @nStep = @nStep_CloseLane
   END

   GOTO Quit

   Step_SplitLane_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 5. Scn = 6134.
   LANE           (field01)
   OPTION         (field02, input)
********************************************************************************/
Step_CloseNewLane:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Initialize value
      SET @cOption = @cInField02

      IF ISNULL( @cOption, '') = ''
      BEGIN
         SET @nErrNo = 191266
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option
         GOTO Step_CloseNewLane_Fail
      END

      IF @cOption NOT IN ( '1', '2')
      BEGIN
         SET @nErrNo = 191267
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_CloseNewLane_Fail
      END
      
      IF @cOption = '2'
      BEGIN
         -- Initialize value
         SET @cLane = ''

         -- Prep next screen var
         SET @cOutField01 = '' -- Track No

         SET @nScn = @nScn_CloseLane
         SET @nStep = @nStep_CloseLane
         
         GOTO Quit
      END
      
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cLane, @cOption, @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cLane          NVARCHAR( 20), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtValidVar   VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cLane, @cOption, @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_CloseNewLane_Fail
         END
      END

      -- Put this outside of tran block
      -- in order to insert record into MBOLErrorReport
      -- (rollback will not insert record)
      SET @bReturnCode = 0
      EXEC [dbo].[isp_ValidateMBOL]            
           @c_MBOLKey = @cMBOLKey,            
           @b_ReturnCode = @bReturnCode  OUTPUT, 
           @n_err        = @nErrNo       OUTPUT,            
           @c_errmsg     = @cErrMsg      OUTPUT,     
           @n_CBOLKey    = 0,        
           @c_CallFrom   = ''  

      IF @bReturnCode <> 0  
      BEGIN          
         SET @nErrNo = 191268          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ValidateMBOLEr      
         GOTO Step_CloseNewLane_Fail    
      END   

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_ShipNewMbol -- For rollback or commit only our own transaction

      UPDATE dbo.Mbol SET     
         [Status] = '7',     
         ValidatedFlag = 'Y',    
         EditDate = GETDATE(),    
         EditWho = SUSER_SNAME()    
      WHERE MbolKey = @cMBOLKey    
      AND Status <= '5' -- AAY Auto MBOL Patch 2022-12-01  
                    
      IF @@ERROR <> 0  
      BEGIN          
         SET @nErrNo = 191269          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL Ship Fail      
         GOTO RollBackTran_ShipNewMbol    
      END   
                  
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cLane, @cOption, @tExtUpdateVar, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cLane          NVARCHAR( 20), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtUpdateVar  VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cLane, @cOption, @tExtUpdateVar,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO RollBackTran_ShipNewMbol
         END
      END
      
      COMMIT TRAN rdt_ShipNewMbol

      GOTO Commit_ShipNewMbol

      RollBackTran_ShipNewMbol:
         ROLLBACK TRAN rdt_ShipNewMbol -- Only rollback change made here
      Commit_ShipNewMbol:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

      IF @nErrNo <> 0
         GOTO Quit

      SET @cOutField01 = @cLane
      SET @cOutField02 = rdt.rdtgetmessage( 191270, @cLangCode, 'DSP') -- PLS ALSO COMPLETE 
      SET @cOutField03 = rdt.rdtgetmessage( 191271, @cLangCode, 'DSP') -- THE REMAINING IN 
      SET @cOutField04 = SUBSTRING( @cLane, 1, CHARINDEX('|', @cLane) - 1) -- Previous Lane

      SET @nScn = @nScn_Message
      SET @nStep = @nStep_Message
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Initialize value
      SET @cLane = ''

      -- Prep next screen var
      SET @cOutField01 = '' -- Track No

      SET @nScn = @nScn_CloseLane
      SET @nStep = @nStep_CloseLane
   END

   GOTO Quit

   Step_CloseNewLane_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField02 = ''
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility,
      UserName  = @cUserName,
      V_OrderKey= @cOrderKey,

      V_String1   = @cMBOLKey,
      V_String2   = @cLane,
      
      V_String3 = @cExtendedInfoSP,
      V_String4 = @cExtendedValidateSP,
      V_String5 = @cExtendedUpdateSP,
      V_String6 = @cCloseLaneSplitMbol,
         
      I_Field01 = @cInField01,  O_Field01 = @cOutField01, FieldAttr01  = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02, FieldAttr02  = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03, FieldAttr03  = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04, FieldAttr04  = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05, FieldAttr05  = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06, FieldAttr06  = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07, FieldAttr07  = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08, FieldAttr08  = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09, FieldAttr09  = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10, FieldAttr10  = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11, FieldAttr11  = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12, FieldAttr12  = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13, FieldAttr13  = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14, FieldAttr14  = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15, FieldAttr15  = @cFieldAttr15
   WHERE Mobile = @nMobile
END

GO