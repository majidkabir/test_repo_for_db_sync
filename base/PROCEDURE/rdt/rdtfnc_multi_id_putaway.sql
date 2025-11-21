SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/ 
/* Copyright: Maersk                                                          */ 
/* Purpose:                                                                   */ 
/*                                                                            */ 
/* Modifications log:                                                         */ 
/*                                                                            */ 
/* Date       Rev  Author     Purposes                                        */ 
/* 2024-07-01 1.0  Dennis     FCR-632 Created                                 */
/******************************************************************************/

CREATE   PROC [RDT].[rdtfnc_Multi_ID_Putaway] (
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
   @cOption     NVARCHAR( 1),
   @nCount      INT,
   @nRowCount   INT
DECLARE @nTranCount       INT
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
   @cFromLocation NVARCHAR(20),
   @cToLocation   NVARCHAR(20),
   @nTotal         INT,
   @nScanned       INT,
   @cID           NVARCHAR( 10),  
   @cToID         NVARCHAR( 10),  
   @cSuggestedLOC NVARCHAR( 10), 
   @cReasonCode   NVARCHAR( 10), 
   @cSKU          NVARCHAR( 20), 
   @nQty          INT = 0,
   @nPABookingKey INT = 0,
   @cCurLocation  NVARCHAR(20),
   @cReceiptKey   NVARCHAR(10),
   @cReceiptLineNumber NVARCHAR(5),
   @cQCLoc        NVARCHAR(10),

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
 --@cOrderKey   = V_OrderKey,
   
   @cFromLocation = V_String1,
   @cID           = V_String2,     
   @cSuggestedLOC = V_String4,
   @cToLocation   = V_String5,
   @cSKU          = V_String6,

   @nTotal        = V_Integer1,
   @nScanned      = V_Integer2,

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

-- Screen constant  
DECLARE  
   @nStep_Location         INT,  @nScn_Location          INT,  
   @nStep_Action           INT,  @nScn_Action            INT,  
   @nStep_SuggLoc          INT,  @nScn_SuggLoc           INT,  
   @nStep_ScanPalletID     INT,  @nScn_ScanPalletID      INT,  
   @nStep_Success          INT,  @nScn_Success           INT,  
   @nStep_AddID            INT,  @nScn_AddID             INT, 
   @nStep_AddSuccess       INT,  @nScn_AddSuccess        INT, 
   @nStep_ReasonCode       INT,  @nScn_ReasonCode        INT, 
   @nStep_Option           INT,  @nScn_Option            INT
SELECT  
   @nStep_Location         = 1,   @nScn_Location         = 6450,  
   @nStep_Action           = 2,  @nScn_Action            = 6451,  
   @nStep_SuggLoc          = 3,  @nScn_SuggLoc           = 6452,  
   @nStep_ScanPalletID     = 4,  @nScn_ScanPalletID      = 6453,  
   @nStep_Success          = 5,  @nScn_Success           = 6454,  
   @nStep_AddID            = 6,  @nScn_AddID             = 6455, 
   @nStep_AddSuccess       = 7,  @nScn_AddSuccess        = 6456, 
   @nStep_ReasonCode       = 8,  @nScn_ReasonCode        = 6457, 
   @nStep_Option           = 9,  @nScn_Option            = 6458
  


IF @nFunc = 747
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Multi ID Putaway
   IF @nStep = 1 GOTO Step_1   -- Scn = 6450. 
   IF @nStep = 2 GOTO Step_2   -- Scn = 6451.
   IF @nStep = 3 GOTO Step_3   -- Scn = 6452. 
   IF @nStep = 4 GOTO Step_4   -- Scn = 6453. 
   IF @nStep = 5 GOTO Step_5   -- Scn = 6454. 
   IF @nStep = 6 GOTO Step_6   -- Scn = 6455. 
   IF @nStep = 7 GOTO Step_7   -- Scn = 6456. 
   IF @nStep = 8 GOTO Step_8   -- Scn = 6457. 
   IF @nStep = 9 GOTO Step_9   -- Scn = 6458. 
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 747. Menu
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

   -- Init screen
   SET @cOutField01 = '' 

   -- Set the entry point
   SET @nScn = @nScn_Location
   SET @nStep = @nStep_Location
   
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 6450. 
   Location (Input , Field01)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      SET @cFromLocation = ISNULL(RTRIM(@cInField01),'')
      
      -- Validate blank
      IF ISNULL(RTRIM(@cFromLocation), '') = ''
      BEGIN
         SET @nErrNo = 224551
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC Req!
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END
      IF NOT EXISTS(SELECT 1 FROM LOC WHERE LOC= @cFromLocation AND Facility = @cFacility)
      BEGIN
         SET @nErrNo = 224561
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Loc
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END
      IF EXISTS (SELECT 1 FROM LOTxLOCxID LLI WITH (NOLOCK)
                  LEFT JOIN SKU WITH (NOLOCK) ON SKU.SKU=LLI.Sku AND SKU.StorerKey = LLI.StorerKey
                  WHERE Loc = @cFromLocation AND LLI.StorerKey = @cStorerKey AND SKU.Style<>'SHLV'
                  AND LLI.QTY - LLI.QTYPicked > 0 
               )
      BEGIN
         SET @nErrNo = 224552
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID With No SHLV Location SKU On Trolley
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END
      
      IF EXISTS ( SELECT 1 FROM LOTxLOCxID LLI WITH (NOLOCK)
                  LEFT JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON RD.SKU=LLI.Sku AND RD.StorerKey = LLI.StorerKey 
                  AND RD.ToId = LLI.ID AND RD.Sku = LLI.Sku
                  WHERE LLI.Loc = @cFromLocation AND LLI.StorerKey = @cStorerKey AND ISNULL(RD.PutawayLoc,'') = ''
                  AND LLI.QTY - LLI.QTYPicked > 0 
               )
      BEGIN
         SET @nErrNo = 224553
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID without putaway location on trolley
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END
      IF EXISTS (
                  SELECT 1 FROM LotxLocxID LLI WITH (NOLOCK)
                  WHERE Loc = @cFromLocation AND StorerKey = @cStorerKey 
                  AND EXISTS(
                     SELECT 1 FROM INVENTORYHOLD IH WITH (NOLOCK)
                     WHERE IH.ID = LLI.ID AND IH.StorerKey = LLI.StorerKey 
                     AND Hold = '1' )
                  AND LLI.QTY - LLI.QTYPicked > 0 
               )
      BEGIN
         SET @nErrNo = 224554
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID with hold on trolley.
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END
      
      -- Prepare Next Screen Variable
      SET @cOutField01 = ''
      
      -- GOTO Next Screen
      SET @nScn = @nScn_Action
      SET @nStep = @nStep_Action
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
   END
   GOTO Quit

   STEP_1_FAIL:
   BEGIN
      SET @cOutField01 = ''
   END
   

END 
GOTO QUIT

/********************************************************************************
Step 2. Scn = 6451. 
   Option(field01, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      SET @cOption = ISNULL(RTRIM(@cInField01),'')
      IF @cOption = '1' -- Add IDs
      BEGIN
         SET @cOutField01 = ''

         SET @nScn = @nScn_AddID
         SET @nStep = @nStep_AddID
      END
      ELSE IF @cOption = '9' -- Putaway
      BEGIN
         SELECT TOP 1 @cID = LLI.ID,@cSuggestedLOC = RD.PutawayLoc,@cSKU = LLI.Sku
         FROM LOTxLOCxID LLI WITH (NOLOCK)
         LEFT JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON RD.SKU=LLI.Sku AND RD.StorerKey = LLI.StorerKey AND RD.ToId = LLI.ID  AND RD.Sku = LLI.Sku
         LEFT JOIN LOC LOC WITH (NOLOCK) ON RD.PutawayLoc = LOC.LOC AND LOC.Facility = @cFacility
         WHERE LLI.Loc = @cFromLocation AND LLI.StorerKey = @cStorerKey
         AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END)) > 0
         Order by PALogicalLoc

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 224563
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoOtherIDToPutaway
            GOTO STEP_2_FAIL
         END

         IF EXISTS (
               SELECT 1 FROM INVENTORYHOLD IH WITH (NOLOCK)
               WHERE IH.Loc = @cSuggestedLOC AND IH.StorerKey = @cStorerKey
               AND Hold = '1')
            OR EXISTS (SELECT 1 FROM LOC L WITH (NOLOCK)
               WHERE L.Loc = @cSuggestedLOC AND L.facility = @cFacility
               AND locationflag <> 'NONE')
         BEGIN
            SELECT 
               @cSKU =  SKU,
               @nQTY = (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END))
            FROM dbo.LOTxLOCxID WITH (NOLOCK)
            WHERE StorerKey =  @cStorerKey 
               AND ID  = @cID
               AND LOC = @cFromLocation
               AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END)) > 0

            EXEC [RDT].[rdt_ExtPTStrategy]
            @nMobile = @nMobile,
            @nFunc = @nFunc,
            @cLangCode = @cLangCode,
            @nStep = @nStep,
            @nInputKey = @nInputKey,
            @cFacility = @cFacility,
            @cStorerKey = @cStorerKey,
            @cType = '',
            @cReceiptKey = '',
            @cPOKey = '',
            @cLOC = '',
            @cID = @cID,
            @cSKU = @cSKU,
            @nQTY = @nQty,
            @cRDLineNo = NULL,
            @cFinalLOC = @cSuggestedLoc,
            @cSuggToLOC = @cToLocation OUTPUT,
            @nPABookingKey = @nPABookingKey OUTPUT,
            @nErrNo = @nErrNo OUTPUT,
            @cErrMsg = @cErrMsg OUTPUT

            IF ISNULL(@cToLocation,'') = ''
            BEGIN
               SET @cOutField01 = ''

               SET @nScn = @nScn_Option
               SET @nStep = @nStep_Option
               GOTO QUIT
            END

            SELECT TOP 1
               @cReceiptKey = ReceiptKey,
               @cReceiptLineNumber = ReceiptLineNumber
            FROM RECEIPTDETAIL WITH (NOLOCK)
            WHERE Sku = @cSKU AND StorerKey = @cStorerKey AND ToId = @cID
            ORDER BY EditDate DESC
            SET @nTranCount = @@TRANCOUNT
            -- Handling transaction
            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN update_rd_and_lock_step_2 -- For rollback or commit only our own transaction 

            -- Unlock SuggestedLOC
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
               ,'' --@cSuggFromLOC
               ,@cID
               ,@cSuggestedLoc
               ,@cStorerKey
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO RollBackTran_Step_2

            UPDATE RECEIPTDETAIL SET 
            PutawayLoc = @cToLocation
            WHERE ReceiptKey = @cReceiptKey AND StorerKey = @cStorerKey AND ToId = @cID

            EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
               ,@cFromLocation
               ,@cID
               ,@cToLocation
               ,@cStorerKey
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
               ,@cSKU = @cSKU
               ,@nPutawayQTY = @nQTY
               ,@cFromLOT = ''
               ,@nFunc = @nFunc
               ,@nPABookingKey = @nPABookingKey OUTPUT
            IF @nErrNo <> 0
               GOTO RollBackTran_Step_2

            COMMIT TRAN update_rd_and_lock_step_2 -- Only commit change made here
            SET @cSuggestedLOC = @cToLocation
         END

         SET @cOutField01 = @cFromLocation
         SET @cOutField02 = @cID
         SET @cOutField03 = @cSuggestedLOC
         SET @nScn = @nScn_SuggLoc
         SET @nStep = @nStep_SuggLoc
         GOTO QUIT
      END
      ELSE
      BEGIN
         SET @nErrNo = 218453
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_2_Fail
      END
   END  -- Inputkey = 1

   IF @nInputKey = 0 
   BEGIN
        -- Prepare Previous Screen Variable
       SET @cOutField01 = ''
          
       -- GOTO Previous Screen
       SET @nScn = @nScn_Location
       SET @nStep = @nStep_Location
   END
   GOTO Quit

   STEP_2_FAIL:
   BEGIN
      SET @cOutField01 = ''
      GOTO QUIT
   END
   RollBackTran_Step_2:
      ROLLBACK TRAN update_rd_and_lock_step_2 -- Only rollback change made here
   STEP_2_Success:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

END 
GOTO QUIT


/********************************************************************************
Step 3. Scn = 6452. 
   Location (field04, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      SET @cToLocation = ISNULL(RTRIM(@cInField04),'')
      IF @cToLocation = '99'
      BEGIN
         SET @cOutField01 = ''
         SET @nScn = @nScn_ReasonCode
         SET @nStep = @nStep_ReasonCode
         GOTO QUIT
      END
      IF @cToLocation <> @cSuggestedLOC
      BEGIN
         SET @nErrNo = 224556
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Location Not Matched
         GOTO Step_3_Fail
      END 
      SET @cOutField01 = @cID
      SET @cOutField02 = @cToLocation
      SET @cOutField03 = ''

      SET @nScn = @nScn_ScanPalletID
      SET @nStep = @nStep_ScanPalletID
   END  -- Inputkey = 1


   IF @nInputKey = 0 
   BEGIN
      -- Prepare Previous Screen Variable
      SET @cOutField01 = ''
            
      -- GOTO Previous Screen
      SET @nScn = @nScn_Action
      SET @nStep = @nStep_Action
   END

   GOTO Quit

   STEP_3_FAIL:
   BEGIN
      SET @cOutField01 = @cFromLocation
      SET @cOutField02 = @cID
      SET @cOutField03 = @cSuggestedLOC
   END
   

END 
GOTO QUIT

/********************************************************************************
Step 4. Scn = 6403. 
   Pallet     (Field03, Input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      SET @cToID = ISNULL(RTRIM(@cInField03),'')
      IF @cToID <> @cID
      BEGIN
         SET @nErrNo = 224557
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID Not Matched
         GOTO Step_4_Fail
      END

      SELECT @nQty = (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END))
      FROM LOTxLOCxID LLI WITH (NOLOCK)
      WHERE Loc = @cFromLocation AND StorerKey = @cStorerKey AND ID  = @cID
         AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END)) > 0

      -- Execute putaway process
      EXEC rdt.rdt_Putaway @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility,
         '',      --@cByLOT, optional
         @cFromLocation,
         @cID,
         @cStorerKey,
         '',--SKU Optional
         @nQty,
         @cToLocation,
         '', --@cLabelType OUTPUT, -- optional
         '', --@cUCC,      OUTPUT, -- optional
         @nErrNo     OUTPUT,
         @cErrMsg    OUTPUT
      IF @nErrNo <> 0
         GOTO STEP_4_FAIL

      -- Unlock SuggestedLOC
      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
         ,'' --@cSuggFromLOC
         ,@cID
         ,@cToLocation
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO STEP_4_FAIL

      SET @nScn = @nScn_Success
      SET @nStep = @nStep_Success
   END  -- Inputkey = 1


   IF @nInputKey = 0 
   BEGIN
      -- Prepare Next Screen Variable
      SET @cOutField01 = @cFromLocation
      SET @cOutField02 = @cID
      SET @cOutField03 = @cSuggestedLOC
      -- GOTO Next Screen
      SET @nScn = @nScn_SuggLoc
      SET @nStep = @nStep_SuggLoc
   END
   GOTO Quit

   STEP_4_FAIL:
   BEGIN
         -- Prepare Next Screen Variable
         SET @cOutField01 = @cID
         SET @cOutField02 = @cToLocation
         SET @cOutField03 = ''
   END
END 
GOTO QUIT

/********************************************************************************
Step 5. Scn = 6454. 
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1
   BEGIN
      SELECT TOP 1 @cID = LLI.ID,@cSuggestedLOC = RD.PutawayLoc,@cSKU = LLI.Sku
      FROM LOTxLOCxID LLI WITH (NOLOCK)
      LEFT JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON RD.SKU=LLI.Sku AND RD.StorerKey = LLI.StorerKey AND RD.ToId = LLI.ID  AND RD.Sku = LLI.Sku
      LEFT JOIN LOC LOC WITH (NOLOCK) ON RD.PutawayLoc = LOC.LOC AND LOC.Facility = @cFacility
      WHERE LLI.Loc = @cFromLocation AND LLI.StorerKey = @cStorerKey
      AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END)) > 0
      Order by PALogicalLoc

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 224563
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoOtherIDToPutaway

         SET @cOutField01 = ''

         SET @nScn = @nScn_Action
         SET @nStep = @nStep_Action
         GOTO QUIT
      END 
      IF EXISTS (
         SELECT 1 FROM INVENTORYHOLD IH WITH (NOLOCK)
         WHERE IH.Loc = @cSuggestedLOC AND IH.StorerKey = @cStorerKey
         AND Hold = '1')
         OR EXISTS (SELECT 1 FROM LOC L WITH (NOLOCK)
         WHERE L.Loc = @cSuggestedLOC AND L.facility = @cFacility
         AND locationflag <> 'NONE')
      BEGIN
         SELECT 
            @cSKU =  SKU,
            @nQTY = (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END))
         FROM dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE StorerKey =  @cStorerKey 
            AND ID  = @cID
            AND LOC = @cFromLocation
            AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END)) > 0

         EXEC [RDT].[rdt_ExtPTStrategy]
         @nMobile = @nMobile,
         @nFunc = @nFunc,
         @cLangCode = @cLangCode,
         @nStep = @nStep,
         @nInputKey = @nInputKey,
         @cFacility = @cFacility,
         @cStorerKey = @cStorerKey,
         @cType = '',
         @cReceiptKey = '',
         @cPOKey = '',
         @cLOC = '',
         @cID = @cID,
         @cSKU = @cSKU,
         @nQTY = @nQty,
         @cRDLineNo = NULL,
         @cFinalLOC = @cSuggestedLoc,
         @cSuggToLOC = @cToLocation OUTPUT,
         @nPABookingKey = @nPABookingKey OUTPUT,
         @nErrNo = @nErrNo OUTPUT,
         @cErrMsg = @cErrMsg OUTPUT

         IF ISNULL(@cToLocation,'') = ''
         BEGIN
            SET @cOutField01 = ''

            SET @nScn = @nScn_Option
            SET @nStep = @nStep_Option
            GOTO QUIT
         END

         SELECT TOP 1
            @cReceiptKey = ReceiptKey,
            @cReceiptLineNumber = ReceiptLineNumber
         FROM RECEIPTDETAIL WITH (NOLOCK)
         WHERE Sku = @cSKU AND StorerKey = @cStorerKey AND ToId = @cID
         ORDER BY EditDate DESC
         SET @nTranCount = @@TRANCOUNT
         -- Handling transaction
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN update_rd_and_lock_step_5 -- For rollback or commit only our own transaction 

         -- Unlock SuggestedLOC
         EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
            ,'' --@cSuggFromLOC
            ,@cID
            ,@cSuggestedLoc
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran_Step_5

         UPDATE RECEIPTDETAIL SET 
         PutawayLoc = @cToLocation
         WHERE ReceiptKey = @cReceiptKey AND StorerKey = @cStorerKey AND ToId = @cID

         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
            ,@cFromLocation
            ,@cID
            ,@cToLocation
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@cSKU = @cSKU
            ,@nPutawayQTY = @nQTY
            ,@cFromLOT = ''
            ,@nFunc = @nFunc
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran_Step_5

         COMMIT TRAN update_rd_and_lock_step_5 -- Only commit change made here
         SET @cSuggestedLOC = @cToLocation
      END
      SET @cOutField01 = @cFromLocation
      SET @cOutField02 = @cID
      SET @cOutField03 = @cSuggestedLOC
      SET @nScn = @nScn_SuggLoc
      SET @nStep = @nStep_SuggLoc
      GOTO QUIT
   END  -- Inputkey = 1

   IF @nInputKey = 0
   BEGIN
      SET @cOutField01 = ''

      SET @nScn = @nScn_Location
      SET @nStep = @nStep_Location
      GOTO QUIT
   END
   RollBackTran_Step_5:
      ROLLBACK TRAN update_rd_and_lock_step_5 -- Only rollback change made here
END 
GOTO QUIT

/********************************************************************************
Step 6. Scn = 6455. 
   ID (field01, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1
   BEGIN
      SET @cID = ISNULL(RTRIM(@cInField01),'')
      IF @cID = '' OR NOT EXISTS (SELECT 1 FROM LOTxLOCxID LLI WITH (NOLOCK) WHERE  ID = @cID AND LLI.StorerKey = @cStorerKey AND LLI.QTY - LLI.QTYPicked > 0 )
      BEGIN
         SET @nErrNo = 224558
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
         GOTO Step_6_Fail
      END

      IF EXISTS(
         SELECT 1
         FROM LOTxLOCxID LLI WITH (NOLOCK)
         LEFT JOIN LOC WITH (NOLOCK) ON LOC.Loc = LLI.LOC 
         WHERE LLI.StorerKey = @cStorerKey AND ID = @cID AND LOC.LocationType = 'TROLLEYIB'
         AND LLI.QTY - LLI.QTYPicked > 0 
      )
      BEGIN
         SET @nErrNo = 224559
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LPN already on trolley
         GOTO Step_6_Fail
      END
      IF EXISTS (
         SELECT 1 FROM LOTxLOCxID LLI WITH (NOLOCK)
         LEFT JOIN SKU WITH (NOLOCK) ON SKU.SKU=LLI.Sku AND SKU.StorerKey = LLI.StorerKey
         WHERE ID = @cID AND LLI.StorerKey = @cStorerKey AND SKU.Style<>'SHLV'
         AND LLI.QTY - LLI.QTYPicked > 0 
         )
      BEGIN
         SET @nErrNo = 224560
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LPN without SKU type SHLV
         GOTO Step_6_Fail
      END

      SELECT 
         @cCurLocation = Loc,
         @cSKU =  SKU,
         @nQTY = (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END))
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE StorerKey =  @cStorerKey 
         AND ID  = @cID
         AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END)) > 0

      EXEC [RDT].[rdt_ExtPTStrategy]
      @nMobile = @nMobile,
      @nFunc = @nFunc,
      @cLangCode = @cLangCode,
      @nStep = @nStep,
      @nInputKey = @nInputKey,
      @cFacility = @cFacility,
      @cStorerKey = @cStorerKey,
      @cType = '',
      @cReceiptKey = '',
      @cPOKey = '',
      @cLOC = '',
      @cID = @cID,
      @cSKU = @cSKU,
      @nQTY = @nQty,
      @cRDLineNo = NULL,
      @cFinalLOC = NULL,
      @cSuggToLOC = @cToLocation OUTPUT,
      @nPABookingKey = @nPABookingKey OUTPUT,
      @nErrNo = @nErrNo OUTPUT,
      @cErrMsg = @cErrMsg OUTPUT

      IF @nErrNo <> 0
         GOTO STEP_6_FAIL
      
      IF ISNULL(@cToLocation,'')=''
      BEGIN
         SET @nErrNo = 224555
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Location Not Determined
         GOTO STEP_6_FAIL
      END

      SELECT TOP 1
      @cReceiptKey = ReceiptKey,
      @cReceiptLineNumber = ReceiptLineNumber
      FROM RECEIPTDETAIL WITH (NOLOCK)
      WHERE Sku = @cSKU AND StorerKey = @cStorerKey AND ToId = @cID
      ORDER BY EditDate DESC
      SET @nTranCount = @@TRANCOUNT
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_Multi_ID_Putaway -- For rollback or commit only our own transaction 

      UPDATE RECEIPTDETAIL SET 
      PutawayLoc = @cToLocation
      WHERE ReceiptKey = @cReceiptKey AND StorerKey = @cStorerKey AND ToId = @cID

      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cCurLocation
         ,@cID
         ,@cFromLocation
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cSKU = @cSKU
         ,@nPutawayQTY = @nQTY
         ,@cFromLOT = ''
         ,@nFunc = @nFunc
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      -- Execute putaway process
      EXEC rdt.rdt_Putaway @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility,
         '',      --@cByLOT, optional
         @cCurLocation,
         @cID,
         @cStorerKey,
         '',--SKU Optional
         @nQty,
         @cFromLocation,
         '', --@cLabelType OUTPUT, -- optional
         '', --@cUCC,      OUTPUT, -- optional
         @nErrNo     OUTPUT,
         @cErrMsg    OUTPUT
      IF @nErrNo <> 0
         GOTO RollbackTran

      -- Unlock SuggestedLOC
      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
         ,'' --@cSuggFromLOC
         ,@cID
         ,@cFromLocation
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO RollbackTran

      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cFromLocation
         ,@cID
         ,@cToLocation
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cSKU = @cSKU
         ,@nPutawayQTY = @nQTY
         ,@cFromLOT = ''
         ,@nFunc = @nFunc
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran
      COMMIT TRAN rdt_NormalReceipt_Putaway -- Only commit change made here

      -- Prepare Next Screen Variable
      SET @cOutField01 = ''

      SET @nScn = @nScn_AddSuccess
      SET @nStep = @nStep_AddSuccess
      GOTO STEP_6_Success
   END  -- Inputkey = 1

   IF @nInputKey = 0
   BEGIN
      SET @cOutField01 = ''

      SET @nScn = @nScn_Action
      SET @nStep = @nStep_Action
   END
   STEP_6_FAIL:
   BEGIN
      SET @cOutField01 = ''
      GOTO QUIT
   END
   RollBackTran:
      ROLLBACK TRAN rdtfnc_Multi_ID_Putaway -- Only rollback change made here
   STEP_6_Success:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
END 
GOTO QUIT
/********************************************************************************
Step 7. Scn = 6456. 
   Success Message
********************************************************************************/
Step_7:
BEGIN
   SET @nScn = @nScn_AddID
   SET @nStep = @nStep_AddID
   SET @cOutField01 = ''
END 
GOTO QUIT
/********************************************************************************
Step 8. Scn = 6457. 
   Reason Code
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1
   BEGIN
      SET @cReasonCode = ISNULL(RTRIM(@cInField01),'')
      EXEC [RDT].[rdt_ActionByReason] 
         @nMobile = @nMobile,    
         @nFunc   = @nFunc,
         @cStorerKey = @cStorerKey,
         @cSKU = @cSKU,
         @cLoc = @cSuggestedLOC,
         @cLot = '',
         @cID  = @cID,
         @cReasonCode = @cReasonCode,
         @nErrNo = @nErrno OUTPUT, 
         @cErrMsg = @cErrMsg   OUTPUT
      IF @nErrno <> 0
         GOTO Step_8_Fail

      SELECT 
         @cSKU =  SKU,
         @nQTY = (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END))
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE StorerKey =  @cStorerKey 
         AND ID  = @cID
         AND LOC = @cFromLocation
         AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END)) > 0

      EXEC [RDT].[rdt_ExtPTStrategy]
      @nMobile = @nMobile,
      @nFunc = @nFunc,
      @cLangCode = @cLangCode,
      @nStep = @nStep,
      @nInputKey = @nInputKey,
      @cFacility = @cFacility,
      @cStorerKey = @cStorerKey,
      @cType = '',
      @cReceiptKey = '',
      @cPOKey = '',
      @cLOC = '',
      @cID = @cID,
      @cSKU = @cSKU,
      @nQTY = @nQty,
      @cRDLineNo = NULL,
      @cFinalLOC = @cSuggestedLoc,
      @cSuggToLOC = @cToLocation OUTPUT,
      @nPABookingKey = @nPABookingKey OUTPUT,
      @nErrNo = @nErrNo OUTPUT,
      @cErrMsg = @cErrMsg OUTPUT

      IF ISNULL(@cToLocation,'') = ''
      BEGIN
         SET @cOutField01 = ''

         SET @nScn = @nScn_Option
         SET @nStep = @nStep_Option
         GOTO QUIT
      END
      SELECT TOP 1
         @cReceiptKey = ReceiptKey,
         @cReceiptLineNumber = ReceiptLineNumber
      FROM RECEIPTDETAIL WITH (NOLOCK)
      WHERE Sku = @cSKU AND StorerKey = @cStorerKey AND ToId = @cID
      ORDER BY EditDate DESC
      SET @nTranCount = @@TRANCOUNT
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN update_rd_and_lock -- For rollback or commit only our own transaction 

      -- Unlock SuggestedLOC
      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
         ,'' --@cSuggFromLOC
         ,@cID
         ,@cSuggestedLoc
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran_Step_8

      UPDATE RECEIPTDETAIL SET 
      PutawayLoc = @cToLocation
      WHERE ReceiptKey = @cReceiptKey AND StorerKey = @cStorerKey AND ToId = @cID

      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cFromLocation
         ,@cID
         ,@cToLocation
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cSKU = @cSKU
         ,@nPutawayQTY = @nQTY
         ,@cFromLOT = ''
         ,@nFunc = @nFunc
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran_Step_8

      COMMIT TRAN update_rd_and_lock -- Only commit change made here
      
      SELECT TOP 1 @cID = LLI.ID,@cSuggestedLOC = RD.PutawayLoc,@cSKU = LLI.Sku
      FROM LOTxLOCxID LLI WITH (NOLOCK)
      LEFT JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON RD.SKU=LLI.Sku AND RD.StorerKey = LLI.StorerKey AND RD.ToId = LLI.ID  AND RD.Sku = LLI.Sku
      LEFT JOIN LOC LOC WITH (NOLOCK) ON RD.PutawayLoc = LOC.LOC AND LOC.Facility = @cFacility
      WHERE LLI.Loc = @cFromLocation AND LLI.StorerKey = @cStorerKey
      AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END)) > 0
      ORDER BY PALogicalLoc

      SET @cOutField01 = @cFromLocation
      SET @cOutField02 = @cID
      SET @cOutField03 = @cSuggestedLOC

      SET @nScn = @nScn_SuggLoc
      SET @nStep = @nStep_SuggLoc
      GOTO QUIT
   END
   IF @nInputKey = 0 
   BEGIN
      SET @cOutField01 = @cFromLocation
      SET @cOutField02 = @cID
      SET @cOutField03 = @cSuggestedLOC

      SET @nScn = @nScn_SuggLoc
      SET @nStep = @nStep_SuggLoc
      GOTO QUIT
   END
   Step_8_Fail:
   BEGIN
      SET @cOutField01 = ''
      GOTO QUIT
   END
   RollBackTran_Step_8:
      ROLLBACK TRAN update_rd_and_lock -- Only rollback change made here
   STEP_8_Success:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
END 
GOTO QUIT
/********************************************************************************
Step 9. Scn = 6458. 
   Option
********************************************************************************/
Step_9:
BEGIN
   IF @nInputKey = 1
   BEGIN
      SET @cOption = ISNULL(RTRIM(@cInField01),'')
      IF @cOption = '1' -- Go back check if location needs to be released
      BEGIN
         IF EXISTS ( SELECT 1 FROM INVENTORYHOLD IH WITH (NOLOCK)
            WHERE IH.Loc = @cSuggestedLOC AND IH.StorerKey = @cStorerKey AND Hold = '1')
         BEGIN
            UPDATE INVENTORYHOLD SET Hold = '0' WHERE Loc = @cSuggestedLOC AND StorerKey = @cStorerKey AND Hold = '1'
         END

         IF EXISTS (SELECT 1 FROM LOC L WITH (NOLOCK)
            WHERE L.Loc = @cSuggestedLOC AND L.facility = @cFacility AND locationflag <> 'NONE')
         BEGIN
            UPDATE LOC SET LocationFlag = 'NONE' where Loc = @cSuggestedLOC AND facility = @cFacility
         END

         SET @cOutField01 = @cFromLocation
         SET @cOutField02 = @cID
         SET @cOutField03 = @cSuggestedLOC

         SET @nScn = @nScn_SuggLoc
         SET @nStep = @nStep_SuggLoc
         GOTO QUIT
      END
      ELSE IF @cOption = '9' -- Move to QC loc
      BEGIN
         SET @cQCLoc = rdt.RDTGetConfig( @nFunc, 'TROLLEYQCLOC', @cStorerKey)
         IF NOT EXISTS (
            SELECT 1 FROM LOC WHERE LOC = @cQCLoc AND @cFacility = Facility
         )
         BEGIN
            SET @nErrNo = 224561
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Loc
            GOTO STEP_9_FAIL
         END

         SELECT @nQty = (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END)),
         @cSku = SKU
         FROM LOTxLOCxID LLI WITH (NOLOCK)
         WHERE Loc = @cFromLocation AND StorerKey = @cStorerKey AND ID  = @cID
            AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END)) > 0

         SELECT TOP 1
            @cReceiptKey = ReceiptKey,
            @cReceiptLineNumber = ReceiptLineNumber
         FROM RECEIPTDETAIL WITH (NOLOCK)
         WHERE Sku = @cSKU AND StorerKey = @cStorerKey AND ToId = @cID
         ORDER BY EditDate DESC

         SET @nTranCount = @@TRANCOUNT
         -- Handling transaction
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN update_rd_and_lock_step_9 -- For rollback or commit only our own transaction 

         -- Unlock SuggestedLOC
         EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
            ,'' --@cSuggFromLOC
            ,@cID
            ,@cSuggestedLoc
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran_Step_9

         UPDATE RECEIPTDETAIL SET PutawayLoc = @cQCLoc WHERE ReceiptKey = @cReceiptKey AND ToId = @cID AND StorerKey = @cStorerKey

         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
            ,@cFromLocation
            ,@cID
            ,@cQCLoc
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@cSKU = @cSKU
            ,@nPutawayQTY = @nQTY
            ,@cFromLOT = ''
            ,@nFunc = @nFunc
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran_Step_9

         COMMIT TRAN update_rd_and_lock_step_9 -- Only commit change made here
         SET @cSuggestedLOC = @cQCLoc

         SET @cOutField01 = @cFromLocation
         SET @cOutField02 = @cID
         SET @cOutField03 = @cSuggestedLOC

         SET @nScn = @nScn_SuggLoc
         SET @nStep = @nStep_SuggLoc
         GOTO QUIT
      END
      ELSE 
      BEGIN
         SET @nErrNo = 218453
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_9_Fail
      END
   END  -- Inputkey = 1

   IF @nInputKey = 0
   BEGIN
      SET @cOutField01 = ''
      SET @nScn = @nScn_ReasonCode
      SET @nStep = @nStep_ReasonCode
      GOTO QUIT
   END
   Step_9_Fail:
   BEGIN
      SET @cOutField01 = ''
      GOTO QUIT
   END
   RollBackTran_Step_9:
      ROLLBACK TRAN update_rd_and_lock_step_9 -- Only rollback change made here
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
      -- UserName  = @cUserName,
      InputKey  =   @nInputKey,

      V_UOM = @cPUOM,
  
      V_String1 = @cFromLocation,
      V_String2 = @cID,
      V_String4 = @cSuggestedLOC,
      V_String5 = @cToLocation,
      V_String6 = @cSKU,

      V_Integer1 = @nTotal,  
      V_Integer2 = @nScanned,
      
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