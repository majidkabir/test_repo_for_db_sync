SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/********************************************************************************/
/* Store procedure: rdtfnc_InboundSKUPutaway                                    */
/* Copyright      : IDS                                                         */
/*                                                                              */
/* Purpose: Putaway by ID, SKU.                                                 */
/*                                                                              */
/* Modifications log:                                                           */
/*                                                                              */
/* Date         Rev   Author   Purposes                                         */
/* 01-JUN-2016  1.0   James    SOS370456 - Created                              */
/* 22-AUG-2016  1.1   James    Remove decode error (james01)                    */
/* 30-SEP-2016  1.2   Ung      Performance tuning                               */
/* 16-JUN-2017  1.3   James    Bug fix on get next loc (james02)                */
/* 10-OCT-2018  1.4   Gan      Performance tuning                               */
/* 08-JUL-2019  1.5   Ung      Fix performance tuning                           */
/********************************************************************************/

CREATE PROC [RDT].[rdtfnc_InboundSKUPutaway] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

-- Misc variable
DECLARE
   @cSQL           NVARCHAR( MAX),
   @cSQLParam      NVARCHAR( MAX)


-- Define a variable
DECLARE  
   @nFunc        			INT,  
   @nScn         			INT,  
   @nStep        			INT,  
   @cLangCode    			NVARCHAR( 3),  
   @nInputKey    			INT,  
   @nMenu        			INT,  
   @cPrinter     			NVARCHAR(10),  
   @cUserName    			NVARCHAR(18),  
   @cStorerKey   			NVARCHAR(15),  
   @cFacility    			NVARCHAR( 5),  
   @cReceiptKey  			NVARCHAR( 10),  
   @cPOKey       			NVARCHAR( 10),  
   @cPOLineNumber       NVARCHAR( 5),  
   @cSKU         			NVARCHAR( 20),  
   @cQTY         			NVARCHAR( 10),  
   @nQTY                INT, 
   @cCaseID             NVARCHAR( 20),
   @cToCaseID           NVARCHAR( 20),
   @cFromID             NVARCHAR( 18),
   @cFromLOC            NVARCHAR( 10),
   @cToLOC              NVARCHAR( 10),
   @cSuggLOC            NVARCHAR( 10),
   @cPUOM               NVARCHAR( 10),
   @cMUOM_Desc          NVARCHAR( 5),
   @cPUOM_Desc          NVARCHAR( 5),
   @cMoveQTYAlloc       NVARCHAR( 1),
   @cMoveQTYPick        NVARCHAR( 1),
   @cPickAndDropLOC     NVARCHAR( 10),
   @cCurToLOC           NVARCHAR( 10),
   @cCurSKU             NVARCHAR( 20),
   @cSuggestedSKU       NVARCHAR( 20),
   @nPABookingKey       INT,
   @nPUOM_Div           INT,
   @nPQTY_PWY           INT,
   @nMQTY_PWY           INT,
   @nQTY_PWY            INT,
   @nPQTY               INT,
   @nMQTY               INT,
   @nActPQTY            INT,
   @nActMQTY            INT,
   @nActQTY             INT,
   @nTranCount          INT,
   @b_Success           INT,
   @cPQTY               NVARCHAR( 5),
   @cMQTY               NVARCHAR( 5),
   @cPASuggestLOCSKU_SP NVARCHAR( 20),
   @cDecodeSP           NVARCHAR( 20),
   @cBarcode            NVARCHAR( 60),
   @cSKUDesc            NVARCHAR( 60),
   @cUPC                NVARCHAR( 30),
   @cActPQTY            NVARCHAR( 5),      
   @cActMQTY            NVARCHAR( 5),
   @cLottable01         NVARCHAR( 18),
   @cLottable02         NVARCHAR( 18),
   @cLottable03         NVARCHAR( 18),
   @dLottable04         DATETIME,
   @dLottable05         DATETIME,
   @cLottable06         NVARCHAR( 30),
   @cLottable07         NVARCHAR( 30),
   @cLottable08         NVARCHAR( 30),
   @cLottable09         NVARCHAR( 30),
   @cLottable10         NVARCHAR( 30),
   @cLottable11         NVARCHAR( 30),
   @cLottable12         NVARCHAR( 30),
   @dLottable13         DATETIME,
   @dLottable14         DATETIME,
   @dLottable15         DATETIME,
   @cCurToLOCLogicalLoc NVARCHAR( 10), -- (james02)

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

DECLARE
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),
   @c_oFieled11 NVARCHAR(20), @c_oFieled12 NVARCHAR(20),
   @c_oFieled13 NVARCHAR(20), @c_oFieled14 NVARCHAR(20),
   @c_oFieled15 NVARCHAR(20),
   @cDecodeLabelNo       NVARCHAR( 20)

DECLARE
   @cErrMsg1    NVARCHAR( 20), @cErrMsg2    NVARCHAR( 20),
   @cErrMsg3    NVARCHAR( 20), @cErrMsg4    NVARCHAR( 20),
   @cErrMsg5    NVARCHAR( 20)

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
   @cUserName        = UserName,

   @cSKU        = V_SKU,
   @nQTY        = V_Qty,
   @cFromLOC    = V_LOC,
   @cFromID     = V_ID,
   
   @nPUOM_Div   = V_PUOM_Div,
   @nPQTY       = V_PQTY,
   @nMQTY       = V_MQTY,
   
   @nPQTY_PWY     = V_Integer1,
   @nMQTY_PWY     = V_Integer2,
   @nQTY_PWY      = V_Integer3,
   @nPABookingKey = V_Integer6,

   @cToLOC      = V_String1,
   @cMUOM_Desc  = V_String2,
   @cPUOM_Desc  = V_String3,
  -- @nPUOM_Div   = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4, 5), 0) = 1 THEN LEFT( V_String4, 5) ELSE 0 END,
  -- @nPQTY_PWY   = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5, 5), 0) = 1 THEN LEFT( V_String5, 5) ELSE 0 END,
  -- @nMQTY_PWY   = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6, 5), 0) = 1 THEN LEFT( V_String6, 5) ELSE 0 END,
  -- @nQTY_PWY    = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String7, 5), 0) = 1 THEN LEFT( V_String7, 5) ELSE 0 END,
  -- @nPQTY       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String8, 5), 0) = 1 THEN LEFT( V_String8, 5) ELSE 0 END,
  -- @nMQTY       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String9, 5), 0) = 1 THEN LEFT( V_String9, 5) ELSE 0 END,
   @cDecodeSP   = V_String10,
   @cSuggLOC    = V_String12,
   @cMoveQTYAlloc = V_String13,
   @cMoveQTYPick  = V_String14,
  -- @nPABookingKey = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String15, 10), 0) = 1 THEN LEFT( V_String15, 10) ELSE 0 END,    
   @cPUOM         = V_String16,
   
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

FROM   RDT.RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile

-- Redirect to respective screen  
IF @nFunc = 743  
BEGIN  
   IF @nStep = 0 GOTO Step_0   -- Func = 743. Menu  
   IF @nStep = 1 GOTO Step_1   -- Scn = 4670. ID  
   IF @nStep = 2 GOTO Step_2   -- Scn = 4671. ID, LOC, LOC (input)  
   IF @nStep = 3 GOTO Step_3   -- Scn = 4672. ID, LOC, SKU/UPC, SKU/UPC (input)  
   IF @nStep = 4 GOTO Step_4   -- Scn = 4673. LOC, SKU/UPC, SUGG QTY, CFM QTY (input)  
   IF @nStep = 5 GOTO Step_5   -- Scn = 4674. MESSAGE  

END  

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 743)
********************************************************************************/
Step_0:
BEGIN
   -- Get preferred UOM
   SELECT @cPUOM = DefaultUOM FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = @cUserName

   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''

   SET @cPASuggestLOCSKU_SP = rdt.RDTGetConfig( @nFunc, 'PASuggestLOCSKU_SP', @cStorerKey)
   IF @cPASuggestLOCSKU_SP = '0'
      SET @cPASuggestLOCSKU_SP = ''

   SET @cMoveQTYAlloc = rdt.rdtGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)
   SET @cMoveQTYPick = rdt.rdtGetConfig( @nFunc, 'MoveQTYPick', @cStorerKey)


   -- Set the entry point
   SET @nScn  = 4670
   SET @nStep = 1

   -- initialise all variable
   SET @cFromID = ''
 
   -- Init screen
   SET @cOutField01 = ''

    -- EventLog - Sign In Function
    EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerKey,
     @nStep       = @nStep
END
GOTO Quit

/********************************************************************************
Step 1. screen = 4620
   ID      (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFromID = @cInField01
  
      -- Validate blank
      IF ISNULL( @cFromID, '') = '' 
      BEGIN  
         SET @nErrNo = 100951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Value required'  
         GOTO Step_1_Fail
      END  

      -- Check valid ID
      IF NOT EXISTS ( 
         SELECT 1
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE Facility = @cFacility
         AND   ID = @cFromID
         AND  (QTY - QTYAllocated - QTYPicked - ABS( QTYReplen)) > 0)
      BEGIN  
         SET @nErrNo = 100952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid id'  
         GOTO Step_1_Fail
      END  

      -- Get ID info
      SELECT TOP 1 
         @cFromLOC = LOC.LOC
      FROM LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility
         AND LLI.ID = @cFromID 
         AND LLI.QTY - 
            (CASE WHEN @cMoveQTYAlloc = '0' THEN LLI.QTYAllocated ELSE 0 END) - 
            (CASE WHEN @cMoveQTYPick = '0' THEN LLI.QTYPicked ELSE 0 END) > 0 

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_InboundSKUPutaway -- For rollback or commit only our own transaction

      -- Get suggest LOC
      DECLARE @nPAErrNo INT
      SET @nPAErrNo = 0
      SET @nPABookingKey = 0
      EXEC rdt.rdt_InboundSKUPutaway_GetSuggestLOC @nMobile, @nFunc, @cLangCode, @cUserName, @cStorerKey, @cFacility
         ,@cFromLOC
         ,@cFromID
         ,@cSuggLOC        OUTPUT
         ,@cPickAndDropLOC OUTPUT
         ,@nPABookingKey   OUTPUT
         ,@nPAErrNo        OUTPUT
         ,@cErrMsg         OUTPUT
      IF @nPAErrNo <> 0 AND
         @nPAErrNo <> -1 -- No suggested LOC
      BEGIN
         SET @nErrNo = @nPAErrNo
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         
         ROLLBACK TRAN rdtfnc_InboundSKUPutaway -- Only rollback change made here
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Step_1_Fail
      END

      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      SET @cToLOC = ''
      SELECT TOP 1 @cToLOC = SuggestedLOC 
      FROM dbo.RFPutaway RF WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( RF.SuggestedLOC = LOC.LOC)
      WHERE FROMID = @cFromID
      AND   Ptcid = @cUserName
      AND   StorerKey = @cStorerKey
      AND   Qty > 0
      ORDER BY LOC.LogicalLocation

      -- Check no suggest LOC (but allow user go to next screen scan another LOC)
      IF ISNULL( @cToLOC, '') = ''
      BEGIN
         SET @nErrNo = 100953
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoSuitableLOC
         GOTO Step_1_Fail         
      END

      SET @cOutField01 = @cFromID
      SET @cOutField02 = @cToLOC
      SET @cOutField03 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'PutawayDefaultSuggestLOC', @cStorerKey) = '1'
                         THEN @cToLOC ELSE '' END

      -- Go to screen 2
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog - Sign Out Function
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

      SET @cOutField01 = ''

      SET @cFromID = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cOutField01 = ''

      SET @cFromID = ''
   END
END
GOTO Quit

/********************************************************************************
Step 2. screen = 4621
   ID      (Field01)
   LOC     (Field02)
   LOC     (Field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      IF ISNULL( @cInField03, '') = ''
      BEGIN  
         IF rdt.RDTGetConfig( @nFunc, 'PutawayAllowSkipLOC', @cStorerKey) = '1'
         BEGIN
            -- Remember current variable
            SET @cCurToLOC = @cToLOC
            SET @cCurToLOCLogicalLoc = ''

            SELECT @cCurToLOCLogicalLoc = LogicalLocation
            FROM dbo.LOC WITH (NOLOCK)
            WHERE LOC = @cCurToLOC
            AND   Facility = @cFacility

            SET @cToLOC = ''
            SELECT TOP 1 @cToLOC = SuggestedLOC 
            FROM dbo.RFPutaway RF WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( RF.SuggestedLOC = LOC.LOC)
            WHERE FROMID = @cFromID
            AND   Ptcid = @cUserName
            AND   StorerKey = @cStorerKey
            AND   Qty > 0
            AND   RTRIM( LOC.LogicalLocation) + SuggestedLOC > RTRIM( @cCurToLOCLogicalLoc) + @cCurToLOC
            ORDER BY LOC.LogicalLocation, LOC.LOC

            -- Check no suggest LOC (but allow user go to next screen scan another LOC)
            IF ISNULL( @cToLOC, '') = ''
            BEGIN
               SET @nErrNo = 100970
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No more loc
               SET @cToLOC = @cCurToLOC   -- Assign back the loc
               GOTO Step_2_Fail         
            END

            SET @cOutField01 = @cFromID
            SET @cOutField02 = @cToLOC
            SET @cOutField03 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'PutawayDefaultSuggestLOC', @cStorerKey) = '1'
                               THEN @cToLOC ELSE '' END

            GOTO Quit
         END
         ELSE
         BEGIN
            SET @nErrNo = 100954
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Loc required'  
            GOTO Step_2_Fail
         END
      END

      IF NOT EXISTS ( SELECT 1 
                      FROM dbo.LOC WITH (NOLOCK) 
                      WHERE Facility = @cFacility
                      AND   LOC = @cInField03)
      BEGIN  
         SET @nErrNo = 100955
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid to loc'  
         GOTO Step_2_Fail
      END

      IF @cInField03 <> @cToLOC 
      BEGIN  
         IF rdt.RDTGetConfig( @nFunc, 'PutawayMatchSuggestLOC', @cStorerKey) = '1'
         BEGIN
            SET @nErrNo = 100956
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Loc not match'  
            GOTO Step_2_Fail
         END
         ELSE
         BEGIN
            SET @nTranCount = @@TRANCOUNT
            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdtfnc_InboundSKUPutaway -- For rollback or commit only our own transaction

            -- Unlock current suggested LOC by using PABokking key
            SET @nPABookingKey = 0
            DECLARE CUR_UNLOCK CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT PABookingKey, SKU
            FROM dbo.RFPutaway WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   Ptcid = @cUserName
            AND   FromID = @cFromID
            AND   SuggestedLOC = @cToLOC
            OPEN CUR_UNLOCK
            FETCH NEXT FROM CUR_UNLOCK INTO @nPABookingKey, @cSKU
            WHILE @@FETCH_STATUS <> -1
            BEGIN

               EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'UNLOCK'
                  ,'' --FromLOC
                  ,''
                  ,'' --cSuggLOC
                  ,'' --Storer
                  ,@nErrNo  OUTPUT
                  ,@cErrMsg OUTPUT
                  ,'', 0, '', '', '', '', 0
                  ,@nPABookingKey OUTPUT

               IF @nErrNo <> 0  
               BEGIN
                  ROLLBACK TRAN rdtfnc_InboundSKUPutaway -- Only rollback change made here
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN
               
                  CLOSE CUR_UNLOCK
                  DEALLOCATE CUR_UNLOCK
                  GOTO Step_2_Fail
               END

               -- Lock the new suggested loc key in by user            
               SET @nPABookingKey = 0
               EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
                  ,@cFromLOC
                  ,@cFromID
                  ,@cInField03
                  ,@cStorerKey
                  ,@nErrNo  OUTPUT
                  ,@cErrMsg OUTPUT
                  ,@cSKU
                  ,@nPABookingKey = @nPABookingKey OUTPUT            
               END

               IF @nErrNo <> 0  
               BEGIN
                  ROLLBACK TRAN rdtfnc_InboundSKUPutaway -- Only rollback change made here
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN
               
                  CLOSE CUR_UNLOCK
                  DEALLOCATE CUR_UNLOCK
                  GOTO Step_2_Fail
               END

               FETCH NEXT FROM CUR_UNLOCK INTO @nPABookingKey, @cSKU
            END
            CLOSE CUR_UNLOCK
            DEALLOCATE CUR_UNLOCK

            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN

      END

      SET @cToLOC = @cInField03

      SET @cSKU = ''
      SET @nQTY = 0
      
      SELECT TOP 1 @cSKU = SKU, 
                   @nQTY = ISNULL( SUM( QTY), 0)
      FROM dbo.RFPutaway RF WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( RF.SuggestedLOC = LOC.LOC)
      WHERE FROMID = @cFromID
      AND   Ptcid = @cUserName
      AND   StorerKey = @cStorerKey
      AND   SuggestedLOC = @cToLOC
      AND   Qty > 0
      GROUP BY SKU
      ORDER BY SKU

      IF ISNULL( @cSKU, '') = ''
      BEGIN
         SET @nErrNo = 100957
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No suggest sku'  
         GOTO Step_2_Fail
      END

      SET @cOutField01 = @cFromID
      SET @cOutField02 = @cToLOC
      SET @cOutField03 = @cSKU
      SET @cOutField04 = ''

      -- Go to screen 3
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1 
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Unlock current session suggested LOC by username + id
      IF @nPABookingKey <> 0
      BEGIN
         SET @nPABookingKey = 0
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'UNLOCK'
            ,'' --FromLOC
            ,@cFromID
            ,'' --cSuggLOC
            ,'' --Storer
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,'', 0, '', '', '', '', 0
            ,@nPABookingKey OUTPUT

         IF @nErrNo <> 0  
            GOTO Step_2_Fail
         
         SET @nPABookingKey = 0
      END
   
      SET @cOutField01 = ''

      SET @cFromID = ''

      -- Go back screen 1
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cOutField03 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 3. screen = 4622
   ID      (Field01)
   LOC     (Field02)
   SKU/UPC (Field03) 
   SKU/UPC (Field04, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cSuggestedSKU = @cOutField03
      SET @cSKU = @cInField04

      IF ISNULL( @cSKU, '') = ''
      BEGIN  
         SET @nErrNo = 100958
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Value required'  
         GOTO Step_3_Fail
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         SET @cBarcode = @cSKU
         SET @cUPC = ''
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
               @cFromID     OUTPUT, @cUPC        OUTPUT, @nQTY        OUTPUT, 
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            SET @cSKU = @cUPC
         END
         
         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC, @cBarcode, @cFieldName, ' +
               ' @cID         OUTPUT, @cSKU        OUTPUT, @nQTY        OUTPUT, ' +
               ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT, ' +
               ' @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT, ' +
               ' @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cReceiptKey  NVARCHAR( 10), ' +
               ' @cPOKey       NVARCHAR( 10), ' +
               ' @cLOC         NVARCHAR( 10), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cFieldName   NVARCHAR( 10), ' +
               ' @cID          NVARCHAR( 18)  OUTPUT, ' +
               ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
               ' @nQTY         INT            OUTPUT, ' +
               ' @cLottable01  NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable02  NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable03  NVARCHAR( 18)  OUTPUT, ' +
               ' @dLottable04  DATETIME       OUTPUT, ' +
               ' @dLottable05  DATETIME       OUTPUT, ' +
               ' @cLottable06  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable07  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable08  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable09  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable10  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable11  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable12  NVARCHAR( 30)  OUTPUT, ' +
               ' @dLottable13  DATETIME       OUTPUT, ' +
               ' @dLottable14  DATETIME       OUTPUT, ' +
               ' @dLottable15  DATETIME       OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cToLOC, @cBarcode, 'SKU',
               @cFromID     OUTPUT, @cSKU        OUTPUT, @nQTY        OUTPUT,
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT
         END
      END

      -- Get SKU barcode count
      DECLARE @nSKUCnt INT
      EXEC rdt.rdt_GETSKUCNT
          @cStorerkey  = @cStorerKey
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Check SKU
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 100959
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         GOTO Step_3_Fail
      END

      -- Check barcode return multi SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 100960
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
         GOTO Step_3_Fail
      END

      -- Get SKU code
      EXEC rdt.rdt_GETSKU
          @cStorerkey  = @cStorerKey
         ,@cSKU        = @cSKU          OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      IF @cSKU <> @cSuggestedSKU 
      BEGIN  
         SET @nErrNo = 100961
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ucc not match'  
         GOTO Step_3_Fail
      END

      -- Get SKU info
      SELECT
         @cSKUDesc = S.Descr,
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
         @nPUOM_Div = CAST(
            CASE @cPUOM
               WHEN '2' THEN Pack.CaseCNT
               WHEN '3' THEN Pack.InnerPack
               WHEN '6' THEN Pack.QTY
               WHEN '1' THEN Pack.Pallet
               WHEN '4' THEN Pack.OtherUnit1
               WHEN '5' THEN Pack.OtherUnit2
            END AS INT)
      FROM dbo.SKU S WITH (NOLOCK)
      JOIN dbo.Pack Pack WITH (NOLOCK) ON (S.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cSKU

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY_PWY = 0
         SET @nPQTY  = 0
         SET @nMQTY_PWY = @nQTY
         SET @cFieldAttr10 = 'O' -- @nPQTY_PWY
         SET @cInField10 = ''
      END
      ELSE
      BEGIN
         SET @nPQTY_PWY = @nQTY / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_PWY = @nQTY % @nPUOM_Div -- Calc the remaining in master unit
      END

      -- Prev next screen
      SET @cOutField01 = @cToLOC
      SET @cOutField02 = @cSKU
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20) -- SKU desc 2
      SET @cOutField05 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
      SET @cOutField06 = @cPUOM_Desc
      SET @cOutField07 = @cMUOM_Desc
      SET @cOutField08 = CASE WHEN @cFieldAttr10 = 'O' THEN '' ELSE CAST( @nPQTY_PWY AS NVARCHAR( 5)) END
      SET @cOutField09 = CAST( @nMQTY_PWY AS NVARCHAR( 5))
      SET @cOutField10 = ''
      SET @cOutField11 = ''

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1 
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = @cFromID
      SET @cOutField02 = @cToLOC
      SET @cOutField03 = ''

      -- Go back screen 2
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cOutField04 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 4. screen = 4623
   LOC      (Field01)
   SKU      (Field02) 
   QTY PWY  (Field03, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- screen mapping
      SET @cPQTY = ISNULL( @cInField10, '')
      SET @cMQTY = @cInField11

      -- Validate PQTY
      IF @cPQTY = '' SET @cPQTY = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 100962
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 13 -- PQTY
         GOTO Step_4_Fail
      END

      -- Validate MQTY
      IF @cMQTY  = '' SET @cMQTY  = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 100963
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 14 -- MQTY
         GOTO Step_4_Fail
      END

      -- Calc total QTY in master UOM
      SET @nPQTY = CAST( @cPQTY AS INT)
      SET @nMQTY = CAST( @cMQTY AS INT)
      SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nQTY = @nQTY + @nMQTY

      -- Calc total QTY in master UOM  
      SET @nActPQTY = CAST( @cOutField08 AS INT)
      SET @nActMQTY = CAST( @cOutField09 AS INT)
      SET @nQTY_PWY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @nActPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nQTY_PWY = @nQTY_PWY + @nActMQTY

      -- Validate QTY
      IF @nQTY = 0
      BEGIN
         SET @nErrNo = 100964
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- QTY needed
         GOTO Step_4_Fail
      END

      IF rdt.RDTGetConfig( @nFunc, 'PutawayBySKUMatchQty', @cStorerKey) = '1'    -- (james01)
      BEGIN
         IF @nActQTY <> @nQTY AND ISNULL(@nActQTY, 0) > 0
         BEGIN
            SET @nErrNo = 100965
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- QTY NOT MATCH
            GOTO Step_4_Fail
         END
      END

      -- Validate QTY to move more than QTY avail
      IF @nQTY > @nQTY_PWY
      BEGIN
         SET @nErrNo = 100966
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- QTYPWY NotEnuf
         GOTO Step_4_Fail
      END

      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_InboundSKUPutaway -- For rollback or commit only our own transaction

      -- Unlock SuggestedLOC
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'UNLOCK'
         ,@cFromLOC
         ,@cFromID
         ,@cToLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cSKU        = @cSKU
         ,@nPutawayQTY = @nQTY

      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN rdtfnc_InboundSKUPutaway -- Only rollback change made here
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Step_4_Fail
      END
      
      -- Execute putaway process
      EXEC rdt.rdt_Putaway @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility,
         '', -- optional
         @cFromLOC,
         @cFromID,
         @cStorerKey,
         @cSKU,
         @nQTY,
         @cToLOC,
         '',   -- optional
         '',   -- optional 
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT

      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN rdtfnc_InboundSKUPutaway -- Only rollback change made here
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Step_4_Fail
      END

      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = @cFromID
      SET @cOutField02 = @cToLOC
      SET @cOutField03 = @cSKU
      SET @cOutField04 = ''

      -- Go back screen 3
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_4_Fail:


END
GOTO Quit

/********************************************************************************
Step 5. scn = 2884. Message screen
   Successful putaway
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Remember current variable
      SET @cCurToLOC = @cToLOC
      SET @cCurSKU = @cSKU
      SET @cCurToLOCLogicalLoc = ''

      SELECT @cCurToLOCLogicalLoc = LogicalLocation
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cCurToLOC
      AND   Facility = @cFacility

      -- Get next SKU to putaway
      SET @cSKU = ''
      SET @nQTY = 0
      SELECT TOP 1 @cSKU = SKU, 
                   @nQTY = ISNULL( SUM( QTY), 0)
      FROM dbo.RFPutaway RF WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( RF.SuggestedLOC = LOC.LOC)
      WHERE FROMID = @cFromID
      AND   Ptcid = @cUserName
      AND   StorerKey = @cStorerKey
      AND   SuggestedLOC = @cToLOC
      AND   Qty > 0
      AND   SKU > @cCurSKU
      GROUP BY SKU
      ORDER BY SKU

      IF ISNULL( @cSKU, '') <> ''
      BEGIN
         SET @cOutField01 = @cFromID
         SET @cOutField02 = @cToLOC
         SET @cOutField03 = @cSKU
         SET @cOutField04 = ''

         -- Go to screen 3
         SET @nScn = @nScn - 2  
         SET @nStep = @nStep - 2 
         
         GOTO Quit
      END

      -- Get next available loc to putaway
      SET @cToLOC = ''
      SELECT TOP 1 @cToLOC = SuggestedLOC 
      FROM dbo.RFPutaway RF WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( RF.SuggestedLOC = LOC.LOC)
      WHERE FROMID = @cFromID
      AND   Ptcid = @cUserName
      AND   StorerKey = @cStorerKey
      AND   Qty > 0
      AND   RTRIM( LOC.LogicalLocation) + SuggestedLOC > RTRIM( @cCurToLOCLogicalLoc) + @cCurToLOC
      ORDER BY LOC.LogicalLocation, LOC.LOC

      -- No next suggested loc
      IF ISNULL( @cToLOC, '') = ''
      BEGIN
         -- Start the search from the beginning of the record
         SELECT TOP 1 @cToLOC = SuggestedLOC 
         FROM dbo.RFPutaway RF WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( RF.SuggestedLOC = LOC.LOC)
         WHERE FROMID = @cFromID
         AND   Ptcid = @cUserName
         AND   StorerKey = @cStorerKey
         AND   Qty > 0
         ORDER BY LOC.LogicalLocation      

         IF ISNULL( @cToLOC, '') <> ''
         BEGIN
            SET @cOutField01 = @cFromID
            SET @cOutField02 = @cToLOC
            SET @cOutField03 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'PutawayDefaultSuggestLOC', @cStorerKey) = '1'
                               THEN @cToLOC ELSE '' END

            -- Go to screen 2
            SET @nScn = @nScn - 3  
            SET @nStep = @nStep - 3  

            GOTO Quit
         END
      END
      ELSE
      BEGIN
         SET @cOutField01 = @cFromID
         SET @cOutField02 = @cToLOC
         SET @cOutField03 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'PutawayDefaultSuggestLOC', @cStorerKey) = '1'
                            THEN @cToLOC ELSE '' END

         -- Go to screen 2
         SET @nScn = @nScn - 3  
         SET @nStep = @nStep - 3  

         GOTO Quit
      END

      -- Nothing to putaway, go back screen 1
      SET @cOutField01 = ''

      -- Go to screen 1
      SET @nScn = @nScn - 4
      SET @nStep = @nStep - 4  
   END
END
GOTO Quit
/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
      EditDate   = GETDATE(), 
      ErrMsg     = @cErrMsg,
      Func       = @nFunc,
      Step       = @nStep,
      Scn        = @nScn,

      StorerKey  = @cStorerKey,
      Facility   = @cFacility,
      Printer    = @cPrinter,
      -- UserName   = @cUserName,

      V_SKU      = @cSKU,
      V_Qty      = @nQTY,
      V_LOC      = @cFromLOC,
      V_ID       = @cFromID,
      
      V_PUOM_Div = @nPUOM_Div,
      V_PQTY     = @nPQTY,
      V_MQTY     = @nMQTY,
      
      V_Integer1 = @nPQTY_PWY,
      V_Integer2 = @nMQTY_PWY,
      V_Integer3 = @nQTY_PWY,
      V_Integer6 = @nPABookingKey,

      V_String1  = @cToLOC,
      V_String2  = @cMUOM_Desc,
      V_String3  = @cPUOM_Desc,
      --V_String4  = @nPUOM_Div ,
      --V_String5  = @nPQTY_PWY ,
      --V_String6  = @nMQTY_PWY ,
      --V_String7  = @nQTY_PWY,
      --V_String8  = @nPQTY,
      --V_String9  = @nMQTY,
      V_String10 = @cDecodeSP,
      V_String11 = @cPASuggestLOCSKU_SP,
      V_String12 = @cSuggLOC,
      V_String13 = @cMoveQTYAlloc,
      V_String14 = @cMoveQTYPick,
      --V_String15 = @nPABookingKey,    
      V_String16 = @cPUOM,
      
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