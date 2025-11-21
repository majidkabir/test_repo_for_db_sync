SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdtfnc_Move_PrePack_SKU                             */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose:                                                             */  
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
/* 14-08-2007 1.0  WengThai Create                                      */  
/* 16-08-2007 1.1  Vicky    Modified                                    */  
/* 21-09-2007 1.2  Vicky    Change of Spec - Qty Avail should display   */  
/*                          according to scanned UOM                    */  
/* 03-11-2008 1.3  Vicky    Remove XML part of code that is used to     */  
/*                          make field invisible and replace with new   */  
/*                          code (Vicky02)                              */  
/* 06-07-2008 1.4  Vicky    Add in EventLog (Vicky06)                   */  
/* 16-10-2009 1.5  Ricky    To include the link by LOT between          */  
/*                          LOTXLOCXID and LOTATTRIBUTE (RY001)         */  
/* 12-08-2010 1.6  Vicky    Clear variables (Vicky07)                   */  
/* 13-08-2010 1.7  James    Clear Variables (james01)                   */
/* 2010-09-15 1.8  Shong    QtyAvailable Should exclude QtyReplen       */
/* 2016-09-30 1.9  Ung      Performance tuning                          */
/* 2018-10-24 2.0  TungGH   Performance                                 */
/************************************************************************/  
  
CREATE  PROCEDURE [RDT].[rdtfnc_Move_PrePack_SKU] (  
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
   @nRowCount     INT,   
   @cChkFacility  NVARCHAR( 5),  
   @cXML          NVARCHAR( 4000) -- To allow double byte data for e.g. SKU desc  
  
  
-- RDT.RDTMobRec variable  
DECLARE   
   @nFunc       INT,  
   @nScn        INT,  
   @nStep       INT,  
   @cLangCode   NVARCHAR( 3),  
   @nInputKey   INT,  
   @nMenu       INT,  
                  
   @cStorerKey  NVARCHAR( 15),  
   @cFacility   NVARCHAR( 5),   
                  
   @cFromLOC    NVARCHAR( 10),   
   @cFromID     NVARCHAR( 18),   
   @cSKU        NVARCHAR( 20),   
   @cSKUDescr   NVARCHAR( 60),   
   @cCompSKU    NVARCHAR( 20),   
   @cFromUPC    NVARCHAR( 20),  
   @cCompSKULOC NVARCHAR( 20),  
   @nPackCnt    INT,  
     
   @cPUOM       NVARCHAR( 5), -- Pref UOM   
   @cPUOM_Desc  NVARCHAR( 5), -- Pref UOM desc  
   @cMUOM_Desc  NVARCHAR( 5), -- Master UOM desc  
   @nQTY_Avail  INT,      -- QTY avail in master UOM  
   @nPQTY_Avail INT,      -- QTY avail in pref UOM  
   @nMQTY_Avail INT,      -- Remaining QTY in master UOM  
   @nQTY        INT,      -- QTY to move, in master UOM  
   @nPQTY       INT,      -- QTY to move, in pref UOM  
   @nMQTY       INT,      -- Remining QTY to move, in master UOM  
   @nPUOM_Div   INT,   
  
   @cToLOC      NVARCHAR( 10),   
   @cToID       NVARCHAR( 18),   
   @cParentSKU  NVARCHAR( 20),  
     
   @nCompQTY        INT,      -- Component QTY in Bill Of Material  
   @nCompQTY_Avail  INT,      -- Component QTY avail in master UOM  
   @nCompPQTY_Avail INT,      -- Component QTY avail in pref UOM  
   @nCompMQTY_Avail INT,      -- Remaining Component QTY in master UOM  
   @nCompQTY_Show   INT,  
   @nTotalQty       INT,  
   @nLooseLocChk    INT,  
  
   @nCountSku   INT,   
   @nTempCount  INT,  
  
   @cUserName   NVARCHAR(18), -- (Vicky06)  
  
   @cPQTY       NVARCHAR( 5),  
   @cMQTY       NVARCHAR( 5),  
     
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
  
   -- (Vicky02) - Start  
   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),  
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),  
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),  
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),  
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),  
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),  
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),  
   @cFieldAttr15 NVARCHAR( 1)  
   -- (Vicky02) - End  
  
-- Commented (Vicky02) - Start  
-- -- Session screen  
-- DECLARE @tSessionScrn TABLE  
-- (  
--    Typ       NVARCHAR( 10),   
--    X         NVARCHAR( 4),    -- size 4 is needed bcoz of 'NULL'  
--    Y         NVARCHAR( 4),    -- size 4 is needed bcoz of 'NULL'  
--    Length    NVARCHAR( 4),    -- size 4 is needed bcoz of 'NULL'  
--    [ID]      NVARCHAR( 10),   
--    [Default] NVARCHAR( 60),   
--    Value     NVARCHAR( 60),   
--    [NewID]   NVARCHAR( 10)  
-- )  
-- Commented (Vicky02) - End  
  
-- Load RDT.RDTMobRec  
SELECT   
   @nFunc       = Func,  
   @nScn        = Scn,  
   @nStep       = Step,  
   @nInputKey   = InputKey,  
   @nMenu       = Menu,  
   @cLangCode   = Lang_code,  
  
   @cStorerKey  = StorerKey,  
   @cFacility   = Facility,  
   @cUserName   = UserName,-- (Vicky06)  
  
   @cFromLOC    = V_String1,   
   @cFromID     = V_String2,   
   @cSKU        = V_String3,   
   @cSKUDescr   = V_SKUDescr,   
  
   @cPUOM       = V_UOM,     -- Pref UOM  
   @cPUOM_Desc  = V_String4, -- Pref UOM desc  
   @cMUOM_Desc  = V_String5, -- Master UOM desc  
   
   @nQTY_Avail  = V_Integer1,   
   @nPQTY_Avail = V_Integer2,   
   @nMQTY_Avail = V_Integer3,   
   @nQTY        = V_Integer4,
   @nCompQTY_Show  = V_Integer5,   
   @nCompQTY_Avail = V_Integer6,   
   @nCompQTY       = V_Integer7,
   @nPackCnt    = V_Integer8,  
   @nCountSku   = V_Integer9,   
        
   @nPQTY       = V_PQTY,   
   @nMQTY       = V_MQTY,   
   @nPUOM_Div   = V_PUOM_Div,   
  
   @cToLOC      = V_String13,   
   @cToID       = V_String14,   
   @cFromUPC    = V_String15,   
  
   @cParentSKU     = V_String16,     
    
   @cCompSKU    = V_String20,     
  
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
  
   -- (Vicky02) - Start  
   @cFieldAttr01  = FieldAttr01,    @cFieldAttr02   = FieldAttr02,  
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,  
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,  
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,  
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,  
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,  
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,  
   @cFieldAttr15 =  FieldAttr15  
   -- (Vicky02) - End  
  
FROM RDTMOBREC (NOLOCK)  
WHERE Mobile = @nMobile  
  
IF @nFunc = 516 -- Move SKU  
BEGIN  
   -- Redirect to respective screen  
   IF @nStep = 0 GOTO Step_0   -- Func = Move SKU  
   IF @nStep = 1 GOTO Step_1   -- Scn = 1530. FromID  
   IF @nStep = 2 GOTO Step_2   -- Scn = 1531. FromLOC  
   IF @nStep = 3 GOTO Step_3   -- Scn = 1532. SKU, desc1, desc2  
   IF @nStep = 4 GOTO Step_4   -- Scn = 1533. UOM, QTY  
   IF @nStep = 5 GOTO Step_5   -- Scn = 1536. ToID  
   IF @nStep = 6 GOTO Step_6   -- Scn = 1537. ToLOC  
   IF @nStep = 7 GOTO Step_7   -- Scn = 1538. Message  
END  
  
RETURN -- Do nothing if incorrect step  
  
  
/********************************************************************************  
Step 0. func = 516. Menu  
********************************************************************************/  
Step_0:  
BEGIN  
   -- Set the entry point  
   SET @nScn = 1530  
   SET @nStep = 1  
  
-- Commented (Vicky02) - Start  
--    -- Create the session data  
--    IF EXISTS (SELECT 1 FROM RDTSessionData (NOLOCK) WHERE Mobile = @nMobile)  
--       UPDATE RDTSessionData WITH (ROWLOCK) SET XML = '' WHERE Mobile = @nMobile  
--    ELSE  
--       INSERT INTO RDTSessionData (Mobile) VALUES (@nMobile)  
-- Commented (Vicky02) - End  
  
  
   -- Get prefer UOM  
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA  
   FROM RDT.rdtMobRec M (NOLOCK)  
      INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)  
   WHERE M.Mobile = @nMobile  
  
    -- (Vicky06) EventLog - Sign In Function  
    EXEC RDT.rdt_STD_EventLog  
     @cActionType = '1', -- Sign in function  
     @cUserID     = @cUserName,  
     @nMobileNo   = @nMobile,  
     @nFunctionID = @nFunc,  
     @cFacility   = @cFacility,  
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep  
  
   -- Prep next screen var  
   SET @cFromLOC = ''  
  
   -- (Vicky07) - Start  
   SET @cPQTY = ''  
   SET @cMQTY = ''  
   SET @cToLOC      = ''  
   SET @cToID       = ''  
   SET @cFromUPC    = ''  
   SET @cSKU        = ''  
   SET @cParentSKU  = ''  
   SET @cCompSKU    = ''  
   SET @nQTY_Avail  = 0  
   SET @nPQTY_Avail = 0  
   SET @nMQTY_Avail = 0  
   SET @nQTY        = 0  
   SET @nPQTY       = 0  
   SET @nMQTY       = 0  
   SET @nPackCnt    = 0  
   SET @nCountSku   = 0  
   SET @nCompQTY_Show  = 0  
   SET @nCompQTY_Avail = 0  
   SET @nCompQTY       = 0    
   -- (Vicky07) - End  
  
   SET @cOutField01 = '' -- FromLOC  
   SET @cOutField02 = ''  
   SET @cOutField03 = ''  
   SET @cOutField04 = ''  
   SET @cOutField05 = ''  
   SET @cOutField06 = ''  
   SET @cOutField07 = ''  
   SET @cOutField08 = ''  
   SET @cOutField09 = ''  
   SET @cOutField10 = ''  
   SET @cOutField11 = ''  
  
   -- (Vicky02) - Start  
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
   -- (Vicky02) - End  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 1. Scn = 1530. FromLOC  
   FromLOC (field01, input)  
********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Screen mapping  
      SET @cFromLOC = @cInField01  
  
      -- Validate blank  
      IF @cFromLOC = '' OR @cFromLOC IS NULL  
      BEGIN  
         SET @nErrNo = 63451  
         SET @cErrMsg = rdt.rdtgetmessage( 63451, @cLangCode, 'DSP') --'LOC needed'  
         GOTO Step_1_Fail  
      END  
  
      -- Get LOC info  
      SELECT @cChkFacility = Facility  
      FROM dbo.LOC (NOLOCK)  
      WHERE LOC = @cFromLOC  
  
      -- Validate LOC  
      IF @@ROWCOUNT = 0  
      BEGIN  
         SET @nErrNo = 63452  
         SET @cErrMsg = rdt.rdtgetmessage( 63452, @cLangCode, 'DSP') --'Invalid LOC'  
         GOTO Step_1_Fail  
      END  
  
      -- Validate LOC's facility  
      IF @cChkFacility <> @cFacility  
      BEGIN  
         SET @nErrNo = 63453  
         SET @cErrMsg = rdt.rdtgetmessage( 63453, @cLangCode, 'DSP') --'Diff facility'  
         GOTO Step_1_Fail  
      END  
  
      -- Get StorerConfig 'UCC'  
      DECLARE @cUCCStorerConfig NVARCHAR( 1)  
      SELECT @cUCCStorerConfig = SValue  
      FROM dbo.StorerConfig (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
         AND ConfigKey = 'UCC'  
        
      -- Check UCC exists  
      IF @cUCCStorerConfig = '1'  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.UCC (NOLOCK)   
            WHERE Storerkey = @cStorerKey  
               AND LOC = @cFromLOC  
               AND Status = 1) -- 1=Received  
         BEGIN  
            SET @nErrNo = 63454  
            SET @cErrMsg = rdt.rdtgetmessage( 63454, @cLangCode, 'DSP') --'LOC have UCC'  
            GOTO Step_1_Fail  
         END  
      END  
        
      -- Prep next screen var  
      SET @cFromID = ''  
      SET @cOutField01 = @cFromLOC  
      SET @cOutField02 = '' --@cFromID  
  
      -- Go to next screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
     -- (Vicky06) EventLog - Sign Out Function  
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
  
   -- (Vicky07) - Start  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
      SET @cOutField07 = ''  
      SET @cOutField08 = ''  
      SET @cOutField09 = ''  
      SET @cOutField10 = ''  
      SET @cOutField11 = ''  
  
      SET @cPQTY = ''  
      SET @cMQTY = ''  
      SET @cToLOC      = ''  
      SET @cToID       = ''  
      SET @cFromUPC    = ''  
      SET @cSKU        = ''  
      SET @cParentSKU  = ''  
      SET @cCompSKU    = ''  
      SET @nQTY_Avail  = 0  
      SET @nPQTY_Avail = 0  
      SET @nMQTY_Avail = 0  
      SET @nQTY        = 0  
      SET @nPQTY       = 0  
      SET @nMQTY       = 0  
      SET @nPackCnt    = 0  
      SET @nCountSku   = 0  
      SET @nCompQTY_Show  = 0  
      SET @nCompQTY_Avail = 0  
      SET @nCompQTY       = 0  
   -- (Vicky07) - End  
  
  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
   END  
   GOTO Quit  
  
   Step_1_Fail:  
   BEGIN  
      SET @cFromLOC = ''  
      SET @cOutField01 = '' -- LOC  
   END  
END  
GOTO Quit  
  
   
/********************************************************************************  
Step 2. Scn = 1531. FromID  
   FromLOC (field01)  
   FromID  (field02, input)  
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Screen mapping  
      SET @cFromID = @cInField02  
  
      -- Validate ID  
      IF NOT EXISTS ( SELECT 1   
         FROM dbo.LOTxLOCxID (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
            AND LOC = @cFromLOC  
            AND ID = @cFromID  
            AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)) > 0)  
      BEGIN  
         SET @nErrNo = 63455  
         SET @cErrMsg = rdt.rdtgetmessage( 63455, @cLangCode, 'DSP') --'Invalid ID'  
         GOTO Step_2_Fail  
      END  
  
      -- Prep next screen var  
      SET @cOutField01 = @cFromLOC  
      SET @cOutField02 = @cFromID  
      SET @cOutField03 = '' --@cSKU  
  
      -- Go to next screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      -- Prep next screen var  
      SET @cFromLOC = ''  
      SET @cOutField01 = @cFromLOC  
  
      -- Go to prev screen  
      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
   GOTO Quit  
  
   Step_2_Fail:  
   BEGIN  
      SET @cFromID  = ''  
      SET @cOutField02 = '' -- ID  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 3. scn = 1532. SKU screen  
   FromLOC (field01)  
   FromID  (field02)  
   SKU     (field03, input)  
********************************************************************************/  
Step_3:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Screen mapping  
      SET @cSKU = @cInField03  
  
      -- Validate blank  
      IF @cSKU = '' OR @cSKU IS NULL  
      BEGIN  
         SET @nErrNo = 63456  
         SET @cErrMsg = rdt.rdtgetmessage( 63456, @cLangCode, 'DSP') --'SKU needed'  
         GOTO Step_3_Fail  
      END  
        
  
      -- Validate SKU  
      IF @cSKU <> '' AND @cSKU IS NOT NULL  
      BEGIN  
         -- Assumption: no SKU with same barcode.  
         -- If scan in ParentSKU, then skip searching from UPC,   
         -- if cant find in SKU master, then search in UPC  
         SELECT TOP 1  
            @cSKU = SKU.SKU  
         FROM dbo.SKU SKU (NOLOCK)   
         WHERE SKU.StorerKey = @cStorerKey  
            AND @cSKU IN (SKU.SKU, SKU.AltSKU, SKU.RetailSKU, SKU.ManufacturerSKU)  
  
         IF @@ROWCOUNT = 0  
         BEGIN  
            -- Search UPC  
            SELECT TOP 1  
               @cParentSKU = UPC.SKU  
            FROM dbo.UPC UPC (NOLOCK)   
            WHERE UPC.StorerKey = @cStorerKey  
               AND UPC.UPC = @cSKU  
  
            IF @@ROWCOUNT = 0  
            BEGIN  
               SET @nErrNo = 63457  
               SET @cErrMsg = rdt.rdtgetmessage( 63457, @cLangCode, 'DSP') --'Invalid SKU'  
               GOTO Step_3_Fail  
            END  
            ELSE  
            BEGIN  
               SELECT @nPackCnt = CASE UPC.UOM  
                        WHEN 'IP' THEN Pack.InnerPack -- Inner pack  
                        WHEN 'CS' THEN Pack.CaseCnt -- Case  
                        WHEN 'SH' THEN Pack.OtherUnit1 -- OtherUnit1  
                        WHEN 'PL' THEN Pack.Pallet -- Pallet  
                     END,  
                     @cPUOM = RTRIM(UPC.UOM),  
                     @cSKUDescr = SKU.DESCR  
                FROM dbo.UPC UPC WITH (NOLOCK)   
               JOIN dbo.SKU SKU WITH (NOLOCK)  
                  ON (UPC.StorerKey = SKU.StorerKey AND  
                      UPC.SKU = SKU.SKU)  
               JOIN dbo.PACK Pack WITH (NOLOCK)  
                  ON (SKU.PackKey = Pack.PackKey)  
               WHERE UPC.StorerKey = @cStorerKey  
               AND   UPC.UPC = @cSKU  
  
               SET @cSKU = @cParentSKU  
          END  
         END  
         ELSE  
         BEGIN  
            SET @cParentSKU = @cSKU  
            SET @cPUOM = 'PK'  
         END  
  
       --get num of componentsku  
       SELECT @nCountSku = COUNT(ComponentSku)  
       FROM dbo.BILLOFMATERIAL WITH (NOLOCK)  
       WHERE SKU = @cParentSKU  
       AND   StorerKey = @cStorerKey  
  
       SET @nTempCount = 1  
       WHILE @nTempCount <= @nCountSku  
       BEGIN  
          SET @cCompSKULOC = ''  
            SET @nLooseLocChk = 0  
  
            SELECT @cCompSKULOC = ComponentSKU  
            FROM  dbo.BILLOFMATERIAL WITH (NOLOCK)  
          WHERE SKU = @cParentSKU  
          AND   StorerKey = @cStorerKey  
            AND   Sequence = CONVERT(CHAR, @nTempCount)  
  
            SELECT @nLooseLocChk = 1   
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
            JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK)  
              ON (LA.Storerkey = LLI.Storerkey AND LA.SKU = LLI.SKU AND LA.LOT = LLI.LOT) -- RY001  
            JOIN dbo.LOC LOC WITH (NOLOCK)  
              ON (LOC.LOC = LLI.LOC)  
            WHERE LLI.StorerKey = @cStorerKey  
               AND LLI.LOC = @cFromLOC  
               AND LLI.ID = @cFromID  
               AND LLI.SKU = @cCompSKULOC  
               AND LA.Lottable03 = @cParentSKU  
               AND LOC.LocationType = 'Loose' -- to be determined  
  
               
            IF @nLooseLocChk = 1  
            BEGIN  
               SET @nErrNo = 63458  
               SET @cErrMsg = rdt.rdtgetmessage( 63458, @cLangCode, 'DSP') --'FrLOC is Loose '  
               GOTO Step_3_Fail  
            END  
  
          SET @nTempCount = @nTempCount + 1  
              
      END --end of while loop  
          
--         DECLARE C_Component CURSOR FAST_FORWARD READ_ONLY FOR   
           SELECT TOP 1 @cCompSKU = ComponentSku,   
                        @nCompQTY = Qty   
             FROM dbo.BILLOFMATERIAL WITH (NOLOCK)  
           WHERE  StorerKey = @cStorerKey  
           AND    SKU = @cParentSKU       
         
--          OPEN C_Component  
--   
--          FETCH NEXT FROM C_Component INTO @cCompSKU, @nCompQTY  
--   
--          WHILE @@FETCH_STATUS <> -1  
--          BEGIN  
  
            -- Get QTY avail  
            SELECT @nCompQTY_Avail = SUM( LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))  
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
            JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK)  
                 ON (LA.Storerkey = LLI.Storerkey AND LA.SKU = LLI.SKU AND LA.LOT = LLI.LOT) -- RY001  
            WHERE LLI.StorerKey = @cStorerKey  
               AND LLI.LOC = @cFromLOC  
               AND LLI.ID = @cFromID  
               AND LLI.SKU = @cCompSKU  
               AND LA.Lottable03 = @cParentSKU  
              
            -- Validate not QTY  
            IF @nCompQTY_Avail = 0 OR @nCompQTY_Avail IS NULL  
            BEGIN  
               SET @nErrNo = 63459  
               SET @cErrMsg = rdt.rdtgetmessage( 63459, @cLangCode, 'DSP') --'No QTY to move'  
               SET @nCompQTY_Show = 0  
               GOTO Step_3_Fail  
            END  
            
            -- To get the QtyAvail for Prepack. Just show 1 ComponentSKU  
            SET @nCompQTY_Show = 0  
            SET @nCompQTY_Show = @nCompQTY_Avail / @nCompQTY        
  
            -- Get Component SKU info  
--             SELECT   
--                @cSKUDescr = S.DescR,   
--                @cMUOM_Desc = Pack.PackUOM3,   
--                @cPUOM_Desc =   
--                   CASE @cPUOM  
--                      WHEN '2' THEN Pack.PackUOM1 -- Case  
--                      WHEN '3' THEN Pack.PackUOM2 -- Inner pack  
--                      WHEN '6' THEN Pack.PackUOM3 -- Master unit  
--                      WHEN '1' THEN Pack.PackUOM4 -- Pallet  
--                      WHEN '4' THEN Pack.PackUOM8 -- Other unit 1  
--                      WHEN '5' THEN Pack.PackUOM9 -- Other unit 2  
--                   END,   
--                @nPUOM_Div = CAST(   
--                   CASE @cPUOM  
--                      WHEN '2' THEN Pack.CaseCNT  
--                      WHEN '3' THEN Pack.InnerPack  
--                      WHEN '6' THEN Pack.QTY  
--                      WHEN '1' THEN Pack.Pallet  
--                      WHEN '4' THEN Pack.OtherUnit1  
--                      WHEN '5' THEN Pack.OtherUnit2  
--                   END AS INT)  
--             FROM dbo.SKU S (NOLOCK)   
--             INNER JOIN dbo.Pack Pack (nolock) ON (S.PackKey = Pack.PackKey)  
--             WHERE StorerKey = @cStorerKey  
--                AND SKU = @cCompSKU  
  
            -- Convert to prefer UOM QTY  
            IF @cPUOM = 'PK'  -- When preferred UOM = master unit   
            BEGIN  
--               SET @cPUOM_Desc = ''  
               SET @nCompPQTY_Avail = 0  
               SET @nCompMQTY_Avail = @nCompQTY_Show--@nCompQTY_Avail -- Bug fix by Vicky on 09-Aug-2007  
            END  
            ELSE  
            BEGIN  
--                SET @cErrMsg = CAst((@nPackCnt * @nCompQTY) as char)  
--                GOTO Step_3_Fail  
  
               SET @nCompPQTY_Avail = @nCompQTY_Show / @nPackCnt --  (RY001)( @nPackCnt * @nCompQTY)--@nCompQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM  
               SET @nCompMQTY_Avail = @nCompQTY_Show  % @nPackCnt -- (RY001)( @nPackCnt * @nCompQTY)--@nCompQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit  
            END  
        
            SET @nPQTY_Avail = @nCompPQTY_Avail  
            SET @nMQTY_Avail = @nCompMQTY_Avail --@nMQTY_Avail + @nCompMQTY_Avail  
              
--            FETCH NEXT FROM C_Component INTO @cCompSKU, @nCompQTY  
  
--          END --WHILE HEADER  
--   
--          CLOSE C_Component  
--          DEALLOCATE C_Component  
           
      END  
  
      -- Prep next screen var  
--       SET @cOutField01 = @cFromID  
--       SET @cOutField02 = @cFromLOC  
              
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
    SET @cOutField07 = ''  
    SET @cOutField08 = ''  
      SET @cOutField09 = ''  
      SET @cOutField10 = ''  
      SET @cOutField11 = ''  
  
      SET @cOutField01 = @cFromLOC -- Bug fix by Vicky on 09-Aug-2007  
      SET @cOutField02 = @cFromID  -- Bug fix by Vicky on 09-Aug-2007  
      SET @cOutField03 = @cParentSKU  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1  
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2  
      IF @cPUOM <> 'PK'  
      BEGIN  
       SET @cOutField06 = @cPUOM  
       SET @cOutField07 = @nPQTY_Avail--CAST( @nPQTY_Avail AS NVARCHAR( 5))  
       SET @cOutField08 = '' -- @nPQTY  
      END  
      ELSE  
      BEGIN  
       SET @cOutField06 = ''  
       SET @cOutField07 = ''--CAST( @nPQTY_Avail AS NVARCHAR( 5))  
       SET @cOutField08 = '' -- @nPQTY  
         SET @cFieldAttr08 = 'O' -- (Vicky02)  
         --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')  
         SET @cInField08 = '' -- (james01)
      END  
        
      SET @cOutField09 = 'PK'--@cPUOM--@cMUOM_Desc  
      SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 5))  
      SET @cOutField11 = '' --@nMQTY  
  
      IF @cPUOM <> 'PK'   
      BEGIN  
        SET @cFieldAttr11 = 'O' -- (Vicky02)  
        --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field11', 'NULL', 'output', 'NULL', 'NULL', '')  
         SET @cInField11 = '' -- (james01)
      END  
        
      -- Go to next screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      -- Prepare prev screen var  
      SET @cFromID = ''  
      SET @cSKU = ''  
      SET @cParentSKU = ''  
      SET @cOutField01 = @cFromLOC  
      SET @cOutField02 = '' --@cFromID  
  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
  
      -- Go to prev screen  
      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
   GOTO Quit  
  
   Step_3_Fail:  
   BEGIN  
      -- Reset this screen var  
      SET @cParentSKU = ''  
      SET @cSKU = ''  
      SET @cOutField03 = '' -- SKU  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 4. Scn = 1533. QTY screen  
   FromLOC (field01)  
   FromID  (field02)  
   SKU     (field03)  
   Desc1   (field04)  
   Desc2   (field05)  
   UOM     (field06, field09)  
   QTY AVL (field07, field10)  
   QTY MV  (field08, field11, input)  
********************************************************************************/  
Step_4:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Screen mapping  
      SET @cPQTY = @cInField08  
      SET @cMQTY = @cInField11  
  
      -- Retain the key-in value  
      SET @cOutField08 = @cInField08 -- Pref QTY  
      SET @cOutField11 = @cInField11 -- Master QTY  
  
      IF @cPUOM <> 'PK'  
      BEGIN  
         SET @cMQTY = 0  
      END  
  
      -- Validate PQTY  
      IF ISNULL(@cPQTY, '') = '' SET @cPQTY = '0' -- Blank taken as zero  
      IF RDT.rdtIsValidQTY( @cPQTY, 0) = 0  
      BEGIN  
         SET @nErrNo = 63460  
         SET @cErrMsg = rdt.rdtgetmessage( 63460, @cLangCode, 'DSP') --'Invalid QTY'  
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY  
         GOTO Step_4_Fail  
      END  
        
      -- Validate MQTY  
      IF ISNULL(@cMQTY, '')  = '' SET @cMQTY  = '0' -- Blank taken as zero  
      IF RDT.rdtIsValidQTY( @cMQTY, 0) = 0  
      BEGIN  
         SET @nErrNo = 63461  
         SET @cErrMsg = rdt.rdtgetmessage( 63461, @cLangCode, 'DSP') --'Invalid QTY'  
         EXEC rdt.rdtSetFocusField @nMobile, 11 -- MQTY  
         GOTO Step_4_Fail  
      END  
  
      DECLARE @cPUOM1 NVARCHAR(5)  
  
      IF @cPUOM = 'PL'   
      BEGIN  
        SELECT @cPUOM1 = '1'  
      END  
      ELSE IF @cPUOM = 'CS'  
      BEGIN  
        SELECT @cPUOM1 = '2'  
      END  
      ELSE IF @cPUOM = 'IP'  
      BEGIN  
        SELECT @cPUOM1 = '3'  
      END  
      ELSE IF @cPUOM = 'SH'  
      BEGIN  
        SELECT @cPUOM1 = '4'  
      END  
      ELSE IF @cPUOM = 'PK'  
      BEGIN  
        SELECT @cPUOM1 = '6'  
      END  
  
      -- Calc total QTY in master UOM  
      SET @nPQTY = CAST( @cPQTY AS INT)  
      SET @nMQTY = CAST( @cMQTY AS INT)  
        
      IF @cPUOM <> 'PK'  
      BEGIN  
         SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cParentSKU, @cPQTY, @cPUOM1, 6) -- Convert to QTY in master UOM  
      END  
  
      SET @nQTY = @nQTY + @nMQTY  
  
      -- Validate QTY  
      IF @nQTY = 0  
      BEGIN  
         SET @nErrNo = 63462  
         SET @cErrMsg = rdt.rdtgetmessage( 63462, @cLangCode, 'DSP') --'QTY needed'  
         GOTO Step_4_Fail  
      END  
  
--       -- Validate QTY to move more than QTY avail  
--       DECLARE C_Component CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
--         SELECT ComponentSku, Qty   
--       FROM dbo.BILLOFMATERIAL WITH (NOLOCK)  
--         WHERE StorerKey = @cStorerKey  
--             AND SKU = @cParentSKU                                 
--                                             
--       OPEN C_Component  
--   
--       FETCH NEXT FROM C_Component INTO @cCompSKU, @nCompQTY  
--   
--       WHILE @@FETCH_STATUS <> -1  
--       BEGIN  
  
       SET @nTempCount = 1  
       WHILE @nTempCount <= @nCountSku  
       BEGIN  
          SET @cCompSKU = ''  
            SET @nCompQTY = 0  
  
            SELECT @cCompSKU = ComponentSKU,   
                   @nCompQTY = QTY  
            FROM  dbo.BILLOFMATERIAL WITH (NOLOCK)  
          WHERE SKU = @cParentSKU  
          AND   StorerKey = @cStorerKey  
            AND   Sequence = CONVERT(CHAR, @nTempCount)  
           
          -- Get QTY avail  
          SELECT @nCompQTY_Avail = SUM( LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))  
          FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
          JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK)  
            ON (LA.Storerkey = LLI.Storerkey AND LA.SKU = LLI.SKU)  
          WHERE LLI.StorerKey = @cStorerKey  
             AND LLI.LOC = @cFromLOC  
             AND LLI.ID = @cFromID  
             AND LLI.SKU = @cCompSKU  
             AND LA.Lottable03 = @cParentSKU  
--          WHERE StorerKey = @cStorerKey  
 --             AND LOC = @cFromLOC  
 --             AND ID = @cFromID  
 --             AND SKU = @cCompSKU  
  
          -- Validate not QTY  
          IF @nCompQTY_Avail = 0 OR @nCompQTY_Avail IS NULL  
          BEGIN  
             SET @nErrNo = 63463  
             SET @cErrMsg = rdt.rdtgetmessage( 63463, @cLangCode, 'DSP') --'No QTY to move'  
             GOTO Step_4_Fail  
          END  
          ELSE  
          BEGIN  
              IF @cPUOM <> 'PK'  
              BEGIN  
             IF (@nQTY * @nCompQTY) > @nCompQTY_Avail  
             BEGIN  
                SET @nErrNo = 63464  
                SET @cErrMsg = CAST((@nQTY) as char)--rdt.rdtgetmessage( 63464, @cLangCode, 'DSP') --'QTYAVL NotEnuf'  
                GOTO Step_4_Fail  
             END  
              END  
          END  
  
           SET @nTempCount = @nTempCount + 1  
        END -- Loop  
  
--          FETCH NEXT FROM C_Component INTO @cCompSKU, @nCompQTY  
--   
--       END --WHILE HEADER  
--         
--       CLOSE C_Component  
--       DEALLOCATE C_Component  
/*        
IF @nQTY > @nQTY_Avail  
      BEGIN  
         SET @nErrNo = 63462  
         SET @cErrMsg = rdt.rdtgetmessage( 63462, @cLangCode, 'DSP') --'QTYAVL NotEnuf'  
         GOTO Step_4_Fail  
      END*/  
  
  
  
       -- Prep ToID screen var  
      SET @cToID = ''  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
    SET @cOutField07 = ''  
    SET @cOutField08 = ''  
      SET @cOutField09 = ''  
      SET @cOutField10 = ''  
      SET @cOutField11 = ''  
  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
  
      SET @cOutField01 = @cFromLOC  
      SET @cOutField02 = @cFromID  
      SET @cOutField03 = @cParentSKU  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1  
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2  
      IF @cPUOM <> 'PK'  
      BEGIN  
       SET @cOutField06 = @cPUOM  
       SET @cOutField07 = @nPQTY_Avail--CAST( @nPQTY_Avail AS NVARCHAR( 5))  
         SET @cOutField08 = CAST( @nPQTY AS NVARCHAR( 5))  
      END  
      ELSE  
      BEGIN  
       SET @cOutField06 = ''  
       SET @cOutField07 = ''--CAST( @nPQTY_Avail AS NVARCHAR( 5))  
       SET @cOutField08 = '' -- @nPQTY  
         SET @cFieldAttr08 = 'O' -- (Vicky02)  
         --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')  
         SET @cInField08 = '' -- (james01)
      END  
        
      SET @cOutField09 = 'PK'--@cPUOM--@cMUOM_Desc  
      SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 5))  
      SET @cOutField11 = CAST( @nMQTY AS NVARCHAR( 5))  
  
      IF @cPUOM <> 'PK'   
      BEGIN  
        SET @cFieldAttr11 = 'O' -- (Vicky02)  
        --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field11', 'NULL', 'output', 'NULL', 'NULL', '')  
         SET @cInField11 = '' -- (james01)
      END  
  
      SET @cOutField12 = '' -- @cToID  
        
      -- Go to ToID screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      -- Prep SKU screen var  
      SET @cSKU = ''  
      SET @cParentSKU = ''  
      SET @cOutField01 = @cFromLOC  
      SET @cOutField02 = @cFromID  
      SET @cOutField03 = @cSKU  
  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
  
      -- Go to QTY screen  
      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
   GOTO Quit  
  
   Step_4_Fail:  
   BEGIN  
      -- Reset this screen var  
      SET @nQty = 0  
      SET @nCompQTY_Avail = 0  
--      SET @cOutField01 = '' -- QTY  
  
      -- (Vicky02) - Start  
      SET @cFieldAttr08 = ''  
      SET @cFieldAttr11 = ''   
      -- (Vicky02) - End  
  
      SET @cOutField01 = @cFromLOC -- Bug fix by Vicky on 09-Aug-2007  
      SET @cOutField02 = @cFromID  -- Bug fix by Vicky on 09-Aug-2007  
      SET @cOutField03 = @cParentSKU  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1  
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2  
      IF @cPUOM <> 'PK'  
      BEGIN  
       SET @cOutField06 = @cPUOM  
       SET @cOutField07 = @nPQTY_Avail--CAST( @nPQTY_Avail AS NVARCHAR( 5))  
       SET @cOutField08 = '' -- @nPQTY  
      END  
      ELSE  
      BEGIN  
       SET @cOutField06 = ''  
       SET @cOutField07 = ''--CAST( @nPQTY_Avail AS NVARCHAR( 5))  
       SET @cOutField08 = '' -- @nPQTY  
         SET @cFieldAttr08 = 'O'  
         --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')  
         SET @cInField08 = '' -- (james01)
      END  
        
      SET @cOutField09 = 'PK'--@cPUOM--@cMUOM_Desc  
      SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 5))  
      SET @cOutField11 = '' --@nMQTY  
  
      IF @cPUOM <> 'PK'   
      BEGIN  
        SET @cFieldAttr11 = 'O'  
        --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field11', 'NULL', 'output', 'NULL', 'NULL', '')  
         SET @cInField11 = '' -- (james01)
      END  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 5. Scn = 1534. ToID  
   FromID  (field01)  
   FromLOC (field02)  
   SKU     (field03)  
   Desc1   (field04)  
   Desc2   (field05)  
   UOM     (field06, field09)  
   QTY MV  (field08, field11)  
   ToID    (field12, input)  
********************************************************************************/  
Step_5:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Screen mapping  
      SET @cToID = @cInField12  
  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
  
      -- Prep ToLOC screen var  
      SET @cToLOC = ''  
      SET @cOutField01 = @cFromLOC  
      SET @cOutField02 = @cFromID  
      SET @cOutField03 = @cParentSKU  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1  
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2  
      IF @cPUOM <> 'PK'  
      BEGIN  
         SET @cOutField06 = @cPUOM  
         SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 5))  
         SET @cOutField08 = CAST( @nPQTY AS NVARCHAR( 5))   
      END  
      ELSE  
      BEGIN  
       SET @cOutField06 = ''  
       SET @cOutField07 = ''--CAST( @nPQTY_Avail AS NVARCHAR( 5))  
       SET @cOutField08 = '' -- @nPQTY  
         SET @cFieldAttr08 = 'O' -- (Vicky02)  
         --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')  
         SET @cInField08 = '' -- (james01)
      END  
  
      SET @cOutField09 = 'PK' --@cMUOM_Desc  
      SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 5))  
  
      IF @cPUOM = 'PK'  
      BEGIN  
         SET @cOutField11 = CAST( @nMQTY AS NVARCHAR( 5))  
      END  
  
      SET @cOutField12 = @cToID  
      SET @cOutField13 = '' -- @cToLOC  
        
      -- Go to next screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
  
      -- Prep QTY screen var  
      SET @cOutField01 = @cFromLOC  
      SET @cOutField02 = @cFromID  
      SET @cOutField03 = @cParentSKU  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1  
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2  
      IF @cPUOM <> 'PK'  
      BEGIN  
       SET @cOutField06 = @cPUOM  
       SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 5))  
       SET @cOutField08 = '' -- @nPQTY  
      END  
      ELSE  
      BEGIN  
       SET @cOutField06 = ''  
       SET @cOutField07 = ''--CAST( @nPQTY_Avail AS NVARCHAR( 5))  
       SET @cOutField08 = '' -- @nPQTY  
         SET @cFieldAttr08 = 'O' -- (Vicky02)  
         --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')  
         SET @cInField08 = '' -- (james01)
      END  
        
      SET @cOutField09 = 'PK'--@cPUOM--@cMUOM_Desc  
      SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 5))  
      SET @cOutField11 = '' -- @nMQTY  
  
      IF @cPUOM <> 'PK'  
      BEGIN  
        SET @cFieldAttr11 = 'O' -- (Vicky02)  
        --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field11', 'NULL', 'output', 'NULL', 'NULL', '')  
         SET @cInField11 = '' -- (james01)
      END  
        
      -- Go to QTY screen  
      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1        
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 6. Scn = 1537. ToLOC  
   FromID  (field01)  
   FromLOC (field02)  
   SKU     (field03)  
   Desc1   (field04)  
   Desc2   (field05)  
   UOM     (field06, field09)  
   QTY MV  (field08, field11)  
   ToID    (field12)  
   ToLOC   (field13, input)  
********************************************************************************/  
Step_6:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Screen mapping  
      SET @cToLOC = @cInField13  
  
-- (Vicky02) - Start  
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
      -- (Vicky02) - End  
  
      -- Validate blank  
      IF @cToLOC = '' OR @cToLOC IS NULL   
      BEGIN  
         SET @nErrNo = 63465  
         SET @cErrMsg = rdt.rdtgetmessage( 63465, @cLangCode, 'DSP') --'ToLOC needed'  
         GOTO Step_6_Fail  
      END  
  
      -- Get LOC info  
      SELECT @cChkFacility = Facility  
      FROM dbo.LOC (NOLOCK)  
      WHERE LOC = @cToLOC  
  
      -- Validate LOC  
      IF @@ROWCOUNT = 0  
      BEGIN  
         SET @nErrNo = 63466  
         SET @cErrMsg = rdt.rdtgetmessage( 63466, @cLangCode, 'DSP') --'Invalid LOC'  
         GOTO Step_6_Fail  
      END  
  
      -- Validate LOC's facility  
      IF NOT (rdt.rdtGetConfig( 0, 'MoveToLOCNotCheckFacility', @cStorerKey) = '1')  
         IF @cChkFacility <> @cFacility  
         BEGIN  
            SET @nErrNo = 63467  
            SET @cErrMsg = rdt.rdtgetmessage( 63467, @cLangCode, 'DSP') --'Diff facility'  
            GOTO Step_6_Fail  
         END  
  
  
      SET @nTempCount = 1  
      BEGIN TRAN  
      WHILE @nTempCount <= @nCountSku  
      BEGIN  
         SET @cCompSKU = ''  
         SET @nCompQTY = 0  
         SET @nTotalQty = 0  
  
         --retrieve one componentSku and qty at a time by sequence  
         SELECT   
            @cCompSKU = ComponentSku,  
            @nCompQTY = Qty  
         FROM dbo.BILLOFMATERIAL WITH (NOLOCK)  
         WHERE SKU = @cParentSKU  
         AND   Storerkey = @cStorerKey  
         AND   Sequence = CONVERT(CHAR, @nTempCount)  
  
         IF @nPackCnt IS NULL OR @nPackCnt = ''  
         BEGIN  
            SET @nPackCnt = 1  
         END  
  
         SET @nTotalQty = @nQTY * @nCompQTY  
  
--       DECLARE C_ComponentToAdd CURSOR FAST_FORWARD READ_ONLY FOR   
--       SELECT ComponentSku, Qty   
--        FROM dbo.BILLOFMATERIAL WITH (NOLOCK)  
--       WHERE StorerKey = @cStorerKey  
--          AND SKU = @cParentSKU                                 
--                                          
--       OPEN C_ComponentToAdd  
--         
--       FETCH NEXT FROM C_ComponentToAdd INTO @cCompSKU, @nCompQTY  
--         
--       WHILE @@FETCH_STATUS <> -1  
--       BEGIN  
--          IF @nPackCnt IS NULL OR @nPackCnt = ''  
--          BEGIN  
--             SET @nPackCnt = 1  
--          END  
--   
--          SET @nTotalQty = @nQTY * @nCompQTY * @nPackCnt  
--   
--          SET @cErrMsg = CAST(@nTotalQty as Char)  
--          GOTO Step_6_Fail  
  
         EXECUTE rdt.rdt_Move  
            @nMobile     = @nMobile,  
            @cLangCode   = @cLangCode,   
            @nErrNo      = @nErrNo  OUTPUT,  
            @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max  
            @cSourceType = 'rdtfnc_Move_PrePack_SKU',   
            @cStorerKey  = @cStorerKey,  
            @cFacility   = @cFacility,   
            @cFromLOC    = @cFromLOC,   
            @cToLOC      = @cToLOC,   
            @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID  
            @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID  
            @cSKU        = @cCompSKU,   
            @nQty        = @nTotalQty  
           
--          FETCH NEXT FROM C_ComponentToAdd INTO @cCompSKU, @nCompQTY  
--   
--       END --END WHILE  
--   
--       CLOSE C_ComponentToAdd  
--       DEALLOCATE C_ComponentToAdd  
  
      IF @nErrNo <> 0  
      BEGIN  
         ROLLBACK TRAN  
         SET @cErrMsg = @cErrMsg  
         GOTO Step_6_Fail  
         GOTO Quit  
      END  
      ELSE  
      BEGIN  
          -- (Vicky06) EventLog - QTY  
  EXEC RDT.rdt_STD_EventLog  
             @cActionType   = '4', -- Move  
             @cUserID       = @cUserName,  
             @nMobileNo     = @nMobile,  
             @nFunctionID   = @nFunc,  
             @cFacility     = @cFacility,  
             @cStorerKey    = @cStorerkey,  
             @cLocation     = @cFromLOC,  
             @cToLocation   = @cToLOC,  
             @cID           = @cFromID,  
             @cToID         = @cToID,  
             @cSKU          = @cParentSKU,  
             @cComponentSKU = @cCompSKU,  
             @cUOM          = 'PK',  
             @nQTY          = @nTotalQty,
             @nStep         = @nStep 
      END  
  
      SET @nTempCount = @nTempCount + 1  
  
   END --end of while loop  
  
    IF @nErrNo = 0  
    BEGIN  
       COMMIT TRAN  
    END  
  
      -- Go to next screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
      GOTO Quit  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      -- Prepare ToID screen var  
            SET @cToID = ''  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
    SET @cOutField07 = ''  
    SET @cOutField08 = ''  
      SET @cOutField09 = ''  
      SET @cOutField10 = ''  
      SET @cOutField11 = ''  
  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
  
      SET @cOutField01 = @cFromLOC  
      SET @cOutField02 = @cFromID  
      SET @cOutField03 = @cParentSKU  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1  
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2  
      IF @cPUOM <> 'PK'  
      BEGIN  
       SET @cOutField06 = @cPUOM  
       SET @cOutField07 = @nPQTY_Avail--CAST( @nPQTY_Avail AS NVARCHAR( 5))  
         SET @cOutField08 = CAST( @nPQTY AS NVARCHAR( 5))  
      END  
      ELSE  
      BEGIN  
       SET @cOutField06 = ''  
       SET @cOutField07 = ''--CAST( @nPQTY_Avail AS NVARCHAR( 5))  
       SET @cOutField08 = '' -- @nPQTY  
         SET @cFieldAttr08 = 'O' -- (Vicky02)  
         --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')  
         SET @cInField08 = '' -- (james01)
      END  
        
      SET @cOutField09 = 'PK'--@cPUOM--@cMUOM_Desc  
      SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 5))  
      SET @cOutField11 = CAST( @nMQTY AS NVARCHAR( 5))  
  
      IF @cPUOM <> 'PK'   
      BEGIN  
        SET @cFieldAttr11 = 'O' -- (Vicky02)  
        --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field11', 'NULL', 'output', 'NULL', 'NULL', '')  
         SET @cInField11 = '' -- (james01)
      END  
  
      SET @cOutField12 = '' -- @cToID  
  
      -- Go to ToID screen  
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
   GOTO Quit  
  
   Step_6_Fail:  
   BEGIN  
      SET @cToLOC = ''  
      SET @cOutField13 = '' -- @cToLOC  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 7. scn = 1538. Message screen  
   Message  
********************************************************************************/  
Step_7:  
BEGIN  
   -- Go back to 1st screen  
   SET @nScn  = @nScn - 6  
   SET @nStep = @nStep - 6  
  
   -- (Vicky02) - Start  
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
   -- (Vicky02) - End  
  
   -- Prep next screen var  
   SET @cFromLOC = ''  
   SET @cOutField01 = '' -- FromLOC  
  
   -- (Vicky07) - Start  
   SET @cPQTY = ''  
   SET @cMQTY = ''  
   SET @cCompSKU    = ''  
   SET @cToLOC      = ''  
   SET @cToID       = ''  
   SET @cFromUPC    = ''  
   SET @cSKU        = ''  
   SET @cParentSKU  = ''  
   SET @nPQTY = 0  
   SET @nMQTY = 0  
   SET @nQTY_Avail  = 0  
   SET @nPQTY_Avail = 0  
   SET @nMQTY_Avail = 0  
   SET @nQTY        = 0  
   SET @nPQTY       = 0  
   SET @nMQTY       = 0  
   SET @nPackCnt    = 0  
   SET @nCountSku   = 0    
   SET @nCompQTY_Show  = 0  
   SET @nCompQTY_Avail = 0  
   SET @nCompQTY       = 0  
   -- (Vicky07) - End  
  
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
      -- UserName  = @cUserName,-- (Vicky06)  
  
      V_String1  = @cFromLOC,   
      V_String2  = @cFromID,   
      V_String3  = @cSKU,   
      V_SKUDescr = @cSKUDescr,   
        
      V_UOM      = @cPUOM,   
      V_String4  = @cPUOM_Desc,   
      V_String5  = @cMUOM_Desc,
         
      V_Integer1 = @nQTY_Avail,   
      V_Integer2 = @nPQTY_Avail,   
      V_Integer3 = @nMQTY_Avail,   
      V_Integer4 = @nQTY, 
      V_Integer5 = @nCompQTY_Show,  
      V_Integer6 = @nCompQTY_Avail,  
      V_Integer7 = @nCompQTY,
      V_Integer8 = @nPackCnt,  
      V_Integer9 = @nCountSku,
        
      V_PQTY     = @nPQTY,   
      V_MQTY     = @nMQTY,   
      V_PUOM_Div = @nPUOM_Div,   
  
      V_String13 = @cToLOC,   
      V_String14 = @cToID,   
      V_String15 = @cFromUPC,   
  
      V_String16 = @cParentSKU,    
    
      V_String20 = @cCompSKU,    
  
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
  
      -- (Vicky02) - Start  
      FieldAttr01  = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,  
      FieldAttr03  = @cFieldAttr03,   FieldAttr04  = @cFieldAttr04,  
      FieldAttr05  = @cFieldAttr05,   FieldAttr06  = @cFieldAttr06,  
      FieldAttr07  = @cFieldAttr07,   FieldAttr08  = @cFieldAttr08,  
      FieldAttr09  = @cFieldAttr09,   FieldAttr10  = @cFieldAttr10,  
      FieldAttr11  = @cFieldAttr11,   FieldAttr12  = @cFieldAttr12,  
      FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,  
      FieldAttr15  = @cFieldAttr15   
      -- (Vicky02) - End  
   WHERE Mobile = @nMobile  
  
-- Commented (Vicky02) - Start  
--    -- Save session screen  
--    IF EXISTS( SELECT 1 FROM @tSessionScrn)  
--    BEGIN  
--       DECLARE @curScreen CURSOR  
--       DECLARE  
--          @cTyp     NVARCHAR( 10),   
--          @cX       NVARCHAR( 4),   -- size 4 is needed bcoz of 'NULL'  
--          @cY       NVARCHAR( 4),   -- size 4 is needed bcoz of 'NULL'  
--          @cLength  NVARCHAR( 4),   -- size 4 is needed bcoz of 'NULL'  
--          @cFieldID NVARCHAR( 10),   
--          @cDefault NVARCHAR( 60),   
--          @cValue   NVARCHAR( 60),   
--          @cNewID   NVARCHAR( 10)  
--   
--       SET @cXML = ''  
--       SET @curScreen = CURSOR FOR   
--          SELECT Typ, X, Y, Length, [ID], [Default], Value, [NewID] FROM @tSessionScrn  
--       OPEN @curScreen  
--       FETCH NEXT FROM @curScreen INTO @cTyp, @cX, @cY, @cLength, @cFieldID, @cDefault, @cValue, @cNewID  
--       WHILE @@FETCH_STATUS = 0  
--       BEGIN  
--          SELECT @cXML = @cXML +   
--             '<Screen ' +   
--                CASE WHEN @cTyp     IS NULL THEN '' ELSE 'Typ="'     + @cTyp     + '" ' END +   
--                CASE WHEN @cX       IS NULL THEN '' ELSE 'X="'       + @cX       + '" ' END +   
--                CASE WHEN @cY       IS NULL THEN '' ELSE 'Y="'       + @cY       + '" ' END +   
--                CASE WHEN @cLength  IS NULL THEN '' ELSE 'Length="'  + @cLength  + '" ' END +   
--                CASE WHEN @cFieldID IS NULL THEN '' ELSE 'ID="'      + @cFieldID + '" ' END +   
--          CASE WHEN @cDefault IS NULL THEN '' ELSE 'Default="' + @cDefault + '" ' END +   
--                CASE WHEN @cValue   IS NULL THEN '' ELSE 'Value="'   + @cValue   + '" ' END +   
--             CASE WHEN @cNewID   IS NULL THEN '' ELSE 'NewID="'   + @cNewID   + '" ' END +   
--             '/>'  
--          FETCH NEXT FROM @curScreen INTO @cTyp, @cX, @cY, @cLength, @cFieldID, @cDefault, @cValue, @cNewID  
--       END  
--       CLOSE @curScreen  
--       DEALLOCATE @curScreen  
--  END  
--   
--   
--    -- Note: UTF-8 is multi byte (1 to 6 bytes) encoding. Use UTF-16 for double byte  
--    SET @cXML =   
--       '<?xml version="1.0" encoding="UTF-16"?>' +   
--       '<Root>' +   
--          @cXML +   
--       '</Root>'  
--    UPDATE RDT.RDTSessionData WITH (ROWLOCK) SET XML = @cXML WHERE Mobile = @nMobile  
-- Commented (Vicky02) - End  
END

GO