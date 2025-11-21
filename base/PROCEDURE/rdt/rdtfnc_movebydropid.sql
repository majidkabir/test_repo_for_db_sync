SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_MoveByDropID                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: RDT Replenishment                                           */
/*          SOS93812 - Move By Drop ID                                  */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2008-02-27 1.0  jwong    Created                                     */
/* 2008-11-03 1.1  Vicky    Remove XML part of code that is used to     */
/*                          make field invisible and replace with new   */
/*                          code (Vicky02)                              */
/* 2009-07-06 1.2  Vicky    Add in EventLog (Vicky06)                   */
/* 2009-12-30 1.3  ChewKP   SOS#156663 RDT Drop ID change Req -         */
/*                          Additional Check While Scanning (ChewKP01)  */
/* 2009-11-11 1.5  James    SOS152583 - Add Generic printing (james01)  */
/* 2009-11-12 1.6  James    Performance tuning on sku retrieve (james02)*/
/* 2010-05-12 1.7  ChewKP   SOS#172046 [LOREAL] RDT Move By DropID        */
/*                          (ChewKP02)                                  */
/* 2011-05-06 1.8  James    Add Traceinfo (james03)                     */
/* 2011-05-10 1.9  James    Perfomance tuning (james04)                 */
/* 2012-12-18 2.0  James    SOS263772 - Enhance dropid check (james05)  */
/* 2013-04-02 2.1  James    Bug fix (james06)                           */
/* 2009-10-02 2.2  GTGOH	 SOS#149095		 									   */
/*									 Insert new screen to print Carton Label		*/
/* 2014-12-24 2.3  James    Get correct codelkup for lottable (james07) */
/* 2016-09-30 2.4  Ung      Performance tuning                          */
/* 2018-10-23 2.5  Gan      Performance tuning                          */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_MoveByDropID] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

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
   @cPrinter    NVARCHAR( 10),		--SOS#149095
   @cDataWindow NVARCHAR( 50),		--SOS#149095
   @cTargetDB   NVARCHAR( 10),		--SOS#149095
   @cPrintLabel NVARCHAR( 1),		   --SOS#149095


   @cSKU        NVARCHAR( 20),
   @cDescr      NVARCHAR( 40),
   @cPUOM       NVARCHAR( 1), -- Prefer UOM
   @cPUOM_Desc  NVARCHAR( 5),
   @cMUOM_Desc  NVARCHAR( 5),
   @cLottable02 NVARCHAR( 18),
   @cLottable03 NVARCHAR( 18),
   @dLottable04 DATETIME,
   @cC4DropID           CHAR (1), --(ChewKP01) 
   @nFuncStorerConfig   INT,      --(ChewKP01) 
   @n_ConsigneeCount    INT,      --(ChewKP01)
   @c_ToConsignee   NVARCHAR( 15),       --(ChewKP01)
   @c_FromConsignee NVARCHAR( 15),       --(ChewKP01)

   @nPUOM_Div   INT, -- UOM divider

   @nPQTY       INT, -- Preferred UOM QTY
   @nMQTY       INT, -- Master unit QTY
   @nPQTY_Avail INT, -- QTY avail in pref UOM
   @nQTY_Avail  INT, -- QTY available in LOTxLOCXID
   @nMQTY_Avail INT, -- Remaining QTY in master UOM
   @nMQTY_Move  INT, -- Remining QTY to move, in master UOM
   @nQTY_Move   INT, -- QTY to move, in master UOM
   @nPQTY_Move  INT, -- QTY to move, in pref UOM

   @cFromDropID NVARCHAR( 18), -- From DropID
   @cToDropID   NVARCHAR( 18), -- To DropID
   @cMergePlt   NVARCHAR( 1), -- Merge Pallet
   @cLottableLabel02  NVARCHAR( 20), 
   @cLottableLabel03  NVARCHAR( 20), 
   @cLottableLabel04  NVARCHAR( 20), 
   @cSearchLottable02 NVARCHAR( 18), 
   @cSearchLottable03 NVARCHAR( 18), 
   @cSearchLottable04 NVARCHAR( 16), 
   @dSearchLottable04 DATETIME,
   @dZero  DATETIME, 
   @b_success   INT,
   @n_err       INT,
   @c_errmsg    NVARCHAR( 255),
   @cUserName   NVARCHAR(18), -- (Vicky06)
   @nQtyMove_Merge INT, -- (Vicky06)
   @cSKU_Merge NVARCHAR(20), -- (Vicky06)
   @cPackUOM3_Merge NVARCHAR(5), -- (Vicky06)
   @cReportType    NVARCHAR( 10), --(james01)
   @cPrintJobName  NVARCHAR( 50), --(james01)
   
   @c_Orderkey       NVARCHAR( 10), --(ChewKP02)
   @c_Loadkey        NVARCHAR( 10), --(ChewKP02)
   @c_ExternOrderkey NVARCHAR( 20), --(ChewKP02)
   @c_CCompany       NVARCHAR( 45), --(ChewKP02)
   @c_CCompany1      NVARCHAR( 25), --(ChewKP02)
   @c_CCompany2      NVARCHAR( 20), --(ChewKP02)
   @c_Door           NVARCHAR( 50), --(ChewKP02)
   @c_Route          NVARCHAR( 10), --(ChewKP02)
   @c_Stop           NVARCHAR( 10), --(ChewKP02)
	@cLODropID		 NVARCHAR(	 1), --(ChewKP02)
	@c_FromOrderkey   NVARCHAR( 10), --(ChewKP02)
	@c_ToOrderkey	 NVARCHAR( 10), --(ChewKP02)
	@cErrMsg1		 NVARCHAR(255), --(ChewKP02)
	@cErrMsg2		 NVARCHAR(255), --(ChewKP02)
     
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
   @cPrinter    = Printer,			--SOS#149095

   @cSKU        = V_SKU,
   @cDescr      = V_SKUDescr,
   @cPUOM       = V_UOM,
   @cLottableLabel02 = V_LottableLabel02, 
   @cLottableLabel03 = V_LottableLabel03, 
   @cLottableLabel04 = V_LottableLabel04, 
   @cLottable02 = V_Lottable02,
   @cLottable03 = V_Lottable03,
   @dLottable04 = V_Lottable04,
   
   @nPUOM_Div   = V_PUOM_Div,
   @nMQTY       = V_MQTY,
   @nPQTY       = V_PQTY,
   
   @nQTY_Avail     = V_Integer1,
   @nPQTY_Avail    = V_Integer2,
   @nMQTY_Avail    = V_Integer3,
   @nPQTY_Move     = V_Integer4,
   @nMQTY_Move     = V_Integer5,
   @nQTY_Move      = V_Integer6,
   @nQtyMove_Merge = V_Integer7,

   @cFromDropID = V_String1,
   @cToDropID   = V_String2,
   @cMergePlt   = V_String3,
   @cPUOM_Desc  = V_String4,
   @cMUOM_Desc  = V_String5,
  -- @nPUOM_Div   = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6,  5), 0) = 1 THEN LEFT( V_String6,  5) ELSE 0 END,
  -- @nMQTY       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String7,  5), 0) = 1 THEN LEFT( V_String7,  5) ELSE 0 END,
  -- @nPQTY       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String8,  5), 0) = 1 THEN LEFT( V_String8,  5) ELSE 0 END,
  -- @nQTY_Avail  = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String9,  5), 0) = 1 THEN LEFT( V_String9,  5) ELSE 0 END,
  -- @nPQTY_Avail = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String10, 5), 0) = 1 THEN LEFT( V_String10, 5) ELSE 0 END,
  -- @nMQTY_Avail = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String11, 5), 0) = 1 THEN LEFT( V_String11, 5) ELSE 0 END, 
   @cSearchLottable02 = V_String12, 
   @cSearchLottable03 = V_String13, 
   @cSearchLottable04 = V_String14, 
  -- @nPQTY_Move  = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String15, 5), 0) = 1 THEN LEFT( V_String15, 5) ELSE 0 END, -- (Vicky06)
  -- @nMQTY_Move  = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String16, 5), 0) = 1 THEN LEFT( V_String16, 5) ELSE 0 END, -- (Vicky06)
  -- @nQTY_Move   = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String17, 5), 0) = 1 THEN LEFT( V_String17, 5) ELSE 0 END, -- (Vicky06)
   @cPackUOM3_Merge = V_String18, -- (Vicky06)
  -- @nQtyMove_Merge = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String19, 5), 0) = 1 THEN LEFT( V_String19, 5) ELSE 0 END, -- (Vicky06)

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

   -- TraceInfo (james03) Start
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

   SET @c_TraceName = 'rdtfnc_MoveByDropID'
   -- TraceInfo (james03) End

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

SET @dZero = 0 -- 1900-01-01

-- To Make RDTGetConfig Function using Variable for FunctionID (ChewKP01) --
SET @nFuncStorerConfig = 0 -- (ChewKP01)

-- Redirect to respective screen
IF @nFunc = 970 
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 970
   IF @nStep = 1 GOTO Step_1   -- Scn = 1700. From DropID
   IF @nStep = 2 GOTO Step_2   -- Scn = 1701. SKU/UPC
   IF @nStep = 3 GOTO Step_3   -- Scn = 1702. Lottable
   IF @nStep = 4 GOTO Step_4   -- Scn = 1703. Qty AVL/Qty Move
   IF @nStep = 5 GOTO Step_5   -- Scn = 1704. To DropID
   IF @nStep = 6 GOTO Step_6   -- Scn = 1705. To DropID
   IF @nStep = 7 GOTO Step_7   -- Scn = 1706. Messsage
   IF @nStep = 8 GOTO Step_8   -- Scn = 1707. Option
   IF @nStep = 9 GOTO Step_9   -- Scn = 1708. Option	SOS#149095
   
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
   SET @nScn = 1700
   SET @nStep = 1

   -- Init var
   SET @nPQTY = 0

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

     SET @cMUOM_Desc = ''
     SET @nQTY_Move = 0

   -- Prep next screen var
   SET @cFromDropID = ''
   SET @cMergePlt = 1
   SET @cOutField01 = '' -- From DropID
   SET @cOutField02 = '1' -- Merge Pallet
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
   EXEC rdt.rdtSetFocusField @nMobile, 1
END
GOTO Quit

/********************************************************************************
Step 1. Screen = 1700
   FROM DROPID
   (Field01, input)
   Merge Pallet: (Field02, input)
   1 = Yes 2 = No
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFromDropID = @cInField01
      SET @cMergePlt = @cInField02

      -- Validate blank
      IF ISNULL(@cFromDropID, '') = '' 
      BEGIN
         SET @nErrNo = 63861
         SET @cErrMsg = rdt.rdtgetmessage( 63861, @cLangCode, 'DSP') --DropID needed
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END
      
      -- StorerConfig For C4 Validation of Drop ID -- SOS#156663
      SET @cC4DropID = rdt.RDTGetConfig( @nFuncStorerConfig, 'ValidateDropIDC4', @cStorerKey)
      
      IF @cC4DropID = 1 
      BEGIN
         IF CharIndex ('C4',LEFT(RTrim(@cFromDropID),2),1) = 0 OR LEN(RTrim(@cFromDropID)) <> 10 OR 
            ISNUMERIC(RIGHT(RTRIM(@cFromDropID), 8)) <> 1    -- (james05)/(james06)
         BEGIN
            SET @nErrNo = 63888
            SET @cErrMsg = rdt.rdtgetmessage( 63888, @cLangCode, 'DSP') --Invalid DropID
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END
      END  

      -- Validate if dropid exists and have moveable stock
      IF NOT EXISTS (SELECT 1 
         FROM dbo.PICKDETAIL WITH (NOLOCK)
         WHERE DropID = @cFromDropID
            AND Status = '5'
         GROUP BY DropID 
         HAVING SUM(Qty) > 0)
      BEGIN
         SET @nErrNo = 63862
         SET @cErrMsg = rdt.rdtgetmessage( 63862, @cLangCode, 'DSP') --Invalid ID
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- Validate Option if blank
      IF ISNULL(@cMergePlt, '') = '' 
      BEGIN
         SET @nErrNo = 63863
         SET @cErrMsg = rdt.rdtgetmessage( 63863, @cLangCode, 'DSP') --Option needed
         EXEC rdt.rdtSetFocusField @nMobile, 2
         SET @cOutField01 = @cFromDropID
         SET @cOutField02 = '1'
         GOTO Quit
      END

      -- Validate Option
      IF @cMergePlt NOT IN ('1', '2') 
      BEGIN
         SET @nErrNo = 63864
         SET @cErrMsg = rdt.rdtgetmessage( 63864, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtSetFocusField @nMobile, 2
         SET @cOutField01 = @cFromDropID
         SET @cOutField02 = '1'
         GOTO Quit
      END

      IF @cMergePlt = '1' --Go to To DropID screen
      BEGIN
         SET @cOutField01 = @cFromDropID -- From DropID
         SET @cOutField02 = '' -- SKU/UPC
         
         -- (ChewKP02) Start --
         SET @c_Orderkey       = ''
         SET @c_Loadkey        = ''
         SET @c_ExternOrderkey = ''
         SET @c_CCompany       = ''
         SET @c_CCompany1      = ''
         SET @c_CCompany2      = ''
         SET @c_Door           = ''
         SET @c_Route          = ''
         SET @c_Stop           = ''
         
         SELECT 
         @c_Orderkey = Orders.OrderKey, 
         @c_Loadkey = Orders.loadkey, 
         @c_ExternOrderkey = Orders.Externorderkey, 
         @c_CCompany = Orders.C_Company, 
         @c_Door = Orders.Door, 
         @c_Route = Orders.Route, 
         @c_Stop = Orders.Stop 
         FROM ORDERS Orders (NOLOCK)
         INNER JOIN PICKDETAIL PD (NOLOCK) ON PD.ORDERKEY = Orders.ORDERKEY
         WHERE PD.DROPID = @cFromDropID
         
         
         SET @cOutField03  = ISNULL(RTRIM(@c_Orderkey),'')       
         SET @cOutField04  = ISNULL(RTRIM(@c_Loadkey),'')        
         SET @cOutField05  = ISNULL(RTRIM(@c_ExternOrderkey),'') 
         
         SET @c_CCompany1  = SubString(ISNULL(RTRIM(@c_CCompany),''),1,25)
         SET @c_CCompany2  = SubString(ISNULL(RTRIM(@c_CCompany),''),21,20)
         
         SET @cOutField06  = ISNULL(RTRIM(@c_CCompany1),'')       
         SET @cOutField07  = ISNULL(RTRIM(@c_CCompany2),'')      
         SET @cOutField08  = ISNULL(RTRIM(@c_Door),'')           
         SET @cOutField09  = ISNULL(RTRIM(@c_Route),'')          
         SET @cOutField10 = ISNULL(RTRIM(@c_Stop),'')           
         
         -- (ChewKP02) End --
         
         
         

         SET @nScn  = @nScn + 5
         SET @nStep = @nStep + 5
      END
      IF @cMergePlt = '2' -- Go to SKU/UPC screen
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cFromDropID -- From DropID
         SET @cOutField02 = '' -- SKU/UPC

         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1
      END
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
       @cStorerKey  = @cStorerkey,
       @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option


     SET @cMUOM_Desc = ''
     SET @nQTY_Move = 0

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
      SET @cFromDropID = ''
      SET @cOutField01 = ''
      SET @cOutField02 = '1'
   END
END
GOTO Quit


/********************************************************************************
Step 2. Screen 1701
   FROM DROPID: 
   (Field01)
   SKU/UPC:
   (Field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField02

      -- Validate blank
      IF ISNULL(@cSKU, '') = ''
      BEGIN
         SET @nErrNo = 63865
         SET @cErrMsg = rdt.rdtgetmessage( 63865, @cLangCode, 'DSP') --SKU/UPC needed
         GOTO Step_2_Fail
      END

   /*
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
         SET @nErrNo = 63866
         SET @cErrMsg = rdt.rdtgetmessage( 63866, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_2_Fail
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 63867
         SET @cErrMsg = rdt.rdtgetmessage( 63867, @cLangCode, 'DSP') --'SameBarCodeSKU'
         GOTO Step_2_Fail
      END 
*/
      --Performance tuning (james01)
      EXEC [RDT].[rdt_GETSKUCNT]
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cSKU
      ,@nSKUCnt     = @nSKUCnt       OUTPUT
      ,@bSuccess    = @b_Success     OUTPUT
      ,@nErr        = @n_Err         OUTPUT
      ,@cErrMsg     = @c_ErrMsg      OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 63866
         SET @cErrMsg = rdt.rdtgetmessage( 63866, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_2_Fail
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 63867
         SET @cErrMsg = rdt.rdtgetmessage( 63867, @cLangCode, 'DSP') --'SameBarCodeSKU'
         GOTO Step_2_Fail
      END 
      
      EXEC [RDT].[rdt_GETSKU]
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cSKU          OUTPUT
      ,@bSuccess    = @b_Success     OUTPUT
      ,@nErr        = @n_Err         OUTPUT
      ,@cErrMsg     = @c_ErrMsg      OUTPUT

      -- Check if SKU exists with pickdetail
      IF NOT EXISTS (SELECT 1 
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND DropID = @cFromDropID
            AND SKU = @cSKU)
      BEGIN
         SET @nErrNo = 63887
         SET @cErrMsg = rdt.rdtgetmessage( 63887, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_2_Fail
      END
      
      
      SELECT 
         @cDescr = S.Descr, 
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
            END AS INT), 
         @cLottableLabel02 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable02Label AND C.ListName = 'LOTTABLE02' AND C.Code <> '' AND (C.StorerKey = @cStorerKey OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''),  -- (james07)
         @cLottableLabel03 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable03Label AND C.ListName = 'LOTTABLE03' AND C.Code <> '' AND (C.StorerKey = @cStorerKey OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''),  -- (james07)
         @cLottableLabel04 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable04Label AND C.ListName = 'LOTTABLE04' AND C.Code <> '' AND (C.StorerKey = @cStorerKey OR C.Storerkey = '') ORDER By C.StorerKey DESC), '')   -- (james07)
      FROM dbo.SKU S (NOLOCK) 
         INNER JOIN dbo.Pack Pack (nolock) ON (S.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      -- Prep next screen var
      SET @cOutField01 = @cFromDropID -- From DropID
      SET @cOutField02 = @cSKU -- SKU
      SET @cOutField03 = SUBSTRInG(@cDescr, 1, 20)
      SET @cOutField04 = SUBSTRInG(@cDescr, 21, 20)
      SET @cOutField05 = CASE WHEN @cLottableLabel02 = '' THEN 'Lottable02:' ELSE @cLottableLabel02 END
      SET @cOutField06 = ''
      SET @cOutField07 = CASE WHEN @cLottableLabel03 = '' THEN 'Lottable03:' ELSE @cLottableLabel03 END
      SET @cOutField08 = ''
      SET @cOutField09 = CASE WHEN @cLottableLabel04 = '' THEN 'Lottable04:' ELSE @cLottableLabel04 END
      SET @cOutField10 = ''

      -- Go to QTY screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
      
      SET @cOutField01 = ''
      SET @cOutField02 = '1'


     SET @cMUOM_Desc = ''
     SET @nQTY_Move = 0

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

      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cSKU = ''
      SET @cOutField02 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 3. Screen 1702
   FROM DROPID     (Field01)
   SKU             (Field02)
   SKU Desc1       (Field03)
   SKU Desc2       (Field04)
   LottableLabel02 (field05)
   Lottable02      (field06, input)
   LottableLabel03 (field07)
   Lottable03      (field08, input)
   LottableLabel04 (field09)
   Lottable04      (field10, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1      -- Yes OR Send
   BEGIN
      -- Screen mapping
      SELECT
         @cSearchLottable02 = CASE WHEN @cLottableLabel02 = '' THEN '' ELSE @cInField06 END, 
         @cSearchLottable03 = CASE WHEN @cLottableLabel03 = '' THEN '' ELSE @cInField08 END, 
         @cSearchLottable04 = CASE WHEN @cLottableLabel04 = '' THEN '' ELSE @cInField10 END

      -- Validate lottable04
      IF @cSearchLottable04 <> ''
         IF RDT.rdtIsValidDate( @cSearchLottable04) = 0
         BEGIN
            SET @nErrNo = 63868
            SET @cErrMsg = rdt.rdtgetmessage( 63868, @cLangCode, 'DSP') --'Invalid date'
            EXEC rdt.rdtSetFocusField @nMobile, 10 -- Lottable04
            GOTO Step_3_Fail
         END
      SET @dSearchLottable04 = @cSearchLottable04 -- When blank, @dLottable04 = 0
      
      -- Get SKU QTY
      SET @nQTY_Avail = 0 
      SELECT TOP 1
         @cLottable02 = LA.Lottable02, 
         @cLottable03 = LA.Lottable03, 
         @dLottable04 = LA.Lottable04, 
         @nQTY_Avail = SUM( PD.QTY)
      FROM dbo.PickDetail PD WITH (NOLOCK) 
         INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.StorerKey = LA.StorerKey AND PD.Lot = LA.Lot)
      WHERE PD.StorerKey = @cStorerKey
         AND PD.SKU = @cSKU
         AND PD.DropID = @cFromDropID
         AND PD.Status = '5'
         AND LA.Lottable02 = CASE WHEN @cSearchLottable02 = '' THEN LA.Lottable02 ELSE @cSearchLottable02 END
         AND LA.Lottable03 = CASE WHEN @cSearchLottable03 = '' THEN LA.Lottable03 ELSE @cSearchLottable03 END
         -- NULL column cannot be compared, even if SET ANSI_NULLS OFF
         AND IsNULL( LA.Lottable04, 0) = CASE WHEN @dSearchLottable04 = 0 THEN IsNULL( LA.Lottable04, 0) ELSE @dSearchLottable04 END
      GROUP BY LA.Lottable02, LA.Lottable03, LA.Lottable04
      ORDER BY LA.Lottable02, LA.Lottable03, LA.Lottable04

      IF @nQTY_Avail = 0 OR @nQTY_Avail IS NULL
      BEGIN
         SET @nErrNo = 63869
         SET @cErrMsg = rdt.rdtgetmessage( 63869, @cLangCode, 'DSP') --'No QTY to move'
         GOTO Step_4_Fail
      END
      
      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit 
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY_Avail = 0
         SET @nPQTY_Move  = 0
         SET @nMQTY_Avail = @nQTY_Avail -- Bug fix by Vicky on 09-Aug-2007
      END
      ELSE
      BEGIN
         SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
      END

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

      -- Prepare next screen var
      SET @nPQTY_Move = 0
      SET @nMQTY_Move = 0
      SET @cOutField01 = @cSKU
      SET @cOutField02 = CASE WHEN @cLottableLabel02 = '' THEN 'Lottable02:' ELSE @cLottableLabel02 END
      SET @cOutField03 = @cLottable02
      SET @cOutField04 = CASE WHEN @cLottableLabel03 = '' THEN 'Lottable03:' ELSE @cLottableLabel03 END
      SET @cOutField05 = @cLottable03
      SET @cOutField06 = CASE WHEN @cLottableLabel04 = '' THEN 'Lottable04:' ELSE @cLottableLabel04 END
      SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField08 = '' -- @cPUOM_Desc
         SET @cOutField09 = '' -- @nPQTY_Avail
         SET @cOutField10 = '' -- @nPQTY_Move
         SET @cFieldAttr10 = 'O' -- (Vicky02)
         --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field10', 'NULL', 'output', 'NULL', 'NULL', '')
      END
      ELSE
      BEGIN
         SET @cOutField08 = @cPUOM_Desc
         SET @cOutField09 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
         SET @cOutField10 = '' -- @nPQTY_Move
      END
      SET @cOutField11 = @cMUOM_Desc
      SET @cOutField12 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
      SET @cOutField13 = '' -- @nMQTY_Move


      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen
      SET @cSKU = ''
      SET @cOutField01 = @cFromDropID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRInG(@cDescr, 1, 20)
      SET @cOutField04 = SUBSTRInG(@cDescr, 21, 20)
      SET @cOutField05 = CASE WHEN @cLottableLabel02 = '' THEN 'Lottable02:' ELSE @cLottableLabel02 END
      SET @cOutField06 = ''
      SET @cOutField07 = CASE WHEN @cLottableLabel03 = '' THEN 'Lottable03:' ELSE @cLottableLabel03 END
      SET @cOutField08 = ''
      SET @cOutField09 = CASE WHEN @cLottableLabel04 = '' THEN 'Lottable04:' ELSE @cLottableLabel04 END
      SET @cOutField10 = ''

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
      SET @cFieldAttr12 = ''
      -- (Vicky02) - End

    IF @cPUOM_Desc = ''
         -- Pref QTY is always enable (as screen defination). When reach error, it will quit directly and forgot
         -- to disable the Pref QTY field. So centralize disable it here for all fail condition
         -- Disable pref QTY field
         SET @cFieldAttr12 = 'O' -- (Vicky02)
         --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field12', 'NULL', 'output', 'NULL', 'NULL', '')


      SET @cOutField12 = '' -- ActPQTY
      SET @cOutField13 = '' -- ActMQTY
   END
END
GOTO Quit


/********************************************************************************
Step 4. Screen = 1703
   SKU
   (Field01)
   (Field02)
   (Field03)
   (Field04)
   (Field05)
   (Field06)
   (Field07)
   PUOM MUOM  (Field08, Field12)
   QTY AVL    (Field09, Field12)
   QTY MV     (Field10, Field13 input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cPQTY NVARCHAR( 5)
      DECLARE @cMQTY NVARCHAR( 5)

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
      SET @cPQTY = IsNULL( @cInField10, '')
      SET @cMQTY = IsNULL( @cInField13, '')

      -- Retain the key-in value
      SET @cOutField10 = @cInField10 -- Pref QTY
      SET @cOutField13 = @cInField13 -- Master QTY

      -- Blank to iterate lottables
      IF @cPQTY = '' AND @cMQTY = ''
      BEGIN
         DECLARE @cNextSKU NVARCHAR( 20)
         DECLARE @cNextLottable02 NVARCHAR( 18)
         DECLARE @cNextLottable03 NVARCHAR( 18)
         DECLARE @dNextLottable04 DATETIME
         DECLARE @nNextQTY_Avail INT
         DECLARE @cNextPickDetailKey NVARCHAR( 10)

         SET @dSearchLottable04 = @cSearchLottable04 

         -- Get SKU QTY
         SELECT TOP 1
            @cNextSKU = PD.SKU,
            @cNextLottable02 = LA.Lottable02, 
            @cNextLottable03 = LA.Lottable03, 
            @dNextLottable04 = LA.Lottable04, 
            @nNextQTY_Avail = SUM( PD.Qty)
         FROM dbo.PickDetail PD WITH (NOLOCK)
            INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.StorerKey = LA.StorerKey AND PD.LOT = LA.LOT)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.DropID = @cFromDropID
            AND PD.Status = '5'
            AND LA.Lottable02 = CASE WHEN @cSearchLottable02 = '' THEN LA.Lottable02 ELSE @cSearchLottable02 END
            AND LA.Lottable03 = CASE WHEN @cSearchLottable03 = '' THEN LA.Lottable03 ELSE @cSearchLottable03 END
            -- NULL column cannot be compared, even if SET ANSI_NULLS OFF
            AND IsNULL( LA.Lottable04, 0) = CASE WHEN @dSearchLottable04 = 0 THEN IsNULL( LA.Lottable04, 0) ELSE @dSearchLottable04 END
            AND (PD.DropID + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), IsNULL( LA.Lottable04, @dZero), 120)) >
                (@cFromDropID   + @cLottable02  + @cLottable03  + CONVERT( NVARCHAR( 10), IsNULL( @dLottable04,  @dZero), 120))
         GROUP BY PD.SKU, LA.Lottable02, LA.Lottable03, LA.Lottable04
         ORDER BY PD.SKU, LA.Lottable02, LA.Lottable03, LA.Lottable04

         -- Validate if any result
         IF IsNULL( @nNextQTY_Avail, 0) = 0
         BEGIN
            SET @nErrNo = 63870
            SET @cErrMsg = rdt.rdtgetmessage( 63870, @cLangCode, 'DSP') --'No record'
            GOTO Step_4_Fail
         END
         
         -- Set next record values
         SET @cSKU = @cNextSKU
         SET @cLottable02 = @cNextLottable02
         SET @cLottable03 = @cNextLottable03
         SET @dLottable04 = @dNextLottable04
         SET @nQTY_Avail = @nNextQTY_Avail

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit 
            @nPUOM_Div = 0 -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY_Avail = 0
            SET @nPQTY_Move  = 0
            SET @nMQTY_Avail = @nQTY_Avail -- Bug fix by Vicky on 09-Aug-2007
         END
         ELSE
         BEGIN
            SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
         END
   
         -- Prepare next screen var
         SET @nPQTY_Move = 0
         SET @nMQTY_Move = 0
         SET @cOutField01 = @cSKU
         SET @cOutField02 = CASE WHEN @cLottableLabel02 = '' THEN 'Lottable02:' ELSE @cLottableLabel02 END
         SET @cOutField03 = @cLottable02
         SET @cOutField04 = CASE WHEN @cLottableLabel03 = '' THEN 'Lottable03:' ELSE @cLottableLabel03 END
         SET @cOutField05 = @cLottable03
         SET @cOutField06 = CASE WHEN @cLottableLabel04 = '' THEN 'Lottable04:' ELSE @cLottableLabel04 END
         SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)
         IF @cPUOM_Desc = ''
         BEGIN
            SET @cOutField08 = '' -- @cPUOM_Desc
            SET @cOutField09 = '' -- @nPQTY_Avail
            SET @cOutField10 = '' -- @nPQTY_Move
            SET @cFieldAttr10 = 'O' -- (Vicky02)
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field10', 'NULL', 'output', 'NULL', 'NULL', '')
         END
         ELSE
         BEGIN
            SET @cOutField08 = @cPUOM_Desc
            SET @cOutField09 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
            SET @cOutField10 = '' -- @nPQTY_Move
         END
         SET @cOutField11 = @cMUOM_Desc
         SET @cOutField12 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
         SET @cOutField13 = '' -- @nMQTY_Move
         
         -- Remain in current screen
         -- SET @nScn = @nScn + 1
         -- SET @nStep = @nStep + 1
         
         GOTO Quit
      END

      -- Validate PQTY
      IF @cPQTY = '' SET @cPQTY = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 63871
         SET @cErrMsg = rdt.rdtgetmessage( 63871, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY
         GOTO Step_4_Fail
      END
      
      -- Validate MQTY
      IF @cMQTY  = '' SET @cMQTY  = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 63872
         SET @cErrMsg = rdt.rdtgetmessage( 63872, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 11 -- MQTY
         GOTO Step_4_Fail
      END
      
      -- Calc total QTY in master UOM
      SET @nPQTY_Move = CAST( @cPQTY AS INT)
      SET @nMQTY_Move = CAST( @cMQTY AS INT)
      SET @nQTY_Move = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nQTY_Move = @nQTY_Move + @nMQTY_Move

      -- Validate QTY
      IF @nQTY_Move = 0
      BEGIN
         SET @nErrNo = 63873
         SET @cErrMsg = rdt.rdtgetmessage( 63873, @cLangCode, 'DSP') --'QTY needed'
      GOTO Step_4_Fail
      END

      -- Validate QTY to move more than QTY avail
      IF @nQTY_Move > @nQTY_Avail
      BEGIN
         SET @nErrNo = 63874
         SET @cErrMsg = rdt.rdtgetmessage( 63874, @cLangCode, 'DSP') --'QTYAVL NotEnuf'
         GOTO Step_4_Fail
      END

      -- Prepare next screen var
      SET @cOutField01 = @cFromDropID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRInG(@cDescr, 1, 20)
      SET @cOutField04 = SUBSTRInG(@cDescr, 21, 20)
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField05 = '' -- @cPUOM_Desc
         SET @cOutField06 = '' -- @nPQTY_Move
         SET @cFieldAttr06 = 'O' -- (Vicky02)
         --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field06', 'NULL', 'output', 'NULL', 'NULL', '')
      END
      ELSE
      BEGIN
         SET @cOutField05 = @cPUOM_Desc
         SET @cOutField06 = CAST( @nPQTY_Move AS NVARCHAR( 5))
      END
      SET @cOutField07 = @cMUOM_Desc
      SET @cOutField08 = CAST( @nMQTY_Move AS NVARCHAR( 5))
      SET @cOutField09 = '' -- To DropID

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep prev screen var
      SET @cOutField01 = @cFromDropID -- From DropID
      SET @cOutField02 = @cSKU -- SKU
      SET @cOutField03 = SUBSTRInG(@cDescr, 1, 20)
      SET @cOutField04 = SUBSTRInG(@cDescr, 21, 20)
      SET @cOutField05 = CASE WHEN @cLottableLabel02 = '' THEN 'Lottable02:' ELSE @cLottableLabel02 END
      SET @cOutField06 = ''
      SET @cOutField07 = CASE WHEN @cLottableLabel03 = '' THEN 'Lottable03:' ELSE @cLottableLabel03 END
      SET @cOutField08 = ''
      SET @cOutField09 = CASE WHEN @cLottableLabel04 = '' THEN 'Lottable04:' ELSE @cLottableLabel04 END
      SET @cOutField10 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 4
      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      -- (Vicky02) - Start
      SET @cFieldAttr10 = ''
      -- (Vicky02) - End

      IF @cPUOM_Desc = ''
         -- Pref QTY is always enable (as screen defination). When reach error, it will quit directly and forgot
         -- to disable the Pref QTY field. So centralize disable it here for all fail condition
         -- Disable pref QTY field
         SET @cFieldAttr10 = 'O' -- (Vicky02)
         --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field10', 'NULL', 'output', 'NULL', 'NULL', '')

      SET @cOutField10 = '' -- PQTY
      SET @cOutField13 = '' -- MQTY
   END
END
GOTO Quit


/********************************************************************************
Step 5. Screen = 1704
   FROM DROPID:
   (Field01)
   SKU:
   (Field02)
   (Field03)
   (Field04)
   PUOM MUOM  (Field05, Field07)
   QTY MV     (Field06, Field08)
   To DROPID:
   (Field09, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToDropID = @cInField09

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
      IF ISNULL(@cToDropID, '') = ''
      BEGIN
         SET @nErrNo = 63875
         SET @cErrMsg = rdt.rdtgetmessage( 63875, @cLangCode, 'DSP') --Invalid ID
         GOTO Step_5_Fail
      END
      
      -- StorerConfig For C4 Validation of Drop ID -- SOS#156663
      SET @cC4DropID = rdt.RDTGetConfig( @nFuncStorerConfig, 'ValidateDropIDC4', @cStorerKey)
      
      IF @cC4DropID = 1 
      BEGIN
            SET @d_step1 = GETDATE() -- (james03)
            IF CharIndex ('C4',LEFT(RTrim(@cFromDropID),2),1) = 0 OR LEN(RTrim(@cFromDropID)) <> 10 OR 
               ISNUMERIC(RIGHT(RTRIM(@cFromDropID), 8)) <> 1    -- (james05)/(james06)
            BEGIN
               SET @nErrNo = 63888
               SET @cErrMsg = rdt.rdtgetmessage( 63888, @cLangCode, 'DSP') --Invalid DropID
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Step_5_Fail
            END
            SET @d_step1 = GETDATE() - @d_step1 -- (james03)

            SET @d_step2 = GETDATE() -- (james03)            
            IF CharIndex ('C4',LEFT(RTrim(@cToDropID),2),1) = 0 OR LEN(RTrim(@cToDropID)) <> 10  
            BEGIN
               SET @nErrNo = 63891
               SET @cErrMsg = rdt.rdtgetmessage( 63891, @cLangCode, 'DSP') --Invalid DropID
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Step_5_Fail
            END
            SET @d_step2 = GETDATE() - @d_step2 -- (james03)


            IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND DropID = @cToDropID)
            BEGIN                    
            SET @d_step3 = GETDATE() -- (james03)            
            SELECT TOP 1 @c_FromConsignee = Consigneekey FROM dbo.PickDetail PD WITH (NOLOCK)	-- (james04)
                  INNER JOIN dbo.Orders Orders WITH (NOLOCK)
                  ON PD.Orderkey = Orders.Orderkey
                  WHERE DropID = @cFromDropID AND Orders.Storerkey = @cStorerKey
            SET @d_step3 = GETDATE() - @d_step3 -- (james03)                        

            SET @d_step4 = GETDATE() -- (james03)            
            SELECT TOP 1 @c_ToConsignee = Consigneekey FROM dbo.PickDetail PD WITH (NOLOCK)	-- (james04)
                  INNER JOIN dbo.Orders Orders WITH (NOLOCK)
                  ON PD.Orderkey = Orders.Orderkey
                  WHERE DropID = @cToDropID AND Orders.Storerkey = @cStorerKey      
            SET @d_step4 = GETDATE() - @d_step4 -- (james03)                  

            IF ISNULL(@c_FromConsignee, '') <> ISNULL(@c_ToConsignee, '')
            BEGIN
               SET @nErrNo = 63890
               SET @cErrMsg = rdt.rdtgetmessage( 63890, @cLangCode, 'DSP') --Wrong Consignee
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Step_5_Fail
            END
         END 
      END  
        

      -- Validate if From DropID = To DropID
      IF @cFromDropID = @cToDropID
      BEGIN
         SET @nErrNo = 63876
         SET @cErrMsg = rdt.rdtgetmessage( 63876, @cLangCode, 'DSP') --Invalid ID
         GOTO Step_5_Fail
      END
      
      SET @d_step5 = GETDATE() -- (james03)            
      -- Check if To DropID exists within same storer
      IF EXISTS(SELECT 1 
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND DropID = @cToDropID)
      BEGIN
         EXECUTE rdt.rdt_MoveByDropID 
            @cFromDropID,
            @cToDropID,
            @nQTY_Move,
            @cStorerKey,
            @cSKU, 
            @cLottable02,
            @cLottable03,
            @dLottable04,
            @cLangCode,
            @nErrNo OUTPUT, 
            @cErrMsg OUTPUT  -- screen limitation, 20 char max
         
            IF @nErrNo <> 0
            BEGIN
               GOTO Step_5_Fail
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
                 @cID           = @cFromDropID,
                 @cToID         = @cToDropID, 
                 @cSKU          = @cSKU,
                 @cUOM          = @cMUOM_Desc,
                 @nQTY          = @nQTY_Move,
                 @cLottable02   = @cLottable02,
                 @cLottable03   = @cLottable03,
                 @dLottable04   = @dLottable04,
                 @nStep         = @nStep                   
            END
            SET @d_step5 = GETDATE() - @d_step5 -- (james03)                  
      END
      ELSE -- DropID not exists
      BEGIN
         SET @cOutField01 = ''

         -- Go to option screen
         SET @nScn  = @nScn + 3
         SET @nStep = @nStep + 3

         GOTO Quit         
      END

      -- Go to message screen
      SET @nScn  = @nScn + 2
      SET @nStep = @nStep + 2

      -- Trace Info (james03) - Start
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
       -- Trace Info (james03) - End

      GOTO Quit
   END

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
      SET @cOutField02 = CASE WHEN @cLottableLabel02 = '' THEN 'Lottable02:' ELSE @cLottableLabel02 END
      SET @cOutField03 = @cLottable02
      SET @cOutField04 = CASE WHEN @cLottableLabel03 = '' THEN 'Lottable03:' ELSE @cLottableLabel03 END
      SET @cOutField05 = @cLottable03
      SET @cOutField06 = CASE WHEN @cLottableLabel04 = '' THEN 'Lottable04:' ELSE @cLottableLabel04 END
      SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField08 = '' -- @cPUOM_Desc
         SET @cOutField09 = '' -- @nPQTY_Avail
         SET @cOutField10 = '' -- @nPQTY_Move
         SET @cFieldAttr10 = 'O' -- (Vicky02)
         --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field10', 'NULL', 'output', 'NULL', 'NULL', '')
      END
      ELSE
      BEGIN
         SET @cOutField08 = @cPUOM_Desc
         SET @cOutField09 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
         SET @cOutField10 = '' -- @nPQTY_Move
      END
      SET @cOutField11 = @cMUOM_Desc
      SET @cOutField12 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
      SET @cOutField13 = '' -- @nMQTY_Move
      
      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cToDropID = ''
      SET @cOutField09 = '' -- To DropID
   END
END
GOTO Quit


/********************************************************************************
Step 6. Screen = 1705
   FROM DROPID:
   (Field01)
	Orderkey: Field03
	Field04 (Loadkey)   
   Field05 (xternOrderkey)
   Field06 (CCompany1)
   Field07 (CCompany2)      
   Field08 (Door)           
   Field09 (Route)          
   Field10 (Stop)           
   TO DROPID:
   (Field02, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToDropID = @cInField02

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
      IF ISNULL(@cToDropID, '') = ''
      BEGIN
         SET @nErrNo = 63877
         SET @cErrMsg = rdt.rdtgetmessage( 63877, @cLangCode, 'DSP') --Invalid ID
         GOTO Step_6_Fail
      END
      

		-- StorerConfig For LO Validation of Drop ID -- SOS#172046
		SET @cLODropID = rdt.RDTGetConfig( @nFuncStorerConfig, 'DropIDNotAllowMixOrderkey', @cStorerKey)
		
		IF @cLODropID  = 1
		BEGIN
			
			SELECT TOP 1 @c_FromOrderkey = Orderkey FROM dbo.PickDetail (NOLOCK)
			WHERE DropID = @cFromDropID

			SELECT TOP 1 @c_ToOrderkey = Orderkey FROM dbo.PickDetail (NOLOCK)
			WHERE DropID = @cToDropID
			
	
			IF ISNULL(RTRIM(@c_ToOrderkey),'') <> ''
			BEGIN
				IF ISNULL(RTRIM(@c_FromOrderkey),'') <> ISNULL(RTRIM(@c_ToOrderkey),'')
				BEGIN
					SET @nErrNo = 0
					
					SET @cErrMsg1 = '63894 Mix orderkey'
					SET @cErrMsg2 = 'not allowed!'
					EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
						  @cErrMsg1, @cErrMsg2

					IF @nErrNo = 1
					BEGIN
						SET @cErrMsg1 = ''
						SET @cErrMsg2 = ''
					END
					GOTO QUIT

				END
			END
			
			
		END
		
		
      -- StorerConfig For C4 Validation of Drop ID -- SOS#156663
      SET @cC4DropID = rdt.RDTGetConfig( @nFuncStorerConfig, 'ValidateDropIDC4', @cStorerKey)
      
      IF @cC4DropID = 1 
      BEGIN
            
            IF CharIndex ('C4',LEFT(RTrim(@cFromDropID),2),1) = 0 OR LEN(RTrim(@cFromDropID)) <> 10 OR 
               ISNUMERIC(RIGHT(RTRIM(@cFromDropID), 8)) <> 1    -- (james05)/(james06)
            BEGIN
               SET @nErrNo = 63892
               SET @cErrMsg = rdt.rdtgetmessage( 63892, @cLangCode, 'DSP') --Invalid DropID
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Step_6_Fail
            END
            
            IF CharIndex ('C4',LEFT(RTrim(@cToDropID),2),1) = 0 OR LEN(RTrim(@cToDropID)) <> 10  
            BEGIN
               SET @nErrNo = 63893
               SET @cErrMsg = rdt.rdtgetmessage( 63893, @cLangCode, 'DSP') --Invalid DropID
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Step_6_Fail
            END
            
             IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND DropID = @cToDropID)
            BEGIN    
                  
                  SELECT TOP 1 @c_FromConsignee = Consigneekey FROM dbo.PickDetail PD WITH (NOLOCK)	-- (james04)
                        INNER JOIN dbo.Orders Orders WITH (NOLOCK)
                        ON PD.Orderkey = Orders.Orderkey
                        WHERE DropID = @cFromDropID AND Orders.Storerkey = @cStorerKey
                        
                  SELECT TOP 1 @c_ToConsignee = Consigneekey FROM dbo.PickDetail PD WITH (NOLOCK)		-- (james04)
                        INNER JOIN dbo.Orders Orders WITH (NOLOCK)
                        ON PD.Orderkey = Orders.Orderkey
                        WHERE DropID = @cToDropID AND Orders.Storerkey = @cStorerKey      
                        
                  IF ISNULL(@c_ToConsignee, '') <> ''
   BEGIN
                     IF ISNULL(@c_FromConsignee, '') <> ISNULL(@c_ToConsignee, '')
                     BEGIN
                        SET @nErrNo = 63889
                        SET @cErrMsg = rdt.rdtgetmessage( 63889, @cLangCode, 'DSP') --Wrong Consignee
                        EXEC rdt.rdtSetFocusField @nMobile, 1
                        GOTO Step_5_Fail
                     END
                  END
           END
      END  
         
      -- Validate if From DropID = To DropID
      IF @cFromDropID = @cToDropID
      BEGIN
         SET @nErrNo = 63878
         SET @cErrMsg = rdt.rdtgetmessage( 63878, @cLangCode, 'DSP') --Invalid ID
         GOTO Step_6_Fail
      END

      -- (Vicky06) - Start
      SELECT @nQtyMove_Merge = SUM(QTY)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.StorerKey = @cStorerKey
      AND PD.DropID = @cFromDropID
      AND PD.Status = '5'
      GROUP BY PD.StorerKey, PD.DropID

      SELECT TOP 1 @cSKU_Merge = SKU
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.StorerKey = @cStorerKey
      AND PD.DropID = @cFromDropID
      AND PD.Status = '5'

      SELECT @cPackUOM3_Merge = PACK.PACKUOM3
      FROM dbo.PACK PACK WITH (NOLOCK)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
      WHERE SKU.Storerkey = @cStorerKey
      AND   SKU.SKU = @cSKU_Merge
      -- (Vicky06) - End

      -- Check if To DropID exists within same storer
      IF EXISTS(SELECT 1 
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND DropID = @cToDropID)
      BEGIN
         EXECUTE rdt.rdt_MoveByDropID 
            @cFromDropID,
            @cToDropID,
            0,
            @cStorerKey,
            '', 
            '',
            '',
            0,
            @cLangCode,
            @nErrNo OUTPUT, 
            @cErrMsg OUTPUT  -- screen limitation, 20 char max
         
            IF @nErrNo <> 0
            BEGIN
               GOTO Step_6_Fail
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
                 @cID           = @cFromDropID,
                 @cToID         = @cToDropID, 
                 @cUOM          = @cPackUOM3_Merge,
                 @nQTY          = @nQtyMove_Merge,
                 @nStep         = @nStep
            END
      END
      ELSE -- DropID not exists
      BEGIN
         SET @cOutField01 = ''

         -- Go to option screen
         SET @nScn  = @nScn + 2
         SET @nStep = @nStep + 2

         GOTO Quit         
      END

      -- Go to message screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1

      GOTO Quit
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep prev screen var
      SET @cOutField01 = '' -- From DropID
      SET @cOutField02 = '1' -- Merge Pallet

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
      SET @nScn  = @nScn - 5
      SET @nStep = @nStep - 5
   END
   GOTO Quit

   Step_6_Fail:
   BEGIN
      SET @cToDropID = ''
      SET @cOutField01 = @cFromDropID -- From DropID
      SET @cOutField02 = '' -- To DropID
   END
END
GOTO Quit

/********************************************************************************
Step 7. Screen = 1706
   Message
********************************************************************************/
Step_7:
BEGIN
	-- SOS#149095 Start
	SET @cPrintLabel = ''
	SET @cPrintLabel = rdt.RDTGetConfig( @nFunc, 'PrintMoveLabel', @cStorerKey) 
	
	IF @cPrintLabel <> '1'
   BEGIN 
	-- SOS#149095 End
	
		IF @cMergePlt = '1'
		BEGIN
			SET @cOutField01 = '' -- From DropID
			SET @cOutField02 = '1' -- Merge Pallet
			SET @cFromDropID = ''
			SET @cMergePlt = ''    
	 
			SET @cMUOM_Desc = ''
			SET @nQTY_Move = 0

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
	     
			EXEC rdt.rdtSetFocusField @nMobile, 1

			-- Go to From DropID screen
			SET @nScn  = @nScn - 6
			SET @nStep = @nStep - 6
		END
		ELSE
		IF @cMergePlt = '2'
		BEGIN
			-- Prep SKU/UPC screen
			SET @cOutField01 = @cFromDropID -- From DropID
			SET @cOutField02 = '' -- SKU/UPCD
			SET @cSKU = ''

			SET @cMUOM_Desc = ''
			SET @nQTY_Move = 0

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

			EXEC rdt.rdtSetFocusField @nMobile, 2

			-- Go to sku/upc screen
			SET @nScn  = @nScn - 5
			SET @nStep = @nStep - 5
		END
		GOTO Quit
	END 
	
	-- SOS#149095 Start
	ELSE
	BEGIN 
		IF @cMergePlt = '1'
		BEGIN

			SET @cOutField01 = '1'	-- Print label option
			SET @cOutField02 = '' 
			SET @cFromDropID = ''

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
	     
			EXEC rdt.rdtSetFocusField @nMobile, 1

		END
		ELSE
		IF @cMergePlt = '2'
		BEGIN
			-- Prep SKU/UPC screen
			SET @cOutField01 = ''
			SET @cOutField02 = '' -- SKU/UPCD
			SET @cSKU = ''

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
	
			EXEC rdt.rdtSetFocusField @nMobile, 2

		END

		IF @nInputKey = 0 -- ESC
		BEGIN
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

			IF @cMergePlt = '1'
			BEGIN
				SET @cOutField01 = '' -- From DropID		
				SET @cOutField02 = '1' -- Merge Pallet
				SET @cFromDropID = ''
				SET @cMergePlt = ''	
		  
				EXEC rdt.rdtSetFocusField @nMobile, 1

				-- Go to From DropID screen
				SET @nScn  = @nScn - 6
				SET @nStep = @nStep - 6
				GOTO Quit
			END
			ELSE
			IF @cMergePlt = '2'
			BEGIN
				-- Prep SKU/UPC screen
				SET @cOutField01 = @cFromDropID -- From DropID
				SET @cOutField02 = '' -- SKU/UPCD
				SET @cSKU = ''

				EXEC rdt.rdtSetFocusField @nMobile, 2

				-- Go to sku/upc screen
				SET @nScn  = @nScn - 5
				SET @nStep = @nStep - 5
				GOTO Quit

			END
		END
	END
END

SET @nScn  = @nScn + 2
SET @nStep = @nStep + 2
GOTO Quit
-- SOS#149095 End

/********************************************************************************
Step 8. Screen = 1707
   Option (Field01, input)
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cOption NVARCHAR( 1)

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
      SET @cOption = @cInField01
      
      -- Validate blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 63880
         SET @cErrMsg = rdt.rdtgetmessage( 63880, @cLangCode, 'DSP') --Option needed
         GOTO Step_5_Fail
      END

      -- Validate option
      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 63881
         SET @cErrMsg = rdt.rdtgetmessage( 63881, @cLangCode, 'DSP') --Invalid option
         GOTO Step_5_Fail
      END

      IF @cOption = '1' -- YES
      BEGIN
         IF @cMergePlt = '1'
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg = ''
            EXECUTE rdt.rdt_MoveByDropID 
               @cFromDropID,
               @cToDropID,
               0,
               @cStorerKey,
               '', 
               '',
               '',
               0,
               @cLangCode,
               @nErrNo OUTPUT, 
               @cErrMsg OUTPUT  -- screen limitation, 20 char max

            IF @nErrNo <> 0
            BEGIN
               GOTO Step_8_Fail
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
                 @cID           = @cFromDropID,
                 @cToID         = @cToDropID, 
                 @cUOM          = @cPackUOM3_Merge,
                 @nQTY          = @nQtyMove_Merge,
                 @nStep         = @nStep
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg = ''

            EXECUTE rdt.rdt_MoveByDropID 
               @cFromDropID,
               @cToDropID,
               @nQTY_Move,
               @cStorerKey,
               @cSKU, 
               @cLottable02,
               @cLottable03,
               @dLottable04,
               @cLangCode,
               @nErrNo OUTPUT, 
               @cErrMsg OUTPUT  -- screen limitation, 20 char max
         
            IF @nErrNo <> 0
            BEGIN
               GOTO Step_8_Fail
            END
            ELSE
            BEGIN
              -- (Vicky06) EventLog - QTY
              EXEC RDT.rdt_STD_EventLog
                 @cActionType   = '4', -- Move
                 @cUserID       = @cUserName,
                 @nMobileNo     = @nMobile,
                 @nFunctionID = @nFunc,
                 @cFacility     = @cFacility,
                 @cStorerKey    = @cStorerkey,
                 @cID           = @cFromDropID,
                 @cToID         = @cToDropID, 
                 @cSKU          = @cSKU,
                 @cUOM          = @cMUOM_Desc,
                 @nQTY          = @nQTY_Move,
                 @cLottable02   = @cLottable02,
                 @cLottable03   = @cLottable03,
                 @dLottable04   = @dLottable04,
                 @nStep         = @nStep
            END
         END
         -- Go to message screen
         SET @nScn  = @nScn - 1 
         SET @nStep = @nStep - 1
         
         GOTO Quit
      END
   END

   IF @cMergePlt = '1'      
   BEGIN
      SET @cOutField01 = @cFromDropID
      SET @cOutField02 = ''

      SET @nScn  = @nScn - 2
      SET @nStep = @nStep - 2
   END
   ELSE
   BEGIN
      SET @cOutField01 = @cFromDropID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRInG(@cDescr, 1, 20)
      SET @cOutField04 = SUBSTRInG(@cDescr, 21, 20)
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField05 = '' -- @cPUOM_Desc
         SET @cOutField06 = '' -- @nPQTY_Move
         SET @cFieldAttr06 = 'O' -- (Vicky02)
         --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field06', 'NULL', 'output', 'NULL', 'NULL', '')
      END
      ELSE
      BEGIN
         SET @cOutField05 = @cPUOM_Desc
         SET @cOutField06 = CAST( @nPQTY_Move AS NVARCHAR( 5))
      END
      SET @cOutField07 = @cMUOM_Desc
      SET @cOutField08 = CAST( @nMQTY_Move AS NVARCHAR( 5))
      SET @cOutField09 = '' -- To DropID

      SET @nScn  = @nScn - 3
      SET @nStep = @nStep - 3
   END      
   GOTO Quit

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

      IF @cMergePlt = '1'      
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField02 = '1'   

         SET @nScn  = @nScn - 2
         SET @nStep = @nStep - 2
      END
      ELSE
      BEGIN
         SET @cOutField01 = @cFromDropID
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRInG(@cDescr, 1, 20)
         SET @cOutField04 = SUBSTRInG(@cDescr, 21, 20)
         IF @cPUOM_Desc = ''
         BEGIN
            SET @cOutField05 = '' -- @cPUOM_Desc
            SET @cOutField06 = '' -- @nPQTY_Move
            SET @cFieldAttr06 = 'O' -- (Vicky02)
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field06', 'NULL', 'output', 'NULL', 'NULL', '')
         END
         ELSE
         BEGIN
            SET @cOutField05 = @cPUOM_Desc
            SET @cOutField06 = CAST( @nPQTY_Move AS NVARCHAR( 5))
         END
         SET @cOutField07 = @cMUOM_Desc
         SET @cOutField08 = CAST( @nMQTY_Move AS NVARCHAR( 5))
         SET @cOutField09 = '' -- To DropID

         SET @nScn  = @nScn - 3
         SET @nStep = @nStep - 3
      END      
   END
   GOTO Quit

   Step_8_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit

-- SOS#149095 Start
/********************************************************************************
Step 9. Screen = 1708
   Option (Field01, input)
********************************************************************************/
Step_9:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cPrtOpt NVARCHAR( 1)

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

      -- Screen mapping
      SET @cPrtOpt = @cInField01
      
      -- Validate blank
      IF @cPrtOpt = '' OR @cPrtOpt IS NULL
      BEGIN
         SET @nErrNo = 67891
         SET @cErrMsg = rdt.rdtgetmessage( 67891, @cLangCode, 'DSP') --Option needed
         GOTO Step_9_Fail
      END

      -- Validate option
      IF @cPrtOpt <> '1' AND @cPrtOpt <> '2'
      BEGIN
         SET @nErrNo = 67892
         SET @cErrMsg = rdt.rdtgetmessage( 67892, @cLangCode, 'DSP') --Invalid option
         GOTO Step_9_Fail
      END

      -- Validate printer setup
      IF @cPrtOpt = '1' -- YES
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg = ''

  			IF ISNULL(@cPrinter, '') = ''
			BEGIN			
				SET @nErrNo = 67893
				SET @cErrMsg = rdt.rdtgetmessage( 67893, @cLangCode, 'DSP') --NoLoginPrinter
				GOTO Step_9_Fail
			END

         SET @cReportType = 'DROPIDLBL'
         SET @cPrintJobName = 'PRINT_MOVEDROPIDPALLET'

			SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
					 @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
			FROM RDT.RDTReport WITH (NOLOCK) 
				WHERE StorerKey = @cStorerKey
				AND ReportType = @cReportType
		
			IF ISNULL(@cDataWindow, '') = ''
			BEGIN
				SET @nErrNo = 67894
				SET @cErrMsg = rdt.rdtgetmessage( 67894, @cLangCode, 'DSP') --DWNOTSetup
				GOTO Step_9_Fail
			END

			IF ISNULL(@cTargetDB, '') = ''
			BEGIN
				SET @nErrNo = 67895
				SET @cErrMsg = rdt.rdtgetmessage( 67895, @cLangCode, 'DSP') --TgetDB Not Set
				GOTO Step_9_Fail
			END

			BEGIN TRAN

         --(james01)
         SET @nErrNo = 0
         EXEC RDT.rdt_BuiltPrintJob 
            @nMobile,
            @cStorerKey,
            @cReportType,
            @cPrintJobName,
            @cDataWindow,
            @cPrinter,
            @cTargetDB,
            @cLangCode,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT

			-- Call printing spooler
--			INSERT INTO RDT.RDTPrintJob
--					(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Parm3, Printer, NoOfCopy, Mobile, TargetDB)
--			VALUES('PRINT_MOVEDROPIDPALLET', 'DROPIDLBL', '0', @cDataWindow, 3, ' ', ' ', @cToDropID, @cPrinter, 1, @nMobile, @cTargetDB)

         --(james01)
			IF @nErrNo <> 0
			BEGIN
				ROLLBACK TRAN

				SET @nErrNo = 67896
				SET @cErrMsg = rdt.rdtgetmessage( 67896, @cLangCode, 'DSP') --'InsertPRTFail'
				GOTO Step_9_Fail
			END

			COMMIT TRAN
		END
   END

   IF @cMergePlt = '1'      
   BEGIN
		SET @cOutField01 = '' -- From DropID		
      SET @cOutField02 = '1' -- Merge Pallet
      SET @cFromDropID = ''
      SET @cMergePlt = ''   

      SET @nScn  = @nScn - 8
      SET @nStep = @nStep - 8

   END
   ELSE
   BEGIN
      SET @cOutField01 = @cFromDropID -- From DropID
      SET @cOutField02 = '' -- SKU/UPCD
      SET @cSKU = ''

      SET @nScn  = @nScn - 7
      SET @nStep = @nStep - 7
   END      
   GOTO Quit


   IF @nInputKey = 0 -- ESC
   BEGIN
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

		IF @cMergePlt = '1'
		BEGIN
			SET @cOutField01 = '' -- From DropID		
			SET @cOutField02 = '1' -- Merge Pallet
			SET @cFromDropID = ''
			SET @cMergePlt = ''	

			EXEC rdt.rdtSetFocusField @nMobile, 1

			SET @nScn  = @nScn - 8
			SET @nStep = @nStep - 8
		END
		ELSE
		IF @cMergePlt = '2'
		BEGIN
		-- Prep SKU/UPC screen
			SET @cOutField01 = @cFromDropID -- From DropID
			SET @cOutField02 = '' -- SKU/UPCD
			SET @cSKU = ''

			EXEC rdt.rdtSetFocusField @nMobile, 2

			SET @nScn  = @nScn - 7
			SET @nStep = @nStep - 7

		END   
   END
   GOTO Quit

   Step_9_Fail:
   BEGIN
      SET @cPrtOpt = ''
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
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg, 
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility, 
      -- UserName  = @cUserName,-- (Vicky06)

      V_SKU     = @cSKU,
      V_SKUDescr= @cDescr,
      V_UOM     = @cPUOM,
      V_Lottable02 = @cLottable02,
      V_Lottable03 = @cLottable03,
      V_Lottable04 = @dLottable04,
      V_LottableLabel02 = @cLottableLabel02, 
      V_LottableLabel03 = @cLottableLabel03, 
      V_LottableLabel04 = @cLottableLabel04, 
      
      V_PUOM_Div = @nPUOM_Div,
      V_MQTY     = @nMQTY,
      V_PQTY     = @nPQTY,
      
      V_Integer1 = @nQTY_Avail,
      V_Integer2 = @nPQTY_Avail,
      V_Integer3 = @nMQTY_Avail,
      V_Integer4 = @nPQTY_Move,
      V_Integer5 = @nMQTY_Move,
      V_Integer6 = @nQTY_Move,
      V_Integer7 = @nQtyMove_Merge,
      
      V_String1 = @cFromDropID,
      V_String2 = @cToDropID, 
      V_String3 = @cMergePlt,
      V_String4 = @cPUOM_Desc,
      V_String5 = @cMUOM_Desc,
      --V_String6 = @nPUOM_Div,
      --V_String7 = @nMQTY,
      --V_String8 = @nPQTY,
      --V_String9 = @nQTY_Avail, 
      --V_String10 = @nPQTY_Avail, 
      --V_String11 = @nMQTY_Avail, 
      V_String12 = @cSearchLottable02, 
      V_String13 = @cSearchLottable03, 
      V_String14 = @cSearchLottable04, 
      --V_String15 = @nPQTY_Move, 
      --V_String16 = @nMQTY_Move, 
      --V_String17 = @nQTY_Move, 
      V_String18 = @cPackUOM3_Merge, -- (Vicky06)
      --V_String19 = @nQtyMove_Merge,-- (Vicky06)

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
--         CASE WHEN @cFieldID IS NULL THEN '' ELSE 'ID="'      + @cFieldID + '" ' END +
--                CASE WHEN @cDefault IS NULL THEN '' ELSE 'Default="' + @cDefault + '" ' END +
--                CASE WHEN @cValue   IS NULL THEN '' ELSE 'Value="'   + @cValue   + '" ' END +
--                CASE WHEN @cNewID   IS NULL THEN '' ELSE 'NewID="'   + @cNewID   + '" ' END +
--             '/>'
--          FETCH NEXT FROM @curScreen INTO @cTyp, @cX, @cY, @cLength, @cFieldID, @cDefault, @cValue, @cNewID
--       END
--       CLOSE @curScreen
--  DEALLOCATE @curScreen
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