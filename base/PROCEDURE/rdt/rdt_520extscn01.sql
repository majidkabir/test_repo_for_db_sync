SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_520ExtScn01                                     */
/* Copyright      :                                                     */
/*                                                                      */
/* Purpose:       FCR-349                                               */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2024-06-21 1.0  JHU151   CREATE                                      */
/*                                                                      */
/************************************************************************/

CREATE   PROC [RDT].[rdt_520ExtScn01] (
   @nMobile       INT,           
   @nFunc         INT,           
   @cLangCode     NVARCHAR( 3),  
   @nStep		  INT,           
   @nScn		  INT,           
   @nInputKey     INT,           
   @cFacility     NVARCHAR( 5),  
   @cStorerKey    NVARCHAR( 15), 
   @tExtScnData   VariableTable READONLY,
   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,  @cLottable01 NVARCHAR( 18) OUTPUT,  
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,  @cLottable02 NVARCHAR( 18) OUTPUT,  
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,  @cLottable03 NVARCHAR( 18) OUTPUT,  
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,  @dLottable04 DATETIME      OUTPUT,  
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,  @dLottable05 DATETIME      OUTPUT,  
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,  @cLottable06 NVARCHAR( 30) OUTPUT, 
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,  @cLottable07 NVARCHAR( 30) OUTPUT, 
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,  @cLottable08 NVARCHAR( 30) OUTPUT, 
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,  @cLottable09 NVARCHAR( 30) OUTPUT, 
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,  @cLottable10 NVARCHAR( 30) OUTPUT, 
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,  @cLottable11 NVARCHAR( 30) OUTPUT,
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,  @cLottable12 NVARCHAR( 30) OUTPUT,
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,  @dLottable13 DATETIME      OUTPUT,
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,  @dLottable14 DATETIME      OUTPUT,
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,  @dLottable15 DATETIME      OUTPUT, 
	@nAction       INT, --0 Jump Screen, 1 Validation(pass through all input fields), 2 Update, 3 Prepare output fields .....
	@nAfterScn     INT OUTPUT, @nAfterStep    INT OUTPUT, 
   @nErrNo        INT            OUTPUT, 
   @cErrMsg       NVARCHAR( 20)  OUTPUT,
   @cUDF01  NVARCHAR( 250) OUTPUT, @cUDF02 NVARCHAR( 250) OUTPUT, @cUDF03 NVARCHAR( 250) OUTPUT,
   @cUDF04  NVARCHAR( 250) OUTPUT, @cUDF05 NVARCHAR( 250) OUTPUT, @cUDF06 NVARCHAR( 250) OUTPUT,
   @cUDF07  NVARCHAR( 250) OUTPUT, @cUDF08 NVARCHAR( 250) OUTPUT, @cUDF09 NVARCHAR( 250) OUTPUT,
   @cUDF10  NVARCHAR( 250) OUTPUT, @cUDF11 NVARCHAR( 250) OUTPUT, @cUDF12 NVARCHAR( 250) OUTPUT,
   @cUDF13  NVARCHAR( 250) OUTPUT, @cUDF14 NVARCHAR( 250) OUTPUT, @cUDF15 NVARCHAR( 250) OUTPUT,
   @cUDF16  NVARCHAR( 250) OUTPUT, @cUDF17 NVARCHAR( 250) OUTPUT, @cUDF18 NVARCHAR( 250) OUTPUT,
   @cUDF19  NVARCHAR( 250) OUTPUT, @cUDF20 NVARCHAR( 250) OUTPUT, @cUDF21 NVARCHAR( 250) OUTPUT,
   @cUDF22  NVARCHAR( 250) OUTPUT, @cUDF23 NVARCHAR( 250) OUTPUT, @cUDF24 NVARCHAR( 250) OUTPUT,
   @cUDF25  NVARCHAR( 250) OUTPUT, @cUDF26 NVARCHAR( 250) OUTPUT, @cUDF27 NVARCHAR( 250) OUTPUT,
   @cUDF28  NVARCHAR( 250) OUTPUT, @cUDF29 NVARCHAR( 250) OUTPUT, @cUDF30 NVARCHAR( 250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE
   @nRowCount           INT,
   @nCheckDigit         INT,
   @b_Success           INT,
   @n_err               INT,
   @nQTY_PWY            INT,
   @nPUOM_Div           INT,
   @nPQTY_PWY           INT,
   @nMQTY_PWY           INT,
   @nPQTY               INT,
   @nMQTY               INT,
   @nQTY                INT,
   @c_errmsg            NVARCHAR( 250),
   @cFromLOC            NVARCHAR( 10),
   @cSKU                NVARCHAR( 20),
   @cActLoc             NVARCHAR( 20),
   @cSKUDesc            NVARCHAR( 60),
   @cPUOM               NVARCHAR( 10),
   @cID                 NVARCHAR( 20),
   @cUserName           NVARCHAR( 18),
   @cMUOM_Desc          NVARCHAR( 5),
   @cPUOM_Desc          NVARCHAR( 5),
   @cPalletTypeSave     NVARCHAR( 10)

   SET @nAfterScn = @nScn
   SET @nAfterStep = @nAfterStep
   SET @cUDF01 = @nFunc

   IF @nFunc = 520
   BEGIN
      IF @nAction = 0 --jump
      BEGIN
      
         IF @nScn = 920
         BEGIN
            SET @nAfterScn = 924
            SET @nAfterStep = 99

			SET @cOutField01 = '' -- FROM Loc
			SET @cOutField02 = '' -- SKU

			EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END
         
      END
      ELSE
      BEGIN
         IF @nStep = 99
         BEGIN
            /********************************************************************************
               Step 99. Scn = 924. FromLOC/SKU screen
               FROM Loc       (field01, input)
               SKU/UPC        (field02, input)
            ********************************************************************************/
            DECLARE @nMenu    INT

            SELECT @nMenu = Value FROM @tExtScnData WHERE Variable = '@nMenu'
            SELECT @cUserName = Value FROM @tExtScnData WHERE Variable = '@cUserName'
			SELECT @cPUOM = DefaultUOM FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = @cUserName

            IF @nScn = 924
            BEGIN
               IF @nInputKey = 1 -- ENTER
               BEGIN
                  DECLARE @cLabelNo NVARCHAR( 32)
				  SET @cID = ''
                  -- Screen mapping
                  SET @cFromLOC = @cInField01
                  SET @cSKU = @cInField02

                  -- Retain input
                  SET @cOutField01 = @cInField01 -- FromLOC
                  SET @cOutField02 = @cInField02 -- SKU

                  -- Check LOC
                  IF @cFromLOC = ''
                  BEGIN
                     SET @nErrNo = 63821
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need FROM LOC
                     EXEC rdt.rdtSetFocusField @nMobile, 1 --FromLOC
                     SET @cOutField01 = '' --FromLOC
                     GOTO Quit
                  END

                  -- Check LOC valid
                  IF NOT EXISTS ( SELECT 1 FROM dbo.LOC LOC WITH (NOLOCK) WHERE LOC = @cFromLOC AND Facility = @cFacility)
                  BEGIN
                     SET @nErrNo = 63807
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidFromLoc
                     EXEC rdt.rdtSetFocusField @nMobile, 1 --FromLOC
                     SET @cOutField01 = ''
                     GOTO Quit
                  END
                  
                  
                  -- Go to next field
                  IF @cSKU = ''
                     EXEC rdt.rdtSetFocusField @nMobile, 2


                  -- Check SKU blank
                  IF @cSKU = ''
                  BEGIN
                     SET @nErrNo = 63801
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NeedID/SKU/LOC
                     EXEC rdt.rdtSetFocusField @nMobile, 2
                     SET @cOutField02 = '' --SKU
                     GOTO Quit
                  END

                  -- Get SKU barcode count
                  DECLARE @nSKUCnt INT
                  EXEC RDT.rdt_GETSKUCNT
                     @cStorerKey  = @cStorerKey,
                     @cSKU        = @cSKU,
                     @nSKUCnt     = @nSKUCnt       OUTPUT,
                     @bSuccess    = @b_Success     OUTPUT,
                     @nErr        = @n_Err         OUTPUT,
                     @cErrMsg     = @c_ErrMsg      OUTPUT

                  -- Check SKU/UPC
                  IF @nSKUCnt = 0
                  BEGIN
                     SET @nErrNo = 63803
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
                     EXEC rdt.rdtSetFocusField @nMobile, 2 --SKU
                     SET @cOutField02 = ''
                     GOTO Quit
                  END

                  -- Count SKU, LOC on ID
                  DECLARE @nSKUCount INT
                  DECLARE @nLOCCount INT
                  SET @nSKUCount = 0
                  SET @nLOCCount = 0

                  SELECT
                     @nSKUCount = COUNT( DISTINCT LLI.SKU)
                  FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
                  WHERE StorerKey = @cStorerKey
                     AND Facility = @cFacility
                     AND LOC.LOC = @cFromLOC
                     AND LLI.SKU = @cSKU
                     AND (LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated) > 0  -- (james07)


                  -- Check SKU Not available at location
                  IF @nSKUCount = 0
                  BEGIN
                     SET @nErrNo = 217551
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKU Not available at location
                     EXEC rdt.rdtSetFocusField @nMobile, 2
                     SET @cOutField02 = '' --SKU
                     GOTO Quit
                  END
                                          
                  -- Get LLI count
                  DECLARE @nRecCnt INT
                  SET @nRecCnt = 0
                  SELECT @nRecCnt = COUNT(1)
                  FROM
                  (
                     SELECT 1 B
                     FROM dbo.LotxLocxID LLI WITH (NOLOCK)
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
                     WHERE Storerkey = @cStorerKey
                        AND SKU = @cSKU
                        AND LLI.LOC = @cFromLOC
						AND ID = CASE WHEN @cID = '' THEN ID ELSE @cID END
                     GROUP BY LLI.LOC, LLI.ID, LLI.SKU
                     HAVING SUM(LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated) > 0
                  ) A

                  -- Check no LLI to putaway
                  IF @nRecCnt = 0
                  BEGIN
                     -- Check QTY to putaway
                     IF EXISTS( SELECT 1
                        FROM dbo.LotxLocxID LLI WITH (NOLOCK)
                           JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
                        WHERE Storerkey = @cStorerKey
                           AND SKU = @cSKU
                           AND LLI.LOC = @cFromLOC
						   AND ID = CASE WHEN @cID = '' THEN ID ELSE @cID END
                        GROUP BY LLI.LOC, LLI.ID, LLI.SKU)
                     BEGIN
                        SET @nErrNo = 63805
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoQTYtoPutaway
                     END
                     ELSE
                     BEGIN
                        SET @nErrNo = 63808
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Rec Found
                     END
                     GOTO Quit
                  END

                  ---- Check multi LLI to putaway
                  --IF @nRecCnt > 1
                  --BEGIN
                  --   SET @nErrNo = 63809
                  --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiRec Found
                  --   GOTO Quit
                  --END

                  -- Get LLI info
                  SELECT TOP 1
                     @cSKU     = LLI.SKU,
                     @cID      = LLI.ID,
                     @cFromLOC = LLI.LOC,
                     @nQTY_PWY = SUM(LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated)
                  FROM dbo.LotxLocxID LLI WITH (NOLOCK)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
                  WHERE Storerkey = @cStorerKey
                     AND LLI.LOC = @cFromLOC
                     AND SKU = CASE WHEN @cSKU = '' THEN SKU ELSE @cSKU END
                  GROUP BY LLI.LOC, LLI.ID, LLI.SKU
                  HAVING SUM(LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated) > 0

                  -- Get SKU info
                  SELECT
                     @cSKUDesc = S.Descr,
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
                        END AS INT)
                  FROM dbo.SKU S (NOLOCK)
                     INNER JOIN dbo.Pack Pack (nolock) ON (S.PackKey = Pack.PackKey)
                  WHERE StorerKey = @cStorerKey
                     AND SKU = @cSKU

                  -- Convert to prefer UOM QTY
                  IF @cPUOM = '6' OR -- When preferred UOM = master unit
                     @nPUOM_Div = 0 -- UOM not setup
                  BEGIN
                     SET @cPUOM_Desc = ''
                     SET @nPQTY_PWY = 0
                     SET @nPQTY  = 0
                     SET @nMQTY_PWY = @nQTY_PWY
                     SET @cFieldAttr11 = 'O' -- @nPQTY_PWY
                     SET @cInField13 = ''
                  END
                  ELSE
                  BEGIN
                     SET @nPQTY_PWY = @nQTY_PWY / @nPUOM_Div -- Calc QTY in preferred UOM
                     SET @nMQTY_PWY = @nQTY_PWY % @nPUOM_Div -- Calc the remaining in master unit
                  END

                  -- Prepare next screen variable
                  SET @cOutField01 = @cID
                  SET @cOutField02 = @cStorerKey
                  SET @cOutField03 = @cSKU
                  SET @cOutField04 = SUBSTRING( @cSKUDesc, 1, 20)
                  SET @cOutField05 = SUBSTRING( @cSKUDesc, 21, 20)
                  SET @cOutField06 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
                  SET @cOutField07 = @cPUOM_Desc
                  SET @cOutField08 = @cMUOM_Desc
                  SET @cOutField09 = CASE WHEN @cFieldAttr11 = 'O' THEN '' ELSE CAST( @nPQTY_PWY AS NVARCHAR( 6)) END
                  SET @cOutField10 = CAST( @nMQTY_PWY AS NVARCHAR( 6))
                  SET @cOutField11 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'NotDefaultPAQty', @cStorerKey) = 1 THEN '' ELSE     -- (james06)
                                    CASE WHEN @cFieldAttr11 = 'O' THEN '' ELSE CAST( @nPQTY_PWY AS NVARCHAR( 6)) END END
                  SET @cOutField12 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'NotDefaultPAQty', @cStorerKey) = 1 THEN '' ELSE     -- (james06)
                                    CAST( @nMQTY_PWY AS NVARCHAR( 6)) END
                  SET @cOutField13 = @cFromLOC

				  SET @cUDF01 = @nFunc
				  SET @cUDF02 = @cSKU
				  SET @cUDF03 = @cFromLOC
				  SET @cUDF04 = @cSKUDesc
				  SET @cUDF05 = @cPUOM
				  SET @cUDF06 = @nPQTY_PWY
				  SET @cUDF07 = @nMQTY_PWY
				  SET @cUDF08 = @nQTY_PWY
				  SET @cUDF09 = @nPUOM_Div
				  SET @cUDF10 = @nPQTY
				  SET @cUDF11 = @nMQTY
				  SET @cUDF12 = @cID

                  -- Go to next screen
                  SET @nAfterScn = 921
                  SET @nAfterStep = 2
               END

               IF @nInputKey = 0 -- ESC
               BEGIN
                  -- Sign Out
                  EXEC RDT.rdt_STD_EventLog
                     @cActionType = '9', -- Sign Out function
                     @cUserID     = @cUserName,
                     @nMobileNo   = @nMobile,
                     @nFunctionID = @nFunc,
                     @cFacility   = @cFacility,
                     @cStorerKey  = @cStorerKey,
                     @nStep       = @nStep

                  -- Back to menu
                  SET @cUDF01 = @nMenu -- set func to back
                  SET @nAfterScn  = @nMenu
                  SET @nAfterStep = 0
                  SET @cOutField01 = '' -- Option
               END

            END         
         END
      END
   END
Quit:
END; 

SET QUOTED_IDENTIFIER OFF 

GO