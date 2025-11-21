SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_PostPackAudit_ExcStock_Scan                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: SOS137582 Post Pick Packing - Excess Stocks Scanning        */
/*          Notes: Only support TOTE process                            */
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
/* Date        Rev  Author   Purposes                                   */
/* 01-Jun-2009 1.0  MaryVong Created                                    */
/*                           1) Add Batch to narrow down the range of   */
/*                              data retrieval                          */
/*                           2) Filter by Order Type                    */
/* 21-Jul-2009 1.1  Vicky    Additional Validation on double scan CaseID*/
/*                           (Vicky01)                                  */  
/* 30-Sep-2016 1.2  Ung      Performance tuning                         */
/* 06-Nov-2016 1.3  Ung      Performance tuning                         */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtfnc_PostPackAudit_ExcStock_Scan] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE 
   @b_Success        INT, 
   @n_err            INT, 
   @c_errmsg         NVARCHAR( 250), 
   @nQTY             INT, -- key-in QTY
   @nPQTY            INT, -- PickDetail.QTY
   @nCQTY            INT, -- rdtCSAudit.CQTY
   @nAllQTY          INT, -- All QTY from PickDetail
   @nAllQTY_S        INT, -- All QTY from PickDetail - Order Type = 'S'
   @nAllQTY_C        INT, -- All QTY from PickDetail - Order Type = 'C'
   @nPQTY_S          INT, -- Balance QTY from PickDetail - Order Type = 'S'
   @nPQTY_C          INT, -- Balance QTY from PickDetail - Order Type = 'C'
   @nRowRef          INT, 
   @i                INT, 
   @cChkConsigneeKey NVARCHAR( 15), 
   @cChkWorkstation  NVARCHAR( 15),
   @cChkStatus       NVARCHAR( 15), 
   @nRowCount        INT,
   @cChkConsignee    NVARCHAR( 15),
   @cDefaultOption   NVARCHAR( 1),
   @cOption          NVARCHAR( 1)   

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
   @cCaseID        NVARCHAR( 18),
   @cSKU           NVARCHAR( 20),
   @cSKUDescr      NVARCHAR( 60),
   
   @cWorkStation   NVARCHAR( 15),
   @cQTY           NVARCHAR( 10),
   @cPQTY          NVARCHAR( 10), 
   
   @cRefNo1        NVARCHAR( 20), 
   @cRefNo2        NVARCHAR( 20), 
   @cRefNo3        NVARCHAR( 20), 
   @cRefNo4        NVARCHAR( 20), 
   @cRefNo5        NVARCHAR( 20), 
   @nBatchID       INT,
   @cBatch         NVARCHAR( 15),

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
   @cCaseID       = V_CaseID,
   @cSKU          = V_SKU,
   @cSKUDescr     = V_SKUDescr,

   @cWorkStation  = V_String1,
   @cQTY          = V_String2,
   @cPQTY         = V_String3, 
   @cRefNo1       = V_String4, 
   @cRefNo2       = V_String5, 
   @cRefNo3       = V_String6, 
   @cRefNo4       = V_String7, 
   @cRefNo5       = V_String8, 
   @nBatchID      = CASE WHEN rdt.rdtIsValidQTY( V_String9,  0) = 1 THEN LEFT( V_String9, 5) ELSE 0 END,
   @cBatch        = V_String10,
   
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
-- Tote
IF @nFunc = 894 -- Excess Stocks Scanning
BEGIN
   IF @nStep = 0 GOTO Step_T0   -- Func = 894
   IF @nStep = 1 GOTO Step_T1   -- Scn = 2040. WorkStation, Batch
   IF @nStep = 2 GOTO Step_T2   -- Scn = 2041. Batch, SKU
   IF @nStep = 3 GOTO Step_T3   -- Scn = 2042. Batch, SKU, SKU DESC, STORE, BAL QTY, PICK QTY
   IF @nStep = 4 GOTO Step_T4   -- Scn = 2043. STORE, PICK QTY, TOTE#
   IF @nStep = 5 GOTO Step_T5   -- Scn = 2044. TOTE#, REFNO 1..5
   IF @nStep = 6 GOTO Step_T6   -- Scn = 2045. REFNO 1..5, OPTION
   IF @nStep = 7 GOTO Step_T7   -- Scn = 2046. Successful Message
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step C0. func = 894. Excess Stocks Scanning
   @nStep = 0
********************************************************************************/
Step_T0:
BEGIN
   -- Set the entry point
   SET @nScn = 2040
   SET @nStep = 1

   SET @cDefaultOption = ''
   SET @cDefaultOption = rdt.RDTGetConfig( @nFunc, 'DefaultOption', @cStorer)
   
   -- Clear all Vars
--   SET @cLOC          = '' -- V_LOC
   SET @cConsigneeKey = '' -- V_ConsigneeKey
   SET @cCaseID       = '' -- V_CaseID
   SET @cSKU          = '' -- V_SKU
   SET @cSKUDescr     = '' -- V_SKUDescr

   SET @cWorkStation  = '' -- V_String1
   SET @cQTY          = '' -- V_String2
   SET @cPQTY         = '' -- V_String3
   SET @cRefNo1       = '' -- V_String4
   SET @cRefNo2       = '' -- V_String5
   SET @cRefNo3       = '' -- V_String6
   SET @cRefNo4       = '' -- V_String7
   SET @cRefNo5       = '' -- V_String8
   SET @nBatchID      = 0  -- V_String9
   SET @cBatch        = '' -- V_String10

   -- Init next screen var
   SET @cOutField01 = ''
   SET @cOutField02 = ''
END
GOTO Quit


/********************************************************************************
Step T1. Scn = 2040. Workstation, Batch
   Workstation  (field01) -- Input field
   Batch        (field02) -- Input field
********************************************************************************/
Step_T1:
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
         SET @nErrNo = 67001
         SET @cErrMsg = rdt.rdtgetmessage( 67001, @cLangCode, 'DSP') --'WKSTA required'
         GOTO Step_T1_Fail
      END

      SET @cPPAWORKSTN = rdt.RDTGetConfig( 0, 'PPAWORKSTN', @cStorer)

      -- If configkey turn on then check for validity of the workstation scanned
      IF @cPPAWORKSTN = '1'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
            WHERE LISTNAME = 'WorkStn' AND CODE = @cWorkStation)
         BEGIN
            SET @nErrNo = 67002
            SET @cErrMsg = rdt.rdtgetmessage( 67002, @cLangCode, 'DSP') --'Invalid WKSTA'
            SET @cOutField01 = ''
            GOTO Step_T1_Fail
         END
      END
      
      -- Save workstation as V_LOC. It is needed by end scan process
      SET @cLOC = @cWorkStation

      -- Validate blank Batch
      IF ISNULL(@cBatch, '') = ''
      BEGIN
         SET @nErrNo = 67003
         SET @cErrMsg = rdt.rdtgetmessage( 67003, @cLangCode, 'DSP') --'Batch required'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_T1_Fail
      END
      
      -- Validate existance of the Batch
      IF NOT EXISTS (SELECT 1 FROM rdt.RDTCSAudit_Batch WITH (NOLOCK)
                     WHERE Batch = @cBatch )
      BEGIN
         SET @nErrNo = 67004
         SET @cErrMsg = rdt.rdtgetmessage( 67004, @cLangCode, 'DSP') --'Invalid Batch'
         SET @cOutField02 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_T1_Fail
      END
      -- Batch is found
      ELSE
      BEGIN
         -- Check any Opened Batch
         IF NOT EXISTS (SELECT 1 FROM rdt.RDTCSAudit_Batch WITH (NOLOCK)
                        WHERE Batch = @cBatch
                        AND   CloseWho = '' )
         BEGIN
            SET @nErrNo = 67005
            SET @cErrMsg = rdt.rdtgetmessage( 67005, @cLangCode, 'DSP') --'BatchIsClosed'
            SET @cOutField02 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_T1_Fail
         END
         
         -- Validate Storer
         IF NOT EXISTS (SELECT 1 FROM rdt.RDTCSAudit_Batch WITH (NOLOCK)
                        WHERE Batch = @cBatch
                        AND   CloseWho = ''
                        AND   StorerKey = @cStorer )
         BEGIN
            SET @nErrNo = 67006
            SET @cErrMsg = rdt.rdtgetmessage( 67006, @cLangCode, 'DSP') --'MisMatchStorer'
            SET @cOutField02 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_T1_Fail
         END
      END

      -- Get BatchID
      SELECT TOP 1
         @nBatchID = BatchID
      FROM RDT.rdtCSAudit_Batch (NOLOCK) 
      WHERE Batch = @cBatch
      AND   CloseWho = ''
      AND   StorerKey = @cStorer
      
      -- Initiate next screen var
      SET @cOutField01 = @cBatch
      SET @cOutField02 = ''      -- SKU/UPC
      
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- SKU/UPC

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

      -- Clear all Vars
      SET @cConsigneeKey = '' -- V_ConsigneeKey
      SET @cCaseID       = '' -- V_CaseID
      SET @cSKU          = '' -- V_SKU
      SET @cSKUDescr     = '' -- V_SKUDescr

      SET @cWorkStation  = '' -- V_String1
      SET @cQTY          = '' -- V_String2
      SET @cPQTY         = '' -- V_String3
      SET @cRefNo1       = '' -- V_String4
      SET @cRefNo2       = '' -- V_String5
      SET @cRefNo3       = '' -- V_String6
      SET @cRefNo4       = '' -- V_String7
      SET @cRefNo5       = '' -- V_String8
      SET @nBatchID      = '' -- V_String9
      SET @cBatch        = '' -- V_String10
   END
   GOTO Quit

   Step_T1_Fail:
END
GOTO Quit


/********************************************************************************
Step T2. Scn = 2041. Batch, SKU
   Batch      (field01)
   SKU/UPC    (field02) -- Input field
********************************************************************************/
Step_T2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField02 -- SKU/UPC

      -- Retain the key-in values
      SET @cOutField02 = @cSKU

      -- Validate blank SKU
      IF @cSKU = '' OR @cSKU IS NULL
      BEGIN
         SET @nErrNo = 67007
         SET @cErrMsg = rdt.rdtgetmessage( 67007, @cLangCode, 'DSP') --'SKU required'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_T2_Fail
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
            SET @nErrNo = 67008
            SET @cErrMsg = rdt.rdtgetmessage( 67008, @cLangCode, 'DSP') --'Invalid SKU'
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_T2_Fail
         END
      END

      -- Get SKU Description
      SELECT TOP 1
         @cSKUDescr = DESCR
      FROM dbo.SKU (NOLOCK) 
      WHERE StorerKey = @cStorer 
         AND SKU = @cSKU

      /******************************************************************************************************************
         For Order Type = 'S' (Shop Order), do not have ExternPOKey, therefore Orders do not exist in RDTCSAudit_BatchPO
         => Retrieve Consignee and BAL QTY for the scanned SKU by: 
            PickDetail.Status = '5'
            PickDetail.CaseID = '' or numeric (created from show pick tab)
            OrderDetail.LoadKey = scanned Batch
         
         For Order Type = 'C' (Cross Dock), 
         => Retrieve Consignee and BAL QTY for the scanned SKU by:
            PickDetail.Status = '5'
            PickDetail.CaseID = '' or numeric (created from show pick tab)
            RDTCSAudit_BatchPO.Batch = scanned Batch
            RDTCSAudit_BatchPO.PO_No = OrderDetail.Lottable03
         Notes: Update follow sequence of Order Type = 'S', then 'C'    
      *******************************************************************************************************************/ 
      
      -- Validate any open record
      IF NOT EXISTS( SELECT 1 -- Order Type = 'S'
         FROM dbo.Orders O (NOLOCK) 
            INNER JOIN dbo.PickDetail PD WITH (NOLOCK, INDEX(PICKDETAIL10)) ON (O.OrderKey = PD.OrderKey)
            INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
         WHERE O.Status < '9'
            AND O.Type = 'S'         
            AND O.StorerKey = @cStorer
            AND PD.StorerKey = @cStorer
            AND PD.SKU = @cSKU
            --AND PD.CaseID = ''
            --AND PD.Status = '5' -- Picked
            --AND PD.UOM = '6' -- Piece
            AND OD.LoadKey = @cBatch)
      BEGIN
         IF NOT EXISTS( SELECT 1 -- Order Type = 'C'
            FROM dbo.Orders O (NOLOCK) 
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK, INDEX(PICKDETAIL10)) ON (O.OrderKey = PD.OrderKey)
               INNER JOIN rdt.RDTCSAudit_BatchPO BPO WITH (NOLOCK) ON (BPO.OrderKey = O.OrderKey)
               INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey AND OD.Lottable03 = BPO.PO_No)
            WHERE O.Status < '9'
               AND O.Type = 'C'            
               AND O.StorerKey = @cStorer
               AND PD.StorerKey = @cStorer
               AND PD.SKU = @cSKU
               --AND PD.CaseID = ''
               --AND PD.Status = '5' -- Picked
               --AND PD.UOM = '6' -- Piece
               AND BPO.Batch = @cBatch)
         BEGIN
            SET @nErrNo = 67009
            SET @cErrMsg = rdt.rdtgetmessage( 67009, @cLangCode, 'DSP') --'No Open Record'
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_T2_Fail            
         END
      END               

      -- Get Balance QTY
      SET @cConsigneeKey = ''
      SET @nPQTY = 0      
      SET @nErrNo = 0
      EXECUTE rdt.rdt_PostPackAudit_ExcStock_GetBalQty
         @cStorer, 
         @cSKU,
         @cBatch,
         @cLangCode,         
         @cConsigneeKey OUTPUT,
         @nPQTY         OUTPUT,          
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT  -- screen limitation, 20 char max

      IF @nErrNo <> 0
         GOTO Step_T2_Fail
     
      SET @cPQTY = CAST (@nPQTY AS NVARCHAR(5))       
                  
      SET @cOutField01 = @cBatch
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr,  1, 20) -- SKU Desc 1
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU Desc 2
      SET @cOutField05 = @cConsigneeKey
      SET @cOutField06 = @cPQTY -- BAL QTY
      SET @cOutField07 = ''     -- PCK QTY

      -- Set screen focus
      EXEC rdt.rdtSetFocusField @nMobile, 7 -- PICK QTY

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cBatch
      
      -- Set next screen focus
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- Workstation

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_T2_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField02 = ''
      SET @cSKU = ''
   END
END
GOTO Quit


/******************************************************************************* 
Step T3. Scn =2042. Batch, SKU, SKU DESC, STORE, BAL QTY, PICK QTY 
   Batch     (field01) 
   SKU       (field02) 
   SKU DESC1 (field03) 
   SKU DESC2 (field04)    
   STORE     (field05) 
   BAL QTY   (field06) 
   PCK QTY   (field07) -- Input field
********************************************************************************/ 
Step_T3: 
BEGIN 
   IF @nInputKey = 1 -- Yes or Send 
   BEGIN
      -- Screen mapping
      SET @cQTY = @cInField07 -- PCK QTY

      -- Retain the key-in values
      SET @cOutField07 = @cQTY
      
      -- Validate blank QTY 
      IF @cQTY = '' OR @cQTY IS NULL 
      BEGIN 
         SET @nErrNo = 67010 
         SET @cErrMsg = rdt.rdtgetmessage( 67010, @cLangCode, 'DSP') --'QTY required' 
         EXEC rdt.rdtSetFocusField @nMobile, 7 
         GOTO Step_T3_Fail 
      END

      -- Validate QTY is numeric
      IF IsNumeric( @cQTY) = 0
      BEGIN
         SET @nErrNo = 67011
         SET @cErrMsg = rdt.rdtgetmessage( 67011, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 7
         GOTO Step_T3_Fail
      END

      -- Validate QTY is integer
      SET @i = 1
      WHILE @i <= LEN( RTRIM( @cQTY))
      BEGIN
         IF NOT (SUBSTRING( @cQTY, @i, 1) >= '0' AND SUBSTRING( @cQTY, @i, 1) <= '9')
         BEGIN
            SET @nErrNo = 67012
            SET @cErrMsg = rdt.rdtgetmessage( 67012, @cLangCode, 'DSP') --'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 7
            GOTO Step_T3_Fail
            BREAK
         END
         SET @i = @i + 1
      END
      
      -- Validate QTY > 0
      SET @nQTY = CAST( @cQTY AS INT) 
      IF @nQTY < 1
      BEGIN
         SET @nErrNo = 67013
         SET @cErrMsg = rdt.rdtgetmessage( 67013, @cLangCode, 'DSP') --'QTY must > 0'
         EXEC rdt.rdtSetFocusField @nMobile, 7
         GOTO Step_T3_Fail
      END

      -- Validate QTY (PCKQTY) and Balance QTY (BALQTY)
      SET @nPQTY = CAST( @cPQTY AS INT) 
      IF @nQTY > @nPQTY
      BEGIN
         SET @nErrNo = 67014
         SET @cErrMsg = rdt.rdtgetmessage( 67014, @cLangCode, 'DSP') --'PCKQTY>BALQTY'
         EXEC rdt.rdtSetFocusField @nMobile, 7
         GOTO Step_T3_Fail
      END
      
      -- Prepare prev screen var
      SET @cOutField01 = @cConsigneeKey
      SET @cOutField02 = @cQTY
      SET @cOutField03 = ''  -- Tote#
      
      -- Set next screen focus
      EXEC rdt.rdtSetFocusField @nMobile, 3

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cBatch
      SET @cOutField02 = '' -- SKU/UPC
      SET @cSKU = ''
      
      EXEC rdt.rdtSetFocusField @nMobile, 2
      
      -- Go to prev screen  
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
   
   Step_T3_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField07 = '' -- PCK QTY
      SET @cQTY = ''      
   END
END
GOTO Quit


/********************************************************************************
Step T4. Scn = 2043. STORE, PICK QTY, TOTE#
   STORE  (field01)
   PCK    (field02)
   TOTE#  (field03)
********************************************************************************/
Step_T4:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cCaseID = @cInField03

      -- Retain the key-in values
      SET @cOutField03 = @cCaseID
      
      -- Validate blank Tote#
      IF @cCaseID = '' OR @cCaseID IS NULL
      BEGIN
         SET @nErrNo = 67015
         SET @cErrMsg = rdt.rdtgetmessage( 67015, @cLangCode, 'DSP') --'Tote required'
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_T4_Fail
      END

      -- Same case scan for 2 Consignees - start
      IF EXISTS( SELECT 1
         FROM RDT.rdtCSAudit CA (NOLOCK) 
         WHERE BatchID = @nBatchID
            AND CaseID = @cCaseID
            AND Status > '0') -- 0=open
      BEGIN
         SET @nErrNo = 67016
         SET @cErrMsg = rdt.rdtgetmessage( 67016, @cLangCode, 'DSP') --'Double scan'
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_T4_Fail
      END

      -- (Vicky01) - Start
      IF EXISTS( SELECT 1
                 FROM RDT.rdtCSAudit_Load ST  (NOLOCK)   
                 WHERE CaseID = @cCaseID
                 AND Status < '9')  -- 0 =open, 5=loading 
      BEGIN
         SET @nErrNo = 67103
         SET @cErrMsg = rdt.rdtgetmessage( 67103, @cLangCode, 'DSP') --Double scan
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_T4_Fail
      END
      -- (Vicky01) - End

      SET @cChkConsigneeKey = ''
      SET @cChkWorkstation = ''
      SELECT 
         @cChkWorkstation = Workstation, 
         @cChkConsigneeKey = ConsigneeKey
      FROM RDT.rdtCSAudit CA (NOLOCK) 
      WHERE BatchID = @nBatchID
         AND CaseID = @cCaseID
         AND Status = '0' -- Open
         AND 
            (Workstation <> @cWorkstation OR -- Same case scan on diff workstation
            ConsigneeKey <> @cConsigneeKey)  -- Same case scan to diff consignee

      IF @@ROWCOUNT > 0
      BEGIN
         -- Same case scanned to different stor
         IF @cChkConsigneeKey <> @cConsigneeKey
         BEGIN
            SET @nErrNo = 67017
            SET @cErrMsg = rdt.rdtgetmessage( 67017, @cLangCode, 'DSP') --'ScanToDiffStor'
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_T4_Fail
         END

         -- Same case scanned on different workstation
         IF @cChkWorkstation <> @cWorkstation
         BEGIN
            SET @nErrNo = 67018
            SET @cErrMsg = rdt.rdtgetmessage( 67018, @cLangCode, 'DSP') --'ScanToDiffWKSt'
            SET @cOutField02 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_T4_Fail
         END
      END
      --Same case scan for 2 Consignees - end

      -- Prevent barcode (numeric) accidentally scanned on this field
      IF IsNumeric( LEFT( @cCaseID, 1)) = 1
      BEGIN
         SET @nErrNo = 67019
         SET @cErrMsg = rdt.rdtgetmessage( 67019, @cLangCode, 'DSP') --'Not a CaseID'
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_T4_Fail
      END
      
      -- Validate more than 1 batch opened for 1 workstation
      IF EXISTS (SELECT 1
         FROM RDT.rdtCSAudit (NOLOCK)
         WHERE StorerKey = @cStorer
            AND WorkStation = @cWorkStation
            AND Status = '0' -- 0=Open, 5=Closed, 9=Printed
            AND BatchID <> @nBatchID )
      BEGIN
         SET @nErrNo = 67020
         SET @cErrMsg = rdt.rdtgetmessage( 67020, @cLangCode, 'DSP') --'DiffOpenBatch'
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_T4_Fail
      END

      -- Initiate next screen var
      SET @cOutField01 = @cCaseID -- Tote#
      SET @cOutField02 = ''       -- RefNo1
      SET @cOutField03 = ''       -- RefNo2
      SET @cOutField04 = ''       -- RefNo3
      SET @cOutField05 = ''       -- RefNo4
      SET @cOutField06 = ''       -- RefNo5

      -- Init var (needed by next screen logic)
      SET @cRefNo1 = ''
      SET @cRefNo2 = ''
      SET @cRefNo3 = ''
      SET @cRefNo4 = ''
      SET @cRefNo5 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- RefNo1

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prep prev screen var
      SET @cOutField01 = @cBatch
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr,  1, 20) -- SKU Desc 1
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU Desc 2
      SET @cOutField05 = @cConsigneeKey
      SET @cOutField06 = @cPQTY -- BAL QTY
      SET @cOutField07 = ''     -- PCK QTY

      -- Set screen focus
      EXEC rdt.rdtSetFocusField @nMobile, 6 -- PICK QTY

      -- Go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_T4_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField03 = '' -- Tote#
      SET @cCaseID = ''
   END
END
GOTO Quit


/********************************************************************************
Step T5. Scn = 2044. TOTE#, REFNO 1..5
   TOTE#    (field01)
   Ref No 1 (field02) -- Input field
   Ref No 2 (field03) -- Input field
   Ref No 3 (field04) -- Input field
   Ref No 4 (field05) -- Input field
   Ref No 5 (field06) -- Input field  
********************************************************************************/
Step_T5:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Check if newly added CSAudit record, if yes then no need to check tote#+seal#
      IF EXISTS (SELECT 1 FROM RDT.rdtCSAudit (NOLOCK) 
         WHERE BatchID = @nBatchID
         AND CaseID = @cCaseID
         AND Status = '0')
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM RDT.rdtCSAudit (NOLOCK) 
            WHERE BatchID = @nBatchID
               AND CaseID = @cCaseID
               AND RefNo1 = @cInField02
               AND RefNo2 = @cInField03
               AND RefNo3 = @cInField04
               AND RefNo4 = @cInField05
               AND RefNo5 = @cInField06
               AND Status = '0')
         BEGIN
            SET @nErrNo = 67021
            SET @cErrMsg = rdt.rdtgetmessage( 67021, @cLangCode, 'DSP') --'WrongRefno'
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END
      END

      -- Validate if RefNo changed
      IF @cRefNo1 <> @cInField02 OR
         @cRefNo2 <> @cInField03 OR
         @cRefNo3 <> @cInField04 OR
         @cRefNo4 <> @cInField05 OR
         @cRefNo5 <> @cInField06
      -- There are changes, remain in current screen
      BEGIN
         -- Set next field focus
         SET @i = 2
         IF @cInField02 <> '' SET @i = @i + 1
         IF @cInField03 <> '' SET @i = @i + 1
         IF @cInField04 <> '' SET @i = @i + 1
         IF @cInField05 <> '' SET @i = @i + 1
         IF @cInField06 <> '' SET @i = @i + 1
         IF @i > 6 SET @i = 2
         EXEC rdt.rdtSetFocusField @nMobile, @i
         
         -- Retain key-in value
         SET @cOutField02 = @cInField02
         SET @cOutField03 = @cInField03
         SET @cOutField04 = @cInField04
         SET @cOutField05 = @cInField05
         SET @cOutField06 = @cInField06

         -- Remain in current screen
         -- SET @nScn = @nScn + 1
         -- SET @nStep = @nStep + 1
      END
      ELSE
      -- No changes, means go to next screen
      BEGIN  
         -- Init next screen var
         SET @cOutField01 = @cInField02     -- RefNo1
         SET @cOutField02 = @cInField03     -- RefNo2
         SET @cOutField03 = @cInField04     -- RefNo3
         SET @cOutField04 = @cInField05     -- RefNo4
         SET @cOutField05 = @cInField06     -- RefNo5
         SET @cOutField06 = @cDefaultOption -- Option
   
         -- Set next screen focus
         EXEC rdt.rdtSetFocusField @nMobile, 6  -- OPTION
   
         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      
      -- Save current screen var
      SET @cRefNo1 = @cInField02
      SET @cRefNo2 = @cInField03
      SET @cRefNo3 = @cInField04
      SET @cRefNo4 = @cInField05
      SET @cRefNo5 = @cInField06
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cCaseID
      SET @cOutField02 = '' -- RefNo1
      SET @cOutField03 = '' -- RefNo2
      SET @cOutField04 = '' -- RefNo3
      SET @cOutField05 = '' -- RefNo4
      SET @cOutField06 = '' -- RefNo5
      
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit  
END
GOTO Quit

/********************************************************************************
Step T6. Scn = 2045. REFNO 1..5, OPTION
   Option (field01) -- Input field
********************************************************************************/
Step_T6:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField06
      
      -- Retain the key-in values
      SET @cOutField06 = @cOption      

      -- Validate blank Option
      IF @cOption = '' OR @cOption IS NULL 
      BEGIN
         SET @nErrNo = 67022
         SET @cErrMsg = rdt.rdtgetmessage( 67022, @cLangCode, 'DSP') --'Option req'
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Step_T6_Fail         
      END

      -- Validate Option (only allowed 1=YES, 2=NO)
      IF (@cOption <> '1' AND @cOption <> '2')
      BEGIN
         SET @nErrNo = 67023
         SET @cErrMsg = rdt.rdtgetmessage( 67023, @cLangCode, 'DSP') --'Invalid Option'
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Step_T6_Fail
      END

      IF @cOption = '1' -- YES
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
            GOTO Step_T6_Fail -- Error

         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      
      IF @cOption = '2' -- NO
      BEGIN
         -- Prepare prev screen var
         SET @cOutField01 = @cCaseID -- Tote#
         SET @cOutField02 = @cRefNo1
         SET @cOutField03 = @cRefNo2
         SET @cOutField04 = @cRefNo3
         SET @cOutField05 = @cRefNo4
         SET @cOutField06 = @cRefNo5
         
         -- Set next screen focus
         SET @i = 1
         IF @cRefNo1 <> '' SET @i = @i + 1
         IF @cRefNo2 <> '' SET @i = @i + 1
         IF @cRefNo3 <> '' SET @i = @i + 1
         IF @cRefNo4 <> '' SET @i = @i + 1
         IF @cRefNo5 <> '' SET @i = @i + 1
         IF @i > 5 SET @i = 1
         EXEC rdt.rdtSetFocusField @nMobile, @i
   
         -- Go to prev screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
   END
   
   IF @nInputKey = 0 -- No or Esc
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cCaseID -- Tote#
      SET @cOutField02 = @cRefNo1
      SET @cOutField03 = @cRefNo2
      SET @cOutField04 = @cRefNo3
      SET @cOutField05 = @cRefNo4
      SET @cOutField06 = @cRefNo5
      
      -- Set next screen focus
      SET @i = 1
      IF @cRefNo1 <> '' SET @i = @i + 1
      IF @cRefNo2 <> '' SET @i = @i + 1
      IF @cRefNo3 <> '' SET @i = @i + 1
      IF @cRefNo4 <> '' SET @i = @i + 1
      IF @cRefNo5 <> '' SET @i = @i + 1
      IF @i > 5 SET @i = 1
      EXEC rdt.rdtSetFocusField @nMobile, @i

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1      
   END
   GOTO Quit

   Step_T6_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- Option
      SET @cOption = ''
   END
END
GOTO Quit


/********************************************************************************
Step T7. Scn = 2046. Successful Message
********************************************************************************/
Step_T7:
BEGIN
   IF @nInputKey = 0 OR @nInputKey = 1 -- Esc or No / Yes or Send
   BEGIN   
      -- Prep next screen var
      SET @cOutField01 = @cBatch
      SET @cOutField02 = '' -- SKU/UPC  
      SET @cSKU = ''
      
      -- Set next screen focus
      EXEC rdt.rdtSetFocusField @nMobile, 2
   
      -- Go to 2nd Screen 2. Batch, SKU screen
      SET @nScn = @nScn - 5
      SET @nStep = @nStep - 5
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
      V_CaseID       = @cCaseID,
      V_SKU          = @cSKU,
      V_SKUDescr     = @cSKUDescr,

      V_String1      = @cWorkStation, 
      V_String2      = @cQTY, 
      V_String3      = @cPQTY, 
      V_String4      = @cRefNo1, 
      V_String5      = @cRefNo2, 
      V_String6      = @cRefNo3, 
      V_String7      = @cRefNo4, 
      V_String8      = @cRefNo5, 
      V_String9      = @nBatchID, 
      V_String10     = @cBatch,
      
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