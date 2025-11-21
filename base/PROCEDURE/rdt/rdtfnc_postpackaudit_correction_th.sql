SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdtfnc_PostPackAudit_Correction_TH                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: normal receipt                                              */
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
/* 2006-08-14 1.0  UngDH    Created                                     */
/* 2007-03-03 1.1  James    check if caseid already scanned within same */
/*                          opened batch                                */
/* 2008-11-26 1.2  Vicky    Add '' to Status filtering (Vicky01)        */
/* 2010-09-28 1.3  UngDH    SOS190654 remove unalloc when correct case  */
/*                          Split from rdtfnc_PostPackAudit_Correction  */
/* 2016-09-30 1.4  Ung      Performance tuning                          */
/* 2018-11-09 1.5  TungGH   Performance                                 */
/************************************************************************/

CREATE  PROCEDURE [RDT].[rdtfnc_PostPackAudit_Correction_TH] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON 
SET QUOTED_IDENTIFIER OFF 
SET ANSI_NULLS OFF

-- Misc variable
DECLARE 
   @i              INT, 
   @cOption        NVARCHAR( 1), 
   @nTranCount     INT, 

   @nRowRef        INT, 
   @nGroupID       INT, 
   @cWorkstation   NVARCHAR( 15), 
   @cConsigneeKey  NVARCHAR( 15), 
   @nCountQTY_B    INT, 
   @nOriginalQTY   INT, 
   @nPickDetailQTY INT, 
   @cPickDetailKey NVARCHAR( 10), 
   @nQTY           INT, 
   @cRefNo1        NVARCHAR( 20), 
   @cRefNo2        NVARCHAR( 20), 
   @cRefNo3        NVARCHAR( 20), 
   @cRefNo4        NVARCHAR( 20), 
   @cRefNo5        NVARCHAR( 20),
   @nBatchID       INT,
   @cCloseWho      NVARCHAR( 18)
  
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

   @cSKUDescr  NVARCHAR( 60), 

   @cCaseID    NVARCHAR( 18), 
   @cRefNo     NVARCHAR( 20), 
   @cSKU       NVARCHAR( 20), 
   @cUOM       NVARCHAR( 10), 
   @cQTY       NVARCHAR( 5), 
   @cReason    NVARCHAR( 10), 
   
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
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60)

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

   @cSKUDescr  = V_SKUDescr, 

   @cCaseID    = V_String1, 
   @cRefNo     = V_String2, 
   @cSKU       = V_String3, 
   @cUOM       = V_String4, 
   @cQTY       = V_String5, 
   @cReason    = V_String6, 

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
   @cInField15 = I_Field15,   @cOutField15 = O_Field15

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile


IF @nFunc = 569 -- XDock/Indent case correction
BEGIN
   IF @nStep = 0 GOTO Step_C0   -- Func. XDock/Indent case correction
   IF @nStep = 1 GOTO Step_C1   -- Scn = 590. Case
   IF @nStep = 2 GOTO Step_C2   -- Scn = 591. QTY, Reason
   IF @nStep = 3 GOTO Step_C3   -- Scn = 592. Message dialog
   IF @nStep = 4 GOTO Step_C4   -- Scn = 593. Message
END

IF @nFunc = 570 -- Tote correction
BEGIN
   IF @nStep = 0 GOTO Step_T0   -- Func. Tote correction
   IF @nStep = 1 GOTO Step_T1   -- Scn = 600. Tote
   IF @nStep = 2 GOTO Step_T2   -- Scn = 601. RefNo
   IF @nStep = 3 GOTO Step_T3   -- Scn = 602. SKU/UPC
   IF @nStep = 4 GOTO Step_T4   -- Scn = 603. QTY, Reason
   IF @nStep = 5 GOTO Step_T5   -- Scn = 604. Message dialog
   IF @nStep = 6 GOTO Step_T6   -- Scn = 605. Message
END

RETURN -- Do nothing if incorrect step


/*-------------------------------------------------------------------------------

                             XDOCK/INDENT CASE SECTION 

-------------------------------------------------------------------------------*/


/********************************************************************************
Step C0. func = 569. Menu
********************************************************************************/
Step_C0:
BEGIN
   -- Set the entry point
   SET @nScn = 590
   SET @nStep = 1

   -- Initiate var
   SET @cCaseID  = ''
   SET @cQTY = ''
   SET @cReason = ''

   -- Init screen
   SET @cOutField01 = ''
END
GOTO Quit


/********************************************************************************
Step C1. Scn = 590. CaseID screen
   CaseID (field01)
********************************************************************************/
Step_C1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cCaseID = @cInField01
      
      -- Validate blank
      IF @cCaseID = '' OR @cCaseID IS NULL
      BEGIN
         SET @nErrNo = 62301
         SET @cErrMsg = rdt.rdtgetmessage( 62301, @cLangCode, 'DSP') --'CaseID needed'
         GOTO Step_C1_Fail
      END

      -- Prevent barcode (numeric) accidentally scanned on this field
      -- Happens a lot when using multi directional scanner, and case is printed with many other barcodes (WATSON, PH)
      IF IsNumeric( LEFT( @cCaseID, 1)) = 1
      BEGIN
         SET @nErrNo = 62302
         SET @cErrMsg = rdt.rdtgetmessage( 62302, @cLangCode, 'DSP') --'Not a CaseID'
         GOTO Step_C1_Fail
      END

      -- Validate CaseID
      IF NOT EXISTS( SELECT 1
         FROM rdt.rdtCSAudit (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND Type = 'C' -- XDock/Indent case
            AND CaseID = @cCaseID
            AND Status IN ('5', '9')) -- 5-Closed, 9-Printed
      BEGIN
         SET @nErrNo = 62303
         SET @cErrMsg = rdt.rdtgetmessage( 62303, @cLangCode, 'DSP') --'Invalid CaseID'
         GOTO Step_C1_Fail
      END

      --sos#60944 check if caseid already scanned within same opened batch -start
      IF EXISTS (SELECT 1 FROM RDT.rdtCSAudit_Batch A (NOLOCK) 
         JOIN RDT.rdtCSAudit B (NOLOCK) 
            ON A.BatchID = B.BatchID AND A.StorerKey = B.StorerKey 
         WHERE A.STORERKEY = @cStorerKey 
            AND A.CloseWho <> '' 
            AND B.CASEID = @cCaseID)
      BEGIN
         SET @nErrNo = 62303
         SET @cErrMsg = rdt.rdtgetmessage( 62303, @cLangCode, 'DSP') --'Invalid CaseID'
         GOTO Step_C1_Fail
      END
      --sos#60944 check if caseid already scanned within same opened batch -end

      -- Prep next screen var
      SET @cQTY = ''
      SET @cReason = ''
      SET @cOutField01 = @cCaseID
      SET @cOutField02 = '' -- QTY
      SET @cOutField03 = '' -- Reason
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- QTY

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_C1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cCaseID = ''
      SET @cOutField01 = '' -- CaseID
   END
END
GOTO Quit


/********************************************************************************
Step C2. scn = 591. QTY, reason screen
   CaseID  (field01)
   QTY     (field02)
   Reason  (field03)
********************************************************************************/
Step_C2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cQTY = @cInField02
      SET @cReason = @cInField03

      -- Retain the input
      SET @cOutField02 = @cInField02 -- QTY
      SET @cOutField03 = @cInField03 -- Reason

      -- Validate QTY
      IF rdt.rdtIsValidQTY( @cQTY, 0) = 0 -- Do not check for zero
      BEGIN
         SET @nErrNo = 62304
         SET @cErrMsg = rdt.rdtgetmessage( 62304, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- QTY
         GOTO Step_C2_Fail
      END
      
      -- Validate blank
      IF @cReason = '' OR @cReason IS NULL
      BEGIN
         SET @nErrNo = 62305
         SET @cErrMsg = rdt.rdtgetmessage( 62305, @cLangCode, 'DSP') --'Reason needed'
         EXEC rdt.rdtSetFocusField @nMobile, 3  -- Reason
         GOTO Step_C2_Fail
      END

      -- Validate reason
      IF NOT EXISTS (SELECT 1
         FROM dbo.CodeLKUP C (NOLOCK)
         WHERE C.ListName = 'PPPEDITRSN'
            AND Code = @cReason)
      BEGIN
         SET @nErrNo = 62306
         SET @cErrMsg = rdt.rdtgetmessage( 62306, @cLangCode, 'DSP') --'Invalid reason'
         EXEC rdt.rdtSetFocusField @nMobile, 3  -- Reason
         GOTO Step_C2_Fail
      END 

      -- Prepare next screen var
      SET @cOutField01 = '' -- Option

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cCaseID = ''
      SET @cOutField01 = @cCaseID

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
   
   Step_C2_Fail:
END
GOTO Quit


/********************************************************************************
Step C3. Scn = 592. Message dialog screen
   Option  (field01)
********************************************************************************/
Step_C3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 62307
         SET @cErrMsg = rdt.rdtgetmessage( 62307, @cLangCode, 'DSP') -- Option needed
         GOTO Step_C3_Fail
      END

      -- Validate option
      IF (@cOption <> '1' AND @cOption <> '2')
      BEGIN
         SET @nErrNo = 62308
         SET @cErrMsg = rdt.rdtgetmessage( 62308, @cLangCode, 'DSP') -- Invalid Option
         GOTO Step_C3_Fail
      END

      IF @cOption = '1' -- Yes
      BEGIN
         SET @nQTY = CAST( @cQTY AS INT)
      
         -- Get case info      
         SELECT TOP 1
            @nRowRef = RowRef, 
            @nGroupID = GroupID, 
            @cConsigneeKey = ConsigneeKey, 
            @cSKU = SKU, 
            @nCountQTY_B = CountQTY_B, 
            @nOriginalQTY = OriginalQTY
         FROM RDT.RDTCSAudit (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND Type = 'C'
            AND CaseID = @cCaseID
            AND Status IN ('5', '9') -- 5-Closed, 9-Printed

         -- Check PickDetail changed by others after end scan
         SELECT 
            @nPickDetailQTY = IsNULL( PD.QTY, 0), 
            @cPickDetailKey = PickDetailKey
         FROM dbo.Orders O (NOLOCK) 
            INNER JOIN dbo.PickDetail PD WITH (NOLOCK, INDEX(PICKDETAIL10)) ON (O.OrderKey = PD.OrderKey)
         WHERE O.ConsigneeKey = @cConsigneeKey
            AND O.Status < '9'
            AND O.StorerKey = @cStorerKey
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.CaseID = @cCaseID
            AND PD.Status = '5' -- Picked -- (Vicky01)
            AND PD.UOM = '2' -- Case -- (Vicky01)
         
         -- Check if PD changed
         IF @nPickDetailQTY = 0 OR @@ROWCOUNT <> 1
         BEGIN
            SET @nErrNo = 62309
            SET @cErrMsg = rdt.rdtgetmessage( 62309, @cLangCode, 'DSP') --'PKDtl changed'
            GOTO Step_C3_Fail
         END

         -- Check if trying to increase PD.QTY
         IF @nQTY > @nPickDetailQTY 
         BEGIN
            SET @nErrNo = 62310
            SET @cErrMsg = rdt.rdtgetmessage( 62310, @cLangCode, 'DSP') --'CantAdd PD.QTY'
            GOTO Step_C3_Fail
         END

         -- Handling transaction
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdtfnc_PostPackAudit_Correction -- For rollback or commit only our own transaction

         -- Get the PickDetail
         SET @nErrNo = 0
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            --QTY = @nQTY, -- SOS190654
            DropID = CASE WHEN @nQTY = 0 THEN '' ELSE DropID END
         WHERE PickDetailKey = @cPickDetailKey
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran_Case
         END
         
         -- Reverse RDTCSAudit
         IF @nQTY = 0
         BEGIN
            -- Delete the case
            DELETE rdt.rdtCSAudit WITH (ROWLOCK) WHERE RowRef = @nRowRef
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 62311
               SET @cErrMsg = rdt.rdtgetmessage( 62311, @cLangCode, 'DSP') --'DelCSAuditFail'
               GOTO RollBackTran_Case
            END
            
            -- Delete the case in load
            DELETE rdt.rdtCSAudit_Load WITH (ROWLOCK) 
            WHERE GroupID = @nGroupID
               AND CaseID = @cCaseID
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 62312
               SET @cErrMsg = rdt.rdtgetmessage( 62312, @cLangCode, 'DSP') --'DelLoadFail'
               GOTO RollBackTran_Case
            END
         END
         ELSE
         BEGIN
            -- Change the QTY
            UPDATE rdt.rdtCSAudit WITH (ROWLOCK) SET
               CountQTY_A = @nQTY, 
               CountQTY_B = @nQTY, 
               AdjustedQTY = @nQTY - @nOriginalQTY, 
               AdjustReason = @cReason, 
               AdjustWho = Suser_Sname(), 
               AdjustDate = GETDATE(), 
               TrafficCop = NULL -- So that EditWho, EditDate won't get overwritten (for measuring performance)
            WHERE RowRef = @nRowRef
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 62313
               SET @cErrMsg = rdt.rdtgetmessage( 62313, @cLangCode, 'DSP') --'UpdCSAuditFail'
               GOTO RollBackTran_Case
            END
         
            -- Reset status to 5-Closed
            UPDATE rdt.rdtCSAudit WITH (ROWLOCK) SET
               Status = '5' -- 5-Closed 
            WHERE GroupID = @nGroupID
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 62314
               SET @cErrMsg = rdt.rdtgetmessage( 62314, @cLangCode, 'DSP') --'UpdCSAuditFail'
               GOTO RollBackTran_Case
            END
         END

         COMMIT TRAN rdtfnc_PostPackAudit_Correction -- Only commit change made here
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO Quit
      END
   END

   -- Prepare prev screen var
   SET @cOutField01 = @cCaseID
   SET @cOutField06 = @cQTY
   SET @cOutField07 = @cReason
   EXEC rdt.rdtSetFocusField @nMobile, 3 -- QTY

   -- Go to prev screen
   SET @nScn = @nScn - 1
   SET @nStep = @nStep - 1
   GOTO Quit

   RollBackTran_Case:
   BEGIN
      ROLLBACK TRAN rdtfnc_PostPackAudit_Correction -- Only rollback change made in rdt_Move
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
   END
   GOTO Quit

   Step_C3_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOption = ''
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit


/********************************************************************************
Step C4. scn = 593. Message screen
   Msg
********************************************************************************/
Step_C4:
BEGIN
   -- Go back to 1st screen
   SET @nScn  = @nScn - 3
   SET @nStep = @nStep - 3

   -- Prep next screen var
   SET @cCaseID = ''
   SET @cOutField01 = '' -- CaseID
END
GOTO Quit


/*-------------------------------------------------------------------------------

                                  TOTE SECTION 

-------------------------------------------------------------------------------*/


/********************************************************************************
Step C0. func = 570. Menu
********************************************************************************/
Step_T0:
BEGIN
   -- Set the entry point
   SET @nScn = 600
   SET @nStep = 1

   -- Initiate var
   SET @cCaseID  = ''
   SET @cRefNo = ''
   SET @cSKU = ''
   SET @cUOM = ''
   SET @cQTY = ''
   SET @cReason = ''

   -- Init screen
   SET @cOutField01 = ''
END
GOTO Quit


/********************************************************************************
Step C1. Scn = 600. Tote screen
   Tote (field01)
********************************************************************************/
Step_T1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cCaseID = @cInField01
      
      -- Validate blank
      IF @cCaseID = '' OR @cCaseID IS NULL
      BEGIN
         SET @nErrNo = 62325
         SET @cErrMsg = rdt.rdtgetmessage( 62325, @cLangCode, 'DSP') --'Tote needed'
         GOTO Step_T1_Fail
      END

      -- SOS60944 check if current batch is closed - start
      -- Get BatchID
      SELECT TOP 1
         @nBatchID = BatchID, 
         @cCloseWho = CloseWho
      FROM RDT.rdtCSAudit_Batch (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      ORDER BY BatchID DESC

      -- Validate batch exists (just in case 1st time where no batch exists)
      IF @nBatchID IS NULL
      BEGIN
         SET @nErrNo = 62344
         SET @cErrMsg = rdt.rdtgetmessage( 62344, @cLangCode, 'DSP') --'NoBatchExist'
         GOTO Step_T1_Fail
      END

      IF @cCloseWho <> ''
      BEGIN
         SET @nErrNo = 62345
         SET @cErrMsg = rdt.rdtgetmessage( 62345, @cLangCode, 'DSP') --'BatchClose'
         GOTO Step_T1_Fail
      END
      -- SOS60944 check if the batch of this case is closed - end

      -- Validate CaseID
      IF NOT EXISTS( SELECT 1
         FROM rdt.rdtCSAudit (NOLOCK)
         WHERE BatchID = @nBatchID
            AND StorerKey = @cStorerKey
            AND PalletID = ''
            AND CaseID = @cCaseID)
      BEGIN
         SET @nErrNo = 62326
         SET @cErrMsg = rdt.rdtgetmessage( 62326, @cLangCode, 'DSP') --'Invalid Tote'
         GOTO Step_T1_Fail
      END

      -- Prep next screen var
      SET @cOutField01 = @cCaseID
      SET @cOutField02 = '' -- RefNo
      EXEC rdt.rdtSetFocusField @nMobile, 2

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_T1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cCaseID = ''
      SET @cOutField01 = '' -- Vehicle
   END
END
GOTO Quit


/********************************************************************************
Step C2. scn = 601. RefNo screen
   Tote  (field01)
   RefNo (field02)
********************************************************************************/
Step_T2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cRefNo = @cInField02
      
      -- Validate blank
      IF @cRefNo = '' OR @cRefNo IS NULL
      BEGIN
         SET @nErrNo = 62327
         SET @cErrMsg = rdt.rdtgetmessage( 62327, @cLangCode, 'DSP') --'RefNo needed'
         GOTO Step_T2_Fail
      END
      
      -- Get case info
      DECLARE @cStatus NVARCHAR( 1)
      SELECT TOP 1
         @cStatus = Status
      FROM rdt.rdtCSAudit (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PalletID = ''
         AND CaseID = @cCaseID
         AND @cRefNo IN (RefNo1, RefNo2, RefNo3, RefNo4, RefNo5)  -- Seal no is unique, never reused
      
      -- Validate Tote
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 62328
         SET @cErrMsg = rdt.rdtgetmessage( 62328, @cLangCode, 'DSP') --'RefNoNotFound'
         GOTO Step_T2_Fail
      END

      -- Validate tote not closed
      IF @cStatus <> '5' AND @cStatus <> '9' -- 5-Closed, 9-Printed
      BEGIN
         SET @nErrNo = 62329
         SET @cErrMsg = rdt.rdtgetmessage( 62329, @cLangCode, 'DSP') --'RescanOpenTote'
         GOTO Step_T2_Fail
      END

      -- Prepare next screen var
      SET @cSKU = ''
      SET @cOutField01 = @cCaseID
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = '' -- SKU/UPC
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU/UPC

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cRefNo  = ''
      SET @cOutField01 = @cCaseID
      SET @cOutField02 = '' -- RefNo
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- CaseID

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_T2_Fail:
END
GOTO Quit


/********************************************************************************
Step 3. scn = 602. SKU/UPC screen
   Tote    (field01)
   RefNo   (field02)
   SKU/UPC (field03)
   Desc1   (field04)
   Desc2   (field05)
   QTY     (field06)
   Reason  (field07)
********************************************************************************/
Step_T3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField03

      -- Validate CaseID blank
      IF @cSKU = '' OR @cSKU IS NULL
      BEGIN
         SET @nErrNo = 62330
      SET @cErrMsg = rdt.rdtgetmessage( 62330, @cLangCode, 'DSP') --'SKU needed'
         GOTO Step_T3_Fail
      END
      
      -- Validate SKU
      -- Assumption: no SKU with same barcode.
      SELECT TOP 1
         @cSKU = SKU.SKU
      FROM dbo.SKU SKU (NOLOCK) 
      WHERE SKU.StorerKey = @cStorerKey
         AND @cSKU IN (SKU.SKU, SKU.AltSKU, SKU.RetailSKU, SKU.ManufacturerSKU)

      IF @@ROWCOUNT = 0
      BEGIN
         -- Search UPC
         SELECT TOP 1
            @cSKU = UPC.SKU
         FROM dbo.UPC UPC (NOLOCK) 
         WHERE UPC.StorerKey = @cStorerKey
            AND UPC.UPC = @cSKU

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 62331
            SET @cErrMsg = rdt.rdtgetmessage( 62331, @cLangCode, 'DSP') --'Invalid SKU'
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_T3_Fail
         END
      END

      -- Get SKU descr
      SELECT @cSKUDescr = SKU.Descr
      FROM dbo.SKU SKU (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      -- Validate SKU in Tote
      IF NOT EXISTS( SELECT 1
         FROM RDT.RDTCSAudit (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND CaseID = @cCaseID
            AND SKU = @cSKU
            AND @cRefNo IN (RefNo1, RefNo2, RefNo3, RefNo4, RefNo5))  -- Seal no is unique, never reused
      BEGIN
         SET @nErrNo = 62332
         SET @cErrMsg = rdt.rdtgetmessage( 62332, @cLangCode, 'DSP') --'SKU NotInTote'
         GOTO Step_T3_Fail
      END

      -- Prepare next screen var
      SET @cQTY = ''
      SET @cReason = ''
      SET @cOutField01 = @cCaseID
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
      SET @cOutField06 = '' -- QTY
      SET @cOutField07 = '' -- Reason
      EXEC rdt.rdtSetFocusField @nMobile, 6 -- QTY

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cSKU = ''
      SET @cOutField01 = @cCaseID
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = '' -- SKU/UPC
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU/UPC

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_T3_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField03 = '' -- SKU/UPC
   END
END
GOTO Quit


/********************************************************************************
Step 4. scn = 603. QTY, reason screen
   Tote    (field01)
   RefNo   (field02)
   SKU/UPC (field03)
   Desc1   (field04)
   Desc2   (field05)
   QTY     (field06)
   Reason  (field07)
********************************************************************************/
Step_T4:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cQTY = @cInField06
      SET @cReason = @cInField07

      -- Retain the input
      SET @cOutField06 = @cInField06
      SET @cOutField07 = @cInField07

      -- Validate QTY
      IF rdt.rdtIsValidQTY( @cQTY, 0) = 0 -- Do not check for zero
      BEGIN
         SET @nErrNo = 62333
         SET @cErrMsg = rdt.rdtgetmessage( 62333, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- QTY
         GOTO Step_T4_Fail
      END
      
      -- Validate blank
      IF @cReason = '' OR @cReason IS NULL
      BEGIN
         SET @nErrNo = 62334
         SET @cErrMsg = rdt.rdtgetmessage( 62334, @cLangCode, 'DSP') --'Reason needed'
         EXEC rdt.rdtSetFocusField @nMobile, 7  -- Reason
         GOTO Step_T4_Fail
      END

      -- Validate reason
      IF NOT EXISTS (SELECT 1
         FROM dbo.CodeLKUP C (NOLOCK)
         WHERE C.ListName = 'PPPEDITRSN'
            AND Code = @cReason)
      BEGIN
         SET @nErrNo = 62335
         SET @cErrMsg = rdt.rdtgetmessage( 62335, @cLangCode, 'DSP') --'Invalid reason'
         EXEC rdt.rdtSetFocusField @nMobile, 7  -- Reason
         GOTO Step_T4_Fail
     END 

      -- Prep next screen var
      SET @cOutField01 = ''

   -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cSKU = ''
      SET @cSKUDescr = ''
      SET @cOutField01 = @cCaseID
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = '' -- SKU/UPC
      SET @cOutField04 = '' -- SKU desc 1
      SET @cOutField05 = '' -- SKU desc 2
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU/UPC

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
   
   Step_T4_Fail:
END
GOTO Quit


/********************************************************************************
Step 5. Scn = 604. Message dialog screen
   Option  (field01)
********************************************************************************/
Step_T5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 62336
         SET @cErrMsg = rdt.rdtgetmessage( 62336, @cLangCode, 'DSP') -- Option needed
         GOTO Step_T5_Fail
      END

      -- Validate option
      IF (@cOption <> '1' AND @cOption <> '2')
      BEGIN
         SET @nErrNo = 62337
         SET @cErrMsg = rdt.rdtgetmessage( 62337, @cLangCode, 'DSP') -- Invalid Option
         GOTO Step_T5_Fail
      END

      IF @cOption = '1' -- Yes
      BEGIN
         SET @nQTY = CAST( @cQTY AS INT)
      
         -- Get case info      
         SELECT TOP 1
            @nRowRef = RowRef, 
            @nGroupID = GroupID, 
            @cWorkstation = Workstation, 
            @cConsigneeKey = ConsigneeKey, 
            @nCountQTY_B = CountQTY_B, 
            @nOriginalQTY = OriginalQTY, 
            @cRefNo1 = RefNo1,
            @cRefNo2 = RefNo2,
            @cRefNo3 = RefNo3,
            @cRefNo4 = RefNo4,
            @cRefNo5 = RefNo5
         FROM RDT.RDTCSAudit (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND CaseID = @cCaseID
            AND SKU = @cSKU
            AND @cRefNo IN (RefNo1, RefNo2, RefNo3, RefNo4, RefNo5)  -- Seal no is unique, never reused

         -- Validate SKU in Tote
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 62338
            SET @cErrMsg = rdt.rdtgetmessage( 62338, @cLangCode, 'DSP') --'SKU NotInTote'
            GOTO Step_T4_Fail
         END

         -- Check PickDetail changed by others after end scan
         SELECT @nPickDetailQTY = IsNULL( SUM( PD.QTY), 0)
         FROM dbo.Orders O (NOLOCK) 
            INNER JOIN dbo.PickDetail PD WITH (NOLOCK, INDEX(PICKDETAIL10)) ON (O.OrderKey = PD.OrderKey)
         WHERE O.ConsigneeKey = @cConsigneeKey
            AND O.Status < '9'
            AND O.StorerKey = @cStorerKey
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.CaseID = @cCaseID
            AND PD.Status = '5' -- Picked -- (Vicky01)
            AND PD.UOM = '6' -- Piece -- (Vicky01)
         IF @nPickDetailQTY <> @nCountQTY_B
         BEGIN
            SET @nErrNo = 62339
            SET @cErrMsg = rdt.rdtgetmessage( 62339, @cLangCode, 'DSP') --'PKDtl changed'
            GOTO Step_T4_Fail
         END

         -- Handling transaction
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdtfnc_PostPackAudit_Correction -- For rollback or commit only our own transaction

         -- Get the PickDetail
         DECLARE @curPD CURSOR
         SET @curPD = CURSOR FORWARD_ONLY READ_ONLY FOR 
            SELECT PD.PickDetailKey 
            FROM dbo.Orders O (NOLOCK) 
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK, INDEX(PICKDETAIL10)) ON (O.OrderKey = PD.OrderKey)
            WHERE O.ConsigneeKey = @cConsigneeKey
               AND O.Status < '9'
               AND O.StorerKey = @cStorerKey
               AND PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
               AND PD.CaseID = @cCaseID
               AND PD.Status = '5' -- Picked -- (Vicky01)
               AND PD.UOM = '6' -- Piece -- (Vicky01)
         OPEN @curPD

          -- Reverse PickDetail
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               CaseID = '', 
               DropID = '',
               TrafficCop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 62340
               SET @cErrMsg = rdt.rdtgetmessage( 62340, @cLangCode, 'DSP') --'Upd PKDtl fail'
               GOTO RollBackTran_Tote
            END
         
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END
         CLOSE @curPD
         DEALLOCATE @curPD

         -- Reverse RDTCSAudit
         IF @nQTY = 0
         BEGIN
            -- Delete the SKU in tote
            DELETE rdt.rdtCSAudit WITH (ROWLOCK) WHERE RowRef = @nRowRef
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 62341
               SET @cErrMsg = rdt.rdtgetmessage( 62341, @cLangCode, 'DSP') --'DelCSAuditFail'
               GOTO RollBackTran_Tote
            END

            -- Delete the tote in load, if all SKU in tote deleted
            IF NOT EXISTS( SELECT 1 FROM rdt.rdtCSAudit WITH (ROWLOCK) WHERE GroupID = @nGroupID)
            BEGIN
               DELETE rdt.rdtCSAudit_Load WITH (ROWLOCK) WHERE GroupID = @nGroupID
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 62342
                  SET @cErrMsg = rdt.rdtgetmessage( 62342, @cLangCode, 'DSP') --'DelLoadFail'
                  GOTO RollBackTran_Tote
               END
            END
         END
         ELSE
         BEGIN
            -- Change the QTY
            UPDATE rdt.rdtCSAudit WITH (ROWLOCK) SET
               Status = '0', 
               CountQTY_A = @nQTY, -- CountQTY_A need to reset. End scan will check variance between A and B
               CountQTY_B = @nQTY, 
               AdjustedQTY = @nQTY - @nOriginalQTY, 
               AdjustReason = @cReason, 
               AdjustWho = Suser_Sname(), 
               AdjustDate = GETDATE(), 
               TrafficCop = NULL -- So that EditWho, EditDate won't get overwritten (for measuring performance)
            WHERE RowRef = @nRowRef
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 62343
               SET @cErrMsg = rdt.rdtgetmessage( 62343, @cLangCode, 'DSP') --'UpdCSAuditFail'
               GOTO RollBackTran_Tote
            END

            -- Try to end scan again (for that SKU)
            SET @nErrNo = 0
            EXECUTE rdt.rdt_PostPackAudit_EndScan
               @nFunc = @nFunc,
               @cStorerKey = @cStorerKey, 
               @cConsigneeKey = @cConsigneeKey, 
               @cType = 'C', 
               @cID = @cCaseID, 
               @cWorkstation = @cWorkstation, 
               @cRefNo1 = @cRefNo1,
               @cRefNo2 = @cRefNo2,
               @cRefNo3 = @cRefNo3,
               @cRefNo4 = @cRefNo4,
               @cRefNo5 = @cRefNo5,
               @nErrNo = @nErrNo OUTPUT,
               @cErrMsg = @cErrMsg OUTPUT, 
               @cLangCode = @cLangCode, 
               @cSKU = @cSKU -- For tote correction only
            IF @nErrNo <> 0 GOTO RollBackTran_Tote
         
            -- After end scan, status change to 5-Closed
         END

         COMMIT TRAN rdtfnc_PostPackAudit_Correction -- Only commit change made here
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO Quit
      END
   END

   -- Prepare prev screen var
   SET @cOutField01 = @cCaseID
   SET @cOutField02 = @cRefNo
   SET @cOutField03 = @cSKU
   SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
   SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
   SET @cOutField06 = @cQTY
   SET @cOutField07 = @cReason
   EXEC rdt.rdtSetFocusField @nMobile, 6 -- QTY

   -- Go to prev screen
   SET @nScn = @nScn - 1
   SET @nStep = @nStep - 1
   GOTO Quit

   RollBackTran_Tote:
   BEGIN
      ROLLBACK TRAN rdtfnc_PostPackAudit_Correction -- Only rollback change made in rdt_Move
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
   END
   GOTO Quit

   Step_T5_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOption = ''
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit


/********************************************************************************
Step 6. scn = 605. Message screen
   Msg
********************************************************************************/
Step_T6:
BEGIN
   -- Go back to 1st screen
   SET @nScn  = @nScn - 5
   SET @nStep = @nStep - 5

   -- Prep next screen var
   SET @cCaseID = ''
   SET @cOutField01 = '' -- CaseID
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
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility, 

      V_SKUDescr = @cSKUDescr, 

      V_String1 = @cCaseID, 
      V_String2 = @cRefNo, 
      V_String3 = @cSKU, 
      V_String4 = @cUOM, 
      V_String5 = @cQTY, 
      V_String6 = @cReason, 

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
      I_Field15 = @cInField15,  O_Field15 = @cOutField15

   WHERE Mobile = @nMobile
END










GO