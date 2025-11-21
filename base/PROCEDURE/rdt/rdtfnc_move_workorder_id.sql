SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_Move_WorkOrder_ID                            */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Purpose: Move pallet                                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2010-05-18 1.0  ACM      Created                                     */
/* 2010-06-15 1.1  Vanessa  SOS#171884 Add LOTxLOCxID.QTY > 0 -- (Vanessa01)*/
/* 2016-09-30 1.2  Ung      Performance tuning                          */
/* 2018-11-02 1.3  Gan      Performance tuning                          */
/************************************************************************/

CREATE  PROCEDURE [RDT].[rdtfnc_Move_WorkOrder_ID] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON 
SET QUOTED_IDENTIFIER OFF 
SET ANSI_NULLS OFF

-- Misc variable
DECLARE 
	@i             INT, 
	@nRowCount     INT, 
	@cChkFacility  NVARCHAR( 5), 
	@cCheckKit	   NVARCHAR(1),
	@cKitStatus	   NVARCHAR(10),
	@cKitStorerkey NVARCHAR(15), 
	@cExternKitKey NVARCHAR(20), 
	@cQTY_Avail	   NVARCHAR(18),
	@cPUOM_Desc    NVARCHAR( 5), -- Preferred UOM desc
	@cMUOM_Desc    NVARCHAR( 5), -- Master unit desc
	@nPUOM_Div     FLOAT, -- UOM divider
	@nPQTY         FLOAT, -- Preferred UOM QTY
	@nQTY          INT

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
   @cAllowOverADJ NVARCHAR(1),
   @cFromLOC   NVARCHAR( 10), 
   @cFromID    NVARCHAR( 18), 
   @cSKU       NVARCHAR( 20), 
   @cSKUDescr  NVARCHAR( 60), 
   @cPUOM      NVARCHAR( 1), -- Prefer UOM
   @cToLOC     NVARCHAR( 10), 

   @nTotalRec    INT, 
   @nCurrentRec  INT, 

   @cUserName    NVARCHAR(18),
   
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
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,
   @cUserName  = UserName,

   @cSKU       = V_SKU, 
   @cSKUDescr  = V_SKUDescr, 
   @cPUOM      = V_UOM,
   
   @nTotalRec   = V_Integer1,
   @nCurrentRec = V_Integer2,
   
   @cFromID    = V_String1, 
   @cFromLOC   = V_String2, 
   @cToLOC     = V_String3, 
  -- @nTotalRec    = CASE WHEN rdt.rdtIsValidQTY( V_String4,  0) = 1 THEN V_String4 ELSE 0 END,
  -- @nCurrentRec  = CASE WHEN rdt.rdtIsValidQTY( V_String5,  0) = 1 THEN V_String5 ELSE 0 END,
   @cExternKitKey  = V_String6, -- @cExternKitKey

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

IF @nFunc = 518 -- Move (generic)
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Move (generic)
   IF @nStep = 1 GOTO Step_1   -- Scn = 1000. FromID 
   IF @nStep = 2 GOTO Step_2   -- Scn = 1001. FromLOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 1002. SKU, Desc, UOM, QTY, ToLOC
   IF @nStep = 4 GOTO Step_4   -- Scn = 1003. Message
   IF @nStep = 5 GOTO Step_5   -- Scn = 1003. Message
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 518. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 2300
   SET @nStep = 1

   -- Prep next screen var
   SET @cFromID = ''
   SET @cFromLOC = ''
   SET @cSKU = ''
   SET @cSKUDescr = ''
   SET @cToLOC = ''
   
   SET @nTotalRec = 0
   SET @nCurrentRec = 0

   -- Get prefer UOM
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M (NOLOCK)
      INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

    -- EventLog - Sign In Function
    EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep
   
   -- Init screen
   SET @cOutField01 = '' -- ExternKitKey
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 2300. ExternKitKey
   ExternKitKey  (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cExternKitKey = @cInField01
      
		-- Validate blank
		IF ISNULL(RTRIM(@cExternKitKey), '') = ''
		BEGIN
		 SET @nErrNo = 69141
		 SET @cErrMsg = rdt.rdtgetmessage( 69141, @cLangCode, 'DSP') --'WO needed'
         EXEC rdt.rdtSetFocusField @nMobile, 1
		 GOTO Step_1_Fail
		END

		-- Get Kit info
		SET @cCheckKit  ='0'
		SET @cKitStatus = '0'
		SET @cChkFacility = ''
		SET @cKitStorerkey = ''

		SELECT @cCheckKit = '1', @cKitStatus = Status,
		@cChkFacility = ISNULL(RTRIM(Facility), ''), @cKitStorerkey = Storerkey
		FROM dbo.KIT (NOLOCK)
		WHERE ExternKitKey = @cExternKitKey

		-- Validate LOC
		IF ISNULL(RTRIM(@cCheckKit), '') = '0'
		BEGIN
			SET @nErrNo = 69142
			SET @cErrMsg = rdt.rdtgetmessage( 69142, @cLangCode, 'DSP') --'Invalid WO'
			EXEC rdt.rdtSetFocusField @nMobile, 1
			GOTO Step_1_Fail
		END

		-- Validate WorkOrder KIT.status = 9
		IF ISNULL(RTRIM(@cKitStatus), '') = '9'
		BEGIN
			SET @nErrNo = 69143
			SET @cErrMsg = rdt.rdtgetmessage( 69143, @cLangCode, 'DSP') --'WO closed'
			EXEC rdt.rdtSetFocusField @nMobile, 1
			GOTO Step_1_Fail
		END

		-- Validate WorkOrder KIT.status = CANC
		IF ISNULL(RTRIM(@cKitStatus), '') = 'CANC'
		BEGIN
			SET @nErrNo = 69144
			SET @cErrMsg = rdt.rdtgetmessage( 69144, @cLangCode, 'DSP') --'WO cancelled'
			EXEC rdt.rdtSetFocusField @nMobile, 1
			GOTO Step_1_Fail
		END
		
		-- Validate Right(KIT.facility,2) = 10
		IF RIGHT(@cChkFacility,2) <> '10'
		BEGIN
         SET @nErrNo = 69145
         SET @cErrMsg = rdt.rdtgetmessage( 69145, @cLangCode, 'DSP') --'Non-manufac WO'
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
		END		
		
		-- Validate Kit's facility
		IF @cChkFacility <> @cFacility
		BEGIN
			SET @nErrNo = 69146
			SET @cErrMsg = rdt.rdtgetmessage( 69146, @cLangCode, 'DSP') --'Invalid FAC'
			EXEC rdt.rdtSetFocusField @nMobile, 1	
			GOTO Step_1_Fail
		END

		-- Validate Kit Storerkey
		IF @cKitStorerkey <> @cStorerkey
		BEGIN
			SET @nErrNo = 69147
			SET @cErrMsg = rdt.rdtgetmessage( 69147, @cLangCode, 'DSP') --'Invalid Storer'
			EXEC rdt.rdtSetFocusField @nMobile, 1
			GOTO Step_1_Fail
		END

      -- Prep next screen var
      SET @cFromLOC = ''
      SET @cOutField01 = @cFromLOC

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
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
      SET @cExternKitKey = ''
      SET @cOutField01 = ''  -- ExternKitKey
   END
END
GOTO Quit

/********************************************************************************
Step 2. Scn = 2301. FromID
   FromID  (field01, input)
   FromLOC (field02)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cFromID = @cInField01
      
      -- Validate blank
      IF ISNULL(RTRIM(@cFromID),'') = ''
      BEGIN
         SET @nErrNo = 69148
         SET @cErrMsg = rdt.rdtgetmessage( 69148, @cLangCode, 'DSP') --'ID needed'
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_2_Fail
      END

      -- Get ID info
	  IF NOT EXISTS( SELECT 1
	  FROM dbo.LOTxLOCxID (NOLOCK)
	  WHERE StorerKey = @cStorerKey
	  AND ID = @cFromID
	  AND (QTY - QTYPicked) > 0)
      BEGIN
         SET @nErrNo = 69149
         SET @cErrMsg = rdt.rdtgetmessage( 69149, @cLangCode, 'DSP') --'Invalid ID'
         GOTO Step_2_Fail
      END

		-- Validate at least 1 sku on ID with type 'F'
		IF NOT EXISTS ( SELECT 1 
		FROM dbo.KITDETAIL KITDETAIL (NOLOCK)  , dbo.LOTXLOCXID LOTXLOCXID (NOLOCK) 
		WHERE KITDETAIL.StorerKey = @cStorerKey
		AND EXTERNKITKEY = @cExternKitKey
		AND KITDETAIL.StorerKey = LOTXLOCXID.StorerKey
		AND KITDETAIL.SKU = LOTXLOCXID.SKU
		AND KITDETAIL.TYPE = 'F'
		AND LOTXLOCXID.ID = @cFromID
		)
		BEGIN
			SET @nErrNo = 69150
			SET @cErrMsg = rdt.rdtgetmessage( 69150, @cLangCode, 'DSP') --'SKU not on WO'
			GOTO Step_2_Fail
		END

		--Validate ID exists in LOTxLOCxID table and have movable stock
		IF NOT EXISTS ( SELECT 1 
		FROM dbo.LOTxLOCxID LOTxLOCxID (NOLOCK) , dbo.LOT LOT (NOLOCK) 
		WHERE LOTxLOCxID.StorerKey = @cStorerKey
		AND LOTxLOCxID.StorerKey = LOT.StorerKey
		AND LOTxLOCxID.SKU = LOT.SKU
		AND LOTxLOCxID.LOT = LOT.LOT
		AND ID = @cFromID
		AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYAllocated - LOTxLOCxID.QTYPicked) > 0
		AND LOT.STATUS <> 'HOLD'
		)
		BEGIN
			SET @nErrNo = 69151
			SET @cErrMsg = rdt.rdtgetmessage( 69151, @cLangCode, 'DSP') --'Lot on Hold'
			GOTO Step_2_Fail
		END

		--Lottable04 (defined as ExpiryDate) on the ID < system date. 
		IF EXISTS( SELECT 1 
		FROM dbo.LOTxLOCxID LOTxLOCxID (NOLOCK) , dbo.lotattribute LA (NOLOCK) 
		WHERE LOTxLOCxID.StorerKey = @cStorerKey
		AND LOTxLOCxID.StorerKey = LA.StorerKey
		AND LOTxLOCxID.SKU = LA.SKU
		AND LOTxLOCxID.LOT = LA.LOT
      AND LOTxLOCxID.QTY > 0  -- (Vanessa01)
		AND ID = @cFromID
        AND (ISNULL(LA.lottable04,getdate())  < getdate())
		)
		BEGIN
			SET @nErrNo = 69152
			SET @cErrMsg = rdt.rdtgetmessage( 69152, @cLangCode, 'DSP') --'Batch expired'
			GOTO Step_2_Fail
		END	
/*		
		--RDTGetConfig	'Allow_WOOverQty'
		SET @cAllowOverADJ = '0'
		SET @cAllowOverADJ = rdt.RDTGetConfig(@nFunc, 'Allow_WOOverQty', @cStorerkey)	--	Parse	in	Function

		SET @cOutField01 = ''

		--If QTY	MV	more than KITDETAIL.ExpectedQty,	prompt í░WARNING:	QTY>KITQTYí▒ as warning		
		IF EXISTS(
		SELECT 1 FROM 
		(SELECT LLI.storerkey, LLI.SKU , SUM( LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked) AS QTY
		FROM dbo.LOTxLOCxID LLI (NOLOCK)
		INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
		WHERE LLI.StorerKey = @cStorerKey
		AND LLI.ID = @cFromID
		AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked) > 0
		GROUP BY LLI.storerkey, LLI.SKU ) AS TH, dbo.KITDETAIL KD
		WHERE TH.STORERKEY = KD.STORERKEY
		AND TH.SKU = KD.SKU
		AND KD.TYPE = 'F'
		AND TH.QTY > KD.EXPECTEDQTY
		AND KD.EXTERNKITKEY = @cExternKitKey
		)
		BEGIN
			IF @cAllowOverADJ	= '1'
			BEGIN
				SET @cOutField01 = 'WARNING: QTY>KITQTY'
			END
			ELSE
			BEGIN
				SET @nErrNo	= 69053
				SET @cErrMsg =	rdt.rdtgetmessage( 69053, @cLangCode, 'DSP')	--'QTY>KITQTY'
				GOTO Step_2_Fail
			END
		END
*/
      -- Prep next screen var
      SET @cFromLOC = ''
      SET @cOutField02 = @cFromID
      SET @cOutField03 = @cFromLOC

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cExternKitKey = ''
      SET @cOutField01 = '' -- ExternKitKey

      -- Go back to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1

   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cFromID  = ''
      SET @cOutField01 = '' -- ID
   END
END
GOTO Quit

/********************************************************************************
Step 3. Scn = 2302. FromLOC
   FromID  (field01)
   FromLOC (field02, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cFromLOC = @cInField03
      
      -- Validate blank
      IF ISNULL(RTRIM(@cFromLOC),'') = ''
      BEGIN
         SET @nErrNo = 69154
         SET @cErrMsg = rdt.rdtgetmessage( 69154, @cLangCode, 'DSP') --'LOC needed'
         GOTO Step_3_Fail
      END

      -- Get LOC info
      SELECT @cChkFacility = Facility
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cFromLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 69155
         SET @cErrMsg = rdt.rdtgetmessage( 69155, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_3_Fail
      END
      
      -- Validate LOC's facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 69156
         SET @cErrMsg = rdt.rdtgetmessage( 69156, @cLangCode, 'DSP') --'Diff facility'
         GOTO Step_3_Fail
      END
      
      -- Get total record
      DECLARE @nQTYAlloc INT
      SET @nTotalRec = 0
      SELECT 
         @nTotalRec = COUNT( DISTINCT SKU.SKU), -- Total no of SKU
         @nQTYAlloc = IsNULL( SUM( QTYAllocated), 0)
      FROM dbo.LOTxLOCxID LLI (NOLOCK)
         INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
      WHERE LLI.StorerKey = @cStorerKey
         AND LLI.ID = @cFromID
         AND LLI.LOC = @cFromLOC
         AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked) > 0
      IF @nTotalRec = 0
      BEGIN
         SET @nErrNo = 69157
         SET @cErrMsg = rdt.rdtgetmessage( 69157, @cLangCode, 'DSP') --'No record'
         GOTO Step_3_Fail
      END

      -- Validate QTY allocated
      IF @nQTYAlloc > 0
      BEGIN
         SET @nErrNo = 69158
         SET @cErrMsg = rdt.rdtgetmessage( 69158, @cLangCode, 'DSP') --'QTY allocated'
         GOTO Step_3_Fail
      END

      -- Get LOTxLOCxID info
      SELECT TOP 1 
         @cSKU = SKU.SKU, 
         @nQTY = SUM( LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked)
      FROM dbo.LOTxLOCxID LLI (NOLOCK)
         INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
      WHERE LLI.StorerKey = @cStorerKey
         AND LLI.ID = @cFromID
         AND LLI.LOC = @cFromLOC
         AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked) > 0
      GROUP BY SKU.SKU
      ORDER BY SKU.SKU

      -- Get Pack info
      SELECT
         @cSKUDescr = SKU.Descr, 
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
      FROM dbo.SKU SKU (NOLOCK) 
         INNER JOIN dbo.Pack Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit 
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = @cMUOM_Desc
         SET @nPQTY = @nQTY
      END
      ELSE
      BEGIN
         SET @nPQTY = @nQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
      END

  	  SET @cQTY_Avail =	CAST (CAST (@nPQTY AS DECIMAL(18,8)) AS NVARCHAR(18))
	  SET @cQTY_Avail =	REPLACE(RTRIM(REPLACE(@cQTY_Avail, '0', ' ')), ' ', '0')
	  SET @cQTY_Avail =	REPLACE(RTRIM(REPLACE(@cQTY_Avail, '.', ' ')), ' ', '.')
	  SET @cQTY_Avail =	SUBSTRING(@cQTY_Avail, 1, 10)
      
      -- Prep next screen var
      SET @nCurrentRec = 1
      SET @cToLOC = ''
      SET @cOutField01 = @cFromID
      SET @cOutField02 = @cFromLOC
      SET @cOutField03 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
      SET @cOutField04 = @cSKU
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField06 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField07 = @cPUOM_Desc
      SET @cOutField08 = @cQTY_Avail
      SET @cOutField09 = '' -- ToLOC
      
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cFromID = ''
      SET @cFromLOC = ''
      SET @cOutField01 = '' -- FromID
      SET @cOutField02 = '' -- FromLOC

      -- Go back to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cFromLOC  = ''
      SET @cOutField03 = '' -- FromLOC
   END
END
GOTO Quit


/********************************************************************************
Step 4. Scn = 2303. ToLOC
   FromID    (field01)
   FromLOC   (field02)
   Counter   (field03)
   SKU       (field04)
   Desc1     (field05)
   Desc2     (field06)
   PUOM_Desc (field07)
   PQTY      (field08)
   MUOM_Desc (filed09)
   MQTY      (field10)
   ToLOC     (field11)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToLOC = @cInField09

      -- Validate blank
      IF ISNULL(RTRIM(@cToLOC),'') = ''
      BEGIN
         IF @nCurrentRec = @nTotalRec
            SET @nCurrentRec = 0
         
         -- Get LOTxLOCxID info
         DECLARE @curLLI CURSOR
         SET @curLLI = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT 
               SKU.SKU, 
               SUM( LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked)
            FROM dbo.LOTxLOCxID LLI (NOLOCK)
               INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
            WHERE LLI.StorerKey = @cStorerKey
               AND LLI.ID = @cFromID
               AND LLI.LOC = @cFromLOC
               AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked) > 0
            GROUP BY SKU.SKU
            ORDER BY SKU.SKU
         OPEN @curLLI
         FETCH NEXT FROM @curLLI INTO @cSKU, @nQTY
         
         -- Skip to the record
         SET @i = 1
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @i > @nCurrentRec BREAK
            SET @i = @i + 1
            FETCH NEXT FROM @curLLI INTO @cSKU, @nQTY
         END

         -- Get Pack info
         SELECT
            @cSKUDescr = SKU.Descr, 
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
         FROM dbo.SKU SKU (NOLOCK) 
            INNER JOIN dbo.Pack Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cSKU
         
         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit 
            @nPUOM_Div = 0 -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = @cMUOM_Desc
            SET @nPQTY = @nQTY
         END
         ELSE
         BEGIN
            SET @nPQTY = @nQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
         END

		 SET @cQTY_Avail =	CAST (CAST (@nPQTY AS DECIMAL(18,8)) AS NVARCHAR(18))
		 SET @cQTY_Avail =	REPLACE(RTRIM(REPLACE(@cQTY_Avail, '0', ' ')), ' ', '0')
		 SET @cQTY_Avail =	REPLACE(RTRIM(REPLACE(@cQTY_Avail, '.', ' ')), ' ', '.')
		 SET @cQTY_Avail =	SUBSTRING(@cQTY_Avail, 1, 10)
         
         -- Prep next screen var
         SET @nCurrentRec = @nCurrentRec + 1
         SET @cToLOC = ''
         SET @cOutField01 = @cFromID
         SET @cOutField02 = @cFromLOC
         SET @cOutField03 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
         SET @cOutField04 = @cSKU
         SET @cOutField05 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField06 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField07 = @cPUOM_Desc
         SET @cOutField08 = @cQTY_Avail
         SET @cOutField09 = '' -- ToLOC

         GOTO Quit
      END

      -- Get LOC info
      SELECT @cChkFacility = Facility
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cToLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 69159
         SET @cErrMsg = rdt.rdtgetmessage( 69159, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_4_Fail
      END

      -- Validate LOC's facility
      IF NOT (rdt.rdtGetConfig( 0, 'MoveToLOCNotCheckFacility', @cStorerKey) = '1')
         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 69160
            SET @cErrMsg = rdt.rdtgetmessage( 69160, @cLangCode, 'DSP') --'Diff facility'
            GOTO Step_4_Fail
         END

      EXECUTE rdt.rdt_Move
         @nMobile     = @nMobile,
         @cLangCode   = @cLangCode, 
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
         @cSourceType = 'rdtfnc_Move_WorkOrder_ID', 
         @cStorerKey  = @cStorerKey,
         @cFacility   = @cFacility, 
         @cFromLOC    = @cFromLOC, 
         @cToLOC      = @cToLOC, 
         @cFromID     = @cFromID, 
         @cToID       = NULL  -- NULL means not changing ID

      IF @nErrNo <> 0
      BEGIN
         GOTO Step_4_Fail
      END
      ELSE
      BEGIN

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
             @cExternKitKey = @cExternKitKey,
             --@cRefNo1       = @cExternKitKey,
             @nStep         = @nStep
      END

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cFromLOC = ''
      SET @cOutField01 = ''
      SET @cOutField02 = @cFromID
      SET @cOutField03 = '' -- FromLOC

      -- Go back to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cToLOC = ''
      SET @cOutField09 = ''
   END
END
GOTO Quit


/********************************************************************************
Step 5. scn = 2304. Message screen
   Msg
********************************************************************************/
Step_5:
BEGIN
   -- Go back to 1st screen
   SET @nScn  = @nScn - 3
   SET @nStep = @nStep - 3

   -- Prep next screen var
   SET @cFromID = ''
   SET @cFromLOC = ''
   
   SET @cOutField01 = '' -- FromID
   SET @cOutField02 = '' -- FromLOC
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
      -- UserName  = @cUserName,

      V_SKU      = @cSKU, 
      V_SKUDescr = @cSKUDescr, 
      V_UOM      = @cPUOM,
      
      V_Integer1 = @nTotalRec,
      V_Integer2 = @nCurrentRec,
   
      V_String1  = @cFromID, 
      V_String2  = @cFromLOC, 
      V_String3  = @cToLOC, 

      --V_String4 = @nTotalRec,
      --V_String5 = @nCurrentRec,
      V_String6 = @cExternKitKey,


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