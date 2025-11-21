SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_898RcvCfm12                                           */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Purpose: Allow multi SKU UCC, same SKU multi line (different ExternLineNo) */
/*                                                                            */
/* Date       Rev  Author      Purposes                                       */
/* 2023-08-22 1.0  Ung         WMS-23484 based on rdt_Receive ver 4.4         */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_898RcvCfm12] (
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @nErrNo         INT          OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT, -- screen limitation, 20 char max
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cReceiptKey    NVARCHAR( 10),
   @cPOKey         NVARCHAR( 10), -- Blank = receive to ReceiptDetail with blank POKey
   @cToLOC         NVARCHAR( 10),
   @cToID          NVARCHAR( 18), -- Blank = receive to blank ToID
   @cSKUCode       NVARCHAR( 20), -- SKU code. Not SKU barcode
   @cSKUUOM        NVARCHAR( 10),
   @nSKUQTY        INT,       -- In master unit
   @cUCC           NVARCHAR( 20),
   @cUCCSKU        NVARCHAR( 20),
   @nUCCQTY        INT,       -- In master unit. Pass in the QTY for UCCWithDynamicCaseCNT
   @cCreateUCC     NVARCHAR( 1),  -- Create UCC. 1=Yes, the rest=No
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @dLottable05    DATETIME,
   @nNOPOFlag      INT,
   @cConditionCode NVARCHAR( 10),
   @cSubreasonCode NVARCHAR( 10),
   @cReceiptLineNumberOutput NVARCHAR( 5) = '' OUTPUT, 
   @cDebug         NVARCHAR( 1)  = '0', 
   @cSerialNo      NVARCHAR( 30) = '', 
   @nSerialQTY     INT = 0, 
   @nBulkSNO       INT = 0, 
   @nBulkSNOQTY    INT = 0
   
) AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @b_success  INT
DECLARE @nTranCount INT
DECLARE @nRowCount  INT
DECLARE @cDocType   NVARCHAR( 1)
DECLARE @cSKU       NVARCHAR( 20)
DECLARE @nQTY       INT
DECLARE @cUOM       NVARCHAR( 10)
--DECLARE @cDebug     NVARCHAR( 1) -- (ChewKP01)
DECLARE @cSQL       NVARCHAR(MAX)
DECLARE @cSQLParam  NVARCHAR(MAX)
DECLARE @cCustomSQL NVARCHAR(MAX)
DECLARE @nSrQTY      INT
DECLARE @nRDQTY      INT
DECLARE @nSKUNotInASN   INT = 0    -- (james04)
DECLARE @cSkipCheckingSKUNotInASN   NVARCHAR( 1)   -- (james04)

/*-------------------------------------------------------------------------------

                                 Get storer config

-------------------------------------------------------------------------------*/
-- Storer config var
DECLARE @cAllow_OverReceipt     NVARCHAR( 1)
DECLARE @cByPassTolerance       NVARCHAR( 1)
DECLARE @cStorerConfig_UCC      NVARCHAR( 1)
DECLARE @cUCCWithDynamicCaseCnt NVARCHAR( 1)
DECLARE @cUCCWithMultiSKU       NVARCHAR( 1)
DECLARE @cAddNwUCCR             NVARCHAR( 1)
DECLARE @nDisAllowDuplicateIdsOnRFRcpt INT
DECLARE @cIncludePOKeyFilter    NVARCHAR( 1) -- (Vicky04)
DECLARE @cReceiptDetailFilterSP NVARCHAR( 20)

DECLARE @cDuplicateFromMatchValue    NVARCHAR(20) -- (ChewKP01)
        ,@nCount                     INT     -- (ChewKP01)
        ,@cASNMatchByPOLineValue     NVARCHAR(1) -- (ChewKP01)
        ,@cExternLineNumber          NVARCHAR(5) -- (ChewKP01)
        ,@cBorrowed_OriginalReceiptLineNumber NVARCHAR(5) -- (ChewKP01)

SET  @cASNMatchByPOLineValue = '0'    -- (ChewKP01)
SET  @cExternLineNumber = ''          -- (ChewKP01)
--SET  @cDebug = '0'                    -- (ChewKP01)

-- (ChewKP01)
IF @cPOKey = 'NOPO'
BEGIN
   SET @cPOKey = ''
END

-- NSQLConfig 'DisAllowDuplicateIdsOnRFRcpt'
SET @nDisAllowDuplicateIdsOnRFRcpt = 0 -- Default Off
SELECT @nDisAllowDuplicateIdsOnRFRcpt = NSQLValue
FROM dbo.NSQLConfig (NOLOCK)
WHERE ConfigKey = 'DisAllowDuplicateIdsOnRFRcpt'

-- StorerConfig 'UCC'
SET @cStorerConfig_UCC = '0' -- Default Off
SELECT @cStorerConfig_UCC = CASE WHEN SValue = '1' THEN '1' ELSE '0' END
FROM dbo.StorerConfig (NOLOCK)
WHERE StorerKey = @cStorerKey
AND ConfigKey = 'UCC'

-- RDT StorerConfig 'UCCWithDynamicCaseCnt'
SET @cUCCWithDynamicCaseCnt = rdt.RDTGetConfig( 0, 'UCCWithDynamicCaseCnt', @cStorerKey)
IF ISNULL(RTRIM(@cUCCWithDynamicCaseCnt),'') = ''
BEGIN
   SET @cUCCWithDynamicCaseCnt = '0' -- Default=No
END

SET @cUCCWithMultiSKU = rdt.RDTGetConfig( @nFunc, 'UCCWithMultiSKU', @cStorerKey)

-- RDT StorerConfig 'AddNwUCCR'
SET @cAddNwUCCR = rdt.RDTGetConfig( @nFunc, 'AddNwUCCR', @cStorerKey)
IF ISNULL(RTRIM(@cAddNwUCCR),'') = ''
BEGIN
   SET @cAddNwUCCR = '0' -- Default=No
END

-- Added by Vicky for SOS#105011 (Start - Vicky04)
-- RDT StorerConfig 'IncludePOKeyFilter'
SET @cIncludePOKeyFilter = ''
SET @cIncludePOKeyFilter = rdt.RDTGetConfig( @nFunc, 'IncludePOKeyFilter', @cStorerKey)
IF ISNULL(RTRIM(@cIncludePOKeyFilter), '') = ''
BEGIN
   SET @cIncludePOKeyFilter = '0'
END
-- Added by Vicky for SOS#105011 (End - Vicky04)

SET @cReceiptDetailFilterSP = rdt.RDTGetConfig( @nFunc, 'ReceiptDetailFilterSP', @cStorerKey)
IF @cReceiptDetailFilterSP = '0'
   SET @cReceiptDetailFilterSP = ''

SET @cDuplicateFromMatchValue = rdt.RDTGetConfig( @nFunc, 'DuplicateFromMatchValue', @cStorerKey)
IF @cDuplicateFromMatchValue = '0'
   SET @cDuplicateFromMatchValue = ''

SET @cSkipCheckingSKUNotInASN = rdt.RDTGetConfig( @nFunc, 'SkipCheckingSKUNotInASN', @cStorerKey)

/*-------------------------------------------------------------------------------

                 Convert parameters

-------------------------------------------------------------------------------*/
IF @cStorerKey  IS NULL SET @cStorerKey  = ''
IF @cFacility   IS NULL SET @cFacility   = ''
IF @cReceiptKey IS NULL SET @cReceiptKey = ''
IF @cPOKey      IS NULL SET @cPOKey      = ''
IF @cToLOC      IS NULL SET @cToLOC      = ''
IF @cToID       IS NULL SET @cToID       = ''
IF @cSKUCode    IS NULL SET @cSKUCode    = ''
IF @cSKUUOM     IS NULL SET @cSKUUOM     = ''
IF @nSKUQTY     IS NULL SET @nSKUQTY     = 0
IF @cUCC        IS NULL SET @cUCC        = ''
IF @nUCCQTY     IS NULL SET @nUCCQTY     = 0
IF @cCreateUCC  IS NULL SET @cCreateUCC  = ''
IF @cLottable01 IS NULL SET @cLottable01 = ''
IF @cLottable02 IS NULL SET @cLottable02 = ''
IF @cLottable03 IS NULL SET @cLottable03 = ''
IF @dLottable04 = 0     SET @dLottable04 = NULL
IF @dLottable05 = 0     SET @dLottable05 = NULL
IF @cSerialNo   IS NULL SET @cSerialNo   = ''
IF @nSerialQTY  IS NULL SET @nSerialQTY  = 0

-- Truncate the time portion
IF @dLottable04 IS NOT NULL
   SET @dLottable04 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dLottable04, 120), 120)
IF @dLottable05 IS NOT NULL
   SET @dLottable05 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dLottable05, 120), 120)


/*-------------------------------------------------------------------------------

                                 Validate data

-------------------------------------------------------------------------------*/
DECLARE @cChkFacility  NVARCHAR( 5)
DECLARE @cChkStorerKey NVARCHAR( 15)
DECLARE @cChkStatus    NVARCHAR( 10)
DECLARE @cChkASNStatus NVARCHAR( 10)
DECLARE @cChkLOC       NVARCHAR( 10)
DECLARE @cUCCPOkey     NVARCHAR( 10)-- (Vicky02)

-- Validate StorerKey
IF @cStorerKey = ''
BEGIN
   SET @nErrNo = 60305
   SET @cErrMsg = rdt.rdtgetmessage( 60305, @cLangCode, 'DSP') --'Need StorerKey'
   GOTO Fail
END

-- Validate Facility
IF @cFacility = ''
BEGIN
   SET @nErrNo = 60306
   SET @cErrMsg = rdt.rdtgetmessage( 60306, @cLangCode, 'DSP') --'Need Facility'
   GOTO Fail
END

-- Validate ReceiptKey
IF @cReceiptKey = ''
BEGIN
   SET @nErrNo = 60307
   SET @cErrMsg = rdt.rdtgetmessage( 60307, @cLangCode, 'DSP') --'Need ASN'
   GOTO Fail
END

-- Get the ASN
SELECT
   @cDocType = DocType,
   @cChkFacility = Facility,
   @cChkStorerKey = StorerKey,
   @cChkStatus = Status,
   @cChkASNStatus = ASNStatus
FROM dbo.Receipt (NOLOCK)
WHERE ReceiptKey = @cReceiptKey

-- Validate ASN exists
IF @@ROWCOUNT <> 1
BEGIN
   SET @nErrNo = 60308
   SET @cErrMsg = rdt.rdtgetmessage( 60308, @cLangCode, 'DSP') --'ASN not found'
   GOTO Fail
END

-- Validate ASN in different facility
IF @cFacility <> @cChkFacility
BEGIN
   SET @nErrNo = 60309
   SET @cErrMsg = rdt.rdtgetmessage( 60309, @cLangCode, 'DSP') --'ASN not in FAC'
   GOTO Fail
END

-- Validate ASN belong to diff storer
IF @cStorerKey <> @cChkStorerKey
BEGIN
   SET @nErrNo = 60310
   SET @cErrMsg = rdt.rdtgetmessage( 60310, @cLangCode, 'DSP') --'Diff storer'
   GOTO Fail
END

/* RDT finalize update ReceiptDetail and trigger will update Receipt.OpenQTY
   If Receipt.OpenQTY <= 0 will update Receipt.Status = 9.
   RDT might still have stock need to over receive, so cannot check status

-- Validate status
IF @cChkStatus <> '0'
BEGIN
   SET @nErrNo = 60311
   SET @cErrMsg = rdt.rdtgetmessage( 60311, @cLangCode, 'DSP') --'ASN not open'
   GOTO Fail
END
*/

-- Validate ASN status
IF @cChkASNStatus > '1' -- (james03)
BEGIN
   -- Bypass ASNStatus check if it is setup in codelkup  (james02)
   IF NOT EXISTS (SELECT 1 FROM dbo.CodeLkUp WITH (NOLOCK)
                  WHERE ListName = 'EXCLASNCHK'
                  AND   Code = @cChkASNStatus
                  AND   Storerkey = @cStorerKey)
   BEGIN
      SET @nErrNo = 60312
      SET @cErrMsg = rdt.rdtgetmessage( 60312, @cLangCode, 'DSP') --'Bad ASNStatus'
      GOTO Fail
   END
END

-- Validate POKey
IF @cPOKey <> '' AND NOT EXISTS(
      SELECT 1
      FROM dbo.ReceiptDetail (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND POKey = @cPOKey)
BEGIN
   SET @nErrNo = 60313
   SET @cErrMsg = rdt.rdtgetmessage( 60313, @cLangCode, 'DSP') --'PO not in ASN'
   GOTO Fail
END

-- Get the LOC
SELECT
   @cChkLOC = LOC,
   @cChkFacility = Facility
FROM dbo.LOC (NOLOCK)
WHERE LOC = @cToLOC

-- Validate ToLOC
IF @cChkLOC IS NULL OR @cChkLOC = ''
BEGIN
   SET @nErrNo = 60314
   SET @cErrMsg = rdt.rdtgetmessage( 60314, @cLangCode, 'DSP') --'Invalid LOC'
   GOTO Fail
END

-- Validate ToLOC not in facility
IF @cChkFacility <> @cFacility
BEGIN
   SET @nErrNo = 60315
   SET @cErrMsg = rdt.rdtgetmessage( 60315, @cLangCode, 'DSP') --'LOC not in FAC'
   GOTO Fail
END

-- Validate ToID
IF @nDisAllowDuplicateIdsOnRFRcpt = '1' AND @cToID <> ''
BEGIN
/*
   IF EXISTS( SELECT 1
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK, INDEX=IDX_LOTxLOCxID_ID)
         INNER JOIN dbo.LOC LOC WITH (NOLOCK, INDEX=IX_LOC_Facility) ON (LLI.LOC = LOC.LOC)
      WHERE LLI.ID = @cToID
         AND LLI.QTY > 0
         AND LOC.Facility = @cFacility) -- Check duplicate ID within same facility only
*/
   DECLARE @nToID_InUsed INT
   SELECT @nToID_InUsed = 1
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LLI.ID = @cToID
         AND LLI.QTY > 0
         AND LOC.Facility = @cFacility OPTION (RECOMPILE)
		 
   IF @nToID_InUsed = 1
   BEGIN
      SET @nErrNo = 60316
      SET @cErrMsg = rdt.rdtgetmessage( 60316, @cLangCode, 'DSP') --'ID in used'
      GOTO Fail
   END
END

-- Validate both SKU and UCC passed-in
IF @cSKUCode <> '' AND @cUCC <> ''
BEGIN
   SET @nErrNo = 60317
   SET @cErrMsg = rdt.rdtgetmessage( 60317, @cLangCode, 'DSP') --'EitherSKUOrUCC'
   GOTO Fail
END

-- Validate both SKU and UCC not passed-in
IF @cSKUCode = '' AND @cUCC = ''
BEGIN
   SET @nErrNo = 60318
   SET @cErrMsg = rdt.rdtgetmessage( 60318, @cLangCode, 'DSP') --'SKU or UCC req'
   GOTO Fail
END

-- Validate SKU
IF @cSKUCode <> ''
BEGIN
   IF NOT EXISTS( SELECT 1
      FROM dbo.SKU SKU (NOLOCK)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKUCode)
   BEGIN
      SET @nErrNo = 60319
      SET @cErrMsg = rdt.rdtgetmessage( 60319, @cLangCode, 'DSP') --'Invalid SKU'
      GOTO Fail
   END

   SET @nSKUNotInASN = 0
   IF NOT EXISTS( SELECT 1
      FROM dbo.ReceiptDetail (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND SKU = @cSKUCode)
      SET @nSKUNotInASN = 1
      
   -- Validate SKU not in ASN
   -- Usually need to turn off for trade return, where SKU only get known when actual stock arrived
   IF @cSkipCheckingSKUNotInASN <> '1'
   BEGIN
      IF @nSKUNotInASN = 1
      BEGIN
         SET @nErrNo = 60320
         SET @cErrMsg = rdt.rdtgetmessage( 60320, @cLangCode, 'DSP') --'SKU not in ASN'
         GOTO Fail
      END
   END

   -- Validate UOM field
   IF @cSKUUOM = ''
   BEGIN
      SET @nErrNo = 60321
      SET @cErrMsg = rdt.rdtgetmessage( 60321, @cLangCode, 'DSP') --'UOM is needed'
      GOTO Fail
   END

   -- Validate UOM exists
   IF NOT EXISTS( SELECT 1
      FROM dbo.Pack P (NOLOCK)
         INNER JOIN dbo.SKU S (NOLOCK) ON P.PackKey = S.PackKey
      WHERE S.StorerKey = @cStorerKey
         AND S.SKU = @cSKUCode
         AND @cSKUUOM IN (
            P.PackUOM1, P.PackUOM2, P.PackUOM3, P.PackUOM4,
            P.PackUOM5, P.PackUOM6, P.PackUOM7, P.PackUOM8, P.PackUOM9))
   BEGIN
      SET @nErrNo = 60322
      SET @cErrMsg = rdt.rdtgetmessage( 60322, @cLangCode, 'DSP') --'Invalid UOM'
      GOTO Fail
   END

   -- Validate QTY
   IF RDT.rdtIsValidQTY( @nSKUQTY, 1) = 0 -- 1=Check for zero
   BEGIN
      SET @nErrNo = 60323
      SET @cErrMsg = rdt.rdtgetmessage( 60323, @cLangCode, 'DSP') --'Invalid QTY'
      GOTO Fail
   END
END

-- Validate UCC
IF @cUCC <> ''
BEGIN
   IF @cStorerConfig_UCC <> '1'
   BEGIN
      SET @nErrNo = 60324
      SET @cErrMsg = rdt.rdtgetmessage( 60324, @cLangCode, 'DSP') --'UCCTrackingOff'
      GOTO Fail
   END

   -- Get the UCC by status
   DECLARE @cUCCStatus      NVARCHAR( 10)
   DECLARE @nCount_Received INT
   DECLARE @nCount_CanBeUse INT

   IF @cIncludePOKeyFilter = '1' -- (Vicky04)
   BEGIN
      SELECT
         @nCount_Received = IsNULL( SUM( CASE WHEN Status =  '1' THEN 1 ELSE 0 END), 0), -- 1=Received
         @nCount_CanBeUse = IsNULL( SUM( CASE WHEN Status <> '1' THEN 1 ELSE 0 END), 0)  -- the rest, can be receive
      FROM dbo.UCC (NOLOCK)
      WHERE StorerKey = @cStorerKey
        AND UCCNo = @cUCC
        AND LEFT(ISNULL(Sourcekey, ''),10) = @cPOKey -- (Vicky02)
        AND SKU = CASE WHEN @cUCCWithMultiSKU = '1' THEN @cUCCSKU ELSE SKU END

   END
   ELSE
   BEGIN
      SELECT
         @nCount_Received = IsNULL( SUM( CASE WHEN Status =  '1' THEN 1 ELSE 0 END), 0), -- 1=Received
         @nCount_CanBeUse = IsNULL( SUM( CASE WHEN Status <> '1' THEN 1 ELSE 0 END), 0)  -- the rest, can be receive
      FROM dbo.UCC (NOLOCK)
      WHERE StorerKey = @cStorerKey
        AND UCCNo = @cUCC
        AND SKU = CASE WHEN @cUCCWithMultiSKU = '1' THEN @cUCCSKU ELSE SKU END
   END

   -- Check allow create new UCC
   IF @cCreateUCC = '1' AND @cAddNwUCCR <> '1'
   BEGIN
      SET @nErrNo = 60325
      SET @cErrMsg = rdt.rdtgetmessage( 60325, @cLangCode, 'DSP') --'AddNwUCCR Off'
      GOTO Fail
   END

   -- Validate UCC existance
   IF @cCreateUCC = '1' --Creating new UCC
   BEGIN
      -- Check if try to create UCC that already exists
      IF @nCount_Received > 0
      BEGIN
         SET @nErrNo = 60326
         SET @cErrMsg = rdt.rdtgetmessage( 60326, @cLangCode, 'DSP') --'CreateExistUCC'
         GOTO Fail
      END

      -- Check if try create new UCC instead of reuse existing ones
      IF @nCount_CanBeUse > 0 AND rdt.RDTGetConfig( @nFunc, 'SkipCheckReuseExistUCC', @cStorerKey) <> '1'
      BEGIN
         SET @nErrNo = 60327
         SET @cErrMsg = rdt.rdtgetmessage( 60327, @cLangCode, 'DSP') --'TryUseExistUCC'
         GOTO Fail
      END

      SET @cUCCStatus = '0' -- 0=Open
   END
   ELSE -- Receive existing UCC
   BEGIN
      -- Check if the UCC is already received
      IF @nCount_Received > 0
      BEGIN
         -- Entire UCC status = 1
         IF EXISTS( SELECT 1 
            FROM dbo.UCC WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey 
               AND UCCNo = @cUCC
            HAVING COUNT( DISTINCT Status) = 1  -- only 1 status
               AND MIN( Status) = '1')          -- and the status is '1'
         BEGIN
            SET @nErrNo = 60328
            SET @cErrMsg = rdt.rdtgetmessage( 60328, @cLangCode, 'DSP') --'UCC AlreadyRCV'
            GOTO Fail
         END
      END

      -- Check if any UCC can be receive
      IF @nCount_CanBeUse < 1
      BEGIN
         SET @nErrNo = 60349
         SET @cErrMsg = rdt.rdtgetmessage( 60349, @cLangCode, 'DSP') --'UCC not found'
         GOTO Fail
      END

      -- Get the UCC status. 1 UCC could have multiple records, with different status
      DECLARE @nChkUCCQTY INT

      IF @cIncludePOKeyFilter = '1' -- (Vicky04)
      BEGIN
         SELECT TOP 1
            @cUCCStatus = Status,
            @nChkUCCQTY = QTY
         FROM dbo.UCC (NOLOCK)
         WHERE StorerKey = @cStorerKey
           AND UCCNo = @cUCC
           AND Status <> '1' -- Not received
           AND LEFT(ISNULL(Sourcekey, ''),10) = @cPOKey -- (Vicky02)
         ORDER BY Status      -- Try to use 0-Open status 1st

      END
      ELSE
      BEGIN
         SELECT TOP 1
            @cUCCStatus = Status,
            @nChkUCCQTY = QTY
         FROM dbo.UCC (NOLOCK)
         WHERE StorerKey = @cStorerKey
           AND UCCNo = @cUCC
           AND Status <> '1' -- Not received
           AND SKU = CASE WHEN @cUCCWithMultiSKU = '1' THEN @cUCCSKU ELSE SKU END
         ORDER BY Status      -- Try to use 0-Open status 1st
      END

      -- Check UCC QTY (Keyed-in and UCC.QTY diff)
      IF (@cUCCWithDynamicCaseCNT = '0') AND (@nChkUCCQTY <> @nUCCQTY)
      BEGIN
         SET @nErrNo = 60350
         SET @cErrMsg = rdt.rdtgetmessage( 60350, @cLangCode, 'DSP') --'UCCQTY<>KeyQTY'
         GOTO Fail
      END

      -- Validate UCC
      IF @cUCCWithMultiSKU <> '1'
      BEGIN
         EXEC RDT.rdtIsValidUCC @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT,
            @cUCC, -- UCC
            @cStorerKey,
            @cUCCStatus,
            @cChkSKU = @cUCCSKU,
            @nChkQTY = @nUCCQTY -- Check case count (for non-UCCWithDynamicCaseCNT)
         IF @nErrNo <> 0
         BEGIN
            GOTO Fail
         END
      END
   END

   -- Validate UCC SKU blank
   IF @cUCCSKU = ''
   BEGIN
      SET @nErrNo = 60329
      SET @cErrMsg = rdt.rdtgetmessage( 60329, @cLangCode, 'DSP') --'Need UCCSKU'
      GOTO Fail
   END

   -- Validate UCC SKU
   IF NOT EXISTS( SELECT 1
      FROM dbo.SKU SKU (NOLOCK)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cUCCSKU)
   BEGIN
      SET @nErrNo = 60330
      SET @cErrMsg = rdt.rdtgetmessage( 60330, @cLangCode, 'DSP') --'Invalid SKU'
      GOTO Fail
   END

   SET @nSKUNotInASN = 0
   IF NOT EXISTS( SELECT 1
      FROM dbo.ReceiptDetail (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND SKU = @cUCCSKU)  -- (james05)
      SET @nSKUNotInASN = 1

   -- Validate UCC SKU not in ASN
   -- Usually need to turn off for trade return, where SKU only get known when actual stock arrived
   IF @cSkipCheckingSKUNotInASN <> '1'
   BEGIN
      IF @nSKUNotInASN = 1
      BEGIN
         SET @nErrNo = 60331
         SET @cErrMsg = rdt.rdtgetmessage( 60331, @cLangCode, 'DSP') --'SKU not in ASN'
         GOTO Fail
      END
   END

   -- Validate UCC QTY
   IF RDT.rdtIsValidQTY( @nUCCQTY, 1) = 0 -- 1=Check for zero
   BEGIN
      SET @nErrNo = 60332
      SET @cErrMsg = rdt.rdtgetmessage( 60332, @cLangCode, 'DSP') --'Invalid QTY'
      GOTO Fail
   END

   -- Get UCC's UOM
   DECLARE @cUCCUOM NVARCHAR( 10)
   SELECT @cUCCUOM = CASE WHEN(IsNULL(Pack.PackUOM1,'') = '') THEN Pack.PackUOM3 ELSE Pack.PackUOM1 END
      FROM dbo.Pack Pack (NOLOCK)
      INNER JOIN dbo.SKU SKU (NOLOCK) ON Pack.PackKey = SKU.PackKey
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cUCCSKU
END

-- Copy to common variable
SET @cSKU = CASE WHEN @cSKUCode <> '' THEN @cSKUCode ELSE @cUCCSKU END
SET @cUOM = CASE WHEN @cSKUCode <> '' THEN @cSKUUOM  ELSE @cUCCUOM END
SET @nQTY = CASE WHEN @cSKUCode <> '' THEN @nSKUQTY  ELSE @nUCCQTY END

-- Get SKU's setting
DECLARE @cLottable01Required NVARCHAR( 1)
DECLARE @cLottable02Required NVARCHAR( 1)
DECLARE @cLottable03Required NVARCHAR( 1)
DECLARE @cLottable04Required NVARCHAR( 1)
DECLARE @cLottable05Required NVARCHAR( 1)
DECLARE @cPackKey NVARCHAR( 10)
DECLARE @cTariffkey NVARCHAR( 10)
DECLARE @nTolerancePercentage INT

SELECT
   @cLottable01Required = CASE WHEN Lottable01Label <> '' THEN '1' ELSE '0' END,
   @cLottable02Required = CASE WHEN Lottable02Label <> '' THEN '1' ELSE '0' END,
   @cLottable03Required = CASE WHEN Lottable03Label <> '' THEN '1' ELSE '0' END,
   @cLottable04Required = CASE WHEN Lottable04Label <> '' THEN '1' ELSE '0' END,
   @cPackKey = SKU.PackKey,
   @cTariffkey = Tariffkey,
   @nTolerancePercentage =
      CASE
         WHEN SKU.SUSR4 IS NOT NULL AND IsNumeric( SKU.SUSR4) = 1
         THEN CAST( SKU.SUSR4 AS INT)
         ELSE 0
      END
FROM dbo.SKU SKU (NOLOCK)
WHERE StorerKey = @cStorerKey
   AND SKU = @cSKU

-- Get SkipLottable setting
DECLARE @cSkipLottable01 NVARCHAR( 1)
DECLARE @cSkipLottable02 NVARCHAR( 1)
DECLARE @cSkipLottable03 NVARCHAR( 1)
DECLARE @cSkipLottable04 NVARCHAR( 1)

SET @cSkipLottable01 = rdt.RDTGetConfig( @nFunc, 'SkipLottable01', @cStorerKey)
SET @cSkipLottable02 = rdt.RDTGetConfig( @nFunc, 'SkipLottable02', @cStorerKey)
SET @cSkipLottable03 = rdt.RDTGetConfig( @nFunc, 'SkipLottable03', @cStorerKey)
SET @cSkipLottable04 = rdt.RDTGetConfig( @nFunc, 'SkipLottable04', @cStorerKey)

IF @cSkipLottable01 = '1' SELECT @cLottable01Required = '0', @cLottable01 = ''
IF @cSkipLottable02 = '1' SELECT @cLottable02Required = '0', @cLottable02 = ''
IF @cSkipLottable03 = '1' SELECT @cLottable03Required = '0', @cLottable03 = ''
IF @cSkipLottable04 = '1' SELECT @cLottable04Required = '0', @dLottable04 = NULL

-- Validate lottable
IF @cLottable01Required = '1' AND @cLottable01 = ''
BEGIN
   SET @nErrNo = 60333
   SET @cErrMsg = rdt.rdtgetmessage( 60333, @cLangCode, 'DSP') --'Need Lottable1'
   GOTO Fail
END

IF @cLottable02Required = '1' AND @cLottable02 = ''
BEGIN
   SET @nErrNo = 60334
   SET @cErrMsg = rdt.rdtgetmessage( 60334, @cLangCode, 'DSP') --'Need Lottable2'
   GOTO Fail
END

IF @cLottable03Required = '1' AND @cLottable03 = ''
BEGIN
   SET @nErrNo = 60335
   SET @cErrMsg = rdt.rdtgetmessage( 60335, @cLangCode, 'DSP') --'Need Lottable3'
   GOTO Fail
END

IF @cLottable04Required = '1' AND @dLottable04 IS NULL
BEGIN
   SET @nErrNo = 60336
   SET @cErrMsg = rdt.rdtgetmessage( 60336, @cLangCode, 'DSP') --'Need Lottable4'
   GOTO Fail
END


/*-------------------------------------------------------------------------------

                            StorerConfig Setup

-------------------------------------------------------------------------------*/
-- Added By Vicky
-- Storer config 'Allow_OverReceipt'
EXECUTE dbo.nspGetRight
   NULL, -- Facility
   @cStorerKey,
   @cSKU,
   'Allow_OverReceipt',
   @b_success             OUTPUT,
   @cAllow_OverReceipt    OUTPUT,
   @nErrNo                OUTPUT,
   @cErrMsg               OUTPUT
IF @b_success <> 1
BEGIN
   SET @nErrNo = 60301
   SET @cErrMsg = rdt.rdtgetmessage( 60301, @cLangCode, 'DSP') --'nspGetRight'
   GOTO Fail
END

-- Storer config 'ByPassTolerance'
EXECUTE dbo.nspGetRight
   NULL, -- Facility
   @cStorerKey,
   NULL,
   'ByPassTolerance',
   @b_success           OUTPUT,
   @cByPassTolerance    OUTPUT,
   @nErrNo              OUTPUT,
   @cErrMsg             OUTPUT
IF @b_success <> 1
BEGIN
   SET @nErrNo = 60302
   SET @cErrMsg = rdt.rdtgetmessage( 60302, @cLangCode, 'DSP') --'nspGetRight'
   GOTO Fail
END


/*-------------------------------------------------------------------------------

                            ReceiptDetail lookup logic

-------------------------------------------------------------------------------*/
/*
   Steps:
   0. Check over receive
   1. Find exact match line
      1.1 Receive up to QTYExpected
      1.2 If have bal, borrow from other line, receive it
   2. If have bal, find blank line
      2.1 Receive up to QTYExpected
      2.2 If have bal, borrow from other line, receive it
   3. If have bal, add line
      3.1 borrow from other line, receive it

   NOTES: Should receive ALL UCC first before loose QTY
*/
DECLARE @c1stExactMatch_ReceiptLineNumber NVARCHAR( 5)
DECLARE @c1stBlank_ReceiptLineNumber      NVARCHAR( 5)
DECLARE @cReceiptLineNumber               NVARCHAR( 5)
DECLARE @cNewReceiptLineNumber            NVARCHAR( 5) -- (ChewKP01)
DECLARE @nRowRef                          INT

DECLARE @nQTY_Bal            INT
DECLARE @nLineBal            INT
DECLARE @nQTYExpected        INT
DECLARE @nBeforeReceivedQTY  INT

DECLARE @nQTYExpected_Borrowed    INT
DECLARE @nQTYExpected_Total       INT
DECLARE @nBeforeReceivedQTY_Total INT

-- Added By Vicky
DECLARE @cReceiptLineNumber_Borrowed NVARCHAR( 5)
DECLARE @cExternReceiptKey           NVARCHAR( 100),--yeekung01  
        @cExternLineNo               NVARCHAR( 20),
        @cAltSku                     NVARCHAR( 20),
        @cVesselKey                  NVARCHAR( 18),
        @cVoyageKey                  NVARCHAR( 18),
        @cXdockKey                   NVARCHAR( 18),
        @cContainerKey               NVARCHAR( 18),
        @nUnitPrice                  FLOAT,
        @nExtendedPrice              FLOAT,
        @nFreeGoodQtyExpected        INT,
        @nFreeGoodQtyReceived        INT,
        @cExportStatus               NVARCHAR(  1),
        @cLoadKey                    NVARCHAR( 10),
        @cExternPoKey                NVARCHAR( 20),
        @cUserDefine01               NVARCHAR( 30),
        @cUserDefine02               NVARCHAR( 30),
        @cUserDefine03               NVARCHAR( 30),
        @cUserDefine04               NVARCHAR( 30),
        @cUserDefine05               NVARCHAR( 30),
        @dtUserDefine06              DATETIME,
        @dtUserDefine07              DATETIME,
        @cUserDefine08               NVARCHAR( 30),
        @cUserDefine09               NVARCHAR( 30),
        @cUserDefine10 NVARCHAR( 30),
        @cPoLineNo                   NVARCHAR(  5),
        @cOrgPOKey                   NVARCHAR( 10),
        @cChannel                    NVARCHAR( 20)

-- ReceiptDetail candidate
DECLARE @tRD TABLE
(
   RowRef                INT IDENTITY( 1, 1), 
   ReceiptLineNumber     NVARCHAR( 5),
   POLineNumber          NVARCHAR( 5),
   QTYExpected           INT,
   BeforeReceivedQTY     INT,
   ToLOC                 NVARCHAR( 10),
   ToID                  NVARCHAR( 18),
   Lottable01            NVARCHAR( 18),
   Lottable02            NVARCHAR( 18),
   Lottable03            NVARCHAR( 18),
   Lottable04            DATETIME,
--   Lottable05            DATETIME,
   FinalizeFlag          NVARCHAR( 1),
   Org_ReceiptLineNumber NVARCHAR( 5), -- Keeping original value, use in saving section
   Org_QTYExpected       INT,
   Org_BeforeReceivedQTY INT,
   -- Added By Vicky (Start)
   ReceiptLine_Borrowed  NVARCHAR( 5), -- Keep the linenumber of borrowed receiptline
   ExternReceiptKey      NVARCHAR( 100),--(yeekung01)  
   ExternLineNo          NVARCHAR( 20),
   AltSku                NVARCHAR( 20),
   VesselKey             NVARCHAR( 18),
   VoyageKey             NVARCHAR( 18),
   XdockKey              NVARCHAR( 18),
   ContainerKey          NVARCHAR( 18),
   UnitPrice             FLOAT,
   ExtendedPrice         FLOAT,
   FreeGoodQtyExpected   INT,
   FreeGoodQtyReceived   INT,
   ExportStatus          NVARCHAR(  1),
   LoadKey               NVARCHAR( 10),
   ExternPoKey           NVARCHAR( 20),
   UserDefine01          NVARCHAR( 30),
   UserDefine02          NVARCHAR( 30),
   UserDefine03          NVARCHAR( 30),
   UserDefine04          NVARCHAR( 30),
   UserDefine05          NVARCHAR( 30),
   UserDefine06          DATETIME,
   UserDefine07          DATETIME,
   UserDefine08          NVARCHAR( 30),
   UserDefine09          NVARCHAR( 30),
   UserDefine10          NVARCHAR( 30),
   POKey                 NVARCHAR( 10),
   UOM                   NVARCHAR( 10),
   EditDate              DATETIME, 
   Channel               NVARCHAR( 20),
   RowVer                VARBINARY( 8)
)

-- Final UCC
DECLARE @tUCC TABLE
(
   StorerKey         NVARCHAR( 20),
   UCCNo             NVARCHAR( 20),
   Status            NVARCHAR( 5),
   QTY               INT,
   LOC               NVARCHAR( 10),
   ID                NVARCHAR( 18),
   ReceiptKey        NVARCHAR( 10),
   ReceiptLineNumber NVARCHAR( 5),
   POKey             NVARCHAR( 10) -- (Vicky02)
)

-- Copy QTY to process
SET @nQTY_Bal = @nQTY

SET @cCustomSQL =
   ' SELECT ReceiptLineNumber, POLineNumber, QTYExpected, BeforeReceivedQTY,       ' +
   '    ToLOC, ToID, Lottable01, Lottable02, Lottable03, Lottable04, FinalizeFlag, ' +
   '    ReceiptLineNumber As Org_receiptLineNumber, QTYExpected, BeforeReceivedQTY, DuplicateFrom, ' + -- (ChewKP03) 
   '    ExternReceiptKey, ExternLineNo, AltSku, VesselKey,                         ' +
   '    VoyageKey, XdockKey, ContainerKey, UnitPrice, ExtendedPrice,               ' +
   '    FreeGoodQtyExpected, FreeGoodQtyReceived, ExportStatus, LoadKey,           ' +
   '    UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05,      ' +
   '    UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10,      ' +
   '    ExternPoKey, POKey, UOM , GETDATE(), Channel, RowVer                       ' +
   ' FROM dbo.ReceiptDetail (NOLOCK)                                               ' +
   ' WHERE ReceiptKey = @cReceiptKey ' +
   '    AND SKU = @cSKU ' 
   --   AND FinalizeFlag <> 'Y' -- We might need to borrow finalized ReceiptDetail line's QTYExpected

IF @nNOPOFlag <> 1 -- POKey <> NOPO
   SET @cCustomSQL = @cCustomSQL + ' AND POKey = @cPOKey '

IF @cReceiptDetailFilterSP <> ''
BEGIN
   IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cReceiptDetailFilterSP AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cReceiptDetailFilterSP) +
         '  @nMobile, @nFunc, @cLangCode, @cReceiptKey, @cPOKey, @cToLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @cUCC, @nQTY ' +
         ' ,@cCustomSQL OUTPUT ' +
         ' ,@nErrNo   OUTPUT  ' +
         ' ,@cErrMsg  OUTPUT  '
      SET @cSQLParam = +
         '  @nMobile     INT       ' +
         ' ,@nFunc       INT       ' +
         ' ,@cLangCode   NVARCHAR(  3) ' +
         ' ,@cReceiptKey NVARCHAR( 10) ' +
         ' ,@cPOKey      NVARCHAR( 10) ' +
         ' ,@cToLOC      NVARCHAR( 10) ' +
         ' ,@cToID       NVARCHAR( 18) ' +
         ' ,@cLottable01 NVARCHAR( 18) ' +
         ' ,@cLottable02 NVARCHAR( 18) ' +
         ' ,@cLottable03 NVARCHAR( 18) ' +
         ' ,@dLottable04 DATETIME      ' +
         ' ,@cSKU        NVARCHAR( 20) ' +
         ' ,@cUCC        NVARCHAR( 20) ' +
         ' ,@nQTY        INT           ' +
         ' ,@cCustomSQL  NVARCHAR( MAX) OUTPUT ' +
         ' ,@nErrNo      INT            OUTPUT ' +
         ' ,@cErrMsg     NVARCHAR( 20)  OUTPUT '
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
          @nMobile, @nFunc, @cLangCode, @cReceiptKey, @cPOKey, @cToLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @cUCC, @nQTY
         ,@cCustomSQL OUTPUT
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT
      IF @nErrNo <> 0
         GOTO Fail
   END
END

-- Default sorting
IF PATINDEX( '%ORDER BY%', @cCustomSQL) = 0
   SET @cCustomSQL = @cCustomSQL + ' ORDER BY ReceiptLineNumber'

SET @cSQLParam = 
   ' @cReceiptKey NVARCHAR(10), ' +  
   ' @cSKU        NVARCHAR(20), ' + 
   ' @cPOKey      NVARCHAR(10)  '
      
-- Get ReceiptDetail candidate
INSERT INTO @tRD (ReceiptLineNumber, POLineNumber, QTYExpected, BeforeReceivedQTY,
   ToLOC, ToID, Lottable01, Lottable02, Lottable03, Lottable04, FinalizeFlag,
   Org_ReceiptLineNumber, Org_QTYExpected, Org_BeforeReceivedQTY, ReceiptLine_Borrowed,
   ExternReceiptKey, ExternLineNo, AltSku, VesselKey,
   VoyageKey, XdockKey, ContainerKey, UnitPrice, ExtendedPrice,
   FreeGoodQtyExpected, FreeGoodQtyReceived, ExportStatus, LoadKey,
   UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05,
   UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10,
   ExternPoKey, POKey, UOM, EditDate, Channel, RowVer)
EXEC sp_ExecuteSQL @cCustomSQL, @cSQLParam,
   @cReceiptKey, 
   @cSKU, 
   @cPOKey

IF @@ERROR <> 0
BEGIN
   SET @nErrNo = 60338
   SET @cErrMsg = rdt.rdtgetmessage( 60338, @cLangCode, 'DSP') --'Get RDtl fail'
   GOTO Fail
END

-- Reset lottable if SkipLottable
IF @cSkipLottable01 = '1' UPDATE @tRD SET Lottable01 = ''
IF @cSkipLottable02 = '1' UPDATE @tRD SET Lottable02 = ''
IF @cSkipLottable03 = '1' UPDATE @tRD SET Lottable03 = ''
IF @cSkipLottable04 = '1' UPDATE @tRD SET Lottable04 = ''

-- Get total QTYExpected, BeforeReceivedQTY
SELECT
   @nQTYExpected_Total = IsNULL( SUM( QTYExpected), 0),
   @nBeforeReceivedQTY_Total = IsNULL( SUM( BeforeReceivedQTY), 0)
FROM @tRD


IF NOT EXISTS( SELECT 1 FROM @tRD)
BEGIN
  SELECT @cExternReceiptKey = ''
  SELECT @cOrgPOKey = ''
END
ELSE
BEGIN
  SELECT @cExternReceiptKey = IsNULL(MIN(ExternReceiptkey), ''),
         @cOrgPOKey = IsNULL(MIN(POKey), '')
  FROM @tRD
END

-- IF @cDocType = 'R' AND @cExternReceiptKey = '' AND @cOrgPOKey = ''
-- GOTO Steps

-- Not allow over receive, by DocType (follow Exceed way in ntrReceiptDetailUpdate)
IF @cAllow_OverReceipt IN ('0', '') OR                   -- Not allow for all doc type
   (@cAllow_OverReceipt = '2' AND @cDocType <> 'R') OR   -- Not allow, except return (means only return is allow)
   (@cAllow_OverReceipt = '3' AND @cDocType <> 'A') OR   -- Not allow, except normal (means only normal is allow)
   (@cAllow_OverReceipt = '4' AND @cDocType <> 'X')      -- Not allow, except xdock  (means only xdoc   is allow)
BEGIN
   -- Over received
   IF (@nQTY_Bal + @nBeforeReceivedQTY_Total) > @nQTYExpected_Total
   BEGIN
      SET @nErrNo = 60339
      SET @cErrMsg = rdt.rdtgetmessage( 60339, @cLangCode, 'DSP') --'Over Receive'
      GOTO Fail
   END
END
ELSE
BEGIN
   -- Check if bypass tolerance
   IF @cByPassTolerance <> '1'
   BEGIN
      -- If sku not in ASN and expected = 0 then skip check tolerance
      IF @nSKUNotInASN <> 1 AND @nQTYExpected_Total > 0  -- (james04)
      BEGIN
         -- Check if over tolerance %
         IF (@nQTY_Bal + @nBeforeReceivedQTY_Total) > (@nQTYExpected_Total * (1 + (@nTolerancePercentage * 0.01)))
         BEGIN
            SET @nErrNo = 60340
            SET @cErrMsg = rdt.rdtgetmessage( 60340, @cLangCode, 'DSP') --'OverTolerance%'
            GOTO Fail
         END
      END
   END
END

SET @cASNMatchByPOLineValue = rdt.RDTGetConfig( @nFunc, 'ASNMatchByPOLine', @cStorerKey) -- (ChewKP01)

-- Steps:

IF @cDebug = '1'
BEGIN
   SELECT  @nQTY_Bal 'STEP 1.1 @nQTY_Bal' ,@nQTY '@nQTY'
END

-- Steps
-- 1. Find exact match lines (could be more then 1 line)
--    1.1 Receive up to QTYExpected
SET @c1stExactMatch_ReceiptLineNumber = ''
SET @cReceiptLineNumber = ''
SET @nRowRef = 0
WHILE 1=1
BEGIN

   -- Get exact match line
   SELECT TOP 1
      @nRowRef = RowRef, 
      @cReceiptLineNumber = ReceiptLineNumber,
      @nLineBal = (QTYExpected - BeforeReceivedQTY),
      @cPOKey = POKey,
      @cExternLineNumber = ExternLineNo
   FROM @tRD
   WHERE FinalizeFlag <> 'Y'
      AND ToID = @cToID
      AND Lottable01 = @cLottable01
      AND Lottable02 = @cLottable02
      AND Lottable03 = @cLottable03
      AND IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0)
      AND @cToLOC = ToLOC
      AND (QTYExpected - BeforeReceivedQTY) > 0 -- (ChewKP01)
      -- AND ReceiptLineNumber > @cReceiptLineNumber
      AND RowRef > @nRowRef
   ORDER BY RowRef -- ReceiptLineNumber

   -- Exit loop
   IF @@ROWCOUNT = 0 BREAK

   -- Remember 1st exact match ReceiptLineNumber (for section 1.2)
   IF @c1stExactMatch_ReceiptLineNumber = ''
      SET @c1stExactMatch_ReceiptLineNumber = @cReceiptLineNumber

   IF @nLineBal < 1 CONTINUE

   -- Calc QTY to receive
   IF @nQTY_Bal >= @nLineBal
      SET @nQTY = @nLineBal
   ELSE
      SET @nQTY = @nQTY_Bal

   -- Update ReceiptDetail
--   IF @nLineBal >= @nUCCQTY -- UCC cannot receive into 2 ReceiptDetails
--   BEGIN
      -- Update ReceiptDetail
      UPDATE @tRD SET
         BeforeReceivedQTY = BeforeReceivedQTY + @nQTY
         -- Lottable05 = @dLottable05 -- Lottable05 is not match, but always overwrite
      WHERE ReceiptLineNumber = @cReceiptLineNumber

      -- Update UCC
      IF @cUCC <> ''
      BEGIN
         IF NOT EXISTS( SELECT 1 FROM @tUCC WHERE UCCNo = @cUCC)
         BEGIN
            INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber)
            VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @cReceiptLineNumber)
         END
      END

      -- Reduce balance
      SET @nQTY_Bal = @nQTY_Bal - @nQTY
--   END
   -- Exit loop
   IF @cDebug = '1'
   BEGIN
      SELECT  @nQTY_Bal 'STEP 1.1 @nQTY_Bal After' , @nQTY '@nQTY'
   END

   IF @nQTY_Bal = 0 BREAK
END

IF @cDebug = '1'
BEGIN
   SELECT  @nQTY_Bal 'STEP 1.2 @nQTY_Bal'
END

-- Step
-- 1.2 If have bal, borrow from other line
IF @nQTY_Bal > 0 AND @c1stExactMatch_ReceiptLineNumber <> ''
BEGIN
   -- Reduce balance after taking-in its own QTYExpected
   SET @nBeforeReceivedQTY = @nQTY_Bal
   SELECT @nQTY_Bal = @nQTY_Bal - (QTYExpected - BeforeReceivedQTY)
   FROM @tRD
   WHERE ReceiptLineNumber = @c1stExactMatch_ReceiptLineNumber
   AND (QTYExpected - BeforeReceivedQTY) > 0

   -- Loop other ReceiptDetail
   SET @cReceiptLineNumber = ''
   SET @nRowRef = 0
   WHILE 1=1
   BEGIN
      -- Get other line that has QTYExpected
      IF @cASNMatchByPOLineValue = '0' -- (ChewKP01)
      BEGIN
         SELECT TOP 1
               @nRowRef = RowRef, 
               @cReceiptLineNumber = ReceiptLineNumber,
               @nLineBal = (QTYExpected - BeforeReceivedQTY)
         FROM @tRD
         WHERE (QTYExpected - BeforeReceivedQTY) > 0
            AND ReceiptLineNumber <> @c1stExactMatch_ReceiptLineNumber
            -- AND ReceiptLineNumber > @cReceiptLineNumber
            AND RowRef > @nRowRef
         ORDER BY RowRef -- ReceiptLineNumber
      END
      ELSE
      BEGIN
         SELECT TOP 1
               @nRowRef = RowRef, 
                @cReceiptLineNumber = ReceiptLineNumber,
                @nLineBal = (QTYExpected - BeforeReceivedQTY)
         FROM @tRD
         WHERE (QTYExpected - BeforeReceivedQTY) > 0
            AND ReceiptLineNumber <> @c1stExactMatch_ReceiptLineNumber
            -- AND ReceiptLineNumber > @cReceiptLineNumber
            AND RowRef > @nRowRef
            AND POKey = @cPOKey -- (ChewKP01)
            AND ExternLineNo = @cExternLineNumber
         ORDER BY RowRef -- ReceiptLineNumber
      END

      -- Exit loop
      IF @@ROWCOUNT = 0 BREAK

      -- Calc QTY to receive
      IF @nQTY_Bal >= @nLineBal
         SET @nQTY = @nLineBal
      ELSE
         SET @nQTY = @nQTY_Bal

      -- Reduce borrowed ReceiptDetail QTYExpected
      UPDATE @tRD SET
            QTYExpected = QTYExpected - @nQTY
      WHERE ReceiptLineNumber = @cReceiptLineNumber

      -- Increase its own QTYExpected, and receive it
      UPDATE @tRD SET
            QTYExpected = QTYExpected + @nQTY
      WHERE ReceiptLineNumber = @c1stExactMatch_ReceiptLineNumber

      -- Reduce balance
      SET @nQTY_Bal = @nQTY_Bal - @nQTY

      -- Exit loop
      IF @nQTY_Bal = 0 BREAK
   END

   -- Update ReceiptDetail -- SOS#112522
   -- update qtyexpected same as beforereceiveqty
   IF (@cASNMatchByPOLineValue = '0') OR (@cASNMatchByPOLineValue = '1' AND @@ROWCOUNT <> 0 ) -- (ChewKP01)
   BEGIN
      IF @cDocType = 'R' AND @cExternReceiptKey = '' AND @cOrgPOKey = ''
      BEGIN
         UPDATE @tRD SET
               BeforeReceivedQTY = BeforeReceivedQTY + @nBeforeReceivedQTY,
               QtyExpected = QtyExpected + @nBeforeReceivedQTY,
               ToID = @cToID,
               ToLOC = @cToLOC,
               Lottable01 = @cLottable01,
               Lottable02 = @cLottable02,
               Lottable03 = @cLottable03,
               Lottable04 = @dLottable04
               --Lottable05 = @dLottable05
         WHERE ReceiptLineNumber = @c1stExactMatch_ReceiptLineNumber
      END
      ELSE
      BEGIN
      UPDATE @tRD SET
            BeforeReceivedQTY = BeforeReceivedQTY + @nBeforeReceivedQTY,
            ToID = @cToID,
            ToLOC = @cToLOC,
            Lottable01 = @cLottable01,
            Lottable02 = @cLottable02,
            Lottable03 = @cLottable03,
            Lottable04 = @dLottable04
            -- Lottable05 = @dLottable05
      WHERE ReceiptLineNumber = @c1stExactMatch_ReceiptLineNumber
   END
   
      -- Update UCC
      IF @cUCC <> ''
      BEGIN
         IF NOT EXISTS( SELECT 1 FROM @tUCC WHERE UCCNo = @cUCC)
         BEGIN
            INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber)
            VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @c1stExactMatch_ReceiptLineNumber)
         END
      END
   
      -- Reduce balance
      SET @nQTY_Bal = 0
   END -- @cASNMatchByPOLineValue = 0
END

IF @cDebug = '1'
BEGIN
   SELECT  @nQTY_Bal 'STEP 2.1 @nQTY_Bal'
END

-- Step
-- 2. If have bal, find blank line
--    2.1 Receive up to QTYExpected
SET @c1stBlank_ReceiptLineNumber = ''
SET @cReceiptLineNumber = ''
SET @nRowRef = 0
WHILE @nQTY_Bal > 0
BEGIN
   -- Get blank line
   SELECT TOP 1
      @nRowRef = RowRef, 
      @cReceiptLineNumber = ReceiptLineNumber,
      @nLineBal = (QTYExpected - BeforeReceivedQTY),
      @cPOKey = POKey
   FROM @tRD
   WHERE FinalizeFlag <> 'Y'
      AND BeforeReceivedQTY = 0
      AND (ToID = '' OR ToID = @cToID)
      AND
      (  -- Blank lottable
         (Lottable01 = '' AND
          Lottable02 = '' AND
          Lottable03 = '' AND
          Lottable04 IS NULL)
         OR
         -- Exact match lottables
         (Lottable01 = @cLottable01 AND
          Lottable02 = @cLottable02 AND
          Lottable03 = @cLottable03 AND
          IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0))
      )
      AND QtyExpected > @nQTY_Bal -- (ChewKP01)
      -- AND ReceiptLineNumber > @cReceiptLineNumber
      AND RowRef = @nRowRef
   ORDER BY RowRef -- ReceiptLineNumber

   -- Exit loop
   IF @@ROWCOUNT = 0 BREAK

   -- Remember 1st blank ReceiptLineNumber (for section 1.2)
   IF @c1stBlank_ReceiptLineNumber = ''
      SET @c1stBlank_ReceiptLineNumber = @cReceiptLineNumber

   IF @nLineBal < 1 CONTINUE

   -- Calc QTY to receive
   IF @nQTY_Bal >= @nLineBal
      SET @nQTY = @nLineBal
   ELSE
      SET @nQTY = @nQTY_Bal

   -- Update ReceiptDetail
--   IF @nLineBal >= @nUCCQTY -- UCC cannot receive into 2 ReceiptDetails
--   BEGIN
      -- Update ReceiptDetail
      UPDATE @tRD SET
            BeforeReceivedQTY = BeforeReceivedQTY + @nQTY,
            ToID = @cToID,
            ToLOC = @cToLOC,
            Lottable01 = @cLottable01,
            Lottable02 = @cLottable02,
            Lottable03 = @cLottable03,
            Lottable04 = @dLottable04
            --Lottable05 = @dLottable05
      WHERE ReceiptLineNumber = @cReceiptLineNumber

      -- Update UCC
      IF @cUCC <> ''
      BEGIN
         IF NOT EXISTS( SELECT 1 FROM @tUCC WHERE UCCNo = @cUCC)
         BEGIN
            INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber)
            VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @cReceiptLineNumber)
         END
      END

      -- Reduce balance
      SET @nQTY_Bal = @nQTY_Bal - @nQTY
--   END
   -- Exit loop
   IF @nQTY_Bal = 0 BREAK
END

IF @cDebug = '1'
BEGIN
   SELECT  @nQTY_Bal 'STEP 2.2 @nQTY_Bal'
END

-- Step
-- 2.2 If have bal, borrow from other line
IF @nQTY_Bal > 0 AND @c1stBlank_ReceiptLineNumber <> ''
BEGIN
   -- Reduce balance after taking-in its own QTYExpected
   SET @nBeforeReceivedQTY = @nQTY_Bal
   SELECT @nQTY_Bal = @nQTY_Bal - (QTYExpected - BeforeReceivedQTY)
   FROM @tRD
   WHERE ReceiptLineNumber = @c1stBlank_ReceiptLineNumber
   AND (QTYExpected - BeforeReceivedQTY) > 0

   -- Loop other ReceiptDetail
   SET @cReceiptLineNumber = ''
   SET @nRowRef = 0
   WHILE 1=1
   BEGIN
      -- Get other line that has QTYExpected
      IF @cASNMatchByPOLineValue = '0' -- (ChewKP01)
      BEGIN
         SELECT TOP 1
            @nRowRef = RowRef, 
            @cReceiptLineNumber = ReceiptLineNumber,
            @nLineBal = (QTYExpected - BeforeReceivedQTY)
         FROM @tRD
         WHERE (QTYExpected - BeforeReceivedQTY) > 0
            AND ReceiptLineNumber <> @c1stBlank_ReceiptLineNumber
            -- AND ReceiptLineNumber > @cReceiptLineNumber
            AND RowRef > @nRowRef
         ORDER BY RowRef -- ReceiptLineNumber
      END
      ELSE
      BEGIN
         SELECT TOP 1
            @nRowRef = RowRef, 
            @cReceiptLineNumber = ReceiptLineNumber,
            @nLineBal = (QTYExpected - BeforeReceivedQTY)
         FROM @tRD
         WHERE (QTYExpected - BeforeReceivedQTY) > 0
            AND ReceiptLineNumber <> @c1stBlank_ReceiptLineNumber
            -- AND ReceiptLineNumber > @cReceiptLineNumber
            AND RowRef > @nRowRef
            AND POKey = @cPOKey -- (ChewKP01)
            AND ExternLineNo = @cExternLineNumber
         ORDER BY RowRef -- ReceiptLineNumber
      END

      -- Exit loop
      IF @@ROWCOUNT = 0 BREAK

      -- Calc QTY to receive
      IF @nQTY_Bal >= @nLineBal
         SET @nQTY = @nLineBal
      ELSE
         SET @nQTY = @nQTY_Bal

      -- Reduce borrowed ReceiptDetail QTYExpected
      UPDATE @tRD SET
         QTYExpected = QTYExpected - @nQTY
      WHERE ReceiptLineNumber = @cReceiptLineNumber

      -- Increase its own QTYExpected, and receive it
      UPDATE @tRD SET
         QTYExpected = QTYExpected + @nQTY
      WHERE ReceiptLineNumber = @c1stBlank_ReceiptLineNumber

      -- Reduce balance
      SET @nQTY_Bal = @nQTY_Bal - @nQTY

      -- Exit loop
      IF @nQTY_Bal = 0 BREAK
   END

   IF (@cASNMatchByPOLineValue = '0') OR (@cASNMatchByPOLineValue = '1' AND @@ROWCOUNT <> 0 ) -- (ChewKP01)
   BEGIN
      -- Update ReceiptDetail -- SOS#112522
      IF @cDocType = 'R' AND @cExternReceiptKey = '' AND @cOrgPOKey = '' -- update qtyexpected same as beforereceiveqty
      BEGIN
         UPDATE @tRD SET
               BeforeReceivedQTY = BeforeReceivedQTY + @nBeforeReceivedQTY,
               QtyExpected =  QtyExpected + @nBeforeReceivedQTY,
               ToID = @cToID,
               ToLOC = @cToLOC,
               Lottable01 = @cLottable01,
               Lottable02 = @cLottable02,
               Lottable03 = @cLottable03,
               Lottable04 = @dLottable04
               --Lottable05 = @dLottable05
         WHERE ReceiptLineNumber = @c1stBlank_ReceiptLineNumber
      END
      ELSE
      BEGIN
         UPDATE @tRD SET
               BeforeReceivedQTY = BeforeReceivedQTY + @nBeforeReceivedQTY,
               ToID = @cToID,
               ToLOC = @cToLOC,
               Lottable01 = @cLottable01,
               Lottable02 = @cLottable02,
               Lottable03 = @cLottable03,
               Lottable04 = @dLottable04
               --Lottable05 = @dLottable05
         WHERE ReceiptLineNumber = @c1stBlank_ReceiptLineNumber
      END

      -- Update UCC
      IF @cUCC <> ''
      BEGIN
         IF NOT EXISTS( SELECT 1 FROM @tUCC WHERE UCCNo = @cUCC)
         BEGIN
            INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber)
            VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @c1stBlank_ReceiptLineNumber)
         END
      END
   
      -- Reduce balance
      SET @nQTY_Bal = 0
   END -- IF (@cASNMatchByPOLineValue = '0') OR (@cASNMatchByPOLineValue = '1' AND @@ROWCOUNT <> 0 ) -- (ChewKP01)
END

IF @cDebug = '1'
BEGIN
   SELECT  @nQTY_Bal 'STEP 2.3 @nQTY_Bal'
END

-- Step -- Start (ChewKP01)
-- 2.3 Check if there is other line with  BeforeReceivedQTY = 0
SET @c1stBlank_ReceiptLineNumber = ''
SET @cReceiptLineNumber = ''
SET @nRowRef = 0
WHILE @nQTY_Bal > 0
BEGIN
   -- Get blank line
   SELECT TOP 1
      @nRowRef = RowRef, 
      @cReceiptLineNumber = ReceiptLineNumber,
      @nLineBal = (QTYExpected - BeforeReceivedQTY),
      @cPOKey = POKey
   FROM @tRD
   WHERE FinalizeFlag <> 'Y'
      AND BeforeReceivedQTY = 0
      AND (ToID = '' OR ToID = @cToID)
      AND
      (  -- Blank lottable
         (Lottable01 = '' AND
          Lottable02 = '' AND
          Lottable03 = '' AND
          Lottable04 IS NULL)
         OR
         -- Exact match lottables
         (Lottable01 = @cLottable01 AND
          Lottable02 = @cLottable02 AND
          Lottable03 = @cLottable03 AND
          IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0))
      )
      -- AND ReceiptLineNumber > @cReceiptLineNumber
      AND RowRef > @nRowRef
   ORDER BY RowRef -- ReceiptLineNumber

   -- Exit loop
   IF @@ROWCOUNT = 0 BREAK

   -- Remember 1st blank ReceiptLineNumber (for section 1.2)
   IF @c1stBlank_ReceiptLineNumber = ''
      SET @c1stBlank_ReceiptLineNumber = @cReceiptLineNumber

  IF @nLineBal < 1 CONTINUE

   -- Calc QTY to receive
   IF @nQTY_Bal >= @nLineBal
      SET @nQTY = @nLineBal
   ELSE
      SET @nQTY = @nQTY_Bal

   -- Update ReceiptDetail
--   IF @nLineBal >= @nUCCQTY -- UCC cannot receive into 2 ReceiptDetails
--   BEGIN
      -- Update ReceiptDetail
      UPDATE @tRD SET
            BeforeReceivedQTY = BeforeReceivedQTY + @nQTY,
            ToID = @cToID,
            ToLOC = @cToLOC,
            Lottable01 = @cLottable01,
            Lottable02 = @cLottable02,
            Lottable03 = @cLottable03,
            Lottable04 = @dLottable04
            --Lottable05 = @dLottable05
      WHERE ReceiptLineNumber = @cReceiptLineNumber

      -- Update UCC
      IF @cUCC <> ''
      BEGIN
         IF NOT EXISTS( SELECT 1 FROM @tUCC WHERE UCCNo = @cUCC)
         BEGIN
            INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber)
            VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @cReceiptLineNumber)
         END
      END

      -- Reduce balance
      SET @nQTY_Bal = @nQTY_Bal - @nQTY
--   END
   -- Exit loop
   IF @nQTY_Bal = 0 BREAK
END
-- Step -- End (ChewKP01)

IF @cDebug = '1'
BEGIN
   SELECT  @nQTY_Bal 'STEP 3.1 @nQTY_Bal'
END

-- Step 3.1 If there is overreceived , receive the qty to the over received line.
SET @cReceiptLineNumber = ''
IF @nQty_Bal > 0
BEGIN
   IF @cPOKey = '' -- (ChewKP01)
   BEGIN
      SELECT TOP 1
         @cReceiptLineNumber = ReceiptLineNumber,
         @cExternLineNumber = ExternLineNo
      FROM @tRD
      WHERE FinalizeFlag <> 'Y'
         AND QtyExpected = 0
         AND ToID = @cToID
         AND Lottable01 = @cLottable01
         AND Lottable02 = @cLottable02
         AND Lottable03 = @cLottable03
         AND IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0)
         AND @cToLOC = ToLOC
      ORDER BY RowRef -- ReceiptLineNumber
   END
   ELSE
   BEGIN
      SELECT TOP 1
         @cReceiptLineNumber = ReceiptLineNumber,
         @cExternLineNumber = ExternLineNo
      FROM @tRD
      WHERE FinalizeFlag <> 'Y'
         AND QtyExpected = 0
         AND ToID = @cToID
         AND Lottable01 = @cLottable01
         AND Lottable02 = @cLottable02
         AND Lottable03 = @cLottable03
         AND IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0)
         AND @cToLOC = ToLOC
         AND POKey = @cPokey
      ORDER BY RowRef -- ReceiptLineNumber
   END

   IF @@RowCount <> 0
   BEGIN
      UPDATE @tRD SET
         BeforeReceivedQTY = BeforeReceivedQTY + @nQty_Bal
      WHERE ReceiptLineNumber = @cReceiptLineNumber

      -- Update UCC
      IF @cUCC <> ''
      BEGIN
         IF NOT EXISTS( SELECT 1 FROM @tUCC WHERE UCCNo = @cUCC)
         BEGIN
            INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber)
            VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @cReceiptLineNumber)
         END
      END

      SET @nQty_Bal = 0
   END
END

IF @cDebug = '1'
BEGIN
   SELECT  @nQTY_Bal 'STEP 3.1.1 @nQTY_Bal'
END

-- (ChewKP02)
-- Step 3.1.1 Over receive to matching line without adding a new ReceiptDetail line
IF rdt.RDTGetConfig( @nFunc, 'OverReceiptToMatchLine', @cStorerKey) = '1'
BEGIN
   SET @cReceiptLineNumber = ''
   SET @nRowRef = 0
   IF @nQty_Bal > 0
   BEGIN
      SELECT TOP 1
         @nRowRef = RowRef, 
         @cReceiptLineNumber = ReceiptLineNumber,
         @cPOKey = POKey,
         @cExternLineNumber = ExternLineNo
      FROM @tRD
      WHERE FinalizeFlag <> 'Y'
         AND (ToID = '' OR ToID = @cToID)
         AND
         (  -- Blank lottable
            (Lottable01 = '' AND
             Lottable02 = '' AND
             Lottable03 = '' AND
             Lottable04 IS NULL)
            OR
            -- Exact match lottables
            (Lottable01 = @cLottable01 AND
             Lottable02 = @cLottable02 AND
             Lottable03 = @cLottable03 AND
             IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0))
         )
         -- AND ReceiptLineNumber > @cReceiptLineNumber
         AND RowRef > @nRowRef
      ORDER BY RowRef -- ReceiptLineNumber

      IF @@ROWCOUNT <> 0
      BEGIN
         UPDATE @tRD SET
            BeforeReceivedQTY = BeforeReceivedQTY + @nQty_Bal
         WHERE ReceiptLineNumber = @cReceiptLineNumber

         -- Update UCC
         IF @cUCC <> ''
         BEGIN
            IF NOT EXISTS( SELECT 1 FROM @tUCC WHERE UCCNo = @cUCC)
            BEGIN
               INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber)
               VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @cReceiptLineNumber)
            END
         END

         -- Reduce balance
         SET @nQTY_Bal = 0
      END
   END
END

IF @cDebug = '1'
BEGIN
   SELECT  @nQTY_Bal 'STEP 3.2 @nQTY_Bal'
END

-- Step 3.2 Over receive it (by adding new ReceiptDetail line)
SET @nBeforeReceivedQTY = @nQTY_Bal
SET @cNewReceiptLineNumber = '' -- (ChewKP01)
IF @nQTY_Bal > 0
BEGIN
   -- Loop all ReceiptDetail to borrow QTYExpected
   SET @cReceiptLineNumber = ''
   SET @nRowRef = 0
   SET @nQTYExpected_Borrowed = 0
   WHILE 1=1
   BEGIN
      -- Get lines that has balance
      SELECT TOP 1
            @nRowRef = RowRef, 
            @cReceiptLineNumber = ReceiptLineNumber,
            @nLineBal = (QTYExpected - BeforeReceivedQTY)
      FROM @tRD
      WHERE (QTYExpected - BeforeReceivedQTY) > 0
      --AND (QTYExpected - BeforeReceivedQTY) >= @nUCCQTY
      --AND ReceiptLineNumber > @cReceiptLineNumber
      AND RowRef > @nRowRef
      ORDER BY RowRef -- ReceiptLineNumber

      -- Exit loop
      IF @@ROWCOUNT = 0 BREAK

      -- Added By Vicky
      SET @cReceiptLineNumber_Borrowed = @cReceiptLineNumber

      -- Calc QTY to receive
      IF @nQTY_Bal >= @nLineBal
         SET @nQTY = @nLineBal
      ELSE
         SET @nQTY = @nQTY_Bal

      IF @cDebug = '1'
      BEGIN
         SELECT @cReceiptLineNumber '@cReceiptLineNumber' , @nLineBal '@nLineBal' , @nQTY '@nQTY' , @nQTY_Bal '@nQTY_Bal'
      END

      -- Reduce borrowed ReceiptDetail QTYExpected
      UPDATE @tRD SET
         QTYExpected = QTYExpected - @nQTY
      WHERE ReceiptLineNumber = @cReceiptLineNumber

      -- Reduce balance
      SET @nQTY_Bal = @nQTY_Bal - @nQTY

      -- Remember borrowed QTYExpected
      SET @nQTYExpected_Borrowed = 0 -- (ChewKP01)
      SET @nQTYExpected_Borrowed = @nQTYExpected_Borrowed + @nQTY

      -- (ChewKP01) -- Revised Logic Start --
      -- Get Temp next ReceiptLineNumber
      SELECT @cNewReceiptLineNumber =
         RIGHT( '00000' + CAST( CAST( IsNULL( MAX( ReceiptLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
      --FROM dbo.ReceiptDetail (NOLOCK)
      FROM @tRD --WITH (NOLOCK) -- (ChewKP01)
      --WHERE ReceiptKey = @cReceiptKey

      -- Balance insert as new ReceiptDetail line
      -- Added By Vicky - To Cater Return without Receiptlines
      IF @cDocType = 'R' AND @cExternReceiptKey = '' AND @cOrgPOKey = ''
      BEGIN
         INSERT INTO @tRD
            (ReceiptLineNumber, POLineNumber, QTYExpected, BeforeReceivedQTY, ToID, ToLOC,
            Lottable01, Lottable02, Lottable03, Lottable04, --Lottable05,
            FinalizeFlag, ExternReceiptkey, Org_ReceiptLineNumber, Org_QTYExpected,
            Org_BeforeReceivedQTY, ReceiptLine_Borrowed, EditDate ) -- (ChewKP01)
         VALUES
         (  @cNewReceiptLineNumber, '', @nQTY, @nQTY, @cToID, @cToLOC,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, --@dLottable05,
            'N', '', '', 0, 0, @cReceiptLineNumber_Borrowed, GetDate()  ) -- Added By Vicky -- (ChewKP01)
      END
      ELSE
      BEGIN
         IF @cDebug = '1'
         BEGIN
            SELECT @nQTY_Bal '@nQTY_Bal', @nQTY '@nQTY', @nQTYExpected_Borrowed '@nQTYExpected_Borrowed', @nBeforeReceivedQTY '@nBeforeReceivedQTY' , @cReceiptLineNumber_Borrowed '@cReceiptLineNumber_Borrowed'
         END

         -- Only create new line when Inserted record not from @cReceiptLineNumber_Borrowed
         SET @cBorrowed_OriginalReceiptLineNumber = ''

         SELECT @cBorrowed_OriginalReceiptLineNumber = ReceiptLineNumber
         FROM @tRD
         WHERE ReceiptLine_Borrowed = @cReceiptLineNumber_Borrowed
         AND FinalizeFlag <> 'Y'
         AND ToID = @cToID
         AND Lottable01 = @cLottable01
         AND Lottable02 = @cLottable02
         AND Lottable03 = @cLottable03
         AND IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0)
         AND @cToLOC = ToLOC

         IF @cBorrowed_OriginalReceiptLineNumber = ''
         BEGIN
            INSERT INTO @tRD
               (ReceiptLineNumber, POLineNumber, QTYExpected, BeforeReceivedQTY, ToID, ToLOC,
               Lottable01, Lottable02, Lottable03, Lottable04, --Lottable05,
               FinalizeFlag, Org_ReceiptLineNumber, Org_QTYExpected, Org_BeforeReceivedQTY, ReceiptLine_Borrowed, EditDate) -- Added By Vicky -- (ChewKP01)
            VALUES
               --(@cReceiptLineNumber, '', @nQTYExpected_Borrowed, @nBeforeReceivedQTY, @cToID, @cToLOC,
               (@cNewReceiptLineNumber, '', @nQTYExpected_Borrowed, @nQTY, @cToID, @cToLOC,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, --@dLottable05,
               'N', '', 0, 0, @cReceiptLineNumber_Borrowed, GetDate() ) -- Added By Vicky -- (ChewKP01)
         END
         ELSE
         BEGIN
            UPDATE @tRD SET
                BeforeReceivedQTY = BeforeReceivedQTY + @nQTY
               ,QtyExpected = QtyExpected + @nQTY
            WHERE ReceiptLineNumber = @cBorrowed_OriginalReceiptLineNumber
            AND ToID = @cToID
            AND Lottable01 = @cLottable01
            AND Lottable02 = @cLottable02
            AND Lottable03 = @cLottable03
            AND IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0)
            AND @cToLOC = ToLOC
         END
      END

      -- Update UCC
      IF @cUCC <> ''
      BEGIN
         IF NOT EXISTS( SELECT 1 FROM @tUCC WHERE UCCNo = @cUCC)
         BEGIN
            INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, POKey) -- (Vicky04)
            VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @cNewReceiptLineNumber, '') -- (Vicky04)
         END
      END

      -- Reduce balance to zero (for calculation error checking below)
      --SET @nQTY_Bal = @nBeforeReceivedQTY - @nQTYExpected_Borrowed -- @nQTY_Bal
      -- (ChewKP01) -- Revised Logic End --

      -- Exit loop
      IF @nQTY_Bal = 0 BREAK
   END -- End While

   IF @nQTY_Bal > 0  -- If There is no Match line from ReceiptDetail , Add a new Record -- (ChewKP01)
   BEGIN
      -- Get Temp next ReceiptLineNumber
      SELECT @cNewReceiptLineNumber =
      RIGHT( '00000' + CAST( CAST( IsNULL( MAX( ReceiptLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
      --FROM dbo.ReceiptDetail (NOLOCK)
      FROM @tRD --WITH (NOLOCK)
      --WHERE ReceiptKey = @cReceiptKey

      -- Balance insert as new ReceiptDetail line
      -- Added By Vicky - To Cater Return without Receiptlines
      IF @cDocType = 'R' AND @cExternReceiptKey = '' AND @cOrgPOKey = ''
      BEGIN
         INSERT INTO @tRD
            (ReceiptLineNumber, POLineNumber, QTYExpected, BeforeReceivedQTY, ToID, ToLOC,
            Lottable01, Lottable02, Lottable03, Lottable04, --Lottable05,
            FinalizeFlag, ExternReceiptkey, Org_ReceiptLineNumber, Org_QTYExpected,
            Org_BeforeReceivedQTY, ReceiptLine_Borrowed, EditDate ) -- (ChewKP01)
         VALUES
            (@cNewReceiptLineNumber, '', 0, @nQTY_Bal, @cToID, @cToLOC,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, --@dLottable05,
            'N', '', '', 0, 0, @cReceiptLineNumber_Borrowed, GetDate()) -- Added By Vicky -- (ChewKP01)
      END
      ELSE
      BEGIN
         IF @cDebug = '1'
         BEGIN
            SELECT @nQTY_Bal '@nQTY_Bal', @nQTY '@nQTY', @nQTYExpected_Borrowed '@nQTYExpected_Borrowed', @nBeforeReceivedQTY '@nBeforeReceivedQTY'
         END

         INSERT INTO @tRD
            (ReceiptLineNumber, POLineNumber, QTYExpected, BeforeReceivedQTY, ToID, ToLOC,
            Lottable01, Lottable02, Lottable03, Lottable04, --Lottable05,
            FinalizeFlag, Org_ReceiptLineNumber, Org_QTYExpected, Org_BeforeReceivedQTY, ReceiptLine_Borrowed, EditDate) -- Added By Vicky -- (ChewKP01)
         VALUES
            --(@cReceiptLineNumber, '', @nQTYExpected_Borrowed, @nBeforeReceivedQTY, @cToID, @cToLOC,
            (@cNewReceiptLineNumber, '', 0, @nQTY_Bal, @cToID, @cToLOC,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, --@dLottable05,
            'N', '', 0, 0, @cReceiptLineNumber_Borrowed, GetDate() ) -- Added By Vicky -- (ChewKP01)
      END

      -- Update UCC
      IF @cUCC <> ''
      BEGIN
         IF NOT EXISTS( SELECT 1 FROM @tUCC WHERE UCCNo = @cUCC)
         BEGIN
            INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, POKey) -- (Vicky04)
            VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @cNewReceiptLineNumber, '') -- (Vicky04)
         END
      END
      
      -- Reduce balance to zero (for calculation error checking below)
      SET @nQTY_Bal = @nBeforeReceivedQTY - @nQTYExpected_Borrowed - @nQTY_Bal
   END
END

-- If still have balance, means offset has error
IF @nQTY_Bal <> 0
BEGIN
   SET @nErrNo = 60341
   SET @cErrMsg = rdt.rdtgetmessage( 60341, @cLangCode, 'DSP') --'Offset error'
   GOTO Fail
END

/*-------------------------------------------------------------------------------

                              Write to ReceiptDetail

-------------------------------------------------------------------------------*/
Saving:

-- Handling transaction
SET @nTranCount = @@TRANCOUNT
BEGIN TRAN  -- Begin our own transaction
SAVE TRAN rdt_898RcvCfm12 -- For rollback or commit only our own transaction

DECLARE @cOrg_ReceiptLineNumber NVARCHAR( 5)
DECLARE @nOrg_QTYExpected       INT
DECLARE @nOrg_BeforeReceivedQTY INT
DECLARE @cReceiptLineNo_Borrowed NVARCHAR( 5) -- Added By Vicky
DECLARE @cDuplicateFromLineNo    NVARCHAR( 5)
DECLARE @bRowVer                 VARBINARY( 8)

-- Loop changed ReceiptDetail
DECLARE @curRD CURSOR
SET @curRD = CURSOR FOR
   SELECT RowRef, 
      Org_ReceiptLineNumber, ReceiptLineNumber,
      Org_QTYExpected, QTYExpected,
      Org_BeforeReceivedQTY, BeforeReceivedQTY,
      ToID, ToLOC, Lottable01, Lottable02, Lottable03, Lottable04, --Lottable05,
      ReceiptLine_Borrowed, RowVer
   FROM @tRD
   WHERE QTYExpected <> Org_QTYExpected
      OR BeforeReceivedQTY <> Org_BeforeReceivedQTY
   ORDER BY RowRef      -- ZG01      
OPEN @curRD
FETCH NEXT FROM @curRD INTO @nRowRef, 
      @cOrg_ReceiptLineNumber, @cReceiptLineNumber,
      @nOrg_QTYExpected, @nQTYExpected,
      @nOrg_BeforeReceivedQTY, @nBeforeReceivedQTY,
      @cToID, @cToLOC, @cLottable01, @cLottable02, @cLottable03, @dLottable04, --@dLottable05,
      @cReceiptLineNo_Borrowed, @bRowVer

WHILE @@FETCH_STATUS = 0
BEGIN
   IF @cOrg_ReceiptLineNumber = ''
   BEGIN
      IF @cDuplicateFromMatchValue = '1' -- (ChewKP01)
      BEGIN
         SELECT TOP 1
                  @cExternReceiptKey    = ExternReceiptKey   ,
                  @cExternLineNo        = ExternLineNo       ,
                  @cAltSku              = AltSku             ,
                  @cVesselKey           = VesselKey          ,
                  @cVoyageKey           = VoyageKey          ,
                  @cXdockKey            = XdockKey           ,
                  @cContainerKey        = ContainerKey       ,
                  @nUnitPrice           = UnitPrice          ,
                  @nExtendedPrice       = ExtendedPrice      ,
                  @nFreeGoodQtyExpected = FreeGoodQtyExpected,
                  @nFreeGoodQtyReceived = FreeGoodQtyReceived,
                  @cExportStatus        = ExportStatus       ,
                  @cLoadKey             = LoadKey            ,
                  @cExternPoKey         = ExternPoKey        ,
                  @cPOKey               = POKey              ,
                  @cUserDefine01        = UserDefine01       ,
                  @cUserDefine02        = UserDefine02       ,
                  @cUserDefine03        = UserDefine03       ,
                  @cUserDefine04        = UserDefine04       ,
                  @cUserDefine05        = UserDefine05       ,
                  @dtUserDefine06       = UserDefine06       ,
                  @dtUserDefine07       = UserDefine07       ,
                  @cUserDefine08        = UserDefine08       ,
                  @cUserDefine09        = UserDefine09       ,
                  @cUserDefine10        = UserDefine10       ,
                  @cPoLineNo            = POLineNumber       ,
                  @cUOM                 = UOM                ,
                  @cChannel             = Channel
         FROM dbo.ReceiptDetail (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND SKU = @cSKU
         ORDER By EditDate DESC
      END
      ELSE
      BEGIN
         SET @cExternLineNo = ''
         SET @cAltSku = ''
         SET @cVesselKey = ''
         SET @cVoyageKey = ''
         SET @cXdockKey = ''
         SET @cContainerKey = ''
         SET @nUnitPrice = 0
         SET @nExtendedPrice = 0
         SET @nFreeGoodQtyExpected = 0
         SET @nFreeGoodQtyReceived = 0
         SET @cExportStatus = '0'
         SET @cLoadKey = ''
         SET @cExternPoKey = ''
         SET @cUserDefine01 = ''
         SET @cUserDefine02 = ''
         SET @cUserDefine03 = ''
         SET @cUserDefine04 = ''
         SET @cUserDefine05 = ''
         SET @dtUserDefine06 = NULL
         SET @dtUserDefine07 = NULL
         SET @cUserDefine08 = ''
         SET @cUserDefine09 = ''
         SET @cUserDefine10 = ''
         SET @cPoLineNo = ''
         SET @cChannel  = ''
      END

      IF ISNULL(@cReceiptLineNumber_Borrowed,'') <> ''
      BEGIN
         SELECT   @cExternReceiptKey    = ExternReceiptKey   ,
                  @cExternLineNo        = ExternLineNo       ,
                  @cAltSku              = AltSku             ,
                  @cVesselKey           = VesselKey          ,
                  @cVoyageKey           = VoyageKey          ,
                  @cXdockKey            = XdockKey           ,
                  @cContainerKey        = ContainerKey       ,
                  @nUnitPrice           = UnitPrice          ,
                  @nExtendedPrice       = ExtendedPrice      ,
                  @nFreeGoodQtyExpected = FreeGoodQtyExpected,
                  @nFreeGoodQtyReceived = FreeGoodQtyReceived,
                  @cExportStatus        = ExportStatus       ,
                  @cLoadKey             = LoadKey            ,
                  @cExternPoKey         = ExternPoKey        ,
                  @cPOKey               = POKey              , -- SOS#129347
                  @cUserDefine01        = UserDefine01       ,
                  @cUserDefine02        = UserDefine02       ,
                  @cUserDefine03        = UserDefine03       ,
                  @cUserDefine04        = UserDefine04       ,
                  @cUserDefine05        = UserDefine05       ,
                  @dtUserDefine06       = UserDefine06       ,
                  @dtUserDefine07       = UserDefine07       ,
                  @cUserDefine08        = UserDefine08       ,
                  @cUserDefine09        = UserDefine09       ,
                  @cUserDefine10        = UserDefine10       ,
                  @cPoLineNo            = POLineNumber       ,
                  @cUOM                 = UOM                ,
                  @cChannel             = Channel
         FROM @tRD
         WHERE ReceiptLineNumber = @cReceiptLineNo_Borrowed
      END

      IF @cDuplicateFromMatchValue NOT IN ('', '1')
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDuplicateFromMatchValue AND type = 'P')
         BEGIN
            SET @cDuplicateFromLineNo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDuplicateFromMatchValue) +
               '  @nMobile, @nFunc, @cLangCode, @cReceiptKey, @cPOKey, @cToLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @cUCC, @nQTY ' +
               ' ,@cOrg_ReceiptLineNumber ' +
               ' ,@nOrg_QTYExpected       ' +
               ' ,@nOrg_BeforeReceivedQTY ' + 
               ' ,@cReceiptLineNumber     ' + 
               ' ,@nQTYExpected           ' + 
               ' ,@nBeforeReceivedQTY     ' + 
               ' ,@cReceiptLineNumber_Borrowed ' +
               ' ,@cDuplicateFromLineNo OUTPUT ' +
               ' ,@nErrNo   OUTPUT  ' +
               ' ,@cErrMsg  OUTPUT  '
            SET @cSQLParam = +
               '  @nMobile     INT       ' +
               ' ,@nFunc       INT       ' +
               ' ,@cLangCode   NVARCHAR(  3) ' +
               ' ,@cReceiptKey NVARCHAR( 10) ' +
               ' ,@cPOKey      NVARCHAR( 10) ' +
               ' ,@cToLOC      NVARCHAR( 10) ' +
               ' ,@cToID       NVARCHAR( 18) ' +
               ' ,@cLottable01 NVARCHAR( 18) ' +
               ' ,@cLottable02 NVARCHAR( 18) ' +
               ' ,@cLottable03 NVARCHAR( 18) ' +
               ' ,@dLottable04 DATETIME      ' +
               ' ,@cSKU        NVARCHAR( 20) ' +
               ' ,@cUCC        NVARCHAR( 20) ' +
               ' ,@nQTY        INT           ' +
               ' ,@cOrg_ReceiptLineNumber       NVARCHAR( 5) ' +
               ' ,@nOrg_QTYExpected             INT          ' +
               ' ,@nOrg_BeforeReceivedQTY       INT          ' + 
               ' ,@cReceiptLineNumber           NVARCHAR( 5) ' +
               ' ,@nQTYExpected                 INT          ' + 
               ' ,@nBeforeReceivedQTY           INT          ' + 
               ' ,@cReceiptLineNumber_Borrowed  NVARCHAR( 5) ' +
               ' ,@cDuplicateFromLineNo         NVARCHAR( 5) OUTPUT ' +
               ' ,@nErrNo      INT              OUTPUT ' +
               ' ,@cErrMsg     NVARCHAR( 20)    OUTPUT '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                @nMobile, @nFunc, @cLangCode, @cReceiptKey, @cPOKey, @cToLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @cUCC, @nQTY
               ,@cOrg_ReceiptLineNumber
               ,@nOrg_QTYExpected
               ,@nOrg_BeforeReceivedQTY
               ,@cReceiptLineNumber
               ,@nQTYExpected
               ,@nBeforeReceivedQTY
               ,@cReceiptLineNumber_Borrowed
               ,@cDuplicateFromLineNo OUTPUT
               ,@nErrNo     OUTPUT
               ,@cErrMsg    OUTPUT
            IF @nErrNo <> 0
               GOTO RollBackTran
               
            IF @cDuplicateFromLineNo <> ''
            BEGIN
               SET @cReceiptLineNo_Borrowed = @cDuplicateFromLineNo
               SELECT 
                  @cExternReceiptKey    = ExternReceiptKey   ,
                  @cExternLineNo        = ExternLineNo       ,
                  @cAltSku              = AltSku             ,
                  @cVesselKey           = VesselKey          ,
                  @cVoyageKey           = VoyageKey          ,
                  @cXdockKey            = XdockKey           ,
                  @cContainerKey        = ContainerKey       ,
                  @nUnitPrice           = UnitPrice          ,
                  @nExtendedPrice       = ExtendedPrice      ,
                  @nFreeGoodQtyExpected = FreeGoodQtyExpected,
                  @nFreeGoodQtyReceived = FreeGoodQtyReceived,
                  @cExportStatus        = ExportStatus       ,
                  @cLoadKey             = LoadKey            ,
                  @cExternPoKey         = ExternPoKey        ,
                  @cPOKey               = POKey              ,
                  @cUserDefine01        = UserDefine01       ,
                  @cUserDefine02        = UserDefine02       ,
                  @cUserDefine03        = UserDefine03       ,
                  @cUserDefine04        = UserDefine04       ,
                  @cUserDefine05        = UserDefine05       ,
                  @dtUserDefine06       = UserDefine06       ,
                  @dtUserDefine07       = UserDefine07       ,
                  @cUserDefine08        = UserDefine08       ,
                  @cUserDefine09        = UserDefine09       ,
                  @cUserDefine10        = UserDefine10       ,
                  @cPoLineNo            = POLineNumber       ,
                  @cUOM                 = UOM                , 
                  @cChannel             = Channel
               FROM dbo.ReceiptDetail WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
                  AND ReceiptLineNumber = @cDuplicateFromLineNo
            END
         END
      END

      SET @cNewReceiptLineNumber = ''
      SELECT @cNewReceiptLineNumber =
      RIGHT( '00000' + CAST( CAST( IsNULL( MAX( ReceiptLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
      FROM dbo.ReceiptDetail (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey

      -- Insert new ReceiptDetail line
      INSERT INTO dbo.ReceiptDetail
         (ReceiptKey, ReceiptLineNumber, POKey, StorerKey, SKU, QTYExpected, BeforeReceivedQTY,
         ToID, ToLOC, Lottable01, Lottable02, Lottable03, Lottable04, --Lottable05,
         Status, DateReceived, UOM, PackKey, ConditionCode, EffectiveDate, TariffKey, FinalizeFlag, SplitPalletFlag,
         ExternReceiptKey, ExternLineNo, AltSku, VesselKey, -- Added By Vicky
         VoyageKey, XdockKey, ContainerKey, UnitPrice, ExtendedPrice, FreeGoodQtyExpected,
         FreeGoodQtyReceived, ExportStatus, LoadKey, ExternPoKey,
         UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05,
         UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10, POLineNumber, SubReasonCode, DuplicateFrom, Channel) -- (ChewKP01)
      SELECT
         @cReceiptKey, @cNewReceiptLineNumber, @cPOKey, @cStorerKey, @cSKU, @nQTYExpected, @nBeforeReceivedQTY,  -- (ChewKP01)
         @cToID, @cToLOC, @cLottable01, @cLottable02, @cLottable03, @dLottable04, --@dLottable05,
         '0', GETDATE(), @cUOM, @cPackKey, @cConditionCode, GETDATE(), @cTariffKey, 'N', 'N',
         ISNULL(@cExternReceiptKey,''), ISNULL(@cExternLineNo, ''), ISNULL(@cAltSku, ''), ISNULL(@cVesselKey,''), -- Added By Vicky
         ISNULL(@cVoyageKey, ''), ISNULL(@cXdockKey, ''), ISNULL(@cContainerKey, ''), ISNULL(@nUnitPrice, 0), ISNULL(@nExtendedPrice, 0), ISNULL(@nFreeGoodQtyExpected, 0),
         ISNULL(@nFreeGoodQtyReceived, 0), ISNULL(@cExportStatus, '0'), @cLoadKey, @cExternPoKey,
         ISNULL(@cUserDefine01, ''), ISNULL(@cUserDefine02, ''), ISNULL(@cUserDefine03, ''), ISNULL(@cUserDefine04, ''), ISNULL(@cUserDefine05, ''),
         @dtUserDefine06, @dtUserDefine07, ISNULL(@cUserDefine08, ''), ISNULL(@cUserDefine09, ''), ISNULL(@cUserDefine10, ''),
         ISNULL(@cPoLineNo, ''), @cSubreasonCode , @cReceiptLineNo_Borrowed, @cChannel -- (ChewKP01)
      FROM @tRD
      WHERE ReceiptLineNumber = @cReceiptLineNumber

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 60342
         SET @cErrMsg = rdt.rdtgetmessage( 60342, @cLangCode, 'DSP') --'INS RDtl fail'
         GOTO RollBackTran
      END

      UPDATE @tRD SET 
         ReceiptLineNumber = @cNewReceiptLineNumber
      WHERE RowRef = @nRowRef

      IF ISNULL(RTRIM(@cNewReceiptLineNumber),'') <> '' AND ISNULL(RTRIM(@cUCC),'') <> ''-- SOS# 249945
      BEGIN
         UPDATE @tUCC
         SET ReceiptLineNumber = @cNewReceiptLineNumber
         WHERE StorerKey = @cStorerKey
         AND ReceiptKey = @cReceiptKey
         AND UCCNo = @cUCC
         AND Id = @cToID
      END
      SET @cReceiptLineNumberOutput = @cNewReceiptLineNumber
   END
   ELSE
   BEGIN
      SET @cNewReceiptLineNumber = '' -- SOS# 249945
      -- Check if other process had updated ReceiptDetail
      DECLARE @cChkQTYExpected INT
      DECLARE @cChkBeforeReceivedQTY INT

      SELECT
         @cChkQTYExpected = QTYExpected,
         @cChkBeforeReceivedQTY = BeforeReceivedQTY
      FROM dbo.ReceiptDetail (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND ReceiptLineNumber = @cReceiptLineNumber

      -- Check if ReceiptDetail deleted
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 60343
         SET @cErrMsg = rdt.rdtgetmessage( 60343, @cLangCode, 'DSP') --'RDtl deleted'
         GOTO RollBackTran
      END

      -- Check if ReceiptDetail changed
      IF @cChkQTYExpected <> @nOrg_QTYExpected OR
         @cChkBeforeReceivedQTY <> @nOrg_BeforeReceivedQTY
      BEGIN
         SET @nErrNo = 60344
         SET @cErrMsg = rdt.rdtgetmessage( 60344, @cLangCode, 'DSP') --'RDtl changed'
         GOTO RollBackTran
      END

      /* multi SKU UCC might cause dead lock
      UCC-A (multi SKU)    UCC-B (single SKU)
      -----------------    ------------------
      SKU-A DTL-X
                           SKU-B DTL-X
      SKU-A HDR-X
                           SKU-B HDR-U-Wait
      SKU-B DTL-U-Wait
      
      X = Exclusive lock
      U = Update lock
      
      DTL = ReceiptDetail
      HDR = Receipt
      
      rdt_898RcvCfm12 
         --> ntrReceiptDetailUpdate (update Receipt.OpenQTY)
            --> ntrReceiptUpdate
      */
      
      -- Update Receipt to prevent deadlock
      IF @cUCC <> '' AND @cUCCWithMultiSKU = '1'
         UPDATE dbo.Receipt WITH (ROWLOCK) SET
            EditDate = GETDATE(),  
            EditWho = SUSER_SNAME(), 
            TrafficCop = NULL
         WHERE ReceiptKey = @cReceiptKey 

      -- Update ReceiptDetail
      UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET
         QTYExpected = @nQTYExpected,
         BeforeReceivedQTY = @nBeforeReceivedQTY,
         ToID = @cToID,
         ToLOC = @cToLOC,
         Lottable01 = CASE WHEN @cSkipLottable01 = '1' THEN Lottable01 ELSE @cLottable01 END,
         Lottable02 = CASE WHEN @cSkipLottable02 = '1' THEN Lottable02 ELSE @cLottable02 END,
         Lottable03 = CASE WHEN @cSkipLottable03 = '1' THEN Lottable03 ELSE @cLottable03 END,
         Lottable04 = CASE WHEN @cSkipLottable04 = '1' THEN Lottable04 ELSE @dLottable04 END,
         ConditionCode = @cConditionCode,
         SubreasonCode = @cSubreasonCode, 
         EditDate = GETDATE(),  
         EditWho = SUSER_SNAME()    
         -- Commented by SHONG on 20th Sept 2007 SOS# 87068
         -- TrafficCop = NULL
      WHERE ReceiptKey = @cReceiptKey
         AND ReceiptLineNumber = @cReceiptLineNumber
         AND RowVer = @bRowVer -- For detect row changed
         
      SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT

      -- Check error from trigger
      IF @nErrNo <> 0
      BEGIN
         -- SET @nErrNo = 60345
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --
         GOTO RollBackTran
      END
      
      -- Check row changed
      IF @nRowCount <> 1
      BEGIN
         SET @nErrNo = 60345
         SET @cErrMsg = rdt.rdtgetmessage( 60345, @cLangCode, 'DSP') --'UPD RDtl fail'
         GOTO RollBackTran
      END
      
      IF ISNULL(RTRIM(@cNewReceiptLineNumber),'') = '' AND ISNULL(RTRIM(@cUCC),'') <> ''-- SOS# 249945
      BEGIN
         UPDATE @tUCC
         SET ReceiptLineNumber = @cReceiptLineNumber
         WHERE StorerKey = @cStorerKey
         AND ReceiptKey = @cReceiptKey
         AND UCCNo = @cUCC
         AND Id = @cToID
      END
      SET @cReceiptLineNumberOutput = @cReceiptLineNumber
   END

   FETCH NEXT FROM @curRD INTO @nRowRef, 
         @cOrg_ReceiptLineNumber, @cReceiptLineNumber,
         @nOrg_QTYExpected, @nQTYExpected,
         @nOrg_BeforeReceivedQTY, @nBeforeReceivedQTY,
         @cToID, @cToLOC, @cLottable01, @cLottable02, @cLottable03, @dLottable04, --@dLottable05,
         @cReceiptLineNo_Borrowed, @bRowVer
END

-- Loop changed UCC
DECLARE @cUCCNo NVARCHAR( 20)
DECLARE @curUCC CURSOR

IF @cIncludePOKeyFilter = '1' -- (Vicky04)
BEGIN
   SET @curUCC = CURSOR FOR
      SELECT UCCNo, ReceiptKey, ReceiptLineNumber, QTY, ID, LOC, POKey
      FROM @tUCC
   OPEN @curUCC
   FETCH NEXT FROM @curUCC INTO @cUCCNo, @cReceiptKey, @cReceiptLineNumber, @nQTY, @cToID, @cToLOC, @cUCCPOkey -- (Vicky02)
   WHILE @@FETCH_STATUS = 0
   BEGIN

      IF EXISTS( SELECT 1
         FROM dbo.UCC (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCC
            AND Status = @cUCCStatus
            AND LEFT(ISNULL(Sourcekey, ''),10) = @cPOKey) -- (Vicky02) --(yeekung01)
      BEGIN
         -- Update UCC
         UPDATE dbo.UCC WITH (ROWLOCK) SET
            ID = @cToID,
            LOC = @cToLOC,
            QTY = @nQTY,
            Status = '1', --1=Received
            ReceiptKey = @cReceiptKey,
            ReceiptLineNumber = @cReceiptLineNumber, 
            EditDate = GETDATE(),  
            EditWho = SUSER_SNAME()                   
         WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCC
            AND Status = @cUCCStatus
            AND LEFT(ISNULL(Sourcekey, ''),10) = @cPOKey -- (Vicky02) --(yeekung01)
            AND SKU = CASE WHEN @cUCCWithMultiSKU = '1' THEN @cUCCSKU ELSE SKU END

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 60346
            SET @cErrMsg = rdt.rdtgetmessage( 60346, @cLangCode, 'DSP') --'UPD UCC fail'
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN

         -- Insert UCC
         INSERT INTO dbo.UCC (StorerKey, UCCNo, Status, SKU, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, ExternKey)
         VALUES (@cStorerKey, @cUCCNo, '1', @cSKU, @nQTY, @cToLOC, @cToID, @cReceiptKey, @cReceiptLineNumber, '')
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 60347
            SET @cErrMsg = rdt.rdtgetmessage( 60347, @cLangCode, 'DSP') --'INS UCC fail'
            GOTO RollBackTran
         END
      END
         FETCH NEXT FROM @curUCC INTO @cUCCNo, @cReceiptKey, @cReceiptLineNumber, @nQTY, @cToID, @cToLOC, @cUCCPOkey -- (Vicky02)
   END
   CLOSE @curUCC
   DEALLOCATE @curUCC
END
ELSE
BEGIN
   SET @curUCC = CURSOR FOR
      SELECT UCCNo, ReceiptKey, ReceiptLineNumber, QTY, ID, LOC
      FROM @tUCC
   OPEN @curUCC
   FETCH NEXT FROM @curUCC INTO @cUCCNo, @cReceiptKey, @cReceiptLineNumber, @nQTY, @cToID, @cToLOC
   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF EXISTS( SELECT 1
         FROM dbo.UCC (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCC
            AND Status = @cUCCStatus
            AND SKU = @cSKU)
      BEGIN
         -- Update UCC
         UPDATE TOP (1) dbo.UCC WITH (ROWLOCK) SET
            ID = @cToID,
            LOC = @cToLOC,
            QTY = @nQTY,
            Status = '1', --1=Received
            ReceiptKey = @cReceiptKey,
            ReceiptLineNumber = @cReceiptLineNumber, 
            EditDate = GETDATE(),  
            EditWho = SUSER_SNAME()
         WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCC
            AND Status = @cUCCStatus
            AND SKU = @cSKU
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 60346
            SET @cErrMsg = rdt.rdtgetmessage( 60346, @cLangCode, 'DSP') --'UPD UCC fail'
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         -- Insert UCC
         INSERT INTO dbo.UCC (StorerKey, UCCNo, Status, SKU, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, ExternKey)
         VALUES (@cStorerKey, @cUCCNo, '1', @cSKU, @nQTY, @cToLOC, @cToID, @cReceiptKey, @cReceiptLineNumber, '')
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 60347
            SET @cErrMsg = rdt.rdtgetmessage( 60347, @cLangCode, 'DSP') --'INS UCC fail'
            GOTO RollBackTran
         END
      END
      FETCH NEXT FROM @curUCC INTO @cUCCNo, @cReceiptKey, @cReceiptLineNumber, @nQTY, @cToID, @cToLOC
   END
   CLOSE @curUCC
   DEALLOCATE @curUCC
END

-- Many serial no
IF @nBulkSNO = '1' 
BEGIN
   DECLARE @nReceiveSerialNoLogKey INT
   
   -- Check SNO QTY
   IF (SELECT ISNULL( SUM( QTY), 0) 
      FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)
      WHERE Mobile = @nMobile
         AND Func = @nFunc) <> @nBulkSNOQTY
   BEGIN
      SET @nErrNo = 60356
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SN QTYNotTally
      GOTO RollBackTran
   END 
   
   SET @nQTY_Bal = @nQTY
   
   -- Loop serial no
   SET @curRD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT ReceiptLineNumber, BeforeReceivedQTY - Org_BeforeReceivedQTY
      FROM @tRD
      WHERE BeforeReceivedQTY <> Org_BeforeReceivedQTY
   OPEN @curRD
   FETCH NEXT FROM @curRD INTO @cReceiptLineNumber, @nRDQTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      WHILE @nRDQTY > 0
      BEGIN
         SELECT TOP 1 
            @nReceiveSerialNoLogKey = ReceiveSerialNoLogKey, 
            @cSerialNo = SerialNo, 
            @nSerialQTY = QTY
         FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)
         WHERE Mobile = @nMobile
            AND Func = @nFunc
            AND QTY <= @nRDQTY

         IF @@ROWCOUNT = 0
            BREAK

         -- ReceiptSerialNo
         EXEC rdt.rdt_Receive_ReceiptSerialNo @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility, 
            @cReceiptKey, 
            @cReceiptLineNumber,
            @cSKU,
            @cSerialNo, 
            @nSerialQTY, 
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran

         DELETE rdt.rdtReceiveSerialNoLog 
         WHERE ReceiveSerialNoLogKey = @nReceiveSerialNoLogKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 60356
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL TmpSN Fail
            GOTO RollBackTran
         END 

         SET @nRDQTY = @nRDQTY - @nSerialQTY
         SET @nQTY_Bal = @nQTY_Bal - @nSerialQTY
      END
      
      -- Check offset
      IF @nRDQTY <> 0
      BEGIN
         SET @nErrNo = 60356
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset error 
         GOTO RollBackTran
      END  

      FETCH NEXT FROM @curRD INTO @cReceiptLineNumber, @nRDQTY
   END

   -- Check fully offset
   IF @nQTY_Bal <> 0
   BEGIN
      SET @nErrNo = 60356
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset error 
      GOTO RollBackTran
   END 

   -- Check balance
   IF EXISTS( SELECT 1
      FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)
      WHERE Mobile = @nMobile
         AND Func = @nFunc)
   BEGIN
      SET @nErrNo = 60356
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset error 
      GOTO RollBackTran
   END
END

-- Single serial no
ELSE IF @cSerialNo <> '' 
BEGIN
   -- ReceiptSerialNo
   EXEC rdt.rdt_Receive_ReceiptSerialNo @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility, 
      @cReceiptKey, 
      @cReceiptLineNumberOutput,     -- KM01
      @cSKU,
      @cSerialNo, 
      @nSerialQTY, 
      @nErrNo     OUTPUT,
      @cErrMsg    OUTPUT
   IF @nErrNo <> 0
      GOTO RollBackTran
END

-- Close pallet
IF rdt.RDTGetConfig( @nFunc, 'ClosePallet', @cStorerKey) > '0'
BEGIN
   IF NOT EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cToID)
   BEGIN
      INSERT INTO DropID (DropID, DropLOC) VALUES (@cToID, @cToLOC)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 60351
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DID Fail
         GOTO RollBackTran
      END
   END
END

-- Auto finalize upon receive
DECLARE @cNotFinalizeRD NVARCHAR(1)
SET @cNotFinalizeRD = rdt.RDTGetConfig( 0, 'RDT_NotFinalizeReceiptDetail', @cStorerKey) 

IF @cNotFinalizeRD <> '1'  -- 1=Not finalize
BEGIN
   IF @cNotFinalizeRD = '0'
   BEGIN
      -- Bulk update (so that trigger fire only once, compare with row update that fire trigger each time)  
      UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET  
         QTYReceived = RD.BeforeReceivedQTY,  
         FinalizeFlag = 'Y', 
         EditDate = GETDATE(),  
         EditWho = SUSER_SNAME()    
      FROM dbo.ReceiptDetail RD  
         INNER JOIN @tRD T ON (T.ReceiptLineNumber = RD.ReceiptLineNumber)  
      WHERE RD.ReceiptKey = @cReceiptKey  
         AND T.BeforeReceivedQTY <> T.Org_BeforeReceivedQTY  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 60348  
         SET @cErrMsg = rdt.rdtgetmessage( 60348, @cLangCode, 'DSP') --'Finalize fail'   -- (ChewKP03)
         GOTO RollBackTran  
      END
   END
   
   IF @cNotFinalizeRD = '2'
   BEGIN
      SET @curRD = CURSOR FOR
         SELECT T.ReceiptLineNumber
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
            INNER JOIN @tRD T ON (T.ReceiptLineNumber = RD.ReceiptLineNumber)  
         WHERE RD.ReceiptKey = @cReceiptKey  
            AND T.BeforeReceivedQTY <> T.Org_BeforeReceivedQTY 
      OPEN @curRD
      FETCH NEXT FROM @curRD INTO @cReceiptLineNumber
      WHILE @@FETCH_STATUS = 0
      BEGIN
         EXEC dbo.ispFinalizeReceipt
             @c_ReceiptKey        = @cReceiptKey
            ,@b_Success           = @b_Success  OUTPUT
            ,@n_err               = @nErrNo     OUTPUT
            ,@c_ErrMsg            = @cErrMsg    OUTPUT
            ,@c_ReceiptLineNumber = @cReceiptLineNumber
         IF @nErrNo <> 0 OR @b_Success = 0
            GOTO RollBackTran
         
         FETCH NEXT FROM @curRD INTO @cReceiptLineNumber
      END
   END
END  
  
IF @cDebug = '1'  
BEGIN
   SELECT * FROM @tRD  
   SELECT * FROM @tUCC  
END  
ELSE  
BEGIN  
   COMMIT TRAN rdt_898RcvCfm12 -- Only commit change made in here  
   GOTO Quit  
END  
  
RollBackTran:  
   ROLLBACK TRAN rdt_898RcvCfm12  
Fail:  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  


GO