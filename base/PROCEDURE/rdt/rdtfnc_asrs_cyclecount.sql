SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_ASRS_CycleCount                                   */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#315031 - Call ASRS pallet to do Cycle Count/Inspection       */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2015-04-16 1.0  James    Created                                          */
/* 2016-09-30 1.1  Ung      Performance tuning                               */
/* 2018-10-26 1.2  TungGH   Performance                                      */
/*****************************************************************************/

CREATE PROC [RDT].[rdtfnc_ASRS_CycleCount](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
-- Misc variable
DECLARE
   @b_success           INT, 
   @bSuccess            INT 

-- Define a variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR(3),
   @cPrinter            NVARCHAR(10),
   @cUserName           NVARCHAR(18),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),

   @cOption             NVARCHAR(1), 
   @cExtendedValidateSP NVARCHAR( 20),    
   @cSQL                NVARCHAR(1000),   
   @cSQLParam           NVARCHAR(1000),   

   @cID                 NVARCHAR( 18), 
   @cCCRefNo            NVARCHAR( 10),
   @cCCSheetNo          NVARCHAR( 10),
   @cSKU                NVARCHAR( 20),
   @cSKUDescr           NVARCHAR( 60),
   @cWithQtyFlag        NVARCHAR( 1),
   @cLottableCode       NVARCHAR( 30), 
   @cCCDetailKey        NVARCHAR( 10), 
   @cCountedFlag        NVARCHAR( 3),
   @cLOT                NVARCHAR( 10),
   @cCaseUOM            NVARCHAR( 3),
   @cEachUOM            NVARCHAR( 3),
   @cPPK                NVARCHAR( 6),
   @cNewSKU             NVARCHAR( 20),
   @cStatus             NVARCHAR( 10),
   @cNewCaseQTY         NVARCHAR( 10),
   @cNewEachQTY         NVARCHAR( 10),
   @cNewSKUDescr        NVARCHAR( 60),
   @cDecodeLabelNo      NVARCHAR( 20),
   @cLabel2Decode       NVARCHAR( 20),
   @nSKUCnt             INT,

   @nCCCountNo          INT,
   @nRecCounted         INT,
   @nFinalizeStage      INT,       
   @nMorePage           INT,       
   @nEachQTY            INT,
   @nCaseCnt            INT,
   @nCaseQTY            INT,
   @nRecCnt             INT,
   @nConvQTY            INT,
   @nNewCaseQTY         INT,
   @nNewEachQTY         INT,
   @nFromScn            INT, 
   @nFromStep           INT, 
   @nTtlRecord          INT, 
   @nCount              INT,

   @fConvQTY            FLOAT,
   @cStorerGroup        NVARCHAR( 20),
   @cChkStorerKey       NVARCHAR( 15),

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

   @cFieldAttr01 NVARCHAR( 1),  @cFieldAttr02 NVARCHAR( 1),
   @cFieldAttr03 NVARCHAR( 1),  @cFieldAttr04 NVARCHAR( 1),
   @cFieldAttr05 NVARCHAR( 1),  @cFieldAttr06 NVARCHAR( 1),
   @cFieldAttr07 NVARCHAR( 1),  @cFieldAttr08 NVARCHAR( 1),
   @cFieldAttr09 NVARCHAR( 1),  @cFieldAttr10 NVARCHAR( 1),
   @cFieldAttr11 NVARCHAR( 1),  @cFieldAttr12 NVARCHAR( 1),
   @cFieldAttr13 NVARCHAR( 1),  @cFieldAttr14 NVARCHAR( 1),
   @cFieldAttr15 NVARCHAR( 1), 

   @c_oFieled01 NVARCHAR(20),   @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20),   @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20),   @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20),   @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20),   @c_oFieled10 NVARCHAR(20),
   @c_oFieled11 NVARCHAR(20),   @c_oFieled12 NVARCHAR(20),
   @c_oFieled13 NVARCHAR(20),   @c_oFieled14 NVARCHAR(20),
   @c_oFieled15 NVARCHAR(20) 


-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @cLangCode        = Lang_code,
   @nMenu            = Menu,

   @cStorerGroup     = StorerGroup, 
   @cFacility        = Facility,
   @cPrinter         = Printer,
   @cUserName        = UserName,

   @cStorerKey       = V_StorerKey,
   @cID              = V_ID,
   @cSKU             = V_SKU, 
   @cSKUDescr        = V_SKUDescr, 

   @cLottable01 =  V_Lottable01,
   @cLottable02 =  V_Lottable02,
   @cLottable03 =  V_Lottable03,
   @dLottable04 =  V_Lottable04,
   @dLottable05 =  V_Lottable05,
   @cLottable06 =  V_Lottable06,
   @cLottable07 =  V_Lottable07,
   @cLottable08 =  V_Lottable08,
   @cLottable09 =  V_Lottable09,
   @cLottable10 =  V_Lottable10,
   @cLottable11 =  V_Lottable11,
   @cLottable12 =  V_Lottable12,
   @dLottable13 =  V_Lottable13,
   @dLottable14 =  V_Lottable14,
   @dLottable15 =  V_Lottable15,

   @cCCRefNo         = V_String1,
   @cCCSheetNo       = V_String2,
   @cLottableCode    = V_String3, 
   @cCaseUOM         = V_String6, 
   @cEachUOM         = V_String8,
   @cCountedFlag     = V_String9,
   @cCCDetailKey     = V_String12,
   @cOption          = V_String14,
   
   @nCaseCnt         = V_Integer1,
   @nCaseQTY         = V_Integer2,
   @nEachQTY         = V_Integer3,   
   @nRecCounted      = V_Integer4,
   @nTtlRecord       = V_Integer5,
   @nCCCountNo       = V_Integer6,   
         
   @nFromScn         = V_FromScn,
   @nFromStep        = V_FromStep,

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
IF @nFunc = 733
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 733
   IF @nStep = 1 GOTO Step_1   -- Scn = 4150   Pallet ID
   IF @nStep = 2 GOTO Step_2   -- Scn = 4151   SKU, Count, Lottables, Option
   IF @nStep = 3 GOTO Step_3   -- Scn = 4152   QTY (Edit)
   IF @nStep = 4 GOTO Step_4   -- Scn = 4153   SKU (Add new)
   IF @nStep = 5 GOTO Step_5   -- Scn = 4154   Lottables (Add new)
   IF @nStep = 6 GOTO Step_6   -- Scn = 4155   QTY (Add new)
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1642)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 4150
   SET @nStep = 1

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

   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   -- initialise all variable
   SET @cID = ''

   -- Prep next screen var
   SET @cOutField01 = ''
END
GOTO Quit

/********************************************************************************
Step 1. screen = 4150
   PALLET ID (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cID = @cInField01

      --When PalletID is blank
      IF ISNULL( @cID, '') = ''
      BEGIN
         SET @nErrNo = 53501
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet ID req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- Check if 1 pallet id contain 2 open cckey. 1 must be closed before proceed 
      -- else cannot find a correct cckey
      SELECT @nCount = COUNT( StockTakeKey) 
      FROM dbo.StockTakeSheetParameters STK WITH (NOLOCK)
      WHERE [PASSWORD] <> 'POSTED'
      AND   EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK) 
                     WHERE TD.DropID = STK.StockTakeKey 
                     AND   TD.FromID = @cID
                     AND   TD.TaskType = 'ASRSCC')

      IF @nCount > 1
      BEGIN
         SET @nErrNo = 53523
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PL>1OPEN CCKEY
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      SET @cCCRefNo = ''
      SET @cCCSheetNo = ''

      -- Get the CCRefno
      SELECT TOP 1 @cCCRefNo = CCD.CCKey, 
                   @cCCSheetNo = CCD.CCSheetNo, 
                   @cChkStorerKey = CCD.StorerKey
      FROM dbo.CCDetail CCD WITH (NOLOCK) 
      JOIN dbo.TaskDetail TD WITH (NOLOCK) 
         ON ( CCD.ID = TD.FromID AND CCD.CCSheetNo = TD.SourceKey AND CCD.CCKey = TD.DropID)
      WHERE CCD.Status < '9'
      AND   CCD.ID = @cID
      AND   TD.Status = '9'
      AND   EXISTS ( SELECT 1
                     FROM dbo.StockTakeSheetParameters STK WITH (NOLOCK)
                     WHERE TD.DropID = STK.StockTakeKey
                     AND   [PASSWORD] <> 'POSTED')
      ORDER BY TransitCount DESC

      IF ISNULL( @cCCRefNo, '') = ''
      BEGIN
         SET @nErrNo = 53502
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- Check storer group
      IF @cStorerGroup <> ''
      BEGIN
         SELECT TOP 1 @cChkStorerKey = StorerKey
         FROM dbo.CCDETAIL WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo

         -- Check storer not in storer group
         IF NOT EXISTS (SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cChkStorerKey)
         BEGIN
            SET @nErrNo = 53522
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END

         -- Set session storer
         SET @cStorerKey = @cChkStorerKey
      END


      -- Get count # & finalized stage
      -- If FinalizeStage = 1 means 1st cnt already finalized.
      SET @nCCCountNo=1
      SELECT @nCCCountNo = CASE WHEN ISNULL(FinalizeStage,0) = 0 THEN 1
                                WHEN FinalizeStage = 1 THEN 2
                                WHEN FinalizeStage = 2 THEN 3
                           END, 
             @nFinalizeStage = FinalizeStage,
             @cWithQtyFlag = WithQuantity
      FROM dbo.StockTakeSheetParameters WITH (NOLOCK)
      WHERE StockTakeKey = @cCCRefNo

      -- Already counted 3 times, not allow to count again
      IF @nFinalizeStage = 3
      BEGIN
         SET @nErrNo = 53503
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Finalized Cnt3'
         GOTO Step_1_Fail
      END

      -- Entered CountNo must equal to FinalizeStage + 1, ie. if cnt1 not finalized, cannot go to cnt2
      IF @nCCCountNo <> @nFinalizeStage + 1
      BEGIN
         SET @nErrNo = 53504
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Wrong CNT NO'
         GOTO Step_1_Fail
      END

      SET @nRecCounted = 0
      -- Get no. of counted cartons
      SELECT @nRecCounted = COUNT(1) 
      FROM dbo.CCDETAIL (NOLOCK)
      WHERE CCKey = @cCCRefNo
      AND   CCSheetNo = @cCCSheetNo
      AND   ID = @cID
      AND   1 = CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN 1
                     WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN 1
                     WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN 1
                ELSE 0 END
      AND   (Status = '2' OR Status = '4')

      SET @nTtlRecord = 0
      -- Get no. of counted cartons
      SELECT @nTtlRecord = COUNT(1)
      FROM dbo.CCDETAIL (NOLOCK)
      WHERE CCKey = @cCCRefNo
      AND   CCSheetNo = @cCCSheetNo
      AND   ID = @cID
      AND   1 = CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '0' THEN 1
                     WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '0' THEN 1
                     WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '0' THEN 1
                ELSE 0 END
      AND   [Status] = '0'

      SET @cCCDetailKey = ''
      SET @nRecCnt = 0
      EXEC [RDT].[rdt_ASRSCC_GetCCDetail] 
         @cCCRefNo,
         @cCCSheetNo,
         @nCCCountNo,
         @cStorerKey,
         '',
         @cID,
         @cCCDetailKey    OUTPUT,
         @cCountedFlag    OUTPUT,
         @cSKU            OUTPUT,
         @cLOT            OUTPUT,
         @cLottable01     OUTPUT,
         @cLottable02     OUTPUT,
         @cLottable03     OUTPUT,
         @dLottable04     OUTPUT,
         @dLottable05     OUTPUT,
         @cLottable06     OUTPUT, 
         @cLottable07     OUTPUT, 
         @cLottable08     OUTPUT, 
         @cLottable09     OUTPUT, 
         @cLottable10     OUTPUT, 
         @cLottable11     OUTPUT, 
         @cLottable12     OUTPUT, 
         @dLottable13     OUTPUT, 
         @dLottable14     OUTPUT, 
         @dLottable15     OUTPUT, 
         @nCaseCnt        OUTPUT,
         @nCaseQTY        OUTPUT,
         @cCaseUOM        OUTPUT,
         @nEachQTY        OUTPUT,
         @cEachUOM        OUTPUT,
         @cSKUDescr       OUTPUT,
         @cPPK            OUTPUT,
         @nRecCnt         OUTPUT, 
         @cLottableCode   OUTPUT  

      IF ISNULL( @nRecCnt, '') = ''
      BEGIN
         SET @nErrNo = 53505
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Get task fail'
         GOTO Step_1_Fail
      END

      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 10, 1, 
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         '',      -- SourceKey
         @nFunc   -- SourceType

      --prepare next screen variable
      SET @cOutField08 = @cSKU
      SET @cOutField09 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField10 = SUBSTRING( @cSKUDescr, 21, 20)

      -- Space constraint, display first 7 chars
      SET @cOutField11 = LEFT( RTRIM( @cCaseUOM) + REPLICATE( ' ', 5), 5) + 
                         LEFT( RTRIM( SUBSTRING( CAST( @nCaseQTY AS NVARCHAR( 7)), 1, 7)) + REPLICATE( ' ', 8), 8) + 
                         CAST( @nRecCounted AS NVARCHAR( 3)) + '/' + CAST( @nTtlRecord AS NVARCHAR( 3))
      SET @cOutField12 = LEFT( RTRIM( @cEachUOM) + REPLICATE( ' ', 5), 5) + 
                         LEFT( RTRIM( CAST( @nEachQTY AS NVARCHAR( 7))) + REPLICATE( ' ', 8), 8) + @cCountedFlag
      SET @cOutField13 = ''



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
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cID = ''
      SET @cOutField01 = ''
    END
END
GOTO Quit

/********************************************************************************
Step 2. (screen = 4151)
   LOTTABLE01-10
   QTY
   OPTION: (Field13, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption= @cInField13

      --When Door is blank
      IF ISNULL( @cOption, '') = ''
      BEGIN
         SET @nRecCnt = 0
         EXEC [RDT].[rdt_ASRSCC_GetCCDetail] 
            @cCCRefNo,
            @cCCSheetNo,
            @nCCCountNo,
            @cStorerKey,
            '',
            @cID,
            @cCCDetailKey    OUTPUT,
            @cCountedFlag    OUTPUT,
            @cSKU            OUTPUT,
            @cLOT            OUTPUT,
            @cLottable01     OUTPUT,
            @cLottable02     OUTPUT,
            @cLottable03     OUTPUT,
            @dLottable04     OUTPUT,
            @dLottable05     OUTPUT,
            @cLottable06     OUTPUT, 
            @cLottable07     OUTPUT, 
            @cLottable08     OUTPUT, 
            @cLottable09     OUTPUT, 
            @cLottable10     OUTPUT, 
            @cLottable11     OUTPUT, 
            @cLottable12     OUTPUT, 
            @dLottable13     OUTPUT, 
            @dLottable14     OUTPUT, 
            @dLottable15     OUTPUT, 
            @nCaseCnt        OUTPUT,
            @nCaseQTY        OUTPUT,
            @cCaseUOM        OUTPUT,
            @nEachQTY        OUTPUT,
            @cEachUOM        OUTPUT,
            @cSKUDescr       OUTPUT,
            @cPPK            OUTPUT,
            @nRecCnt         OUTPUT, 
            @cLottableCode   OUTPUT  

         IF ISNULL( @nRecCnt, '') = ''
         BEGIN
            SET @nErrNo = 53506
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NO MORE TASK'
            GOTO Step_2_Fail
         END

         -- Dynamic lottable
         EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 10, 1, 
            @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
            @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
            @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
            @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
            @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
            @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
            @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
            @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
            @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
            @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
            @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
            @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
            @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
            @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
            @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
            @nMorePage   OUTPUT,
            @nErrNo      OUTPUT,
            @cErrMsg     OUTPUT,
            '',      -- SourceKey
            @nFunc   -- SourceType

         --prepare next screen variable
         SET @cOutField08 = @cSKU
         SET @cOutField09 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField10 = SUBSTRING( @cSKUDescr, 21, 20)

         -- Space constraint, display first 7 chars
         SET @cOutField11 = LEFT( RTRIM( @cCaseUOM) + REPLICATE( ' ', 5), 5) + 
                            LEFT( RTRIM( SUBSTRING( CAST( @nCaseQTY AS NVARCHAR( 7)), 1, 7)) + REPLICATE( ' ', 8), 8) + 
                            CAST( @nRecCounted AS NVARCHAR( 3)) + '/' + CAST( @nTtlRecord AS NVARCHAR( 3))
         SET @cOutField12 = LEFT( RTRIM( @cEachUOM) + REPLICATE( ' ', 5), 5) + 
                            LEFT( RTRIM( CAST( @nEachQTY AS NVARCHAR( 7))) + REPLICATE( ' ', 8), 8) + @cCountedFlag
         SET @cOutField13 = ''

         GOTO Quit
      END

      IF @cOption NOT IN ('1', '2', '3') 
      BEGIN
         SET @nErrNo = 53507
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Option
         GOTO Step_2_Fail
      END

      IF @cOption = '1' 
      BEGIN
         SET @cOutField01 = ''

         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2

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

         GOTO Quit
      END

      IF @cOption = '2' 
      BEGIN
         SET @cOutField01 = LEFT( RTRIM( @cCaseUOM) + REPLICATE( ' ', 5), 5)  
         SET @cOutField02 = LEFT( CAST( @nCaseQTY AS NVARCHAR( 7)), 5)
         SET @cOutField03 = ''
         SET @cOutField04 = LEFT( RTRIM( @cEachUOM) + REPLICATE( ' ', 5), 5) 
         SET @cOutField05 = CAST( @nEachQTY AS NVARCHAR( 7))
         SET @cOutField06 = ''

         SET @cFieldAttr03 = CASE WHEN ISNULL( @cCaseUOM, '') = '' THEN 'O' ELSE '' END
         SET @cFieldAttr06 = CASE WHEN ISNULL( @cEachUOM, '') = '' THEN 'O' ELSE '' END

         IF @cFieldAttr03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 3
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 6

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO Quit
      END

      IF @cOption = '3' 
      BEGIN
         IF ISNULL( @cCCDetailKey, '' ) <> ''
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK) 
                        WHERE CCDetailKey = @cCCDetailKey
                        AND 1 = CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN 1 
                                     WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN 1
                                     WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN 1
                                ELSE 0 END)
                        --AND  [Status] IN ('2', '4', '9'))
            BEGIN
               SET @nErrNo = 53521
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Rec Counted
               GOTO Step_2_Fail
            END

            SET @cCountedFlag = '[ ]'

            SELECT
               @cStatus = Status,
               @cCountedFlag =
                  CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN '[C]'
                       WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN '[C]'
                       WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN '[C]'
                  ELSE '[ ]' END
            FROM dbo.CCDETAIL (NOLOCK)
            WHERE CCDetailKey = @cCCDetailKey

            -- Update at 1st time verification / not counted
            IF @cCountedFlag = '[ ]' OR @cStatus = '0' 
            BEGIN
               -- Confirmed current record
               SET @nErrNo = 0
               SET @cErrMsg = ''
               EXECUTE rdt.rdt_ASRS_CycleCount
                  @nMobile,
                  @nFunc,
                  @cLangCode,
                  @cUserName,
                  @cCCRefNo,
                  @cCCSheetNo,
                  @nCCCountNo, 
                  @cStorerKey,
                  @cCCDetailKey,
                  0, 
                  @cSKU,
                  '',
                  @cID,
                  @cLottable01,
                  @cLottable02,
                  @cLottable03,
                  @dLottable04, 
                  @dLottable05, 
                  @cLottable06, 
                  @cLottable07, 
                  @cLottable08, 
                  @cLottable09, 
                  @cLottable10, 
                  @cLottable11, 
                  @cLottable12, 
                  @dLottable13, 
                  @dLottable14, 
                  @dLottable15, 
                  '3',     -- Confirm CCDetail only
                  @nErrNo       OUTPUT, 
                  @cErrMsg      OUTPUT

               IF @nErrNo <> 0
                  GOTO Step_2_Fail

               -- Set current record CountedFlag = [C]
               SET @cCountedFlag = '[C]'

               SET @nRecCounted = @nRecCounted + 1

               -- Space constraint, display first 7 chars
               SET @cOutField11 = LEFT( RTRIM( @cCaseUOM) + REPLICATE( ' ', 5), 5) + 
                                  LEFT( RTRIM( SUBSTRING( CAST( @nCaseQTY AS NVARCHAR( 7)), 1, 7)) + REPLICATE( ' ', 8), 8) + 
                                  CAST( @nRecCounted AS NVARCHAR( 3)) + '/' + CAST( @nTtlRecord AS NVARCHAR( 3))
               SET @cOutField12 = LEFT( RTRIM( @cEachUOM) + REPLICATE( ' ', 5), 5) + 
                                  LEFT( RTRIM( CAST( @nEachQTY AS NVARCHAR( 7))) + REPLICATE( ' ', 8), 8) + @cCountedFlag
               SET @cOutField13 = ''
            END
         END

         GOTO Quit
      END

      -- Get next CCDetail record
      SET @cCCDetailKey = ''
      SET @nRecCnt = 0
      EXEC [RDT].[rdt_ASRSCC_GetCCDetail] 
         @cCCRefNo,
         @cCCSheetNo,
         @nCCCountNo,
         @cStorerKey,
         '',
         @cID,
         @cCCDetailKey    OUTPUT,
         @cCountedFlag    OUTPUT,
         @cSKU            OUTPUT,
         @cLOT            OUTPUT,
         @cLottable01     OUTPUT,
         @cLottable02     OUTPUT,
         @cLottable03     OUTPUT,
         @dLottable04     OUTPUT,
         @dLottable05     OUTPUT,
         @cLottable06     OUTPUT, 
         @cLottable07     OUTPUT, 
         @cLottable08     OUTPUT, 
         @cLottable09     OUTPUT, 
         @cLottable10     OUTPUT, 
         @cLottable11     OUTPUT, 
         @cLottable12     OUTPUT, 
         @dLottable13     OUTPUT, 
         @dLottable14     OUTPUT, 
         @dLottable15     OUTPUT, 
         @nCaseCnt        OUTPUT,
         @nCaseQTY        OUTPUT,
         @cCaseUOM        OUTPUT,
         @nEachQTY        OUTPUT,
         @cEachUOM        OUTPUT,
         @cSKUDescr       OUTPUT,
         @cPPK            OUTPUT,
         @nRecCnt         OUTPUT, 
         @cLottableCode   OUTPUT  

      IF ISNULL( @nRecCnt, '') = ''
      BEGIN
         SET @nErrNo = 53509
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Get task fail'
         GOTO Step_2_Fail
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cID = ''
      SET @cOutField01 = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOption = ''
      SET @cOutField13 = ''
  END
END
GOTO Quit

/********************************************************************************
Step 3. (screen = 4152)
   QTY:           (Field01)
   QTY, PACKKEY:  (Field04, input)
   QTY, PACKKEY:  (Field07, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cNewCaseQTY = @cInField03
      SET @cNewEachQTY = @cInField06

      -- Retain the key-in value
      SET @cOutField03 = @cNewCaseQTY
      SET @cOutField06 = @cNewEachQTY

      -- Validate QTY (CS)
      IF ISNULL( @cNewCaseQTY, '') <> '' 
      BEGIN
         IF rdt.rdtIsValidQTY( @cNewCaseQTY, 0) <> 1
         BEGIN
            SET @nErrNo = 53510
            SET @cErrMsg = rdt.rdtgetmessage( 62134, @cLangCode, 'DSP') -- 'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 3   -- QTY (CS)
            GOTO Step_3_Fail
         END
      END

      -- Validate QTY (EA)
      IF ISNULL( @cNewEachQTY, '') <> '' 
      BEGIN
         IF rdt.rdtIsValidQTY( @cNewEachQTY, 0) <> 1
         BEGIN
            SET @nErrNo = 53511
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (EA)
            GOTO Step_3_Fail
         END
      END

      SET @nNewCaseQTY = 0
      SET @nNewEachQTY = 0

      -- Store in New variables
      SET @nNewCaseQTY = CASE WHEN ISNULL( @cNewCaseQTY, '') <> '' THEN CAST( @cNewCaseQTY AS FLOAT) ELSE 0 END
      SET @nNewEachQTY = CASE WHEN ISNULL( @cNewEachQTY, '') <> '' THEN CAST( @cNewEachQTY AS FLOAT) ELSE 0 END
      /*
      IF @nNewCaseQTY + @nNewEachQTY = 0
      BEGIN
         SET @nErrNo = 53512
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid Qty'
         GOTO Step_3_Fail
      END
      */
      -- Compare CaseCnt not NewCaseCnt, it is passed from previous screen
      IF @nCaseCnt = 0 AND @nNewCaseQTY > 0
      BEGIN
         SET @nErrNo = 53513
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Zero CaseCnt'
         GOTO Step_3_Fail
      END

      -- Get status
      SELECT @cStatus = Status
      FROM dbo.CCDETAIL (NOLOCK)
      WHERE CCDetailKey = @cCCDetailKey

      -- Update when Status = '0' or QTY is diff
      -- Status = '0' is 1st time verification, if EDIT then QTY shd be diff
      IF @cStatus = '0' OR
         @nNewCaseQTY <> @nCaseQTY OR
         @nNewEachQTY <> @nEachQTY
      BEGIN
         -- Convert QTY
         -- Allow zero QTY for Total of CaseQTY + EachQTY
         -- Check on CaseCnt, not NewCaseCnt
         IF @nCaseCnt > 0
            SET @nConvQTY = (@nNewCaseQTY * @nCaseCnt) + @nNewEachQTY
         ELSE
            SET @nConvQTY = @nNewEachQTY

         -- Confirmed current record
         SET @nErrNo = 0
         SET @cErrMsg = ''
         EXECUTE rdt.rdt_ASRS_CycleCount
            @nMobile,
            @nFunc,
            @cLangCode,
            @cUserName,
            @cCCRefNo,
            @cCCSheetNo,
            @nCCCountNo, 
            @cStorerKey,
            @cCCDetailKey,
            @nConvQTY, 
            @cSKU,
            '',
            @cID,
            @cLottable01,
            @cLottable02,
            @cLottable03,
            @dLottable04, 
            @dLottable05, 
            @cLottable06, 
            @cLottable07, 
            @cLottable08, 
            @cLottable09, 
            @cLottable10, 
            @cLottable11, 
            @cLottable12, 
            @dLottable13, 
            @dLottable14, 
            @dLottable15, 
            '2',     -- Edit Qty
            @nErrNo       OUTPUT, 
            @cErrMsg      OUTPUT

         IF @nErrNo <> 0
            GOTO Step_3_Fail

         SELECT TOP 1
            @nCaseQty = CASE WHEN PAC.CaseCnt > 0 AND @nConvQTY > 0
                                THEN FLOOR( @nConvQTY / PAC.CaseCnt)
                             ELSE 0 END,
            @nEachQty = CASE WHEN PAC.CaseCnt > 0
                                THEN @nConvQTY % CAST (PAC.CaseCnt AS INT)
                             WHEN PAC.CaseCnt = 0
                                THEN @nConvQTY
                             ELSE 0 END
         FROM dbo.SKU SKU (NOLOCK)
            INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cSKU

         SET @cCountedFlag = '[C]'

         -- Increase counter by 1
         SET @nRecCounted = @nRecCounted + 1
      END

      -- Space constraint, display first 7 chars
      SET @cOutField11 = LEFT( RTRIM( @cCaseUOM) + REPLICATE( ' ', 5), 5) + 
                         LEFT( RTRIM( SUBSTRING( CAST( @nCaseQTY AS NVARCHAR( 7)), 1, 7)) + REPLICATE( ' ', 8), 8) + 
                         CAST( @nRecCounted AS NVARCHAR( 3)) + '/' + CAST( @nTtlRecord AS NVARCHAR( 3))
      SET @cOutField12 = LEFT( RTRIM( @cEachUOM) + REPLICATE( ' ', 5), 5) + 
                         LEFT( RTRIM( CAST( @nEachQTY AS NVARCHAR( 7))) + REPLICATE( ' ', 8), 8) + @cCountedFlag
      SET @cOutField13 = ''


      -- Go to SKU (Main) screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 10, 1, 
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         '',      -- SourceKey
         @nFunc   -- SourceType

      --prepare prev screen variable
      SET @cOutField08 = @cSKU
      SET @cOutField09 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField10 = SUBSTRING( @cSKUDescr, 21, 20)

      -- Space constraint, display first 7 chars
      SET @cOutField11 = LEFT( RTRIM( @cCaseUOM) + REPLICATE( ' ', 5), 5) + 
                         LEFT( RTRIM( SUBSTRING( CAST( @nCaseQTY AS NVARCHAR( 7)), 1, 7)) + REPLICATE( ' ', 8), 8) + 
                         CAST( @nRecCounted AS NVARCHAR( 3)) + '/' + CAST( @nTtlRecord AS NVARCHAR( 3))
      SET @cOutField12 = LEFT( RTRIM( @cEachUOM) + REPLICATE( ' ', 5), 5) + 
                         LEFT( RTRIM( CAST( @nEachQTY AS NVARCHAR( 7))) + REPLICATE( ' ', 8), 8) + @cCountedFlag
      SET @cOutField13 = ''


      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      IF @cFieldAttr03 = ''
      BEGIN
         SET @cOutField03 = ''
         SET @cOutField06 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 3
      END
      ELSE
      BEGIN
         SET @cOutField06 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 6
      END
      GOTO Quit
  END
END
GOTO Quit


/********************************************************************************
Step 4. (screen = 4153)
   SKU: (Field01, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cNewSKU= ISNULL(@cInField01,'')

      -- Retain the key-in value
      SET @cOutField03 = @cNewSKU

      IF @cNewSKU = '' OR @cNewSKU IS NULL
      BEGIN
         SET @nErrNo = 53514
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'SKU/UPC req'
         GOTO Step_4_Fail
      END

      SET @cDecodeLabelNo = ''    
      SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)    

      IF ISNULL(@cDecodeLabelNo,'') NOT IN ('','0') 
      BEGIN    
         EXEC dbo.ispLabelNo_Decoding_Wrapper    
            @c_SPName     = @cDecodeLabelNo    
            ,@c_LabelNo    = @cLabel2Decode    
            ,@c_Storerkey  = @cStorerKey    
            ,@c_ReceiptKey = @nMobile    
            ,@c_POKey      = ''    
            ,@c_LangCode   = @cLangCode    
            ,@c_oFieled01  = @c_oFieled01 OUTPUT   
            ,@c_oFieled02  = @c_oFieled02 OUTPUT   
            ,@c_oFieled03  = @c_oFieled03 OUTPUT   
            ,@c_oFieled04  = @c_oFieled04 OUTPUT   
            ,@c_oFieled05  = @c_oFieled05 OUTPUT   
            ,@c_oFieled06  = @c_oFieled06 OUTPUT   
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
            GOTO Step_4_Fail    
         END    

         SET @cNewSKU = @c_oFieled01    
      END    
      SET @nSKUCnt = 0
      EXEC rdt.rdt_GETSKUCNT
          @cStorerkey  
         ,@cNewSKU        
         ,@nSKUCnt      OUTPUT
         ,@bSuccess     OUTPUT
         ,@nErrNo       OUTPUT
         ,@cErrMsg      OUTPUT

      -- Check SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 53515
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
         GOTO Step_4_Fail
      END

      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 53516
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SameBarCodeSKU
         GOTO Step_4_Fail
      END

      -- Validate SKU/UPC
      EXEC dbo.nspg_GETSKU
          @cStorerKey   OUTPUT
         ,@cNewSKU      OUTPUT
         ,@bSuccess     OUTPUT
         ,@nErrNo       OUTPUT
         ,@cErrMsg      OUTPUT

      SET @cSKU = @cNewSKU

      SELECT TOP 1
         @nCaseCnt = PAC.CaseCnt,
         @cSKUDescr = SKU.Descr,
         @cCaseUOM = CASE WHEN PAC.CaseCnt > 0
                             THEN SUBSTRING( PAC.PACKUOM1, 1, 3)
                          ELSE '' END,
         @cEachUOM = SUBSTRING( PAC.PACKUOM3, 1, 3),
         @cPPK     = CASE WHEN SKU.PrePackIndicator = '2'
                             THEN 'PPK:' + CAST( SKU.PackQtyIndicator AS NVARCHAR( 2))
                          ELSE '' END, 
         @cLottableCode = LottableCode 
      FROM dbo.SKU SKU (NOLOCK)
         INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU

      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'CAPTURE', 'POPULATE', 5, 1, 
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         '',
         @nFunc

      IF @nErrNo <> 0
         GOTO Quit

      IF @nMorePage = 1 -- Yes
      BEGIN
         -- Go to dynamic lottable screen
         SET @nFromScn = @nScn
         SET @nScn = 3990
         SET @nStep = @nStep + 1
         GOTO Quit
      END
      ELSE
      BEGIN
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField04 = @cCaseUOM
         SET @cOutField05 = ''
         SET @cOutField06 = @cEachUOM
         SET @cOutField07 = ''

         SET @cFieldAttr05 = CASE WHEN ISNULL( @cCaseUOM, '') = '' THEN 'O' ELSE '' END
         SET @cFieldAttr07 = CASE WHEN ISNULL( @cEachUOM, '') = '' THEN 'O' ELSE '' END

         IF @cFieldAttr05 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 5
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 7

         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2
      END
   END

   IF @nInputKey = 0 -- ENTER
   BEGIN
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 10, 1, 
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         '',      -- SourceKey
         @nFunc   -- SourceType

      --prepare next screen variable
      SET @cOutField08 = @cSKU
      SET @cOutField09 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField10 = SUBSTRING( @cSKUDescr, 21, 20)

      -- Space constraint, display first 7 chars
      SET @cOutField11 = LEFT( RTRIM( @cCaseUOM) + REPLICATE( ' ', 5), 5) + 
                         LEFT( RTRIM( SUBSTRING( CAST( @nCaseQTY AS NVARCHAR( 7)), 1, 7)) + REPLICATE( ' ', 8), 8) + 
                         CAST( @nRecCounted AS NVARCHAR( 3)) + '/' + CAST( @nTtlRecord AS NVARCHAR( 3))
      SET @cOutField12 = LEFT( RTRIM( @cEachUOM) + REPLICATE( ' ', 5), 5) + 
                         LEFT( RTRIM( CAST( @nEachQTY AS NVARCHAR( 7))) + REPLICATE( ' ', 9), 9) + @cCountedFlag
      SET @cOutField13 = ''

      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cNewSKU = ''

      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 5. (screen = 4154)
   LOTTABLES (Field01, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'CAPTURE', 'CHECK', 5, 1, 
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         '',
         @nFunc

      IF @nErrNo <> 0
         GOTO Quit

      IF @nMorePage = 1 -- Yes
         GOTO Quit

      -- Enable field
      SET @cFieldAttr02 = '' -- Dynamic lottable 1..5
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''

      SELECT TOP 1
         @nCaseCnt = PAC.CaseCnt,
         @cSKUDescr = SKU.Descr,
         @cCaseUOM = CASE WHEN PAC.CaseCnt > 0
                             THEN SUBSTRING( PAC.PACKUOM1, 1, 3)
                          ELSE '' END,
         @cEachUOM = SUBSTRING( PAC.PACKUOM3, 1, 3),
         @cPPK     = CASE WHEN SKU.PrePackIndicator = '2'
                             THEN 'PPK:' + CAST( SKU.PackQtyIndicator AS NVARCHAR( 2))
                          ELSE '' END, 
         @cLottableCode = LottableCode 
      FROM dbo.SKU SKU (NOLOCK)
         INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU

      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField04 = LEFT( RTRIM( @cCaseUOM) + REPLICATE( ' ', 5), 5)
      SET @cOutField05 = ''
      SET @cOutField06 = LEFT( RTRIM( @cEachUOM) + REPLICATE( ' ', 5), 5)
      SET @cOutField07 = ''

      SET @cFieldAttr05 = CASE WHEN ISNULL( @cCaseUOM, '') = '' THEN 'O' ELSE '' END
      SET @cFieldAttr07 = CASE WHEN ISNULL( @cEachUOM, '') = '' THEN 'O' ELSE '' END

      IF @cFieldAttr05 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 5
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 7

      SET @nScn = @nFromScn + 2
      SET @nStep = @nStep + 1      
   END

   IF @nInputKey = 0 -- ENTER
   BEGIN
      SET @cOutField01 = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

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

      GOTO Quit
   END
END
GOTO Quit

/********************************************************************************
Step 6. (screen = 4155)
   QTY (Field01, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cNewCaseQTY = @cInField05
      SET @cNewEachQTY = @cInField07

      -- Retain the key-in value
      SET @cOutField05 = @cNewCaseQTY
      SET @cOutField07 = @cNewEachQTY

      -- Validate QTY (CS)
      IF ISNULL( @cNewCaseQTY, '') <> '' 
      BEGIN
         IF rdt.rdtIsValidQTY( @cNewCaseQTY, 0) <> 1
         BEGIN
            SET @nErrNo = 53510
            SET @cErrMsg = rdt.rdtgetmessage( 62134, @cLangCode, 'DSP') -- 'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 3   -- QTY (CS)
            GOTO Step_6_Fail
         END
      END

      -- Validate QTY (EA)
      IF ISNULL( @cNewEachQTY, '') <> '' 
      BEGIN
         IF rdt.rdtIsValidQTY( @cNewEachQTY, 0) <> 1
         BEGIN
            SET @nErrNo = 53511
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 6   -- QTY (EA)
            GOTO Step_6_Fail
         END
      END

      SET @nNewCaseQTY = 0
      SET @nNewEachQTY = 0

      -- Store in New variables
      SET @nNewCaseQTY = CASE WHEN ISNULL( @cNewCaseQTY, '') <> '' THEN CAST( @cNewCaseQTY AS FLOAT) ELSE 0 END
      SET @nNewEachQTY = CASE WHEN ISNULL( @cNewEachQTY, '') <> '' THEN CAST( @cNewEachQTY AS FLOAT) ELSE 0 END

      IF @nNewCaseQTY + @nNewEachQTY = 0
      BEGIN
         SET @nErrNo = 53512
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid Qty'
         GOTO Step_6_Fail
      END

      -- Compare CaseCnt not NewCaseCnt, it is passed from previous screen
      IF @nCaseCnt = 0 AND @nNewCaseQTY > 0
      BEGIN
         SET @nErrNo = 53513
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Zero CaseCnt'
         GOTO Step_6_Fail
      END

      -- Get status
      SELECT @cStatus = Status
      FROM dbo.CCDETAIL (NOLOCK)
      WHERE CCDetailKey = @cCCDetailKey

      -- Update when Status = '0' or QTY is diff
      -- Status = '0' is 1st time verification, if EDIT then QTY shd be diff
      IF @cStatus = '0' OR
         @nNewCaseQTY <> @nCaseQTY OR
         @nNewEachQTY <> @nEachQTY
      BEGIN
         -- Convert QTY
         -- Allow zero QTY for Total of CaseQTY + EachQTY
         -- Check on CaseCnt, not NewCaseCnt
         IF @nCaseCnt > 0
            SET @nConvQTY = (@nNewCaseQTY * @nCaseCnt) + @nNewEachQTY
         ELSE
            SET @nConvQTY = @nNewEachQTY

         -- Confirmed current record
         SET @nErrNo = 0
         SET @cErrMsg = ''
         EXECUTE rdt.rdt_ASRS_CycleCount
            @nMobile,
            @nFunc,
            @cLangCode,
            @cUserName,
            @cCCRefNo,
            @cCCSheetNo,
            @nCCCountNo, 
            @cStorerKey,
            @cCCDetailKey,
            @nConvQTY, 
            @cSKU,
            '',
            @cID,
            @cLottable01,
            @cLottable02,
            @cLottable03,
            @dLottable04, 
            @dLottable05, 
            @cLottable06, 
            @cLottable07, 
            @cLottable08, 
            @cLottable09, 
            @cLottable10, 
            @cLottable11, 
            @cLottable12, 
            @dLottable13, 
            @dLottable14, 
            @dLottable15, 
            '1',     -- Add
            @nErrNo       OUTPUT, 
            @cErrMsg      OUTPUT

         IF @nErrNo <> 0
            GOTO Step_6_Fail

         SELECT TOP 1
            @nCaseQty = CASE WHEN PAC.CaseCnt > 0 AND @nConvQTY > 0
                                THEN FLOOR( @nConvQTY / PAC.CaseCnt)
                             ELSE 0 END,
            @nEachQty = CASE WHEN PAC.CaseCnt > 0
                                THEN @nConvQTY % CAST (PAC.CaseCnt AS INT)
                             WHEN PAC.CaseCnt = 0
                                THEN @nConvQTY
                             ELSE 0 END
         FROM dbo.SKU SKU (NOLOCK)
            INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cSKU

         SET @cCountedFlag = '[C]'

         -- Increase counter by 1
         SET @nRecCounted = @nRecCounted + 1
      END

      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 10, 1, 
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         '',      -- SourceKey
         @nFunc   -- SourceType

      SET @cOutField08 = @cSKU
      SET @cOutField09 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField10 = SUBSTRING( @cSKUDescr, 21, 20)

      -- Space constraint, display first 7 chars
      SET @cOutField11 = LEFT( RTRIM( @cCaseUOM) + REPLICATE( ' ', 5), 5) + 
                         LEFT( RTRIM( SUBSTRING( CAST( @nCaseQTY AS NVARCHAR( 7)), 1, 7)) + REPLICATE( ' ', 8), 8) + 
                         CAST( @nRecCounted AS NVARCHAR( 3)) + '/' + CAST( @nTtlRecord AS NVARCHAR( 3))
      SET @cOutField12 = LEFT( RTRIM( @cEachUOM) + REPLICATE( ' ', 5), 5) + 
                         LEFT( RTRIM( CAST( @nEachQTY AS NVARCHAR( 7))) + REPLICATE( ' ', 8), 8) + @cCountedFlag
      SET @cOutField13 = ''


      SET @nScn = @nScn - 4
      SET @nStep = @nStep - 4      
   END

   IF @nInputKey = 0 -- ENTER
   BEGIN
      SET @cOutField01 = ''

      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2

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

      GOTO Quit
   END
   GOTO Quit

   Step_6_Fail:
   BEGIN
      IF @cFieldAttr05 = ''
      BEGIN
         SET @cOutField05 = ''
         SET @cOutField07 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 5
      END
      ELSE
      BEGIN
         SET @cOutField07 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 7
      END
      GOTO Quit
  END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
      EditDate       = GETDATE(), 
      ErrMsg         = @cErrMsg,
      Func           = @nFunc,
      Step           = @nStep,
      Scn            = @nScn,

      V_StorerKey    = @cStorerKey,
      Facility       = @cFacility,
      Printer        = @cPrinter,
      -- UserName       = @cUserName,

      V_ID           = @cID,
      V_SKU          = @cSKU, 
      V_SKUDescr     = @cSKUDescr, 

      V_Lottable01   = @cLottable01,
      V_Lottable02   = @cLottable02,
      V_Lottable03   = @cLottable03,
      V_Lottable04   = @dLottable04,
      V_Lottable05   = @dLottable05,
      V_Lottable06   = @cLottable06,
      V_Lottable07   = @cLottable07,
      V_Lottable08   = @cLottable08,
      V_Lottable09   = @cLottable09,
      V_Lottable10   = @cLottable10,
      V_Lottable11   = @cLottable11,
      V_Lottable12   = @cLottable12,
      V_Lottable13   = @dLottable13,
      V_Lottable14   = @dLottable14,
      V_Lottable15   = @dLottable15,

      V_String1      = @cCCRefNo,
      V_String2      = @cCCSheetNo,
      V_String3      = @cLottableCode,
      V_String6      = @cCaseUOM,
      V_String8      = @cEachUOM,
      V_String9      = @cCountedFlag,
      V_String12     = @cCCDetailKey,
      V_String14     = @cOption,
      
      V_Integer1     = @nCaseCnt,
      V_Integer2     = @nCaseQTY,
      V_Integer3     = @nEachQTY,
      V_Integer4     = @nRecCounted,
      V_Integer5     = @nTtlRecord,
      V_Integer6     = @nCCCountNo,
      
      V_FromScn      = @nFromScn,
      V_FromStep     = @nFromStep,

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