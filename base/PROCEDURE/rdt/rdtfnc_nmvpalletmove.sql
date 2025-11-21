SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_NMVPalletMove                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Putaway to pack and hold                                    */
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
/* Date       Rev  Author   Purposes                                    */
/* 2011-11-30 1.0  Ung      Created                                     */
/* 2012-02-01 1.1  ChewKP   CR : Able to Move to Staging, MaxPallet     */
/*                          (ChewKP01)                                  */
/* 2012-02-06 1.2  James    Include max pallet check (james01)          */
/* 2012-02-08 1.3  James    Prompt user to scan LOC if pack & hold are  */
/*                          full (james02)                              */
/* 2012-02-16 1.4  Ung      Add FinalLOC check same ShipTo + PO         */
/* 2012-02-27 1.5  ChewKP   ADd StorerConfig for checking same ShipTo   */
/*                          + PO (ChewKP02)                             */
/* 2012-02-27 1.6  James    Bug fix on maxpallet checking (james03)     */
/* 2012-04-19 1.7  Ung      Support master carton on pallet (ung01)     */
/* 2012-05-07 1.8  Ung      SOS243691 Chg DropID.Status 5 to 3 (ung02)  */
/* 2012-05-11 1.9  James    Update Dropid status. If Pack&Hold then '3' */
/*                          ELSE '5' (james04)                          */
/* 2012-05-17 2.0  James    Add extra validation (james05)              */
/* 2012-05-24 2.1  James    Add eventlog (james06)                      */
/* 2012-06-04 2.2  Ung      SOS246383 Add generate label file (ung03)   */
/* 2012-06-12 2.3  Ung      SOS247019 Pack&Hold loc sequence (ung04)    */
/* 2012-07-02 2.4  James    SOS248014 Cannot move pallet when audit     */
/*                          failed (status = '1') (james07)             */
/* 2012-10-17 2.5  James    SOS257520 Remove Pallet QC Check (james08)  */
/* 2014-03-24 2.6  ChewKP   SOS#294360 - Add in ExtUpdateSP (ChewKP03)  */
/* 2016-09-30 2.7  Ung      Performance tuning                          */
/* 2018-10-10 2.8  TungGH   Performance                                 */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtfnc_NMVPalletMove] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Other var use in this stor proc
DECLARE
   @b_Success        INT,
   @c_errmsg         NVARCHAR( 250),
   @cChkFacility     NVARCHAR(5)

-- Variable for RDT.RDTMobRec
DECLARE
   @nFunc            INT,
   @nScn             INT,
   @nStep            INT,
   @cLangCode        NVARCHAR( 3),
   @nInputKey        INT,
   @nMenu            INT,

   @cStorer          NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),
   @cPrinter         NVARCHAR( 10),
   @cUserName        NVARCHAR( 18),

   @cID              NVARCHAR( 20),
   @cSuggestedLOC    NVARCHAR( 10),
   @cFinalLOC        NVARCHAR( 10),
   @cLOCAssigned     NVARCHAR( 10),
   @nPalletCount     INT,
   @nMaxPallet       INT,
   @cDropLoc         NVARCHAR( 10),
   @nMax_Pallet      INT,
   @nPallet_Cnt      INT,
   @cLOC             NVARCHAR(10),
   @c_mixpoinlane    NVARCHAR(1),
   @cPrintLabelSP    NVARCHAR( 20), 
   @cExtendedUpdateSP NVARCHAR(20),   -- (ChewKP03)
   @cSQL              NVARCHAR(1000), -- (ChewKP03)
   @cSQLParam         NVARCHAR(1000), -- (ChewKP03)
   @cAllowMultiLoadKey NVARCHAR(1),   -- (ChewKP03)
   @cExtendedValidateSP NVARCHAR(20), -- (ChewKP03)

   @cInField01 NVARCHAR( 60),  @cOutField01 NVARCHAR( 60),
   @cInField02 NVARCHAR( 60),  @cOutField02 NVARCHAR( 60),
   @cInField03 NVARCHAR( 60),  @cOutField03 NVARCHAR( 60),
   @cInField04 NVARCHAR( 60),  @cOutField04 NVARCHAR( 60),
   @cInField05 NVARCHAR( 60),  @cOutField05 NVARCHAR( 60),
   @cInField06 NVARCHAR( 60),  @cOutField06 NVARCHAR( 60),
   @cInField07 NVARCHAR( 60),  @cOutField07 NVARCHAR( 60),
   @cInField08 NVARCHAR( 60),  @cOutField08 NVARCHAR( 60),
   @cInField09 NVARCHAR( 60),  @cOutField09 NVARCHAR( 60),
   @cInField10 NVARCHAR( 60),  @cOutField10 NVARCHAR( 60),
   @cInField11 NVARCHAR( 60),  @cOutField11 NVARCHAR( 60),
   @cInField12 NVARCHAR( 60),  @cOutField12 NVARCHAR( 60),
   @cInField13 NVARCHAR( 60),  @cOutField13 NVARCHAR( 60),
   @cInField14 NVARCHAR( 60),  @cOutField14 NVARCHAR( 60),
   @cInField15 NVARCHAR( 60),  @cOutField15 NVARCHAR( 60),

   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),
   @cFieldAttr15 NVARCHAR( 1)

-- Getting Mobile information
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorer    = StorerKey,
   @cFacility  = Facility,
   @cPrinter   = Printer, 
   @cUserName  = UserName,

   @cID        = V_ID,

   @cSuggestedLOC  = V_String1,
   @cFinalLOC      = V_String2,
   @cLOCAssigned   = V_String3,
   @cExtendedUpdateSP = V_String4, -- (ChewKP03)
   @cExtendedValidateSP = V_String5, -- (ChewKP03)

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
IF @nFunc = 1791
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Func = 1791. Menu
   IF @nStep = 1 GOTO Step_1   -- Scn  = 2990. ID, LOC
   IF @nStep = 2 GOTO Step_2   -- Scn  = 2991. Suggested LOC, final LOC
   IF @nStep = 3 GOTO Step_3   -- Scn  = 2992. Message
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 1791. Menu
   @nStep = 0
********************************************************************************/
Step_0:
BEGIN
   EXEC RDT.rdt_STD_EventLog
  @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorer,
      @nStep       = @nStep

   -- (ChewKP03)
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorer)
   IF @cExtendedUpdateSP = '0'  
   BEGIN
      SET @cExtendedUpdateSP = ''
   END
   
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorer)
   IF @cExtendedValidateSP = '0'  
   BEGIN
      SET @cExtendedValidateSP = ''
   END
   
    -- (ChewKP03)
   SET @cAllowMultiLoadKey = ''
   SET @cAllowMultiLoadKey = rdt.RDTGetConfig( @nFunc, 'AllowMultiLoadKey', @cStorer)
   
   -- Enable all fields
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

   -- Set the entry point
   SET @nScn = 2990
   SET @nStep = 1
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 2990
   ID  (field01, input)
   LOC (field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cID = @cInField01

      -- Check blank ID
      IF @cID = ''
      BEGIN
         SET @nErrNo = 75051
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need ID
         GOTO Step_1_Fail
      END

      -- Get ID info
      DECLARE @cStatus NVARCHAR( 10)
      SET @cStatus = ''
      SELECT @cStatus = Status
      FROM dbo.DropID WITH (NOLOCK)
      WHERE DropID = @cID

      -- Check valid ID
      IF @@ROWCOUNT = 0
      BEGIN
      SET @nErrNo = 75052
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid ID
         GOTO Step_1_Fail
      END
      SET @cOutField01 = @cID

      -- Check ID putaway
      IF @cStatus = '3' --(ung02)
      BEGIN
         SET @nErrNo = 75053
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID PACK&HOLD
         GOTO Step_1_Fail
      END

      IF @cStatus = '5' --(james05)
      BEGIN
         SET @nErrNo = 75067
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID STAGED
         GOTO Step_1_Fail
      END
      
      -- Check if ID shipped
      IF @cStatus = '9'
      BEGIN
         SET @nErrNo = 75054
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID had shipped
         GOTO Step_1_Fail
      END

/*
      -- Check if ID failed audit   (james07)/(james08)
      IF @cStatus = '1'
      BEGIN
         SET @nErrNo = 75068
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID Fail Audit
         GOTO Step_1_Fail
      END
*/
      
      DECLARE @nCountLoadKey    INT
      DECLARE @nCountLoadKey_MC INT
      DECLARE @cLoadKey         NVARCHAR( 10)
      DECLARE @cLoadKey_MC      NVARCHAR( 10)

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

      -- Check if pallet no LoadKey
      IF @nCountLoadKey = 0 OR @cLoadKey = ''
      BEGIN
         SET @nErrNo = 75055
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID no LoadKey
         GOTO Step_1_Fail
      END
      
      IF @cAllowMultiLoadKey <> '1'
      BEGIN
         -- Check if pallet has multi LoadKey
         -- IF @nCountLoadKey > 1 AND ISNULL(@cLoadKey, '') <> ISNULL(@cLoadKey_MC, '')  -- temp fix by larry
         IF @nCountLoadKey < 1 AND ISNULL(@cLoadKey, '') <> ISNULL(@cLoadKey_MC, '')  -- temp fix by larry      
         BEGIN
            SET @nErrNo = 75056
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- IDMultiLoadKey
            GOTO Step_1_Fail
         END
      END

      -- Get lane assigned
      SET @cLOCAssigned = ''
      SELECT @cLOCAssigned = LOC
      FROM dbo.LoadPlanLaneDetail WITH (NOLOCK)
      WHERE LoadKey = @cLoadKey
         AND Status = '0' -- 0=Assigned, 9=Released

      -- Lane assigned
      IF @cLOCAssigned <> ''
         SET @cSuggestedLOC = @cLOCAssigned
      ELSE
      BEGIN -- Lane not assigned
         
         -- Find LOC not yet reach MaxPallet
         SET @cSuggestedLOC = ''
     
         
         IF @cExtendedValidateSP <> ''
         BEGIN
         
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
            BEGIN
        

               SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorer, @cFacility, @cID, @cSuggestedLOC OUTPUT,  @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile        INT, ' +
                  '@nFunc          INT, ' +
                  '@cLangCode      NVARCHAR( 3),  ' +
                  '@nStep          INT, ' +
                  '@cStorer        NVARCHAR( 15), ' +
                  '@cFacility      NVARCHAR( 5), ' +
                  '@cID            NVARCHAR( 20), ' +
                  '@cSuggestedLOC  NVARCHAR( 20) OUTPUT, ' +
                  '@nErrNo         INT           OUTPUT, ' + 
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'
                  
              
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @cStorer, @cFacility, @cID, @cSuggestedLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 
               
               IF @nErrNo <> 0 
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
                  GOTO Step_1_Fail 
               END
            END  
         END
         ELSE
         BEGIN
            DECLARE CUR_DropLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Count(DISTINCT D.DropID)
                   ,D.DropLoc
            FROM dbo.DropID D WITH (NOLOCK)
            INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = D.DropLoc
            WHERE Loc.Facility = @cFacility
            AND Loc.LocationCategory = 'PACK&HOLD'
            AND D.Status = '3' --(ung02)
            GROUP BY LOC.LogicalLocation, D.DropLoc --(ung04)
            ORDER BY LOC.LogicalLocation, D.DropLoc --(ung04)
   
            OPEN CUR_DropLoc
            FETCH NEXT FROM CUR_DropLoc INTO @nPalletCount, @cDropLoc
            WHILE (@@FETCH_STATUS <> -1)
            BEGIN
               SELECT @nMaxPallet = (CASE MaxPallet WHEN NULL THEN 0 ELSE MaxPallet END) FROM LOC WITH (NOLOCK) WHERE LOC = @cDropLoc
               IF @nPalletCount < @nMaxPallet
               BEGIN
                  SET @cSuggestedLOC = @cDropLoc
                  BREAK
               END
               FETCH NEXT FROM CUR_DropLoc INTO @nPalletCount, @cDropLoc
            END
            CLOSE CUR_DropLoc
            DEALLOCATE CUR_DropLoc
   
            -- Find empty LOC
            IF @cSuggestedLOC = ''
               SELECT TOP 1
                  @cSuggestedLOC = LOC.LOC
               FROM dbo.LOC WITH (NOLOCK)
                  LEFT OUTER JOIN dbo.DropID WITH (NOLOCK) ON (DropID.DropLOC = LOC.LOC AND DropID.Status = '3') -- 3=Putaway (ung02)
               WHERE LOC.LocationCategory = 'PACK&HOLD'
                  AND LOC.Facility = @cFacility
                  AND DropID.DropID IS NULL
               ORDER BY LOC.LogicalLocation, LOC.LOC --(ung04)
         END
         
         -- Prompt if no suggested LOC
         IF @cSuggestedLOC = ''
         BEGIN
            DECLARE @cErrMsg1 NVARCHAR( 20)
            SET @cErrMsg1 = rdt.rdtgetmessage( 75066, @cLangCode, 'DSP') -- PACK & HOLD LOC FULL
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 'PACK HOLD LOC FULL'
         END
      END

      -- Prepare next screen var
      SET @cFinalLOC = ''
      SET @cOutField01 = @cSuggestedLOC
      SET @cOutField02 = '' -- FinalLOC

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorer,
         @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cID = ''
      SET @cOutField01 = '' -- ID
   END

END
GOTO Quit


/********************************************************************************
Step 2. Scn = 2991
   Suggested LOC  (field01)
   Final LOC      (field02, input)
********************************************************************************/
Step_2:
BEGIN
 IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFinalLOC = @cInField02

      -- Check blank final LOC
      IF @cFinalLOC = ''
      BEGIN
         SET @nErrNo = 75058
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need Final LOC
         GOTO Step_2_Fail
      END

      -- Check invalid from loc
      SELECT @cChkFacility = Facility FROM LOC WITH (NOLOCK) WHERE LOC = @cFinalLOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 75059
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid LOC
         GOTO Step_2_Fail
      END

      -- Check from loc different facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 75060
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff facility
         GOTO Step_2_Fail
      END



      -- Lane assigned
      IF @cLOCAssigned <> ''
      BEGIN
         IF @cSuggestedLOC <> @cFinalLOC
         BEGIN
            IF rdt.RDTGetConfig( @nFunc, 'PutawayMatchStagingLOC', @cStorer) = '1'
            BEGIN
               SET @nErrNo = 75061
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LOC Not Match
               GOTO Step_2_Fail
            END

            -- Get other ID on this lane
            DECLARE @cOtherID NVARCHAR( 18)
            SET @cOtherID = ''
            SELECT TOP 1 @cOtherID = DropID
            FROM dbo.DropID WITH (NOLOCK)
            WHERE DropLOC = @cFinalLOC
               AND DropID <> @cID
               AND Status = 5 --5=Putaway


            -- (ChewKP02)
            EXECUTE nspGetRight @cFacility,  -- facility
               '',      -- Storerkey
               NULL,      -- Sku
               'MIXPOINLANE', -- Configkey
               @b_success       OUTPUT,
               @c_mixpoinlane   OUTPUT,
               @nErrNo           OUTPUT,
               @cErrMsg        OUTPUT



            IF @c_mixpoinlane <> '1'
            BEGIN
            -- Check other ID is same ExternOrderKey and ConsigneeKey
               IF @cOtherID <> ''
               BEGIN
                  -- Get LoadKey of other ID
                  DECLARE @cOtherLoadKey    NVARCHAR( 10)
                  DECLARE @cOtherLoadKey_MC NVARCHAR( 10)
                  SET @cOtherLoadKey = ''
                  SET @cOtherLoadKey_MC = ''

                  -- Get LoadKey of normal carton
                  SELECT TOP 1 @cOtherLoadKey = PH.LoadKey
                  FROM dbo.DropIDDetail DD WITH (NOLOCK)
                     INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (DD.ChildID = PD.LabelNo)
                     INNER JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
                  WHERE DD.DropID = @cOtherID

                  -- Get LoadKey of master carton (ung01)
                  SELECT TOP 1 @cOtherLoadKey_MC = PH.LoadKey
                  FROM dbo.DropIDDetail DD WITH (NOLOCK)
                     INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (DD.ChildID = PD.RefNo2)
                     INNER JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
                  WHERE DD.DropID = @cOtherID

                  IF @cOtherLoadKey = ''
                     SET @cOtherLoadKey = @cOtherLoadKey_MC

                  DECLARE
                     @cOtherExternOrderKey NVARCHAR( 30),
                     @cOtherConsigneeKey NVARCHAR( 15),
                     @cExternOrderKey NVARCHAR( 30),
                     @cConsigneeKey NVARCHAR( 15)

                  -- Get ID ExternOrderKey and ConsigneeKey
                  SELECT TOP 1
                     @cExternOrderKey = O.ExternOrderKey,
                     @cConsigneeKey = O.ConsigneeKey
                  FROM dbo.Orders O WITH (NOLOCK)
                     JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
                  WHERE LPD.LoadKey = @cLoadKey

                  -- Get other ID ExternOrderKey and ConsigneeKey
                  SELECT TOP 1
                     @cOtherExternOrderKey = O.ExternOrderKey,
                     @cOtherConsigneeKey = O.ConsigneeKey
                  FROM dbo.Orders O WITH (NOLOCK)
                     JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
                  WHERE LPD.LoadKey = @cOtherLoadKey

                  IF @cOtherExternOrderKey <> @cExternOrderKey OR
                     @cOtherConsigneeKey <> @cConsigneeKey
                  BEGIN
                     SET @nErrNo = 75062
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff ShipTo+PO
                     GOTO Step_2_Fail
                  END
               END
            END
         END
      END
      ELSE
      BEGIN -- Lane not assigned
         IF @cSuggestedLOC <> '' AND
            @cSuggestedLOC <> @cFinalLOC AND
            rdt.RDTGetConfig( @nFunc, 'PutawayMatchSuggestLOC', @cStorer) = '1'
         BEGIN
            SET @nErrNo = 75063
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LOC Not Match
            GOTO Step_2_Fail
         END

         -- Get max pallet that a LOC can hold (james01)
         SELECT @nMax_Pallet = MaxPallet
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cFinalLOC
            AND Facility = @cFacility

         -- Get the pallet that already in LOC (james01)
         SELECT @nPallet_Cnt = COUNT( DropID)
         FROM dbo.DropID WITH (NOLOCK)
         WHERE DropLOC = @cFinalLOC
            AND Status = '3' --3=Putaway. (ung02)

         -- Note: if MaxPallet = 0 means unlimited pallet count in the loc
         -- No need check pallet count if MaxPallet = 0
         IF @nMax_Pallet > 0  -- (james03)
         BEGIN
            IF @nPallet_Cnt + 1 > @nMax_Pallet
            BEGIN
               SET @nErrNo = 75064
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- EXCEED MAX PLT
               GOTO Step_2_Fail
            END
         END
      END

      IF @cExtendedUpdateSP <> ''
      BEGIN
            
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorer, @cID, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile        INT, ' +
                  '@nFunc          INT, ' +
                  '@cLangCode      NVARCHAR( 3), ' +
                  '@cUserName      NVARCHAR( 18), ' +
                  '@cFacility      NVARCHAR( 5), ' +
                  '@cStorer        NVARCHAR( 15), ' +
                  '@cID            NVARCHAR( 20), ' +
                  '@cFinalLOC      NVARCHAR( 10), ' +
                  '@nErrNo         INT           OUTPUT, ' + 
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'
                  
      
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorer, @cID, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT 
      
               IF @nErrNo <> 0 
                  GOTO Step_2_Fail
                  
            END
      END  
      ELSE
      BEGIN
         -- If location category is pack&hold then update status '3'. The rest is status '5' (james04)
         IF EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cFinalLOC AND LocationCategory <> 'PACK&HOLD')
         BEGIN
            -- Update DropID
            UPDATE DropID SET
               DropLOC = @cFinalLOC,
               Status = '5', -- 5=Putaway. (ung02)
               EditWho = 'rdt.' + sUser_sName(),
               EditDate = GETDATE()
            WHERE DropID = @cID
         END
         ELSE
         BEGIN
            -- Update DropID
            UPDATE DropID SET
               DropLOC = @cFinalLOC,
               Status = '3', -- 3=Putaway. (ung02)
               EditWho = 'rdt.' + sUser_sName(),
               EditDate = GETDATE()
            WHERE DropID = @cID
         END
   
         IF @nErrNo <> 0
         BEGIN
            SET @nErrNo = 75065
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdDropIDFail
            GOTO Step_2_Fail
         END
      
         -- Print label (ung03)
         IF EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cFinalLOC AND LocationCategory <> 'PACK&HOLD')
         BEGIN
            -- Get storer
            SELECT DISTINCT @cStorer = Storerkey FROM dbo.DropID DropID WITH (NOLOCK)
            INNER JOIN dbo.DropIDDetail DD WITH (NOLOCK) on DD.DropID = DropID.DropID
            INNER JOIN dbo.PackDetail PD WITH (NOLOCK) on PD.LabelNo = DD.ChildID
            WHERE DropID.DropID = @cID
            
            SET @cPrintLabelSP = rdt.RDTGetConfig( 1791, 'PrintLabel', @cStorer)
            IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = @cPrintLabelSP AND type = 'P')
            BEGIN
               DECLARE @cSQLStatement NVARCHAR(1000)
               DECLARE @cSQLParms     NVARCHAR(1000)
               
         	   SET @cSQLStatement = N'EXEC rdt.' + @cPrintLabelSP + 
                  ' @nMobile, @cLangCode, @cUserName, @cPrinter, @cStorerKey, @cFacility, @cDropID, ' +
                  ' @nErrNo     OUTPUT,' +
                  ' @cErrMsg    OUTPUT '
   
         	   SET @cSQLParms = 
         	      '@nMobile     INT,       ' +
                  '@cLangCode   NVARCHAR(3),   ' +
                  '@cUserName   NVARCHAR(18),  ' +
                  '@cPrinter    NVARCHAR(10),  ' +
                  '@cStorerKey  NVARCHAR(15),  ' +
                  '@cFacility   NVARCHAR(5),   ' +  
                  '@cDropID     NVARCHAR( 20), ' +        
                  '@nErrNo      INT          OUTPUT, ' +
                  '@cErrMsg     NVARCHAR(250) OUTPUT  ' 
                              
               EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,    
                   @nMobile
                  ,@cLangCode
                  ,@cUserName 
                  ,@cPrinter 
                  ,@cStorer
                  ,@cFacility 
                  ,@cID
      	         ,@nErrNo   OUTPUT
      	         ,@cErrMsg  OUTPUT
            END
         END
      END
      -- (james06)  
      EXEC RDT.rdt_STD_EventLog  
        @cActionType   = '4', -- Move  
        @cUserID       = @cUserName,  
        @nMobileNo     = @nMobile,  
        @nFunctionID   = @nFunc,  
        @cFacility     = @cFacility,  
        @cStorerKey    = @cStorer,  
        @cID           = @cID,  
        @cToID         = @cID,   
        @cLocation     = 'DOWN LANE',    
        @cToLocation   = @cFinalLOC,    
        @cSuggestedLOC = @cSuggestedLOC,
        @nStep         = @nStep
      
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen variable
      SET @cID = ''
      SET @cOutField01 = '' -- ID

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cFinalLOC = ''
      SET @cOutField02 = '' -- Final LOC
   END
END
GOTO Quit


/********************************************************************************
Step 3. scn = 2992. Message screen
   Successful putaway
********************************************************************************/
Step_3:
BEGIN
   -- Prepare next screen variable
   SET @cID = ''
   SET @cOutField01 = '' -- ID

   -- Go back to ID screen
   SET @nScn  = @nScn  - 2
   SET @nStep = @nStep - 2
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
      Func = @nFunc,
      Step = @nStep,
      Scn = @nScn,

      Facility  = @cFacility,
      StorerKey = @cStorer,
      -- UserName  = @cUserName,

      V_ID       = @cID,
      V_String1  = @cSuggestedLOC,
      V_String2  = @cFinalLOC,
      V_String3  = @cLOCAssigned,
      V_String4  = @cExtendedUpdateSP,
      V_String5  = @cExtendedValidateSP,

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