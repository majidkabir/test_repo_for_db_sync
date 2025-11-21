SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_PostPackAudit_Scan                           */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Post Pick Packing                                           */
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
/* Date       Rev   Author   Purposes                                   */
/* 19-Jan-2006 1.0  MaryVong Created                                    */
/* 28-Feb-2007 1.1  jwong    SOS69044 PPP/PPA open/close batch          */
/* 19-Mar-2007 1.2  Ung      SOS69534 Same tote scan for 2 stor         */
/* 21-Jan-2008 1.3  James    SOS93437 Check Seal# scanned exists within */
/*                           same Tote#                                 */
/* 31-Jul-2008 1.4  James    Add in config @cPPP_PPA_StoreAddr          */
/* 31-Jul-2008 1.5  James    Add in validation for valid workstation    */
/* 24-Aug-2008 1.6  Shong    SUM Pickdetail.Qty by CaseID due to Pick   */
/*                           Detail Splitted by nspChangePickDetail...  */
/* 26-May-2009 1.7  MaryVong SOS137578                                  */
/*                           1) Add Batch to narrow down the range of   */
/*                              data retrieval                          */
/*                           2) Filter by Order Type - Tote Only        */
/* 21-Jul-2009 1.8  Vicky    Additional Validation on double scan CaseID*/
/*                           Bug Fix (Vicky01)                          */  
/* 30-Sep-2016 1.9  Ung      Performance tuning                         */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtfnc_PostPackAudit_Scan] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE 
   @b_Success      INT, 
   @n_err          INT, 
   @c_errmsg       NVARCHAR( 250), 
   @cXML           NVARCHAR( 4000), -- To allow double byte data for e.g. SKU descr
   @nQTY           INT, -- QTY key-in
   @nPQTY          INT, -- PickDetail.QTY or rdtCSAudit.PQTY
   @nCQTY          INT, -- rdtCSAudit.CQTY
   @nPQTY_C        INT, -- SOS137578
   @nPQTY_S        INT, -- SOS137578
   @nAllQTY        INT, -- SOS137578
   @nAllQTY_C      INT, -- SOS137578
   @nAllQTY_S      INT, -- SOS137578
   @nRowRef        INT, 
   @i              INT, 
   @cChkConsigneeKey NVARCHAR( 15), 
   @cChkWorkstation  NVARCHAR( 15),
   @cChkStatus     NVARCHAR( 15), 
   @nRowCount      INT,
   @cChkConsignee  NVARCHAR( 15),
   @cType          NVARCHAR( 1)

-- RDT.RDTMobRec variable
DECLARE 
   @nFunc          INT,
   @nScn           INT,
   @nStep          INT,
   @cLangCode      NVARCHAR( 3),
   @nInputKey      INT,
   @nMenu          INT,

   @cStorer        NVARCHAR( 15),
   @cFacility      NVARCHAR( 5), 
   @cLOC           NVARCHAR( 10), 
   @cConsigneeKey  NVARCHAR( 15), 
   @cPalletID      NVARCHAR( 18),
   @cCaseID        NVARCHAR( 18),
   @cSKU           NVARCHAR( 20),
   @cSKUDescr      NVARCHAR( 60),
   
   @cWorkStation   NVARCHAR( 15),
   @cQTY           NVARCHAR( 10),
   @cPQTY          NVARCHAR( 10), 
   @cTotalCase     NVARCHAR( 10), 
   @cTotalQTY      NVARCHAR( 10), 
   
   @cRefNo1        NVARCHAR( 20), 
   @cRefNo2        NVARCHAR( 20), 
   @cRefNo3        NVARCHAR( 20), 
   @cRefNo4        NVARCHAR( 20), 
   @cRefNo5        NVARCHAR( 20), 
   @nBatchID       INT,
   @cBatch         NVARCHAR( 15), -- SOS137578
   
   @cPPP_PPA_StoreAddr NVARCHAR( 1),
   @cPPAWORKSTN    NVARCHAR( 1),

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
   @nFunc         = Func,
   @nScn          = Scn,
   @nStep         = Step,
   @nInputKey     = InputKey,
   @nMenu         = Menu,
   @cLangCode     = Lang_code,

   @cStorer       = StorerKey,
   @cFacility     = Facility,
   @cLOC          = V_LOC, 
   @cConsigneeKey = V_ConsigneeKey, 
   @cPalletID     = V_ID,
   @cCaseID       = V_CaseID,
   @cSKU          = V_SKU,
   @cSKUDescr     = V_SKUDescr,

   @cWorkStation  = V_String1,
   @cQTY          = V_String2,
   @cPQTY         = V_String3, 
   @cTotalCase    = V_String4, 
   @cTotalQTY     = V_String5, 

   @cRefNo1       = V_String6, 
   @cRefNo2       = V_String7, 
   @cRefNo3       = V_String8, 
   @cRefNo4       = V_String9, 
   @cRefNo5       = V_String10, 
   @nBatchID      = CASE WHEN rdt.rdtIsValidQTY( V_String11,  0) = 1 THEN LEFT( V_String11, 5) ELSE 0 END,
   @cPPP_PPA_StoreAddr = V_String12,
   @cBatch        = V_String13, -- SOS137578
   
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

-- Redirect to respective screen
-- Pallet
IF @nFunc = 560 OR @nFunc = 562 -- Scanner A or scanner B
BEGIN
   IF @nStep = 0 GOTO Step_P0   -- Func = 560 / 562. Pallet
   IF @nStep = 1 GOTO Step_P1   -- Scn = 610 / 615. Workstation, Batch
   IF @nStep = 2 GOTO Step_P2   -- Scn = 611 / 616. Batch, Store, Pallet ID
   IF @nStep = 3 GOTO Step_P3   -- Scn = 612 / 617. Batch, Case ID (input), QTY (display), SKU, Desc, TotalQTY
END

-- Case
IF @nFunc = 561 OR @nFunc = 563 -- Scanner A or scanner B
BEGIN
   IF @nStep = 0 GOTO Step_C0   -- Func = 563 / 564. Case
   IF @nStep = 1 GOTO Step_C1   -- Scn = 620 / 625. WorkStation, Batch
   IF @nStep = 2 GOTO Step_C2   -- Scn = 621 / 626. Batch, Store, Case ID
   IF @nStep = 3 GOTO Step_C3   -- Scn = 622 / 627. Ref No 1..5
   IF @nStep = 4 GOTO Step_C4   -- Scn = 623 / 628. Batch, SKU, QTY, Desc, TotalQTY
   IF @nStep = 5 GOTO Step_C5   -- Scn = 624 / 629. Warning message, Option
END

RETURN -- Do nothing if incorrect step


/*-------------------------------------------------------------------------------

                                  PALLET SECTION 

-------------------------------------------------------------------------------*/


/********************************************************************************
Step P0. func = 560. Pallet
   @nStep = 0
********************************************************************************/
Step_P0:
BEGIN
   -- Set the entry point
   IF @nFunc = 560 SET @nScn = 610 -- Scanner A 
   IF @nFunc = 562 SET @nScn = 615 -- scanner B
   SET @nStep = 1

   -- Clear all Vars
   SET @cLOC          = '' -- V_LOC
   SET @cConsigneeKey = '' -- V_ConsigneeKey
   SET @cPalletID     = '' -- V_ID
   SET @cCaseID       = '' -- V_CaseID
   SET @cSKU          = '' -- V_SKU
   SET @cSKUDescr     = '' -- V_SKUDescr

   SET @cWorkStation  = '' -- V_String1
   SET @cQTY          = '' -- V_String2
   SET @cPQTY         = '' -- V_String3
   SET @cTotalCase    = '' -- V_String4
   SET @cTotalQTY     = '' -- V_String5
   SET @nBatchID      = 0  -- V_String11
   SET @cBatch        = '' -- V_String13 -- SOS137578

   -- Init next screen var
   SET @cOutField01 = ''
   SET @cOutField02 = '' -- SOS137578
END
GOTO Quit
   

/********************************************************************************
Step P1. Scn = 610 / 615. Workstation, Batch
   Workstation  (field01)
   Batch        (field02)
********************************************************************************/
Step_P1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cWorkStation = @cInField01
      SET @cBatch       = @cInField02  -- SOS137578 

      -- Retain the key-in values
      SET @cOutField01 = @cWorkStation
      SET @cOutField02 = @cBatch
      
      -- Validate blank
      IF (@cWorkStation = '' OR @cWorkStation IS NULL)
      BEGIN
         SET @nErrNo = 60701
         SET @cErrMsg = rdt.rdtgetmessage( 60701, @cLangCode, 'DSP') --'WKSTA required'
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_P1_Fail
      END

      SET @cPPAWORKSTN = rdt.RDTGetConfig( 0, 'PPAWORKSTN', @cStorer)

      -- If configkey turn on then check for validity of the workstation scanned
      IF @cPPAWORKSTN = '1'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
            WHERE LISTNAME = 'WorkStn' AND CODE = @cWorkStation)
         BEGIN
            SET @nErrNo = 60718
            SET @cErrMsg = rdt.rdtgetmessage( 60718, @cLangCode, 'DSP') --'Invalid WKSTA'
            SET @cOutField01 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_P1_Fail
         END
      END

      -- Save workstation as V_LOC. It is needed by end scan process
      SET @cLOC = @cWorkStation

      -- SOS137578 - Start
      -- Validate blank Batch
      IF ISNULL(@cBatch, '') = ''
      BEGIN
         SET @nErrNo = 60720
         SET @cErrMsg = rdt.rdtgetmessage( 60720, @cLangCode, 'DSP') --'Batch required'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_P1_Fail
      END
      
      -- Validate existance of the Batch
      IF NOT EXISTS (SELECT 1 FROM rdt.RDTCSAudit_Batch WITH (NOLOCK)
                     WHERE Batch = @cBatch )
      BEGIN
         SET @nErrNo = 60721
         SET @cErrMsg = rdt.rdtgetmessage( 60721, @cLangCode, 'DSP') --'Invalid Batch'
         SET @cOutField02 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_P1_Fail
      END
      -- Batch is found
      ELSE
      BEGIN
         -- Check any Opened Batch
         IF NOT EXISTS (SELECT 1 FROM rdt.RDTCSAudit_Batch WITH (NOLOCK)
                        WHERE Batch = @cBatch
                        AND   CloseWho = '' )
         BEGIN
            SET @nErrNo = 60722
            SET @cErrMsg = rdt.rdtgetmessage( 60722, @cLangCode, 'DSP') --'BatchIsClosed'
            SET @cOutField02 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_P1_Fail
         END
         
         -- Validate Storer
         IF NOT EXISTS (SELECT 1 FROM rdt.RDTCSAudit_Batch WITH (NOLOCK)
                        WHERE Batch = @cBatch
                        AND   CloseWho = ''
                        AND   StorerKey = @cStorer )
         BEGIN
            SET @nErrNo = 60723
            SET @cErrMsg = rdt.rdtgetmessage( 60723, @cLangCode, 'DSP') --'MisMatchStorer'
            SET @cOutField02 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_P1_Fail
         END
      END
      -- SOS137578 - End

      -- Initiate next screen var
      SET @cOutField01 = @cBatch -- SOS137578
      SET @cOutField02 = '' -- Store
      SET @cOutField03 = '' -- Pallet ID

      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Stor

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
      SET @cOutField01 = '' -- Option

      -- Clear all Vars
      SET @cConsigneeKey = '' -- V_ConsigneeKey
      SET @cPalletID     = '' -- V_ID
      SET @cCaseID       = '' -- V_CaseID
      SET @cSKU          = '' -- V_SKU
      SET @cSKUDescr     = '' -- V_SKUDescr
   
      SET @cQTY          = '' -- V_String2
      SET @cPQTY         = '' -- V_String3
      SET @cTotalCase    = '' -- V_String4
      SET @cTotalQTY     = '' -- V_String5
      SET @nBatchID      = '' -- V_String11
      SET @cBatch        = '' -- V_String13 -- SOS137578
   END
   GOTO Quit

   Step_P1_Fail:
   -- SOS137578
   --BEGIN
      -- Reset this screen var
      -- SET @cOutField01 = '' -- Workstation

      -- SET @cWorkStation = ''
   --END
END
GOTO Quit


/********************************************************************************
Step P2. Scn = 611 / 616. Batch, Store, pallet ID
   Batch      (field01)
   Store      (field02)
   Pallet ID  (field03)
********************************************************************************/
Step_P2:
BEGIN
IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cConsigneeKey = @cInField02
      SET @cPalletID = @cInField03
      
      -- Retain the key-in values
      SET @cOutField02 = @cConsigneeKey
      SET @cOutField03 = @cPalletID      

      -- SOS69044 check if batch is opened - start
      SET @nBatchID = 0
      SELECT @nBatchID = BatchID 
      FROM RDT.rdtCSAudit_Batch (NOLOCK) 
      WHERE STORERKEY = @cStorer 
         AND CloseWho = ''
         AND Batch = @cBatch -- SOS137578
      IF @nBatchID = 0 or @nBatchID = ''
      BEGIN
         SET @nErrNo = 60714
         SET @cErrMsg = rdt.rdtgetmessage( 60714, @cLangCode, 'DSP') --60714^NoOpenedBatch
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_P2_Fail
      END
      -- SOS69044 check if batch is opened - end

      -- Validate consignee blank
      IF @cConsigneeKey = '' OR @cConsigneeKey IS NULL
      BEGIN
         SET @nErrNo = 60702
         SET @cErrMsg = rdt.rdtgetmessage( 60702, @cLangCode, 'DSP') --'Store required'
         SET @cOutField02 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_P2_Fail
      END

      -- Validate ConsigneeKey
      IF NOT EXISTS( SELECT 1
         FROM dbo.Storer (NOLOCK) 
         WHERE StorerKey = @cConsigneeKey)
      BEGIN
         SET @nErrNo = 60703
         SET @cErrMsg = rdt.rdtgetmessage( 60703, @cLangCode, 'DSP') --'Invalid store'
         SET @cOutField02 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_P2_Fail
      END

      -- Validate whether it has open order
      IF NOT EXISTS( SELECT 1
         FROM dbo.Orders (NOLOCK)
         WHERE StorerKey = @cStorer
            AND ConsigneeKey = @cConsigneeKey
            AND Status < '9' -- 9 = Closed
            AND SOStatus <> 'CANC')
      BEGIN
         SET @nErrNo = 60704
         SET @cErrMsg = rdt.rdtgetmessage( 60704, @cLangCode, 'DSP') --'No open order'
         SET @cOutField02 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_P2_Fail
      END
      SET @cOutField02 = @cConsigneeKey

      -- Validate pallet ID blank
      IF @cPalletID = '' OR @cPalletID IS NULL
      BEGIN
         SET @nErrNo = 60705
         SET @cErrMsg = rdt.rdtgetmessage( 60705, @cLangCode, 'DSP') --'PalletID req'
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_P2_Fail
      END

      -- Commented: Allowed 1 WS multi batches multi opened pallets
      ---- Validate more than 1 PL/CS opened
      --IF EXISTS (SELECT 1
      --   FROM RDT.rdtCSAudit (NOLOCK)
      --   WHERE StorerKey = @cStorer
      --      AND WorkStation = @cWorkStation
      --      AND Status = '0' -- 0=Open, 5=Closed, 9=Printed
      --      AND 
      --         (PalletID = '' OR -- Tote
      --         (PalletID <> '' AND PalletID <> @cPalletID))) -- Pallet
      --BEGIN
      --   SET @nErrNo = 60706
      --   SET @cErrMsg = rdt.rdtgetmessage( 60706, @cLangCode, 'DSP') --'PL/T StillOpen'
      --   SET @cOutField03 = ''
      --   EXEC rdt.rdtSetFocusField @nMobile, 3
      --   GOTO Step_P2_Fail
      --END

      -- Get TotalCase. 
      IF @nFunc = 560 -- scanner A
         SELECT @cTotalCase = CAST( IsNULL( COUNT( 1), 0) AS NVARCHAR( 10))
         FROM rdt.rdtCSAudit (NOLOCK)
         WHERE StorerKey = @cStorer
            AND ConsigneeKey = @cConsigneeKey
            AND WorkStation = @cWorkStation
            AND PalletID = @cPalletID
            AND Status = '0' -- 0=Open
            AND CountQTY_A > 0 -- Only consider those scanned by A
            AND BatchID = @nBatchID -- SOS137578

      IF @nFunc = 562 -- scanner B
         SELECT @cTotalCase = CAST( IsNULL( COUNT( 1), 0) AS NVARCHAR( 10))
         FROM rdt.rdtCSAudit (NOLOCK)
         WHERE StorerKey = @cStorer
            AND ConsigneeKey = @cConsigneeKey
            AND WorkStation = @cWorkStation
            AND PalletID = @cPalletID
            AND Status = '0' -- 0=Open
            AND CountQTY_B > 0 -- Only consider those scanned by B
            AND BatchID = @nBatchID -- SOS137578

      SET @cQTY = '1' -- always 1 coz we're scanning 1 case

      -- Init next screen var
      SET @cOutField01 = @cBatch
      SET @cOutField02 = '' -- Case ID
      SET @cOutField03 = @cQTY
      SET @cOutField04 = '' -- SKU
      SET @cOutField05 = '' -- SKU desc 1
      SET @cOutField06 = '' -- SKU desc 2
      SET @cOutField07 = @cTotalCase

      SET @cCaseID = ''
      
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prep prev screen var
      SET @cOutField01 = @cWorkStation
      SET @cOutField02 = @cBatch -- SOS137578

      -- Go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_P2_Fail:
END
GOTO Quit


/********************************************************************************
Step P3. Scn = 612 / 617. Batch, Case ID (input), QTY (display), SKU, Desc, TotalQTY
   Batch      (field01)
   Case ID    (field02)
   QTY        (field03)
   SKU        (field04)
   SKU desc 1 (field05)
   SKU desc 2 (field06)
   Total QTY  (field07)
********************************************************************************/
Step_P3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cCaseID = @cInField02 -- Case ID

      -- Validate blank
      IF @cCaseID = '' OR @cCaseID IS NULL
      BEGIN
         SET @nErrNo = 60707
         SET @cErrMsg = rdt.rdtgetmessage( 60707, @cLangCode, 'DSP') --'Case ID is required'
         GOTO Step_P3_Fail
      END
      
      -- Prevent barcode (numeric) accidentally scanned on this field
      -- Happens a lot when using multi directional scanner, and case is printed with many other barcodes (WATSON, PH)
      IF IsNumeric( LEFT( @cCaseID, 1)) = 1
      BEGIN
         SET @nErrNo = 60713
         SET @cErrMsg = rdt.rdtgetmessage( 60713, @cLangCode, 'DSP') --'Not a CaseID'
         GOTO Step_P3_Fail
      END

      -- SOS69534 same case scan for 2 stor - start
      SET @cChkConsigneeKey = ''
      SET @cChkWorkstation = ''
      SELECT 
         @cChkStatus = IsNULL( SUM( CASE WHEN Status <> '0' THEN 1 ELSE 0 END), 0), 
         @cChkWorkstation = IsNULL( SUM( CASE WHEN Workstation <> @cWorkstation THEN 1 ELSE 0 END), 0), 
         @cChkConsigneeKey = IsNULL( SUM( CASE WHEN ConsigneeKey <> @cConsigneeKey THEN 1 ELSE 0 END), 0) 
      FROM RDT.rdtCSAudit (NOLOCK) 
      WHERE BatchID = @nBatchID
         AND CaseID = @cCaseID
--          AND 
--             (Workstation <> @cWorkstation  OR -- Same case scan on diff workstation
--             ConsigneeKey <> @cConsigneeKey OR -- Same case scan to diff stor
--             PalletID <> @cPalletID)           -- Same case scan to diff pallet

         -- Same case scanned to different stor
         IF @cChkConsigneeKey > 0
         BEGIN
            SET @nErrNo = 60715
            SET @cErrMsg = rdt.rdtgetmessage( 60715, @cLangCode, 'DSP') --ScanToDiffStor
            SET @cOutField02 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_C2_Fail
         END

         -- Same case scanned on different workstation
         IF @cChkWorkstation > 0
         BEGIN
            SET @nErrNo = 60716
            SET @cErrMsg = rdt.rdtgetmessage( 60716, @cLangCode, 'DSP') --ScanToDiffWKSt
            SET @cOutField02 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_C2_Fail
         END

         IF @cChkStatus > 0
         BEGIN
            SET @nErrNo = 60745
            SET @cErrMsg = rdt.rdtgetmessage( 60745, @cLangCode, 'DSP') --Double scan
            SET @cOutField02 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_C2_Fail
         END

          -- (Vicky01) - Start
          IF EXISTS( SELECT 1
                     FROM RDT.rdtCSAudit_Load ST  (NOLOCK)   
                     WHERE CaseID = @cCaseID
                     AND Status < '9')  -- 0 =open, 5=loading 
          BEGIN
             SET @nErrNo = 67103
             SET @cErrMsg = rdt.rdtgetmessage( 67103, @cLangCode, 'DSP') --Double scan
             SET @cOutField02 = ''
             EXEC rdt.rdtSetFocusField @nMobile, 2
             GOTO Step_C2_Fail
          END
          -- (Vicky01) - End


         -- Get storer config Added by James on 31/07/2008 Start
         SET @cPPP_PPA_StoreAddr = rdt.RDTGetConfig( 0, 'PPP_PPA_StoreAddr', @cStorer)
         -- End
--      END
      --SOS69534 same case scan for 2 stor - end

      /* Note:
         There are 2 types of PickDetail.CaseID for pallet:
         1. Hardcoded string "(StorAddr)". For flow thru (store address) orders. 
            Stamp upon printing "Store Address Label" in ASN screen
         2. C999999999. For XDock or Indent orders. Stamp upon printing "Case / Carton label" in ASN screen
      */

      -- Get Case ID info
-- Commented by Shong, problem occurs when pickdetail had been splitted, 1 case id have more then 1 records
--      SELECT TOP 1 
--         -- NOTE: Do not remove the TOP 1, otherwise SQL will wrongly select "Parallelism / Repartition stream"
--         --       execution plan that run for 30 ~ 40 seconds. Without parallel runs only < 1 sec :-O
--         @cSKU = SKU.SKU, 
--         @cSKUDescr = SKU.DescR, 
--         @cChkConsignee = O.ConsigneeKey, 
--         @cChkStatus = PD.Status, 
--         @nPQTY = PD.QTY -- PickDetail.QTY always in EA
--      FROM dbo.Orders O (NOLOCK)
--         INNER JOIN dbo.PickDetail PD (NOLOCK) ON (O.OrderKey = PD.OrderKey)
--         INNER JOIN dbo.SKU SKU (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
--      WHERE O.StorerKey = @cStorer
--         -- AND O.ConsigneeKey = @cConsigneeKey -- Remarked to have '60711 Diff stor's case' checking
--         AND PD.CaseID = @cCaseID
--         -- AND PD.Status = 5 -- Picked -- Remarked to have '60712 Case not scan out' checking
--         AND PD.UOM = 2 -- Case

      SELECT 
         @cSKU = SKU.SKU, 
         @cSKUDescr = SKU.DescR,
         @cChkConsignee = O.ConsigneeKey, 
         @cChkStatus = PD.Status, 
         @nPQTY = SUM(PD.QTY) 
      FROM dbo.Orders O (NOLOCK)
         INNER JOIN dbo.PickDetail PD (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         INNER JOIN dbo.SKU SKU (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey AND PD.Orderlinenumber = OD.OrderLinenumber) -- SOS137578 --Vicky01
      WHERE O.StorerKey = @cStorer
         AND PD.CaseID = @cCaseID
         AND PD.UOM = '2' -- Case
         AND OD.LoadKey = @cBatch -- SOS137578
      GROUP BY SKU.SKU, SKU.DescR, O.ConsigneeKey, PD.Status
      
      SET @nRowCount = @@ROWCOUNT
      
      IF @nRowCount > 0
      BEGIN
         -- Validate the case is for that consignee
         IF @cChkConsignee <> @cConsigneeKey
         BEGIN
            SET @nErrNo = 60711
            SET @cErrMsg = rdt.rdtgetmessage( 60711, @cLangCode, 'DSP') --'Diff stor's case'
            GOTO Step_P3_Fail
         END
      
         -- Validate case is not scan out
         IF @cChkStatus <> '5'
         BEGIN
            SET @nErrNo = 60712
            SET @cErrMsg = rdt.rdtgetmessage( 60712, @cLangCode, 'DSP') --'Case not scan out'
            GOTO Step_P3_Fail
         END
         
         SET @cType = 'C' -- XDOCK / indent case
      END

      -- Not found means store address. 
      IF @nRowCount = 0
      BEGIN
         SET @cType = 'S' -- Stored address case
         SET @cSKU = ''
         SET @cSKUDescr = ''
         SET @nPQTY = 1
      END
      
      -- Stop if Config turned on and Type = 'S' Start
      IF @cPPP_PPA_StoreAddr = '1' AND @cType = 'S'
      BEGIN
         SET @nErrNo = 60717
         SET @cErrMsg = rdt.rdtgetmessage( 60717, @cLangCode, 'DSP') --'Call IT number'
         GOTO Step_P3_Fail
      END      
      -- End
      
      SET @cPQTY = CAST( @nPQTY AS INT)

      -- Update QTY
      DECLARE @nCountQTY_A INT
      DECLARE @nCountQTY_B INT
      SELECT 
         @nRowRef = RowRef, 
         @nCountQTY_A = CountQTY_A, 
         @nCountQTY_B = CountQTY_B
      FROM rdt.rdtCSAudit (NOLOCK)
      WHERE StorerKey = @cStorer
         AND Workstation = @cWorkstation
         AND PalletID = @cPalletID
         AND CaseID = @cCaseID
         AND Status = '0' -- Open
         AND BatchID = @nBatchID -- SOS137578
      IF @@ROWCOUNT = 0
      BEGIN
         INSERT INTO rdt.rdtCSAudit 
            (StorerKey, Facility, WorkStation, ConsigneeKey, Type, PalletID, CaseID, SKU, Descr,
             RefNo1, RefNo2, RefNo3, RefNo4, RefNo5, CountQTY_A, CountQTY_B, BatchID)
         VALUES
            (@cStorer, @cFacility, @cWorkStation, @cConsigneeKey, @cType, @cPalletID, @cCaseID, @cSKU, @cSKUDescr, 
             '', '', '', '', '', 
            CASE WHEN @nFunc = 560 THEN @nPQTY ELSE 0 END, -- scanner A
            CASE WHEN @nFunc = 562 THEN @nPQTY ELSE 0 END, -- scanner B 
            @nBatchID) 
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 60708
            SET @cErrMsg = rdt.rdtgetmessage( 60708, @cLangCode, 'DSP') --'Add QTY fail'
            GOTO Step_P3_Fail
         END
      END
      ELSE
      BEGIN
         -- Check for double scan. Once scanned, QTY will have value
         IF (@nCountQTY_A > 0 AND @nFunc = 560) OR -- scanner A
            (@nCountQTY_B > 0 AND @nFunc = 562)    -- scanner B
         BEGIN
            SET @nErrNo = 60709
            SET @cErrMsg = rdt.rdtgetmessage( 60709, @cLangCode, 'DSP') --'Double scan'
            GOTO Step_P3_Fail
         END

         UPDATE rdt.rdtCSAudit SET
            CountQTY_A = CASE WHEN @nFunc = 560 THEN CountQTY_A + @nPQTY ELSE CountQTY_A END, -- scanner A
            CountQTY_B = CASE WHEN @nFunc = 562 THEN CountQTY_B + @nPQTY ELSE CountQTY_B END  -- scanner B
         WHERE RowRef = @nRowRef
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 60710
            SET @cErrMsg = rdt.rdtgetmessage( 60710, @cLangCode, 'DSP') --'Update QTY fail'
            GOTO Step_P3_Fail
         END
      END

      -- Increase case count
      SET @cTotalCase = CAST( CAST( @cTotalCase AS INT) + 1 AS NVARCHAR( 10))

      -- Reset case ID, for next scan
      SET @cCaseID = ''

      -- Init next screen var
      SET @cOutField01 = @cBatch -- SOS137578
      SET @cOutField02 = @cCaseID
      SET @cOutField03 = @cQTY
      SET @cOutField04 = @cSKU
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField06 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
      SET @cOutField07 = @cTotalCase

      -- Remain in same screen
      -- SET @nScn  = @nScn + 1
      -- SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cBatch -- SOS137578
      SET @cOutField02 = @cConsigneeKey
      SET @cOutField03 = @cPalletID

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_P3_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- Clear the field for next scan
      SET @cCaseID = ''
   END
END
GOTO Quit

/*-------------------------------------------------------------------------------

                                  CASE SECTION 

-------------------------------------------------------------------------------*/


/********************************************************************************
Step C0. func = 560. Case
   @nStep = 0
********************************************************************************/
Step_C0:
BEGIN
   -- Set the entry point
   IF @nFunc = 561 SET @nScn = 620 -- scanner A
   IF @nFunc = 563 SET @nScn = 625 -- scanner B
   SET @nStep = 1

   -- Clear all Vars
   SET @cLOC          = '' -- V_LOC
   SET @cConsigneeKey = '' -- V_ConsigneeKey
   SET @cPalletID     = '' -- V_ID
   SET @cCaseID       = '' -- V_CaseID
   SET @cSKU          = '' -- V_SKU
   SET @cSKUDescr     = '' -- V_SKUDescr

   SET @cWorkStation  = '' -- V_String1
   SET @cQTY          = '' -- V_String2
   SET @cPQTY         = '' -- V_String3
   SET @cTotalCase    = '' -- V_String4
   SET @cTotalQTY     = '' -- V_String5
   SET @nBatchID      = 0  -- V_String11
   SET @cBatch        = '' -- V_String13 -- SOS137578

   -- Init next screen var
   SET @cOutField01 = ''
   SET @cOutField02 = '' -- SOS137578
END
GOTO Quit


/********************************************************************************
Step C1. Scn = 620 / 625. Workstation, Batch
   Workstation  (field01)
   Batch        (field02)
********************************************************************************/
Step_C1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cWorkStation = @cInField01
      SET @cBatch       = @cInField02 

      -- Retain the key-in values
      SET @cOutField01 = @cWorkStation
      SET @cOutField02 = @cBatch

      -- Validate blank
      IF (@cWorkStation = '' OR @cWorkStation IS NULL)
      BEGIN
         SET @nErrNo = 60725
         SET @cErrMsg = rdt.rdtgetmessage( 60725, @cLangCode, 'DSP') --'WKSTA required'
         GOTO Step_C1_Fail
      END

      SET @cPPAWORKSTN = rdt.RDTGetConfig( 0, 'PPAWORKSTN', @cStorer)

      -- If configkey turn on then check for validity of the workstation scanned
      IF @cPPAWORKSTN = '1'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
            WHERE LISTNAME = 'WorkStn' AND CODE = @cWorkStation)
         BEGIN
            SET @nErrNo = 60719
            SET @cErrMsg = rdt.rdtgetmessage( 60719, @cLangCode, 'DSP') --'Invalid WKSTA'
            SET @cOutField01 = ''
            GOTO Step_C1_Fail
         END
      END
      
      -- Save workstation as V_LOC. It is needed by end scan process
      SET @cLOC = @cWorkStation

      -- SOS137578 - Start
      -- Validate blank Batch
      IF ISNULL(@cBatch, '') = ''
      BEGIN
         SET @nErrNo = 60749
         SET @cErrMsg = rdt.rdtgetmessage( 60749, @cLangCode, 'DSP') --'Batch required'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_C1_Fail
      END
      
      -- Validate existance of the Batch
      IF NOT EXISTS (SELECT 1 FROM rdt.RDTCSAudit_Batch WITH (NOLOCK)
                     WHERE Batch = @cBatch )
      BEGIN
         SET @nErrNo = 60750
         SET @cErrMsg = rdt.rdtgetmessage( 60750, @cLangCode, 'DSP') --'Invalid Batch'
         SET @cOutField02 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_C1_Fail
      END
      -- Batch is found
      ELSE
      BEGIN
         -- Check any Opened Batch
         IF NOT EXISTS (SELECT 1 FROM rdt.RDTCSAudit_Batch WITH (NOLOCK)
                        WHERE Batch = @cBatch
                        AND   CloseWho = '' )
         BEGIN
            SET @nErrNo = 67101
            SET @cErrMsg = rdt.rdtgetmessage( 67101, @cLangCode, 'DSP') --'BatchIsClosed'
            SET @cOutField02 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_C1_Fail
         END
         
         -- Validate Storer
         IF NOT EXISTS (SELECT 1 FROM rdt.RDTCSAudit_Batch WITH (NOLOCK)
                        WHERE Batch = @cBatch
                        AND   CloseWho = ''
                        AND   StorerKey = @cStorer )
         BEGIN
            SET @nErrNo = 67102
            SET @cErrMsg = rdt.rdtgetmessage( 67102, @cLangCode, 'DSP') --'MisMatchStorer'
            SET @cOutField02 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_C1_Fail
         END
      END
      -- SOS137578 - End

      -- Initiate next screen var
      SET @cOutField01 = @cBatch -- SOS137578 
      SET @cOutField02 = ''      -- Store
      SET @cOutField03 = ''      -- Case ID
      
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Stor

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
      SET @cOutField01 = '' -- Option

      -- Clear all Vars
      SET @cConsigneeKey = '' -- V_ConsigneeKey
      SET @cPalletID     = '' -- V_ID
      SET @cCaseID       = '' -- V_CaseID
      SET @cSKU          = '' -- V_SKU
      SET @cSKUDescr     = '' -- V_SKUDescr
   
      SET @cQTY          = '' -- V_String2
      SET @cPQTY         = '' -- V_String3
      SET @cTotalCase    = '' -- V_String4
      SET @cTotalQTY     = '' -- V_String5
      SET @nBatchID      = '' -- V_String11
      SET @cBatch        = '' -- V_String13 -- SOS137578
   END
   GOTO Quit

   Step_C1_Fail:
   -- SOS137578
   --BEGIN
   --  -- Reset this screen var
   --   SET @cOutField01 = '' -- Workstation
   --   SET @cWorkStation = ''
   --END
END
GOTO Quit


/********************************************************************************
Step C2. Scn = 621 / 626. Batch, Store, Case ID
   Batch      (field01)
   Store      (field02)
   Case ID    (field03)
********************************************************************************/
Step_C2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cConsigneeKey = @cInField02
      SET @cCaseID = @cInField03

      -- Retain the key-in values
      SET @cOutField02 = @cConsigneeKey
      SET @cOutField03 = @cCaseID

      -- SOS69044 check if batch is opened -start
      SET @nBatchID = 0
      SELECT @nBatchID = BatchID 
      FROM RDT.rdtCSAudit_Batch (NOLOCK) 
      WHERE StorerKey = @cStorer 
         AND CloseWho = ''
         AND Batch = @cBatch -- SOS137578
      IF @nBatchID = 0 OR @nBatchID = ''
      BEGIN
         SET @nErrNo = 60741
         SET @cErrMsg = rdt.rdtgetmessage( 60741, @cLangCode, 'DSP') --'NoOpenedBatch'
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_C2_Fail
      END
      -- SOS69044 check if batch is opened -end      

      -- Validate consignee blank
      IF @cConsigneeKey = '' OR @cConsigneeKey IS NULL
      BEGIN
         SET @nErrNo = 60726
         SET @cErrMsg = rdt.rdtgetmessage( 60726, @cLangCode, 'DSP') --'Store required'
         SET @cOutField02 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_C2_Fail
      END

      -- Validate ConsigneeKey
      IF NOT EXISTS( SELECT 1
         FROM dbo.Storer (NOLOCK) 
         WHERE StorerKey = @cConsigneeKey)
      BEGIN
         SET @nErrNo = 60727
         SET @cErrMsg = rdt.rdtgetmessage( 60727, @cLangCode, 'DSP') --'Invalid store'
         SET @cOutField02 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_C2_Fail
      END

      -- Validate stor has open order
      IF NOT EXISTS( SELECT 1
         FROM dbo.Orders (NOLOCK)
         WHERE StorerKey = @cStorer
            AND ConsigneeKey = @cConsigneeKey
         AND Status < '9' -- 9 = Closed
            AND SOStatus <> 'CANC')
      BEGIN
         SET @nErrNo = 60728
         SET @cErrMsg = rdt.rdtgetmessage( 60728, @cLangCode, 'DSP') --'No open order'
         SET @cOutField02 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_C2_Fail
      END
      SET @cOutField02 = @cConsigneeKey

      -- Validate case ID blank
      IF @cCaseID = '' OR @cCaseID IS NULL
      BEGIN
         SET @nErrNo = 60729
         SET @cErrMsg = rdt.rdtgetmessage( 60729, @cLangCode, 'DSP') --'CaseID required'
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_C2_Fail
      END

      -- SOS69534 same case scan for 2 stor - start
      IF EXISTS( SELECT 1
         FROM RDT.rdtCSAudit CA (NOLOCK) 
         WHERE BatchID = @nBatchID
            AND CaseID = @cCaseID
            AND Status > '0') -- 0=open
      BEGIN
         SET @nErrNo = 60744
         SET @cErrMsg = rdt.rdtgetmessage( 60744, @cLangCode, 'DSP') --Double scan
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_C2_Fail
      END

      -- (Vicky01) - Start
      IF EXISTS( SELECT 1
                 FROM RDT.rdtCSAudit_Load ST  (NOLOCK)   
                 WHERE CaseID = @cCaseID
                 AND Status < '9')  -- 0 =open, 5=loading 
      BEGIN
         SET @nErrNo = 67103
         SET @cErrMsg = rdt.rdtgetmessage( 67103, @cLangCode, 'DSP') --Double scan
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_C2_Fail
      END
      -- (Vicky01) - End

      SET @cChkConsigneeKey = ''
      SET @cChkWorkstation = ''
      SELECT 
         @cChkWorkstation = Workstation, 
         @cChkConsigneeKey = ConsigneeKey, 
         @cChkStatus = Status
      FROM RDT.rdtCSAudit CA (NOLOCK) 
      WHERE BatchID = @nBatchID
         AND CaseID = @cCaseID
         AND Status = '0' -- Open
         AND 
            (Workstation <> @cWorkstation OR -- Same case scan on diff workstation
            ConsigneeKey <> @cConsigneeKey)  -- Same case scan to diff stor

      IF @@ROWCOUNT > 0
      BEGIN
         -- Same case scanned to different stor
         IF @cChkConsigneeKey <> @cConsigneeKey
         BEGIN
       SET @nErrNo = 60742
            SET @cErrMsg = rdt.rdtgetmessage( 60742, @cLangCode, 'DSP') --ScanToDiffStor
            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_C2_Fail
         END

         -- Same case scanned on different workstation
         IF @cChkWorkstation <> @cWorkstation
         BEGIN
            SET @nErrNo = 60743
            SET @cErrMsg = rdt.rdtgetmessage( 60743, @cLangCode, 'DSP') --ScanToDiffWKSt
            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_C2_Fail
         END
      END
      --SOS69534 same case scan for 2 stor - end

      -- Prevent barcode (numeric) accidentally scanned on this field
      IF IsNumeric( LEFT( @cCaseID, 1)) = 1
      BEGIN
         SET @nErrNo = 60747
         SET @cErrMsg = rdt.rdtgetmessage( 60747, @cLangCode, 'DSP') --'Not a CaseID'
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_C2_Fail
      END
      
      -- Commented: Allowed 1 WS multi batches multi opened cases
      ---- Validate more that 1 PL/CS opened
      --IF EXISTS (SELECT 1
      --   FROM RDT.rdtCSAudit (NOLOCK)
      --   WHERE StorerKey = @cStorer
      --      AND WorkStation = @cWorkStation
      --      AND Status = '0' -- 0=Open, 5=Closed, 9=Printed
      --      AND 
      --         (PalletID <> '' OR -- Pallet
      --         (PalletID = '' AND CaseID <> @cCaseID))) -- Tote
      --BEGIN
      --   SET @nErrNo = 60730
      --   SET @cErrMsg = rdt.rdtgetmessage( 60730, @cLangCode, 'DSP') --'PL/T still open'
      --   SET @cOutField03 = ''
      --   EXEC rdt.rdtSetFocusField @nMobile, 3
      --   GOTO Step_C2_Fail
      --END

      -- Initiate next screen var
      SET @cOutField01 = '' -- RefNo1
      SET @cOutField02 = '' -- RefNo2
      SET @cOutField03 = '' -- RefNo3
      SET @cOutField04 = '' -- RefNo4
      SET @cOutField05 = '' -- RefNo5

      -- Init var (needed by next screen logic)
      SET @cRefNo1 = ''
      SET @cRefNo2 = ''
      SET @cRefNo3 = ''
      SET @cRefNo4 = ''
      SET @cRefNo5 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prep prev screen var
      SET @cOutField01 = @cWorkStation
      SET @cOutField02 = @cBatch -- SOS137578

      -- Go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_C2_Fail:
END
GOTO Quit


/********************************************************************************
Step C3. Scn = 622 / 627. RefNo1..5
   Ref No 1 (field01)
   Ref No 2 (field02)
   Ref No 3 (field03)
   Ref No 4 (field04)
   Ref No 5 (field05)   
********************************************************************************/
Step_C3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      --SOS93437 start
      --check if newly added CSAudit record, if yes then no need to check tote#+seal#
      IF EXISTS (SELECT 1 FROM RDT.rdtCSAudit (NOLOCK) 
         WHERE BatchID = @nBatchID
         AND CaseID = @cCaseID
         AND Status = '0')
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM RDT.rdtCSAudit (NOLOCK) 
            WHERE BatchID = @nBatchID
               AND CaseID = @cCaseID
               AND RefNo1 = @cInField01 
               AND RefNo2 = @cInField02 
               AND RefNo3 = @cInField03 
               AND RefNo4 = @cInField04 
               AND RefNo5 = @cInField05
               AND Status = '0')
         BEGIN
            SET @nErrNo = 60746
            SET @cErrMsg = rdt.rdtgetmessage( 60746, @cLangCode, 'DSP') --'WrongRefno'
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END
      END
      --SOS93437 end

      -- Validate if RefNo changed
      IF @cRefNo1 <> @cInField01 OR
         @cRefNo2 <> @cInField02 OR
         @cRefNo3 <> @cInField03 OR
         @cRefNo4 <> @cInField04 OR
         @cRefNo5 <> @cInField05
      -- There are changes, remain in current screen
      BEGIN
         -- Set next field focus
         SET @i = 1
         IF @cInField01 <> '' SET @i = @i + 1
         IF @cInField02 <> '' SET @i = @i + 1
         IF @cInField03 <> '' SET @i = @i + 1
         IF @cInField04 <> '' SET @i = @i + 1
         IF @cInField05 <> '' SET @i = @i + 1
         IF @i > 5 SET @i = 1
         EXEC rdt.rdtSetFocusField @nMobile, @i
         
         -- Retain key-in value
         SET @cOutField01 = @cInField01
         SET @cOutField02 = @cInField02
         SET @cOutField03 = @cInField03
         SET @cOutField04 = @cInField04
         SET @cOutField05 = @cInField05

         -- Remain in current screen
         -- SET @nScn = @nScn + 1
         -- SET @nStep = @nStep + 1
      END
      ELSE
      -- No changes, means go to next screen
      BEGIN
         -- Get TotalQTY
         SELECT @cTotalQTY = CAST( IsNULL( SUM( 
            CASE WHEN @nFunc = 561 THEN CountQTY_A ELSE CountQTY_B END), 0) AS NVARCHAR( 10))
         FROM rdt.rdtCSAudit (NOLOCK)
         WHERE StorerKey = @cStorer
            AND ConsigneeKey = @cConsigneeKey
            AND WorkStation = @cWorkStation
            AND CaseID = @cCaseID
            AND Status = '0'
            AND BatchID = @nBatchID -- SOS137578
   
         SET @cQTY = '1' -- default to 1 EA
   
         -- Init next screen var
         SET @cOutField01 = @cBatch -- SOS137578
         SET @cOutField02 = @cQTY
         SET @cOutField03 = '' -- SKU
         SET @cOutField04 = '' -- SKU desc 1
         SET @cOutField05 = '' -- SKU desc 2
         SET @cOutField06 = @cTotalQTY
   
         -- Set next screen focus
         EXEC rdt.rdtSetFocusField @nMobile, 2  -- SKU
   
         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      
      -- Save current screen var
      SET @cRefNo1 = @cInField01
      SET @cRefNo2 = @cInField02
      SET @cRefNo3 = @cInField03
      SET @cRefNo4 = @cInField04
      SET @cRefNo5 = @cInField05
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cBatch -- SOS137578
      SET @cOutField02 = @cConsigneeKey
      SET @cOutField03 = @cCaseID
      
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
END
GOTO Quit


/********************************************************************************
Step C4. Scn = 623 / 628. Batch, SKU, QTY, SKU, Desc, TotalQTY
   Batch      (field01)
   QTY        (field02)
   SKU        (field03)
   SKU desc 1 (field04)
   SKU desc 2 (field05)
   Total QTY  (field06)
********************************************************************************/
Step_C4:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cQTY = @cInField02 -- QTY
      SET @cSKU = @cInField03 -- SKU

      -- Retain the key-in values
      SET @cOutField02 = @cQTY -- QTY
      SET @cOutField03 = @cSKU -- SKU

      -- Validate QTY blank
      IF @cQTY = '' OR @cQTY IS NULL
      BEGIN
         SET @nErrNo = 60731
         SET @cErrMsg = rdt.rdtgetmessage( 60731, @cLangCode, 'DSP') --'QTY required'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_C4_Fail
      END

      -- Validate QTY is numeric
      IF IsNumeric( @cQTY) = 0
      BEGIN
         SET @nErrNo = 60732
         SET @cErrMsg = rdt.rdtgetmessage( 60732, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_C4_Fail
      END

      -- Validate QTY is integer
      SET @i = 1
      WHILE @i <= LEN( RTRIM( @cQTY))
      BEGIN
         IF NOT (SUBSTRING( @cQTY, @i, 1) >= '0' AND SUBSTRING( @cQTY, @i, 1) <= '9')
         BEGIN
            SET @nErrNo = 60733
            SET @cErrMsg = rdt.rdtgetmessage( 60733, @cLangCode, 'DSP') --'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_C4_Fail
            BREAK
         END
         SET @i = @i + 1
      END
      
      -- Validate QTY > 0
      SELECT @nQTY = CAST( @cQTY AS INT)
      IF @nQTY < 1
      BEGIN
         SET @nErrNo = 60734
         SET @cErrMsg = rdt.rdtgetmessage( 60734, @cLangCode, 'DSP') --'QTY must > 0'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_C4_Fail
      END

      -- Reset SKU desc
      SET @cOutField03 = '' -- SKU desc 1
      SET @cOutField04 = '' -- SKU desc 2

      -- Validate SKU blank
      IF @cSKU = '' OR @cSKU IS NULL
      BEGIN
         SET @nErrNo = 60735
         SET @cErrMsg = rdt.rdtgetmessage( 60735, @cLangCode, 'DSP') --'SKU required'
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_C4_Fail
      END

      -- Validate SKU
      -- Assumption: no SKU with same barcode.
      SELECT TOP 1
         @cSKU = SKU.SKU
      FROM dbo.SKU SKU (NOLOCK) 
      WHERE SKU.StorerKey = @cStorer 
         AND @cSKU IN (SKU.SKU, SKU.AltSKU, SKU.RetailSKU, SKU.ManufacturerSKU)

      IF @@ROWCOUNT = 0
      BEGIN
         -- Search UPC
         SELECT TOP 1
            @cSKU = UPC.SKU
         FROM dbo.UPC UPC (NOLOCK) 
         WHERE UPC.StorerKey = @cStorer
            AND UPC.UPC = @cSKU

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 60736
            SET @cErrMsg = rdt.rdtgetmessage( 60736, @cLangCode, 'DSP') --'Invalid SKU'
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_C4_Fail
         END
      END

      -- Get SKU description
      SELECT TOP 1
         @cSKUDescr = Descr
      FROM dbo.SKU (NOLOCK) 
      WHERE StorerKey = @cStorer 
         AND SKU = @cSKU

      -- Commented by SOS137578         
      -- Validate SKU on consignee's order
      --IF NOT EXISTS( SELECT 1 
      --   FROM dbo.Orders O (NOLOCK) 
      --      INNER JOIN dbo.Pickdetail PD WITH (NOLOCK, INDEX(PICKDETAIL10)) ON (O.OrderKey = PD.OrderKey)
      --   WHERE O.ConsigneeKey = @cConsigneeKey
      --      AND O.Status < '9'
      --      AND O.StorerKey = @cStorer
      --      AND PD.StorerKey = @cStorer
      --      AND PD.SKU = @cSKU )
      --      -- AND PD.CaseID = ''
      --      -- AND PD.Status = 5 -- Picked
      --      -- AND PD.UOM = 6 -- Piece
      --   BEGIN
      --      SET @nErrNo = 60737
      --      SET @cErrMsg = rdt.rdtgetmessage( 60737, @cLangCode, 'DSP') --'SKU not in Order'
      --      EXEC rdt.rdtSetFocusField @nMobile, 2
      --      GOTO Step_C4_Fail
      --   END
      --
      ---- Get the PickDetail balance for that SKU
      --DECLARE @nAllQTY INT
      --SELECT 
      --   @nAllQTY = IsNULL( SUM( PD.QTY), 0), 
      --   @nPQTY = IsNULL( SUM( CASE WHEN PD.Status = 5 THEN PD.QTY ELSE 0 END), 0)
      --FROM dbo.Orders O (NOLOCK) 
      --    INNER JOIN dbo.PickDetail PD WITH (NOLOCK, INDEX(PICKDETAIL10)) ON (O.OrderKey = PD.OrderKey)
      --WHERE  O.ConsigneeKey = @cConsigneeKey 
      --   AND O.Status < '9'
      --   AND O.StorerKey = @cStorer 
      --   AND PD.StorerKey = @cStorer
      --   AND PD.SKU = @cSKU 
      --   AND PD.Status <= 5 -- picked 
      --   AND PD.UOM = 6 -- piece only 
      --   -- Blank   case ID = created from XDOCK allocation
      --   -- Numeric case ID = created by user in show pick tab
      --   AND (PD.CaseID = '' OR IsNumeric( PD.CaseID) = 1) 


      -- SOS137578 - Start
      /******************************************************************************************************************
         For Order Type = 'C' (Cross Dock), 
         => Retrieve Consignee and BAL QTY for the scanned SKU by:
            PickDetail.Status <= '5'
            PickDetail.CaseID = ''         
            RDTCSAudit_BatchPO.Batch = scanned Batch
            RDTCSAudit_BatchPO.PO_No = OrderDetail.Lottable03
            
         For Order Type = 'S' (Shop Order), do not have ExternPOKey, therefore Orders do not exist in RDTCSAudit_BatchPO
         => Retrieve Consignee and BAL QTY for the scanned SKU by: 
            PickDetail.Status <= '5'
            PickDetail.CaseID = ''
            OrderDetail.LoadKey = scanned Batch

         Notes: Update follow sequence of Order Type = 'S', then 'C'    
      *******************************************************************************************************************/ 
      
      -- Validate if any open record
      IF NOT EXISTS( SELECT 1 -- Order Type = 'C'
         FROM dbo.Orders O (NOLOCK) 
            INNER JOIN dbo.PickDetail PD WITH (NOLOCK, INDEX(PICKDETAIL10)) ON (O.OrderKey = PD.OrderKey)
            INNER JOIN rdt.RDTCSAudit_BatchPO BPO WITH (NOLOCK) ON (BPO.OrderKey = O.OrderKey)
            INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey AND OD.Lottable03 = BPO.PO_No)
         WHERE O.ConsigneeKey = @cConsigneeKey
            AND O.Status < '9'
            AND O.Type = 'C'
            AND O.StorerKey = @cStorer
            AND PD.StorerKey = @cStorer
            AND PD.SKU = @cSKU
            AND PD.Status = '5' -- Picked
            AND PD.UOM = '6' -- Piece
            -- Blank   case ID = created from XDOCK allocation
            -- Numeric case ID = created by user in show pick tab
            AND (PD.CaseID = '' OR IsNumeric( PD.CaseID) = 1)            
            AND BPO.Batch = @cBatch)
      BEGIN
      IF NOT EXISTS( SELECT 1 -- Order Type = 'S'
         FROM dbo.Orders O (NOLOCK) 
            INNER JOIN dbo.PickDetail PD WITH (NOLOCK, INDEX(PICKDETAIL10)) ON (O.OrderKey = PD.OrderKey)
            INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
         WHERE O.ConsigneeKey = @cConsigneeKey
            AND O.Status < '9'
            AND O.Type = 'S'
            AND O.StorerKey = @cStorer
            AND PD.StorerKey = @cStorer
            AND PD.SKU = @cSKU
            AND PD.Status = '5' -- Picked
            AND PD.UOM = '6' -- Piece
            -- Blank   case ID = created from XDOCK allocation
            -- Numeric case ID = created by user in show pick tab
            AND (PD.CaseID = '' OR IsNumeric( PD.CaseID) = 1)            
            AND OD.LoadKey = @cBatch)
         BEGIN
            SET @nErrNo = 60748
            SET @cErrMsg = rdt.rdtgetmessage( 60748, @cLangCode, 'DSP') --'No Open Record'
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_C4_Fail           
         END
      END               
     
      -- Get the PickDetail balance for that SKU
      SELECT -- Order Type = 'C'
         @nAllQTY_C = IsNULL( SUM( DISTINCT PD.QTY), 0), 
         @nPQTY_C = IsNULL( SUM( DISTINCT CASE WHEN PD.Status = 5 THEN PD.QTY ELSE 0 END), 0)
      FROM dbo.Orders O (NOLOCK) 
         INNER JOIN dbo.PickDetail PD WITH (NOLOCK, INDEX(PICKDETAIL10)) ON (O.OrderKey = PD.OrderKey)
         INNER JOIN rdt.RDTCSAudit_BatchPO BPO WITH (NOLOCK) ON (BPO.OrderKey = O.OrderKey)
         INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey AND OD.Lottable03 = BPO.PO_No)          
      WHERE  O.ConsigneeKey = @cConsigneeKey 
         AND O.Status < '9'
         AND O.Type = 'C'
         AND O.StorerKey = @cStorer 
         AND PD.StorerKey = @cStorer
         AND PD.SKU = @cSKU 
         AND PD.Status = '5' -- picked 
         AND PD.UOM = '6' -- piece only 
         -- Blank   case ID = created from XDOCK allocation
         -- Numeric case ID = created by user in show pick tab
         AND (PD.CaseID = '' OR IsNumeric( PD.CaseID) = 1) 
         AND BPO.Batch = @cBatch

      SELECT -- Order Type = 'S'
         @nAllQTY_S = IsNULL( SUM( DISTINCT PD.QTY), 0), 
         @nPQTY_S = IsNULL( SUM( DISTINCT CASE WHEN PD.Status = 5 THEN PD.QTY ELSE 0 END), 0)
      FROM dbo.Orders O (NOLOCK) 
         INNER JOIN dbo.PickDetail PD WITH (NOLOCK, INDEX(PICKDETAIL10)) ON (O.OrderKey = PD.OrderKey)
         INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
      WHERE  O.ConsigneeKey = @cConsigneeKey 
         AND O.Status < '9'
         AND O.Type = 'S'
         AND O.StorerKey = @cStorer 
         AND PD.StorerKey = @cStorer
         AND PD.SKU = @cSKU 
         AND PD.Status = '5' -- picked 
         AND PD.UOM = '6' -- piece only 
         -- Blank   case ID = created from XDOCK allocation
         -- Numeric case ID = created by user in show pick tab
         AND (PD.CaseID = '' OR IsNumeric( PD.CaseID) = 1)
         AND OD.LoadKey = @cBatch

      -- Sum-up QTY
      SET @nAllQTY = @nAllQTY_C + @nAllQTY_S
      SET @nPQTY   = @nPQTY_C + @nPQTY_S

      -- SOS137578 - End

      -- Get the QTY of that SKU currently in all workstation but not yet commit
      SELECT @nCQTY = IsNULL( SUM( 
         CASE @nFunc 
            WHEN 561 THEN CountQTY_A  -- Scanner A
            WHEN 563 THEN CountQTY_B  -- Scanner B
            ELSE 0
         END), 0)
      FROM rdt.rdtCSAudit (NOLOCK)
      WHERE StorerKey = @cStorer
         AND ConsigneeKey = @cConsigneeKey
         -- AND Workstation = @cWorkstation -- From all workstation
         AND PalletID = ''
         -- AND CaseID = @cID -- From all cases
         AND SKU = @cSKU
         AND Status = '0'

      -- Validate if over pick
      -- (PickDetail balance - QTY in checking lane - QTY key-in) not enough means over picked
      IF (@nPQTY - @nCQTY - @nQTY) < 0
      BEGIN
         -- Validate if there are items not scan out (which can be offset after scanned out)
         IF (@nAllQTY - @nPQTY) > 0
         BEGIN
            SET @nErrNo = 60740
            SET @cErrMsg = rdt.rdtgetmessage( 60740, @cLangCode, 'DSP') --'Not scan out'
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_C4_Fail
         END
         ELSE
         BEGIN
            SET @nErrNo = 60738
            SET @cErrMsg = rdt.rdtgetmessage( 60738, @cLangCode, 'DSP') --'Over pick 99999'
            SET @cErrMsg = @cErrMsg + CAST( (@nPQTY - @nCQTY - @nQTY) AS NVARCHAR( 10))
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_C4_Fail
         END
      END

      -- Warning if reach QTY checking level (prevent user accidentally scan barcode on QTY field)
      DECLARE @nQTYCheckLevel INT
      SET @nQTYCheckLevel = rdt.rdtGetCfg( @nFunc, 'PPA_QTYChk', @cStorer)
      IF (@nQTYCheckLevel > 0) AND (@nQTY >= @nQTYCheckLevel)
      BEGIN
         -- Pass to next screen
         SET @cQTY = @nQTY
         
         -- Prep next screen var
         SET @cOutField01 = '' -- Option

         -- Go to warning screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
         GOTO Quit
      END

      -- Update rdtCSAudit
      SET @nErrNo = 0
      EXECUTE rdt.rdt_PostPackAudit_Scan
         @nFunc, 
         @cStorer, 
         @cFacility, 
         @cWorkstation, 
         @cConsigneeKey, 
         @cCaseID,
         @cSKU,
         @cSKUDescr,
         @nQTY, 
         @cRefNo1, 
         @cRefNo2, 
         @cRefNo3, 
         @cRefNo4, 
         @cRefNo5, 
         @nErrNo    OUTPUT,
         @cErrMsg   OUTPUT, -- screen limitation, 20 char max
         @cLangCode,
         @nBatchID

      IF @nErrNo <> 0
         GOTO Step_C4_Fail
            
      -- Init screen var
      SET @cTotalQTY = CAST( (CAST( @cTotalQTY AS INT) + @nQTY) AS NVARCHAR( 10)) -- Increase totalQTY
      SET @cSKU = '' -- Clear SKU for next scan
      SET @cQTY = '1' -- Default to 1
      -- SET @cSKUDescr = '' -- Retain last SKU desc

      SET @cOutField01 = @cBatch -- SOS137578
      SET @cOutField02 = @cQTY
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
      SET @cOutField06 = @cTotalQTY

      -- Set screen focus
      EXEC rdt.rdtSetFocusField @nMobile, 2

      -- Remain on same screen
      -- SET @nScn  = @nScn + 1
      -- SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cRefNo1
      SET @cOutField02 = @cRefNo2
      SET @cOutField03 = @cRefNo3
      SET @cOutField04 = @cRefNo4
      SET @cOutField05 = @cRefNo5
      
      -- Set next screen focus
      SET @i = 1
      IF @cRefNo1 <> '' SET @i = @i + 1
      IF @cRefNo2 <> '' SET @i = @i + 1
      IF @cRefNo3 <> '' SET @i = @i + 1
      IF @cRefNo4 <> '' SET @i = @i + 1
      IF @cRefNo5 <> '' SET @i = @i + 1
      IF @i > 5 SET @i = 1
      EXEC rdt.rdtSetFocusField @nMobile, @i

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_C4_Fail:
   BEGIN
      -- Reset this screen var
      -- SET @cOutField01 = '' -- Retain the QTY
      -- SET @cOutField02 = '' -- Retain the SKU
      SET @cQTY = ''
      SET @cSKU = ''
   END
END
GOTO Quit


/********************************************************************************
Step C5. Scn = 624 / 629. Option screen
   Option (field01)
********************************************************************************/
Step_C5:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      DECLARE @cOption NVARCHAR( 1)
      SET @cOption = @cInField01

      -- Validate blank
      IF (@cOption <> '1' AND @cOption <> '2')
      BEGIN
         SET @nErrNo = 60739
         SET @cErrMsg = rdt.rdtgetmessage( 60739, @cLangCode, 'DSP') --'Invalid option'
         GOTO Step_C5_Fail
      END

      IF @cOption = '1'
      BEGIN
         SET @nQTY = CAST( @cQTY AS INT)
         SET @nErrNo = 0
         EXECUTE rdt.rdt_PostPackAudit_Scan
            @nFunc, 
            @cStorer, 
            @cFacility, 
            @cWorkstation, 
            @cConsigneeKey, 
            @cCaseID,
            @cSKU,
            @cSKUDescr,
            @nQTY, 
            @cRefNo1, 
            @cRefNo2, 
            @cRefNo3, 
            @cRefNo4, 
            @cRefNo5, 
            @nErrNo    OUTPUT,
            @cErrMsg   OUTPUT, -- screen limitation, 20 char max
            @cLangCode, 
            @nBatchID 
            
         IF @nErrNo <> 0 
            GOTO Step_C5_Fail -- Error
         
         -- Increase totalQTY
         SET @cTotalQTY = CAST( (CAST( @cTotalQTY AS INT) + @nQTY) AS NVARCHAR( 10))

         -- Reset screen var
         SET @cQTY = '1' -- Default to 1
         SET @cSKU = ''  -- Clear SKU for next scan
         -- SET @cSKUDescr = '' -- Retain SKU desc
      END
   END
   
   -- Set prev screen focus
   IF @cOption = '1'
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Scan next SKU
   ELSE
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- Correct the QTY

   -- Init prev screen var
   SET @cOutField01 = @cBatch -- SOS137578
   SET @cOutField02 = @cQTY
   SET @cOutField03 = @cSKU
   SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
   SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
   SET @cOutField06 = @cTotalQTY

   -- Go to prev screen
   SET @nScn  = @nScn - 1  -- SKU, QTY screen
   SET @nStep = @nStep - 1
   GOTO Quit

   Step_C5_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET 
      EditDate       = GETDATE(), 
      ErrMsg         = @cErrMsg, 
      Func           = @nFunc,
      Step           = @nStep,
      Scn            = @nScn,

      V_LOC          = @cLOC,
      V_ConsigneeKey = @cConsigneeKey, 
      V_ID           = @cPalletID,
      V_CaseID       = @cCaseID,
      V_SKU          = @cSKU,
      V_SKUDescr     = @cSKUDescr,

      V_String1      = @cWorkStation, 
      V_String2      = @cQTY, 
      V_String3      = @cPQTY, 
      V_String4      = @cTotalCase, 
      V_String5      = @cTotalQTY, 

      V_String6      = @cRefNo1, 
      V_String7      = @cRefNo2, 
      V_String8      = @cRefNo3, 
      V_String9      = @cRefNo4, 
      V_String10     = @cRefNo5, 
      V_String11     = @nBatchID, 
      V_String12     = @cPPP_PPA_StoreAddr,
      V_String13     = @cBatch, -- SOS137578
      
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