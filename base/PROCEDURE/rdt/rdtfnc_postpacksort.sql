SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdtfnc_PostPackSort                                    */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose: Post pack sort                                                 */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date         Rev  Author   Purposes                                     */
/* 2019-09-25   1.0  James    WMS-10316 Created                            */
/*                            Bug fix. Prevent user book loc               */
/*                            unintentionally (james01)                    */
/* 2020-04-08   1.1  James    WMS-12735 Add ExtendedUpdateSP (james02)     */
/* 2020-10-27   1.2  LZG      INC1335308 - Fixed rollback tran (ZG01)      */
/* 2021-07-10   1.3  Chermain WMS-17386 Add display Msg screen             */
/*                            Add ExtInfo in scn1 (cc01)                   */
/* 2022-01-13   1.4  James    WMS-17386 Modify message screen. Set field11 */
/*                            as default output ExtendedInfo (james03)     */
/* 2022-01-13   1.5  James    WMS-18506 Add ExtUpdSP to close plt (james04)*/
/***************************************************************************/

CREATE   PROC [RDT].[rdtfnc_PostPackSort](
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE 
   @cSQL           NVARCHAR(MAX), 
   @cSQLParam      NVARCHAR(MAX)

-- RDT.RDTMobRec variables
DECLARE
   @nFunc          INT,
   @nScn           INT,
   @nStep          INT,
   @cLangCode      NVARCHAR( 3),
   @nInputKey      INT,
   @nMenu          INT,

   @cStorerKey     NVARCHAR( 15),
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5),
   @cLabelPrinter  NVARCHAR( 10),
   @cPaperPrinter  NVARCHAR( 10),

   @cDecodeSP           NVARCHAR( 20), 
   @cExtendedInfo       NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cBarcode            NVARCHAR( Max), 
   @cOption             NVARCHAR( 1), 
   @cPickConfirmStatus  NVARCHAR( 1),
   @cDefaultWeight      NVARCHAR( 1),  
   @tExtValidate        VariableTable, 
   @tExtUpdate          VariableTable, 
   @tExtInfo            VariableTable, 
   @tClosePallet        VariableTable, 
   @tPostPackSortCfm    VariableTable, 
   @cCartonID           NVARCHAR( 20),
   @cPalletID           NVARCHAR( 20),
   @nNoOfCheck          INT,
   @cLoadKey            NVARCHAR( 10),
   @cOrderKey           NVARCHAR( 10),
   @cPPS_Loc            NVARCHAR( 10),
   @cPickDetailCartonID NVARCHAR( 20),
   @nTranCount          INT,
   @nRowCount           INT,
   @cCheckOrderMustPickComplete  NVARCHAR( 1),
   
   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),  @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),  @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),  @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),  @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),  @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),  @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),  @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),  @cFieldAttr08 NVARCHAR( 1), 
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),  @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),  @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),  @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),  @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),  @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),  @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),  @cFieldAttr15 NVARCHAR( 1)

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cLabelPrinter    = Printer,
   @cPaperPrinter    = Printer_Paper, 

   @cLoadKey         = V_LoadKey,
   @cPPS_Loc         = V_Loc,

   @cExtendedUpdateSP   = V_String1,
   @cExtendedValidateSP = V_String2,
   @cExtendedInfoSP     = V_String3,
   @cCartonID           = V_String4,
   @cPalletID           = V_String5,
   @cPickDetailCartonID = V_String6,
   @cPickConfirmStatus  = V_String7,
   @cCheckOrderMustPickComplete = V_String8,

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
   
FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_FromCarton    INT,  @nScn_FromCarton     INT,
   @nStep_ToPallet      INT,  @nScn_ToPallet       INT,
   @nStep_ClosePallet   INT,  @nScn_ClosePallet    INT,
   @nStep_Message       INT,  @nScn_Message        INT

SELECT
   @nStep_FromCarton  = 1,  @nScn_FromCarton   = 5590,
   @nStep_ToPallet    = 2,  @nScn_ToPallet     = 5591,
   @nStep_ClosePallet = 3,  @nScn_ClosePallet  = 5592,
   @nStep_Message     = 4,  @nScn_Message      = 5593

IF @nFunc = 1837
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start         -- Menu. Func = 1837
   IF @nStep = 1  GOTO Step_FromCarton    -- Scn = 5590. Scan Carton ID, Pallet ID
   IF @nStep = 2  GOTO Step_ToPallet      -- Scn = 5591. Scan To Pallet ID
   IF @nStep = 3  GOTO Step_ClosePallet   -- Scn = 5592. Close Pallet
   IF @nStep = 4  GOTO Step_Message       -- Scn = 5593. DisplayMsg 

END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 1837
********************************************************************************/
Step_Start:
BEGIN
   -- Get storer config
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'  
      SET @cExtendedValidateSP = ''

   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'  
      SET @cExtendedUpdateSP = ''

   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   SET @cPickDetailCartonID = rdt.RDTGetConfig( @nFunc, 'PickDetailCartonID', @cStorerKey)
   IF @cPickDetailCartonID NOT IN ('DropID', 'CaseID')
      SET @cPickDetailCartonID = 'DropID'

   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
   IF @cPickConfirmStatus = '0'  
      SET @cPickConfirmStatus = '5'  

   SET @cCheckOrderMustPickComplete = rdt.RDTGetConfig( @nFunc, 'CheckOrderMustPickComplete', @cStorerKey)
   
              
   -- Prepare next screen var
   SET @cOutField01 = '' 
   SET @cOutField02 = '' 

   EXEC rdt.rdtSetFocusField @nMobile, 1

   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType     = '1', -- Sign-in
      @cUserID         = @cUserName,
      @nMobileNo       = @nMobile,
      @nFunctionID     = @nFunc,
      @cFacility       = @cFacility,
      @cStorerKey      = @cStorerKey,
      @nStep           = @nStep

      -- Go to next screen
      SET @nScn = @nScn_FromCarton
      SET @nStep = @nStep_FromCarton
END
GOTO Quit

/************************************************************************************
Scn = 5590. Scan Carton, Pallet
   Carton ID (field01, input)
   Pallet ID (field02, input)
************************************************************************************/
Step_FromCarton:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cCartonID = @cInField01
      SET @cPalletID = @cInField02

      -- Check blank
      IF ISNULL( @cCartonID, '') = '' AND ISNULL( @cPalletID, '') = ''
      BEGIN
         SET @nErrNo = 144301
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Value req
         GOTO Step_FromCarton_Fail
      END

      IF ISNULL( @cCartonID, '') <> '' AND ISNULL( @cPalletID, '') <> ''
      BEGIN
         SET @nErrNo = 144312
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Only Either 1
         GOTO Step_FromCarton_Fail
      END

      SET @cPPS_Loc = ''

		SET @nTranCount = @@TRANCOUNT
		BEGIN TRAN
		SAVE TRAN LockPPSLoc

      IF ISNULL( @cCartonID, '') <> '' 
      BEGIN
         SET @cSQL = 
            ' SELECT TOP 1 @cOrderKey = OrderKey ' + 
            ' FROM dbo.PickDetail WITH (NOLOCK) ' + 
            ' WHERE StorerKey = @cStorerKey ' + 
               ' AND Status = ''' + @cPickConfirmStatus + '''' +  
               ' AND QTY > 0 ' + 
               ' AND ' + RTRIM( @cPickDetailCartonID) + ' = @cCartonID ' +
               ' ORDER BY 1 ' +
               ' SET @nRowCount = @@ROWCOUNT '

         SET @cSQLParam = 
            ' @cStorerKey  NVARCHAR( 15), ' + 
            ' @cCartonID   NVARCHAR( 20), ' + 
            ' @cOrderKey   NVARCHAR( 10)  OUTPUT, ' + 
            ' @nRowCount   INT            OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam
            ,@cStorerKey
            ,@cCartonID 
            ,@cOrderKey OUTPUT
            ,@nRowCount OUTPUT

         IF @nRowCount = 0 OR ISNULL( @cOrderKey, '') = ''
         BEGIN
            SET @nErrNo = 144302
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Ctn
            GOTO LockPPSLoc_RollBackTran
         END

         SET @cSQL = 
            ' SET @nRowCount = 0' + 
            ' SELECT @nRowCount = COUNT( 1) ' + 
            ' FROM dbo.PickDetail WITH (NOLOCK) ' + 
            ' WHERE StorerKey = @cStorerKey ' + 
               ' AND Status = ''4''' +  
               ' AND ' + RTRIM( @cPickDetailCartonID) + ' = @cCartonID ' +
               ' ORDER BY 1 ' 

         SET @cSQLParam = 
            ' @cStorerKey  NVARCHAR( 15), ' + 
            ' @cCartonID   NVARCHAR( 20), ' + 
            ' @nRowCount   INT            OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam
            ,@cStorerKey
            ,@cCartonID 
            ,@nRowCount OUTPUT

         IF @nRowCount > 0 
         BEGIN
            SET @nErrNo = 144316
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CaseNotPickCfm
            GOTO LockPPSLoc_RollBackTran
         END
         
         IF @cCheckOrderMustPickComplete = '1'
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.PICKDETAIL WITH (NOLOCK)
                        WHERE OrderKey = @cOrderKey
                        AND   [Status] < @cPickConfirmStatus)
            BEGIN
               SET @nErrNo = 144317
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CaseNotPickCfm
               GOTO LockPPSLoc_RollBackTran
            END
         END

         SELECT @cLoadKey = LoadKey
         FROM dbo.Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         SELECT TOP 1 @cPPS_Loc = Loc
         FROM rdt.rdtSortLaneLocLog WITH (NOLOCK) 
         WHERE LoadKey = @cLoadKey
         AND   Status = '1'   -- in use
         ORDER BY 1

         -- This loadkey not yet assign PPS loc
         IF @@ROWCOUNT = 0
         BEGIN
            SELECT TOP 1 @cPPS_Loc = Loc
            FROM dbo.Loc LOC WITH (NOLOCK)
            WHERE Facility = @cFacility
            AND   LocationCategory = 'PPS'
            AND   [Status] = 'OK'
            AND NOT EXISTS (
               SELECT 1 FROM rdt.rdtSortLaneLocLog SL WITH (NOLOCK) 
               WHERE LOC.LOC = SL.LOC
               AND   SL.Status = '1')
            ORDER BY 1

            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 144303
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No PPS Loc
               GOTO LockPPSLoc_RollBackTran
            END
         END

         IF EXISTS ( SELECT 1 FROM rdt.rdtSortLaneLocLog WITH (NOLOCK) 
                     WHERE LOC = @cPPS_Loc
                     AND   Lane = ''
                     AND   [Status] = '9')
         BEGIN
            UPDATE rdt.rdtSortLaneLocLog WITH (ROWLOCK) SET 
               LoadKey = @cLoadKey,
               Status = '1',
               Id = '',
               EditWho = @cUserName,
               EditDate = GETDATE()
            WHERE LOC = @cPPS_Loc
            AND   Lane = ''
            AND   [Status] = '9'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 144313
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Assign Loc err
               GOTO LockPPSLoc_RollBackTran
            END
         END
         ELSE
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM rdt.rdtSortLaneLocLog WITH (NOLOCK) 
                            WHERE LOC = @cPPS_Loc 
                            AND  [Status] = '1' 
                            AND   Lane = '')
            BEGIN
               INSERT INTO rdt.rdtSortLaneLocLog 
               ( Lane, LOC, ID, OrderKey, ConsigneeKey, Status, AddWho, AddDate, EditWho, EditDate, LoadKey)
               VALUES
               ( '', @cPPS_Loc, '', '', '', '1', @cUserName, GETDATE(), @cUserName, GETDATE(), @cLoadKey)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 144304
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Assign Loc err
                  GOTO LockPPSLoc_RollBackTran
               END
            END
         END
      END

      IF ISNULL( @cPalletID, '') <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM rdt.rdtSortLaneLocLog WITH (NOLOCK)
                         WHERE ID = @cPalletID
                         AND   [Status] = '1')
         BEGIN
            SET @nErrNo = 144311
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Pallet
            GOTO LockPPSLoc_RollBackTran
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cCartonID, @cPalletID, @cLoadKey, @cLoc, @cOption, @tExtValidate, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cCartonID      NVARCHAR( 20), ' +
               ' @cPalletID      NVARCHAR( 20), ' +
               ' @cLoadKey       NVARCHAR( 10), ' +
               ' @cLoc           NVARCHAR( 10), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtValidate   VariableTable READONLY, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cCartonID, @cPalletID, @cLoadKey, @cPPS_Loc, @cOption, @tExtValidate, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO LockPPSLoc_RollBackTran
         END
      END

      -- (james02)
      -- Extended validate
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cCartonID, @cPalletID, @cLoadKey, @cLoc, @cOption, @tExtUpdate, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cCartonID      NVARCHAR( 20), ' +
               ' @cPalletID      NVARCHAR( 20), ' +
               ' @cLoadKey       NVARCHAR( 10), ' +
               ' @cLoc           NVARCHAR( 10), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtUpdate     VariableTable READONLY, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cCartonID, @cPalletID, @cLoadKey, @cPPS_Loc, @cOption, @tExtUpdate, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO LockPPSLoc_RollBackTran
         END
      END

      GOTO LockPPSLoc_CommitTran

      LockPPSLoc_RollBackTran:
         ROLLBACK TRAN LockPPSLoc

      LockPPSLoc_CommitTran:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN LockPPSLoc

      IF @nErrNo <> 0
         GOTO Step_FromCarton_Fail
      
      ---- Extended Info --(cc01)
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cCartonID, @cPalletID, @cLoadKey, @cLoc, @cOption, @tExtValidate, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cCartonID      NVARCHAR( 20), ' +
               ' @cPalletID      NVARCHAR( 20), ' +
               ' @cLoadKey       NVARCHAR( 10), ' +
               ' @cLoc           NVARCHAR( 10), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtValidate   VariableTable READONLY, ' + 
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cCartonID, @cPalletID, @cLoadKey, @cPPS_Loc, @cOption, @tExtValidate, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo = -1 
            Begin
               SET @cOutField01 = @cCartonID
               SELECT @cOutField02 = Long FROM codelkup (NOLOCK) WHERE listName = 'RDTMsgQ' AND storerKey = @cStorerKey AND code2 = @nFunc AND code = '1'
            	SELECT @cOutField03 = Long FROM codelkup (NOLOCK) WHERE listName = 'RDTMsgQ' AND storerKey = @cStorerKey AND code2 = @nFunc AND code = '2'
            	SELECT @cOutField04 = Long FROM codelkup (NOLOCK) WHERE listName = 'RDTMsgQ' AND storerKey = @cStorerKey AND code2 = @nFunc AND code = '3'
            	SELECT @cOutField05 = Long FROM codelkup (NOLOCK) WHERE listName = 'RDTMsgQ' AND storerKey = @cStorerKey AND code2 = @nFunc AND code = '4'
            	SELECT @cOutField06 = Long FROM codelkup (NOLOCK) WHERE listName = 'RDTMsgQ' AND storerKey = @cStorerKey AND code2 = @nFunc AND code = '5'
            	SELECT @cOutField07 = Long FROM codelkup (NOLOCK) WHERE listName = 'RDTMsgQ' AND storerKey = @cStorerKey AND code2 = @nFunc AND code = '6'
            	SELECT @cOutField08 = Long FROM codelkup (NOLOCK) WHERE listName = 'RDTMsgQ' AND storerKey = @cStorerKey AND code2 = @nFunc AND code = '7'
            	SELECT @cOutField09 = Long FROM codelkup (NOLOCK) WHERE listName = 'RDTMsgQ' AND storerKey = @cStorerKey AND code2 = @nFunc AND code = '8'
            	SELECT @cOutField10 = Long FROM codelkup (NOLOCK) WHERE listName = 'RDTMsgQ' AND storerKey = @cStorerKey AND code2 = @nFunc AND code = '9'
            	SELECT @cOutField11 = @cExtendedInfo   -- Default for ExtendedInfo (james03)

               -- Go to next screen
               SET @nScn = @nScn_Message
               SET @nStep = @nStep_Message

               GOTO Quit
            END
            ELSE IF @nErrNo <> 0
            BEGIN
            	GOTO Step_FromCarton_Fail
            END
         END
      END
      	
      IF ISNULL( @cPalletID, '') <> ''
      BEGIN
         SET @cOutField01 = ''

         -- Go to next screen
         SET @nScn = @nScn_ClosePallet
         SET @nStep = @nStep_ClosePallet

         GOTO Quit
      END

      -- Prepare next screen var
      SET @cOutField01 = @cCartonID
      SET @cOutField02 = @cLoadKey
      SET @cOutField03 = @cPPS_Loc
      SET @cOutField04 = ''

      SET @cOutField04 = ''

      -- Go to next screen
      SET @nScn = @nScn_ToPallet
      SET @nStep = @nStep_ToPallet 
   END

   IF @nInputKey = 0 -- Esc or No
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

      -- Reset all variables
      SET @cOutField01 = '' 

      -- Enable field
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
   END
   GOTO Quit

   Step_FromCarton_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''

      IF ISNULL( @cCartonID, '') <> ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 2
   END
   GOTO Quit
END
GOTO Quit

/***********************************************************************************
Scn = 5591. Carton ID/LoadKey/Loc/Pallet ID screen
   Carton ID   (field01)
   Loadkey     (field02)
   Loc         (field03)
   Pallet ID   (field04, input)
***********************************************************************************/
Step_ToPallet:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Prepare next screen var
      SET @cPalletID = @cInField04 

      IF ISNULL( @cPalletID, '') = ''
      BEGIN
         SET @nErrNo = 144305
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Value req
         GOTO Step_ToPallet_Fail  
      END

      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cPalletID) = 0  
      BEGIN
         SET @nErrNo = 144306
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Invalid Format
         GOTO Step_ToPallet_Fail  
      END

      -- Check if the id already scanned to different loc
      IF EXISTS ( SELECT 1 FROM rdt.rdtSortLaneLocLog WITH (NOLOCK)
                  WHERE ID = @cPalletID
                  AND   Status = '1'
                  AND   LoadKey <> @cLoadKey)
      BEGIN
         SET @nErrNo = 144307
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --ID In Use
         GOTO Step_ToPallet_Fail  
      END

      -- Check if loc has id already but scan in different id
      IF EXISTS ( SELECT 1 FROM rdt.rdtSortLaneLocLog WITH (NOLOCK)
                  WHERE ( ID <> '' AND ID <> @cPalletID)
                  AND   Status = '1'
                  AND   LoadKey = @cLoadKey)
      BEGIN
         SET @nErrNo = 144314
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Loc In Use
         GOTO Step_ToPallet_Fail  
      END

      -- Check if pallet id has inventory but not in PPS
      IF EXISTS ( SELECT 1 FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
                  WHERE LOC.Facility = @cFacility
                  AND   LOC.LocationCategory <> 'PPS'
                  AND   LLI.ID = @cPalletID
                  AND   ( ((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + PendingMoveIn)) > 0)
      BEGIN
         SET @nErrNo = 144308
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --ID In Use
         GOTO Step_ToPallet_Fail  
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cCartonID, @cPalletID, @cLoadKey, @cLoc, @cOption, @tExtValidate, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cCartonID      NVARCHAR( 20), ' +
               ' @cPalletID      NVARCHAR( 20), ' +
               ' @cLoadKey       NVARCHAR( 10), ' +
               ' @cLoc           NVARCHAR( 10), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtValidate   VariableTable READONLY, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cCartonID, @cPalletID, @cLoadKey, @cPPS_Loc, @cOption, @tExtValidate, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO Step_ToPallet_Fail
         END
      END

		SET @nTranCount = @@TRANCOUNT
		BEGIN TRAN
		SAVE TRAN PPA_Confirm

      SET @nErrNo = 0
      EXEC rdt.rdt_PostPackSort_Confirm
         @nMobile             = @nMobile,    
         @nFunc               = @nFunc,    
         @cLangCode           = @cLangCode,    
         @cStorerKey          = @cStorerKey,    
         @cFacility           = @cFacility,     
         @cCartonID           = @cCartonID, 
         @cPalletID           = @cPalletID, 
         @cLoadKey            = @cLoadKey, 
         @cLoc                = @cPPS_Loc, 
         @cOption             = @cOption, 
         @cPickDetailCartonID = @cPickDetailCartonID,    
         @tPostPackSortCfm    = @tPostPackSortCfm,    
         @nErrNo              = @nErrNo            OUTPUT,    
         @cErrMsg             = @cErrMsg           OUTPUT    

      IF @nErrNo <> 0 
         GOTO PPA_Confirm_RollBackTran

      -- (james02)
      -- Extended validate
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cCartonID, @cPalletID, @cLoadKey, @cLoc, @cOption, @tExtUpdate, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cCartonID      NVARCHAR( 20), ' +
               ' @cPalletID      NVARCHAR( 20), ' +
               ' @cLoadKey       NVARCHAR( 10), ' +
               ' @cLoc           NVARCHAR( 10), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtUpdate     VariableTable READONLY, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cCartonID, @cPalletID, @cLoadKey, @cPPS_Loc, @cOption, @tExtUpdate, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO PPA_Confirm_RollBackTran
         END
      END

      GOTO PPA_Confirm_CommitTran

      PPA_Confirm_RollBackTran:
         ROLLBACK TRAN PPA_Confirm       -- ZG01

      PPA_Confirm_CommitTran:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN PPA_Confirm

      -- Extended validate
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cCartonID, @cPalletID, @cLoadKey, @cLoc, @cOption, @tExtValidate, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cCartonID      NVARCHAR( 20), ' +
               ' @cPalletID      NVARCHAR( 20), ' +
               ' @cLoadKey       NVARCHAR( 10), ' +
               ' @cLoc           NVARCHAR( 10), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtValidate   VariableTable READONLY, ' + 
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cCartonID, @cPalletID, @cLoadKey, @cPPS_Loc, @cOption, @tExtValidate, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO Step_ToPallet_Fail
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = '' 
      SET @cOutField02 = '' 
      SET @cOutField15 = @cExtendedInfo

      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go to next screen
      SET @nScn = @nScn_FromCarton
      SET @nStep = @nStep_FromCarton
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- (james01)
      -- User key in carton, booked loc but didn't key in any id and esc
      -- need clear the status to let other user use or else loc will be blocked
      IF EXISTS ( SELECT 1 FROM rdt.rdtSortLaneLocLog WITH (NOLOCK)
                  WHERE LoadKey = @cLoadKey
                  AND   LOC = @cPPS_Loc
                  AND   [Status] = '1'
                  AND   ID = '')
      BEGIN
         UPDATE  rdt.rdtSortLaneLocLog WITH (ROWLOCK) SET 
            LoadKey = '',
            [Status] = '9'
         WHERE LoadKey = @cLoadKey
         AND   LOC = @cPPS_Loc
         AND   [Status] = '1'
         AND   ID = ''

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 144315
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Assign Loc Err
            GOTO Step_ToPallet_Fail  
         END
      END
      
      -- Prepare next screen var
      SET @cOutField01 = '' 
      SET @cOutField02 = '' 

      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go to next screen
      SET @nScn = @nScn_FromCarton
      SET @nStep = @nStep_FromCarton
   END
   GOTO Quit

   Step_ToPallet_Fail:
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cCartonID
      SET @cOutField02 = @cLoadKey
      SET @cOutField03 = @cPPS_Loc
      SET @cOutField04 = ''

      SET @cOutField04 = ''
   END
END
GOTO Quit

/********************************************************************************
Scn = 5592. Close Pallet?
   Option (field01, input)
********************************************************************************/
Step_ClosePallet:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 144309
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionRequired
         GOTO Step_ClosePallet_Fail
      END

      -- Validate option
      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 144310
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_ClosePallet_Fail
      END

      IF @cOption = '1'  -- Yes
      BEGIN
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN
         SAVE TRAN Step_ClosePallet

         EXEC rdt.rdt_PostPackSort_ClosePallet
            @nMobile       = @nMobile,    
            @nFunc         = @nFunc,    
            @cLangCode     = @cLangCode,    
            @cStorerKey    = @cStorerKey,    
            @cFacility     = @cFacility,     
            @cCartonID     = @cCartonID, 
            @cPalletID     = @cPalletID, 
            @cLoadKey      = @cLoadKey, 
            @cLoc          = @cPPS_Loc, 
            @cOption       = @cOption, 
            @cPickDetailCartonID = @cPickDetailCartonID,    
            @tClosePallet  = @tClosePallet,    
            @nErrNo        = @nErrNo            OUTPUT,    
            @cErrMsg       = @cErrMsg           OUTPUT    

         IF @nErrNo <> 0
            GOTO RollBackTran_ClosePallet

         -- (james04)
         -- Extended validate
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
                  ' @cCartonID, @cPalletID, @cLoadKey, @cLoc, @cOption, @tExtUpdate, ' +
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

               SET @cSQLParam =
                  ' @nMobile        INT,           ' +
                  ' @nFunc          INT,           ' +
                  ' @cLangCode      NVARCHAR( 3),  ' +
                  ' @nStep          INT,           ' +
                  ' @nInputKey      INT,           ' +
                  ' @cFacility      NVARCHAR( 5),  ' +
                  ' @cStorerKey     NVARCHAR( 15), ' +
                  ' @cCartonID      NVARCHAR( 20), ' +
                  ' @cPalletID      NVARCHAR( 20), ' +
                  ' @cLoadKey       NVARCHAR( 10), ' +
                  ' @cLoc           NVARCHAR( 10), ' +
                  ' @cOption        NVARCHAR( 1), ' +
                  ' @tExtUpdate     VariableTable READONLY, ' + 
                  ' @nErrNo         INT           OUTPUT, ' +
                  ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
                  @cCartonID, @cPalletID, @cLoadKey, @cPPS_Loc, @cOption, @tExtUpdate, 
                  @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0 
                  GOTO RollBackTran_ClosePallet
            END

            GOTO ClosePalletnCommit
   
            RollBackTran_ClosePallet:  
                  ROLLBACK TRAN Step_ClosePallet  

            ClosePalletnCommit:  
               WHILE @@TRANCOUNT > @nTranCount  
                  COMMIT TRAN Step_ClosePallet
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = '' 
      SET @cOutField02 = '' 

      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go to next screen
      SET @nScn = @nScn_FromCarton
      SET @nStep = @nStep_FromCarton
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' 
      SET @cOutField02 = '' 

      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go to next screen
      SET @nScn = @nScn_FromCarton
      SET @nStep = @nStep_FromCarton
   END
   GOTO Quit

   Step_ClosePallet_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cOption = ''
   END
END
GOTO Quit

/********************************************************************************
Scn = 5593 Message.
   CartonID (field01)
********************************************************************************/
Step_Message:
BEGIN
   IF @nInputKey = 1 -- ENTER/ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cCartonID
      SET @cOutField02 = @cLoadKey
      SET @cOutField03 = @cPPS_Loc
      SET @cOutField04 = ''

      SET @cOutField04 = ''

      -- Go to next screen
      SET @nScn = @nScn_ToPallet
      SET @nstep = @nStep_ToPallet
      
      GOTO Quit
   END
   IF @nInputKey = 0 -- ESC
   BEGIN
      -- (james01)
      -- User key in carton, booked loc but didn't key in any id and esc
      -- need clear the status to let other user use or else loc will be blocked
      IF EXISTS ( SELECT 1 FROM rdt.rdtSortLaneLocLog WITH (NOLOCK)
                  WHERE LoadKey = @cLoadKey
                  AND   LOC = @cPPS_Loc
                  AND   [Status] = '1'
                  AND   ID = '')
      BEGIN
         UPDATE  rdt.rdtSortLaneLocLog WITH (ROWLOCK) SET 
            LoadKey = '',
            [Status] = '9'
         WHERE LoadKey = @cLoadKey
         AND   LOC = @cPPS_Loc
         AND   [Status] = '1'
         AND   ID = ''

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 144318
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Assign Loc Err
            GOTO Quit 
         END
      END
      
      -- Prepare next screen var
      SET @cOutField01 = '' 
      SET @cOutField02 = '' 

      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go to next screen
      SET @nScn = @nScn_FromCarton
      SET @nStep = @nStep_FromCarton
   END
   GOTO Quit
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.rdtMobRec WITH (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      V_LoadKey = @cLoadKey,
      V_Loc     = @cPPS_Loc,

	   V_String1  = @cExtendedUpdateSP,
      V_String2  = @cExtendedValidateSP,
      V_String3  = @cExtendedInfoSP,
      V_String4  = @cCartonID,
      V_String5  = @cPalletID,
      V_String6  = @cPickDetailCartonID,
      V_String7  = @cPickConfirmStatus,
      V_String8 = @cCheckOrderMustPickComplete,

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,   FieldAttr01  = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,   FieldAttr02  = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,   FieldAttr03  = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,   FieldAttr04  = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,   FieldAttr05  = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,   FieldAttr06  = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,   FieldAttr07  = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,   FieldAttr08  = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,   FieldAttr09  = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,   FieldAttr10  = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,   FieldAttr11  = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,   FieldAttr12  = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,   FieldAttr13  = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,   FieldAttr14  = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,   FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile
END

GO