SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***********************************************************************************/
/* Store procedure: rdtfnc_Move_WorkOrder                                          */
/* Copyright      : IDS                                                            */
/* Written by: AQSACM                                                              */
/*                                                                                 */
/* Purpose:                                                                        */
/* Move partial or full QTY of a SKU from a LOC/ID to another LOC/ID               */
/* By Workorder no                                                                 */
/*                                                                                 */
/* Modifications log:                                                              */
/* Date       Rev  Author   Purposes                                               */
/* 2010-05-18 1.0  AQSACM   Created                                                */
/* 2010-06-16 1.1  AQSACM   Change Qty Convert  -- (AQSACM01)                      */
/* 2010-06-30 1.2  Vanessa  SOS#165789 Add Break Loop when QtyBal = 0 --(Vanessa01)*/
/* 2016-09-30 1.3  Ung      Performance tuning                                     */
/* 2018-11-02 1.4  TungGH   Performance                                            */
/***********************************************************************************/

CREATE  PROCEDURE	[RDT].[rdtfnc_Move_WorkOrder] (
	@nMobile		INT,
	@nErrNo		INT  OUTPUT,
	@cErrMsg	 NVARCHAR(	20) OUTPUT -- screen	limitation,	20	char max
) AS

SET NOCOUNT	ON	
SET QUOTED_IDENTIFIER OFF 
SET ANSI_NULLS	OFF

--	Misc variable
DECLARE 
	@nRowCount			INT, 
	@cChkFacility	 NVARCHAR(5), 
	@cCheckKit		 NVARCHAR(1),
	@cKitStatus		 NVARCHAR(10),
	@cKitStorerkey	 NVARCHAR(15), 
	@cExternKitKey	 NVARCHAR(20), 
	@cCorrectFromQTY NVARCHAR(20), 
	@dZero				DATETIME, 
	@cXML				NVARCHAR(4000), -- To allow double	byte data for e.g. SKU desc
	@dSearchLottable04	DATETIME,
	@b_Success			INT, 
	@n_err				INT, 
	@c_errmsg		 NVARCHAR(250)

SET @dZero = 0	--	1900-01-01
SET @cXML =	''

--	RDT.RDTMobRec variable
DECLARE 
	@nFunc				INT,
	@nScn				INT,
	@nStep				INT,
	@cLangCode		 NVARCHAR(	3),
	@nInputKey			INT,
	@nMenu				INT,					  
	@cStorerKey		 NVARCHAR(15),
	@cPackKey		 NVARCHAR(10),
	@cMUOM_Desc		 NVARCHAR(5),  -- Master	UOM desc
	@cFacility		 NVARCHAR(5),					  
	@cFromLOC		 NVARCHAR(10),	--	Searched	ID
	@cFromID		 NVARCHAR(18), 
	@cSKU			 NVARCHAR(20), 
	@cSKUDescr		 NVARCHAR(60), 
	@cLottableLabel02 NVARCHAR(20), 
	@cLottableLabel03 NVARCHAR(20), 
	@cLottableLabel04 NVARCHAR(20), 
	@cSearchLottable02 NVARCHAR(18), 
	@cSearchLottable03 NVARCHAR(18), 
	@cSearchLottable04 NVARCHAR(16), 
	@cLottable02	 NVARCHAR(18), 
	@cLottable03	 NVARCHAR(18), 
	@dLottable04		DATETIME,	 
	@cID			 NVARCHAR(18), -- Actual	moved	ID
	@cEUOM			 NVARCHAR(1),  -- Pref UOM 
	@cEUOM_Desc		 NVARCHAR(5),  -- Pref UOM desc
	@nQTY_Avail			INT,		  -- QTY	avail	in	master UOM
	@nMQTY_Avail		FLOAT,	  -- QTY	in	Pref UOM
	@nQTY_Move			INT,		  -- QTY	to	move,	in	master UOM
	@nMQTY_Move			FLOAT,	  -- QTY	to	move,	in	prefer UOM
	@cQTY_Avail		 NVARCHAR(18),	--QTY	in	Pref UOM
	@cQTY_Move		 NVARCHAR(18),	--	QTY to move, in prefer UOM
	@nSKUCnt				INT,
	@cAllowOverADJ	 NVARCHAR(1),
	@cToLOC			 NVARCHAR(10), 
	@cToID			 NVARCHAR(18),
	@cUserName		 NVARCHAR(18)
	
DECLARE	@cLottable01_Code	 NVARCHAR(	20),
	@cLottable02_Code	 NVARCHAR(	20),
	@cLottable03_Code	 NVARCHAR(	20),
	@cLottable04_Code	 NVARCHAR(	20),
	@cLottableLabel	 NVARCHAR(	20),
	@cPostLottable01	 NVARCHAR(	18), 
	@cListName			 NVARCHAR(	20),
	@cShort				 NVARCHAR(	10),
	@dPreLottable04		DATETIME, 
	@dPreLottable05		DATETIME,
	@dPostLottable05		DATETIME,
	@dTempLottable04		DATETIME,
	@dTempLottable05		DATETIME,
	@nCountLot				INT,
		
	@cInField01 NVARCHAR(	60),	 @cOutField01 NVARCHAR( 60),
	@cInField02 NVARCHAR(	60),	 @cOutField02 NVARCHAR( 60),
	@cInField03 NVARCHAR(	60),	 @cOutField03 NVARCHAR( 60),
	@cInField04 NVARCHAR(	60),	 @cOutField04 NVARCHAR( 60),
	@cInField05 NVARCHAR(	60),	 @cOutField05 NVARCHAR( 60),
	@cInField06 NVARCHAR(	60),	 @cOutField06 NVARCHAR( 60), 
	@cInField07 NVARCHAR(	60),	 @cOutField07 NVARCHAR( 60), 
	@cInField08 NVARCHAR(	60),	 @cOutField08 NVARCHAR( 60), 
	@cInField09 NVARCHAR(	60),	 @cOutField09 NVARCHAR( 60), 
	@cInField10 NVARCHAR(	60),	 @cOutField10 NVARCHAR( 60), 
	@cInField11 NVARCHAR(	60),	 @cOutField11 NVARCHAR( 60), 
	@cInField12 NVARCHAR(	60),	 @cOutField12 NVARCHAR( 60), 
	@cInField13 NVARCHAR(	60),	 @cOutField13 NVARCHAR( 60), 
	@cInField14 NVARCHAR(	60),	 @cOutField14 NVARCHAR( 60), 
	@cInField15 NVARCHAR(	60),	 @cOutField15 NVARCHAR( 60),

	@cFieldAttr01 NVARCHAR( 1),	@cFieldAttr02 NVARCHAR( 1),
	@cFieldAttr03 NVARCHAR( 1),	@cFieldAttr04 NVARCHAR( 1),
	@cFieldAttr05 NVARCHAR( 1),	@cFieldAttr06 NVARCHAR( 1),
	@cFieldAttr07 NVARCHAR( 1),	@cFieldAttr08 NVARCHAR( 1),
	@cFieldAttr09 NVARCHAR( 1),	@cFieldAttr10 NVARCHAR( 1),
	@cFieldAttr11 NVARCHAR( 1),	@cFieldAttr12 NVARCHAR( 1),
	@cFieldAttr13 NVARCHAR( 1),	@cFieldAttr14 NVARCHAR( 1),
	@cFieldAttr15 NVARCHAR( 1)

--	Load RDT.RDTMobRec
SELECT 
	@nFunc		 =	Func,
	@nScn			 =	Scn,
	@nStep		 =	Step,
	@nInputKey	 =	InputKey,
	@nMenu		 =	Menu,
	@cLangCode	 =	Lang_code,

	@cStorerKey	 =	StorerKey,
	@cFacility	 =	Facility,
	@cUserName	 =	UserName,
	@cFromLOC	 =	V_String1, 
	@cFromID		 =	V_String2, 
	@cSKU			 =	V_String3, 
	@cSKUDescr	 =	V_SKUDescr,	

	@cLottableLabel02	= V_LottableLabel02,	
	@cLottableLabel03	= V_LottableLabel03,	
	@cLottableLabel04	= V_LottableLabel04,	
	@cSearchLottable02 =	V_String4, 
	@cSearchLottable03 =	V_String5, 
	@cSearchLottable04 =	V_String6, 
	@cLottable02 =	V_Lottable02, 
	@cLottable03 =	V_Lottable03, 
	@dLottable04 =	V_Lottable04, 

	@cID			 =	V_ID,	
	@cEUOM		 =	V_UOM,	  -- Pref UOM
	@cEUOM_Desc	 =	V_String8, -- Pref UOM desc
	@cExternKitKey	 =	V_String9, -- @cExternKitKey
	@nQTY_Avail	 =	 CASE WHEN ISNUMERIC( V_String10) = 1 THEN V_String10 ELSE 0 END, --AQSACM01
	@cQTY_Avail	= V_String11,
	@nQTY_Move	 =	CASE WHEN ISNUMERIC( V_String12) = 1 THEN V_String12 ELSE 0 END,	--AQSACM01
	@cQTY_Move		= V_String13, 
	@cToLOC		 =	V_String14,	
	@cToID		 =	V_String15,	
	@cLottable02_Code	  = V_String16,
	@cLottable03_Code	  = V_String17,
	@cLottable04_Code	  = V_String18,
	@cPackKey			  = V_String19,
	@cMUOM_Desc			  = V_String20,

	@cInField01	= I_Field01,	@cOutField01 =	O_Field01,
	@cInField02	= I_Field02,	@cOutField02 =	O_Field02,
	@cInField03	= I_Field03,	@cOutField03 =	O_Field03, 
	@cInField04	= I_Field04,	@cOutField04 =	O_Field04, 
	@cInField05	= I_Field05,	@cOutField05 =	O_Field05, 
	@cInField06	= I_Field06,	@cOutField06 =	O_Field06, 
	@cInField07	= I_Field07,	@cOutField07 =	O_Field07, 
	@cInField08	= I_Field08,	@cOutField08 =	O_Field08, 
	@cInField09	= I_Field09,	@cOutField09 =	O_Field09, 
	@cInField10	= I_Field10,	@cOutField10 =	O_Field10, 
	@cInField11	= I_Field11,	@cOutField11 =	O_Field11, 
	@cInField12	= I_Field12,	@cOutField12 =	O_Field12, 
	@cInField13	= I_Field13,	@cOutField13 =	O_Field13, 
	@cInField14	= I_Field14,	@cOutField14 =	O_Field14, 
	@cInField15	= I_Field15,	@cOutField15 =	O_Field15,

	@cFieldAttr01	= FieldAttr01,		@cFieldAttr02	 =	FieldAttr02,
	@cFieldAttr03 =  FieldAttr03,		@cFieldAttr04	 =	FieldAttr04,
	@cFieldAttr05 =  FieldAttr05,		@cFieldAttr06	 =	FieldAttr06,
	@cFieldAttr07 =  FieldAttr07,		@cFieldAttr08	 =	FieldAttr08,
	@cFieldAttr09 =  FieldAttr09,		@cFieldAttr10	 =	FieldAttr10,
	@cFieldAttr11 =  FieldAttr11,		@cFieldAttr12	 =	FieldAttr12,
	@cFieldAttr13 =  FieldAttr13,		@cFieldAttr14	 =	FieldAttr14,
	@cFieldAttr15 =  FieldAttr15

FROM RDTMOBREC	(NOLOCK)
WHERE	Mobile =	@nMobile


IF	@nFunc =	517 -- Move	SKU (WorkOrder)
BEGIN
	--	Redirect	to	respective screen
	IF	@nStep =	0 GOTO Step_0	 -- Func	= Move SKU (lottable)
	IF	@nStep =	1 GOTO Step_1	 -- Scn = 2280. WorkOrder
	IF	@nStep =	2 GOTO Step_2	 -- Scn = 2281. FromLOC
	IF	@nStep =	3 GOTO Step_3	 -- Scn = 2282. FromID
	IF	@nStep =	4 GOTO Step_4	 -- Scn = 2283. SKU,	desc1, desc2
	IF	@nStep =	5 GOTO Step_5	 -- Scn = 2284. Lottable 2/3/4
	IF	@nStep =	6 GOTO Step_6	 -- Scn = 2285. UOM,	QTY
	IF	@nStep =	7 GOTO Step_7	 -- Scn = 2286. ToID
	IF	@nStep =	8 GOTO Step_8	 -- Scn = 2287. ToLOC
	IF	@nStep =	9 GOTO Step_9	 -- Scn = 2288. Message
END

RETURN -- Do nothing	if	incorrect step


/********************************************************************************
Step 0. func =	517. Menu
********************************************************************************/
Step_0:
BEGIN
	
	--	Set the entry point
	SET @nScn =	2280
	SET @nStep = 1

	--	Get prefer UOM
	 EXEC	RDT.rdt_STD_EventLog
	  @cActionType	= '1', 
	  @cUserID		= @cUserName,
	  @nMobileNo	= @nMobile,
	  @nFunctionID	= @nFunc,
	  @cFacility	= @cFacility,
	  @cStorerKey	= @cStorerkey,
	  @nStep       = @nStep

	--	Prep next screen var
	SET @cFromLOC = ''
	SET @cExternKitKey  = ''
	SET @cOutField01 = '' -- @cExternKitKey

	SET @cFieldAttr01	= '' 
	SET @cFieldAttr02	= ''
	SET @cFieldAttr03	= '' 
	SET @cFieldAttr04	= ''
	SET @cFieldAttr05	= '' 
	SET @cFieldAttr06	= ''
	SET @cFieldAttr07	= '' 
	SET @cFieldAttr08	= ''
	SET @cFieldAttr09	= ''
	SET @cFieldAttr10	= ''
	SET @cFieldAttr11	= '' 
	SET @cFieldAttr12	= ''
	SET @cFieldAttr13	= ''
	SET @cFieldAttr14	= ''
	SET @cFieldAttr15	= ''
END
GOTO Quit

/********************************************************************************
Step 1. Scn	= 2280. cExternKitKey
	cExternKitKey (field01,	input)
********************************************************************************/
Step_1:
BEGIN
	IF	@nInputKey = 1	--	Yes or Send
	BEGIN
		--	Screen mapping
		SET @cExternKitKey =	@cInField01

		--	Validate	blank
		IF	ISNULL(RTRIM(@cExternKitKey),	'') =	''
		BEGIN
		 SET @nErrNo =	69016
		 SET @cErrMsg = rdt.rdtgetmessage( 69016,	@cLangCode,	'DSP') --'WO needed'
		 GOTO	Step_1_Fail
		END

		--	Get Kit info
		SET @cCheckKit	 ='0'
		SET @cKitStatus =	'0'
		SET @cChkFacility	= ''
		SET @cKitStorerkey =	''

		SELECT @cCheckKit	= '1', @cKitStatus =	Status,
		@cChkFacility = ISNULL(RTRIM(Facility), ''),	@cKitStorerkey	= Storerkey
		FROM dbo.KIT (NOLOCK)
		WHERE	ExternKitKey =	@cExternKitKey

		--	Validate	LOC
		IF	ISNULL(RTRIM(@cCheckKit), '')	= '0'
		BEGIN
			SET @nErrNo	= 69017
			SET @cErrMsg =	rdt.rdtgetmessage( 69017, @cLangCode, 'DSP')	--'Invalid WO'
			GOTO Step_1_Fail
		END

		--	Validate	WorkOrder KIT.status	= 9
		IF	ISNULL(RTRIM(@cKitStatus),	'') =	'9'
		BEGIN
			SET @nErrNo	= 69018
			SET @cErrMsg =	rdt.rdtgetmessage( 69018, @cLangCode, 'DSP')	--'WO	closed'
			GOTO Step_1_Fail
		END

		--	Validate	WorkOrder KIT.status	= CANC
		IF	ISNULL(RTRIM(@cKitStatus),	'') =	'CANC'
		BEGIN
			SET @nErrNo	= 69019
			SET @cErrMsg =	rdt.rdtgetmessage( 69019, @cLangCode, 'DSP')	--'WO	cancelled'
			GOTO Step_1_Fail
		END



		
		--	Validate	Right(KIT.facility,2) =	10
		SET @cChkFacility = ISNULL(RTRIM(@cChkFacility),'')

		IF	RIGHT(@cChkFacility,2) <> '10'
		BEGIN
			SET @nErrNo	= 69020
			SET @cErrMsg =	rdt.rdtgetmessage( 69020, @cLangCode, 'DSP')	--'Non-manufac	WO'
			GOTO Step_1_Fail
		END		

		--	Validate	Kit's	facility
		IF	@cChkFacility <> @cFacility
		BEGIN
			SET @nErrNo	= 69021
			SET @cErrMsg =	rdt.rdtgetmessage( 69021, @cLangCode, 'DSP')	--'Invalid FAC'
			GOTO Step_1_Fail
		END

		--	Validate	Kit Storerkey
		IF	@cKitStorerkey	<>	@cStorerkey
		BEGIN
			SET @nErrNo	= 69022
			SET @cErrMsg =	rdt.rdtgetmessage( 69022, @cLangCode, 'DSP')	--'Invalid Storer'
			GOTO Step_1_Fail
		END

		--	Prep next screen var
		SET @cFromLOC = ''
		SET @cOutField01 = '' --@cFromLOC

		--	Go	to	next screen
		SET @nScn =	@nScn	+ 1
		SET @nStep = @nStep + 1
	END

	IF	@nInputKey = 0	--	Esc or No
	BEGIN
		EXEC RDT.rdt_STD_EventLog
		@cActionType =	'9', -- Sign Out function
		@cUserID		 =	@cUserName,
		@nMobileNo	 =	@nMobile,
		@nFunctionID =	@nFunc,
		@cFacility	 =	@cFacility,
		@cStorerKey	 =	@cStorerkey,
		@nStep       = @nStep

		--	Back to menu
		SET @nFunc = @nMenu
		SET @nScn  = @nMenu
		SET @nStep = 0
		SET @cOutField01 = ''

		SET @cFieldAttr01	= '' 
		SET @cFieldAttr02	= ''
		SET @cFieldAttr03	= '' 
		SET @cFieldAttr04	= ''
		SET @cFieldAttr05	= '' 
		SET @cFieldAttr06	= ''
		SET @cFieldAttr07	= '' 
		SET @cFieldAttr08	= ''
		SET @cFieldAttr09	= ''
		SET @cFieldAttr10	= ''
		SET @cFieldAttr11	= '' 
		SET @cFieldAttr12	= ''
		SET @cFieldAttr13	= ''
		SET @cFieldAttr14	= ''
		SET @cFieldAttr15	= ''
	END
	GOTO Quit

	Step_1_Fail:
	BEGIN
		SET @cExternKitKey =	''
		SET @cOutField01 = '' -- ExternKitKey
	END
END
GOTO Quit

/********************************************************************************
Step 2. Scn	= 2281. FromLOC
	FromLOC	(field01, input)
********************************************************************************/
Step_2:
BEGIN
	IF	@nInputKey = 1	--	Yes or Send
	BEGIN
		--	Screen mapping
		SET @cFromLOC = @cInField01

		--	Validate	blank
		IF	ISNULL(RTRIM(@cFromLOC), '') = ''
		BEGIN
			SET @nErrNo	= 69023
			SET @cErrMsg =	rdt.rdtgetmessage( 69023, @cLangCode, 'DSP')	--'LOC needed'
			GOTO Step_1_Fail
		END

		--	Get LOC info
		SELECT @cChkFacility	= Facility
		FROM dbo.LOC (NOLOCK)
		WHERE	LOC =	@cFromLOC

		--	Validate	LOC
		IF	@@ROWCOUNT = 0
		BEGIN
			SET @nErrNo	= 69024
			SET @cErrMsg =	rdt.rdtgetmessage( 69024, @cLangCode, 'DSP')	--'Invalid LOC'
			GOTO Step_2_Fail
		END

		--	Validate	LOC's	facility
		IF	@cChkFacility <> @cFacility
		BEGIN
			SET @nErrNo	= 69025
			SET @cErrMsg =	rdt.rdtgetmessage( 69025, @cLangCode, 'DSP')	--'Diff facility'
			GOTO Step_2_Fail
		END

		--	Prep next screen var
		SET @cFromID =	''
		SET @cOutField01 = @cFromLOC
		SET @cOutField02 = '' --@cFromID

		--	Go	to	next screen
		SET @nScn =	@nScn	+ 1
		SET @nStep = @nStep + 1
	END

	IF	@nInputKey = 0	--	Esc or No
	BEGIN
		--	Prep next screen var
		SET @cExternKitKey =	''
		SET @cOutField01 = ''

		SET @cFieldAttr01	= '' 
		SET @cFieldAttr02	= ''
		SET @cFieldAttr03	= '' 
		SET @cFieldAttr04	= ''
		SET @cFieldAttr05	= '' 
		SET @cFieldAttr06	= ''
		SET @cFieldAttr07	= '' 
		SET @cFieldAttr08	= ''
		SET @cFieldAttr09	= ''
		SET @cFieldAttr10	= ''
		SET @cFieldAttr11	= '' 
		SET @cFieldAttr12	= ''
		SET @cFieldAttr13	= ''
		SET @cFieldAttr14	= ''
		SET @cFieldAttr15	= ''

		--	Go	to	prev screen
		SET @nScn =	@nScn	- 1
		SET @nStep = @nStep - 1
	END
	GOTO Quit

	Step_2_Fail:
	BEGIN
		SET @cFromLOC = ''
		SET @cOutField01 = '' -- LOC
	END
END
GOTO Quit


/********************************************************************************
Step 3. Scn	= 2282. FromID
	FromLOC (field01)
	FromID  (field02,	input)
********************************************************************************/
Step_3:
BEGIN
	IF	@nInputKey = 1	--	Yes or Send
	BEGIN
		--	Screen mapping
		SET @cFromID =	@cInField02

		 -- Validate ID
		IF	ISNULL(RTRIM(@cFromID),	'') <> ''
		BEGIN
			--	Validate	ID	exist	in	from loc
			IF	NOT EXISTS ( SELECT 1 
			FROM dbo.LOTxLOCxID (NOLOCK)
			WHERE	StorerKey =	@cStorerKey
			AND LOC = @cFromLOC
			AND ID =	@cFromID)
			BEGIN
				SET @nErrNo	= 69026
				SET @cErrMsg =	rdt.rdtgetmessage( 69026, @cLangCode, 'DSP')	--'ID	not in LOC'
				GOTO Step_3_Fail
			END

			--	Validate	at	least	1 sku	on	ID	with type 'F'
			IF	NOT EXISTS ( SELECT 1 
			FROM dbo.KITDETAIL KITDETAIL (NOLOCK)	, dbo.LOTXLOCXID LOTXLOCXID (NOLOCK) 
			WHERE	KITDETAIL.StorerKey = @cStorerKey
			AND EXTERNKITKEY = @cExternKitKey
			AND KITDETAIL.StorerKey	= LOTXLOCXID.StorerKey
			AND KITDETAIL.SKU	= LOTXLOCXID.SKU
			AND KITDETAIL.TYPE =	'F'
			AND LOTXLOCXID.ID	= @cFromID
			)
			BEGIN
				SET @nErrNo	= 69027
				SET @cErrMsg =	rdt.rdtgetmessage( 69027, @cLangCode, 'DSP')	--'Invalid ID/SKU'
				GOTO Step_3_Fail
			END

			--Validate ID exists	in	LOTxLOCxID table and	have movable stock
			IF	NOT EXISTS ( SELECT 1 
			FROM dbo.LOTxLOCxID LOTxLOCxID (NOLOCK) ,	dbo.LOT LOT	(NOLOCK)	
			WHERE	LOTxLOCxID.StorerKey	= @cStorerKey
			AND LOTxLOCxID.StorerKey =	LOT.StorerKey
			AND LOTxLOCxID.SKU =	LOT.SKU
			AND LOTxLOCxID.LOT =	LOT.LOT
			AND LOC = @cFromLOC
			AND ID =	@cFromID
			AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYAllocated -	LOTxLOCxID.QTYPicked) >	0
			AND LOT.STATUS	<>	'HOLD'
			)
			BEGIN
				SET @nErrNo	= 69028
				SET @cErrMsg =	rdt.rdtgetmessage( 69028, @cLangCode, 'DSP')	--'Invalid ID'
				GOTO Step_3_Fail
			END
		END

		--	Prep next screen var
		SET @cOutField01 = @cFromLOC
		SET @cOutField02 = @cFromID
		SET @cOutField03 = '' 

		--	Go	to	next screen
		SET @nScn =	@nScn	+ 1
		SET @nStep = @nStep + 1
	END

	IF	@nInputKey = 0	--	Esc or No
	BEGIN
		--	Prep next screen var
		SET @cFromLOC = ''
		SET @cOutField01 = @cFromLOC

		SET @cFieldAttr01	= '' 
		SET @cFieldAttr02	= ''
		SET @cFieldAttr03	= '' 
		SET @cFieldAttr04	= ''
		SET @cFieldAttr05	= '' 
		SET @cFieldAttr06	= ''
		SET @cFieldAttr07	= '' 
		SET @cFieldAttr08	= ''
		SET @cFieldAttr09	= ''
		SET @cFieldAttr10	= ''
		SET @cFieldAttr11	= '' 
		SET @cFieldAttr12	= ''
		SET @cFieldAttr13	= ''
		SET @cFieldAttr14	= ''
		SET @cFieldAttr15	= ''

		--	Go	to	prev screen
		SET @nScn =	@nScn	- 1
		SET @nStep = @nStep - 1
	END
	GOTO Quit

	Step_3_Fail:
	BEGIN
		SET @cFromID  = ''
		SET @cOutField02 = '' -- ID
	END
END
GOTO Quit

/********************************************************************************
Step 4. scn	= 2283. SKU	screen
	FromLOC (field01)
	FromID  (field02)
	SKU	  (field03,	input)
********************************************************************************/
Step_4:
BEGIN
	IF	@nInputKey = 1	--	Yes or Send
	BEGIN
		--	Screen mapping
		SET @cSKU =	@cInField03

		--	Validate	blank
		IF	ISNULL(RTRIM(@cSKU),	'') =	''
		BEGIN
		SET @nErrNo	= 69029
		SET @cErrMsg =	rdt.rdtgetmessage( 69029, @cLangCode, 'DSP')	--'SKU needed'
		GOTO Step_4_Fail
		END

		--	Valid	SKU in KITDETAIL
		IF	NOT EXISTS ( SELECT 1 
		FROM dbo.KITDETAIL (NOLOCK)
		WHERE	StorerKey =	@cStorerKey
		AND EXTERNKITKEY = @cExternKitKey
		AND SKU = @cSKU
		AND TYPE	= 'F'
		)
		BEGIN
			SET @nErrNo	= 69030
			SET @cErrMsg =	rdt.rdtgetmessage( 69030, @cLangCode, 'DSP')	--'Invalid SKU'
			GOTO Step_4_Fail
		END

		EXEC [RDT].[rdt_GETSKUCNT]
		@cStorerKey	 =	@cStorerKey
		,@cSKU		  = @cSKU
		,@nSKUCnt	  = @nSKUCnt		 OUTPUT
		,@bSuccess	  = @b_Success		 OUTPUT
		,@nErr		  = @n_Err			 OUTPUT
		,@cErrMsg	  = @c_ErrMsg		 OUTPUT

		--	Validate	SKU/UPC
		IF	@nSKUCnt	= 0
		BEGIN
			SET @nErrNo	= 69030
			SET @cErrMsg =	rdt.rdtgetmessage( 69030, @cLangCode, 'DSP')	--'Invalid SKU'
			GOTO Step_4_Fail
		END

		EXEC [RDT].[rdt_GETSKU]
		@cStorerKey	 =	@cStorerKey
		,@cSKU		  = @cSKU			 OUTPUT
		,@bSuccess	  = @b_Success		 OUTPUT
		,@nErr		  = @n_Err			 OUTPUT
		,@cErrMsg	  = @c_ErrMsg		 OUTPUT
		
		--	Get QTY avail
		SET @nQTY_Avail =	0
		SELECT @nQTY_Avail =	SUM(LOTxLOCxID.QTY -	LOTxLOCxID.QTYAllocated	- LOTxLOCxID.QTYPicked)
		FROM dbo.LOTxLOCxID LOTxLOCxID (NOLOCK) ,	dbo.LOT LOT	(NOLOCK)	
		WHERE	LOTxLOCxID.StorerKey	= @cStorerKey
		AND LOTxLOCxID.StorerKey =	LOT.StorerKey
		AND LOTxLOCxID.SKU =	LOT.SKU
		AND LOTxLOCxID.LOT =	LOT.LOT
		AND LOTxLOCxID.SKU =	@cSKU
		AND LOC = @cFromLOC
		AND ID =	CASE WHEN @cFromID =	''	THEN ID ELSE @cFromID END
		AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYAllocated -	LOTxLOCxID.QTYPicked) >	0
		AND LOT.STATUS	<>	'HOLD'

		--	Validate	no	QTY
		IF	@nQTY_Avail	= 0 OR @nQTY_Avail IS NULL
		BEGIN
			SET @nErrNo	= 69031
			SET @cErrMsg =	rdt.rdtgetmessage( 69031, @cLangCode, 'DSP')	--'QTY not avail'
			GOTO Step_4_Fail
		END

		--	Get SKU info
		SELECT 
		@cSKUDescr = S.DescR, 
		@cPackKey =	Pack.Packkey,
		@cMUOM_Desc	= Pack.Packuom3,
		@cLottableLabel02	= IsNULL(( SELECT	C.[Description] FROM	dbo.CodeLKUP C	(NOLOCK)	WHERE	C.Code =	S.Lottable02Label	AND C.ListName	= 'LOTTABLE02'	AND C.Code <> ''), ''),	
		@cLottableLabel03	= IsNULL(( SELECT	C.[Description] FROM	dbo.CodeLKUP C	(NOLOCK)	WHERE	C.Code =	S.Lottable03Label	AND C.ListName	= 'LOTTABLE03'	AND C.Code <> ''), ''),	
		@cLottableLabel04	= IsNULL(( SELECT	C.[Description] FROM	dbo.CodeLKUP C	(NOLOCK)	WHERE	C.Code =	S.Lottable04Label	AND C.ListName	= 'LOTTABLE04'	AND C.Code <> ''), ''),
		@cLottable02_Code	= IsNULL(S.Lottable02Label, ''),
		@cLottable03_Code	= IsNULL(S.Lottable03Label, ''),
		@cLottable04_Code	= IsNULL(S.Lottable04Label, '')
		FROM dbo.SKU S	(NOLOCK)	
		INNER	JOIN dbo.Pack Pack (nolock) ON (S.PackKey	= Pack.PackKey)
		WHERE	StorerKey =	@cStorerKey
		AND SKU = @cSKU
		
		--	Disable lottable field
		IF	@cLottableLabel02	= ''
		BEGIN
			SET @cFieldAttr07	= 'O'	
		END

		IF	@cLottableLabel03	= ''
		BEGIN
			SET @cFieldAttr09	= 'O'	
		END

		IF	@cLottableLabel04	= ''
		BEGIN
			SET @cFieldAttr11	= 'O'
		END

		IF	(IsNULL(@cLottable02_Code,	'') <> '') OR (IsNULL(@cLottable03_Code, '')	<>	'') OR 
		(IsNULL(@cLottable04_Code,	'') <> '') 
		BEGIN

			--initiate @nCounter	= 1
			SET @nCountLot	= 1

			--retrieve value for	pre lottable02	- 04
			WHILE	@nCountLot <=3	--break the	loop when @nCount	> 3
			BEGIN
				IF	@nCountLot = 1	
				BEGIN
					SET @cListName	= 'Lottable02'
					SET @cLottableLabel = @cLottable02_Code
				END
				ELSE
				IF	@nCountLot = 2	
				BEGIN
					SET @cListName	= 'Lottable03'
					SET @cLottableLabel = @cLottable03_Code
				END
				ELSE
				IF	@nCountLot = 3	
				BEGIN
					SET @cListName	= 'Lottable04'
					SET @cLottableLabel = @cLottable04_Code
				END

				--	increase	counter by 1
				SET @nCountLot	= @nCountLot +	1
			END -- nCount
		END -- Lottable <> ''
		
		--	Prep next screen var
		SET @cOutField01 = @cFromLOC
		SET @cOutField02 = @cFromID
		SET @cOutField03 = @cSKU
		SET @cSearchLottable02 = ''
		SET @cSearchLottable03 = ''
		SET @cSearchLottable04 = ''
		SET @cOutField04 = SUBSTRING(	@cSKUDescr,	1,	20)	--	SKU desc	1
		SET @cOutField05 = SUBSTRING(	@cSKUDescr,	21, 20)	--	SKU desc	2
		SET @cOutField06 = CASE	WHEN @cLottableLabel02 = '' THEN	'Lottable02:' ELSE @cLottableLabel02 END
		SET @cOutField07 = ''  -- @cSearchLottable02
		SET @cOutField08 = CASE	WHEN @cLottableLabel03 = '' THEN	'Lottable03:' ELSE @cLottableLabel03 END
		SET @cOutField09 = ''  -- @cSearchLottable03
		SET @cOutField10 = CASE	WHEN @cLottableLabel04 = '' THEN	'Lottable04:' ELSE @cLottableLabel04 END
		SET @cOutField11 = ''  -- @cSearchLottable04

		--	Go	to	next screen
		SET @nScn =	@nScn	+ 1
		SET @nStep = @nStep + 1
	END

	IF	@nInputKey = 0	--	Esc or No
	BEGIN
		--	Prepare prev screen var
		SET @cFromID =	''
		SET @cOutField01 = @cFromLOC
		SET @cOutField02 = '' --@cFromID

		SET @cFieldAttr01	= '' 
		SET @cFieldAttr02	= ''
		SET @cFieldAttr03	= '' 
		SET @cFieldAttr04	= ''
		SET @cFieldAttr05	= '' 
		SET @cFieldAttr06	= ''
		SET @cFieldAttr07	= '' 
		SET @cFieldAttr08	= ''
		SET @cFieldAttr09	= ''
		SET @cFieldAttr10	= ''
		SET @cFieldAttr11	= '' 
		SET @cFieldAttr12	= ''
		SET @cFieldAttr13	= ''
		SET @cFieldAttr14	= ''
		SET @cFieldAttr15	= ''

		--	Go	to	prev screen
		SET @nScn =	@nScn	- 1
		SET @nStep = @nStep - 1
	END
	GOTO Quit

	Step_4_Fail:
	BEGIN
		--	Reset	this screen	var
		SET @cSKU =	''
		SET @cOutField03 = '' -- SKU
	END
END
GOTO Quit

/********************************************************************************
Step 5. scn	= 2284. Lottable
	FromLOC			 (field01)
	FromID			 (field02)
	SKU				 (field03)
	SKUDesc			 (field04, field05)
	LottableLabel02 (field06)
	Lottable02		 (field07)
	LottableLabel03 (field08)
	Lottable03		 (field09)
	LottableLabel04 (field10)
	Lottable04		 (field11)
********************************************************************************/
Step_5:
BEGIN
	IF	@nInputKey = 1	--	Yes or Send
	BEGIN
		--	Screen mapping
		SELECT @cSearchLottable02 = CASE	WHEN @cLottableLabel02 = '' THEN	''	ELSE @cInField07 END, 
		@cSearchLottable03 =	CASE WHEN @cLottableLabel03 =	''	THEN '' ELSE @cInField09 END,	
		@cSearchLottable04 =	CASE WHEN @cLottableLabel04 =	''	THEN '' ELSE @cInField11 END

		DECLARE @dtSearchLottable04 DATETIME

		SET @cPostLottable01	= ''
		SET @dPostLottable05	= 0

		SET @cFieldAttr01	= '' 
		SET @cFieldAttr02	= ''
		SET @cFieldAttr03	= '' 
		SET @cFieldAttr04	= ''
		SET @cFieldAttr05	= '' 
		SET @cFieldAttr06	= ''
		SET @cFieldAttr07	= '' 
		SET @cFieldAttr08	= ''
		SET @cFieldAttr09	= ''
		SET @cFieldAttr10	= ''
		SET @cFieldAttr11	= '' 
		SET @cFieldAttr12	= ''
		SET @cFieldAttr13	= ''
		SET @cFieldAttr14	= ''
		SET @cFieldAttr15	= ''

		--initiate @nCounter	= 1
		SET @nCountLot	= 1

		WHILE	@nCountLot < =	3
		BEGIN
			IF	@nCountLot = 1	
			BEGIN
				SET @cListName	= 'Lottable02'
				SET @cLottableLabel = @cLottable02_Code
			END
			ELSE
			IF	@nCountLot = 2	
			BEGIN
				SET @cListName	= 'Lottable03'
				SET @cLottableLabel = @cLottable03_Code
			END
			ELSE
			IF	@nCountLot = 3	
			BEGIN
				SET @cListName	= 'Lottable04'
				SET @cLottableLabel = @cLottable04_Code
			END

			--increase counter by 1
			SET @nCountLot	= @nCountLot +	1

		END -- end of while

		--	Lottable02 define	as	batchno,validate lottable02 not on hold in inventory
		IF	ISNULL(RTRIM(@cSearchLottable02),'') <> ''
		BEGIN
			IF	EXISTS( SELECT	1
			FROM dbo.LOT LOT (NOLOCK),dbo.LOTATTRIBUTE LOTATTRIBUTE (NOLOCK)
			WHERE	LOT.StorerKey = LOTATTRIBUTE.StorerKey
			AND LOT.SKU	= LOTATTRIBUTE.SKU
			AND LOT.LOT	= LOTATTRIBUTE.LOT
			AND LOT.StorerKey	= @cStorerKey
			AND LOT.SKU	= @cSKU
			AND LOTATTRIBUTE.Lottable02 =	@cSearchLottable02
			AND LOT.STATUS	= 'HOLD'	
			)
			BEGIN
				SET @nErrNo	= 69032
				SET @cErrMsg =	rdt.rdtgetmessage( 69032, @cLangCode, 'DSP')	--'IDSLot on hold'
				EXEC rdt.rdtSetFocusField @nMobile,	7 -- Lottable02
				GOTO Step_5_Fail
			END
		END

		--	Validate	lottable04
		IF	ISNULL(RTRIM(@cSearchLottable04),'') <> '' 
		BEGIN
			IF	RDT.rdtIsValidDate( @cSearchLottable04) =	0
			BEGIN
				SET @nErrNo	= 69033
				SET @cErrMsg =	rdt.rdtgetmessage( 69033, @cLangCode, 'DSP')	--'Invalid date'
				EXEC rdt.rdtSetFocusField @nMobile,	11	--	Lottable04
				GOTO Step_5_Fail
			END
		END

		SET @dSearchLottable04 = @cSearchLottable04 -- When blank, @dLottable04	= 0

		--	validate	lottable04(expired date) >= system date
		IF	ISNULL(RTRIM(@cSearchLottable04),'') <> '' 
		BEGIN
			IF	@dSearchLottable04 <	getdate()
			BEGIN
				SET @nErrNo	= 69034
				SET @cErrMsg =	rdt.rdtgetmessage( 69034, @cLangCode, 'DSP')	--'Batch	expired'
				EXEC rdt.rdtSetFocusField @nMobile,	11	--	Lottable04
				GOTO Step_5_Fail
			END
		END		
		
		--	Get SKU QTY
		SET @nQTY_Avail =	0 
		SELECT TOP 1
		@cID = LLI.ID,	
		@cLottable02 =	LA.Lottable02,	
		@cLottable03 =	LA.Lottable03,	
		@dLottable04 =	LA.Lottable04,	
		@nQTY_Avail	= SUM( LLI.QTY	- LLI.QTYAllocated -	LLI.QTYPicked)
		FROM dbo.LOTxLOCxID LLI(NOLOCK)
		INNER	JOIN dbo.LotAttribute LA (NOLOCK) ON (LLI.LOT =	LA.LOT)
		INNER	JOIN dbo.Lot LOT (NOLOCK) ON (LLI.LOT = LOT.LOT)
		WHERE	LLI.StorerKey = @cStorerKey
		AND LLI.SKU	= @cSKU
		AND LLI.LOC	= @cFromLOC
		AND (LLI.QTY -	LLI.QTYAllocated - LLI.QTYPicked) >	0
		AND LLI.ID = CASE	WHEN @cFromID = '' THEN	LLI.ID ELSE	@cFromID	END
		AND LA.Lottable02	= CASE WHEN	@cSearchLottable02 =	''	THEN LA.Lottable02 ELSE	@cSearchLottable02 END
		AND LA.Lottable03	= CASE WHEN	@cSearchLottable03 =	''	THEN LA.Lottable03 ELSE	@cSearchLottable03 END
		--	NULL column	cannot be compared, even if SET ANSI_NULLS OFF
		AND IsNULL(	LA.Lottable04,	0)	= CASE WHEN	@dSearchLottable04 =	0 THEN IsNULL(	LA.Lottable04,	0)	ELSE @dSearchLottable04	END
		AND (LA.Lottable04 >	getdate() OR LA.Lottable04	IS	NULL)
		AND LOT.STATUS	<>	'HOLD'
		GROUP	BY	LLI.ID, LA.Lottable02, LA.Lottable03, LA.Lottable04
		ORDER	BY	LLI.ID, LA.Lottable02, LA.Lottable03, LA.Lottable04

		IF	@nQTY_Avail	= 0 OR @nQTY_Avail IS NULL
		BEGIN
			SET @nErrNo	= 69035
			SET @cErrMsg =	rdt.rdtgetmessage( 69035, @cLangCode, 'DSP')	--'No	QTY to move'
			GOTO Step_5_Fail
		END
		
		--	Convert to prefer	UOM QTY
		SET @cEUOM_Desc =	''
		SET @nMQTY_Avail = @nQTY_Avail 

		--	Prepare next screen var
		SET @nMQTY_Move =	0
		SET @cOutField01 = @cID
		SET @cOutField02 = CASE	WHEN @cLottableLabel02 = '' THEN	'Lottable02:' ELSE @cLottableLabel02 END
		SET @cOutField03 = @cLottable02
		SET @cOutField04 = CASE	WHEN @cLottableLabel03 = '' THEN	'Lottable03:' ELSE @cLottableLabel03 END
		SET @cOutField05 = @cLottable03
		SET @cOutField06 = CASE	WHEN @cLottableLabel04 = '' THEN	'Lottable04:' ELSE @cLottableLabel04 END
		SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)

		SET @cEUOM_Desc =	''
		SELECT @cEUOM_Desc =	CASE @cEUOM
		WHEN '1'	THEN PACK.PackUOM4
		WHEN '2'	THEN PACK.PackUOM1
		WHEN '3'	THEN PACK.PackUOM2 
		WHEN '4'	THEN PACK.PackUOM8
		WHEN '5'	THEN PACK.PackUOM9
		WHEN '6'	THEN PACK.PackUOM3
		ELSE '' END
		FROM dbo.SKU SKU (NOLOCK)
		INNER	JOIN dbo.PACK PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
		WHERE	SKU.StorerKey = @cStorerKey
		AND	SKU.SKU = @cSKU

		SET @b_success	= 0
		EXECUTE dbo.nspUOMCONV
		@n_fromqty	  = @nQTY_Avail,
		@c_fromuom	  = @cMUOM_Desc,
		@c_touom		  = @cEUOM_Desc,
		@c_packkey	  = @cPackkey,
		@n_toqty		  = @nMQTY_Avail	OUTPUT,
		@b_Success	  = @b_Success		OUTPUT,
		@n_err		  = @nErrNo			OUTPUT,
		@c_errmsg	  = @cErrMsg		OUTPUT

		--	avoid	display 1e7	(exponent)
		SET @cQTY_Avail =	CAST (CAST (@nMQTY_Avail AS DECIMAL(18,8)) AS NVARCHAR(18))
		SET @cQTY_Avail =	REPLACE(RTRIM(REPLACE(@cQTY_Avail, '0', ' ')), ' ', '0')
		SET @cQTY_Avail =	REPLACE(RTRIM(REPLACE(@cQTY_Avail, '.', ' ')), ' ', '.')
		SET @cQTY_Avail =	SUBSTRING(@cQTY_Avail, 1, 10)

		SET @cOutField08 = @cEUOM_Desc -- @cEUOM_Desc
		SET @cOutField09 = @cQTY_Avail
		SET @cOutField10 = '' -- @nMQTY_Move

		--	Goto next screen
		SET @nScn =	@nScn	+ 1
		SET @nStep = @nStep + 1

		--bug	fix -	to	reset	the input value scanned
		SET @cInField10 =	''

		GOTO Quit
	END

	IF	@nInputKey = 0	--	Esc or No
	BEGIN
		SET @cSKU =	''
		SET @cSKUDescr	= ''
		SET @cOutField01 = @cFromLOC
		SET @cOutField02 = @cFromID
		SET @cOutField03 = '' -- SKU
		SET @cOutField04 = '' -- SKU desc 1
		SET @cOutField05 = '' -- SKU desc 2

		SET @cFieldAttr01	= '' 
		SET @cFieldAttr02	= ''
		SET @cFieldAttr03	= '' 
		SET @cFieldAttr04	= ''
		SET @cFieldAttr05	= '' 
		SET @cFieldAttr06	= ''
		SET @cFieldAttr07	= '' 
		SET @cFieldAttr08	= ''
		SET @cFieldAttr09	= ''
		SET @cFieldAttr10	= ''
		SET @cFieldAttr11	= '' 
		SET @cFieldAttr12	= ''
		SET @cFieldAttr13	= ''
		SET @cFieldAttr14	= ''
		SET @cFieldAttr15	= ''

		--	Go	back to prev screen
		SET @nScn =	@nScn	- 1
		SET @nStep = @nStep - 1
	END
	GOTO Quit

	Step_5_Fail:
	BEGIN

		SET @cFieldAttr07	= '' 
		SET @cFieldAttr09	= ''
		SET @cFieldAttr11	= '' 

		IF	@cLottableLabel02	= ''
		BEGIN
			SET @cFieldAttr07	= 'O'	
		END
		ELSE
		BEGIN
			SET @cOutField07 = ISNULL(@cSearchLottable02, '') 
		END 

		IF	@cLottableLabel03	= ''
		BEGIN
			SET @cFieldAttr09	= 'O'	
		END
		ELSE
		BEGIN
			SET @cOutField09 = ISNULL(@cSearchLottable03, '') 
		END 

		IF	@cLottableLabel04	= ''
		BEGIN
			SET @cFieldAttr11	= 'O'	
		END
		ELSE
		BEGIN
			SET @cOutField11 = ISNULL(@cSearchLottable04, '')
		END 
		
		--	Remain in current	screen
		SET @cOutField01 = @cFromLOC
		SET @cOutField02 = @cFromID
		SET @cOutField03 = @cSKU
		SET @cOutField04 = SUBSTRING(	@cSKUDescr,	1,	20)	--	SKU desc	1
		SET @cOutField05 = SUBSTRING(	@cSKUDescr,	21, 20)	--	SKU desc	2
		SET @cOutField06 = CASE	WHEN @cLottableLabel02 = '' THEN	'Lottable02:' ELSE @cLottableLabel02 END
		SET @cOutField08 = CASE	WHEN @cLottableLabel03 = '' THEN	'Lottable03:' ELSE @cLottableLabel03 END
		SET @cOutField10 = CASE	WHEN @cLottableLabel04 = '' THEN	'Lottable04:' ELSE @cLottableLabel04 END
	END
END
GOTO Quit

/********************************************************************************
Step 6. Scn	= 2285. QTY	screen
	ID					 (field01)
	LottableLabel02 (field02)
	Lottable02		 (field03)
	LottableLabel03 (field04)
	Lottable03		 (field05)
	LottableLabel04 (field06)
	Lottable04		 (field07)
	UOM				 (field08)
	QTY AVL			 (field09)
	QTY MV			 (field10, input)
********************************************************************************/
Step_6:
BEGIN
	IF	@nInputKey = 1	--	Yes or Send
	BEGIN
		DECLARE @cMQTY NVARCHAR(10)
		DEClARE @n_KitDTQty INT

		SET @cFieldAttr01	= '' 
		SET @cFieldAttr02	= ''
		SET @cFieldAttr03	= '' 
		SET @cFieldAttr04	= ''
		SET @cFieldAttr05	= '' 
		SET @cFieldAttr06	= ''
		SET @cFieldAttr07	= '' 
		SET @cFieldAttr08	= ''
		SET @cFieldAttr09	= ''
		SET @cFieldAttr10	= ''
		SET @cFieldAttr11	= '' 
		SET @cFieldAttr12	= ''
		SET @cFieldAttr13	= ''
		SET @cFieldAttr14	= ''
		SET @cFieldAttr15	= ''

		--	Screen mapping

		SET @cMQTY = IsNULL(	RTRIM(@cInField10), '')
		SET @cEUOM_Desc =	IsNULL( RTRIM(@cInField08), '')
		  -- Retain	the key-in value
		SET @cOutField10 = @cInField10 -- Master QTY

		--	Blank	to	iterate lottables
		IF	@cMQTY =	''
		BEGIN
			DECLARE @cNextID NVARCHAR( 18)
			DECLARE @cNextLottable02 NVARCHAR( 18)
			DECLARE @cNextLottable03 NVARCHAR( 18)
			DECLARE @dNextLottable04 DATETIME
			DECLARE @nNextQTY_Avail	INT

			SET @dSearchLottable04 = @cSearchLottable04 

			--	Get SKU QTY
			SELECT TOP 1
			@cNextID	= LLI.ID, 
			@cNextLottable02 = LA.Lottable02, 
			@cNextLottable03 = LA.Lottable03, 
			@dNextLottable04 = LA.Lottable04, 
			@nNextQTY_Avail =	SUM( LLI.QTY -	LLI.QTYAllocated - LLI.QTYPicked)
			FROM dbo.LOTxLOCxID LLI(NOLOCK)
			INNER	JOIN dbo.LotAttribute LA (NOLOCK) ON (LLI.LOT =	LA.LOT)
			INNER	JOIN dbo.Lot LOT (NOLOCK) ON (LLI.LOT = LOT.LOT)
			WHERE	LLI.StorerKey = @cStorerKey
			AND LLI.SKU	= @cSKU
			AND LLI.LOC	= @cFromLOC
			AND (LLI.QTY -	LLI.QTYAllocated - LLI.QTYPicked) >	0
			AND LLI.ID = CASE	WHEN @cFromID = '' THEN	LLI.ID ELSE	@cFromID	END
			AND LA.Lottable02	= CASE WHEN	@cSearchLottable02 =	''	THEN LA.Lottable02 ELSE	@cSearchLottable02 END
			AND LA.Lottable03	= CASE WHEN	@cSearchLottable03 =	''	THEN LA.Lottable03 ELSE	@cSearchLottable03 END
			--	NULL column	cannot be compared, even if SET ANSI_NULLS OFF
			AND IsNULL(	LA.Lottable04,	0)	= CASE WHEN	@dSearchLottable04 =	0 THEN IsNULL(	LA.Lottable04,	0)	ELSE @dSearchLottable04	END
			AND (LLI.ID	+ LA.Lottable02 +	LA.Lottable03 + CONVERT( NVARCHAR( 10),	IsNULL( LA.Lottable04, @dZero), 120)) >
			(@cID	+ @cLottable02	 +	@cLottable03  + CONVERT( NVARCHAR( 10),	IsNULL( @dLottable04,  @dZero), 120))
			AND (LA.Lottable04 >	getdate() OR LA.Lottable04	IS	NULL)
			AND LOT.STATUS	<>	'HOLD'
			GROUP	BY	LLI.ID, LA.Lottable02, LA.Lottable03, LA.Lottable04
			ORDER	BY	LLI.ID, LA.Lottable02, LA.Lottable03, LA.Lottable04

			--	Validate	if	any result
			IF	IsNULL( @nNextQTY_Avail, 0) =	0
			BEGIN
				SET @nErrNo	= 69036
				SET @cErrMsg =	rdt.rdtgetmessage( 69036, @cLangCode, 'DSP')	--'No	record'
				GOTO Step_6_Fail
			END

			--	Set next	record values
			SET @cID	= @cNextID
			SET @cLottable02 = @cNextLottable02
			SET @cLottable03 = @cNextLottable03
			SET @dLottable04 = @dNextLottable04
			SET @nQTY_Avail =	@nNextQTY_Avail

			--	Convert to prefer	UOM QTY to float for	conversion
			SET @nMQTY_Avail = @nQTY_Avail 

			--	Prepare next screen var
			--SET	@nPQTY_Move	= 0
			SET @nMQTY_Move =	0
			SET @cOutField01 = @cID
			SET @cOutField02 = CASE	WHEN @cLottableLabel02 = '' THEN	'Lottable02:' ELSE @cLottableLabel02 END
			SET @cOutField03 = @cLottable02
			SET @cOutField04 = CASE	WHEN @cLottableLabel03 = '' THEN	'Lottable03:' ELSE @cLottableLabel03 END
			SET @cOutField05 = @cLottable03
			SET @cOutField06 = CASE	WHEN @cLottableLabel04 = '' THEN	'Lottable04:' ELSE @cLottableLabel04 END
			SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)
			SET @cEUOM_Desc =	''
 
			SELECT @cEUOM_Desc =	CASE @cEUOM
			WHEN '1'	THEN PACK.PackUOM4
			WHEN '2'	THEN PACK.PackUOM1
			WHEN '3'	THEN PACK.PackUOM2 
			WHEN '4'	THEN PACK.PackUOM8
			WHEN '5'	THEN PACK.PackUOM9
			WHEN '6'	THEN PACK.PackUOM3
			ELSE '' END
			FROM dbo.SKU SKU (NOLOCK)
			INNER	JOIN dbo.PACK PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
			WHERE	SKU.StorerKey = @cStorerKey
			AND	SKU.SKU = @cSKU

			SET @b_success	= 0
			EXECUTE dbo.nspUOMCONV
			@n_fromqty	  = @nQTY_Avail,
			@c_fromuom	  = @cMUOM_Desc,
			@c_touom		  = @cEUOM_Desc,
			@c_packkey	  = @cPackkey,
			@n_toqty		  = @nMQTY_Avail	OUTPUT,
			@b_Success	  = @b_Success		OUTPUT,
			@n_err		  = @nErrNo			OUTPUT,
			@c_errmsg	  = @cErrMsg		OUTPUT

			SET @cQTY_Avail =	CAST (CAST (@nMQTY_Avail AS DECIMAL(18,8)) AS NVARCHAR(18))
			SET @cQTY_Avail =	REPLACE(RTRIM(REPLACE(@cQTY_Avail, '0', ' ')), ' ', '0')
			SET @cQTY_Avail =	REPLACE(RTRIM(REPLACE(@cQTY_Avail, '.', ' ')), ' ', '.')
			SET @cQTY_Avail =	SUBSTRING(@cQTY_Avail,1,10)
							
			SET @cOutField08 = @cEUOM_Desc -- @cEUOM_Desc
			SET @cOutField09 = @cQTY_Avail

			GOTO Quit
		END

		IF	ISNULL(RTRIM(@cEUOM_Desc),'')	= ''
		BEGIN
			SET @nErrNo	= 69037
			SET @cErrMsg =	rdt.rdtgetmessage( 69037, @cLangCode, 'DSP')	--'UOM required'
			EXEC rdt.rdtSetFocusField @nMobile,	8 -- PQTY
			GOTO Step_6_Fail
		END

		IF	NOT EXISTS (
		SELECT 1	FROM dbo.SKU SKU (NOLOCK)
		INNER	JOIN dbo.PACK PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
		WHERE	SKU.StorerKey = @cStorerKey
		AND	SKU.SKU = @cSKU 
		AND @cEUOM_Desc IN (PACK.PackUOM1, PACK.PackUOM2, PACK.PackUOM3, PACK.PackUOM4, 
		PACK.PackUOM8,	PACK.PackUOM9 )
		)
		BEGIN
			 SET @nErrNo =	69038
			 SET @cErrMsg = rdt.rdtgetmessage( 69038,	@cLangCode,	'DSP') --'Invalid	UOM'
			 EXEC	rdt.rdtSetFocusField	@nMobile, 8	--	PQTY
			 GOTO	Step_6_Fail
		END


		--	Validate	MQTY
		IF	@cMQTY  = '' SET @cMQTY	 =	'0' -- Blank taken as zero	me	modify lack	negative
		IF	ISNUMERIC(@cMQTY)	<>	1
		BEGIN
			SET @nErrNo	= 69039
			SET @cErrMsg =	rdt.rdtgetmessage( 69039, @cLangCode, 'DSP')	--'Invalid QTY'
			EXEC rdt.rdtSetFocusField @nMobile,	10	--	PQTY
			GOTO Step_6_Fail
		END
		
		--	Calc total QTY	in	master UOM
		SET @cCorrectFromQTY	= ''
		SET @nMQTY_Move =	CAST(	@cMQTY AS FLOAT)
		IF	@nMQTY_Move	< 0
		BEGIN
			SET @nErrNo	= 69039
			SET @cErrMsg =	rdt.rdtgetmessage( 69039, @cLangCode, 'DSP')	--'Invalid QTY'
			EXEC rdt.rdtSetFocusField @nMobile,	10	--	PQTY
			GOTO Step_6_Fail
		END

		IF	@nMQTY_Move	= 0
		BEGIN
			SET @nErrNo	= 69040
			SET @cErrMsg =	rdt.rdtgetmessage( 69040, @cLangCode, 'DSP')	--'QTY needed'
			EXEC rdt.rdtSetFocusField @nMobile,	10	--	PQTY
			GOTO Step_6_Fail
		END
		

		  -- UOM	XX	to	BASE UOM
		SET @b_success	= 0
		EXECUTE dbo.nspUOMCONV
		@n_fromqty	  = @nMQTY_Move,
		@c_fromuom	  = @cEUOM_Desc,
		@c_touom		  = @cMUOM_Desc,
		@c_packkey	  = @cPackkey,
		@n_toqty		  = @nQTY_Move	OUTPUT,
		@b_Success	  = @b_Success	OUTPUT,
		@n_err		  = @nErrNo		OUTPUT,
		@c_errmsg	  = @cErrMsg	OUTPUT

		--If QTY	after	conversion to master	unit is < 1, prompt UOMConvQTY <	1
		IF	@nQTY_Move < 1
		BEGIN
			SET @nErrNo	= 69041
			SET @cErrMsg =	rdt.rdtgetmessage( 69041, @cLangCode, 'DSP')	--'UOMConvQTY < 1'
			EXEC rdt.rdtSetFocusField @nMobile,	10	--	PQTY
			GOTO Step_6_Fail
		END

		--	Validate	QTY to move	more than QTY avail
		IF	@nQTY_Move > @nQTY_Avail
		BEGIN
			SET @nErrNo	= 69042
			SET @cErrMsg =	rdt.rdtgetmessage( 69042, @cLangCode, 'DSP')	--'QTYAVL NotEnuf'
			GOTO Step_6_Fail
		END

		--	BASE UOM	to	UOM XX, Get	Correct Figure
		SET @b_success	= 0
		EXECUTE dbo.nspUOMCONV
		@n_fromqty	  = @nQTY_Move,
		@c_fromuom	  = @cMUOM_Desc,
		@c_touom		  = @cEUOM_Desc,
		@c_packkey	  = @cPackkey,
		@n_toqty		  = @nMQTY_Move	OUTPUT,
		@b_Success	  = @b_Success		OUTPUT,
		@n_err		  = @nErrNo			OUTPUT,
		@c_errmsg	  = @cErrMsg		OUTPUT
		
		SET	@cQTY_Move = CAST	(CAST	(@nMQTY_Move AS DECIMAL(18,8)) as NVARCHAR(18))
		SET @cQTY_Move	= REPLACE(RTRIM(REPLACE(@cQTY_Move,	'0', ' ')),	' ', '0')
		SET @cQTY_Move	= REPLACE(RTRIM(REPLACE(@cQTY_Move,	'.', ' ')),	' ', '.')
		SET @cQTY_Move	= SUBSTRING(@cQTY_Move,	1,	10)

		--RDTGetConfig	'Allow_WOOverQty'
		SET @cAllowOverADJ =	'0'
		SET @cAllowOverADJ =	rdt.RDTGetConfig(@nFunc, 'Allow_WOOverQty', @cStorerkey)	--	Parse	in	Function
		--If QTY	MV	more than KITDETAIL.ExpectedQty,	prompt í░WARNING:	QTY>KITQTYí▒ as warning
		SET @n_KitDTQty =	0
	
		SELECT @n_KitDTQty =	ExpectedQty
		FROM dbo.KITDETAIL KITDETAIL(NOLOCK)
		WHERE	SKU =@cSKU
		AND STORERKEY = @cStorerKey
		AND EXTERNKITKEY = @cExternKitKey
		
		IF	@nQTY_Move > @n_KitDTQty 
		BEGIN
			IF	@cAllowOverADJ	= '1'
			BEGIN
				SET @cOutField01 = 'WARNING: QTY>KITQTY'
			END
			ELSE
			BEGIN
				SET @nErrNo	= 69043
				SET @cErrMsg =	rdt.rdtgetmessage( 69043, @cLangCode, 'DSP')	--'QTY >	KITQTY'
				GOTO Step_6_Fail
			END
		END
		ELSE
			SET @cOutField01 = ''
		
		--	Prep ToID screen var
		SET @cFromID =	@cID
		SET @cToID = ''

		SET @cOutField02 = @cFromLOC
		SET @cOutField03 = @cFromID
		SET @cOutField04 = @cSKU
		SET @cOutField05 = SUBSTRING(	@cSKUDescr,	1,	20)	--	SKU desc	1
		SET @cOutField06 = SUBSTRING(	@cSKUDescr,	21, 20)	--	SKU desc	2
		SET @cOutField07 = @cEUOM_Desc -- @cEUOM_Desc
		SET @cOutField08 = @cQTY_Move	--	cast(@nMQTY_Move as NVARCHAR(20))
		SET @cOutField09 = @cFromID

		--	Go	to	ToID screen
		SET @nScn =	@nScn	+ 1
		SET @nStep = @nStep + 1

	END

	IF	@nInputKey = 0	--	Esc or No
	BEGIN
		--	Init next screen var
		SET @cFieldAttr07	= '' 
		SET @cFieldAttr09	= ''
		SET @cFieldAttr11	= '' 

		--	Disable lottable field
		IF	@cLottableLabel02	= ''
		BEGIN
			SET @cFieldAttr07	= 'O'	
		END

		IF	@cLottableLabel03	= ''
		BEGIN
			SET @cFieldAttr09	= 'O'	
		END

		IF	@cLottableLabel04	= ''
		BEGIN
			SET @cFieldAttr11	= 'O'	
		END
		
		--	Prep next screen var
		SET @cOutField01 = @cFromLOC
		SET @cOutField02 = @cFromID
		SET @cOutField03 = @cSKU
		SET @cSearchLottable02 = ''
		SET @cSearchLottable03 = ''
		SET @cSearchLottable04 = ''
		SET @cOutField04 = SUBSTRING(	@cSKUDescr,	1,	20)	--	SKU desc	1
		SET @cOutField05 = SUBSTRING(	@cSKUDescr,	21, 20)	--	SKU desc	2
		SET @cOutField06 = CASE	WHEN @cLottableLabel02 = '' THEN	'Lottable02:' ELSE @cLottableLabel02 END
		SET @cOutField07 = '' -- @cSearchLottable02
		SET @cOutField08 = CASE	WHEN @cLottableLabel03 = '' THEN	'Lottable03:' ELSE @cLottableLabel03 END
		SET @cOutField09 = '' -- @cSearchLottable03
		SET @cOutField10 = CASE	WHEN @cLottableLabel04 = '' THEN	'Lottable04:' ELSE @cLottableLabel04 END
		SET @cOutField11 = '' -- @cSearchLottable04

		--	Go	to	QTY screen
		SET @nScn =	@nScn	- 1
		SET @nStep = @nStep - 1
	END
	GOTO Quit

	Step_6_Fail:
	SET @cOutField10 =  ''
	SET @cFieldAttr10	= ''
END
GOTO Quit

/********************************************************************************
Step 7. Scn	= 2286. ToID
	WarnMsg (field01)
	FromLOC (field02)
	FromID  (field03)
	SKU	  (field04)
	Desc1	  (field05)
	Desc2	  (field06)
	UOM	  (field07)
	QTY MV  (field08)
	ToID	  (field09,	input)
********************************************************************************/
Step_7:
BEGIN
	IF	@nInputKey = 1	--	Yes or Send
	BEGIN
		--	Screen mapping
		SET @cToID = @cInField09

		SET @cFieldAttr01	= '' 
		SET @cFieldAttr02	= ''
		SET @cFieldAttr03	= '' 
		SET @cFieldAttr04	= ''
		SET @cFieldAttr05	= '' 
		SET @cFieldAttr06	= ''
		SET @cFieldAttr07	= '' 
		SET @cFieldAttr08	= ''
		SET @cFieldAttr09	= ''
		SET @cFieldAttr10	= ''
		SET @cFieldAttr11	= '' 
		SET @cFieldAttr12	= ''
		SET @cFieldAttr13	= ''
		SET @cFieldAttr14	= ''
		SET @cFieldAttr15	= ''

		--	Prep ToLOC screen	var
		SET @cToLOC	= ''
		SET @cOutField01 = @cFromLOC
		SET @cOutField02 = @cID
		SET @cOutField03 = @cSKU
		SET @cOutField04 = SUBSTRING(	@cSKUDescr,	1,	20)	--	SKU desc	1
		SET @cOutField05 = SUBSTRING(	@cSKUDescr,	21, 20)	--	SKU desc	2

		 SET @cOutField06	= @cEUOM_Desc -- @cPUOM_Desc
		 SET @cOutField07	= @cQTY_Move

		SET @cOutField08 =  @cToID
		SET @cOutField09 = '' -- @cToLOC


		--	Go	to	next screen
		SET @nScn =	@nScn	+ 1
		SET @nStep = @nStep + 1
	END

	IF	@nInputKey = 0	--	Esc or No
	BEGIN

		SET @cFieldAttr01	= '' 
		SET @cFieldAttr02	= ''
		SET @cFieldAttr03	= '' 
		SET @cFieldAttr04	= ''
		SET @cFieldAttr05	= '' 
		SET @cFieldAttr06	= ''
		SET @cFieldAttr07	= '' 
		SET @cFieldAttr08	= ''
		SET @cFieldAttr09	= ''
		SET @cFieldAttr10	= ''
		SET @cFieldAttr11	= '' 
		SET @cFieldAttr12	= ''
		SET @cFieldAttr13	= ''
		SET @cFieldAttr14	= ''
		SET @cFieldAttr15	= ''

		--	Prepare next screen var
		SET @cOutField01 = @cID
		SET @cOutField02 = CASE	WHEN @cLottableLabel02 = '' THEN	'Lottable02:' ELSE @cLottableLabel02 END
		SET @cOutField03 = @cLottable02
		SET @cOutField04 = CASE	WHEN @cLottableLabel03 = '' THEN	'Lottable03:' ELSE @cLottableLabel03 END
		SET @cOutField05 = @cLottable03
		SET @cOutField06 = CASE	WHEN @cLottableLabel04 = '' THEN	'Lottable04:' ELSE @cLottableLabel04 END
		SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)

		SET @cOutField08 = @cEUOM_Desc -- @cEUOM_Desc

		SET @nMQTY_Avail = @nQTY_Avail 
		SET @b_success	= 0
		EXECUTE dbo.nspUOMCONV
		@n_fromqty	  = @nQTY_Avail,
		@c_fromuom	  = @cMUOM_Desc,
		@c_touom		  = @cEUOM_Desc,
		@c_packkey	  = @cPackkey,
		@n_toqty		  = @nMQTY_Avail	OUTPUT,
		@b_Success	  = @b_Success		OUTPUT,
		@n_err		  = @nErrNo			OUTPUT,
		@c_errmsg	  = @cErrMsg		OUTPUT

		SET @cQTY_Avail =	CAST (CAST (@nMQTY_Avail AS DECIMAL(18,8)) AS NVARCHAR(18))
		SET @cQTY_Avail =	REPLACE(RTRIM(REPLACE(@cQTY_Avail, '0', ' ')), ' ', '0')
		SET @cQTY_Avail =	REPLACE(RTRIM(REPLACE(@cQTY_Avail, '.', ' ')), ' ', '.')
		SET @cQTY_Avail =	substring(@cQTY_Avail,1,10)

		SET @cOutField09 = @cQTY_Avail --CAST(	@nMQTY_Avail AS NVARCHAR(20))
		SET @cOutField10 = @cQTY_Move

		--	Go	to	QTY screen
		SET @nScn =	@nScn	- 1
		SET @nStep = @nStep - 1		  
	END
END
GOTO Quit

/********************************************************************************
Step 8. Scn	= 2287. ToLOC
	FromLOC (field01)
	FromID  (field02)
	SKU	  (field03)
	Desc1	  (field04)
	Desc2	  (field05)
	UOM	  (field06)
	QTY MV  (field07)
	ToID	  (field08)
	ToLOC	  (field09,	input)
********************************************************************************/
Step_8:
BEGIN
	IF	@nInputKey = 1	--	Yes or Send
	BEGIN
		--	Screen mapping
		SET @cToLOC	= @cInField09

		SET @cFieldAttr01	= '' 
		SET @cFieldAttr02	= ''
		SET @cFieldAttr03	= '' 
		SET @cFieldAttr04	= ''
		SET @cFieldAttr05	= '' 
		SET @cFieldAttr06	= ''
		SET @cFieldAttr07	= '' 
		SET @cFieldAttr08	= ''
		SET @cFieldAttr09	= ''
		SET @cFieldAttr10	= ''
		SET @cFieldAttr11	= '' 
		SET @cFieldAttr12	= ''
		SET @cFieldAttr13	= ''
		SET @cFieldAttr14	= ''
		SET @cFieldAttr15	= ''

		--	Validate	blank
		IF	ISNULL(RTRIM(@cToLOC),'') = ''
		BEGIN
			SET @nErrNo	= 69044
			SET @cErrMsg =	rdt.rdtgetmessage( 69044, @cLangCode, 'DSP')	--'ToLOC	needed'
			GOTO Step_8_Fail
		END

		--	Get LOC info
		SELECT @cChkFacility	= Facility
		FROM dbo.LOC (NOLOCK)
		WHERE	LOC =	@cToLOC

		--	Validate	LOC
		IF	@@ROWCOUNT = 0
		BEGIN
			SET @nErrNo	= 69045
			SET @cErrMsg =	rdt.rdtgetmessage( 69045, @cLangCode, 'DSP')	--'Invalid LOC'
			GOTO Step_8_Fail
		END

		--	Validate	LOC's	facility
		IF	NOT (rdt.rdtGetConfig( 0, 'MoveToLOCNotCheckFacility', @cStorerKey) = '1')
		IF	@cChkFacility <> @cFacility
		BEGIN
			SET @nErrNo	= 69046
			SET @cErrMsg =	rdt.rdtgetmessage( 69046, @cLangCode, 'DSP')	--'Diff facility'
			GOTO Step_8_Fail
		END

		DECLARE @nQTY_Bal	INT
		DECLARE @nQTY_LLI	INT
		DECLARE @nQTY		INT
		DECLARE @cLOT	 NVARCHAR(	10)

		SET @dSearchLottable04 = @cSearchLottable04

		--	Prepare cursor
		DECLARE @curLLI CURSOR
		SET @curLLI	= CURSOR	FAST_FORWARD READ_ONLY FOR	
		SELECT 
		LLI.LOT,	
		LLI.QTY - LLI.QTYAllocated	- LLI.QTYPicked
		FROM dbo.LOTxLOCxID LLI(NOLOCK)
		INNER	JOIN dbo.LotAttribute LA (NOLOCK) ON (LLI.LOT =	LA.LOT)
		INNER	JOIN dbo.LOT LOT (NOLOCK) ON (LLI.LOT = LOT.LOT)
		WHERE	LLI.StorerKey = @cStorerKey
		AND LLI.SKU	= @cSKU
		AND LLI.LOC	= @cFromLOC
		AND (LLI.QTY -	LLI.QTYAllocated - LLI.QTYPicked) >	0
		AND LLI.ID = @cID
		AND LA.Lottable02	= @cLottable02
		AND LA.Lottable03	= @cLottable03
		AND IsNULL(	LA.Lottable04,	0)	= CASE WHEN	@dSearchLottable04 =	0 THEN IsNULL(	LA.Lottable04,	0)	ELSE @dSearchLottable04	END
		AND (LA.Lottable04 >	getdate() OR LA.Lottable04	IS	NULL)
		AND LOT.STATUS	<>	'HOLD' 
		ORDER	BY	LLI.LOT,	LLI.ID, LA.Lottable02, LA.Lottable03, LA.Lottable04
		OPEN @curLLI

		--	Handling	transaction
		DECLARE @nTranCount INT
		SET @nTranCount =	@@TRANCOUNT
		BEGIN	TRAN	--	Begin	our own transaction
		SAVE TRAN rdtfnc_Move_SKU_Lottable -- For	rollback	or	commit only	our own transaction

		--	Loop LOTxLOTxID
		FETCH	NEXT FROM @curLLI	INTO @cLOT,	@nQTY_LLI
		SET @nQTY_Bal = @nQTY_Move
		WHILE	@@FETCH_STATUS	= 0
		BEGIN
			--	Calc LLI.QTY to take
			IF	@nQTY_LLI >	@nQTY_Bal
			SET @nQTY =	@nQTY_Bal -- LLI had	enuf QTY, so charge all	the balance	into this LLI
			ELSE
			SET @nQTY =	@nQTY_LLI -- LLI not	enuf QTY, take	all QTY avail of this LLI			

			EXECUTE rdt.rdt_Move
			@nMobile		 =	@nMobile,
			@cLangCode	 =	@cLangCode,	
			@nErrNo		 =	@nErrNo	OUTPUT,
			@cErrMsg		 =	@cErrMsg	OUTPUT, -- screen	limitation,	20	char max
			@cSourceType =	'rdtfnc_Move_SKU_Workorder', 
			@cStorerKey	 =	@cStorerKey,
			@cFacility	 =	@cFacility,	
			@cFromLOC	 =	@cFromLOC, 
			@cToLOC		 =	@cToLOC,	
			@cFromID		 =	@cID,			  -- NULL means not filter	by	ID. Blank is a	valid	ID
			@cToID		 =	@cToID,		  -- NULL means not changing ID.	Blank	consider	a valid ID
			@cSKU			 =	@cSKU, 
			@nQTY			 =	@nQTY, 
			@cFromLOT	 =	@cLOT
	
			IF	@nErrNo <> 0
			BEGIN
				CLOSE	@curLLI
				DEALLOCATE @curLLI
				GOTO RollBackTran
			END
			ELSE
			BEGIN
				--	EventLog	- QTY
				EXEC RDT.rdt_STD_EventLog
				@cActionType	= '4', -- Move
				@cUserID			= @cUserName,
				@nMobileNo		= @nMobile,
				@nFunctionID	= @nFunc,
				@cFacility		= @cFacility,
				@cStorerKey		= @cStorerkey,
				@cLocation		= @cFromLOC,
				@cToLocation	= @cToLOC,
				@cID				= @cFromID,
				@cToID			= @cToID, 
				@cSKU				= @cSKU,
				@cUOM				= @cMUOM_Desc,
				@nQTY				= @nQTY,
				@cLot				= @cLOT,
            @cExternKitKey = @cExternKitKey,
            @nStep         = @nStep
			END
			
			SET @nQTY_Bal = @nQTY_Bal - @nQTY  -- Reduce	balance

         --Start (Vanessa01)
         IF @nQTY_Bal = 0
         BEGIN  
            BREAK
         END
         --End (Vanessa01)

			FETCH	NEXT FROM @curLLI	INTO @cLOT,	@nQTY_LLI
		END
		
		--	Still	have balance, means no LLI	changed
		IF	@nQTY_Bal <> 0
		BEGIN
			SET @nErrNo	= 69047
			SET @cErrMsg =	rdt.rdtgetmessage( 69047, @cLangCode, 'DSP')	--'Inv changed'
			CLOSE	@curLLI
			DEALLOCATE @curLLI
			GOTO RollBackTran
		END
		COMMIT TRAN	rdtfnc_Move_SKU_Lottable -- Only	commit change made in here
		WHILE	@@TRANCOUNT	> @nTranCount
			COMMIT TRAN

		--	Go	to	next screen
		SET @nScn =	@nScn	+ 1
		SET @nStep = @nStep + 1

		GOTO Quit
	END

	IF	@nInputKey = 0	--	Esc or No
	BEGIN

		SET @cFieldAttr01	= '' 
		SET @cFieldAttr02	= ''
		SET @cFieldAttr03	= '' 
		SET @cFieldAttr04	= ''
		SET @cFieldAttr05	= '' 
		SET @cFieldAttr06	= ''
		SET @cFieldAttr07	= '' 
		SET @cFieldAttr08	= ''
		SET @cFieldAttr09	= ''
		SET @cFieldAttr10	= ''
		SET @cFieldAttr11	= '' 
		SET @cFieldAttr12	= ''
		SET @cFieldAttr13	= ''
		SET @cFieldAttr14	= ''
		SET @cFieldAttr15	= ''

		--	Prepare ToID screen var
		SET @cToID = ''
		SET @cOutField01 = ''		
		SET @cOutField02 = @cFromLOC
		SET @cOutField03 = @cID
		SET @cOutField04 = @cSKU
		SET @cOutField05 = SUBSTRING(	@cSKUDescR,	1,	20)	--	SKU desc	1
		SET @cOutField06 = SUBSTRING(	@cSKUDescR,	21, 20)	--	SKU desc	2
		SET @cOutField07 = '' -- @cPUOM_Desc
		SET @cOutField08 = @cQTY_Move
		SET @cOutField09 = '' -- ToID

		--	Go	to	ToID screen
		SET @nScn  = @nScn -	1
		SET @nStep = @nStep - 1
	END
	GOTO Quit

	RollBackTran:
	BEGIN
		ROLLBACK	TRAN rdtfnc_Move_SKU_Lottable
		WHILE	@@TRANCOUNT	> @nTranCount
		COMMIT TRAN
	END

	Step_8_Fail:
	BEGIN
		SET @cToLOC	= ''
		SET @cOutField09 = '' -- @cToLOC
	END
END
GOTO Quit

/********************************************************************************
Step 9. scn	= 2288. Message screen
	Message
********************************************************************************/
Step_9:
BEGIN
	--	Go	back to 1st	screen
	SET @nScn  = @nScn -	7
	SET @nStep = @nStep - 7

	--	Prep next screen var
	SET @cFromLOC = ''
	SET @cOutField01 = '' -- FromLOC

	SET @cFieldAttr01	= '' 
	SET @cFieldAttr02	= ''
	SET @cFieldAttr03	= '' 
	SET @cFieldAttr04	= ''
	SET @cFieldAttr05	= '' 
	SET @cFieldAttr06	= ''
	SET @cFieldAttr07	= '' 
	SET @cFieldAttr08	= ''
	SET @cFieldAttr09	= ''
	SET @cFieldAttr10	= ''
	SET @cFieldAttr11	= '' 
	SET @cFieldAttr12	= ''
	SET @cFieldAttr13	= ''
	SET @cFieldAttr14	= ''
	SET @cFieldAttr15	= ''

END
GOTO Quit


/********************************************************************************
Quit.	Update back	to	I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
	UPDATE RDTMOBREC WITH (ROWLOCK) SET	
	EditDate = GETDATE(), 
	ErrMsg =	@cErrMsg, 
	Func	 =	@nFunc,
	Step	 =	@nStep,
	Scn	 =	@nScn,

	StorerKey =	@cStorerKey,
	Facility	 =	@cFacility,	
	-- UserName	 =	@cUserName,

	V_String1  = @cFromLOC,	
	V_String2  = @cFromID, 
	V_String3  = @cSKU, 
	V_SKUDescr = @cSKUDescr, 

	V_LottableLabel02	= @cLottableLabel02,	
	V_LottableLabel03	= @cLottableLabel03,	
	V_LottableLabel04	= @cLottableLabel04,	
	V_String4 =	@cSearchLottable02, 
	V_String5 =	@cSearchLottable03, 
	V_String6 =	@cSearchLottable04, 
	V_Lottable02 =	@cLottable02, 
	V_Lottable03 =	@cLottable03, 
	V_Lottable04 =	@dLottable04, 

	V_ID		  = @cID, 
	V_UOM		  = @cEUOM,	
	V_String8  = @cEUOM_Desc, 
	V_String9  = @cExternKitKey, 
	V_String10 = @nQTY_Avail, 
	V_String11 = @cQTY_Avail, 
	V_String12 = @nQTY_Move, 
	V_String13 = @cQTY_Move, 
	V_String14 = @cToLOC, 
	V_String15 = @cToID,	
	V_String16 = @cLottable02_Code, 
	V_String17 = @cLottable03_Code, 
	V_String18 = @cLottable04_Code, 
	V_String19 = @cPackKey,	
	V_String20 = @cMUOM_Desc, 

	I_Field01 =	@cInField01,  O_Field01	= @cOutField01, 
	I_Field02 =	@cInField02,  O_Field02	= @cOutField02, 
	I_Field03 =	@cInField03,  O_Field03	= @cOutField03, 
	I_Field04 =	@cInField04,  O_Field04	= @cOutField04, 
	I_Field05 =	@cInField05,  O_Field05	= @cOutField05, 
	I_Field06 =	@cInField06,  O_Field06	= @cOutField06, 
	I_Field07 =	@cInField07,  O_Field07	= @cOutField07, 
	I_Field08 =	@cInField08,  O_Field08	= @cOutField08, 
	I_Field09 =	@cInField09,  O_Field09	= @cOutField09, 
	I_Field10 =	@cInField10,  O_Field10	= @cOutField10, 
	I_Field11 =	@cInField11,  O_Field11	= @cOutField11, 
	I_Field12 =	@cInField12,  O_Field12	= @cOutField12, 
	I_Field13 =	@cInField13,  O_Field13	= @cOutField13, 
	I_Field14 =	@cInField14,  O_Field14	= @cOutField14, 
	I_Field15 =	@cInField15,  O_Field15	= @cOutField15,

	FieldAttr01	 =	@cFieldAttr01,	  FieldAttr02	= @cFieldAttr02,
	FieldAttr03	 =	@cFieldAttr03,	  FieldAttr04	= @cFieldAttr04,
	FieldAttr05	 =	@cFieldAttr05,	  FieldAttr06	= @cFieldAttr06,
	FieldAttr07	 =	@cFieldAttr07,	  FieldAttr08	= @cFieldAttr08,
	FieldAttr09	 =	@cFieldAttr09,	  FieldAttr10	= @cFieldAttr10,
	FieldAttr11	 =	@cFieldAttr11,	  FieldAttr12	= @cFieldAttr12,
	FieldAttr13	 =	@cFieldAttr13,	  FieldAttr14	= @cFieldAttr14,
	FieldAttr15	 =	@cFieldAttr15 

	WHERE	Mobile =	@nMobile

END

GO