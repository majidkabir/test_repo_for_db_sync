SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdtfnc_CycleCount_ResetCnt                          */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Cycle Count for SOS#190291                                  */
/*          1. Reset Count                                              */
/*          Copied from original rdtfnc_CycleCount                      */
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
/* 23-05-2011  1.0  ChewKP   SOS#216365 Reset Count by SKU (ChewKP01)   */
/* 08-02-2013  1.1  ChewKP   SOS#269924 Bug Fix (ChewKP02)              */
/* 30-09-2016  1.2  Ung      Performance tuning                         */
/* 20-04-2017  1.3  James    Remove ANSI_WARNINGS (james01)             */
/* 09-10-2018  1.4  TungGH   Performance                                */
/* 11-06-2019  1.5  YeeKung  WMS-9385 Add Eventlog (yeekung01)          */ 
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_CycleCount_ResetCnt] (
   @nMobile    INT,
   @nErrNo     INT            OUTPUT,
   @cErrMsg    NVARCHAR( 1024) OUTPUT -- screen limitation, 20 char max
)
AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET ANSI_DEFAULTS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE
   @b_success         INT,
   @n_err             INT,
   @c_errmsg          NVARCHAR( 250)
                      
                  
-- RDT.RDTMobRec variables
DECLARE              
   @nFunc             INT,
   @nScn              INT,
   @nStep             INT,
   @cLangCode         NVARCHAR( 3),
   @nInputKey         INT,
   @nMenu             INT,
                     
   @cStorerkey           NVARCHAR( 15),
   @cUserName         NVARCHAR( 18),
   @cFacility         NVARCHAR( 5),
   @cLOC              NVARCHAR( 10),
   @cID               NVARCHAR( 18),
                     
   @cCCRefNo          NVARCHAR( 10),
   @nCCCountNo        INT,
   @cID_In            NVARCHAR( 18),  
   @nRowRef           INT,
   @nTranCount        INT,
   @cSKU              NVARCHAR( 20), -- (ChewKP01)
   @cInSKU            NVARCHAR( 40), -- (ChewKP01)
   @cDecodeLabelNo    NVARCHAR( 20), -- (ChewKP01)   
   @cSKUDesc          NVARCHAR( 60), -- (ChewKP01)
   @nQty              INT        -- (ChewKP01)


DECLARE  @nCCDLinesPerLOC     INT,        -- Total CCDetail Lines (LOC)
         @cOption             NVARCHAR( 1),
         @nSetFocusField      INT,


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
   @cFieldAttr15 NVARCHAR( 1),

   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),      
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),      
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),      
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),      
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)     

-- Getting Mobile information
SELECT
   @nFunc             = Func,
   @nScn              = Scn,
   @nStep             = Step,
   @nInputKey         = InputKey,
   @nMenu             = Menu,
   @cLangCode         = Lang_code,

   @cStorerkey        = StorerKey,
   @cFacility         = Facility,
   @cUserName         = UserName,
   @cLOC              = V_LOC,
   @cID               = V_ID,
   @cSKU              = V_SKU, -- (ChewKP01)

   @cCCRefNo          = V_String1,
   
   @nCCCountNo        = V_Integer1,

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

   @cFieldAttr01 = FieldAttr01,     @cFieldAttr02   = FieldAttr02,
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_CCRef                    INT,  @nScn_CCRef                    INT,
   @nStep_LOC                      INT,  @nScn_LOC                      INT,
   @nStep_ID                       INT,  @nScn_ID                       INT,
   @nStep_ConfirmReset             INT,  @nScn_ConfirmReset             INT,
   @nStep_SKU                      INT,  @nScn_SKU                      INT     -- (ChewKP01)

SELECT
   @nStep_CCRef                    = 1,  @nScn_CCRef                    = 2600,
   @nStep_LOC                      = 2,  @nScn_LOC                      = 2601,
   @nStep_ID                       = 3,  @nScn_ID                       = 2602,
   @nStep_ConfirmReset             = 4,  @nScn_ConfirmReset             = 2603,
   @nStep_SKU                      = 5,  @nScn_SKU                      = 2604  -- (ChewKP01)

IF @nFunc = 612 -- RDT Cycle Count - Reset Count
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start                    -- Menu. Func = 612
   IF @nStep = 1  GOTO Step_CCRef                    -- Scn = 2600. CCREF
   IF @nStep = 2  GOTO Step_LOC                      -- Scn = 2601. LOC
   IF @nStep = 3  GOTO Step_ID                       -- Scn = 2602. ID
   IF @nStep = 4  GOTO Step_ConfirmReset             -- Scn = 2603. Reset
   IF @nStep = 5  GOTO Step_SKU                      -- Scn = 2604. SKU -- (ChewKP01)
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 612. Screen 0.
********************************************************************************/
Step_Start:
BEGIN
   SELECT
      @cOutField01   = '',
      @cOutField02   = '',
      @cOutField03   = '',
      @cOutField04   = '',
      @cOutField05   = '',
      @cOutField06   = '',
      @cOutField07   = '',
      @cOutField08   = '',
      @cOutField09   = '',
      @cOutField10   = '',
      @cOutField11   = '',
      @cOutField12   = '',
      @cOutField13   = '',
      @cOutField14   = '',
      @cOutField15   = ''

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
 
      SET @cCCRefNo        = ''
      SET @nCCCountNo      = 1 

      -- (ChewKP01) (yeekung01) 
      -- insert to Eventlog        
      EXEC RDT.rdt_STD_EventLog        
           @cActionType   = '1', -- Sign In  
           @cUserID       = @cUserName,        
           @nMobileNo     = @nMobile,        
           @nFunctionID   = @nFunc,        
           @cFacility     = @cFacility,        
           @cStorerkey    = @cStorerkey,  
           @nStep         = @nStep   

      SET @nScn = @nScn_CCRef   -- 2600
      SET @nStep = @nStep_CCRef -- 1
END
GOTO Quit

/************************************************************************************
Step_CCRef. Scn = 2600. Screen 1.
   CCREF (field01)   - Input field
************************************************************************************/
Step_CCRef:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cCCRefNo = @cInField01

      -- Retain the key-in value
      SET @cOutField01 = @cCCRefNo

      -- Validate CCKey
      IF @cCCRefNo = '' OR @cCCRefNo IS NULL
      BEGIN
         SET @nErrNo = 71566
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'CCREF required'
         GOTO CCRef_Fail
      END

      -- Validate with CCDETAIL
      IF NOT EXISTS (SELECT 1 --TOP 1 CCKey
                     FROM dbo.CCDETAIL (NOLOCK)
                     WHERE CCKey = @cCCRefNo
                     AND StorerKey = @cStorerkey)
      BEGIN
         SET @nErrNo = 71567
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid CCREF'
         GOTO CCRef_Fail
      END


      SET @nCCCountNo=0  
      SELECT @nCCCountNo = CASE WHEN ISNULL(STSP.FinalizeStage,0) = 0 THEN 1    
                                WHEN STSP.FinalizeStage = 1 THEN 2  
                                WHEN STSP.FinalizeStage = 2 THEN 3  
                                WHEN STSP.FinalizeStage = 3 THEN 4   
                           END    
      FROM dbo.StockTakeSheetParameters STSP (NOLOCK)  
      WHERE StockTakeKey = @cCCRefNo  
        
      IF ISNULL(@nCCCountNo,0) = 0   
      BEGIN  
         SET @nErrNo = 71568  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Setup CCREF'  
         GOTO CCRef_Fail  
      END        

      -- Already counted 3 times, not allow to reset count
      IF ISNULL(@nCCCountNo,0) = 4
      BEGIN
         SET @nErrNo = 71569
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'CCKey Finalized'
         GOTO CCRef_Fail
      END

      -- Prepare next screen var
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = @nCCCountNo         -- Countno
      SET @cOutField03 = ''                  -- Loc

      -- Go to next screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
      
      -- (ChewKP01)
      -- insert to Eventlog      
      EXEC RDT.rdt_STD_EventLog      
           @cActionType   = '1', -- Sign In
           @cUserID       = @cUserName,      
           @nMobileNo     = @nMobile,      
           @nFunctionID   = @nFunc,      
           @cFacility     = @cFacility,      
           @cStorerkey    = @cStorerkey,
           @cID           = @cID,
           @cSKU          = @cSKU,
           @cCCKey        = @cCCRefNo,      
           @cRefNo2       = '',      
           @cRefNo3       = '',      
           @cRefNo4       = '',
           @nStep         = @nStep  
           
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- CCREF

      -- (ChewKP01)
      EXEC RDT.rdt_STD_EventLog      
           @cActionType   = '9', -- Sign Out
           @cUserID       = @cUserName,      
           @nMobileNo     = @nMobile,      
           @nFunctionID   = @nFunc,      
           @cFacility     = @cFacility,      
           @cStorerkey    = @cStorerkey,
           @cID           = @cID,
           @cSKU          = @cSKU,
           @cCCKey        = @cCCRefNo,      
           @cRefNo2       = '',      
           @cRefNo3       = '',      
           @cRefNo4       = '',
           @nStep         = @nStep   
      
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option

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
      
      
           
   END
   GOTO Quit

   CCRef_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- CCREF
   END
END
GOTO Quit

/************************************************************************************
Step_LOC. Scn = 2601. Screen 2.
   CCREF         (field01)
   CNT NO        (field02)
   LOC           (field03)   - Input field
************************************************************************************/
Step_LOC:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField03

      -- Retain the key-in value
      SET @cOutField03 = @cLOC

      -- Check If LOC is Blank 
      IF @cLOC = '' OR @cLOC IS NULL
      BEGIN
         SET @nErrNo = 71570
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'LOC Required'
         GOTO LOC_Fail
      END

      -- Check if the LOC scanned already locked by other ppl 
      IF ISNULL(@cLOC, '') <> ''
      BEGIN
         IF EXISTS (SELECT 1 FROM RDT.RDTCCLock WITH (NOLOCK) 
            WHERE StorerKey = @cStorerkey
               AND CCKey = @cCCRefNo
               AND LOC = @cLOC
               AND Status = '0'
               AND AddWho <> @cUserName)
         BEGIN
            SET @nErrNo = 71571
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'LOC is Locked'
            GOTO LOC_Fail
         END
      END

      -- check any CCDetails to reset for the LOC
      IF @cLOC <> '' AND @cLOC IS NOT NULL
      BEGIN
         SELECT @nCCDLinesPerLOC = COUNT(1)
         FROM dbo.CCDETAIL WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
         AND StorerKey = @cStorerkey
         AND LOC = @cLOC
         AND 1 = CASE 
                 WHEN @nCCCountNo = 1 AND FinalizeFlag = 'N' THEN 1
                 WHEN @nCCCountNo = 2 AND FinalizeFlag_Cnt2 = 'N' THEN 1
                 WHEN @nCCCountNo = 3 AND FinalizeFlag_Cnt3 = 'N' THEN 1
              ELSE 0 END     
         AND 1 = CASE 
                 WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN 1
                 WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN 1
                 WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN 1
              ELSE 0 END     

         IF @nCCDLinesPerLOC = 0
         BEGIN
            SET @nErrNo = 71572
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'No CC To Reset'
            GOTO LOC_Fail
         END

      END

      -- Prepare next screen var
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = CAST( @nCCCountNo AS NVARCHAR(1))
      SET @cOutField03 = @cLOC
      SET @cOutField04 = '' -- ID

      EXEC rdt.rdtSetFocusField @nMobile, 4   -- ID

      -- Go to next screen
      SET @nScn = @nScn_ID
      SET @nStep = @nStep_ID
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = @cCCRefNo

      -- Go to previous screen
      SET @nScn = @nScn_CCRef
      SET @nStep = @nStep_CCRef
   END
   GOTO Quit

   LOC_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField03 = '' -- LOC
   END
END
GOTO Quit

/************************************************************************************
Step_ID. Scn = 2602. Screen 3.
   CCREF  (field01)
   COUNT  (field02)
   LOC    (field03)
   ID     (field04)   - Input field
************************************************************************************/
Step_ID:
BEGIN

   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cID = @cInField04

--      -- Retain the key-in value
--      SET @cOutField04 = @cID

      -- check any CCDetails to reset for the LOC + ID
      IF @cID <> '' AND @cID IS NOT NULL -- (ChewKP01)
      BEGIN
         SET @nCCDLinesPerLOC = 0
         SELECT @nCCDLinesPerLOC = COUNT(1)
         FROM dbo.CCDETAIL WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
         AND StorerKey = @cStorerkey
         AND LOC = @cLOC
         AND ID = @cID
         AND 1 = CASE 
                 WHEN @nCCCountNo = 1 AND FinalizeFlag = 'N' THEN 1
                 WHEN @nCCCountNo = 2 AND FinalizeFlag_Cnt2 = 'N' THEN 1
                 WHEN @nCCCountNo = 3 AND FinalizeFlag_Cnt3 = 'N' THEN 1
              ELSE 0 END     
         AND 1 = CASE 
                 WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN 1
                 WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN 1
                 WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN 1
              ELSE 0 END     

         IF @nCCDLinesPerLOC = 0
         BEGIN
            SET @nErrNo = 71575
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'No CC To Reset'
            GOTO ID_Fail
         END

      END

      -- Prepare Reset screen var
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = CAST( @nCCCountNo AS NVARCHAR(1))
      SET @cOutField03 = @cLOC
      SET @cOutField04 = @cID -- ID
      SET @cOutField05 = ''   -- SKU

      EXEC rdt.rdtSetFocusField @nMobile, 6   -- Option

      -- Go to Reset count screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
      
      GOTO Quit
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = CAST( @nCCCountNo AS NVARCHAR( 1))
      SET @cOutField03 = ''

      -- Go to previous screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
   END
   GOTO Quit

   ID_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField04 = '' -- ID
   END

END
GOTO Quit

/************************************************************************************
Step_ConfirmReset. Scn = 2603. Screen 4.
   OPTION (field06)   - Input field
************************************************************************************/
Step_ConfirmReset:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField08

      -- 1=YES, 2=NO
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 71573
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Option req'
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- OPTION
         GOTO Reset_Option_Fail
      END

      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 71574
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid Option'
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- OPTION
         GOTO Reset_Option_Fail
      END

      IF @cOption = '1' -- YES
      BEGIN
         IF EXISTS (SELECT 1 FROM RDT.RDTCCLock WITH (NOLOCK) 
            WHERE StorerKey = @cStorerkey
               AND CCKey = @cCCRefNo
               AND LOC = @cLOC
               AND Status = '0'
               AND AddWho <> @cUserName)
         BEGIN
            SET @nErrNo = 71576
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'LOC is Locked'
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- OPTION
            GOTO Reset_Option_Fail
         END

         -- (ChewKP01)
         IF @cID <> '' AND @cSKU = ''
         BEGIN
            UPDATE dbo.CCDETAIL WITH (ROWLOCK)
            SET Qty = CASE WHEN @nCCCountNo = 1 THEN 0 ELSE QTY END,
                Qty_Cnt2 = CASE WHEN @nCCCountNo = 2 THEN 0 ELSE Qty_Cnt2 END, -- (ChewKP02)
                Qty_Cnt3 = CASE WHEN @nCCCountNo = 3 THEN 0 ELSE Qty_Cnt3 END,
                Counted_Cnt1 =  CASE WHEN @nCCCountNo = 1 THEN '0' ELSE Counted_Cnt1 END,
                Counted_Cnt2 =  CASE WHEN @nCCCountNo = 2 THEN '0' ELSE Counted_Cnt2 END,
                Counted_Cnt3 =  CASE WHEN @nCCCountNo = 3 THEN '0' ELSE Counted_Cnt3 END,
                Status = CASE WHEN Status = '2' THEN '0' ELSE Status END
            FROM dbo.CCDETAIL 
            WHERE CCKey = @cCCRefNo
            AND ID = @cID 
            AND StorerKey = @cStorerkey
            AND LOC = @cLOC
            AND SKU = @cSKU
            AND 1 = CASE 
                    WHEN @nCCCountNo = 1 AND FinalizeFlag = 'N' THEN 1
                    WHEN @nCCCountNo = 2 AND FinalizeFlag_Cnt2 = 'N' THEN 1
                    WHEN @nCCCountNo = 3 AND FinalizeFlag_Cnt3 = 'N' THEN 1
                 ELSE 0 END     
            AND 1 = CASE 
                    WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN 1
                    WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN 1
                    WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN 1
                 ELSE 0 END     
         END
         ELSE IF @cID = '' AND @cSKU <> ''
         BEGIN
            UPDATE dbo.CCDETAIL WITH (ROWLOCK)
            SET Qty = CASE WHEN @nCCCountNo = 1 THEN 0 ELSE QTY END,
                Qty_Cnt2 = CASE WHEN @nCCCountNo = 2 THEN 0 ELSE Qty_Cnt2 END, -- (ChewKP02)
                Qty_Cnt3 = CASE WHEN @nCCCountNo = 3 THEN 0 ELSE Qty_Cnt3 END,
                Counted_Cnt1 =  CASE WHEN @nCCCountNo = 1 THEN '0' ELSE Counted_Cnt1 END,
                Counted_Cnt2 =  CASE WHEN @nCCCountNo = 2 THEN '0' ELSE Counted_Cnt2 END,
                Counted_Cnt3 =  CASE WHEN @nCCCountNo = 3 THEN '0' ELSE Counted_Cnt3 END,
                Status = CASE WHEN Status = '2' THEN '0' ELSE Status END
            FROM dbo.CCDETAIL 
            WHERE CCKey = @cCCRefNo
            --AND SKU = @cID 
            AND StorerKey = @cStorerkey
            AND LOC = @cLOC
            AND SKU = @cSKU
            AND 1 = CASE 
                    WHEN @nCCCountNo = 1 AND FinalizeFlag = 'N' THEN 1
                    WHEN @nCCCountNo = 2 AND FinalizeFlag_Cnt2 = 'N' THEN 1
                    WHEN @nCCCountNo = 3 AND FinalizeFlag_Cnt3 = 'N' THEN 1
                 ELSE 0 END     
            AND 1 = CASE 
                    WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN 1
                    WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN 1
                    WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN 1
                 ELSE 0 END     
         END
         ELSE IF @cID <> '' AND @cSKU <> ''
         BEGIN
            UPDATE dbo.CCDETAIL WITH (ROWLOCK)
            SET Qty = CASE WHEN @nCCCountNo = 1 THEN 0 ELSE QTY END,
                Qty_Cnt2 = CASE WHEN @nCCCountNo = 2 THEN 0 ELSE Qty_Cnt2 END, -- (ChewKP02)
                Qty_Cnt3 = CASE WHEN @nCCCountNo = 3 THEN 0 ELSE Qty_Cnt3 END,
                Counted_Cnt1 =  CASE WHEN @nCCCountNo = 1 THEN '0' ELSE Counted_Cnt1 END,
                Counted_Cnt2 =  CASE WHEN @nCCCountNo = 2 THEN '0' ELSE Counted_Cnt2 END,
                Counted_Cnt3 =  CASE WHEN @nCCCountNo = 3 THEN '0' ELSE Counted_Cnt3 END,
                Status = CASE WHEN Status = '2' THEN '0' ELSE Status END
            FROM dbo.CCDETAIL 
            WHERE CCKey = @cCCRefNo
            AND ID = @cID 
            AND StorerKey = @cStorerkey
            AND LOC = @cLOC
            AND SKU = @cSKU
            AND 1 = CASE 
                    WHEN @nCCCountNo = 1 AND FinalizeFlag = 'N' THEN 1
                    WHEN @nCCCountNo = 2 AND FinalizeFlag_Cnt2 = 'N' THEN 1
                    WHEN @nCCCountNo = 3 AND FinalizeFlag_Cnt3 = 'N' THEN 1
                 ELSE 0 END     
            AND 1 = CASE 
                    WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN 1
                    WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN 1
                    WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN 1
                 ELSE 0 END     
         END
         
         -- Prepare next screen var
         SET @cOutField01 = @cCCRefNo
         SET @cOutField02 = CAST( @nCCCountNo AS NVARCHAR( 1))
         SET @cOutField03 = ''

         -- Go to next screen
         SET @nScn = @nScn_LOC
         SET @nStep = @nStep_LOC

         EXEC rdt.rdtSetFocusField @nMobile, 3   -- Loc
      END

      IF @cOption = '2' -- NO
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cCCRefNo
         SET @cOutField02 = CAST( @nCCCountNo AS NVARCHAR(1))
         SET @cOutField03 = @cLOC
         SET @cOutField04 = '' -- ID

         EXEC rdt.rdtSetFocusField @nMobile, 4   -- ID

         -- Go to next screen
         SET @nScn = @nScn_ID
         SET @nStep = @nStep_ID
      END
      
      -- (ChewKP01)
      -- insert to Eventlog      
      EXEC RDT.rdt_STD_EventLog      
           @cActionType   = '3', -- Confirm Reset
           @cUserID       = @cUserName,      
           @nMobileNo     = @nMobile,      
           @nFunctionID   = @nFunc,      
           @cFacility     = @cFacility,      
           @cStorerkey    = @cStorerkey,
           @cID           = @cID,
           @cSKU          = @cSKU,
           @cCCKey        = @cCCRefNo,      
           @cRefNo2       = '',      
           @cRefNo3       = '',      
           @cRefNo4       = '',
           @nStep         = @nStep   
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = CAST( @nCCCountNo AS NVARCHAR(1))
      SET @cOutField03 = @cLOC
      SET @cOutField04 = '' -- ID

      EXEC rdt.rdtSetFocusField @nMobile, 4   -- ID

      -- Go to next screen
      SET @nScn = @nScn_SKU -- (ChewKP01)
      SET @nStep = @nStep_SKU -- (ChewKP01)
   END
   GOTO Quit

   Reset_Option_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField08 = '' -- Option
   END
END
GOTO Quit



/************************************************************************************
Step_SKU. Scn = 2604. Screen 5.
   CCREF  (field01)
   COUNT  (field02)
   LOC    (field03)
   ID     (field04)   
   SKU    (field05)   - Input field  
************************************************************************************/
Step_SKU:
BEGIN

   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cInSKU = @cInField05
      
      SET @cSKU = ''  

--      -- Retain the key-in value
--      SET @cOutField04 = @cID

      -- check any CCDetails to reset for the LOC + ID
      IF ISNULL(@cInSKU, '') <> ''
      BEGIN
         
         SET @cDecodeLabelNo = ''      
         SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerkey)    
         
         IF LEN(ISNULL(RTRim(@cInSKU),'')) > 20 AND (ISNULL(@cDecodeLabelNo,'') <> '' OR ISNULL(@cDecodeLabelNo,'') = '0' )          
         BEGIN    
         
               IF ISNULL(@cDecodeLabelNo,'') <> '0'      
               BEGIN      
                        
                  EXEC dbo.ispLabelNo_Decoding_Wrapper       
                   @c_SPName     = @cDecodeLabelNo      
                  ,@c_LabelNo    = @cInSKU      
                  ,@c_Storerkey  = @cStorerkey      
                  ,@c_ReceiptKey = ''      
                  ,@c_POKey      = ''      
                  ,@c_LangCode   = @cLangCode      
                  ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU      
                  ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE      
                  ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR      
                  ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE      
                  ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY      
                  ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- CO#      
                  ,@c_oFieled07  = @c_oFieled07 OUTPUT      
                  ,@c_oFieled08  = @c_oFieled08 OUTPUT      
                  ,@c_oFieled09  = @c_oFieled09 OUTPUT      
                  ,@c_oFieled10  = @c_oFieled10 OUTPUT      
                  ,@b_Success    = @b_Success   OUTPUT      
                  ,@n_ErrNo      = @nErrNo      OUTPUT      
                  ,@c_ErrMsg     = @cErrMsg     OUTPUT      
            
                  IF ISNULL(@cErrMsg, '') <> ''        
                  BEGIN      
                     SET @cErrMsg = @cErrMsg      
                     GOTO SKU_Fail      
                  END        
                        
                  SET @cSKU = @c_oFieled01      
                  SET @nQty = @c_oFieled05      
                        
               END      
               ELSE      
               BEGIN      
                  SET @cSKU = ISNULL(@cInSKU,'')      
               END    
         END
         ELSE
         BEGIN
            SET @cSKU = ISNULL(@cInSKU,'')    
         END

       
         
         EXEC [RDT].[rdt_GETSKU]        
               @cStorerkey  = @cStorerkey,       
               @cSKU        = @cSKU          OUTPUT,        
               @bSuccess    = @b_Success     OUTPUT,       
               @nErr        = @nErrNo        OUTPUT,       
               @cErrMsg     = @cErrMsg       OUTPUT      
                     
         IF @nErrNo <> 0       
         BEGIN      
            SET @nErrNo = 71577      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU      
            EXEC rdt.rdtSetFocusField @nMobile, 5          
            GOTO SKU_Fail         
         END     
         
         
         
         SET @nCCDLinesPerLOC = 0
         SELECT @nCCDLinesPerLOC = COUNT(1)
         FROM dbo.CCDETAIL WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
         AND StorerKey = @cStorerkey
         AND LOC = @cLOC
         --AND ID  = @cID
         AND SKU = @cSKU
         AND 1 = CASE 
                 WHEN @nCCCountNo = 1 AND FinalizeFlag = 'N' THEN 1
                 WHEN @nCCCountNo = 2 AND FinalizeFlag_Cnt2 = 'N' THEN 1
                 WHEN @nCCCountNo = 3 AND FinalizeFlag_Cnt3 = 'N' THEN 1
              ELSE 0 END     
         AND 1 = CASE 
                 WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN 1
                 WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN 1
                 WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN 1
              ELSE 0 END     

         IF @nCCDLinesPerLOC = 0
         BEGIN
            SET @nErrNo = 71578
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'No CC To Reset'
            GOTO SKU_Fail
         END

      END
      
      SET @cSKUDesc = ''  
        
      SELECT @cSKUDesc = DESCR FROM dbo.SKU WITH (NOLOCK)  
      WHERE SKU = @cSKU  
      AND Storerkey = @cStorerkey  

      -- Prepare Reset screen var
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = CAST( @nCCCountNo AS NVARCHAR(1))
      SET @cOutField03 = @cLOC
      SET @cOutField04 = @cID -- ID
      SET @cOutField05 = @cSKU -- SKU
      SET @cOutField06 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1     
      SET @cOutField07 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2      
      SET @cOutField07 = ''   -- Option
      

      EXEC rdt.rdtSetFocusField @nMobile,8    -- Option

      --(yeekung01)  
      -- insert to Eventlog        
      EXEC RDT.rdt_STD_EventLog        
           @cActionType   = '7',
           @cUserID       = @cUserName,        
           @nMobileNo     = @nMobile,        
           @nFunctionID   = @nFunc,        
           @cFacility     = @cFacility,        
           @cStorerkey    = @cStorerkey,
           @cLocation     = @cLOC,  
           @cID           = @cID,  
           @cSKU          = @cSKU,  
           @cCCKey        = @cCCRefNo,        
           @cRefNo2       = '',        
           @cRefNo3       = '',        
           @cRefNo4       = '',  
           @nStep         = @nStep 

      -- Go to Reset count screen
      SET @nScn = @nScn_ConfirmReset
      SET @nStep = @nStep_ConfirmReset
      
      GOTO Quit
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = CAST( @nCCCountNo AS NVARCHAR( 1))
      SET @cOutField03 = ''

      -- Go to previous screen
      SET @nScn = @nScn_ID
      SET @nStep = @nStep_ID
   END
   GOTO Quit

   SKU_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField05 = '' -- SKU
   END

END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate       = GETDATE(), 
      ErrMsg         = @cErrMsg,
      Func           = @nFunc,
      Step           = @nStep,
      Scn            = @nScn,

      StorerKey      = @cStorerkey,
      Facility       = @cFacility,
      -- UserName       = @cUserName,
      
      V_LOC          = @cLOC,
      V_ID           = @cID,
      V_SKU          = @cSKU, -- (ChewKP01)

      V_String1      = @cCCRefNo,
      
      V_Integer1     = @nCCCountNo,
      
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