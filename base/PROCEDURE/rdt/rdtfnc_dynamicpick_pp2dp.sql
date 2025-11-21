SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_DynamicPick_PP2DP                            */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: RDT Replenishment                                           */
/*          SOS85863 - Dynamic Pick Replenishment From                  */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2008-08-22 1.0  Shong    Combine Dynamic Pick Replen From & Replen To*/
/* 2008-09-04 1.1  James    Add checking on ToLOC scanned must be       */
/*                          DYNAMICPK type (james01)                    */
/* 2008-09-09 1.2  Shong    Performance Tuning                          */ 
/* 2008-10-30 1.3  Vicky    Add Trace                                   */
/* 2008-11-03 1.4  Vicky    Remove XML part of code that is used to     */
/*                          make field invisible and replace with new   */
/*                          code (Vicky02)                              */
/* 2008-11-10 1.5  James    Add in Event Log (james02)                  */
/* 2009-02-13 1.6  James    SOS122773 - Bug fix for wrongly placed      */
/*                          BEGIN TRAN (james03)                        */
/* 2009-03-09 1.7  James    SOS124937 - Skip PP to DP fromLoc           */
/* 2009-08-26 1.8  Vicky    Replace current EventLog with Standard Event*/
/*                          Log (Vicky06)                               */
/* 2016-09-30 1.9  Ung      Performance tuning                          */
/* 2018-11-01 2.0  Gan      Performance tuning                          */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_DynamicPick_PP2DP] (
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
   @cChkFacility NVARCHAR( 5),
   @nSKUCnt      INT, 
   @nRowCount    INT,
   @cXML         NVARCHAR( 4000) -- To allow double byte data for e.g. SKU desc

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
   @cPrinter    NVARCHAR( 10),  
   
   @cSKU        NVARCHAR( 20),
   @cDescr      NVARCHAR( 40),
   @cPUOM       NVARCHAR( 1), -- Prefer UOM
   @cPUOM_Desc  NVARCHAR( 5),
   @cMUOM_Desc  NVARCHAR( 5),
   @cReplenKey  NVARCHAR( 10),
   @cLot        NVARCHAR( 10),
   @cFromLoc    NVARCHAR( 10),
   @cToLoc      NVARCHAR( 10),
   @cFromID     NVARCHAR( 18),
   @cDropID     NVARCHAR( 18),-- Drop ID
   @cLottable02 NVARCHAR( 18),
   @cLottable03 NVARCHAR( 18),
   @dLottable04 DATETIME,
   @cActToLOC   NVARCHAR( 10), 
   @cReplenGroup NVARCHAR( 10), 
   @dZero       DATETIME, 
   
   @nPUOM_Div   INT, -- UOM divider
   @nQTY_Avail  INT, -- QTY available in LOTxLOCXID
   @nQTY        INT, -- Replenishment.QTY
   @nPQTY       INT, -- Preferred UOM QTY
   @nMQTY       INT, -- Master unit QTY
   @nActQTY     INT, -- Actual replenish QTY
   @nActMQTY    INT, -- Actual keyed in master QTY
   @nActPQTY    INT, -- Actual keyed in prefered QTY
   @nRowRef     INT, -- (james02)
   @cUserName   NVARCHAR( 15),  -- (james02)
   
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

   DECLARE @nReplenQTY        int, 
           @cReplenishmentKey NVARCHAR(10),
           @nReplenDiffLoc    NVARCHAR(10),
           @cSToLOC           NVARCHAR(10),
           @b_success         int, 
           @n_err             int, 
           @c_errmsg          NVARCHAR(215), 
           @c_WaveKey         NVARCHAR(10) 


   -- TraceInfo
   DECLARE    @d_starttime    datetime,
              @d_endtime      datetime,
              @d_step1        datetime,
              @d_step2        datetime,
              @d_step3        datetime,
              @d_step4        datetime,
              @d_step5        datetime, 
              @c_col1         NVARCHAR(20),
              @c_col2         NVARCHAR(20),
              @c_col3         NVARCHAR(20),
              @c_col4         NVARCHAR(20),
              @c_col5         NVARCHAR(20),
              @c_TraceName    NVARCHAR(80)


   SET @d_starttime = getdate()

   SET @c_TraceName = 'rdt_DynamicPick_PickAndPack_PP2DP'  
   
   
SET @dZero = 0 -- 1900-01-01

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
   @cPrinter    = Printer,   
   @cUserName   = UserName,
   
   @cSKU        = V_SKU,
   @cDescr      = V_SKUDescr,
   @cPUOM       = V_UOM,
   @cLottable02 = V_Lottable02,
   @cLottable03 = V_Lottable03,
   @dLottable04 = V_Lottable04,
   @cLOT        = V_LOt,
   @cFromLoc    = V_LOC,
   @cFromID     = V_ID,
   
   @nPUOM_Div   = V_PUOM_Div,
   @nMQTY       = V_MQTY,
   @nPQTY       = V_PQTY,
   
   @nActMQTY    = V_Integer1,
   @nActPQTY    = V_Integer2,
   @nActQty     = V_Integer3,
   @nRowRef     = V_Integer4,

   @cToLOC      = V_String1,
   @cActToLOC   = V_String2,
   @cMUOM_Desc  = V_String3,
   @cPUOM_Desc  = V_String4,
   @cReplenKey  = V_String5,
  -- @nPUOM_Div   = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6,  5), 0) = 1 THEN LEFT( V_String6,  5) ELSE 0 END,
  -- @nMQTY       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String7,  5), 0) = 1 THEN LEFT( V_String7,  5) ELSE 0 END,
  -- @nPQTY       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String8,  5), 0) = 1 THEN LEFT( V_String8,  5) ELSE 0 END,
  -- @nActMQTY    = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String9,  5), 0) = 1 THEN LEFT( V_String9,  5) ELSE 0 END,
  -- @nActPQTY    = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String10, 5), 0) = 1 THEN LEFT( V_String10, 5) ELSE 0 END,
  -- @nActQty     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String11, 5), 0) = 1 THEN LEFT( V_String11, 5) ELSE 0 END, 
   @cReplenGroup = V_String12,
  -- @nRowRef     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String13, 5), 0) = 1 THEN LEFT( V_String13, 5) ELSE 0 END, 
   
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

FROM RDTMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

SET @c_col1 = @cLOT
SET @c_col2 = @cFromLoc
SET @c_col3 = @cSKU

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

-- Redirect to respective screen
IF @nFunc = 930 -- Replenish (1 stage)
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 930
   IF @nStep = 1 GOTO Step_1   -- Scn = 1590. Repl Grp
   IF @nStep = 2 GOTO Step_2   -- Scn = 1591. SKU
   IF @nStep = 3 GOTO Step_3   -- Scn = 1592. ACT QTY
   IF @nStep = 4 GOTO Step_4   -- Scn = 1593. To LOC
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 515)
********************************************************************************/
Step_0:
BEGIN
-- Commented (Vicky02) - Start
--    -- Create the session data
--    IF EXISTS (SELECT 1 FROM RDTSessionData WHERE Mobile = @nMobile)
--       UPDATE RDTSessionData SET XML = '' WHERE Mobile = @nMobile
--    ELSE
--       INSERT INTO RDTSessionData (Mobile) VALUES (@nMobile)
-- Commented (Vicky02) - End

   -- Set the entry point
   SET @nScn = 1590
   SET @nStep = 1

   -- Init var
   SET @nPQTY = 0
   SET @nActPQTY = 0

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

   -- Get prefer UOM
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   -- Prep next screen var
   SET @cReplenGroup = ''
   SET @cOutField01 = '' -- FromLOC

    -- (Vicky06) EventLog - Sign In Function
    EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerKey,
     @cRefNo1     = 'PP to DP',
     @nStep       = @nStep

--   -- Start insert into eventlog (james02)
--   EXEC RDT.RDT_EventLog 
--      @nRowRef     = @nRowRef OUTPUT, 
--      @cUserID     = @cUserName, 
--      @cActivity   = 'PP to DP', 
--      @nFucntionID = @nFunc
END
GOTO Quit

/********************************************************************************
Step 1. Screen = 1590
   REPL GRP (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cReplenGroup = @cInField01

      -- Validate blank
      IF @cReplenGroup = '' OR @cReplenGroup IS NULL
      BEGIN
         SET @nErrNo = 63619
         SET @cErrMsg = rdt.rdtgetmessage( 63619, @cLangCode, 'DSP') --Need REPL GRP
         GOTO Step_1_Fail
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.Replenishment WITH (NOLOCK)
         WHERE ReplenishmentGroup = @cReplenGroup
            AND Confirmed = 'W')
      BEGIN
         SET @nErrNo = 63620
         SET @cErrMsg = rdt.rdtgetmessage( 63620, @cLangCode, 'DSP') --No Replen Task
         GOTO Step_1_Fail
      END

      SELECT TOP 1   
         @c_WaveKey = ReplenNo  
      FROM dbo.Replenishment WITH (NOLOCK)  
      WHERE ReplenishmentGroup = @cReplenGroup  
        AND Confirmed = 'W'

      IF NOT EXISTS (SELECT TOP 1 1  
         FROM   dbo.WAVE WAVE WITH (NOLOCK)   
         JOIN   dbo.WAVEDETAIL WD WITH (NOLOCK) ON WAVE.WaveKey = WD.WaveKey  
         JOIN   dbo.LOADPLANDETAIL LPD WITH (NOLOCK) ON WD.OrderKey = LPD.OrderKey  
         WHERE  WAVE.WaveKey = @c_WaveKey)  
      BEGIN
         SET @nErrNo = 63621
         SET @cErrMsg = rdt.rdtgetmessage( 63621, @cLangCode, 'DSP') --LoadNotExists
         GOTO Step_1_Fail
      END
			
      -- Prep next screen var
      SET @cOutField01 = @cReplenGroup
      SET @cOutField02 = '' --FromLOC

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN

     -- (Vicky06) EventLog - Sign Out Function
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerKey,
       @cRefNo1     = 'PP to DP',
       @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option

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

      -- Commented (Vicky02)
      -- Delete session data
      --DELETE RDTSessionData WHERE Mobile = @nMobile
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cReplenGroup = ''
      SET @cOutField01 = '' -- Repl Grp
   END
END
GOTO Quit

/********************************************************************************
Step 2. Screen 1591
   REPL GRP  (Field01)
   SKU       (Field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField02

      -- Validate blank
      IF @cSKU = '' OR @cSKU IS NULL
      BEGIN
         SET @nErrNo = 63606
         SET @cErrMsg = rdt.rdtgetmessage( 63606, @cLangCode, 'DSP') --SKU/UPC needed
         GOTO Step_2_Fail
      END

      -- Get SKU/UPC
      SELECT 
         @nSKUCnt = COUNT( DISTINCT A.SKU), 
         @cSKU = MIN( A.SKU) -- Just to bypass SQL aggregrate checking
      FROM 
      (
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
      ) A

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 63607
         SET @cErrMsg = rdt.rdtgetmessage( 63607, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_2_Fail
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 63608
         SET @cErrMsg = rdt.rdtgetmessage( 63608, @cLangCode, 'DSP') --'SameBarCodeSKU'
         GOTO Step_2_Fail
      END
      
      -- Validate if open task exists
      IF NOT EXISTS ( SELECT 1
         FROM dbo.Replenishment WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND ReplenishmentGroup = @cReplenGroup
            AND SKU = @cSKU
            AND Confirmed = 'W')
         BEGIN
            SET @nErrNo = 63609
            SET @cErrMsg = rdt.rdtgetmessage( 63609, @cLangCode, 'DSP') --'SKU Not on RPL'
            GOTO Step_2_Fail
         END

      -- Retrieve the FromLOC & ID
      SELECT TOP 1 
         @cFromLoc = FromLoc, 
         @cFromID = ID
      FROM dbo.Replenishment WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ReplenishmentGroup = @cReplenGroup
         AND SKU = @cSKU
         AND Confirmed = 'W'

      IF ISNULL(@cFromLoc, '') = ''
      BEGIN
         SET @nErrNo = 63602
         SET @cErrMsg = rdt.rdtgetmessage( 63602, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_2_Fail
      END

      -- Get 1st replenish task
      SELECT @cLottable02 = SPACE(18)
      SELECT @cLottable03 = SPACE(18)


      SELECT TOP 1
         @cLottable02 = LA.Lottable02, 
         @cLottable03 = LA.Lottable03, 
         @dLottable04 = LA.Lottable04, 
         @cSKU = R.SKU,
         @cToLOC = R.ToLOC,
         @nQTY = SUM(R.QTY)
      FROM dbo.Replenishment R WITH (NOLOCK)
      INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.LOT = R.LOT)
      WHERE R.StorerKey = @cStorerKey
         AND R.ReplenishmentGroup = @cReplenGroup
         AND R.FromLoc = @cFromLoc
         AND R.ID = @cFromID
         AND R.SKU = @cSKU
         AND R.Confirmed = 'W'
         AND LA.Lottable02 + LA.lottable03 + CONVERT( NVARCHAR(10), ISNULL( LA.lottable04, @dZero), 120) >
            @cLottable02 + @cLottable03 + CONVERT( NVARCHAR(10), ISNULL( @dLottable04, @dZero), 120)
      GROUP BY R.FROMLOC, R.SKU, LA.lottable02, LA.lottable03, LA.lottable04, R.TOLOC
      ORDER BY LA.lottable02 + LA.Lottable03 + CONVERT( NVARCHAR(10), ISNULL( LA.Lottable04, @dZero), 120)

      -- Get Pack info
      SELECT
         @cDescr = SKU.Descr,
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
         @nPUOM_Div = CAST( IsNULL(
            CASE @cPUOM
               WHEN '2' THEN Pack.CaseCNT
               WHEN '3' THEN Pack.InnerPack
               WHEN '6' THEN Pack.QTY
               WHEN '1' THEN Pack.Pallet
               WHEN '4' THEN Pack.OtherUnit1
               WHEN '5' THEN Pack.OtherUnit2
            END, 1) AS INT)
      FROM dbo.SKU SKU WITH (NOLOCK)
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY = 0
         SET @nMQTY = @nQTY
      END
      ELSE
      BEGIN
         SET @nPQTY = @nQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
         SET @nMQTY = @nQTY % @nPUOM_Div  -- Calc the remaining in master unit
      END

      -- Prep QTY screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRInG(@cDescr, 1, 20)
      SET @cOutField03 = SUBSTRInG(@cDescr, 21, 20)
      SET @cOutField04 = @cLottable02
      SET @cOutField05 = @cLottable03
      SET @cOutField06 = rdt.rdtFormatDate( @dLottable04)
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField07 = '' -- @cPUOM_Desc
         SET @cOutField09 = '' -- @nPQTY
         SET @cOutField11 = '' -- @nActPQTY
         SET @cOutField13 = '' -- @nPUOM_Div
         -- Disable pref QTY field
         SET @cFieldAttr11 = 'O' -- (Vicky02)
         --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field11', 'NULL', 'output', 'NULL', 'NULL', '')
      END
      ELSE
      BEGIN
         SET @cOutField07 = @cPUOM_Desc
         SET @cOutField09 = CAST( @nPQTY AS NVARCHAR( 5))
         SET @cOutField11 = '' -- ActPQTY
         SET @cOutField13 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
      END
      SET @cOutField08 = @cMUOM_Desc
      SET @cOutField10 = CAST( @nMQTY as NVARCHAR( 5))
      SET @cOutField12 = '' -- ActMQTY
      SET @cOutField13 = @cToLOC -- Dynamic Loc 

      -- Go to QTY screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
      
      SET @cOutField01 = ''

      SET @cSKU = ''

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

   Step_2_Fail:
   BEGIN
      SET @cOutField01 = @cReplenGroup
      SET @cOutField02 = '' -- SKU
   END
END
GOTO Quit

/********************************************************************************
Step 3. Screen 1592
   SKU       (Field01)
   SKU Desc1 (Field02)
   SKU Desc2 (Field03)
   Lottable2 (Field04)
   Lottable3 (Field05)
   Lottable4 (Field06)
   PUOM MUOM (Field07, Field08)
   RPL QTY   (Field09, Field10)
   ACT QTY   (Field11, Field12, both input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1      -- Yes OR Send
   BEGIN
      DECLARE @cActPQTY NVARCHAR( 5)
      DECLARE @cActMQTY NVARCHAR( 5)

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

      -- Screen mapping
      -- To prevent @cActPQTY been assigned by other value coz @cInField12 not always got value entered
      IF @cPUOM_Desc <> '' 
      BEGIN
         SET @cActPQTY = IsNULL( @cInField11, '')
      END

      SET @cActMQTY = IsNULL( @cInField12, '')

      -- Retain the key-in value
      SET @cOutField11 = @cInField11 -- Pref QTY
      SET @cOutField12 = @cInField12 -- Master QTY
      
      -- Blank to iterate open replenish tasks
      IF (@cPUOM_Desc <> '' AND @cActPQTY = '' AND @cActMQTY = '') OR -- When both prefer QTY and master QTY
         (@cPUOM_Desc = '' AND @cActMQTY = '')                        -- When only master QTY
      BEGIN
         -- Get next replenish task
         SELECT TOP 1
            @cLottable02 = LA.Lottable02, 
            @cLottable03 = LA.Lottable03, 
            @dLottable04 = LA.Lottable04, 
            @cSKU = R.SKU,
            @cToLOC = R.ToLOC,
            @nQTY = SUM(R.QTY)
         FROM dbo.Replenishment R WITH (NOLOCK)
         INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.LOT = R.LOT)
         WHERE R.StorerKey = @cStorerKey
            AND R.ReplenishmentGroup = @cReplenGroup
            AND R.FromLoc = @cFromLoc
            AND R.ID = @cFromID
            AND R.SKU = @cSKU
            AND R.Confirmed = 'W'
            AND LA.Lottable02 + LA.lottable03 + CONVERT( NVARCHAR(10), ISNULL( LA.lottable04, @dZero), 120) >
               @cLottable02 + @cLottable03 + CONVERT( NVARCHAR(10), ISNULL( @dLottable04, @dZero), 120)
         GROUP BY R.FROMLOC, R.SKU, LA.lottable02, LA.lottable03, LA.lottable04, R.TOLOC
         ORDER BY LA.lottable02 + LA.Lottable03 + CONVERT( NVARCHAR(10), ISNULL( LA.Lottable04, @dZero), 120)

         -- Validate next open tasks exist
         IF @@ROWCOUNT = 0 
         BEGIN
            -- (Vicky02) - Start
            SET @cFieldAttr11 = '' 
            -- (Vicky02) - End

            IF @cPUOM_Desc = ''
               -- Pref QTY is always enable (as screen defination). When reach last replenish task, this check comes 
               -- before the retrival and disable section, then quit. So need to disable the field here
               -- Disable pref QTY field
               --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field11', 'NULL', 'output', 'NULL', 'NULL', '')
               SET @cFieldAttr11 = 'O' -- (Vicky02)

            SET @nErrNo = 63610
            SET @cErrMsg = rdt.rdtgetmessage( 63610, @cLangCode, 'DSP') --'No more task'
            GOTO Step_3_Fail
         END
         
--         -- Get lottables
--         SELECT
--            @cLottable02 = Lottable02,
--            @cLottable03 = Lottable03,
--            @dLottable04 = Lottable04
--         FROM dbo.LotAttribute WITH (NOLOCK)
--         WHERE StorerKey = @cStorerKey
--            AND SKU = @cSKU
--            AND LOT = @cLOT
         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY = 0
            SET @nMQTY = @nQTY
         END
         ELSE
         BEGIN
            SET @nPQTY = @nQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
            SET @nMQTY = @nQTY % @nPUOM_Div  -- Calc the remaining in master unit
         END

         -- Prep QTY screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRInG(@cDescr, 1, 20)
         SET @cOutField03 = SUBSTRInG(@cDescr, 21, 20)
         SET @cOutField04 = @cLottable02
         SET @cOutField05 = @cLottable03
         SET @cOutField06 = rdt.rdtFormatDate( @dLottable04)
         IF @cPUOM_Desc = ''
         BEGIN
            SET @cOutField07 = '' -- @cPUOM_Desc
            SET @cOutField08 = '' -- @nPQTY
            SET @cOutField11 = '' -- ActPQTY
            SET @cOutField13 = '' -- @nPUOM_Div
            -- Disable pref QTY field
            SET @cFieldAttr11 = 'O' -- (Vicky02)
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field11', 'NULL', 'output', 'NULL', 'NULL', '')
         END
         ELSE
         BEGIN
            SET @cOutField07 = @cPUOM_Desc
            SET @cOutField09 = CAST( @nPQTY AS NVARCHAR( 5))
            SET @cOutField11 = '' -- ActPQTY
            SET @cOutField13 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
         END
         SET @cOutField08 = @cMUOM_Desc
         SET @cOutField10 = CAST( @nMQTY as NVARCHAR( 5))
         SET @cOutField12 = '' -- ActMQTY
         
         GOTO Quit
      END

      -- Validate ActPQTY
      IF ISNULL(RTRIM(@cActPQTY), '') = '' SET @cActPQTY = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cActPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 63611
         SET @cErrMsg = rdt.rdtgetmessage( 63611, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 12 -- PQTY
         GOTO Step_3_Fail
      END
      
      -- Validate ActMQTY
      IF @cActMQTY  = '' SET @cActMQTY  = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cActMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 63612
         SET @cErrMsg = rdt.rdtgetmessage( 63612, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 13 -- MQTY
         GOTO Step_3_Fail
      END

      -- Calc total QTY in master UOM
      SET @nActPQTY = CAST( @cActPQTY AS INT)
      SET @nActMQTY = CAST( @cActMQTY AS INT)
      SET @nActQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @nActPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nActQTY = @nActQTY + @nActMQTY

      -- Validate QTY
      IF @nActQTY = 0
      BEGIN
         SET @nErrNo = 63613
         SET @cErrMsg = rdt.rdtgetmessage( 63613, @cLangCode, 'DSP') --'QTY needed'
         GOTO Step_3_Fail
      END

      -- Calc total QTY in master UOM for Replen QTY
      SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @nPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nQTY = @nQTY + @nMQTY

      -- check if actual QTY different from RPL QTY
      IF @nActQTY <> @nQTY
      BEGIN
         SET @nErrNo = 63614
         SET @cErrMsg = rdt.rdtgetmessage( 63614, @cLangCode, 'DSP') --QTY different
         GOTO Step_3_Fail
      END
   
      SELECT @nQTY_Avail = SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) 
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)  
         INNER JOIN dbo.LOT LOT WITH (NOLOCK) ON (LOT.LOT = LLI.LOT)  
         INNER JOIN dbo.ID  ID WITH (NOLOCK) ON (ID.ID = LLI.ID)  
	      INNER JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
      WHERE LLI.StorerKey = @cStorerKey
      AND LLI.SKU = @cSKU
      AND LLI.LOC = @cFromLOC
      AND LLI.ID  = @cFromID
      AND LA.Lottable02 = @cLottable02
      AND LA.Lottable03 = @cLottable03
      AND ISNULL(LA.Lottable04, '') = ISNULL(@dLottable04, '')	
      AND LOC.LocationFlag <> 'HOLD'
      AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  
      GROUP BY LLI.StorerKey, LLI.SKU, LLI.LOC, LLI.ID

      IF @nQTY_Avail < @nActQTY 
      BEGIN
         SET @nErrNo = 63645
         SET @cErrMsg = rdt.rdtgetmessage( 63645, @cLangCode, 'DSP') --QTY different
         GOTO Step_3_Fail
      END			      

      -- Prep next screen var
      SET @cOutField01 = @cReplenGroup
      SET @cOutField02 = @cFromLoc
      SET @cOutField03 = @cFromID
      SET @cOutField04 = @cSKU
      SET @cOutField05 = SUBSTRING(@cDescr, 1, 20)
      SET @cOutField06 = SUBSTRING(@cDescr, 21, 20)
	   IF @cPUOM_Desc = ''
	   BEGIN
         SET @cOutField07 = '' -- @cPUOM_Desc
         SET @cOutField09 = '' -- @nPQTY
         SET @cOutField11 = '' -- @nActPQty
         SET @cOutField15 = '' -- @nPUOM_Div
         -- Disable pref QTY field
         SET @cFieldAttr11 = 'O' -- (Vicky02)
         --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field11', 'NULL', 'output', 'NULL', 'NULL', '')
	   END
	   ELSE
	   BEGIN
         SET @cOutField07 = @cPUOM_Desc
         SET @cOutField09 = CAST( @nPQTY AS NVARCHAR( 5))
         SET @cOutField11 = CAST( @nActPQty AS NVARCHAR( 5))
         SET @cOutField15 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
      END
      SET @cOutField08 = @cMUOM_Desc
      SET @cOutField10 = CAST( @nMQTY AS NVARCHAR( 5))
      SET @cOutField12 = CAST( @nActMQty AS NVARCHAR( 5))
      SET @cOutField13 = @cToLOC --Dynamic Loc

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen
      SET @cOutField01 = @cReplenGroup
      SET @cOutField02 = @cFromLoc
      SET @cOutField03 = @cFromID
      SET @cOutField04 = '' -- SKU
      SET @cOutField05 = @cSKU -- SKU
      SET @cOutField06 = SUBSTRInG(@cDescr, 1, 20) -- SKU DESCR 1
      SET @cOutField07 = SUBSTRInG(@cDescr, 21, 20) -- SKU DESCR 2
      SET @cSKU = ''

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
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      -- (Vicky02) - Start
      SET @cFieldAttr11 = '' 
      -- (Vicky02) - End

      IF @cPUOM_Desc = ''
         -- Pref QTY is always enable (as screen defination). When reach error, it will quit directly and forgot
         -- to disable the Pref QTY field. So centralize disable it here for all fail condition
         -- Disable pref QTY field
         SET @cFieldAttr11 = 'O' -- (Vicky02)
         --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field11', 'NULL', 'output', 'NULL', 'NULL', '')


      SET @cOutField12 = '' -- ActPQTY
      SET @cOutField13 = '' -- ActMQTY
   END
END
GOTO Quit


/********************************************************************************
Step 4. Screen = 1593
   REPL GROUP (Field01)
   FROM LOC   (Field02)
   FROM ID    (Field03)
   SKU        (Field04)
   SKU Desc 1 (Field05)
   SKU Desc 2 (Field06)
   PUOM MUOM  (Field07, Field08)
   RPL QTY    (Field09, Field09)
   ACT QTY    (Field11, Field10)
   DYN LOC    (Field13, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSToLOC = @cInField13

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

      IF @cToLOC = @cSToLOC 
         SET @nReplenDiffLoc = 0
      ELSE
         SET @nReplenDiffLoc = 1 

      SET @nReplenQTY = @nActMQty

      
      -- Validate blank
      IF @cToLoc = '' OR @cToLoc IS NULL
      BEGIN
         SET @nErrNo = 63615
      SET @cErrMsg = rdt.rdtgetmessage( 63601, @cLangCode, 'DSP') --LOC needed
         GOTO Step_4_Fail
      END

      -- Only DYNAMICPK allow (james01)
      IF NOT EXISTS(SELECT 1 FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cSToLOC AND LocationType = 'DYNAMICPK')
      BEGIN
         SET @nErrNo = 63646
         SET @cErrMsg = rdt.rdtgetmessage( 63646, @cLangCode, 'DSP') --Invalid LOC
         GOTO Step_4_Fail
      END

      BEGIN TRAN  -- (james03)
      SAVE TRAN DynamicPick_ReplenTo_1 -- (james03)
      
------------------------------------------------------
      -- Delete and insert new Replenishment record
      DECLARE @cReplenishmentGroup NVARCHAR( 10)
	      , @nQtyMoved		INT
	      , @nQtyInPickLoc	INT
	      , @cPriority	 NVARCHAR( 5)
	      , @cUOM			 NVARCHAR( 10)
	      , @cPackKey		 NVARCHAR( 10)
	      , @cConfirmed	 NVARCHAR( 1)
	      , @cReplenNo	 NVARCHAR( 10)
	      , @cRemark		 NVARCHAR( 255)
	      , @cRefNo		 NVARCHAR( 20)
	      , @cLoadKey		 NVARCHAR( 10)
	      , @cReplenToLOC NVARCHAR( 10)
	      , @nTotalQTY		INT
	      , @nQtyToTake		INT
	      , @nLotQTY			INT
	      , @cLotToTake	 NVARCHAR( 10)   		

      DECLARE curReplenMove CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT R.LOT, 
			    R.ReplenishmentKey, 
             R.Qty, 
             R.ReplenNo   
      FROM dbo.Replenishment R WITH (NOLOCK)
      JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (R.LOT = LA.LOT)
      WHERE R.StorerKey = @cStorerKey
         AND R.ReplenishmentGroup = @cReplenGroup
         AND R.FromLoc = @cFromLoc
         AND R.ID  = @cFromID
         AND R.SKU = @cSKU
         AND R.Confirmed = 'W'
         AND LA.Lottable02 = @cLottable02 
         AND LA.lottable03 = @cLottable03
    AND ISNULL(LA.Lottable04, '') = ISNULL(@dLottable04, '')	


      OPEN curReplenMove

      FETCH NEXT FROM curReplenMove INTO @cLOT, @cReplenKey, @nQty, @c_WaveKey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
------------
         IF NOT EXISTS (SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
						   INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)  
						   INNER JOIN dbo.LOT LOT WITH (NOLOCK) ON (LOT.LOT = LLI.LOT)  
						   INNER JOIN dbo.ID  ID WITH (NOLOCK) ON (ID.ID = LLI.ID)  
					      WHERE LLI.StorerKey = @cStorerKey
						   AND LLI.SKU = @cSKU
						   AND LLI.LOT = @cLOT
						   AND LLI.LOC = @cFromLOC
						   AND LLI.ID  = @cFromID
						   AND LOC.LocationFlag <> 'HOLD'
						   AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  
						   AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) >= @nQty)
         BEGIN
   	      -- Find same or other LOT with same LOC, ID and Lottables
   	      IF EXISTS (SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
						         INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)  
						         INNER JOIN dbo.LOT LOT WITH (NOLOCK) ON (LOT.LOT = LLI.LOT)  
						         INNER JOIN dbo.ID  ID WITH (NOLOCK) ON (ID.ID = LLI.ID)  
							      INNER JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
					         WHERE LLI.StorerKey = @cStorerKey
						         AND LLI.SKU = @cSKU
							      -- Can use current LOT if having available QTY
						         --AND LLI.LOT <> @cLOT
						         AND LLI.LOC = @cFromLOC
						         AND LLI.ID  = @cFromID
							      -- Must be same Lottables
							      AND LA.Lottable02 = @cLottable02
							      AND LA.Lottable03 = @cLottable03
							      AND ISNULL(LA.Lottable04, '') = ISNULL(@dLottable04, '')	
						         AND LOC.LocationFlag <> 'HOLD'
						         AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  
							      GROUP BY LLI.StorerKey, LLI.SKU, LLI.LOC, LLI.ID
							      HAVING SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) >= @nQty)
   	      BEGIN
   		      SET @nQtyToTake = 0
   		      SET @nTotalQTY = @nQTY
         		
   		      IF @nReplenDiffLoc = 0
   			      SET @cReplenToLOC = @cToLOC
   		      ELSE
   			      SET @cReplenToLOC = @cSToLOC
         			
   		      SELECT 
   			      @cReplenishmentGroup = ReplenishmentGroup
   			      , @nQtyMoved 		 	= QtyMoved
   			      , @nQtyInPickLoc 		= QtyInPickLoc
   			      , @cPriority 			= Priority
   			      , @cUOM 					= UOM
   			      , @cPackKey 			= PackKey
   			      , @cConfirmed			= Confirmed
   			      , @cReplenNo			= ReplenNo
   			      , @cRemark				= Remark
   			      , @cRefNO				= RefNo
   			      , @cLoadKey				= LoadKey
                  , @c_WaveKey         = ReplenNo
			      FROM dbo.Replenishment (NOLOCK)
			      WHERE ReplenishmentKey = @cReplenKey
      		
--   		      BEGIN TRAN (james03)
--   		      SAVE TRAN DynamicPick_ReplenTo_1
         		
   		      -- Delete replenishment record
   		      DELETE FROM dbo.Replenishment WHERE ReplenishmentKey = @cReplenKey

         		SET @d_step1 = GETDATE()         		
   		      DECLARE curLOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
 				      SELECT LLI.LOT, LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked 
 				      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
				         INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)  
				         INNER JOIN dbo.LOT LOT WITH (NOLOCK) ON (LOT.LOT = LLI.LOT)  
				         INNER JOIN dbo.ID  ID WITH (NOLOCK) ON (ID.ID = LLI.ID)
					      INNER JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)  
			         WHERE LLI.StorerKey = @cStorerKey
				         AND LLI.SKU = @cSKU
				         AND LLI.LOC = @cFromLOC
				         AND LLI.ID  = @cFromID
					 AND LA.Lottable02 = @cLottable02
					      AND LA.Lottable03 = @cLottable03
					      AND ISNULL(LA.Lottable04, '') = ISNULL(@dLottable04, '')	
				         AND LOC.LocationFlag <> 'HOLD'
				         AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  
					      AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked > 0
				      ORDER BY LLI.LOT
      		
   		      OPEN curLOT
               SET @d_step1 = GETDATE() - @d_step1   		      
		         FETCH NEXT FROM curLOT INTO @cLotToTake, @nLotQTY
		         WHILE @@FETCH_STATUS = 0
		         BEGIN
   			      IF @nTotalQTY >= @nLotQTY
   			      BEGIN
   				      SET @nQtyToTake = @nLotQTY
   				      SET @nTotalQTY = @nTotalQTY - @nLotQTY
   			      END
   			      ELSE
   			      BEGIN
   				      SET @nQtyToTake = @nTotalQTY
   				      SET @nTotalQTY = 0  				
   			      END		

                  SET @d_step2 = GETDATE()
   		         -- Insert new Replenishment record
	               DECLARE @cNewReplenKey NVARCHAR( 10)
	               EXECUTE dbo.nspg_GetKey
	                  'REPLENISHKEY', 
	                  10 ,
	                  @cNewReplenKey	OUTPUT,
	                  @b_success     OUTPUT,
	                  @n_err         OUTPUT,
	                  @c_errmsg      OUTPUT
	               IF @b_success <> 1
	               BEGIN
	                  SET @nErrNo = 63643
	                  SET @cErrMsg = rdt.rdtgetmessage( 63643, @cLangCode, 'DSP') -- 'GetRplKey Fail'
	                  GOTO RollBackTran
	               END
                  SET @d_step2 = GETDATE() - @d_step2
                  
	               INSERT INTO dbo.Replenishment (ReplenishmentKey, ReplenishmentGroup, Storerkey, Sku, FromLoc, ToLoc,                
						      Lot, Id, Qty, QtyMoved, QtyInPickLoc, Priority, UOM, PackKey, 
						      Confirmed, ReplenNo, Remark, RefNo, DropID, LoadKey)            
	               VALUES (@cNewReplenKey, @cReplenishmentGroup, @cStorerkey, @cSKU, @cFromLoc, @cReplenToLoc,                
						      @cLotToTake, @cFromID, @nQtyToTake, @nQtyMoved, @nQtyInPickLoc, @cPriority, @cUOM, @cPackKey, 
						      @cConfirmed, @cReplenNo, @cRemark, @cRefNo, @cDropID, @cLoadKey)  
      			   
	               IF @@ERROR <> 0
	               BEGIN
					      SET @nErrNo = 63644
	                  SET @cErrMsg = rdt.rdtgetmessage( 63644, @cLangCode, 'DSP') --'Ins REPL Fail'
	                  GOTO RollBackTran
	               END

                  SET @d_step3 = GETDATE() 
   			      -- Perform MOVE
   			      EXECUTE rdt.rdt_DynamicPick_ReplenMove 
		               @nFunc       = @nFunc,
		               @nMobile     = @nMobile,
		               @cLangCode   = @cLangCode, 
		               @nErrNo      = @nErrNo OUTPUT,
		               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
		               @cSourceType = 'rdtfnc_DynamicPick_ReplenishTo', 
		               @cStorerKey  = @cStorerKey,
		               @cFacility   = @cFacility, 
		               @cFromLOC    = @cFromLOC, 
		               @cToLOC      = @cReplenToLOC,	
		               @cFromID     = @cFromID, 		-- NULL means not filter by ID. Blank ID is a valid ID
		               @cToID       = @cFromID, 		-- NULL means not changing ID. Blank ID is a valid ID
		               @cSKU        = @cSKU, 			-- Either SKU or UCC only
		               @cUCC        = NULL, 			
		               @nQTY        = @nQtyToTake,	-- For move by SKU, QTY must have value
		               @cFromLOT    = @cLotToTake, 	-- Applicable for all 6 types of move
		               @c_WaveKey   = @c_WaveKey,
		               @cReplenKey  = @cNewReplenKey,-- @cReplenKey,
		               @cLottable02 = @cLottable02
         		
			         IF @nErrNo <> 0
			         BEGIN
					      GOTO RollBackTran
			         END   			

                  SET @d_step3 = GETDATE() - @d_step3	
                  SET @c_Col5 = 'SwapLot'

                  SET @d_endtime = GETDATE()
                  INSERT INTO TraceInfo VALUES
		                     (RTRIM(@c_TraceName), @d_starttime, @d_endtime
		                     ,CONVERT(CHAR(12),@d_endtime - @d_starttime ,114)
		                     ,CONVERT(CHAR(12),@d_step1,114) 
		                     ,CONVERT(CHAR(12),@d_step2,114) 
		                     ,CONVERT(CHAR(12),@d_step3,114) 
		                     ,CONVERT(CHAR(12),@d_step4,114) 
		                     ,CONVERT(CHAR(12),@d_step5,114)
                           ,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)
            
                  SET @d_step1 = NULL
                  SET @d_step2 = NULL
                  SET @d_step3 = NULL
                  SET @d_step4 = NULL
                  SET @d_step5 = NULL

                  -- (Vicky06) EventLog - QTY
                  EXEC RDT.rdt_STD_EventLog
                     @cActionType   = '3', -- Picking
                     @cUserID       = @cUserName,
                     @nMobileNo     = @nMobile,
                     @nFunctionID   = @nFunc,
                     @cFacility     = @cFacility,
                     @cStorerKey    = @cStorerKey,
                     @cSKU          = @cSKU,
                     @cUOM          = @cUOM,
                     @nQTY          = @nQtyToTake,
                     @cWaveKey      = @c_WaveKey,
                     --@cRefNo1       = @c_WaveKey
                     @nStep         = @nStep
                  
--                  -- Start insert event log detail (james02)
--                  EXEC RDT.RDT_EventLogDetail 
--                     @nRowRef    = @nRowRef, 
--                     @cFacility  = @cFacility, 
--                     @cStorerKey = @cStorerKey, 
--                     @cSKU       = @cSKU,
--                     @cUOM       = @cUOM,
--                     @nQTY       = @nQtyToTake,
--                     @cDocRefNo  = @c_WaveKey 
                              		
   			      IF @nTotalQTY = 0 BREAK -- Exit
         		
   			      FETCH NEXT FROM curLOT INTO @cLotToTake, @nLotQTY
   		      END
			      CLOSE curLOT
			      DEALLOCATE curLOT

			      COMMIT TRAN DynamicPick_ReplenTo_1
   	      END
   	      ELSE
		      BEGIN
	            SET @nErrNo = 63645
	            SET @cErrMsg = rdt.rdtgetmessage( 63645, @cLangCode, 'DSP') --'InventNotEnuf'
	            GOTO RollBackTran   	
	         END
	      END -- LOT NOT Exists
	      ELSE
	      BEGIN -- LOT Exists
	         IF @nReplenDiffLoc = 0   
		      BEGIN
		         SET @d_step1 = GETDATE() 
	            EXECUTE rdt.rdt_DynamicPick_ReplenMove 
	               @nFunc       = @nFunc,
	               @nMobile     = @nMobile,
	               @cLangCode   = @cLangCode, 
	               @nErrNo      = @nErrNo OUTPUT,
	               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
	               @cSourceType = 'rdtfnc_DynamicPick_ReplenishTo', 
	               @cStorerKey  = @cStorerKey,
	               @cFacility   = @cFacility, 
	               @cFromLOC    = @cFromLOC, 
	               @cToLOC      = @cToLOC, 
	               @cFromID     = @cFromID, -- NULL means not filter by ID. Blank ID is a valid ID
	               @cToID       = @cFromID, -- NULL means not changing ID. Blank ID is a valid ID
	               @cSKU        = @cSKU,	 -- Either SKU or UCC only
	               @cUCC        = NULL,
	               @nQTY        = @nQTY,    -- For move by SKU, QTY must have value
	               @cFromLOT    = @cLOT,	 -- Applicable for all 6 types of move
	               @c_WaveKey   = @c_WaveKey,
	               @cReplenKey  = @cReplenKey,
	               @cLottable02 = @cLottable02

                 SET @d_step1 = GETDATE() - @d_step1
                 SET @c_Col5 = 'RepDiffLoc=0'
		      END
		      ELSE
		      BEGIN
		         SET @d_step2 = GETDATE() 
	            EXECUTE rdt.rdt_DynamicPick_ReplenMove 
	               @nFunc       = @nFunc,
	               @nMobile     = @nMobile,
	               @cLangCode   = @cLangCode, 
	               @nErrNo      = @nErrNo OUTPUT,
	               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
	               @cSourceType = 'rdtfnc_DynamicPick_ReplenishTo', 
	               @cStorerKey  = @cStorerKey,
	               @cFacility   = @cFacility, 
	               @cFromLOC    = @cFromLOC, 
	               @cToLOC      = @cSToLOC, 
	               @cFromID     = @cFromID, -- NULL means not filter by ID. Blank ID is a valid ID
	               @cToID       = @cFromID, -- NULL means not changing ID. Blank ID is a valid ID
	               @cSKU        = @cSKU,	 -- Either SKU or UCC only
	               @cUCC        = NULL,
	               @nQTY        = @nQTY,    -- For move by SKU, QTY must have value
	               @cFromLOT    = @cLOT,	 -- Applicable for all 6 types of move
	               @cReplenKey  = @cReplenKey,
	               @c_WaveKey   = @c_WaveKey,
	               @cLottable02 = @cLottable02
	               
                  SET @d_step2 = GETDATE() - @d_step2
                  SET @c_Col5 = 'RepDiffLoc<>0'
		      END

	         IF @nErrNo <> 0
	         BEGIN
	            GOTO Step_4_Fail
	         END
	         
            SET @d_endtime = GETDATE()
            INSERT INTO TraceInfo VALUES
		               (RTRIM(@c_TraceName), @d_starttime, @d_endtime
		               ,CONVERT(CHAR(12),@d_endtime - @d_starttime ,114)
		               ,CONVERT(CHAR(12),@d_step1,114) 
		               ,CONVERT(CHAR(12),@d_step2,114) 
		               ,CONVERT(CHAR(12),@d_step3,114) 
		               ,CONVERT(CHAR(12),@d_step4,114) 
		               ,CONVERT(CHAR(12),@d_step5,114)
                     ,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)

            SET @d_step1 = NULL
            SET @d_step2 = NULL
            SET @d_step3 = NULL
            SET @d_step4 = NULL
            SET @d_step5 = NULL

            SELECT @cUOM = UOM FROM dbo.Replenishment WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey 
               AND ReplenishmentKey = @cReplenKey

            -- (Vicky06) EventLog - QTY
              EXEC RDT.rdt_STD_EventLog
                 @cActionType   = '3', -- Picking
                 @cUserID       = @cUserName,
                 @nMobileNo     = @nMobile,
                 @nFunctionID   = @nFunc,
                 @cFacility     = @cFacility,
                 @cStorerKey    = @cStorerKey,
                 @cSKU          = @cSKU,
                 @cUOM          = @cUOM,
                 @nQTY          = @nQTY,
                 @cWaveKey      = @c_WaveKey,
                 --@cRefNo1       = @c_WaveKey
                 @nStep         = @nStep
               
            -- Start insert event log detail (james02)
--            EXEC RDT.RDT_EventLogDetail 
--               @nRowRef    = @nRowRef, 
--               @cFacility  = @cFacility, 
--               @cStorerKey = @cStorerKey, 
--               @cSKU       = @cSKU,
--               @cUOM       = @cUOM,
--               @nQTY       = @nQTY,
--               @cDocRefNo  = @c_WaveKey               	         
	      END -- LOT Exists

-----------
         FETCH NEXT FROM curReplenMove INTO @cLOT, @cReplenKey, @nQTY, @c_WaveKey
      END
      CLOSE curReplenMove
      DEALLOCATE curReplenMove

      -- Go to screen 2
      SET @nScn  = @nScn - 2
      SET @nStep = @nStep - 2

      -- Prep next screen var
      SET @cOutField01 = @cReplenGroup
      SET @cOutField02 = ''

      SET @cSKU = ''
   END

--------------------------------------
   IF @nInputKey = 0 -- ESC
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

      -- Prep prev screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING(@cDescr, 1, 20)
      SET @cOutField03 = SUBSTRING(@cDescr, 21, 20)
      SET @cOutField04 = @cLottable02
      SET @cOutField05 = @cLottable03
      SET @cOutField06 = rdt.rdtFormatDate( @dLottable04)
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField07 = '' -- @cPUOM_Desc
         SET @cOutField09 = '' -- @nPQTY
         SET @cOutField11 = '' -- ActPQTY
         SET @cOutField13 = '' -- @nPUOM_Div
         -- Disable pref QTY field
         SET @cFieldAttr11 = 'O' -- (Vicky02)
         --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field11', 'NULL', 'output', 'NULL', 'NULL', '')
	   END
	   ELSE
	   BEGIN
         SET @cOutField07 = @cPUOM_Desc
         SET @cOutField09 = CAST( @nPQTY AS NVARCHAR( 5))
         SET @cOutField11 = '' -- ActPQTY
         SET @cOutField13 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
      END

      SET @cOutField08 = @cMUOM_Desc
      SET @cOutField10 = CAST( @nMQTY AS NVARCHAR( 5))
      SET @cOutField12 = '' -- ActMQTY

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   RollBackTran:
   	ROLLBACK TRAN DynamicPick_ReplenTo_1  	

   Step_4_Fail:
   BEGIN
      SET @cActToLOC = ''
      SET @cOutField13 = '' -- ActToLOC
   END
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

      V_SKU     = @cSKU,
      V_SKUDescr= @cDescr,
      V_UOM     = @cPUOM,
      V_LOT     = @cLOT,
      V_LOC     = @cFromLoc,
      V_ID      = @cFromID,
      V_Lottable02 = @cLottable02,
      V_Lottable03 = @cLottable03,
      V_Lottable04 = @dLottable04,
      
      V_PUOM_Div  = @nPUOM_Div,
      V_MQTY      = @nMQTY,
      V_PQTY      = @nPQTY,
   
      V_Integer1  = @nActMQTY,
      V_Integer2  = @nActPQTY,
      V_Integer3  = @nActQty,
      V_Integer4  = @nRowRef,
      
      V_String1 = @cToLOC,
      V_String2 = @cActToLOC, 
      V_String3 = @cMUOM_Desc,
      V_String4 = @cPUOM_Desc,
      V_String5 = @cReplenKey,
      --V_String6 = @nPUOM_Div,
      --V_String7 = @nMQTY,
      --V_String8 = @nPQTY,
      --V_String9 = @nActMQTY,
      --V_String10= @nActPQTY,
      --V_String11= @nActQty, 
      V_String12 = @cReplenGroup,
      --V_String13 = @nRowRef,
      
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
--  @cX       NVARCHAR( 4),   -- size 4 is needed bcoz of 'NULL'
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
--                CASE WHEN @cDefault IS NULL THEN '' ELSE 'Default="' + @cDefault + '" ' END +
--                CASE WHEN @cValue   IS NULL THEN '' ELSE 'Value="'   + @cValue   + '" ' END +
--                CASE WHEN @cNewID   IS NULL THEN '' ELSE 'NewID="'   + @cNewID   + '" ' END +
--             '/>'
--          FETCH NEXT FROM @curScreen INTO @cTyp, @cX, @cY, @cLength, @cFieldID, @cDefault, @cValue, @cNewID
--       END
--       CLOSE @curScreen
--       DEALLOCATE @curScreen
--    END
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