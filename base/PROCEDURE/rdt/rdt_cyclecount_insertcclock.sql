SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_CycleCount_InsertCCLock                         */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Insert new CCDetail after confirmed items counted           */
/*                                                                      */
/* Called from: rdtfnc_CycleCount                                       */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 14-May-2009 1.0  MaryVong    Created                                 */
/* 22-Dec-2011 1.1  Ung         SOS235351 Handle empty LOC no StorerKey */
/* 20-Dec-2017 1.2  James       Remove ANSI_WARNINGS (james01)          */
/************************************************************************/

CREATE PROC [RDT].[rdt_CycleCount_InsertCCLock] (
   @nMobile           INT,
   @cCCRefNo          NVARCHAR( 10),
   @cCCSheetNo        NVARCHAR( 10),
   @nCCCountNo        INT,
   @cStorer           NVARCHAR( 15),
   @cUserName         NVARCHAR( 18),
   @cSKU              NVARCHAR( 20),
   @cLOT              NVARCHAR( 10),
   @cLOC              NVARCHAR( 10),
   @cID               NVARCHAR( 18),
   @nCntQTY           INT,
   @cLottable01       NVARCHAR( 18),
   @cLottable02       NVARCHAR( 18),
   @cLottable03       NVARCHAR( 18),
   @dLottable04       DATETIME,
   @dLottable05       DATETIME,
   @cRefNo            NVARCHAR( 20),
   @cLangCode         VARCHAR (3),
   @nErrNo            INT          OUTPUT,
   @cErrMsg           NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @cZone1  NVARCHAR( 10),
      @cZone2  NVARCHAR( 10),
      @cZone3  NVARCHAR( 10),
      @cZone4  NVARCHAR( 10),
      @cZone5  NVARCHAR( 10),
      @cAisle  NVARCHAR( 10),
      @cLevel  NVARCHAR( 10),
      @cLottableFlag    NVARCHAR( 1),
      @cLOTTABLE01LABEL NVARCHAR( 20),
      @cLOTTABLE02LABEL NVARCHAR( 20),
      @cLOTTABLE03LABEL NVARCHAR( 20),
      @cLOTTABLE04LABEL NVARCHAR( 20)

   SET @cZone1 = ''
   SET @cZone2 = ''
   SET @cZone3 = ''
   SET @cZone4 = ''
   SET @cZone5 = ''
   SET @cAisle = ''
   SET @cLevel = ''
   SET @cLottableFlag    = 'N'
   SET @cLOTTABLE01LABEL = ''
   SET @cLOTTABLE02LABEL = ''
   SET @cLOTTABLE03LABEL = ''
   SET @cLOTTABLE04LABEL = ''

   -- Check any Lottable label setup for the SKU
   SELECT
      @cLOTTABLE01LABEL = ISNULL(LOTTABLE01LABEL, ''),
      @cLOTTABLE02LABEL = ISNULL(LOTTABLE02LABEL, ''),
      @cLOTTABLE03LABEL = ISNULL(LOTTABLE03LABEL, ''),
      @cLOTTABLE04LABEL = ISNULL(LOTTABLE04LABEL, '')
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorer
   AND   SKU = @cSKU

   IF @cLOTTABLE01LABEL <> '' OR @cLOTTABLE02LABEL <> '' OR
      @cLOTTABLE03LABEL <> '' OR @cLOTTABLE04LABEL <> ''
   BEGIN
      SET @cLottableFlag = 'Y'
   END

   -- Check again if any record inserted before (regardless of status)
   -- New SKU or LOC or ID
   IF @cLottableFlag = 'Y'
   BEGIN
      IF NOT EXISTS( SELECT 1
         FROM RDT.RDTCCLock WITH (NOLOCK)
         WHERE Mobile = @nMobile
         AND CCKey = @cCCRefNo
         AND SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
         AND AddWho = @cUserName
         AND SKU = CASE WHEN @cSKU = '' THEN SKU ELSE @cSKU END
         AND Loc = CASE WHEN @cLOC = '' THEN Loc ELSE @cLOC END
         AND Id  = CASE WHEN @cID  = '' THEN Id  ELSE @cID  END
         AND Status <> '9' -- (Vicky03)
         AND Lottable01 = @cLottable01
         AND Lottable02 = @cLottable02
         AND Lottable03 = @cLottable03
         AND Lottable04 = @dLottable04)
      BEGIN
         -- Get Zones/Aisle/Level, if any
         SELECT TOP 1
            @cZone1 = Zone1,
            @cZone2 = Zone2,
            @cZone3 = Zone3,
            @cZone4 = Zone4,
            @cZone5 = Zone5,
            @cAisle = Aisle,
            @cLevel = Level
         FROM RDT.RDTCCLock WITH (NOLOCK)
         WHERE Mobile = @nMobile
         AND CCKey = @cCCRefNo
         AND SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
         AND AddWho = @cUserName
         -- Get from latest record, not necessary status = '1'
         ORDER BY EditDate DESC

         BEGIN TRAN
         INSERT INTO RDT.RDTCCLock
            (Mobile,    CCKey,      SheetNo,    CountNo,    StorerKey,  Sku,     Lot,    Loc,    Id,
            Zone1,      Zone2,      Zone3,      Zone4,      Zone5,      Aisle,   Level,
            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
            SystemQty,  CountedQty, Status,     RefNo,      AddWho,     AddDate)
         VALUES (
            @nMobile,     @cCCRefNo,    @cCCSheetNo,  @nCCCountNo,  @cStorer,     @cSKU,  @cLOT,   @cLOC, @cID,
            @cZone1,      @cZone2,      @cZone3,      @cZone4,      @cZone5,     @cAisle, @cLevel,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            0,            @nCntQTY,     '0',          @cRefNo,      @cUserName,   GETDATE() )

         IF @@ERROR = 0
            COMMIT TRAN
         ELSE
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 66876
            SET @cErrMsg = rdt.rdtgetmessage( 66876, @cLangCode, 'DSP') -- ADDCCLockFail
            GOTO QUIT
         END
      END
   END
   ELSE
   BEGIN
      IF NOT EXISTS( SELECT 1
         FROM RDT.RDTCCLock WITH (NOLOCK)
         WHERE Mobile = @nMobile
         AND CCKey = @cCCRefNo
         AND SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
         AND AddWho = @cUserName
         AND SKU = CASE WHEN @cSKU = '' THEN SKU ELSE @cSKU END
         AND Loc = CASE WHEN @cLOC = '' THEN Loc ELSE @cLOC END
         AND Id  = CASE WHEN @cID  = '' THEN Id  ELSE @cID  END
         AND SystemQty < CountedQty
         AND Status <> '9') -- (Vicky03)
      BEGIN
         -- Get Zones/Aisle/Level, if any
         SELECT TOP 1
            @cZone1 = Zone1,
            @cZone2 = Zone2,
            @cZone3 = Zone3,
            @cZone4 = Zone4,
            @cZone5 = Zone5,
            @cAisle = Aisle,
            @cLevel = Level
         FROM RDT.RDTCCLock WITH (NOLOCK)
         WHERE Mobile = @nMobile
         AND CCKey = @cCCRefNo
         AND SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
         AND AddWho = @cUserName
         -- Get from latest record, not necessary status = '1'
         ORDER BY EditDate DESC

         BEGIN TRAN
         INSERT INTO RDT.RDTCCLock
            (Mobile,    CCKey,      SheetNo,    CountNo,    StorerKey,  Sku,     Lot,    Loc,    Id,
            Zone1,      Zone2,      Zone3,      Zone4,      Zone5,      Aisle,   Level,
            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
            SystemQty,  CountedQty, Status,     RefNo,      AddWho,     AddDate)
         VALUES (
            @nMobile,     @cCCRefNo,    @cCCSheetNo,  @nCCCountNo,  @cStorer,     @cSKU,  @cLOT,   @cLOC, @cID,
            @cZone1,      @cZone2,      @cZone3,      @cZone4,      @cZone5,     @cAisle, @cLevel,
            '',           '',           '',           NULL,         NULL,
            0,            @nCntQTY,     '0',          @cRefNo,      @cUserName,   GETDATE() )

         IF @@ERROR = 0
            COMMIT TRAN
         ELSE
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 66876
            SET @cErrMsg = rdt.rdtgetmessage( 66876, @cLangCode, 'DSP') -- ADDCCLockFail
            GOTO QUIT
         END
      END
   END
   QUIT:

END

GO