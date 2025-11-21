SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Copyright: Maersk                                                    */
/* Purpose: UCC Replenishment To (Dynamic Pick)	   					      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2007-10-17 1.0  FKLIM      Created                                   */
/* 2013-07-09 1.1  ChewKP     SOS#281897 - TBL Enhancement (ChewKP01)   */
/* 2015-07-24 1.2  ChewKP     SOS#348582 - Enhancement on               */
/*                            DynamicPickAutoDefaultDPLOC (ChewKP02)    */
/* 2016-09-30 1.3  Ung        Performance tuning                        */
/* 2018-11-01 1.4  Gan        Performance tuning                        */
/* 2019-10-09 1.5  Chermaine  WMS-10777 Add EventLog                    */
/* 2023-05-31 1.6  James      WMS-22615 Add UCCWithMultiSKU (james01)   */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_DynamicPick_UCCReplenTo] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF  

-- Misc variable
DECLARE 
   @cOption     NVARCHAR(1),
   @nCount      INT,
   @nRowCount   INT

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

   @nKeyCount  INT,
   @nError     INT,
   @i          INT,
   @b_success  INT,
   @n_err      INT,  
   @cSKU       NVARCHAR( 20),   
   @c_errmsg   NVARCHAR( 250), 
   @cUCC       NVARCHAR( 20),
   @cLot       NVARCHAR( 10),
   @cToLoc     NVARCHAR( 10),
   @cToLoc2    NVARCHAR( 10),
   @cReplenKey NVARCHAR( 10),
   @c_OrderKey NVARCHAR( 10),
   @c_UOM      NVARCHAR( 10),
   @c_PackKey  NVARCHAR( 10),
   @c_WaveKey  NVARCHAR( 10),
   @c_SPName   NVARCHAR( 20),
   @cFromLoc    NVARCHAR( 10),
   @cFromID     NVARCHAR( 18),
   @cLottable02 NVARCHAR( 18),
   @cLottable03 NVARCHAR( 18),
   @dLottable04 DATETIME,
   @c_PickDetailKey    NVARCHAR( 10),
   @c_PickHeaderKey    NVARCHAR( 10),
   @c_OrderLineNo      NVARCHAR( 5),
   @cRetrieveDynamicPickslipNo NVARCHAR( 30),
   @cDynamicPickAllocateInPPLOC  NVARCHAR( 1),
   @cDynamicPickAutoDefaultDPLOC NVARCHAR( 1),
   @cUserName   NVARCHAR( 15),  -- (cc01)  

   @nReplenQty         INT, -- Replenishment.QTY
   @nQTY               INT,
   @nReplenDiffLoc     INT,
   @n_OrdAvailQTY      INT,
   @n_UOMQTY           INT,
   @cPickDetailKey     NVARCHAR(10), -- (ChewKP01)
   @cLottable01        NVARCHAR(18), -- (ChewKP01)
   @cExtendedValidateSP NVARCHAR(20) , -- (ChewKP01)
   @cExecStatements    NVARCHAR(4000), -- (ChewKP01)
   @cExecArguments     NVARCHAR(4000), -- (ChewKP01)
   @nUCC_RowRef        INT,
   @tExtValidateData       VariableTable,

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

   DECLARE @cSQLStatement   NVARCHAR(2000), 
           @cSQLParms       NVARCHAR(2000)

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
   @cUserName  = UserName, --(cc01)
   @cSKU       = V_SKU,
   @cLottable02 = V_Lottable02,
   @cLottable03 = V_Lottable03,
   @dLottable04 = V_Lottable04,
   @cLOT        = V_LOT,
  -- @nReplenQTY  = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_QTY,  5), 0) = 1 THEN LEFT( V_QTY,  5) ELSE 0 END,
   @cFromLoc    = V_LOC,
   @cFromID     = V_ID,
   
   @nReplenQTY  = V_Integer1,

   @cUCC       = V_String1,
   @cToLoc     = V_String2,
   @cToLoc2    = V_String3,
   @cReplenKey = V_String4,
   @cDynamicPickAllocateInPPLOC = V_String5,
   @c_WaveKey  = V_String6,
   @cPickDetailKey = V_String7, 

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

IF @nFunc = 941  -- UCC Replenishment To (Dynamic Pick)
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- UCC Replenishment To (Dynamic Pick)
   IF @nStep = 1 GOTO Step_1   -- Scn = 1620. UCC
   IF @nStep = 2 GOTO Step_2   -- Scn = 1621. TO LOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 1622. OPTION
END

--RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 933. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 1620
   SET @nStep = 1

   -- Initiate var
   SET @cUCC = ''

   -- Init screen
   SET @cOutField01 = '' -- UCC

   -- EventLog - (cc01)    
   EXEC RDT.rdt_STD_EventLog    
      @cActionType = '1', -- Sign in function    
      @cUserID     = @cUserName,    
      @nMobileNo   = @nMobile,    
      @nFunctionID = @nFunc,    
      @cFacility   = @cFacility,    
      @cStorerKey  = @cStorerKey
  
END
GOTO Quit

/********************************************************************************
Step 1. Scn = 1620. UCC
   UCC NO      (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      --screen mapping
	   SET @cUCC = @cInField01

      IF @cUCC = '' OR @cUCC IS NULL
      BEGIN
         SET @nErrNo = 63701
         SET @cErrMsg = rdt.rdtgetmessage( 63701, @cLangCode,'DSP') --Need UCC
         GOTO Step_1_Fail  
      END

      IF NOT EXISTS(SELECT 1
         FROM dbo.Replenishment WITH (NOLOCK)
         WHERE RefNo = @cUCC
            AND Confirmed = 'S'
            AND StorerKey = @cStorerKey)
      BEGIN
         SET @nErrNo = 63702
         SET @cErrMsg = rdt.rdtgetmessage( 63702, @cLangCode,'DSP') --UCCNotOnReplen
         GOTO Step_1_Fail
      END

      --get Replenishment.ToLoc
      SET @cToLoc = ''
      SELECT 
         @cToLoc = ToLoc,
         @cReplenKey = ReplenishmentKey,
         @cSKU = SKU,
         @cFromLoc = FromLoc,
         @cFromID = ID,
         @cLot = Lot,
         @c_WaveKey = ReplenNo
      FROM dbo.Replenishment WITH (NOLOCK)
      WHERE RefNo = @cUCC
         AND Confirmed = 'S'
         AND StorerKey = @cStorerKey

      
      -- Get lottables
      SELECT
         @cLottable01 = Lottable01,
         @cLottable02 = Lottable02,
         @cLottable03 = Lottable03,
         @dLottable04 = Lottable04
      FROM dbo.LotAttribute WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND LOT = @cLOT

      --default ToLoc2 if configKey 'DynamicPickAutoDefaultDPLOC' setup
      SET @cToLoc2 = ''
      
      -- (ChewKP02) 
--      IF EXISTS(SELECT 1
--         FROM RDT.StorerConfig WITH (NOLOCK)
--         WHERE ConfigKey='DynamicPickAutoDefaultDPLOC'
--            AND SValue = '1')
--      BEGIN
--         SET @cToLoc2 = @cToLoc
--
--      END
      
      SET @cDynamicPickAutoDefaultDPLOC = rdt.rdtGetConfig( @nFunc, 'DynamicPickAutoDefaultDPLOC', @cStorerKey)
      IF @cDynamicPickAutoDefaultDPLOC = '0'
         SET @cDynamicPickAutoDefaultDPLOC = ''
       


      IF @cDynamicPickAutoDefaultDPLOC = ''
      BEGIN
         IF ISNULL(RTRIM(@cToLoc),'')  <> 'PICK'
         BEGIN
            SET @cToLoc2 = ''
         END
         ELSE
         BEGIN
            SET @cToLoc2 = @cToLoc
         END
      END
      ELSE
      BEGIN
       
         SET @cToLoc2 = @cToLoc

      END
         
      
      -- (ChewKP01)
      SET @cPickDetailKey = ''
      
      SELECT @cPickDetailKey = PickDetailKey 
      FROM dbo.UCC WITH (NOLOCK)
      WHERE UCCNo = @cUCC
      AND StorerKey = @cStorerKey

      SELECT @cDynamicPickAllocateInPPLOC = rdt.RDTGetConfig( 0, 'DynamicPickAllocateInPPLOC', @cStorerKey)

      --prepare next screen var
      SET @cOutField01 = @cUCC
      SET @cOutField02 = @cToLoc
      SET @cOutField03 = @cToLoc2

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
      
   END

   IF @nInputKey = 0 --ESC
   BEGIN
   		-- EventLog - (cc01)    
     	EXEC RDT.rdt_STD_EventLog    
      	@cActionType = '9', -- Sign Out function    
       	@cUserID     = @cUserName,    
	      @nMobileNo   = @nMobile,    
       	@nFunctionID = @nFunc,    
       	@cFacility   = @cFacility,    
       	@cStorerKey  = @cStorerKey
       
      --go to main menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cUCC = ''
      SET @cOutField01 = '' -- UCC
   END

END
GOTO Quit

/********************************************************************************
Step 2. Scn = 1621. UCC, ToLOC, ToLOC2
   UCCNo          (field01)
   To LOC         (field02)
   To LOC         (field03, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN

      --screen mapping
	   SET @cToLoc2 = @cInField03

      IF @cToLoc2 = '' OR @cToLoc2 IS NULL
      BEGIN
         SET @nErrNo = 63703
         SET @cErrMsg = rdt.rdtgetmessage( 63703, @cLangCode,'DSP') --TO LOC needed
         GOTO Step_2_Fail
      END
      
      -- (ChewKP01)
      SET @cExtendedValidateSP = ''
      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey) -- Parse in Function
      
      -- Extended info
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cExecStatements = N'EXEC rdt.' + RTRIM( @cExtendedValidateSP) + 
                                    '   @nMobile               ' +
                                    ' , @nFunc                 ' +
                                    ' , @cLangCode             ' +
                                    ' , @nStep                 ' +
                                    ' , @nInputKey             ' +
                                    ' , @cFacility             ' +
                                    ' , @cStorerKey            ' +
                                    ' , @cUCC                  ' +
                                    ' , @cToLoc                ' +
                                    ' , @tExtValidateData      ' +
                                    ' , @nErrNo       OUTPUT   ' +
                                    ' , @cErrMSG      OUTPUT   ' 
      
             
            SET @cExecArguments = 
                      N'@nMobile     INT,                    ' +
                       '@nFunc       INT,                    ' +    
                       '@cLangCode   NVARCHAR(3),            ' +    
                       '@nStep       INT,                    ' +
                       '@nInputKey   INT,                    ' +
                       '@cFacility   NVARCHAR(5),            ' +    
                       '@cStorerKey  NVARCHAR(15),           ' +    
                       '@cUCC        NVARCHAR(20),           ' +    
                       '@cToLoc      NVARCHAR(10),           ' +
                       '@tExtValidateData       VariableTable READONLY,' +
                       '@nErrNo      INT  OUTPUT,            ' +
                       '@cErrMsg     NVARCHAR(1024) OUTPUT   ' 
                       
       
            
            EXEC sp_executesql @cExecStatements, @cExecArguments, 
                                  @nMobile
                                , @nFunc
                                , @cLangCode
                                , @nStep
                                , @nInputKey
                                , @cFacility
                                , @cStorerKey
                                , @cUCC
                                , @cToLoc2
                                , @tExtValidateData
                                , @nErrNo       OUTPUT
                                , @cErrMSG      OUTPUT
         END
         
         IF @nErrNo <> 0 
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP')
            GOTO Step_2_Fail
         END
      END

      IF RTRIM(@cToLoc2) <> RTRIM(@cToLoc)
      BEGIN

         IF @cToLoc = 'PICK' -- FCP Replenishment
         BEGIN
            SET @nErrNo = 63712
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --FCPNotAllowOverride
            GOTO Step_2_Fail
         END   
         ELSE -- Only Non FCP Replenishment able to Override ToLoc
         BEGIN
            --validate LOC
            IF NOT EXISTS (SELECT 1 
               FROM dbo.Loc WITH (NOLOCK) 
               WHERE LOC = @cToLoc2)
            BEGIN
               SET @nErrNo = 63704
               SET @cErrMsg = rdt.rdtgetmessage( 63704, @cLangCode,'DSP') --Invalid LOC
               GOTO Step_2_Fail
            END
   
            --Validate if LOC in same facility
            IF NOT EXISTS (SELECT 1 
               FROM dbo.Loc WITH (NOLOCK) 
               WHERE Loc = @cToLoc2 
                  AND Facility = @cFacility)
            BEGIN
               SET @nErrNo = 63705
               SET @cErrMsg = rdt.rdtgetmessage( 63705, @cLangCode,'DSP') --Diff facility
               GOTO Step_2_Fail
            END
            
            SET @nReplenDiffLoc = 1
            
   
            --prepare next screen var
            SET @cOption = ''
            SET @cOutField01 = '' --option
   
            -- Go to next screen
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1
  
            GOTO Quit
         END            
      END
      ELSE
      BEGIN
         SET @nReplenDiffLoc = 0

         IF EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
            WHERE LOC = @cToLoc 
               AND LocationType = 'DYNAMICPK')
         BEGIN -- DP Allocation
            SELECT @nReplenQTY = QTY 
            FROM dbo.Replenishment WITH (NOLOCK)
            WHERE ReplenishmentKey = @cReplenKey
         END
         ELSE
         BEGIN -- PP Allocation
            IF @cDynamicPickAllocateInPPLoc = '1'
            BEGIN
               SELECT @nReplenQTY = QTYInPickLoc 
               FROM dbo.Replenishment WITH (NOLOCK)
               WHERE ReplenishmentKey = @cReplenKey
            END
         END

         GOTO UCC_Replenish_To_Process
      END
    
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = ''  -- ReplenGroup
      SET @cUCC = ''

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cToLoc2 = '' 
      SET @cOutField03 = '' --ToLoc2
   END

END
GOTO Quit

/********************************************************************************
Step 3. Scn = 1622. Option
   Replenish to different LOC?
   1=YES
   2=NO
   
   OPTION   (field01, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      --screen mapping
	   SET @cOption = @cInField01

      --check if option is blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 63706
         SET @cErrMsg = rdt.rdtgetmessage( 63706, @cLangCode, 'DSP') --Option req
         GOTO Step_3_Fail
      END

      --prompt error msg if option is not '1' or '2'
      IF @cOption NOT IN ('1','2')
	   BEGIN
         SET @nErrNo = 63707
         SET @cErrMsg = rdt.rdtgetmessage(63707, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_3_Fail   
      END

      IF @cOption = '1'
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
            WHERE LOC = @cToLoc2 
               AND LocationType = 'DYNAMICPK')
         BEGIN -- DP Allocation
            SELECT @nReplenQTY = QTY 
            FROM dbo.Replenishment WITH (NOLOCK)
            WHERE ReplenishmentKey = @cReplenKey
         END
         ELSE
         BEGIN -- PP Allocation
            IF @cDynamicPickAllocateInPPLoc = '1'
            BEGIN
               SELECT @nReplenQTY = QTYInPickLoc 
               FROM dbo.Replenishment WITH (NOLOCK)
               WHERE ReplenishmentKey = @cReplenKey
            END
         END

         GOTO UCC_Replenish_To_Process
      END

      IF @cOption = '2'
      BEGIN
         -- Prepare prev screen var
         SET @cOutField01 = @cUCC
         SET @cOutField02 = @cToLoc
         SET @cOutField03 = ''
         SET @cToLoc2 = ''

         -- Go to prev screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cUCC
      SET @cOutField02 = @cToLoc
      SET @cOutField03 = ''
      SET @cToLoc2 = ''

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cOption = '' 
      SET @cOutField01 = '' --Option
   END

END
GOTO Quit

UCC_Replenish_To_Process:
BEGIN
	DECLARE @nTranCount INT
	DECLARE @curUCC CURSOR
   DECLARE @cUCCWithMultiSKU       NVARCHAR( 1)
   DECLARE @cUCCSKU NVARCHAR( 20)
   DECLARE @nUCCQty INT
   DECLARE @cUCCLot NVARCHAR( 10)
   DECLARE @cUCCLottable02 NVARCHAR( 18)
   
   SET @cUCCWithMultiSKU = rdt.RDTGetConfig( @nFunc, 'UCCWithMultiSKU', @cStorerKey)
   
   IF @cUCCWithMultiSKU = '1'
   BEGIN
      SET @nTranCount = @@TRANCOUNT            
      BEGIN TRAN  -- Begin our own transaction            
      SAVE TRAN rdt_UCCReplen -- For rollback or commit only our own transaction                  
      
      SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT SKU, Qty, Lot, UCC_RowRef 
      FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cUCC
      OPEN @curUCC
      FETCH NEXT FROM @curUCC INTO @cUCCSKU, @nUCCQty, @cUCCLot, @nUCC_RowRef
      WHILE @@FETCH_STATUS = 0
      BEGIN
      	SELECT @cReplenKey = ReplenishmentKey 
      	FROM dbo.REPLENISHMENT WITH (NOLOCK) 
      	WHERE RefNo = @cUCC 
      	AND   Sku = @cUCCSKU 
      	AND   Lot = @cUCCLot
      	AND   Confirmed <> 'Y'
      	
         IF @nReplenDiffLoc = 0
         BEGIN
            EXECUTE rdt.rdt_DynamicPick_ReplenMove 
               @nMobile     = @nMobile,
               @nFunc       = @nFunc,
               @cLangCode   = @cLangCode, 
               @nErrNo      = @nErrNo OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
               @cSourceType = 'rdtfnc_DynamicPick_UCCReplenTo', 
               @cStorerKey  = @cStorerKey,
               @cFacility   = @cFacility, 
               @cFromLOC    = @cFromLOC, 
               @cToLOC      = @cToLOC, 
               @cFromID     = @cFromID, -- NULL means not filter by ID. Blank ID is a valid ID
               @cToID       = @cFromID, -- NULL means not changing ID. Blank ID is a valid ID
               @cSKU        = NULL, -- Either SKU or UCC only
               @cUCC        = @cUCC, -- 
               @nQTY        = @nUCCQty,    -- For move by SKU, QTY must have value
               @cFromLOT    = @cUCCLot, -- Applicable for all 6 types of move
               @c_WaveKey   = @c_WaveKey,
               @cReplenKey  = @cReplenKey,
               @cLottable02 = @cLottable02,
               @nUCC_RowRef = @nUCC_RowRef
         END
         ELSE
         BEGIN
            EXECUTE rdt.rdt_DynamicPick_ReplenMove 
               @nMobile     = @nMobile,
               @nFunc       = @nFunc,
               @cLangCode   = @cLangCode, 
               @nErrNo      = @nErrNo OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
               @cSourceType = 'rdtfnc_DynamicPick_UCCReplenTo', 
               @cStorerKey  = @cStorerKey,
               @cFacility   = @cFacility, 
               @cFromLOC    = @cFromLOC, 
               @cToLOC      = @cToLOC2, 
               @cFromID     = @cFromID, -- NULL means not filter by ID. Blank ID is a valid ID
               @cToID       = @cFromID, -- NULL means not changing ID. Blank ID is a valid ID
               @cSKU        = NULL, -- Either SKU or UCC only
               @cUCC        = @cUCC, -- 
               @nQTY        = @nUCCQTY,    -- For move by SKU, QTY must have value
               @cFromLOT    = @cUCCLot, -- Applicable for all 6 types of move
               @c_WaveKey   = @c_WaveKey,
               @cReplenKey  = @cReplenKey,
               @cLottable02 = @cLottable02,
               @nUCC_RowRef = @nUCC_RowRef
         END

         IF @nErrNo <> 0
         BEGIN
            GOTO RollBackTran
         END

      	FETCH NEXT FROM @curUCC INTO @cUCCSKU, @nUCCQty, @cUCCLot, @nUCC_RowRef
      END
         
      COMMIT TRAN rdt_UCCReplen

      GOTO Commit_Tran

      RollBackTran:
         ROLLBACK TRAN rdt_UCCReplen -- Only rollback change made here
      Commit_Tran:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

      IF @nErrNo <> 0
      BEGIN
         GOTO Step_Replen_To_Fail
      END
   END
   ELSE
   BEGIN
      IF @nReplenDiffLoc = 0
      BEGIN
         EXECUTE rdt.rdt_DynamicPick_ReplenMove 
            @nMobile     = @nMobile,
            @nFunc       = @nFunc,
            @cLangCode   = @cLangCode, 
            @nErrNo      = @nErrNo OUTPUT,
            @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
            @cSourceType = 'rdtfnc_DynamicPick_UCCReplenTo', 
            @cStorerKey  = @cStorerKey,
            @cFacility   = @cFacility, 
            @cFromLOC    = @cFromLOC, 
            @cToLOC      = @cToLOC, 
            @cFromID     = @cFromID, -- NULL means not filter by ID. Blank ID is a valid ID
            @cToID       = @cFromID, -- NULL means not changing ID. Blank ID is a valid ID
            @cSKU        = NULL, -- Either SKU or UCC only
            @cUCC        = @cUCC, -- 
            @nQTY        = @nQTY,    -- For move by SKU, QTY must have value
            @cFromLOT    = @cLOT, -- Applicable for all 6 types of move
            @c_WaveKey   = @c_WaveKey,
            @cReplenKey  = @cReplenKey,
            @cLottable02 = @cLottable02,
            @nUCC_RowRef = @nUCC_RowRef
      END
      ELSE
      BEGIN
         EXECUTE rdt.rdt_DynamicPick_ReplenMove 
            @nFunc       = @nFunc,
            @nMobile     = @nMobile,
            @cLangCode   = @cLangCode, 
            @nErrNo      = @nErrNo OUTPUT,
            @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
            @cSourceType = 'rdtfnc_DynamicPick_UCCReplenTo', 
            @cStorerKey  = @cStorerKey,
            @cFacility   = @cFacility, 
            @cFromLOC    = @cFromLOC, 
            @cToLOC      = @cToLOC2, 
            @cFromID     = @cFromID, -- NULL means not filter by ID. Blank ID is a valid ID
            @cToID       = @cFromID, -- NULL means not changing ID. Blank ID is a valid ID
            @cSKU        = NULL, -- Either SKU or UCC only
            @cUCC        = @cUCC, -- 
            @nQTY        = @nQTY,    -- For move by SKU, QTY must have value
            @cFromLOT    = @cLOT, -- Applicable for all 6 types of move
            @c_WaveKey   = @c_WaveKey,
            @cReplenKey  = @cReplenKey,
            @cLottable02 = @cLottable02,
            @nUCC_RowRef = @nUCC_RowRef

       END


      IF @nErrNo <> 0
      BEGIN
         GOTO Step_Replen_To_Fail
      END
   END
   
   -- EventLog - (cc01)    
   EXEC RDT.rdt_STD_EventLog    
      @cActionType   = '5', -- Replen    
      @cUserID       = @cUserName,    
      @nMobileNo     = @nMobile,    
      @nFunctionID   = @nFunc,    
      @cFacility     = @cFacility,    
      @cStorerKey    = @cStorerKey,    
      @cSKU          = @cSKU,   
      @cUCC			  = @cUCC,
      @cSuggestedLOC = @cToLoc,
      @ctoLocation	  = @cToLoc2

   -- Where to go
   IF @nReplenDiffLoc = 0
   BEGIN
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1

      SET @cOutField01 = '' -- UCC
   END
   ELSE
   BEGIN
      SET @nScn  = @nScn - 2
      SET @nStep = @nStep - 2

      SET @cOutField01 = '' -- UCC
   END

   GOTO Quit

   Step_Replen_To_Fail:

   IF @nReplenDiffLoc = 0
   BEGIN
      SET @cOutField03 = ''   -- To Loc
   END
   ELSE
   BEGIN
      SET @cOutField01 = ''
   END
END

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
      V_LOT     = @cLOT,
      V_Lottable02 = @cLottable02,
      V_Lottable03 = @cLottable03,
      V_Lottable04 = @dLottable04,
      --V_QTY     = @nReplenQTY,
      V_LOC     = @cFromLoc,
      V_ID      = @cFromID,
      
      V_Integer1 = @nReplenQTY,

      V_String1 = @cUCC,
      V_String2 = @cToLoc,
      V_String3 = @cToLoc2,
      V_String4 = @cReplenKey,
      V_String5 = @cDynamicPickAllocateInPPLOC,
      V_String6 = @c_WaveKey,
      V_String7 = @cPickDetailKey,

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