SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1580ExtScn01                                     */
/* Copyright      :                                                     */
/*                                                                      */
/* Purpose:       For Unilever                                          */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2024-03-13 1.0  Dennis   Check Digit                                 */
/* 2024-06-26 1.1  Dennis   Capture Pallet Type                         */
/************************************************************************/

CREATE   PROC [rdt].[rdt_1580ExtScn01] (
	@nMobile      INT,           
	@nFunc        INT,           
	@cLangCode    NVARCHAR( 3),  
	@nStep INT,           
	@nScn  INT,           
	@nInputKey    INT,           
	@cFacility    NVARCHAR( 5),  
	@cStorerKey   NVARCHAR( 15), 

	@cSuggLOC     NVARCHAR( 10) OUTPUT, 
	@cLOC         NVARCHAR( 20) OUTPUT, 
	@cID          NVARCHAR( 20) OUTPUT, 
	@cSKU         NVARCHAR( 20) OUTPUT, 
   @cReceiptKey  NVARCHAR( 10), 
   @cPOKey       NVARCHAR( 10),
   @cReasonCode  NVARCHAR( 10),
   @cReceiptLineNumber  NVARCHAR( 5),
   @cPalletType  NVARCHAR( 10),  

   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,  @cLottable01 NVARCHAR( 18) OUTPUT,  
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,  @cLottable02 NVARCHAR( 18) OUTPUT,  
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,  @cLottable03 NVARCHAR( 18) OUTPUT,  
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,  @dLottable04 DATETIME      OUTPUT,  
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,   
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,   
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,  
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,  
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,  
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,  
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,  
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,  
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,  
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,  
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,  
	@nAction      INT, --0 Jump Screen, 1 Validation(pass through all input fields), 2 Update, 3 Prepare output fields .....
	@nAfterScn    INT OUTPUT, @nAfterStep    INT OUTPUT, 
   @nErrNo             INT            OUTPUT, 
   @cErrMsg            NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @nShelfLife FLOAT
   DECLARE @cResultCode NVARCHAR( 60)
   DECLARE
   @nRowCount            INT,
   @cPalletTypeInUse     NVARCHAR( 5),
   @nCheckDigit          INT,
   @cActLoc              NVARCHAR( 20),
   @cPalletTypeSave      NVARCHAR( 10),
   @cLoseIDlocSkipID     NVARCHAR( 1),
   @cRefNo               NVARCHAR(20),
   @cSQL                 NVARCHAR(1000),
   @cSQLParam            NVARCHAR(1000),
   @cSuggestedLoc        NVARCHAR(10),
   @cSuggestedLocSP      NVARCHAR(20),
   @cLoseID              NVARCHAR( 10),
   @cAutoID              NVARCHAR( 10),
   @cRECType             NVARCHAR( 10),
   @cActSKU              NVARCHAR( 30)

   SET @nAfterScn = 0
   SET @nAfterStep = 0
   
   SELECT
   @cRefNo = V_String26
   FROM RDT.RDTMOBREC
   WHERE Mobile = @nMobile

   IF @nAction = 1 --Validate fields
   BEGIN
	   IF @nFunc = 1580 
	   BEGIN
         IF @nInputKey = 1
         BEGIN
            IF( @nStep = 99 )
            BEGIN
               IF (ISNULL( rdt.RDTGetConfig( @nFunc, 'ValidatePalletType', @cStorerKey),'0') != '0')
               BEGIN
                  SELECT 
                  @cPalletTypeInUse = PalletTypeInUse
                  FROM dbo.PalletTypeMaster WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND Facility = @cFacility
                     AND PalletType = @cPalletType

                  IF @@ROWCOUNT = 0
                  BEGIN
                     SET @nErrNo = 212601
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --212601Pallet Type Not Configured
                     GOTO Quit
                  END

                  IF @cPalletTypeInUse != 'Y'
                  BEGIN
                     SET @nErrNo = 212602
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --212602Pallet Type Not In Use
                     GOTO Quit
                  END

                  SET @cPalletTypeSave = @cPalletType
               END
            END
            IF ( @nStep = 2 )
            BEGIN

               IF ISNULL(rdt.RDTGetConfig( 0, 'ReceiveDefaultToLoc', @cStorerKey),'') = @cLOC
                  GOTO QUIT

               SELECT
                  @nCheckDigit = CheckDigitLengthForLocation
               FROM dbo.FACILITY WITH (NOLOCK)
               WHERE facility = @cFacility

               IF @nCheckDigit > 0
               BEGIN
                  SELECT @cActLoc = loc 
                  FROM dbo.LOC WITH (NOLOCK)
                  WHERE Facility = @cFacility AND CONCAT(LOC,LOCCHECKDIGIT) = @cLOC
                  SET @nRowCount = @@ROWCOUNT
                  IF @nRowCount > 1
                  BEGIN
                     SET @nErrNo = 212603
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --212603Unique location not identified
                     GOTO Quit
                  END
                  ELSE IF @nRowCount = 0
                  BEGIN
                     SET @nErrNo = 212604
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --212604Loc Not Found
                     GOTO Quit
                  END
                  --SET @nAfterStep = 3
                  SET @cLOC = @cActLoc
                  GOTO QUIT
               END
            END
            IF ( @nStep = 5 )
            BEGIN
               SELECT @cRECType = R.RECType,@cActSKU = RD.Sku
               FROM dbo.Receipt R WITH (NOLOCK)
                     INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey
               WHERE R.Facility = @cFacility AND R.StorerKey = @cStorerKey
                     AND R.ReceiptKey = @cReceiptKey AND (@cPOKey='NOPO' or RD.POKey = @cPOKey)
                     AND RD.UserDefine01 = @cSKU AND QtyExpected > QtyReceived
               -- SET @nRowCount = @@ROWCOUNT
               -- IF @cRECType = 'FACTORY'
               -- BEGIN
               --    IF @nRowCount = 0
               --    BEGIN
               --       SET @nErrNo = 212608
               --       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --212608No line found
               --       GOTO Quit
               --    END
               --    ELSE IF @nRowCount > 1
               --    BEGIN
               --       SET @nErrNo = 212609
               --       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --212609Multi Line found
               --       GOTO Quit
               --    END
               --    IF EXISTS (SELECT 1 FROM dbo.SerialNo WITH (NOLOCK)
               --    WHERE SerialNo = @cSKU AND Status = '1')
               --    BEGIN
               --       SET @nErrNo = 212610
               --       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --212610SN Received
               --       GOTO Quit
               --    END
                  
               --END
            END
         END

		END
      GOTO Quit
	END
   IF @nAction = 2 --Update
   BEGIN
      IF @nFunc = 1580 
	   BEGIN
         IF @nInputKey = 1
         BEGIN
            IF( @nStep = 1 )
            BEGIN
               IF @cLOC != ''
               BEGIN
                  SELECT
                  @nCheckDigit = CheckDigitLengthForLocation
                  FROM dbo.FACILITY WITH (NOLOCK)
                  WHERE facility = @cFacility

                  IF @nCheckDigit > 0
                  BEGIN
                     SELECT @cActLoc = CONCAT(LOC,LOCCHECKDIGIT) 
                     FROM dbo.LOC WITH (NOLOCK)
                     WHERE Facility = @cFacility AND LOC = @cLOC

                     SET @nRowCount = @@ROWCOUNT
                     IF @nRowCount > 0
                     BEGIN
                        SET @cLOC = @cActLoc
                        GOTO QUIT
                     END
                  END
               END
            END
         END
         ELSE IF @nInputKey = 0
         BEGIN
            IF( @nStep = 3 )
            BEGIN
               IF @cLOC != ''
               BEGIN
                  SELECT
                  @nCheckDigit = CheckDigitLengthForLocation
                  FROM dbo.FACILITY WITH (NOLOCK)
                  WHERE facility = @cFacility

                  IF @nCheckDigit > 0
                  BEGIN
                     SELECT @cActLoc = CONCAT(LOC,LOCCHECKDIGIT) 
                     FROM dbo.LOC WITH (NOLOCK)
                     WHERE Facility = @cFacility AND LOC = @cLOC

                     SET @nRowCount = @@ROWCOUNT
                     IF @nRowCount > 0
                     BEGIN
                        SET @cLOC = @cActLoc
                        GOTO QUIT
                     END
                  END
               END
            END
         END
      END
   END
   IF @nAction = 3 --Prepare Fields
   BEGIN
      IF @nFunc IN( 1580, 1581) 
	   BEGIN
         IF @nInputKey = 1
         BEGIN
            IF( @nStep = 2 )
            BEGIN
               SET @cLoseIDlocSkipID = rdt.RDTGetConfig( @nFunc, 'LoseIDlocSkipID', @cStorerKey)
               IF ISNULL(@cLoseIDlocSkipID,'0')<>'0'
               BEGIN
                  SELECT @cLoseID = LoseID
                  FROM dbo.LOC WITH (NOLOCK)
                     WHERE Facility = @cFacility AND LOC = @cLOC
                  IF @cLoseID = '1'
                  BEGIN
                     DECLARE @cAutoGenID NVARCHAR(20)
                     SET @cAutoGenID = rdt.RDTGetConfig( @nFunc, 'AutoGenID', @cStorerKey)
                     IF @cAutoGenID = '0'
                        SET @cAutoGenID = ''
                     IF @cAutoGenID <> ''
                     BEGIN
                        EXEC rdt.rdt_PieceReceiving_AutoGenID @nMobile, @nFunc, @nStep, @cLangCode
                        ,@cAutoGenID          --@cAutoGenID
                        ,@cReceiptKey
                        ,@cPOKey
                        ,@cLOC
                        ,@cID
                        ,''            --@cOption
                        ,@cAutoID  OUTPUT
                        ,@nErrNo   OUTPUT
                        ,@cErrMsg  OUTPUT
                        IF @nErrNo <> 0
                           GOTO Quit
                        
                        SET @cID = @cAutoID
                     END

                     IF(ISNULL(rdt.RDTGetConfig( @nFunc, 'ValidatePalletType', @cStorerKey),'0'))!='0' -- Capture pallet type
                     BEGIN
                        SELECT 
                           @cPalletType = PalletType
                        FROM dbo.PalletTypeMaster WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                        AND Facility = @cFacility
                        AND PalletTypeInUse = 'Y'

                        SET @nRowCount = @@ROWCOUNT
                        IF @nRowCount > 1
                        BEGIN
                           SET @cFieldAttr01='1'
                           SET @cOutField01 = ''
                           -- Go to next screen
                           SET @nAfterScn = 6382
                           SET @nAfterStep = 99
                           GOTO Quit
                        END
                        ELSE IF @nRowCount=1
                        BEGIN
                           SET @cPalletTypeSave = @cPalletType
                        END
                     END

                     -- Prep next screen var
                     SET @cLottable01 = IsNULL( @cLottable01, '')
                     SET @cLottable02 = IsNULL( @cLottable02, '')
                     SET @cLottable03 = IsNULL( @cLottable03, '')
				         SET @dLottable04 = 0
                     SET @cOutField01 = @cLottable01
                     SET @cOutField02 = @cLottable02
                     SET @cOutField03 = @cLottable03
                     -- SET @cOutField04 = CASE WHEN @dLottable04 IS NULL THEN rdt.rdtFormatDate( @dLottable04) END
                     SET @cOutField04 = rdt.rdtFormatDate( @dLottable04)

                     EXEC rdt.rdtSetFocusField @nMobile, 1 --Lottable01
                     SET @cInField01 =''
                     SET @cInField02 =''
                     SET @cInField03 =''
                     SET @cInField04 =''
                  
                     -- Go to next screen
                     SET @nAfterScn = @nScn + 2
                     SET @nAfterStep = @nStep + 2
                  END
                  
               END
            END
            IF( @nStep IN( 6,10 ))
            BEGIN
               GOTO GOTO_LOC_SCREEN
            END
            GOTO Quit
         END
         ELSE IF @nInputKey = 0
         BEGIN
            IF( @nStep in (4,6,10,99) )
            BEGIN
               GOTO GOTO_LOC_SCREEN
            END
         END
      END
   END


GOTO_LOC_SCREEN:
   SET @cLoseIDlocSkipID = rdt.RDTGetConfig( @nFunc, 'LoseIDlocSkipID', @cStorerKey)
   IF ISNULL(@cLoseIDlocSkipID,'0')<>'0'
   BEGIN
      SELECT @cLoseID = LoseID
      FROM dbo.LOC WITH (NOLOCK)
         WHERE Facility = @cFacility AND LOC = @cLOC
      IF @cLoseID = '1'
      BEGIN
         -- Prepare prev screen var
         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = @cPOKey
         SET @cOutField03 = @cRefNo

         SET @cLOC = rdt.RDTGetConfig( 0, 'ReceiveDefaultToLoc', @cStorerKey)
         IF @cLOC = '0' SET @cLOC = ''

         SET @cSuggestedLocSP = rdt.RDTGetConfig( @nFunc, 'SuggestedLocSP', @cStorerKey)
         IF @cSuggestedLocSP = '0'
         SET @cSuggestedLocSP = ''
         -- (cc03)
         IF @cSuggestedLocSP <> ''
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSuggestedLocSP) +
               ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cReceiptKey, @cPOKey, @cExtASN, @cToLOC, @cToID, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, @nAfterStep, ' +
               ' @cSuggestedLoc OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@cStorerkey   NVARCHAR( 15), ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cPOKey       NVARCHAR( 10), ' +
               '@cExtASN      NVARCHAR( 20), ' +
               '@cToLOC       NVARCHAR( 10), ' +
               '@cToID        NVARCHAR( 18), ' +
               '@cLottable01  NVARCHAR( 18), ' +
               '@cLottable02  NVARCHAR( 18), ' +
               '@cLottable03  NVARCHAR( 18), ' +
               '@dLottable04  DATETIME,      ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@nQTY         INT,           ' +
               '@nAfterStep   INT,           ' +
               '@cSuggestedLoc NVARCHAR( 10) OUTPUT, ' +
               '@nErrNo       INT           OUTPUT, ' +
               '@cErrMsg      NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cID,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, 0, @nStep,
               @cSuggestedLoc OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            IF @cSuggestedLoc <> ''
               SET @cLOC = @cSuggestedLoc
         END

         SET @cOutField04 = @cLoc --'' -- LOC -- (ChewKP06)

         -- Go to previous screen
         SET @nAfterScn = 1751
         SET @nAfterStep = 2
         GOTO Quit
      END
   END
   GOTO Quit

Exception:
   ROLLBACK TRANSACTION

Quit:
UPDATE RDT.RDTMOBREC SET
   C_String1 = @cPalletTypeSave,
   C_String2 = @cLoseID
   WHERE Mobile = @nMobile

END; 

SET QUOTED_IDENTIFIER OFF 

GO