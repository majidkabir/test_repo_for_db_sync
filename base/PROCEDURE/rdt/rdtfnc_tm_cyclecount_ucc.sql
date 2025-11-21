SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/ 
/* Copyright: MAERSK                                                          */ 
/* Purpose: SkipJack CycleCount SOS#227151                                    */ 
/*                                                                            */ 
/* Modifications log:                                                         */ 
/*                                                                            */ 
/* Date       Rev  Author     Purposes                                        */ 
/* 2011-11-02 1.0  ChewKP     Created                                         */ 
/* 2012-10-30 1.1  James      SOS257258 - Bug fix (james01)                   */
/* 2016-10-05 1.2  James      Perf tuning                                     */
/* 2018-10-24 1.3  Gan        Performance tuning                              */
/* 2020-01-06 1.4  James      WMS-16965 Add ExtendedInfoSP @ scn 4 (james02)  */
/* 2021-07-20 1.5  Chermaine  WMS-17453 Add eventlog at scn2 (cc01)           */
/* 2023-10-12 1.6  James      WMS-23797 Enhance UCC filtering (james03)       */
/* 2023-11-29 1.7  James      WMS-24279 Add config check whether UCC exists in*/
/*                            current loc (james04)                           */
/******************************************************************************/

CREATE   PROC [RDT].[rdtfnc_TM_CycleCount_UCC] (
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
   @cOption     NVARCHAR( 1),
   @nCount      INT,
   @nRowCount   INT,
   @cSQL        NVARCHAR( MAX),
   @cSQLParam   NVARCHAR( MAX)

-- RDT.RDTMobRec variable
DECLARE 
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,
   @cPickStatus         NVARCHAR( 20),
   @nSumPick            INT,
  
   @cPrinter   NVARCHAR( 20), 
   @cUserName  NVARCHAR( 18),
   
   
   @cStorerKey          NVARCHAR(15),              
   @cFacility           NVARCHAR(5),         
   @cTaskDetailKey      NVARCHAR(10),     
   @cLoc                NVARCHAR(10),
   @cID                 NVARCHAR(18),
   @cSKU                NVARCHAR(20),
   @cSuggFromLoc        NVARCHAR(10),
   @cSuggID             NVARCHAR(18),              
   @cSuggSKU            NVARCHAR(20),     
   @cUCC                NVARCHAR(20),
   @cCommodity          NVARCHAR(20),
   @c_outstring         NVARCHAR(255),
   @cContinueProcess    NVARCHAR(10),     
   @cReasonStatus       NVARCHAR(10),      
   @cAreakey            NVARCHAR(10),
   @cUserPosition       NVARCHAR(10),
   @nFromScn            INT,
   @nFromStep           INT,
   @cTMCCSingleScan     NVARCHAR(1),
   @nToFunc             INT,
   @nToScn              INT,
   @cTTMStrategykey     NVARCHAR(10),
   @cRefKey01           NVARCHAR(20),
   @cRefKey02           NVARCHAR(20),
   @cRefKey03           NVARCHAR(20),
   @cRefKey04           NVARCHAR(20),
   @cRefKey05           NVARCHAR(20),
   @cTTMTasktype        NVARCHAR(10),
   @cReasonCode         NVARCHAR(10),
   @cNextTaskdetailkey  NVARCHAR(10),
   @nPrevStep           INT,
   @cCCKey              NVARCHAR(10),
   @c_CCDetailKey       NVARCHAR(10),
   @b_Success           INT,
	@cSKUDescr           NVARCHAR(60),
	@cLotLabel01         NVARCHAR( 20),
   @cLotLabel02         NVARCHAR( 20),
   @cLotLabel03         NVARCHAR( 20),
   @cLotLabel04         NVARCHAR( 20),
   @cLotLabel05         NVARCHAR( 20),
   @cLottable01         NVARCHAR( 18),
   @cLottable02         NVARCHAR( 18),
   @cLottable03         NVARCHAR( 18),
   @cLottable04         NVARCHAR( 16),
   @cLottable05         NVARCHAR( 16),
	@nUCCQty             INT,
	@cQty                INT,
	@cOptions            NVARCHAR( 1),
	@cInSKU              NVARCHAR(20),
	@nSKUCnt             INT,
	@cLottable01_Code    NVARCHAR( 30),
	@cLottable02_Code    NVARCHAR( 30),
	@cLottable03_Code    NVARCHAR( 30),
	@cLottable04_Code    NVARCHAR( 30),
	@cLottable05_Code    NVARCHAR( 30),
	@nCountLot   INT,
	@cListName           NVARCHAR( 20),
	@cLottableLabel      NVARCHAR( 20),   
	@cShort              NVARCHAR( 10),
	@cStoredProd         NVARCHAR( 250),
	@dLottable04         DATETIME,
	@dLottable05         DATETIME,
	@cHasLottable        NVARCHAR( 1),
	@cSourcekey          NVARCHAR(15),
	@cTempLottable01     NVARCHAR( 18),
   @cTempLottable02     NVARCHAR( 18),
   @cTempLottable03     NVARCHAR( 18),
   @dTempLottable04     NVARCHAR( 16),
   @dTempLottable05     NVARCHAR( 16),
   @nRowID              INT,
   @nActQTY             INT, -- Actual QTY
   @nPrevScreen         INT,
   @cInUCCCount         NVARCHAR( 5),
   @nSumUCCQty          INT,
	@nSumUCCCount        INT,
	@nUCCCounter         NVARCHAR( 5),
	@c_modulename        NVARCHAR( 30),
	@c_Activity          NVARCHAR( 10),
	@cCCType             NVARCHAR( 10),
	@cPickMethod         NVARCHAR( 10),
	@cSKUDescr1          NVARCHAR( 20),
	@cSKUDescr2          NVARCHAR( 20),
	@cCCDetailKey        NVARCHAR( 10),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @cSkipAlertScreen    NVARCHAR( 1),
   @cDefaultOption      NVARCHAR( 1),
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
   @cCheckUCCExistsInLoc   NVARCHAR( 1),  
   
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
   
   @cTaskDetailKey   = V_TaskDetailKey,         
   @cSuggFromLoc     = V_Loc,
   @cID              = V_ID,
   @cSKU             = V_SKU,
   
   @cLottable01       = V_Lottable01, 
   @cLottable02       = V_Lottable02, 
   @cLottable03       = V_Lottable03, 
   @dLottable04       = V_Lottable04, 
   @dLottable05       = V_Lottable05, 
   
   @cLotLabel01      = V_LottableLabel01, 
   @cLotLabel02      = V_LottableLabel02, 
   @cLotLabel03      = V_LottableLabel03, 
   @cLotLabel04      = V_LottableLabel04, 
   @cLotLabel05      = V_LottableLabel05,
   
   @nFromStep        = V_FromStep,
   @nFromScn         = V_FromScn,

   @nUCCQty          = V_Integer1,
   @nPrevStep        = V_Integer2,
   @nPrevScreen      = V_Integer3,
   @nSumUCCCount     = V_Integer4,
   @nUCCCounter      = V_Integer5,
   @nActQTY          = V_Integer6,
   @nRowID           = V_Integer7,
     
   @cCCKey           = V_String1,
   @cSuggID          = V_String2,
   @cCommodity       = V_String3,
   @cUCC             = V_String4,
   @cExtendedInfoSP  = V_String5,
   @cExtendedInfo    = V_String6,
   @cSkipAlertScreen = V_String7,
   @cDefaultOption   = V_String8,
  -- @nUCCQty          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5, 5), 0) = 1 THEN LEFT( V_String5, 5) ELSE 0 END,     
   
   @cCheckUCCExistsInLoc = V_String9,  
   
   @cLoc             = V_String10,
  -- @nPrevStep        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String11, 5), 0) = 1 THEN LEFT( V_String11, 5) ELSE 0 END,
  -- @nPrevScreen      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String12, 5), 0) = 1 THEN LEFT( V_String12, 5) ELSE 0 END,
   @cSuggSKU         = V_String13,
   @cPickMethod      = V_String14,
   @cSKUDescr1       = V_String15,
   @cSKUDescr2       = V_String16,
   @cCCDetailKey     = V_String17,
   
   
   
   -- Module SP Variable V_String 20 - 26 -- 
   @cInUCCCount      = V_String20,
  -- @nSumUCCCount     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String21, 5), 0) = 1 THEN LEFT( V_String21, 5) ELSE 0 END,
  -- @nUCCCounter      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String22, 5), 0) = 1 THEN LEFT( V_String22, 5) ELSE 0 END,
   
   
   
  -- @nActQTY          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String28, 5), 0) = 1 THEN LEFT( V_String28, 5) ELSE 0 END,     
  -- @nRowID           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String29, 8), 0) = 1 THEN LEFT( V_String29, 8) ELSE 0 END,
  -- @nFromScn         = V_String30,
  -- @nFromStep        = V_String31,            
   @cAreakey         = V_String32,               
   @cTTMStrategykey  = V_String33,               
   @cTTMTasktype     = V_String34,               
   @cRefKey01        = V_String35,               
   @cRefKey02        = V_String36,               
   @cRefKey03        = V_String37,               
   @cRefKey04        = V_String38,               
   @cRefKey05        = V_String39,  
   

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



IF @nFunc = 1767  -- TM CC - UCC
BEGIN
   -- (james02)
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   SET @cSkipAlertScreen = rdt.RDTGetConfig( @nFunc, 'SkipAlertScreen', @cStorerkey)
	
   SET @cDefaultOption = rdt.RDTGetConfig( @nFunc, 'DefaultOption', @cStorerkey)
   IF @cDefaultOption = '0'
   SET @cDefaultOption = ''

   -- (james04)  
   SET @cCheckUCCExistsInLoc = rdt.RDTGetConfig( @nFunc, 'CheckUCCExistsInLoc', @cStorerKey)  
   
   -- Redirect to respective screen
   IF @nStep = 1 GOTO Step_1   -- Scn = 2930. UCC
	IF @nStep = 2 GOTO Step_2   -- Scn = 2931. Options
	IF @nStep = 3 GOTO Step_3   -- Scn = 2932. Alert Message
   IF @nStep = 4 GOTO Step_4   -- Scn = 2933. SKU Not Exists   
END

/********************************************************************************
Step 1. Scn = 2930. 
   UCC (input, field01)
   SKU (field02) 
   DESCR 1 (field03)
   DESCR 2 (field04)
   'LOTTABLE 1/2/3/4/5:'
   Lottable01 (field06)
   Lottable02 (field07)
   Lottable03 (field08)
   Lottable04 (field09)
   Lottable05 (field10)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
		SET @cUCC = ISNULL(RTRIM(@cInField01),'')
		
      IF ISNULL(RTRIM(@cUCC), '') = ''
      BEGIN
         SET @cOutField01 = CASE WHEN @cDefaultOption <> '' THEN @cDefaultOption ELSE '' END

         -- GOTO Next Screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO QUIT
      END
      
      IF NOT EXISTS (SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                     WHERE UCCNo = @cUCC 
                     AND Status <> '0' ) 
      BEGIN
         SET @nErrNo = 74464
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid UCC'
         GOTO Step_1_Fail
      END                     
                     
      IF EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                  WHERE Loc = @cLoc
                  --AND ID = @cID 
                  AND CCKey = @cCCKey
                  AND RefNo = @cUCC
                  AND Status > '0'
                  AND CCSheetNo = @cTaskDetailKey ) 
      BEGIN      
         SET @nErrNo = 74463
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCC Counted'
         GOTO Step_1_Fail
      END
      
      IF EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
	               WHERE CCkey = @cCCKey
	               AND CCSheetNo = @cTaskDetailKey 
	               AND Status >= '2'
	               AND RefNo = '' )
      BEGIN
         SET @nErrNo = 74472
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'MixCountTypeNotAllowed'
         GOTO Step_1_Fail
      END
      
      IF @cCheckUCCExistsInLoc = '1'  
      BEGIN  
         IF NOT EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)  
                         WHERE CCKey = @cCCKey  
                         AND   Loc = @cLoc  
                         AND   (( @cID = '') OR ( ID = @cID))  
                         AND   RefNo = @cUCC  
                         AND   Status  < '9'  
                         AND   CCSheetNo = @cTaskDetailKey)     
         BEGIN  
            SET @cOutField01 = ''  
            SET @nScn = @nScn + 3  
            SET @nStep = @nStep + 3  
              
            GOTO Quit  
         END  
      END  
      
      
      SET @nUCCQty = 0 
      SET @cLottable01 = ''
      SET @cLottable02 = ''
      SET @cLottable03 = ''
      SET @dLottable04 = ''
      SET @dLottable05 = ''
      SET @cSKU = ''
      SET @cSKUDescr = ''
      SET @cStorerKey = ''
      
      SELECT   
               @cStorerKey = UCC.StorerKey
             , @cSKU = UCC.SKU
             , @cSKUDescr = SKU.DESCR
             , @nUCCQty = UCC.Qty
             , @cLottable01 = CC.Lottable01
             , @cLottable02 = CC.Lottable02
             , @cLottable03 = CC.Lottable03
             , @dLottable04 = rdt.rdtFormatDate( CC.Lottable04)
             , @dLottable05 = rdt.rdtFormatDate( CC.Lottable05)
      FROM dbo.UCC UCC WITH (NOLOCK)
      INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.SKU = UCC.SKU AND SKU.Storerkey = UCC.StorerKey)
      INNER JOIN dbo.CCDetail CC WITH (NOLOCK) ON ( CC.SKU           = UCC.SKU 
                                                    AND CC.StorerKey = UCC.StorerKey
                                                    AND CC.Loc       = UCC.Loc
                                                    AND CC.ID        = UCC.ID 
                                                    AND CC.LOT       = UCC.LOT  -- (TESTING)
                                                    AND CC.RefNo     = UCC.UCCNo -- (TESTING)
                                                  ) 
      WHERE CC.CCKey = @cCCKey
      AND UCC.Loc    = @cLoc
      AND UCC.ID     = @cID
      AND UCC.UCCNo  = @cUCC
      AND CC.Status < '9'
      
      
      IF ISNULL(@nUCCQty,'') = 0 
      BEGIN
         SELECT   @nUCCQty    = UCC.Qty 
                , @cSKU       = UCC.SKU
                , @cStorerKey = UCC.StorerKey
                , @cLottable01 = LOTATTR.Lottable01
                , @cLottable02 = LOTATTR.Lottable02
                , @cLottable03 = LOTATTR.Lottable03
                , @dLottable04 = LOTATTR.Lottable04
                , @dLottable05 = LOTATTR.Lottable05
         FROM dbo.UCC UCC WITH (NOLOCK)
         INNER JOIN SKU SKU WITH (NOLOCK) ON (SKU.SKU = UCC.SKU AND SKU.StorerKey = UCC.StorerKey)
         INNER JOIN LOTATTRIBUTE LOTATTR WITH (NOLOCK) ON (LOTATTR.LOT = UCC.LOT AND LOTATTR.SKU = UCC.SKU AND LOTATTR.StorerKey = UCC.StorerKey)
         WHERE UCC.UCCNo = @cUCC

         -- If still cannot find correct UCC
         IF ISNULL(@nUCCQty,'') = 0
         BEGIN
            SET @nErrNo = 74476
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid UCC'
            GOTO Step_1_Fail
         END
      END

      SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'CCExcludePICK', @cStorerkey)
      IF @cPickStatus <> '0'
      BEGIN
         SELECT @nSumPick = SUM(Qty)
         FROM PICKDETAIL WITH (NOLOCK)
         WHERE Storerkey = @cStorerKey AND ID = ISNULL(@cID,'')
         AND Loc = @cLOC AND Sku = @cSKU AND Status = @cPickStatus
         GROUP BY Loc,Storerkey
         
         IF @nUCCQty > @nSumPick
         BEGIN
            SET @nUCCQty = @nUCCQty - @nSumPick
         END
      END

      IF @cPickMethod = 'SKU' 
      BEGIN
         IF @cSuggSKU <> @cSKU
         BEGIN
               SET @nErrNo = 74471
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
               GOTO Step_1_Fail
         END
      END

      -- Update CCDetail --
      EXEC [RDT].[rdt_TM_CycleCount_UCC_ConfirmTask]
              @nMobile           = @nMobile    
             ,@cCCKey            = @cCCKey     
             ,@cStorerKey        = @cStorerKey 
             ,@cSKU              = @cSKU       
             ,@cLOC              = @cLOC       
             ,@cID               = @cID        
             ,@nQty              = @nUCCQty       
             ,@nPackValue        = '' 
             ,@cUserName         = @cUserName  
             ,@cLottable01       = @cLottable01
             ,@cLottable02       = @cLottable02
             ,@cLottable03       = @cLottable03
             ,@dLottable04       = @dLottable04
             ,@dLottable05       = @dLottable05
             ,@cUCC              = @cUCC      
             ,@cPickMethod       = @cPickMethod 
             ,@cTaskDetailKey    = @cTaskDetailKey
             ,@cLangCode         = @cLangCode  
             ,@nErrNo            = @nErrNo      OUTPUT
             ,@cErrMsg           = @cErrMsg     OUTPUT -- screen limitation, 20 char max
      
      
      IF @nErrNo <> 0 
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO Step_1_Fail
      END
      
      SET @nUCCCounter = @nUCCCounter + 1
      
      --(cc01)
      -- EventLog - Sign In Function
      EXEC RDT.rdt_STD_EventLog
        @cActionType = '3', -- Sign in function
        @cUserID     = @cUserName,
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorerkey,
        @cUCC        = @cUCC,
        @cSKU        = @cSKU,
        @cLocation   = @cLOC,
        @nQTY        = @nUCCQty,
        @cID         = @cID,
        @cCCKey      = @cCCKey
      
      SET @cOutField01 = ''
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
      SET @cOutField05 = CAST (@nUCCCounter AS NVARCHAR(2)) + '/' + CAST (@nSumUCCCount AS NVARCHAR(2))  
      SET @cOutField06 = @cLottable01
      SET @cOutField07 = @cLottable02
      SET @cOutField08 = @cLottable03
      SET @cOutField09 = rdt.rdtFormatDate( @dLottable04)
      SET @cOutField10 = rdt.rdtFormatDate( @dLottable05)

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cExtendedInfo OUTPUT '

            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR( 3), ' +
               '@nStep           INT, ' +
               '@nInputKey       INT, ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cTaskDetailKey  NVARCHAR( 10), ' +
               '@cCCKey          NVARCHAR( 10), ' +
               '@cCCDetailKey    NVARCHAR( 10), ' +
               '@cLoc            NVARCHAR( 10), ' +
               '@cID             NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nActQTY         INT, ' +
               '@cLottable01     NVARCHAR( 18), ' +
               '@cLottable02     NVARCHAR( 18), ' +
               '@cLottable03     NVARCHAR( 18), ' +
               '@dLottable04     DATETIME, ' +
               '@dLottable05     DATETIME, ' +
               '@cLottable06     NVARCHAR( 30), ' +
               '@cLottable07     NVARCHAR( 30), ' +
               '@cLottable08     NVARCHAR( 30), ' +
               '@cLottable09     NVARCHAR( 30), ' +
               '@cLottable10     NVARCHAR( 30), ' +
               '@cLottable11     NVARCHAR( 30), ' +
               '@cLottable12     NVARCHAR( 30), ' +
               '@dLottable13     DATETIME, ' +
               '@dLottable14     DATETIME, ' +
               '@dLottable15     DATETIME, ' +
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cExtendedInfo OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END
	END  -- Inputkey = 1


	IF @nInputKey = 0 
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
      
      -- EventLog - Sign In Function
      EXEC RDT.rdt_STD_EventLog
        @cActionType = '9', -- Sign in function
        @cUserID     = @cUserName,
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorerkey,
        @nStep       = @nStep
      
      
      SET @cOutField01 = @cLoc
      SET @cOutField02 = @cID
      SET @cOutField03 = ''
      
      
      --go to main menu
      SET @nFunc = 1766
      SET @nScn  = 2872
      SET @nStep = 3
        
   END
	GOTO Quit

   STEP_1_FAIL:
   BEGIN
         
         SET @cOutField01 = ''
         SET @cOutField02 = ''--@cSKU
         SET @cOutField03 = ''--SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
         SET @cOutField04 = ''--SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
         SET @cOutField05 = CAST (@nUCCCounter AS NVARCHAR(2)) + '/' + CAST (@nSumUCCCount AS NVARCHAR(2))  
         SET @cOutField06 = ''--@cLottable01
         SET @cOutField07 = ''--@cLottable02
         SET @cOutField08 = ''--@cLottable03
         SET @cOutField09 = ''--@dLottable04
         SET @cOutField10 = ''--@dLottable05
         
         
   END
   

END 
GOTO QUIT

/********************************************************************************
Step 2. Scn = 2931. 
   Options (Input , Field01)
   
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN	
		SET @cOptions = ISNULL(RTRIM(@cInField01),'')
		
      IF ISNULL(@cOptions, '') = ''
      BEGIN
         SET @nErrNo = 74454
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option needed'
         GOTO Step_2_Fail
      END

      IF @cOptions NOT IN ('1', '2','3','4')
      BEGIN
         SET @nErrNo = 74455
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_2_Fail
      END
     
      
      IF @cOptions = '1'
      BEGIN
         -- Prepare Next Screen Variable
         SET @cOutField01 = @cSuggFromLoc
         SET @cOutField02 = ''
                        
         -- GOTO Main Module ID Screen
         SET @nFunc = 1766
         SET @nScn = 2871
         SET @nStep = 2   
      END
      ELSE IF @cOptions = '2'
      BEGIN
         -- Update CCDetail Remaining Loc , ID to Status = '2'
         UPDATE dbo.CCDetail
            SET FinalizeFlag = 'Y'
--                  ,Status = CASE WHEN Status = '0' THEN '2'
--                            ELSE Status 
--                            END
         WHERE CCKey  = @cCCKey
            AND Loc    = @cLoc
            AND Status < '9'  
            AND CCSheetNo = @cTaskDetailKey
            
         IF @@ERROR <> ''
         BEGIN
            SET @nErrNo = 74459
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDCCDetFail'
            GOTO Step_2_Fail
         END 
            
               
         IF @cTTMTasktype = 'CCSUP' 
         BEGIN
            EXEC dbo.isp_CCPostingByAdjustment_UCC   
                 	@c_CCKey    = @cCCKey
            	, @b_success  = @b_success OUTPUT
               , @c_TaskDetailKey  = @cTaskDetailKey
              
            IF @b_success = 0
            BEGIN
               SET @nErrNo = 74469
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CCPostingFail'
               GOTO Step_2_Fail
            END   

            -- If Supervisor Alert created while posting
            IF EXISTS (SELECT 1 FROM dbo.ALERT WITH (NOLOCK) 
                        WHERE TaskDetailKey = @cTaskDetailKey
                        AND   Status = '0')
            BEGIN
               UPDATE dbo.TaskDetail 
               SET Status = '9'
                     ,TrafficCop = NULL
                     ,EditDate = GetDate()
               WHERE TaskDetailKey = @cTaskDetailKey
                  
               IF @@ERROR <> ''
               BEGIN
                  SET @nErrNo = 74475
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskDetFailed'
 GOTO Step_2_Fail
               END    

               -- GOTO Alert Screen
   		      SET @nScn = @nScn + 1
   	         SET @nStep = @nStep + 1
   	                        
   	         GOTO Quit
   	      END
         END
            
                    
         UPDATE dbo.TaskDetail 
         SET Status = '9'
               ,TrafficCop = NULL
               ,EditDate = GetDate()
         WHERE TaskDetailKey = @cTaskDetailKey
            
         IF @@ERROR <> ''
         BEGIN
            SET @nErrNo = 74474
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskDetFailed'
            GOTO Step_2_Fail
         END    

         UPDATE AL WITH (ROWLOCK) SET 
            AL.STATUS = '9'
         FROM dbo.TaskDetail TD 
         JOIN dbo.Alert AL ON TD.Message03 = AL.AlertKey 
         WHERE TD.TaskDetailKey = @cTaskDetailKey
         AND   TD.TaskType = 'CCSUP'
         AND   TD.Status = '9'

         IF @@ERROR <> ''
         BEGIN
            SET @nErrNo = 74473
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD ALERT FAIL'
            GOTO Step_2_Fail
         END    
         
         IF EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                     WHERE CCKey = @cCCKey
                     AND Loc = @cLoc
                     AND CCSheetNo = @cTaskDetailKey
                     AND SystemQty <> Qty )
         BEGIN
                
            IF @cTTMTasktype <> 'CCSUP' 
            BEGIN
            -- Go to ALERT Message Screen        
            SET @cCCType = 'UCC'
            SET @c_ModuleName = 'TMCC'
            SET @c_Activity	 = 'CC'   
                      
            EXEC [RDT].[rdt_TM_CycleCount_Alert] 
                     @nMobile         = @nMobile       
                     ,@cCCKey          = @cCCKey        
                     ,@cStorerKey      = @cStorerKey    
                     ,@cLOC            = @cLOC          
                     ,@cID             = @cID  
                     ,@cSKU            = @cSKU         
                     ,@cUserName       = @cUserName     
                     ,@cModuleName     = @c_ModuleName   
                     ,@cActivity       = @c_Activity     
                     ,@cCCType         = @cCCType
                     ,@cTaskDetailKey  = @cTaskDetailKey
                     ,@cLangCode       = @cLangCode     
                     ,@nErrNo          = @nErrNo        
                     ,@cErrMsg         = @cErrMsg    

            -- GOTO Next Screen
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1

            IF @cSkipAlertScreen = '1'
               GOTO Step_3
      	   END
      	   ELSE
      	   BEGIN
         	   -- GOTO Main Module Get Next Task Screen Screen
         		SET @nFunc = 1766
         		SET @nScn = 2875
         	   SET @nStep = 6 
      	   END
         END  
         ELSE     
         BEGIN
      	      -- GOTO Main Module Get Next Task Screen Screen
      		   SET @nFunc = 1766
      		   SET @nScn = 2875
      	      SET @nStep = 6 
         END     
	      
      END
      ELSE IF @cOptions = '3'
      BEGIN
           -- Update CCDetail Remaining Loc , ID to Status = '5'
           
           DELETE FROM dbo.CCDetail
           WHERE CCKey  = @cCCKey
              AND Loc    = @cLoc
              AND CCSheetNo = @cTaskDetailKey
              
            
           IF @@ERROR <> ''
           BEGIN
               SET @nErrNo = 74460
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDCCDetFail'
               GOTO Step_2_Fail
           END 
                   
           -- Prepare Next Screen Variable
		     SET @cOutField10 = @cSuggFromLoc
           SET @cOutField02 = ''
                        
		     -- GOTO Next Screen
		     SET @nFunc = 1766
		     SET @nScn = 2870
	        SET @nStep = 1
	        
	        -- GOTO Main Module Get Next Task Screen Screen
--		    SET @nFunc = 1766
--		    SET @nScn = 2875
--	       SET @nStep = 6     
         
      END
      ELSE IF @cOptions = '4'
      BEGIN
         
         -- Back to UCC Input Screen
         -- Prepare Next Screen Variable
         
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
      	
      	SET @nScn = @nScn - 1
   	   SET @nStep = @nStep - 1  
      END
	END  -- Inputkey = 1


	GOTO Quit

   STEP_2_FAIL:
   BEGIN
      SET @cOutField01 = ''
      
   END
   

END 
GOTO QUIT

/********************************************************************************              
Step 3.            
    Screen = 2932               
    Message
********************************************************************************/              
Step_3:              
BEGIN              
   
   IF @nInputKey = 1 OR @nInputKey = 0 -- ENTER  / ESC            
   BEGIN  
              
      /****************************              
       prepare next screen variable              
      ****************************/              
                    
      SET @cOutField01 = ''
    
      SET @nFunc = 1766
		SET @nScn = 2875
	   SET @nStep = 6  
	            
      -- Go to Options Screen              
      --SET @nScn = @nScn - 2              
      --SET @nStep = @nStep - 2         
           
   END     
   GOTO QUIT
   
 
   
END              
GOTO Quit   

/********************************************************************************  
Step 4. Scn = 2933.  
   Options (Input , Field01)  
  
********************************************************************************/  
Step_4:  
BEGIN  
   IF @nInputKey = 1 --ENTER  
   BEGIN  
  
      SET @cOption = ISNULL(RTRIM(@cInField01),'')  
  
      IF ISNULL(@cOption, '') = ''  
      BEGIN  
         SET @nErrNo = 74477  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option needed'  
         GOTO Step_4_Fail  
      END  
  
      IF @cOption NOT IN ('1', '2')  
      BEGIN  
         SET @nErrNo = 74477  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'  
         GOTO Step_4_Fail  
      END  
  
      IF @cOption = '1'  
      BEGIN  
         SET @nUCCQty = 0 
         SET @cLottable01 = ''
         SET @cLottable02 = ''
         SET @cLottable03 = ''
         SET @dLottable04 = ''
         SET @dLottable05 = ''
         SET @cSKU = ''
         SET @cSKUDescr = ''
         SET @cStorerKey = ''
      
         SELECT   
                  @cStorerKey = UCC.StorerKey
                , @cSKU = UCC.SKU
                , @cSKUDescr = SKU.DESCR
                , @nUCCQty = UCC.Qty
                , @cLottable01 = CC.Lottable01
                , @cLottable02 = CC.Lottable02
                , @cLottable03 = CC.Lottable03
                , @dLottable04 = rdt.rdtFormatDate( CC.Lottable04)
                , @dLottable05 = rdt.rdtFormatDate( CC.Lottable05)
         FROM dbo.UCC UCC WITH (NOLOCK)
         INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.SKU = UCC.SKU AND SKU.Storerkey = UCC.StorerKey)
         INNER JOIN dbo.CCDetail CC WITH (NOLOCK) ON ( CC.SKU           = UCC.SKU 
                                                       AND CC.StorerKey = UCC.StorerKey
                                                       AND CC.Loc       = UCC.Loc
                                                       AND CC.ID        = UCC.ID 
                                                       AND CC.LOT       = UCC.LOT  
                                                       AND CC.RefNo     = UCC.UCCNo)
         WHERE CC.CCKey = @cCCKey
         AND UCC.Loc    = @cLoc
         AND UCC.ID     = @cID
         AND UCC.UCCNo  = @cUCC
         AND CC.Status < '9'
      
      
         IF ISNULL(@nUCCQty,'') = 0 
         BEGIN
            SELECT   @nUCCQty    = UCC.Qty 
                   , @cSKU       = UCC.SKU
                   , @cStorerKey = UCC.StorerKey
                   , @cLottable01 = LOTATTR.Lottable01
                   , @cLottable02 = LOTATTR.Lottable02
                   , @cLottable03 = LOTATTR.Lottable03
                   , @dLottable04 = LOTATTR.Lottable04
                   , @dLottable05 = LOTATTR.Lottable05
            FROM dbo.UCC UCC WITH (NOLOCK)
            INNER JOIN SKU SKU WITH (NOLOCK) ON (SKU.SKU = UCC.SKU AND SKU.StorerKey = UCC.StorerKey)
            INNER JOIN LOTATTRIBUTE LOTATTR WITH (NOLOCK) ON (LOTATTR.LOT = UCC.LOT AND LOTATTR.SKU = UCC.SKU AND LOTATTR.StorerKey = UCC.StorerKey)
            WHERE UCC.UCCNo = @cUCC

            -- If still cannot find correct UCC
            IF ISNULL(@nUCCQty,'') = 0
            BEGIN
               SET @nErrNo = 74476
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid UCC'
               GOTO Step_1_Fail
            END
         END
      
         IF @cPickMethod = 'SKU' 
         BEGIN
            IF @cSuggSKU <> @cSKU
            BEGIN
               SET @nErrNo = 74479
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
               GOTO Step_4_Fail
            END
         END

         -- Update CCDetail --
         EXEC [RDT].[rdt_TM_CycleCount_UCC_ConfirmTask]
                 @nMobile           = @nMobile    
                ,@cCCKey            = @cCCKey     
                ,@cStorerKey        = @cStorerKey 
                ,@cSKU              = @cSKU       
                ,@cLOC              = @cLOC       
                ,@cID               = @cID        
                ,@nQty              = @nUCCQty       
                ,@nPackValue        = '' 
                ,@cUserName         = @cUserName  
                ,@cLottable01       = @cLottable01
                ,@cLottable02       = @cLottable02
                ,@cLottable03       = @cLottable03
                ,@dLottable04       = @dLottable04
                ,@dLottable05       = @dLottable05
                ,@cUCC              = @cUCC      
                ,@cPickMethod       = @cPickMethod 
                ,@cTaskDetailKey    = @cTaskDetailKey
                ,@cLangCode         = @cLangCode  
                ,@nErrNo            = @nErrNo      OUTPUT
                ,@cErrMsg           = @cErrMsg     OUTPUT -- screen limitation, 20 char max
      
      
         IF @nErrNo <> 0 
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO Step_4_Fail
         END
      
         SET @nUCCCounter = @nUCCCounter + 1
      
         -- EventLog - Sign In Function
         EXEC RDT.rdt_STD_EventLog
           @cActionType = '3', -- Sign in function
           @cUserID     = @cUserName,
           @nMobileNo   = @nMobile,
           @nFunctionID = @nFunc,
           @cFacility   = @cFacility,
           @cStorerKey  = @cStorerkey,
           @cUCC        = @cUCC,
           @cSKU        = @cSKU,
           @cLocation   = @cLOC,
           @nQTY        = @nUCCQty,
           @cID         = @cID,
           @cCCKey      = @cCCKey
      
         SET @cOutField01 = ''
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
         SET @cOutField05 = CAST (@nUCCCounter AS NVARCHAR(2)) + '/' + CAST (@nSumUCCCount AS NVARCHAR(2))  
         SET @cOutField06 = @cLottable01
         SET @cOutField07 = @cLottable02
         SET @cOutField08 = @cLottable03
         SET @cOutField09 = rdt.rdtFormatDate( @dLottable04)
         SET @cOutField10 = rdt.rdtFormatDate( @dLottable05)

         -- Extended info
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cExtendedInfo = ''

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                  ' @cExtendedInfo OUTPUT '

               SET @cSQLParam =
                  '@nMobile         INT, ' +
                  '@nFunc           INT, ' +
                  '@cLangCode       NVARCHAR( 3), ' +
                  '@nStep           INT, ' +
                  '@nInputKey       INT, ' +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cTaskDetailKey  NVARCHAR( 10), ' +
                  '@cCCKey          NVARCHAR( 10), ' +
                  '@cCCDetailKey    NVARCHAR( 10), ' +
                  '@cLoc            NVARCHAR( 10), ' +
                  '@cID             NVARCHAR( 18), ' +
                  '@cSKU            NVARCHAR( 20), ' +
                  '@nActQTY         INT, ' +
                  '@cLottable01     NVARCHAR( 18), ' +
                  '@cLottable02     NVARCHAR( 18), ' +
                  '@cLottable03     NVARCHAR( 18), ' +
                  '@dLottable04     DATETIME, ' +
                  '@dLottable05     DATETIME, ' +
                  '@cLottable06     NVARCHAR( 30), ' +
                  '@cLottable07     NVARCHAR( 30), ' +
                  '@cLottable08     NVARCHAR( 30), ' +
                  '@cLottable09     NVARCHAR( 30), ' +
                  '@cLottable10     NVARCHAR( 30), ' +
                  '@cLottable11     NVARCHAR( 30), ' +
                  '@cLottable12     NVARCHAR( 30), ' +
                  '@dLottable13     DATETIME, ' +
                  '@dLottable14     DATETIME, ' +
                  '@dLottable15     DATETIME, ' +
                  '@cExtendedInfo   NVARCHAR( 20) OUTPUT '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @cExtendedInfo OUTPUT

               SET @cOutField15 = @cExtendedInfo
            END
         END
           
         SET @nScn = @nScn - 3  
         SET @nStep = @nStep - 3  
         GOTO Quit  
      END  
      ELSE  
      BEGIN  
         -- Go back screen 1  
         SET @cUCC = ''
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
         SET @cOutField15 = ''

         SET @nScn = @nScn - 3  
         SET @nStep = @nStep - 3      
      END  
   END  -- Inputkey = 1  
   GOTO Quit  
  
   STEP_4_FAIL:  
   BEGIN  
      SET @cOutField01 = ''  
   END  
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
		InputKey  =	@nInputKey,
		
      
      V_TaskDetailKey  = @cTaskDetailKey,      
      V_Loc            = @cSuggFromLoc,     
      V_ID             = @cID,              
      V_SKU            = @cSKU,             

      V_Lottable01     = @cLottable01,  
      V_Lottable02     = @cLottable02,  
      V_Lottable03     = @cLottable03,  
      V_Lottable04     = @dLottable04,  
      V_Lottable05     = @dLottable05,  
      
      V_LottableLabel01 = @cLotLabel01,      
      V_LottableLabel02 = @cLotLabel02,     
      V_LottableLabel03 = @cLotLabel03,      
      V_LottableLabel04 = @cLotLabel04,      
      V_LottableLabel05 = @cLotLabel05,    
      
      V_FromStep     = @nFromStep,
      V_FromScn      = @nFromScn,

      V_Integer1     = @nUCCQty,
      V_Integer2     = @nPrevStep,
      V_Integer3     = @nPrevScreen,
      V_Integer4     = @nSumUCCCount,
      V_Integer5     = @nUCCCounter,
      V_Integer6     = @nActQTY,
      V_Integer7     = @nRowID,
                          
      V_String1        = @cCCKey,
      V_String2        = @cSuggID,          
      V_String3        = @cCommodity,       
      V_String4        = @cUCC,             
      V_String5        = @cExtendedInfoSP,
      V_String6        = @cExtendedInfo,
      V_String7        = @cSkipAlertScreen,
      V_String8        = @cDefaultOption,
      V_String9        = @cCheckUCCExistsInLoc,
      V_String10       = @cLoc,         
      --V_String11       = @nPrevStep,
      --V_String12       = @nPrevScreen,    
      V_String13       = @cSuggSKU,
      V_String14       = @cPickMethod,
      V_String15       = @cSKUDescr1,      
      V_String16       = @cSKUDescr2,    
      V_String17       = @cCCDetailKey,

      -- Module SP Variable V_String 20 - 26 -- 
      V_String20       = @cInUCCCount,
      --V_String21       = @nSumUCCCount,
      --V_String22       = @nUCCCounter,
      
      --V_String27       = @nUCCQty,                          
      --V_String28       = @nActQTY,                    
      --V_String29       = @nRowID,                    
      --V_String30       = @nFromScn,         
      --V_String31       = @nFromStep,         
      V_String32       = @cAreakey,             
      V_String33       = @cTTMStrategykey,      
      V_String34       = @cTTMTasktype,         
      V_String35       = @cRefKey01,            
      V_String36       = @cRefKey02,           
      V_String37       = @cRefKey03,            
      V_String38       = @cRefKey04,           
      V_String39       = @cRefKey05,        
      
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