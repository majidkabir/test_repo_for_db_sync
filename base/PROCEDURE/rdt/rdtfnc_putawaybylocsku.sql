SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_PutawayByLOCSKU                                    */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2019-08-15 1.0  Ung      WMS-10056 Created                                 */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdtfnc_PutawayByLOCSKU] (
   @nMobile    INT,
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Other var use in this stor proc
DECLARE
   @bSuccess         INT,
   @cChkFacility     NVARCHAR( 5), 
   @cOption          NVARCHAR( 1),
   @nTranCount       INT, 
   @nRowCount        INT

-- Variable for RDT.RDTMobRec
DECLARE
   @nFunc            INT,
   @nScn             INT,
   @nStep            INT,
   @cLangCode        NVARCHAR( 3),
   @nInputKey        INT,
   @nMenu            INT,

   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),

   @cID              NVARCHAR( 18),
   @cLOC             NVARCHAR( 10),
   @cSKU             NVARCHAR( 30), 
   @cSKUDesc         NVARCHAR( 60),

   @cSuggestedLOC    NVARCHAR( 10),
   @cFinalLOC        NVARCHAR( 10),

   @nQTY_PWY         INT,
   @nQTY             INT,
   @nPABookingKey    INT, 
   
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20), 
   @cExtendedInfoSP     NVARCHAR( 20), 
   @cPAMatchSuggestLOC  NVARCHAR( 1),
   @cDecodeSP           NVARCHAR( 20),
   @cBarcode            NVARCHAR( 60),

   @cInField01 NVARCHAR( 60),  @cOutField01 NVARCHAR( 60),  @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),  @cOutField02 NVARCHAR( 60),  @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),  @cOutField03 NVARCHAR( 60),  @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),  @cOutField04 NVARCHAR( 60),  @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),  @cOutField05 NVARCHAR( 60),  @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),  @cOutField06 NVARCHAR( 60),  @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),  @cOutField07 NVARCHAR( 60),  @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),  @cOutField08 NVARCHAR( 60),  @cFieldAttr08 NVARCHAR( 1), 
   @cInField09 NVARCHAR( 60),  @cOutField09 NVARCHAR( 60),  @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),  @cOutField10 NVARCHAR( 60),  @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),  @cOutField11 NVARCHAR( 60),  @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),  @cOutField12 NVARCHAR( 60),  @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),  @cOutField13 NVARCHAR( 60),  @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),  @cOutField14 NVARCHAR( 60),  @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),  @cOutField15 NVARCHAR( 60),  @cFieldAttr15 NVARCHAR( 1)

-- Getting Mobile information
SELECT
   @nFunc         = Func,
   @nScn          = Scn,
   @nStep         = Step,
   @nInputKey     = InputKey,
   @nMenu         = Menu,
   @cLangCode     = Lang_code,
                  
   @cStorerKey    = StorerKey,
   @cFacility     = Facility,
                  
   @cID           = V_ID,
   @cLOC          = V_LOC,
   @cSKU          = V_SKU,
   @cSKUDesc      = V_SKUDescr,

   @cSuggestedLOC = V_String1,
   @cFinalLOC     = V_String2,
   
   @nQTY_PWY      = V_Integer1,
   @nPABookingKey = V_Integer2, 
   
   @cExtendedUpdateSP   = V_String20, 
   @cExtendedValidateSP = V_String21, 
   @cExtendedInfoSP     = V_String22, 
   @cPAMatchSuggestLOC  = V_String23, 
   @cDecodeSP           = V_String24, 

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

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 745
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Func = 745. Menu
   IF @nStep = 1 GOTO Step_1   -- Scn  = 5570. LOC
   IF @nStep = 2 GOTO Step_2   -- Scn  = 5571. SKU
   IF @nStep = 3 GOTO Step_3   -- Scn  = 5573. Suggested LOC, final LOC
   IF @nStep = 4 GOTO Step_4   -- Scn  = 5574. Successful putaway
   IF @nStep = 5 GOTO Step_5   -- Scn  = 5575. LOC not match. Proceed?
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 745. Menu
   @nStep = 0
********************************************************************************/
Step_0:
BEGIN
   -- Get storer configure
   SET @cPAMatchSuggestLOC = rdt.RDTGetConfig( @nFunc, 'PutawayMatchSuggestLOC', @cStorerKey)
   
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'  
      SET @cExtendedValidateSP = ''

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerkey  = @cStorerKey

   -- Prepare next screen var
   SET @cOutField01 = '' -- ID
   SET @cOutField02 = '' -- UCC
   SET @cOutField03 = '' -- LOC

   -- Set the entry point
   SET @nScn = 5570
   SET @nStep = 1

END
GOTO Quit


/********************************************************************************
Step 1. Scn = 5570
   LOC   (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField01

      -- Check blank
      IF @cLOC = ''
      BEGIN
         SET @nErrNo = 143251
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need LOC
         GOTO Quit
      END

      -- Get LOC info
      SELECT @cChkFacility = Facility 
      FROM LOC WITH (NOLOCK) 
      WHERE LOC = @cLOC

      -- Check LOC valid
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 143252
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid LOC
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check different facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 143253
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff facility
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Prepare next screen variable
      SET @cOutField01 = @cLOC
      SET @cOutField02 = '' -- SKU

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerkey  = @cStorerKey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 5571
   LOC   (field01)
   SKU   (field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField02
      SET @cBarcode = @cInField02

      -- Check blank
      IF @cBarcode = ''
      BEGIN
         SET @nErrNo = 143254
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need SKU
         GOTO Quit
      END

      -- Standard decode
      IF @cDecodeSP = '1'
      BEGIN
         EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
            @cUPC    = @cSKU    OUTPUT, 
            @nErrNo  = @nErrNo  OUTPUT, 
            @cErrMsg = @cErrMsg OUTPUT,
            @cType   = 'UPC'
 
         IF @nErrNo <> 0
            GOTO Quit
      END

      -- Get SKU barcode count
      DECLARE @nSKUCnt INT
      EXEC rdt.rdt_GETSKUCNT
          @cStorerkey  = @cStorerKey
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @bSuccess      OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Check SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 143255
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Check multi SKU barcode
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 143256
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Get SKU code
      EXEC rdt.rdt_GETSKU
          @cStorerkey  = @cStorerKey
         ,@cSKU        = @cSKU          OUTPUT
         ,@bSuccess    = @bSuccess      OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Get SKU info
      SELECT @cSKUDesc = Descr
      FROM dbo.SKU (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      -- Prepare next screen variable
      SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20)

      -- Get QTY
      SELECT TOP 1
        @nQTY_PWY = 1, -- Hardcode QTY = 1, for piece putaway
        @cID = ID
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE LOC = @cLOC
         AND StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen > 0 THEN QTYReplen ELSE 0 END)) > 0

      -- Check SKU
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 143257
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No QTY to PA
         SET @cOutField02 = ''
         GOTO Quit
      END

      /*
      -- Check multi ID
      IF @nRowCount > 1
      BEGIN
         SET @nErrNo = 143258
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKU multi ID
         SET @cOutField02 = ''
         GOTO Quit
      END
      */
      
      -- Get suggest LOC
      DECLARE @nPAErrNo INT
      SET @nPAErrNo = 0
      SET @nPABookingKey = 0
      EXEC rdt.rdt_PutawayByLOCSKU_GetSuggestLOC @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility
         ,@cLOC
         ,@cID
         ,@cSKU
         ,@nQTY_PWY
         ,@cSuggestedLOC   OUTPUT
         ,@nPABookingKey   OUTPUT
         ,@nPAErrNo        OUTPUT
         ,@cErrMsg         OUTPUT
      IF @nPAErrNo <> 0 AND
         @nPAErrNo <> -1 -- No suggested LOC
      BEGIN
         SET @nErrNo = @nPAErrNo
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Check any suggested LOC
      IF @cSuggestedLOC = ''
      BEGIN
         SET @nErrNo = 143259
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoSuitableLOC
      END
      ELSE IF @cSuggestedLOC = 'SEE_SUPV'
      BEGIN
         SET @nErrNo = 143260
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoSuggestedLOC
      END

      -- Prepare next screen variable
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20)
      SET @cOutField04 = CAST( @nQTY_PWY AS NVARCHAR( 5))
      SET @cOutField05 = @cSuggestedLOC
      SET @cOutField06 = '' -- FinalLOC

      -- Go to prev screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen variable
      SET @cOutField01 = '' -- LOC

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 5572
   SKU            (field01)
   Desc 1         (field02)
   Desc 2         (field03)
   QTY            (field04)
   Suggested LOC  (field05)
   Final LOC      (field06, input)
********************************************************************************/
Step_3:
BEGIN
 IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFinalLOC = @cInField06

      -- Check blank 
      IF @cFinalLOC = ''
      BEGIN
         SET @nErrNo = 143261
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need Final LOC
         GOTO Quit
      END

      -- Get LOC info
      SELECT @cChkFacility = Facility 
      FROM LOC WITH (NOLOCK) 
      WHERE LOC = @cFinalLOC

      -- Check LOC valid
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 143262
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid LOC
         SET @cOutField06 = ''
         GOTO Quit
      END

      -- Check different facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 143263
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff facility
         SET @cOutField06 = ''
         GOTO Quit
      END

      -- Check if suggested LOC match
      IF @cSuggestedLOC <> '' AND @cSuggestedLOC <> @cFinalLOC
      BEGIN
         IF @cPAMatchSuggestLOC = '1'
         BEGIN
            SET @nErrNo = 143264
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LOC Not Match
            GOTO Quit
         END
         ELSE IF @cPAMatchSuggestLOC = '2'
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = '' -- Option
            
            -- Go to LOC not match screen
            SET @nScn = @nScn + 2
            SET @nStep = @nStep + 2
            
            GOTO Quit
         END
      END  

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_PutawayByLOCSKU -- For rollback or commit only our own transaction

      -- Putaway
      EXEC rdt.rdt_PutawayByLOCSKU_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 
         @cLOC, 
         @cID, 
         @cSKU, 
         @nQTY_PWY, 
         @cFinalLoc, 
         @cSuggestedLOC, 
         @nPABookingKey OUTPUT,
         @nErrNo        OUTPUT, 
         @cErrMsg       OUTPUT 
      IF @nErrNo <> 0 
      BEGIN
         ROLLBACK TRAN rdtfnc_PutawayByLOCSKU
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Quit
      END
      
      COMMIT TRAN rdtfnc_PutawayByLOCSKU
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Unlock current session suggested LOC
      IF @nPABookingKey <> 0
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
            ,'' --FromLOC
            ,'' --FromID
            ,'' --SuggLOC
            ,'' --Storer
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0  
            GOTO Quit
         
         SET @nPABookingKey = 0
      END

      -- Prepare next screen variable
      SET @cOutField01 = @cLOC
      SET @cOutField02 = '' -- SKU

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/********************************************************************************
Step 4. scn = 5573. Message screen
   Successful putaway
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Prepare next screen variable
      SET @cOutField01 = @cLOC
      SET @cOutField02 = '' -- SKU

      -- Go back to SKU screen
      SET @nScn  = @nScn - 2
      SET @nStep = @nStep - 2
   END
END
GOTO Quit


/********************************************************************************
Step 5. Scn = 5574.
   LOC not match. Proceed?
   1 = YES
   2 = NO
   OPTION (Input, Field01)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1
   BEGIN
      SET @cOption = @cInField01

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 143265
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Option req
         GOTO Quit
      END
      
      -- Check optin valid
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 143266
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Invalid Option
         SET @cOutField01 = ''
         GOTO Quit
      END

      IF @cOption = '1' -- YES
      BEGIN
         -- Putaway
         EXEC rdt.rdt_PutawayByLOCSKU_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 
            @cLOC, 
            @cID, 
            @cSKU, 
            @nQTY_PWY, 
            @cFinalLoc, 
            @cSuggestedLOC, 
            @nPABookingKey OUTPUT,
            @nErrNo        OUTPUT, 
            @cErrMsg       OUTPUT 
         IF @nErrNo <> 0
            GOTO Quit

         -- Go to successful putaway screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1

         GOTO Quit
      END
   END

   -- Prepare next screen var
   SET @cOutField01 = @cSKU
   SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)
   SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20)
   SET @cOutField04 = CAST( @nQTY_PWY AS NVARCHAR( 5))
   SET @cOutField05 = @cSuggestedLOC
   SET @cOutField06 = '' -- FinalLOC

   -- Go to suggested LOC screen
   SET @nScn = @nScn - 2
   SET @nStep = @nStep - 2
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
      Func = @nFunc,
      Step = @nStep,
      Scn = @nScn,

      V_ID       = @cID,
      V_LOC      = @cLOC,
      V_SKU      = @cSKU,
      V_SKUDescr = @cSKUDesc,

      V_String1  = @cSuggestedLOC,
      V_String2  = @cFinalLOC,

      V_Integer1 = @nQTY_PWY,
      V_Integer2 = @nPABookingKey, 
      
      V_String20 = @cExtendedUpdateSP, 
      V_String21 = @cExtendedValidateSP, 
      V_String22 = @cExtendedInfoSP, 
      V_String23 = @cPAMatchSuggestLOC, 
      V_String24 = @cDecodeSP, 

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