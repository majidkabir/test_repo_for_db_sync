SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: isp_PostPieceReceiving                                    */
/* Copyright      : IDS                                                       */
/*                                                                            */
/* Purpose: Lookup qualified ReceiptDetail lines to receive in the QTY        */
/*                                                                            */
/* PVCS Version: 2.1                                                          */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author      Purposes                                       */
/* 2007-03-20 1.0  UngDH       Created                                        */
/* 2015-04-16 2.0  CSCHONG     New lottable06 to 15 (Cs01)                    */
/******************************************************************************/

CREATE PROCEDURE [dbo].[isp_PostPieceReceiving] (
   @nErrNo         INT          OUTPUT,
   @cErrMsg        VARCHAR( 20) OUTPUT, -- screen limitation, 20 char max
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
   @cLottable04    NVARCHAR( 18),
   @cLottable05    NVARCHAR( 18),
   @cLottable06   NVARCHAR(30)   = '',    --(CS01)
   @cLottable07   NVARCHAR(30)   = '',    --(CS01)
   @cLottable08   NVARCHAR(30)   = '',    --(CS01)
   @cLottable09   NVARCHAR(30)   = '',    --(CS01)
   @cLottable10   NVARCHAR(30)   = '',    --(CS01)
   @cLottable11   NVARCHAR(30)   = '',    --(CS01)
   @cLottable12   NVARCHAR(30)   = '',    --(CS01)
   @cLottable13  NVARCHAR(30)   = '',  --(CS01) 
   @cLottable14  NVARCHAR(30)   = '',  --(CS01)
   @cLottable15  NVARCHAR(30)   = '',  --(CS01) 
   @nNOPOFlag      INT,
   @cConditionCode NVARCHAR( 10) ,
   @cSubreasonCode NVARCHAR( 10)
) AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @bSuccess  INT
DECLARE @nTranCount INT
DECLARE @cDocType   NVARCHAR( 1)
DECLARE @cSKU       NVARCHAR( 20)
DECLARE @nQTY       INT
DECLARE @cUOM       NVARCHAR( 10)
       ,@cPackUOM3  NVARCHAR( 10)

DECLARE @cDebug     NVARCHAR( 1) 
DECLARE @dLottable04 DATETIME,
        @dLottable05 DATETIME,
        @dLottable13 DATETIME,
        @dLottable14 DATETIME,
        @dLottable15 DATETIME 


/*-------------------------------------------------------------------------------

                                 Get storer config

-------------------------------------------------------------------------------*/
-- Storer config var
DECLARE @cAllow_OverReceipt     NVARCHAR( 1)
DECLARE @cByPassTolerance       NVARCHAR( 1)
DECLARE @cStorerConfig_UCC      NVARCHAR( 1)
DECLARE @cUCCWithDynamicCaseCnt NVARCHAR( 1)
DECLARE @cAddNwUCCR             NVARCHAR( 1)
DECLARE @nDisAllowDuplicateIdsOnRFRcpt INT
DECLARE @cSkipCheckMultiUCC     NVARCHAR( 1) 
DECLARE @cIncludePOKeyFilter    NVARCHAR( 1) 

DECLARE @cDuplicateFromMatchValue    NVARCHAR(1) 
        ,@nCount                     INT     
        ,@cASNMatchByPOLineValue     NVARCHAR(1) 
        ,@cExternLineNumber          NVARCHAR(5) 
        ,@cBorrowed_OriginalReceiptLineNumber NVARCHAR(5) 

-- Get SkipLottable setting
DECLARE @cSkipLottable01      NVARCHAR( 1)
DECLARE @cSkipLottable02      NVARCHAR( 1)
DECLARE @cSkipLottable03      NVARCHAR( 1)
DECLARE @cSkipLottable04      NVARCHAR( 1)

/*CS01 start*/
DECLARE @cSkipLottable06      NVARCHAR( 1)
DECLARE @cSkipLottable07      NVARCHAR( 1)
DECLARE @cSkipLottable08      NVARCHAR( 1)
DECLARE @cSkipLottable09      NVARCHAR( 1)
DECLARE @cSkipLottable10      NVARCHAR( 1)
DECLARE @cSkipLottable11      NVARCHAR( 1)
DECLARE @cSkipLottable12      NVARCHAR( 1)
DECLARE @cSkipLottable13      NVARCHAR( 1)
DECLARE @cSkipLottable14      NVARCHAR( 1)
DECLARE @cSkipLottable15      NVARCHAR( 1)
/*CS01 End*/


DECLARE @cLottable01Required  NVARCHAR( 1)
DECLARE @cLottable02Required  NVARCHAR( 1)
DECLARE @cLottable03Required  NVARCHAR( 1)
DECLARE @cLottable04Required  NVARCHAR( 1)
DECLARE @cLottable05Required  NVARCHAR( 1)
DECLARE @cAddUCCFromUDF01     NVARCHAR( 1)
DECLARE @cPackKey             NVARCHAR( 10)
DECLARE @cTariffkey           NVARCHAR( 10)
DECLARE @nTolerancePercentage INT


/*CS01 Start*/

DECLARE @cLottable06Required  NVARCHAR( 1)
DECLARE @cLottable07Required  NVARCHAR( 1)
DECLARE @cLottable08Required  NVARCHAR( 1)
DECLARE @cLottable09Required  NVARCHAR( 1)
DECLARE @cLottable10Required  NVARCHAR( 1)
DECLARE @cLottable11Required  NVARCHAR( 1)
DECLARE @cLottable12Required  NVARCHAR( 1)
DECLARE @cLottable13Required  NVARCHAR( 1)
DECLARE @cLottable14Required  NVARCHAR( 1)
DECLARE @cLottable15Required  NVARCHAR( 1)
  
/*CS01 End*/

DECLARE @cUCCUOM              NVARCHAR( 10)

-- Get the UCC by status
DECLARE @cUCCStatus      NVARCHAR( 10)
DECLARE @nCount_Received INT
DECLARE @nCount_CanBeUse INT
   
SET  @cDuplicateFromMatchValue = '0'  
SET  @cASNMatchByPOLineValue = '0'    
SET  @cExternLineNumber = ''          
SET  @cDebug = '0'          

IF @nErrNo = 999 
BEGIN
   SET  @cDebug = '1'  
   SET @nErrNo = 0 
END          


IF @cPOKey = 'NOPO'
BEGIN
   SET @cPOKey = ''
END

-- NSQLConfig 'DisAllowDuplicateIdsOnRFRcpt'
SET @nDisAllowDuplicateIdsOnRFRcpt = 0 -- Default Off
SELECT @nDisAllowDuplicateIdsOnRFRcpt = NSQLValue
FROM dbo.NSQLConfig (NOLOCK)
WHERE ConfigKey = 'DisAllowDuplicateIdsOnRFRcpt'


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
IF ISNULL(@cLottable04,'') = ''     
   SET @dLottable04 = NULL
ELSE
   SET @dLottable04 = CONVERT(DATETIME, @cLottable04)
   
IF ISNULL(@cLottable05,'') = ''     
   SET @dLottable05 = NULL
ELSE
   SET @dLottable05 = CONVERT(DATETIME, @cLottable05)

/*CS01 start*/

IF @cLottable06 IS NULL SET @cLottable06 = ''
IF @cLottable07 IS NULL SET @cLottable07 = ''
IF @cLottable08 IS NULL SET @cLottable08 = ''

IF @cLottable09 IS NULL SET @cLottable09 = ''
IF @cLottable10 IS NULL SET @cLottable10 = ''
IF @cLottable11 IS NULL SET @cLottable11 = ''
IF @cLottable12 IS NULL SET @cLottable12 = ''

IF ISNULL(@cLottable13,'') = ''     
   SET @dLottable13 = NULL
ELSE
   SET @dLottable13 = CONVERT(DATETIME, @cLottable13)

IF ISNULL(@cLottable14,'') = ''     
   SET @dLottable14 = NULL
ELSE
   SET @dLottable14 = CONVERT(DATETIME, @cLottable14)
   
IF ISNULL(@cLottable15,'') = ''     
   SET @dLottable15 = NULL
ELSE
   SET @dLottable15 = CONVERT(DATETIME, @cLottable15)



SELECT
   @cLottable01Required = CASE WHEN Lottable01Label <> '' THEN '1' ELSE '0' END,
   @cLottable02Required = CASE WHEN Lottable02Label <> '' THEN '1' ELSE '0' END,
   @cLottable03Required = CASE WHEN Lottable03Label <> '' THEN '1' ELSE '0' END,
   @cLottable04Required = CASE WHEN Lottable04Label <> '' THEN '1' ELSE '0' END,
   @cLottable06Required = CASE WHEN Lottable06Label <> '' THEN '1' ELSE '0' END,
   @cLottable07Required = CASE WHEN Lottable07Label <> '' THEN '1' ELSE '0' END,
   @cLottable08Required = CASE WHEN Lottable08Label <> '' THEN '1' ELSE '0' END,
   @cLottable09Required = CASE WHEN Lottable09Label <> '' THEN '1' ELSE '0' END,
   @cLottable10Required = CASE WHEN Lottable10Label <> '' THEN '1' ELSE '0' END,
   @cLottable11Required = CASE WHEN Lottable11Label <> '' THEN '1' ELSE '0' END,
   @cLottable12Required = CASE WHEN Lottable12Label <> '' THEN '1' ELSE '0' END,
   @cLottable13Required = CASE WHEN Lottable13Label <> '' THEN '1' ELSE '0' END,
   @cLottable14Required = CASE WHEN Lottable14Label <> '' THEN '1' ELSE '0' END,
   @cLottable15Required = CASE WHEN Lottable15Label <> '' THEN '1' ELSE '0' END,
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
   AND SKU = @cSKUCode
/*CS01 End*/

SET @cPackUOM3 = ''
SELECT @cPackUOM3 = PackUOM3 
FROM PACK WITH (NOLOCK) 
WHERE PackKey = @cPackKey
   
EXEC nspGetRight   @c_Facility = @cFacility,         @c_StorerKey = @cStorerKey,      @c_sku = '',   
                   @c_ConfigKey = 'SkipLottable01',  @b_Success = @bSuccess OUTPUT,   @c_authority = @cSkipLottable01 OUTPUT,
                   @n_err = @nErrNo OUTPUT,          @c_errmsg = @cErrMsg OUTPUT

EXEC nspGetRight   @c_Facility = @cFacility,         @c_StorerKey = @cStorerKey,       @c_sku = '',   
                   @c_ConfigKey = 'SkipLottable02',  @b_Success = @bSuccess OUTPUT,   @c_authority = @cSkipLottable02 OUTPUT,
                   @n_err = @nErrNo OUTPUT,          @c_errmsg = @cErrMsg OUTPUT

EXEC nspGetRight   @c_Facility = @cFacility,         @c_StorerKey = @cStorerKey,       @c_sku = '',   
                   @c_ConfigKey = 'SkipLottable03',  @b_Success = @bSuccess OUTPUT,   @c_authority = @cSkipLottable03 OUTPUT,
                   @n_err = @nErrNo OUTPUT,          @c_errmsg = @cErrMsg OUTPUT

EXEC nspGetRight   @c_Facility = @cFacility,         @c_StorerKey = @cStorerKey,       @c_sku = '',   
                   @c_ConfigKey = 'SkipLottable04',  @b_Success = @bSuccess OUTPUT,   @c_authority = @cSkipLottable04 OUTPUT,
                   @n_err = @nErrNo OUTPUT,          @c_errmsg = @cErrMsg OUTPUT

/*CS01 Start*/

EXEC nspGetRight   @c_Facility = @cFacility,         @c_StorerKey = @cStorerKey,      @c_sku = '',   
                   @c_ConfigKey = 'SkipLottable06',  @b_Success = @bSuccess OUTPUT,   @c_authority = @cSkipLottable06 OUTPUT,
                   @n_err = @nErrNo OUTPUT,          @c_errmsg = @cErrMsg OUTPUT

EXEC nspGetRight   @c_Facility = @cFacility,         @c_StorerKey = @cStorerKey,       @c_sku = '',   
                   @c_ConfigKey = 'SkipLottable07',  @b_Success = @bSuccess OUTPUT,   @c_authority = @cSkipLottable07 OUTPUT,
                   @n_err = @nErrNo OUTPUT,          @c_errmsg = @cErrMsg OUTPUT

EXEC nspGetRight   @c_Facility = @cFacility,         @c_StorerKey = @cStorerKey,       @c_sku = '',   
                   @c_ConfigKey = 'SkipLottable08',  @b_Success = @bSuccess OUTPUT,   @c_authority = @cSkipLottable08 OUTPUT,
                   @n_err = @nErrNo OUTPUT,          @c_errmsg = @cErrMsg OUTPUT

EXEC nspGetRight   @c_Facility = @cFacility,         @c_StorerKey = @cStorerKey,       @c_sku = '',   
                   @c_ConfigKey = 'SkipLottable09',  @b_Success = @bSuccess OUTPUT,   @c_authority = @cSkipLottable09 OUTPUT,
                   @n_err = @nErrNo OUTPUT,          @c_errmsg = @cErrMsg OUTPUT

EXEC nspGetRight   @c_Facility = @cFacility,         @c_StorerKey = @cStorerKey,      @c_sku = '',   
                   @c_ConfigKey = 'SkipLottable10',  @b_Success = @bSuccess OUTPUT,   @c_authority = @cSkipLottable10 OUTPUT,
                   @n_err = @nErrNo OUTPUT,          @c_errmsg = @cErrMsg OUTPUT

EXEC nspGetRight   @c_Facility = @cFacility,         @c_StorerKey = @cStorerKey,       @c_sku = '',   
                   @c_ConfigKey = 'SkipLottable11',  @b_Success = @bSuccess OUTPUT,   @c_authority = @cSkipLottable11 OUTPUT,
                   @n_err = @nErrNo OUTPUT,          @c_errmsg = @cErrMsg OUTPUT

EXEC nspGetRight   @c_Facility = @cFacility,         @c_StorerKey = @cStorerKey,       @c_sku = '',   
                   @c_ConfigKey = 'SkipLottable12',  @b_Success = @bSuccess OUTPUT,   @c_authority = @cSkipLottable12 OUTPUT,
                   @n_err = @nErrNo OUTPUT,          @c_errmsg = @cErrMsg OUTPUT

EXEC nspGetRight   @c_Facility = @cFacility,         @c_StorerKey = @cStorerKey,       @c_sku = '',   
                   @c_ConfigKey = 'SkipLottable13',  @b_Success = @bSuccess OUTPUT,   @c_authority = @cSkipLottable13 OUTPUT,
                   @n_err = @nErrNo OUTPUT,          @c_errmsg = @cErrMsg OUTPUT

EXEC nspGetRight   @c_Facility = @cFacility,         @c_StorerKey = @cStorerKey,       @c_sku = '',   
                   @c_ConfigKey = 'SkipLottable14',  @b_Success = @bSuccess OUTPUT,   @c_authority = @cSkipLottable14 OUTPUT,
                   @n_err = @nErrNo OUTPUT,          @c_errmsg = @cErrMsg OUTPUT

EXEC nspGetRight   @c_Facility = @cFacility,         @c_StorerKey = @cStorerKey,       @c_sku = '',   
                   @c_ConfigKey = 'SkipLottable15',  @b_Success = @bSuccess OUTPUT,   @c_authority = @cSkipLottable15 OUTPUT,
                   @n_err = @nErrNo OUTPUT,          @c_errmsg = @cErrMsg OUTPUT

                                                                            
IF @cSkipLottable01 = '1' SELECT @cLottable01Required = '0', @cLottable01 = ''
IF @cSkipLottable02 = '1' SELECT @cLottable02Required = '0', @cLottable02 = ''
IF @cSkipLottable03 = '1' SELECT @cLottable03Required = '0', @cLottable03 = ''
IF @cSkipLottable04 = '1' SELECT @cLottable04Required = '0', @dLottable04 = NULL


IF @cSkipLottable06 = '1' SELECT @cLottable06Required = '0', @cLottable06 = ''
IF @cSkipLottable07 = '1' SELECT @cLottable07Required = '0', @cLottable07 = ''
IF @cSkipLottable08 = '1' SELECT @cLottable08Required = '0', @cLottable08 = ''
IF @cSkipLottable09 = '1' SELECT @cLottable09Required = '0', @cLottable09 = ''
IF @cSkipLottable10 = '1' SELECT @cLottable10Required = '0', @cLottable10 = ''
IF @cSkipLottable11 = '1' SELECT @cLottable11Required = '0', @cLottable11 = ''
IF @cSkipLottable12 = '1' SELECT @cLottable12Required = '0', @cLottable12 = ''
IF @cSkipLottable13= '1' SELECT @cLottable13Required = '0', @dLottable13 = NULL
IF @cSkipLottable14= '1' SELECT @cLottable14Required = '0', @dLottable14 = NULL
IF @cSkipLottable15= '1' SELECT @cLottable15Required = '0', @dLottable15 = NULL

IF @cLottable01Required = '1' AND @cLottable01 = ''
BEGIN
   SET @nErrNo = 60333
   SET @cErrMsg = 'Lottable01 Required'
   GOTO Fail
END

IF @cLottable02Required = '1' AND @cLottable02 = ''
BEGIN
   SET @nErrNo = 60334
   SET @cErrMsg = 'Lottable2 Required'
   GOTO Fail
END

IF @cLottable03Required = '1' AND @cLottable03 = ''
BEGIN
   SET @nErrNo = 60335
   SET @cErrMsg = 'Lottable3 Required'
   GOTO Fail
END

IF @cLottable04Required = '1' AND @dLottable04 IS NULL
BEGIN
   SET @nErrNo = 60336
   SET @cErrMsg = 'Lottable4 Required'
   GOTO Fail
END


IF @cLottable06Required = '1' AND @cLottable06 = ''
BEGIN
   SET @nErrNo = 60337
   SET @cErrMsg = 'Lottable06 Required'
   GOTO Fail
END

IF @cLottable07Required = '1' AND @cLottable07 = ''
BEGIN
   SET @nErrNo = 60338
   SET @cErrMsg = 'Lottable7 Required'
   GOTO Fail
END

IF @cLottable08Required = '1' AND @cLottable08 = ''
BEGIN
   SET @nErrNo = 60339
   SET @cErrMsg = 'Lottable8 Required'
   GOTO Fail
END

IF @cLottable09Required = '1' AND @cLottable09 = ''
BEGIN
   SET @nErrNo = 60340
   SET @cErrMsg = 'Lottable09 Required'
   GOTO Fail
END

IF @cLottable10Required = '1' AND @cLottable10 = ''
BEGIN
   SET @nErrNo = 60341
   SET @cErrMsg = 'Lottable10 Required'
   GOTO Fail
END

IF @cLottable11Required = '1' AND @cLottable11 = ''
BEGIN
   SET @nErrNo = 60342
   SET @cErrMsg = 'Lottable11 Required'
   GOTO Fail
END

IF @cLottable12Required = '1' AND @cLottable12 = ''
BEGIN
   SET @nErrNo = 60343
   SET @cErrMsg = 'Lottable12 Required'
   GOTO Fail
END

IF @cLottable13Required = '1' AND @dLottable13 IS NULL
BEGIN
   SET @nErrNo = 60344
   SET @cErrMsg = 'Lottable13 Required'
   GOTO Fail
END

IF @cLottable14Required = '1' AND @dLottable14 IS NULL
BEGIN
   SET @nErrNo = 60345
   SET @cErrMsg = 'Lottable14 Required'
   GOTO Fail
END

IF @cLottable15Required = '1' AND @dLottable15 IS NULL
BEGIN
   SET @nErrNo = 60346
   SET @cErrMsg = 'Lottable15 Required'
   GOTO Fail
END

/*CS01 End*/

SET @bSuccess = 0  
SET @cAddUCCFromUDF01='0'
Execute nspGetRight null,  -- facility  
   @cStorerKey,           -- Storerkey  
   '',                     -- Sku  
   'AddUCCFromColUDF01',   -- Configkey  
   @bSuccess           OUTPUT,  
   @cAddUCCFromUDF01   OUTPUT,   
   @nErrNo              OUTPUT,  
   @cErrMsg             OUTPUT  

               

-- Truncate the time portion
IF @dLottable04 IS NOT NULL
   SET @dLottable04 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dLottable04, 120), 120)
IF @dLottable05 IS NOT NULL
   SET @dLottable05 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dLottable05, 120), 120)

/*CS01 start*/

IF @dLottable13 IS NOT NULL
   SET @dLottable13 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dLottable13, 120), 120)
IF @dLottable14 IS NOT NULL
   SET @dLottable14 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dLottable14, 120), 120)
IF @dLottable15 IS NOT NULL
   SET @dLottable15 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dLottable15, 120), 120)


/*CS01 End*/

SET @cIncludePOKeyFilter = ''
SELECT @cIncludePOKeyFilter = ISNULL(sValue,'0')
FROM StorerConfig sc WITH (NOLOCK) 
WHERE sc.ConfigKey = 'IncludePOKeyFilter'
AND sc.StorerKey =  @cStorerKey 
IF ISNULL(RTRIM(@cIncludePOKeyFilter), '') = ''
BEGIN
   SET @cIncludePOKeyFilter = '0'
END

/*-------------------------------------------------------------------------------

                                 Validate data

-------------------------------------------------------------------------------*/
DECLARE @cChkFacility  NVARCHAR( 5)
DECLARE @cChkStorerKey NVARCHAR( 15)
DECLARE @cChkStatus    NVARCHAR( 10)
DECLARE @cChkASNStatus NVARCHAR( 10)
DECLARE @cChkLOC       NVARCHAR( 10)
DECLARE @cUCCPOkey     NVARCHAR( 10)

-- Validate StorerKey
IF @cStorerKey = ''
BEGIN
   SET @nErrNo = 60305
   SET @cErrMsg = 'Need StorerKey'
   GOTO Fail
END

-- Validate Facility
IF @cFacility = ''
BEGIN
   SET @nErrNo = 60306
   SET @cErrMsg = 'Need Facility'
   GOTO Fail
END

-- Validate ReceiptKey
IF @cReceiptKey = ''
BEGIN
   SET @nErrNo = 60307
   SET @cErrMsg = 'Need ASN'
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
   SET @cErrMsg = 'ASN not found'
   GOTO Fail
END

-- Validate ASN in different facility
IF @cFacility <> @cChkFacility
BEGIN
   SET @nErrNo = 60309
   SET @cErrMsg = 'ASN not in FAC'
   GOTO Fail
END

-- Validate ASN belong to diff storer
IF @cStorerKey <> @cChkStorerKey
BEGIN
   SET @nErrNo = 60310
   SET @cErrMsg = 'Diff storer'
   GOTO Fail
END

-- Validate status
IF @cChkStatus <> '0'
BEGIN
   SET @nErrNo = 60311
   SET @cErrMsg = 'ASN not open'
   GOTO Fail
END

-- Validate ASN status
IF @cChkASNStatus <> '0'
BEGIN
   SET @nErrNo = 60312
   SET @cErrMsg = 'Bad ASNStatus'
   GOTO Fail
END

-- Validate POKey
IF @cPOKey <> '' AND NOT EXISTS(
      SELECT 1
      FROM dbo.ReceiptDetail (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND POKey = @cPOKey)
BEGIN
   SET @nErrNo = 60313
   SET @cErrMsg = 'PO not in ASN'
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
   SET @cErrMsg = 'Invalid LOC'
   GOTO Fail
END

-- Validate ToLOC not in facility
IF @cChkFacility <> @cFacility
BEGIN
   SET @nErrNo = 60315
   SET @cErrMsg = 'LOC not in FAC'
   GOTO Fail
END

-- Validate ToID
IF @nDisAllowDuplicateIdsOnRFRcpt = '1' AND @cToID <> ''
BEGIN
   IF EXISTS( SELECT 1
      FROM dbo.LOTxLOCxID LLI (NOLOCK)
         INNER JOIN dbo.LOC LOC (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LLI.ID = @cToID
         AND LLI.QTY > 0
         AND LOC.Facility = @cFacility) -- Check duplicate ID within same facility only
   BEGIN
      SET @nErrNo  = 60316
      SET @cErrMsg = 'ID in used'
      GOTO Fail
   END
END

-- Validate both SKU and UCC passed-in
--IF @cSKUCode <> '' AND @cUCC <> ''
--BEGIN
--   SET @nErrNo = 60317
--   SET @cErrMsg = 'Either SKU Or UCC'
--   GOTO Fail
--END

-- Validate both SKU and UCC not passed-in
IF @cSKUCode = '' AND @cUCC = ''
BEGIN
   SET @nErrNo = 60318
   SET @cErrMsg = 'SKU or UCC req'
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
      SET @cErrMsg = 'Invalid SKU'
      GOTO Fail
   END

   -- Validate UOM field
   IF @cSKUUOM = ''
   BEGIN
      SET @cSKUUOM = @cPackUOM3
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
      SET @cErrMsg = 'Invalid UOM'
      GOTO Fail
   END

END

-- Validate UCC
--IF @cUCC <> ''
--BEGIN
--   -- Get the UCC by status
--   DECLARE @cUCCStatus      NVARCHAR( 10)
--   DECLARE @nCount_Received INT
--   DECLARE @nCount_CanBeUse INT
--
--   IF @cIncludePOKeyFilter = '1' 
--   BEGIN
--      SELECT
--         @nCount_Received = IsNULL( SUM( CASE WHEN Status =  '1' THEN 1 ELSE 0 END), 0), -- 1=Received
--         @nCount_CanBeUse = IsNULL( SUM( CASE WHEN Status <> '1' THEN 1 ELSE 0 END), 0)  -- the rest, can be receive
--      FROM dbo.UCC (NOLOCK)
--      WHERE StorerKey = @cStorerKey
--        AND UCCNo = @cUCC
--        AND LEFT(ISNULL(Sourcekey, ''),10) = @cPOKey 
--   END
--   ELSE
--   BEGIN
--      SELECT
--         @nCount_Received = IsNULL( SUM( CASE WHEN Status =  '1' THEN 1 ELSE 0 END), 0), -- 1=Received
--         @nCount_CanBeUse = IsNULL( SUM( CASE WHEN Status <> '1' THEN 1 ELSE 0 END), 0)  -- the rest, can be receive
--      FROM dbo.UCC (NOLOCK)
--      WHERE StorerKey = @cStorerKey
--        AND UCCNo = @cUCC
--   END
--
--   -- Validate UCC existance
--   IF @cCreateUCC = '1' --Creating new UCC
--   BEGIN
--      -- Check if try to create UCC that already exists
--      IF @nCount_Received > 0
--      BEGIN
--         SET @nErrNo = 60326
--         SET @cErrMsg = 'UCC Already Received'
--         GOTO Fail
--      END
--
--      -- Check if try create new UCC instead of reuse existing ones
--      IF @nCount_CanBeUse > 0
--      BEGIN
--         SET @nErrNo = 60327
--         SET @cErrMsg = 'UCC Already Exists'
--         GOTO Fail
--      END
--
--      SET @cUCCStatus = '0' -- 0=Open
--   END
--   ELSE -- Receive existing UCC
--   BEGIN
--      -- Check if the UCC is already received
--      IF @nCount_Received > 0
--      BEGIN
--         SET @nErrNo = 60328
--         SET @cErrMsg = 'UCC Already Received'
--         GOTO Fail
--      END
--
--      -- Check if any UCC can be receive
--      IF @nCount_CanBeUse < 1
--      BEGIN
--         SET @nErrNo = 60349
--         SET @cErrMsg = 'UCC not found'
--         GOTO Fail
--      END
--
--      -- Get the UCC status. 1 UCC could have multiple records, with different status
--      DECLARE @nChkUCCQTY INT
--
--      IF @cIncludePOKeyFilter = '1' 
--      BEGIN
--         SELECT TOP 1
--            @cUCCStatus = Status,
--            @nChkUCCQTY = QTY
--         FROM dbo.UCC (NOLOCK)
--         WHERE StorerKey = @cStorerKey
--           AND UCCNo = @cUCC
--           AND Status <> '1' -- Not received
--           AND LEFT(ISNULL(Sourcekey, ''),10) = @cPOKey 
--         ORDER BY Status      -- Try to use 0-Open status 1st
--      END
--      ELSE
--      BEGIN
--         SELECT TOP 1
--            @cUCCStatus = Status,
--            @nChkUCCQTY = QTY
--         FROM dbo.UCC (NOLOCK)
--         WHERE StorerKey = @cStorerKey
--           AND UCCNo = @cUCC
--           AND Status <> '1' -- Not received
--         ORDER BY Status      -- Try to use 0-Open status 1st
--      END
--
--      -- Check UCC QTY (Keyed-in and UCC.QTY diff)
--      IF (@nChkUCCQTY <> @nUCCQTY)
--      BEGIN
--         SET @nErrNo = 60350
--         SET @cErrMsg = 'UCC QTY Not Match'
--         GOTO Fail
--      END
--   END
--
--   -- Validate UCC SKU blank
--   IF @cUCCSKU = ''
--   BEGIN
--      SET @nErrNo = 60329
--      SET @cErrMsg = 'Need UCC SKU'
--      GOTO Fail
--   END
--
--   -- Validate UCC SKU
--   IF NOT EXISTS( SELECT 1
--      FROM dbo.SKU SKU (NOLOCK)
--      WHERE SKU.StorerKey = @cStorerKey
--         AND SKU.SKU = @cUCCSKU)
--   BEGIN
--      SET @nErrNo = 60330
--      SET @cErrMsg = 'Invalid SKU'
--      GOTO Fail
--   END
--
--   -- Get UCC's UOM
--   SELECT @cUCCUOM = CASE WHEN(IsNULL(Pack.PackUOM1,'') = '') THEN Pack.PackUOM3 ELSE Pack.PackUOM1 END
--      FROM dbo.Pack Pack (NOLOCK)
--      INNER JOIN dbo.SKU SKU (NOLOCK) ON Pack.PackKey = SKU.PackKey
--      WHERE SKU.StorerKey = @cStorerKey
--         AND SKU.SKU = @cUCCSKU
--END

-- Copy to common variable
SET @cSKU = CASE WHEN @cSKUCode <> '' THEN @cSKUCode ELSE @cUCCSKU END
SET @cUOM = CASE WHEN @cSKUCode <> '' THEN @cSKUUOM  ELSE @cUCCUOM END
SET @nQTY = CASE WHEN @cSKUCode <> '' THEN @nSKUQTY  ELSE @nUCCQTY END


/*-------------------------------------------------------------------------------

                            StorerConfig Setup

-------------------------------------------------------------------------------*/

-- Storer config 'Allow_OverReceipt'
EXECUTE dbo.nspGetRight
   NULL, -- Facility
   @cStorerKey,
   @cSKU,
   'Allow_OverReceipt',
   @bSuccess              OUTPUT,
   @cAllow_OverReceipt    OUTPUT,
   @nErrNo                OUTPUT,
   @cErrMsg               OUTPUT
IF @bSuccess <> 1
BEGIN
   SET @nErrNo = 60301
   SET @cErrMsg = 'nspGetRight'
   GOTO Fail
END

-- Storer config 'ByPassTolerance'
EXECUTE dbo.nspGetRight
   NULL, -- Facility
   @cStorerKey,
   NULL,
   'ByPassTolerance',
   @bSuccess            OUTPUT,
   @cByPassTolerance    OUTPUT,
   @nErrNo              OUTPUT,
   @cErrMsg             OUTPUT
IF @bSuccess <> 1
BEGIN
   SET @nErrNo = 60302
   SET @cErrMsg = 'nspGetRight'
   GOTO Fail
END


/*-------------------------------------------------------------------------------

                            ReceiptDetail lookup logic

-------------------------------------------------------------------------------*/
/*
   Steps:
   0. Check over receive
   1. Find exact match line
      1.1 Receive up to QtyExpected
      1.2 If have bal, borrow from other line, receive it
   2. If have bal, find blank line
      2.1 Receive up to QtyExpected
      2.2 If have bal, borrow from other line, receive it
   3. If have bal, add line
      3.1 borrow from other line, receive it

   NOTES: Should receive ALL UCC first before loose QTY
*/
DECLARE @c1stExactMatch_ReceiptLineNumber NVARCHAR( 5)
DECLARE @c1stBlank_ReceiptLineNumber      NVARCHAR( 5)
DECLARE @cReceiptLineNumber               NVARCHAR( 5)
DECLARE @cNewReceiptLineNumber            NVARCHAR( 5) 
DECLARE @cLottableSpecify                 NVARCHAR( 1)

DECLARE @nQty_Bal            INT
DECLARE @nLineBal            INT
DECLARE @nQtyExpected        INT
DECLARE @nBeforeReceivedQty  INT

DECLARE @nQtyExpected_Borrowed    INT
DECLARE @nQtyExpected_Total       INT
DECLARE @nBeforeReceivedQty_Total INT


DECLARE @cReceiptLineNumber_Borrowed NVARCHAR( 5)
DECLARE @cExternReceiptKey           NVARCHAR( 20),
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
        @cUserDefine01               VARCHAR( 30),
        @cUserDefine02               VARCHAR( 30),
        @cUserDefine03               VARCHAR( 30),
        @cUserDefine04               VARCHAR( 30),
        @cUserDefine05               VARCHAR( 30),
        @dtUserDefine06              DATETIME,
        @dtUserDefine07              DATETIME,
        @cUserDefine08               VARCHAR( 30),
        @cUserDefine09               VARCHAR( 30),
        @cUserDefine10               VARCHAR( 30),
        @cPoLineNo                   VARCHAR(  5),
        @cOrgPOKey                   NVARCHAR( 10)

-- ReceiptDetail candidate
DECLARE @tRD TABLE
(
   ReceiptLineNumber     NVARCHAR( 5),
   POLineNumber          NVARCHAR( 5),
   QtyExpected           INT,
   BeforeReceivedQty     INT,
   ToLOC                 NVARCHAR( 10),
   ToID                  NVARCHAR( 18),
   Lottable01            NVARCHAR( 18),
   Lottable02            NVARCHAR( 18),
   Lottable03            NVARCHAR( 18),
   Lottable04            DATETIME,
   Lottable06            NVARCHAR( 30),       --(CS01)
   Lottable07            NVARCHAR( 30),       --(CS01)
   Lottable08            NVARCHAR( 30),       --(CS01)
   Lottable09            NVARCHAR( 30),       --(CS01)
   Lottable10            NVARCHAR( 30),       --(CS01)
   Lottable11            NVARCHAR( 30),       --(CS01)
   Lottable12            NVARCHAR( 30),       --(CS01)
   Lottable13            DATETIME,            --(CS01) 
   Lottable14            DATETIME,            --(CS01)
   Lottable15            DATETIME,            --(CS01)
   FinalizeFlag          NVARCHAR( 1),
   Org_ReceiptLineNumber NVARCHAR( 5), -- Keeping original value, use in saving section
   Org_QtyExpected       INT,
   Org_BeforeReceivedQty INT,
   ReceiptLine_Borrowed  NVARCHAR( 5), -- Keep the linenumber of borrowed receiptline
   ExternReceiptKey      NVARCHAR( 20),
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
   UserDefine01          VARCHAR( 30),
   UserDefine02          VARCHAR( 30),
   UserDefine03          VARCHAR( 30),
   UserDefine04          VARCHAR( 30),
   UserDefine05          VARCHAR( 30),
   UserDefine06          DATETIME,
   UserDefine07          DATETIME,
   UserDefine08          VARCHAR( 30),
   UserDefine09          VARCHAR( 30),
   UserDefine10          VARCHAR( 30),
   POKey                 NVARCHAR( 10),
   UOM                   NVARCHAR( 10),
   EditDate              DATETIME  
)

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
   POKey             NVARCHAR( 10) 
)

-- Copy QTY to process
SET @nQty_Bal = @nQTY

-- Set lottable flag
IF @cLottable01 = '' AND
   @cLottable02 = '' AND
   @cLottable03 = '' AND
   @dLottable04 IS NULL AND
   @cLottable06 = '' AND
   @cLottable07 = '' AND
   @cLottable08 = '' AND
   @cLottable09 = '' AND
   @cLottable10 = '' AND
   @cLottable11 = '' AND
   @cLottable12 = '' AND
   @dLottable13 IS NULL AND
   @dLottable14 IS NULL AND
   @dLottable15 IS NULL
   SET @cLottableSpecify = '0' -- Not specify
ELSE
   SET @cLottableSpecify = '1' -- Specify


IF @nNOPOFlag = 1 ---without pokey 'NOPO'
BEGIN
   -- Get ReceiptDetail candidate
   INSERT INTO @tRD (ReceiptLineNumber, POLineNumber, QtyExpected, BeforeReceivedQty,
      ToLOC, ToID, Lottable01, Lottable02, Lottable03, Lottable04, --Lottable05,
      Lottable06, Lottable07, Lottable08, Lottable09,Lottable10, Lottable11, Lottable12, Lottable13,              --(CS01)
      Lottable14, Lottable15,                                                                                     --(CS01)
      FinalizeFlag, Org_ReceiptLineNumber, Org_QtyExpected, Org_BeforeReceivedQty, ReceiptLine_Borrowed, 
      ExternReceiptKey, ExternLineNo, AltSku, VesselKey,
      VoyageKey, XdockKey, ContainerKey, UnitPrice, ExtendedPrice,
      FreeGoodQtyExpected, FreeGoodQtyReceived, ExportStatus, LoadKey,
      ExternPoKey, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05,
      UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10, POKey, UOM, EditDate ) 
   SELECT ReceiptLineNumber, POLineNumber, QtyExpected, BeforeReceivedQty,
      ToLOC, ToID, 
      CASE WHEN @cSkipLottable01 = '1' THEN '' ELSE Lottable01 END, -- Lottable01,
      CASE WHEN @cSkipLottable02 = '1' THEN '' ELSE Lottable02 END, -- Lottable02,
      CASE WHEN @cSkipLottable03 = '1' THEN '' ELSE Lottable03 END, -- Lottable03,
      CASE WHEN @cSkipLottable04 = '1' THEN '' ELSE Lottable04 END, -- Lottable04,
      CASE WHEN @cSkipLottable06 = '1' THEN '' ELSE Lottable06 END, -- Lottable06,
      CASE WHEN @cSkipLottable07 = '1' THEN '' ELSE Lottable07 END, -- Lottable07,
      CASE WHEN @cSkipLottable08 = '1' THEN '' ELSE Lottable08 END, -- Lottable08,
      CASE WHEN @cSkipLottable09 = '1' THEN '' ELSE Lottable09 END, -- Lottable09,
      CASE WHEN @cSkipLottable10 = '1' THEN '' ELSE Lottable10 END, -- Lottable10,
      CASE WHEN @cSkipLottable11 = '1' THEN '' ELSE Lottable11 END, -- Lottable11,
      CASE WHEN @cSkipLottable12 = '1' THEN '' ELSE Lottable12 END, -- Lottable12,
      CASE WHEN @cSkipLottable13 = '1' THEN '' ELSE Lottable13 END, -- Lottable13,
      CASE WHEN @cSkipLottable14 = '1' THEN '' ELSE Lottable14 END, -- Lottable14,
      CASE WHEN @cSkipLottable15 = '1' THEN '' ELSE Lottable15 END, -- Lottable15,
      FinalizeFlag, ReceiptLineNumber, QtyExpected, BeforeReceivedQty, DuplicateFrom,  
      ExternReceiptKey, ExternLineNo, AltSku, VesselKey,
      VoyageKey, XdockKey, ContainerKey, UnitPrice, ExtendedPrice,
      FreeGoodQtyExpected, FreeGoodQtyReceived, ExportStatus, LoadKey,
      ExternPoKey, UserDefine01, 
      UserDefine02, UserDefine03, UserDefine04, UserDefine05,
      UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10, POKey, UOM , GetDate() 
   FROM dbo.ReceiptDetail (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey 
      AND StorerKey = @cStorerKey 
      AND SKU = @cSKU
END
ELSE
BEGIN
   -- Get ReceiptDetail candidate
   INSERT INTO @tRD (ReceiptLineNumber, POLineNumber, QtyExpected, BeforeReceivedQty,
      ToLOC, ToID, Lottable01, Lottable02, Lottable03, Lottable04, --Lottable05,
      Lottable06, Lottable07, Lottable08, Lottable09,Lottable10, Lottable11, Lottable12, Lottable13,              --(CS01)
      Lottable14, Lottable15,                                                                                     --(CS01)
      FinalizeFlag, Org_ReceiptLineNumber, Org_QtyExpected, Org_BeforeReceivedQty, ReceiptLine_Borrowed, 
      ExternReceiptKey, ExternLineNo, AltSku, VesselKey,
      VoyageKey, XdockKey, ContainerKey, UnitPrice, ExtendedPrice,
      FreeGoodQtyExpected, FreeGoodQtyReceived, ExportStatus, LoadKey,
      ExternPoKey, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05,
      UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10, POKey, UOM, EditDate ) 
   SELECT ReceiptLineNumber, POLineNumber, QtyExpected, BeforeReceivedQty,
      ToLOC, ToID, -- Lottable01, Lottable02, Lottable03, Lottable04, --Lottable05,
      CASE WHEN @cSkipLottable01 = '1' THEN '' ELSE Lottable01 END, -- Lottable01,
      CASE WHEN @cSkipLottable02 = '1' THEN '' ELSE Lottable02 END, -- Lottable02,
      CASE WHEN @cSkipLottable03 = '1' THEN '' ELSE Lottable03 END, -- Lottable03,
      CASE WHEN @cSkipLottable04 = '1' THEN '' ELSE Lottable04 END, -- Lottable04,
      CASE WHEN @cSkipLottable06 = '1' THEN '' ELSE Lottable06 END, -- Lottable06,
      CASE WHEN @cSkipLottable07 = '1' THEN '' ELSE Lottable07 END, -- Lottable07,
      CASE WHEN @cSkipLottable08 = '1' THEN '' ELSE Lottable08 END, -- Lottable08,
      CASE WHEN @cSkipLottable09 = '1' THEN '' ELSE Lottable09 END, -- Lottable09,
      CASE WHEN @cSkipLottable10 = '1' THEN '' ELSE Lottable10 END, -- Lottable10,
      CASE WHEN @cSkipLottable11 = '1' THEN '' ELSE Lottable11 END, -- Lottable11,
      CASE WHEN @cSkipLottable12 = '1' THEN '' ELSE Lottable12 END, -- Lottable12,
      CASE WHEN @cSkipLottable13 = '1' THEN '' ELSE Lottable13 END, -- Lottable13,
      CASE WHEN @cSkipLottable14 = '1' THEN '' ELSE Lottable14 END, -- Lottable14,
      CASE WHEN @cSkipLottable15 = '1' THEN '' ELSE Lottable15 END, -- Lottable15,
      FinalizeFlag, ReceiptLineNumber, QtyExpected, BeforeReceivedQty, DuplicateFrom,  
      ExternReceiptKey, ExternLineNo, AltSku, VesselKey,
      VoyageKey, XdockKey, ContainerKey, UnitPrice, ExtendedPrice,
      FreeGoodQtyExpected, FreeGoodQtyReceived, ExportStatus, LoadKey,
      ExternPoKey,  UserDefine01,
      UserDefine02, UserDefine03, UserDefine04, UserDefine05,
      UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10, POKey, UOM, GetDate() 
   FROM dbo.ReceiptDetail (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
      AND POKey = @cPOKey 
      AND StorerKey = @cStorerKey 
      AND SKU = @cSKU
      -- AND FinalizeFlag <> 'Y' -- We might need to borrow finalized ReceiptDetail line's QtyExpected
END

IF @@ERROR <> 0
BEGIN
   SET @nErrNo = 60338
   SET @cErrMsg = 'Get Receipt Detail Fail'
   GOTO Fail
END

DECLARE @nCnt INT

SELECT @nCnt = COUNT(*)
FROM @tRD

IF @nCnt = 0
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

-- Get total QtyExpected, BeforeReceivedQty
SELECT
   @nQtyExpected_Total = IsNULL( SUM( QtyExpected), 0),
   @nBeforeReceivedQty_Total = IsNULL( SUM( BeforeReceivedQty), 0)
FROM @tRD 

IF @cDocType = 'R' AND @cExternReceiptKey = '' AND @cOrgPOKey = ''
   GOTO Steps 

 --Check if over receive
IF (@nQty_Bal + @nBeforeReceivedQty_Total) > @nQtyExpected_Total
BEGIN
   IF @cAllow_OverReceipt = '0'
   BEGIN
      SET @nErrNo = 60339
      SET @cErrMsg = 'Over Received'
      GOTO Fail
   END
   ELSE
   -- Check if bypass tolerance
   IF @cByPassTolerance <> '1'
      -- Check if over tolerance %
      IF (@nQty_Bal + @nBeforeReceivedQty_Total) > (@nQtyExpected_Total * (1 + (@nTolerancePercentage * 0.01)))
      BEGIN
         SET @nErrNo = 60340
         SET @cErrMsg = 'QtyReceived Over Tolerance%'
         GOTO Fail
      END
END

--SET @cASNMatchByPOLineValue = RDTGetConfig( @nFunc, 'ASNMatchByPOLine', @cStorerKey) 
SET @cASNMatchByPOLineValue = '0'

IF @cDebug = '1'
BEGIN
   SELECT  @nQty_Bal 'STEP 1.1 @nQty_Bal' ,@nQTY '@nQTY'
END

Steps:
-- Steps
-- 1. Find exact match lines (could be more then 1 line)
--    1.1 Receive up to QtyExpected
SET @c1stExactMatch_ReceiptLineNumber = ''
SET @cReceiptLineNumber = ''
WHILE 1=1
BEGIN
   -- Get exact match line
   SELECT TOP 1
      @cReceiptLineNumber = ReceiptLineNumber,
      @nLineBal = (QtyExpected - BeforeReceivedQty),
      @cPOKey = POKey,
      @cExternLineNumber = ExternLineNo
   FROM @tRD
   WHERE FinalizeFlag <> 'Y'
      AND ToID = @cToID
      AND Lottable01 = @cLottable01
      AND Lottable02 = @cLottable02
      AND Lottable03 = @cLottable03
      AND IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0)
      AND Lottable06 = @cLottable06                         --(CS01)
      AND Lottable07 = @cLottable07                         --(CS01)
      AND Lottable08 = @cLottable08                         --(CS01)
      AND Lottable09 = @cLottable09                         --(CS01)
      AND Lottable10 = @cLottable10                         --(CS01)
      AND Lottable11 = @cLottable11                         --(CS01)
      AND Lottable12 = @cLottable12                         --(CS01)
      AND IsNULL( Lottable13, 0) = IsNULL( @dLottable13, 0) --(CS01)
      AND IsNULL( Lottable14, 0) = IsNULL( @dLottable14, 0) --(CS01)
      AND IsNULL( Lottable15, 0) = IsNULL( @dLottable15, 0) --(CS01)
      AND @cToLOC = ToLOC
      AND (QtyExpected - BeforeReceivedQty) > 0 
      AND ReceiptLineNumber > @cReceiptLineNumber 
      AND UserDefine01 = CASE WHEN @cAddUCCFromUDF01 = '1' AND ISNULL(RTRIM(@cUCC),'') <> '' THEN  ISNULL(RTRIM(@cUCC),'') ELSE UserDefine01 END
   ORDER BY ReceiptLineNumber

   -- Exit loop
   IF @@ROWCOUNT = 0 BREAK

   -- Remember 1st exact match ReceiptLineNumber (for section 1.2)
   IF @c1stExactMatch_ReceiptLineNumber = ''
      SET @c1stExactMatch_ReceiptLineNumber = @cReceiptLineNumber

   IF @nLineBal < 1 CONTINUE

   -- Calc QTY to receive
   IF @nQty_Bal >= @nLineBal
      SET @nQTY = @nLineBal
   ELSE
      SET @nQTY = @nQty_Bal

   -- Update ReceiptDetail
   IF @nLineBal >= @nUCCQTY -- UCC cannot receive into 2 ReceiptDetails
   BEGIN
      -- Update ReceiptDetail
      UPDATE @tRD SET
         BeforeReceivedQty = BeforeReceivedQty + @nQTY
      WHERE ReceiptLineNumber = @cReceiptLineNumber

      -- Update UCC
      IF @cUCC <> ''
      BEGIN
         IF @cIncludePOKeyFilter = '1' 
         BEGIN
            INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, POKey) 
            VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @cReceiptLineNumber,  @cPOKey) 
         END
         ELSE
         BEGIN
            INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, POKey) 
            VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @cReceiptLineNumber,  '') 
         END
      END

      -- Reduce balance
      SET @nQty_Bal = @nQty_Bal - @nQTY
   END
   -- Exit loop
   IF @cDebug = '1'
   BEGIN
      SELECT  @nQty_Bal 'STEP 1.1 @nQty_Bal After' , @nQTY '@nQTY'
   END

   IF @nQty_Bal = 0 BREAK
END

IF @cDebug = '1'
BEGIN
   SELECT  @nQty_Bal 'STEP 1.2 @nQty_Bal'
END

-- Step
-- 1.2 If have bal, borrow from other line
IF @nQty_Bal > 0 AND @c1stExactMatch_ReceiptLineNumber <> ''
BEGIN
   -- Reduce balance after taking-in its own QtyExpected
   SET @nBeforeReceivedQty = @nQty_Bal
   SELECT @nQty_Bal = @nQty_Bal - (QtyExpected - BeforeReceivedQty)
   FROM @tRD
   WHERE ReceiptLineNumber = @c1stExactMatch_ReceiptLineNumber
   AND (QtyExpected - BeforeReceivedQty) > 0

   -- Loop other ReceiptDetail
   SET @cReceiptLineNumber = ''
   WHILE 1=1
   BEGIN
      -- Get other line that has QtyExpected
      IF @cASNMatchByPOLineValue = '0' 
      BEGIN
         SELECT TOP 1
               @cReceiptLineNumber = ReceiptLineNumber,
               @nLineBal = (QtyExpected - BeforeReceivedQty)
         FROM @tRD
         WHERE (QtyExpected - BeforeReceivedQty) > 0
            AND ReceiptLineNumber <> @c1stExactMatch_ReceiptLineNumber
            AND ReceiptLineNumber > @cReceiptLineNumber
         ORDER BY ReceiptLineNumber
      END
      ELSE
      BEGIN
         SELECT TOP 1
                @cReceiptLineNumber = ReceiptLineNumber,
                @nLineBal = (QtyExpected - BeforeReceivedQty)
         FROM @tRD
         WHERE (QtyExpected - BeforeReceivedQty) > 0
            AND ReceiptLineNumber <> @c1stExactMatch_ReceiptLineNumber
            AND ReceiptLineNumber > @cReceiptLineNumber
            AND POKey = @cPOKey 
            AND ExternLineNo = @cExternLineNumber
         ORDER BY ReceiptLineNumber
      END

      -- Exit loop
      IF @@ROWCOUNT = 0 BREAK

      -- Calc QTY to receive
      IF @nQty_Bal >= @nLineBal
         SET @nQTY = @nLineBal
      ELSE
         SET @nQTY = @nQty_Bal

      -- Reduce borrowed ReceiptDetail QtyExpected
      UPDATE @tRD SET
            QtyExpected = QtyExpected - @nQTY
      WHERE ReceiptLineNumber = @cReceiptLineNumber

      -- Increase its own QtyExpected, and receive it
      UPDATE @tRD SET
            QtyExpected = QtyExpected + @nQTY
      WHERE ReceiptLineNumber = @c1stExactMatch_ReceiptLineNumber

      -- Reduce balance
      SET @nQty_Bal = @nQty_Bal - @nQTY

      -- Exit loop
      IF @nQty_Bal = 0 BREAK
   END

   -- update QtyExpected same as beforereceiveqty
   IF (@cASNMatchByPOLineValue = '0') OR (@cASNMatchByPOLineValue = '1' AND @@ROWCOUNT <> 0 ) 
   BEGIN
      IF @cDocType = 'R' AND @cExternReceiptKey = '' AND @cOrgPOKey = ''
      BEGIN
         UPDATE @tRD SET
               BeforeReceivedQty = BeforeReceivedQty + @nBeforeReceivedQty,
               QtyExpected = QtyExpected + @nBeforeReceivedQty,
               ToID = @cToID,
               ToLOC = @cToLOC,
               Lottable01 = @cLottable01,
               Lottable02 = @cLottable02,
               Lottable03 = @cLottable03,
               Lottable04 = @dLottable04, 
               Lottable06 = @cLottable06,      --(CS01)
               Lottable07 = @cLottable07,      --(CS01)
               Lottable08 = @cLottable08,      --(CS01)
               Lottable09 = @cLottable09,      --(CS01)
               Lottable10 = @cLottable10,      --(CS01)
               Lottable11 = @cLottable11,      --(CS01)
               Lottable12 = @cLottable12,      --(CS01)
               Lottable13 = @dLottable13,      --(CS01)
               Lottable14 = @dLottable14,      --(CS01)
               Lottable15 = @dLottable15,      --(CS01)  
               UserDefine01 = CASE WHEN @cAddUCCFromUDF01 = '1' AND ISNULL(RTRIM(@cUCC),'') <> '' THEN  ISNULL(RTRIM(@cUCC),'') ELSE UserDefine01 END
         WHERE ReceiptLineNumber = @c1stExactMatch_ReceiptLineNumber
      END
      ELSE
      BEGIN
         UPDATE @tRD SET
               BeforeReceivedQty = BeforeReceivedQty + @nBeforeReceivedQty,
               ToID = @cToID,
               ToLOC = @cToLOC,
               Lottable01 = @cLottable01,
               Lottable02 = @cLottable02,
               Lottable03 = @cLottable03,
               Lottable04 = @dLottable04, 
               Lottable06 = @cLottable06,      --(CS01)
               Lottable07 = @cLottable07,      --(CS01)
               Lottable08 = @cLottable08,      --(CS01)
               Lottable09 = @cLottable09,      --(CS01)
               Lottable10 = @cLottable10,      --(CS01)
               Lottable11 = @cLottable11,      --(CS01)
               Lottable12 = @cLottable12,      --(CS01)
               Lottable13 = @dLottable13,      --(CS01)
               Lottable14 = @dLottable14,      --(CS01)
               Lottable15 = @dLottable15,      --(CS01)  
               UserDefine01 = CASE WHEN @cAddUCCFromUDF01 = '1' AND ISNULL(RTRIM(@cUCC),'') <> '' THEN  ISNULL(RTRIM(@cUCC),'') ELSE UserDefine01 END
         WHERE ReceiptLineNumber = @c1stExactMatch_ReceiptLineNumber
      END

      -- Update UCC
      IF @cUCC <> ''
      BEGIN
         IF @cIncludePOKeyFilter = '1' 
         BEGIN
            INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, POKey) 
            VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @c1stExactMatch_ReceiptLineNumber, @cPOKey) 
         END
         ELSE
         BEGIN
            INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, POKey) 
            VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @c1stExactMatch_ReceiptLineNumber, '') 
         END
      END

      -- Reduce balance
      SET @nQty_Bal = 0
   END -- @cASNMatchByPOLineValue = 0
END

IF @cDebug = '1'
BEGIN
   SELECT  @nQty_Bal 'STEP 2.1 @nQty_Bal'
END

-- Step
-- 2. If have bal, find blank line
--    2.1 Receive up to QtyExpected
SET @c1stBlank_ReceiptLineNumber = ''
SET @cReceiptLineNumber = ''
WHILE @nQty_Bal > 0
BEGIN
   -- Get blank line
   SELECT TOP 1
      @cReceiptLineNumber = ReceiptLineNumber,
      @nLineBal = (QtyExpected - BeforeReceivedQty),
      @cPOKey = POKey
   FROM @tRD
   WHERE FinalizeFlag <> 'Y'
      AND BeforeReceivedQty = 0
      AND (ToID = '' OR ToID = @cToID)
      AND
      (  -- Blank lottable
         (Lottable01 = '' AND
          Lottable02 = '' AND
          Lottable03 = '' AND
          Lottable04 IS NULL AND
          Lottable06 = '' AND
          Lottable07 = '' AND
          Lottable08 = '' AND
          Lottable09 = '' AND
          Lottable10 = '' AND
          Lottable11 = '' AND 
          Lottable12 = '' AND 
          Lottable13 IS NULL AND
          Lottable14 IS NULL AND
          Lottable15 IS NULL)
         OR
         -- Exact match lottables
         (Lottable01 = @cLottable01 AND
          Lottable02 = @cLottable02 AND
          Lottable03 = @cLottable03 AND
          IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0) AND
          Lottable06 = @cLottable06 AND
          Lottable07 = @cLottable07 AND
          Lottable08 = @cLottable08 AND
          Lottable09 = @cLottable09 AND
          Lottable10 = @cLottable10 AND
          Lottable11 = @cLottable11 AND
          Lottable12 = @cLottable12 AND
          IsNULL( Lottable13, 0) = IsNULL( @dLottable13, 0) AND
          IsNULL( Lottable14, 0) = IsNULL( @dLottable14, 0) AND
          IsNULL( Lottable15, 0) = IsNULL( @dLottable15, 0)   
         )) AND
         (UserDefine01 = CASE WHEN @cAddUCCFromUDF01 = '1' AND ISNULL(RTRIM(@cUCC),'') <> '' 
                              THEN  ISNULL(RTRIM(@cUCC),'')
                         ELSE UserDefine01 
                         END OR UserDefine01 = '' OR UserDefine01 IS NULL) 
      AND QtyExpected > @nQty_Bal 
      AND ReceiptLineNumber > @cReceiptLineNumber
   ORDER BY ReceiptLineNumber

   -- Exit loop
   IF @@ROWCOUNT = 0 BREAK

   -- Remember 1st blank ReceiptLineNumber (for section 1.2)
   IF @c1stBlank_ReceiptLineNumber = ''
      SET @c1stBlank_ReceiptLineNumber = @cReceiptLineNumber

   IF @nLineBal < 1 CONTINUE

   -- Calc QTY to receive
   IF @nQty_Bal >= @nLineBal
      SET @nQTY = @nLineBal
   ELSE
      SET @nQTY = @nQty_Bal

   -- Update ReceiptDetail
   IF @nLineBal >= @nUCCQTY -- UCC cannot receive into 2 ReceiptDetails
   BEGIN
      -- Update ReceiptDetail
      UPDATE @tRD SET
            BeforeReceivedQty = BeforeReceivedQty + @nQTY,
            ToID = @cToID,
            ToLOC = @cToLOC,
            Lottable01 = @cLottable01,
            Lottable02 = @cLottable02,
            Lottable03 = @cLottable03,
            Lottable04 = @dLottable04,
            Lottable06 = @cLottable06,      --(CS01)
            Lottable07 = @cLottable07,      --(CS01)
            Lottable08 = @cLottable08,      --(CS01)
            Lottable09 = @cLottable09,      --(CS01)
            Lottable10 = @cLottable10,      --(CS01)
            Lottable11 = @cLottable11,      --(CS01)
            Lottable12 = @cLottable12,      --(CS01)
            Lottable13 = @dLottable13,      --(CS01)
            Lottable14 = @dLottable14,      --(CS01)
            Lottable15 = @dLottable15,      --(CS01)   
            UserDefine01 = CASE WHEN @cAddUCCFromUDF01 = '1' AND ISNULL(RTRIM(@cUCC),'') <> '' THEN  ISNULL(RTRIM(@cUCC),'') ELSE UserDefine01 END
      WHERE ReceiptLineNumber = @cReceiptLineNumber

      -- Update UCC
      IF @cUCC <> ''
      BEGIN
         IF @cIncludePOKeyFilter = '1' 
         BEGIN
            INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, POKey) 
            VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @cReceiptLineNumber, @cPOKey) 
         END
         ELSE
         BEGIN
            INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, POKey) 
            VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @cReceiptLineNumber, '') 
         END
      END

      -- Reduce balance
      SET @nQty_Bal = @nQty_Bal - @nQTY
   END
   -- Exit loop
   IF @nQty_Bal = 0 BREAK
END

IF @cDebug = '1'
BEGIN
   SELECT  @nQty_Bal 'STEP 2.2 @nQty_Bal'
END

-- Step
-- 2.2 If have bal, borrow from other line
IF @nQty_Bal > 0 AND @c1stBlank_ReceiptLineNumber <> ''
BEGIN
   -- Reduce balance after taking-in its own QtyExpected
   SET @nBeforeReceivedQty = @nQty_Bal
   SELECT @nQty_Bal = @nQty_Bal - (QtyExpected - BeforeReceivedQty)
   FROM @tRD
   WHERE ReceiptLineNumber = @c1stBlank_ReceiptLineNumber
   AND (QtyExpected - BeforeReceivedQty) > 0

   -- Loop other ReceiptDetail
   SET @cReceiptLineNumber = ''
   WHILE 1=1
   BEGIN
      -- Get other line that has QtyExpected
      IF @cASNMatchByPOLineValue = '0' 
      BEGIN
         SELECT TOP 1
            @cReceiptLineNumber = ReceiptLineNumber,
            @nLineBal = (QtyExpected - BeforeReceivedQty)
         FROM @tRD
         WHERE (QtyExpected - BeforeReceivedQty) > 0
            AND ReceiptLineNumber <> @c1stBlank_ReceiptLineNumber
            AND ReceiptLineNumber > @cReceiptLineNumber
         ORDER BY ReceiptLineNumber
      END
      ELSE
      BEGIN
         SELECT TOP 1
            @cReceiptLineNumber = ReceiptLineNumber,
            @nLineBal = (QtyExpected - BeforeReceivedQty)
         FROM @tRD
         WHERE (QtyExpected - BeforeReceivedQty) > 0
            AND ReceiptLineNumber <> @c1stBlank_ReceiptLineNumber
            AND ReceiptLineNumber > @cReceiptLineNumber
            AND POKey = @cPOKey 
            AND ExternLineNo = @cExternLineNumber
         ORDER BY ReceiptLineNumber
      END

      -- Exit loop
      IF @@ROWCOUNT = 0 BREAK

      -- Calc QTY to receive
      IF @nQty_Bal >= @nLineBal
         SET @nQTY = @nLineBal
      ELSE
         SET @nQTY = @nQty_Bal

      -- Reduce borrowed ReceiptDetail QtyExpected
      UPDATE @tRD SET
         QtyExpected = QtyExpected - @nQTY
      WHERE ReceiptLineNumber = @cReceiptLineNumber

      -- Increase its own QtyExpected, and receive it
      UPDATE @tRD SET
         QtyExpected = QtyExpected + @nQTY
      WHERE ReceiptLineNumber = @c1stBlank_ReceiptLineNumber

      -- Reduce balance
      SET @nQty_Bal = @nQty_Bal - @nQTY

      -- Exit loop
      IF @nQty_Bal = 0 BREAK
   END

   IF (@cASNMatchByPOLineValue = '0') OR (@cASNMatchByPOLineValue = '1' AND @@ROWCOUNT <> 0 ) 
   BEGIN
      -- Update ReceiptDetail -- SOS#112522
      IF @cDocType = 'R' AND @cExternReceiptKey = '' AND @cOrgPOKey = '' -- update QtyExpected same as beforereceiveqty
      BEGIN
         UPDATE @tRD SET
               BeforeReceivedQty = BeforeReceivedQty + @nBeforeReceivedQty,
               QtyExpected =  QtyExpected + @nBeforeReceivedQty,
               ToID = @cToID,
               ToLOC = @cToLOC,
               Lottable01 = @cLottable01,
               Lottable02 = @cLottable02,
               Lottable03 = @cLottable03,
               Lottable04 = @dLottable04, 
               Lottable06 = @cLottable06,      --(CS01)
               Lottable07 = @cLottable07,      --(CS01)
               Lottable08 = @cLottable08,      --(CS01)
               Lottable09 = @cLottable09,      --(CS01)
               Lottable10 = @cLottable10,      --(CS01)
               Lottable11 = @cLottable11,      --(CS01)
               Lottable12 = @cLottable12,      --(CS01)
               Lottable13 = @dLottable13,      --(CS01)
               Lottable14 = @dLottable14,      --(CS01)
               Lottable15 = @dLottable15,      --(CS01)  
               UserDefine01 = CASE WHEN @cAddUCCFromUDF01 = '1' AND ISNULL(RTRIM(@cUCC),'') <> '' THEN  ISNULL(RTRIM(@cUCC),'') ELSE UserDefine01 END
         WHERE ReceiptLineNumber = @c1stBlank_ReceiptLineNumber
      END
      ELSE
      BEGIN
         UPDATE @tRD SET
               BeforeReceivedQty = BeforeReceivedQty + @nBeforeReceivedQty,
               ToID = @cToID,
               ToLOC = @cToLOC,
               Lottable01 = @cLottable01,
               Lottable02 = @cLottable02,
               Lottable03 = @cLottable03,
               Lottable04 = @dLottable04, 
               Lottable06 = @cLottable06,      --(CS01)
               Lottable07 = @cLottable07,      --(CS01)
               Lottable08 = @cLottable08,      --(CS01)
               Lottable09 = @cLottable09,      --(CS01)
               Lottable10 = @cLottable10,      --(CS01)
               Lottable11 = @cLottable11,      --(CS01)
               Lottable12 = @cLottable12,      --(CS01)
               Lottable13 = @dLottable13,      --(CS01)
               Lottable14 = @dLottable14,      --(CS01)
               Lottable15 = @dLottable15,      --(CS01)  
               UserDefine01 = CASE WHEN @cAddUCCFromUDF01 = '1' AND ISNULL(RTRIM(@cUCC),'') <> '' THEN  ISNULL(RTRIM(@cUCC),'') ELSE UserDefine01 END
         WHERE ReceiptLineNumber = @c1stBlank_ReceiptLineNumber
      END

      -- Update UCC
      IF @cUCC <> ''
      BEGIN
         IF @cIncludePOKeyFilter = '1' 
         BEGIN
            INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, POKey) 
            VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @c1stBlank_ReceiptLineNumber, @cPOKey) 
         END
         ELSE
         BEGIN
            INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, POKey) 
            VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @c1stBlank_ReceiptLineNumber, '') 
         END
      END

      -- Reduce balance
      SET @nQty_Bal = 0
   END -- IF (@cASNMatchByPOLineValue = '0') OR (@cASNMatchByPOLineValue = '1' AND @@ROWCOUNT <> 0 ) 
END

IF @cDebug = '1'
BEGIN
   SELECT  @nQty_Bal 'STEP 2.3 @nQty_Bal'
END

-- Step -- Start (ChewKP01)
-- 2.3 Check if there is other line with  BeforeReceivedQty = 0
SET @c1stBlank_ReceiptLineNumber = ''
SET @cReceiptLineNumber = ''
WHILE @nQty_Bal > 0
BEGIN
   -- Get blank line
   SELECT TOP 1
      @cReceiptLineNumber = ReceiptLineNumber,
      @nLineBal = (QtyExpected - BeforeReceivedQty),
      @cPOKey = POKey
   FROM @tRD
   WHERE FinalizeFlag <> 'Y'
      AND BeforeReceivedQty = 0
      AND (ToID = '' OR ToID = @cToID)
      AND
      (  -- Blank lottable
         (Lottable01 = '' AND
          Lottable02 = '' AND
          Lottable03 = '' AND
          Lottable04 IS NULL AND
          Lottable06 = '' AND
          Lottable07 = '' AND
          Lottable08 = '' AND
          Lottable09 = '' AND
          Lottable10 = '' AND
          Lottable11 = '' AND 
          Lottable12 = '' AND 
          Lottable13 IS NULL AND
          Lottable14 IS NULL AND
          Lottable15 IS NULL)
         OR
         -- Exact match lottables
         (Lottable01 = @cLottable01 AND
          Lottable02 = @cLottable02 AND
          Lottable03 = @cLottable03 AND
          IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0) AND
          Lottable06 = @cLottable06 AND
          Lottable07 = @cLottable07 AND
          Lottable08 = @cLottable08 AND
          Lottable09 = @cLottable09 AND
          Lottable10 = @cLottable10 AND
          Lottable11 = @cLottable11 AND
          Lottable12 = @cLottable12 AND
          IsNULL( Lottable13, 0) = IsNULL( @dLottable13, 0) AND
          IsNULL( Lottable14, 0) = IsNULL( @dLottable14, 0) AND
          IsNULL( Lottable15, 0) = IsNULL( @dLottable15, 0) )
      ) AND
      (UserDefine01 = CASE WHEN @cAddUCCFromUDF01 = '1' AND ISNULL(RTRIM(@cUCC),'') <> '' 
                           THEN  ISNULL(RTRIM(@cUCC),'')
                      ELSE UserDefine01 
                      END OR UserDefine01 = '' OR UserDefine01 IS NULL) 
      AND ReceiptLineNumber > @cReceiptLineNumber
   ORDER BY ReceiptLineNumber

   -- Exit loop
   IF @@ROWCOUNT = 0 BREAK

   -- Remember 1st blank ReceiptLineNumber (for section 1.2)
   IF @c1stBlank_ReceiptLineNumber = ''
      SET @c1stBlank_ReceiptLineNumber = @cReceiptLineNumber

   IF @nLineBal < 1 CONTINUE

   -- Calc QTY to receive
   IF @nQty_Bal >= @nLineBal
      SET @nQTY = @nLineBal
   ELSE
      SET @nQTY = @nQty_Bal

   -- Update ReceiptDetail
   IF @nLineBal >= @nUCCQTY -- UCC cannot receive into 2 ReceiptDetails
   BEGIN
      -- Update ReceiptDetail
      UPDATE @tRD SET
            BeforeReceivedQty = BeforeReceivedQty + @nQTY,
            ToID = @cToID,
            ToLOC = @cToLOC,
            Lottable01 = @cLottable01,
            Lottable02 = @cLottable02,
            Lottable03 = @cLottable03,
            Lottable04 = @dLottable04,
            Lottable06 = @cLottable06,      --(CS01)
            Lottable07 = @cLottable07,      --(CS01)
            Lottable08 = @cLottable08,      --(CS01)
            Lottable09 = @cLottable09,      --(CS01)
            Lottable10 = @cLottable10,      --(CS01)
            Lottable11 = @cLottable11,      --(CS01)
            Lottable12 = @cLottable12,      --(CS01)
            Lottable13 = @dLottable13,      --(CS01)
            Lottable14 = @dLottable14,      --(CS01)
            Lottable15 = @dLottable15,      --(CS01)  
            UserDefine01 = CASE WHEN @cAddUCCFromUDF01 = '1' AND ISNULL(RTRIM(@cUCC),'') <> '' THEN  ISNULL(RTRIM(@cUCC),'') ELSE UserDefine01 END
      WHERE ReceiptLineNumber = @cReceiptLineNumber

      -- Update UCC
      IF @cUCC <> ''
      BEGIN
         IF @cIncludePOKeyFilter = '1' 
         BEGIN
            INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, POKey) 
            VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @cReceiptLineNumber, @cPOKey) 
         END
         ELSE
         BEGIN
            INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, POKey) 
            VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @cReceiptLineNumber, '') 
         END
      END

      -- Reduce balance
      SET @nQty_Bal = @nQty_Bal - @nQTY
   END
   -- Exit loop
   IF @nQty_Bal = 0 BREAK
END
-- Step -- End (ChewKP01)

IF @cDebug = '1'
BEGIN
   SELECT  @nQty_Bal 'STEP 3.1 @nQty_Bal'
END

-- Step 3.1 If there is overreceived , receive the qty to the over received line.
SET @cReceiptLineNumber = ''
IF @nQty_Bal > 0
BEGIN
   IF @cPOKey = '' 
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
         AND Lottable06 = @cLottable06                         --(CS01)
         AND Lottable07 = @cLottable07                         --(CS01)
         AND Lottable08 = @cLottable08                         --(CS01)
         AND Lottable09 = @cLottable09                         --(CS01)
         AND Lottable10 = @cLottable10                         --(CS01)
         AND Lottable11 = @cLottable11                         --(CS01)
         AND Lottable12 = @cLottable12                         --(CS01)
         AND IsNULL( Lottable13, 0) = IsNULL( @dLottable13, 0) --(CS01)
         AND IsNULL( Lottable14, 0) = IsNULL( @dLottable14, 0) --(CS01)
         AND IsNULL( Lottable15, 0) = IsNULL( @dLottable15, 0) --(CS01)  
         AND ToLOC  = @cToLOC 
         AND UserDefine01 = CASE WHEN @cAddUCCFromUDF01 = '1' AND ISNULL(RTRIM(@cUCC),'') <> '' 
                            THEN  ISNULL(RTRIM(@cUCC),'') ELSE UserDefine01 
                            END
      ORDER BY ReceiptLineNumber
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
         AND Lottable06 = @cLottable06                         --(CS01)
         AND Lottable07 = @cLottable07                         --(CS01)
         AND Lottable08 = @cLottable08                         --(CS01)
         AND Lottable09 = @cLottable09                         --(CS01)
         AND Lottable10 = @cLottable10                         --(CS01)
         AND Lottable11 = @cLottable11                         --(CS01)
         AND Lottable12 = @cLottable12                         --(CS01)
         AND IsNULL( Lottable13, 0) = IsNULL( @dLottable13, 0) --(CS01)
         AND IsNULL( Lottable14, 0) = IsNULL( @dLottable14, 0) --(CS01)
         AND IsNULL( Lottable15, 0) = IsNULL( @dLottable15, 0) --(CS01)
         AND @cToLOC = ToLOC
         AND POKey = @cPokey
         AND UserDefine01 = CASE WHEN @cAddUCCFromUDF01 = '1' AND ISNULL(RTRIM(@cUCC),'') <> '' 
                            THEN  ISNULL(RTRIM(@cUCC),'') ELSE UserDefine01 
                            END         
      ORDER BY ReceiptLineNumber
   END

   IF @@RowCount <> 0
   BEGIN
      UPDATE @tRD SET
      BeforeReceivedQty = BeforeReceivedQty + @nQty_Bal
      WHERE ReceiptLineNumber = @cReceiptLineNumber

      SET @nQty_Bal = 0
   END
END

IF @cDebug = '1'
BEGIN
   SELECT  @nQty_Bal 'STEP 3.1.1 @nQty_Bal'
END

-- Step 3.1.1 Over receive to matching line without adding a new ReceiptDetail line 
--IF RDTGetConfig( @nFunc, 'OverReceiptToMatchLine', @cStorerKey) = '1'
--BEGIN
--   
--   SET @cReceiptLineNumber = ''
--   
--   IF @nQty_Bal > 0 
--   BEGIN
--      SELECT TOP 1
--         @cReceiptLineNumber = ReceiptLineNumber,
--         @cPOKey = POKey,
--         @cExternLineNumber = ExternLineNo
--      FROM @tRD
--      WHERE FinalizeFlag <> 'Y'
--         AND (ToID = '' OR ToID = @cToID)
--         AND
--         (  -- Blank lottable
--            (Lottable01 = '' AND
--             Lottable02 = '' AND
--             Lottable03 = '' AND
--             Lottable04 IS NULL)
--            OR
--            -- Exact match lottables
--            (Lottable01 = @cLottable01 AND
--             Lottable02 = @cLottable02 AND
--             Lottable03 = @cLottable03 AND
--             IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0))
--         )
--         AND ReceiptLineNumber > @cReceiptLineNumber
--      ORDER BY ReceiptLineNumber
--      
--      
--      IF @@ROWCOUNT <> 0 
--      BEGIN
--         UPDATE @tRD SET
--         BeforeReceivedQty = BeforeReceivedQty + @nQty_Bal
--         WHERE ReceiptLineNumber = @cReceiptLineNumber
--   
--         -- Reduce balance
--         SET @nQty_Bal = 0
--      END         
--   END
--END


IF @cDebug = '1'
BEGIN
   SELECT  @nQty_Bal 'STEP 3.2 @nQty_Bal'
END

-- Step 3.2 Over receive it (by adding new ReceiptDetail line)
SET @nBeforeReceivedQty = @nQty_Bal
SET @cNewReceiptLineNumber = '' 
IF @nQty_Bal > 0
BEGIN
   -- Loop all ReceiptDetail to borrow QtyExpected
   SET @cReceiptLineNumber = ''
   SET @nQtyExpected_Borrowed = 0
   WHILE 1=1
   BEGIN
      -- Get lines that has balance
      SELECT TOP 1
            @cReceiptLineNumber = ReceiptLineNumber,
            @nLineBal = (QtyExpected - BeforeReceivedQty)
      FROM @tRD
      WHERE (QtyExpected - BeforeReceivedQty) > 0
      AND ReceiptLineNumber > @cReceiptLineNumber
      ORDER BY ReceiptLineNumber

      -- Exit loop
      IF @@ROWCOUNT = 0 BREAK

      
      SET @cReceiptLineNumber_Borrowed = @cReceiptLineNumber

      -- Calc QTY to receive
      IF @nQty_Bal >= @nLineBal
         SET @nQTY = @nLineBal
      ELSE
         SET @nQTY = @nQty_Bal

      IF @cDebug = '1'
      BEGIN
         SELECT @cReceiptLineNumber '@cReceiptLineNumber' , @nLineBal '@nLineBal' , @nQTY '@nQTY' , @nQty_Bal '@nQty_Bal'
      END

      -- Reduce borrowed ReceiptDetail QtyExpected
      UPDATE @tRD SET
         QtyExpected = QtyExpected - @nQTY
      WHERE ReceiptLineNumber = @cReceiptLineNumber

      -- Reduce balance
      SET @nQty_Bal = @nQty_Bal - @nQTY

      -- Remember borrowed QtyExpected
      SET @nQtyExpected_Borrowed = 0 
      SET @nQtyExpected_Borrowed = @nQtyExpected_Borrowed + @nQTY

       -- Revised Logic Start --
      -- Get Temp next ReceiptLineNumber
      SELECT @cNewReceiptLineNumber =
         RIGHT( '00000' + CAST( CAST( IsNULL( MAX( ReceiptLineNumber), 0) AS INT) + 1 AS VARCHAR( 5)), 5)
      FROM @tRD --WITH (NOLOCK) 

      -- Balance insert as new ReceiptDetail line
      -- To Cater Return without Receiptlines
      IF @cDocType = 'R' AND @cExternReceiptKey = '' AND @cOrgPOKey = ''
      BEGIN
         INSERT INTO @tRD
            (ReceiptLineNumber, POLineNumber, QtyExpected, BeforeReceivedQty, ToID, ToLOC,
            Lottable01, Lottable02, Lottable03, Lottable04,Lottable06, Lottable07, Lottable08, Lottable09,      --(CS01)
            Lottable10, Lottable11, Lottable12, Lottable13,Lottable14, Lottable15,                              --(CS01) 
            FinalizeFlag, ExternReceiptkey, Org_ReceiptLinenumber, Org_QtyExpected,
            Org_BeforeReceivedQty, ReceiptLine_Borrowed, EditDate,
            UserDefine01 ) 
         VALUES
         (  @cNewReceiptLineNumber, '', @nQTY, @nQTY, @cToID, @cToLOC,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04,
            @cLottable06, @cLottable07, @cLottable08, 
            @cLottable09, @cLottable10, @cLottable11,@cLottable12,
             @dLottable13,@dLottable14, @dLottable15, 
            'N', '', '', 0, 0, @cReceiptLineNumber_Borrowed, GetDate(),
            CASE WHEN @cAddUCCFromUDF01 = '1' AND ISNULL(RTRIM(@cUCC),'') <> '' 
                 THEN  ISNULL(RTRIM(@cUCC),'') ELSE '' 
            END  )  
      END
      ELSE
      BEGIN
         IF @cDebug = '1'
         BEGIN
            SELECT @nQty_Bal '@nQty_Bal', @nQTY '@nQTY', @nQtyExpected_Borrowed '@nQtyExpected_Borrowed', @nBeforeReceivedQty '@nBeforeReceivedQty' , @cReceiptLineNumber_Borrowed '@cReceiptLineNumber_Borrowed'
         END

         -- Only create new line when Inserted record not from @cReceiptLineNumber_Borrowed
         SET @cBorrowed_OriginalReceiptLineNumber = ''

         SELECT @cBorrowed_OriginalReceiptLineNumber = ReceiptLineNumber
         FROM @tRD
         WHERE ReceiptLine_Borrowed = @cReceiptLineNumber_Borrowed
         AND ToID = @cToID
         AND Lottable01 = @cLottable01
         AND Lottable02 = @cLottable02
         AND Lottable03 = @cLottable03
         AND IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0) 
         AND Lottable06 = @cLottable06                         --(CS01)
         AND Lottable07 = @cLottable07                         --(CS01)
         AND Lottable08 = @cLottable08                         --(CS01)
         AND Lottable09 = @cLottable09                         --(CS01)
         AND Lottable10 = @cLottable10                         --(CS01)
         AND Lottable11 = @cLottable11                         --(CS01)
         AND Lottable12 = @cLottable12                         --(CS01)
         AND IsNULL( Lottable13, 0) = IsNULL( @dLottable13, 0) --(CS01)
         AND IsNULL( Lottable14, 0) = IsNULL( @dLottable14, 0) --(CS01)
         AND IsNULL( Lottable15, 0) = IsNULL( @dLottable15, 0) --(CS01)
         AND UserDefine01 = CASE WHEN @cAddUCCFromUDF01 = '1' AND ISNULL(RTRIM(@cUCC),'') <> '' 
                            THEN  ISNULL(RTRIM(@cUCC),'') ELSE UserDefine01 
                            END
         AND @cToLOC = ToLOC

         IF @cBorrowed_OriginalReceiptLineNumber = ''
         BEGIN
            INSERT INTO @tRD
               (ReceiptLineNumber, POLineNumber, QtyExpected, BeforeReceivedQty, ToID, ToLOC,
               Lottable01, Lottable02, Lottable03, Lottable04, 
               Lottable06, Lottable07, Lottable08, Lottable09,      --(CS01)
                Lottable10, Lottable11, Lottable12, Lottable13,Lottable14, Lottable15,                              --(CS01)	
               FinalizeFlag, Org_ReceiptLineNumber, Org_QtyExpected, Org_BeforeReceivedQty, 
               ReceiptLine_Borrowed, EditDate, UserDefine01) 
            VALUES
               (@cNewReceiptLineNumber, '', @nQtyExpected_Borrowed, @nQTY, @cToID, @cToLOC,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04,
               @cLottable06, @cLottable07, @cLottable08, 
               @cLottable09, @cLottable10, @cLottable11,@cLottable12,
               @dLottable13,@dLottable14, @dLottable15,                
               'N', '', 0, 0, @cReceiptLineNumber_Borrowed, GetDate(),
               CASE WHEN @cAddUCCFromUDF01 = '1' AND ISNULL(RTRIM(@cUCC),'') <> '' 
                    THEN  ISNULL(RTRIM(@cUCC),'') ELSE '' 
               END) 
         END
         ELSE
         BEGIN
            UPDATE @tRD SET
                BeforeReceivedQty = BeforeReceivedQty + @nQTY
               ,QtyExpected = QtyExpected + @nQTY
            WHERE ReceiptLineNumber = @cBorrowed_OriginalReceiptLineNumber
            AND ToID = @cToID
            AND Lottable01 = @cLottable01
            AND Lottable02 = @cLottable02
            AND Lottable03 = @cLottable03
            AND IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0) 
            AND Lottable06 = @cLottable06                         --(CS01)
            AND Lottable07 = @cLottable07                         --(CS01)
            AND Lottable08 = @cLottable08                         --(CS01)
            AND Lottable09 = @cLottable09                         --(CS01)
            AND Lottable10 = @cLottable10                         --(CS01)
            AND Lottable11 = @cLottable11                         --(CS01)
            AND Lottable12 = @cLottable12                         --(CS01)
            AND IsNULL( Lottable13, 0) = IsNULL( @dLottable13, 0) --(CS01)
            AND IsNULL( Lottable14, 0) = IsNULL( @dLottable14, 0) --(CS01)
            AND IsNULL( Lottable15, 0) = IsNULL( @dLottable15, 0) --(CS01)

            AND ToLOC = @cToLOC 
            AND UserDefine01 = CASE WHEN @cAddUCCFromUDF01 = '1' AND ISNULL(RTRIM(@cUCC),'') <> '' 
                                    THEN  ISNULL(RTRIM(@cUCC),'') ELSE UserDefine01 
                               END

         END
      END

      -- Update UCC
      IF @cUCC <> ''
      BEGIN
         IF @cIncludePOKeyFilter = '1' 
         BEGIN
            INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, POKey) 
            VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @cNewReceiptLineNumber, @cPOKey) 
         END
         ELSE
         BEGIN
            INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, POKey) 
            VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @cNewReceiptLineNumber, '') 
         END
      END

      -- Exit loop
      IF @nQty_Bal = 0 BREAK
   END -- End While

   IF @nQty_Bal > 0  -- If There is no Match line from ReceiptDetail , Add a new Record 
   BEGIN
      -- Get Temp next ReceiptLineNumber
      SELECT @cNewReceiptLineNumber =
      RIGHT( '00000' + CAST( CAST( IsNULL( MAX( ReceiptLineNumber), 0) AS INT) + 1 AS VARCHAR( 5)), 5)
      FROM @tRD 

      -- Balance insert as new ReceiptDetail line
      -- To Cater Return without Receiptlines
      IF @cDocType = 'R' AND @cExternReceiptKey = '' AND @cOrgPOKey = ''
      BEGIN
         INSERT INTO @tRD
            (ReceiptLineNumber, POLineNumber, QtyExpected, BeforeReceivedQty, ToID, ToLOC,
            Lottable01, Lottable02, Lottable03, Lottable04, 
            Lottable06, Lottable07, Lottable08, Lottable09,      --(CS01)
            Lottable10, Lottable11, Lottable12, Lottable13,Lottable14, Lottable15,                              --(CS01)	
            FinalizeFlag, ExternReceiptkey, Org_ReceiptLineNumber, Org_QtyExpected,
            Org_BeforeReceivedQty, ReceiptLine_Borrowed, EditDate, UserDefine01 ) 
         VALUES
            (@cNewReceiptLineNumber, '', 0, @nQty_Bal, @cToID, @cToLOC,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, 
            @cLottable06, @cLottable07, @cLottable08, 
            @cLottable09, @cLottable10, @cLottable11,@cLottable12,
             @dLottable13,@dLottable14, @dLottable15, 	
            'N', '', '', 0, 0, @cReceiptLineNumber_Borrowed, GetDate(),
            CASE WHEN @cAddUCCFromUDF01 = '1' AND ISNULL(RTRIM(@cUCC),'') <> '' 
                  THEN  ISNULL(RTRIM(@cUCC),'') ELSE '' 
            END) 
      END
      ELSE
      BEGIN
         IF @cDebug = '1'
         BEGIN
            SELECT @nQty_Bal '@nQty_Bal', @nQTY '@nQTY', @nQtyExpected_Borrowed '@nQtyExpected_Borrowed', @nBeforeReceivedQty '@nBeforeReceivedQty'
         END

         INSERT INTO @tRD
            (ReceiptLineNumber, POLineNumber, QtyExpected, BeforeReceivedQty, ToID, ToLOC,
            Lottable01, Lottable02, Lottable03, Lottable04, 
            Lottable06, Lottable07, Lottable08, Lottable09,      --(CS01)
            Lottable10, Lottable11, Lottable12, Lottable13,Lottable14, Lottable15,                              --(CS01)	
            FinalizeFlag, Org_ReceiptLineNumber, Org_QtyExpected, Org_BeforeReceivedQty, 
            ReceiptLine_Borrowed, EditDate, UserDefine01) 
         VALUES
            (@cNewReceiptLineNumber, '', 0, @nQty_Bal, @cToID, @cToLOC,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, 
            @cLottable06, @cLottable07, @cLottable08, 
            @cLottable09, @cLottable10, @cLottable11,@cLottable12,
             @dLottable13,@dLottable14, @dLottable15, 	
            'N', '', 0, 0, @cReceiptLineNumber_Borrowed, GetDate(),
            CASE WHEN @cAddUCCFromUDF01 = '1' AND ISNULL(RTRIM(@cUCC),'') <> '' 
                  THEN  ISNULL(RTRIM(@cUCC),'') ELSE '' 
            END ) 
      END

      -- Update UCC
      IF @cUCC <> ''
      BEGIN
         IF @cIncludePOKeyFilter = '1' 
         BEGIN
            INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, POKey) 
            VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @cNewReceiptLineNumber, @cPOKey) 
         END
         ELSE
         BEGIN
            INSERT INTO @tUCC (StorerKey, UCCNo, Status, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, POKey) 
            VALUES ( @cStorerKey, @cUCC, @cUCCStatus, @nUCCQTY, @cToLOC, @cToID, @cReceiptKey, @cNewReceiptLineNumber, '') 
         END
      END
      -- Reduce balance to zero (for calculation error checking below)
      SET @nQty_Bal = @nBeforeReceivedQty - @nQtyExpected_Borrowed - @nQty_Bal
   END
END

-- If still have balance, means offset has error
IF @nQty_Bal <> 0
BEGIN
   SET @nErrNo = 60341
   SET @cErrMsg = 'Offset Receipt Detail Error'
   GOTO Fail
END

/*-------------------------------------------------------------------------------

                              Write to ReceiptDetail

-------------------------------------------------------------------------------*/
Saving:

IF @cDebug = '1'
BEGIN
   SELECT
         Org_ReceiptLineNumber, ReceiptLineNumber,
         Org_QtyExpected, QtyExpected,
         Org_BeforeReceivedQty, BeforeReceivedQty,
         ToID, ToLOC, Lottable01, Lottable02, Lottable03, Lottable04, 
         Lottable06, Lottable07, Lottable08, Lottable09,Lottable10,
         Lottable11, Lottable12, Lottable13, Lottable14,Lottable15,   
         ReceiptLine_Borrowed, UserDefine01
      FROM @tRD
    WHERE QtyExpected <> Org_QtyExpected
      OR BeforeReceivedQty <> Org_BeforeReceivedQty      
END
-- Handling transaction
SET @nTranCount = @@TRANCOUNT
BEGIN TRAN  -- Begin our own transaction
SAVE TRAN isp_PostPieceReceiving -- For rollback or commit only our own transaction

DECLARE @cOrg_ReceiptLineNumber NVARCHAR( 5)
DECLARE @nOrg_QtyExpected       INT
DECLARE @nOrg_BeforeReceivedQty INT
DECLARE @cReceiptLineNo_Borrowed  NVARCHAR( 5) 

-- Loop changed ReceiptDetail
DECLARE @curRD CURSOR
SET @curRD = CURSOR FOR
   SELECT
      Org_ReceiptLineNumber, ReceiptLineNumber,
      Org_QtyExpected,       QtyExpected,
      Org_BeforeReceivedQty, BeforeReceivedQty,
      ToID, ToLOC, Lottable01, Lottable02, Lottable03, Lottable04,  
      Lottable06, Lottable07, Lottable08, Lottable09,Lottable10,
      Lottable11, Lottable12, Lottable13, Lottable14,Lottable15, 
      ReceiptLine_Borrowed, UserDefine01 
   FROM @tRD
   WHERE QtyExpected <> Org_QtyExpected
      OR BeforeReceivedQty <> Org_BeforeReceivedQty
OPEN @curRD
FETCH NEXT FROM @curRD INTO
      @cOrg_ReceiptLineNumber, @cReceiptLineNumber,
      @nOrg_QtyExpected, @nQtyExpected,
      @nOrg_BeforeReceivedQty, @nBeforeReceivedQty,
      @cToID, @cToLOC, @cLottable01, @cLottable02, @cLottable03, @dLottable04, 
      @cLottable06, @cLottable07, @cLottable08,@cLottable09, @cLottable10, @cLottable11,  --(CS01)
      @cLottable12,@dLottable13,@dLottable14,@dLottable15 ,                                --(CS01)  
      @cReceiptLineNo_Borrowed, @cUserDefine01 

WHILE @@FETCH_STATUS = 0
BEGIN
   IF @cOrg_ReceiptLineNumber = ''
   BEGIN
      -- Get data from line borrowed to insert to new line
      -- SET @cDuplicateFromMatchValue = RDTGetConfig( @nFunc, 'DuplicateFromMatchValue', @cStorerKey) 
      SET @cDuplicateFromMatchValue = '0'

      IF @cDuplicateFromMatchValue = '1' 
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
                  --@cUserDefine01        = UserDefine01       ,
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
                  @cUOM                 = UOM
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
         --SET @cUserDefine01 = ''
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
                  @cPOKey               = POKey              , 
                  --@cUserDefine01        = UserDefine01       ,
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
                  @cUOM                 = UOM
         FROM @tRD
         WHERE ReceiptLineNumber = @cReceiptLineNo_Borrowed
      END

      SET @cNewReceiptLineNumber = ''
      SELECT @cNewReceiptLineNumber =
      RIGHT( '00000' + CAST( CAST( IsNULL( MAX( ReceiptLineNumber), 0) AS INT) + 1 AS VARCHAR( 5)), 5)
      FROM dbo.ReceiptDetail (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey

      -- Insert new ReceiptDetail line
      INSERT INTO dbo.ReceiptDetail
         (ReceiptKey, ReceiptLineNumber, POKey, StorerKey, SKU, QtyExpected, BeforeReceivedQty,
         ToID, ToLOC, Lottable01, Lottable02, Lottable03, Lottable04, 
         Lottable06, Lottable07, Lottable08, Lottable09,      --(CS01)
            Lottable10, Lottable11, Lottable12, Lottable13,Lottable14, Lottable15,                              --(CS01)	 
         Status, DateReceived, UOM, PackKey, ConditionCode, EffectiveDate, TariffKey, FinalizeFlag, SplitPalletFlag,
         ExternReceiptKey, ExternLineNo, AltSku, VesselKey, 
         VoyageKey, XdockKey, ContainerKey, UnitPrice, ExtendedPrice, FreeGoodQtyExpected,
         FreeGoodQtyReceived, ExportStatus, LoadKey, ExternPoKey,
         UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05,
         UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10, POLineNumber, SubReasonCode, DuplicateFrom) 
      SELECT
         @cReceiptKey, @cNewReceiptLineNumber, @cPOKey, @cStorerKey, @cSKU, @nQtyExpected, @nBeforeReceivedQty,  
         @cToID, @cToLOC, @cLottable01, @cLottable02, @cLottable03, @dLottable04, 
         @cLottable06, @cLottable07, @cLottable08, 
         @cLottable09, @cLottable10, @cLottable11,@cLottable12,
         @dLottable13,@dLottable14, @dLottable15, 	
         '0', GETDATE(), @cUOM, @cPackKey, @cConditionCode, GETDATE(), @cTariffKey, 'N', 'N',
         ISNULL(@cExternReceiptKey,''), ISNULL(@cExternLineNo, ''), ISNULL(@cAltSku, ''), ISNULL(@cVesselKey,''), 
         ISNULL(@cVoyageKey, ''), ISNULL(@cXdockKey, ''), ISNULL(@cContainerKey, ''), ISNULL(@nUnitPrice, 0), ISNULL(@nExtendedPrice, 0), ISNULL(@nFreeGoodQtyExpected, 0),
         ISNULL(@nFreeGoodQtyReceived, 0), ISNULL(@cExportStatus, '0'), @cLoadKey, @cExternPoKey,
         ISNULL(@cUserDefine01, ''), ISNULL(@cUserDefine02, ''), ISNULL(@cUserDefine03, ''), ISNULL(@cUserDefine04, ''), ISNULL(@cUserDefine05, ''),
         @dtUserDefine06, @dtUserDefine07, ISNULL(@cUserDefine08, ''), ISNULL(@cUserDefine09, ''), ISNULL(@cUserDefine10, ''),
         ISNULL(@cPoLineNo, ''), @cSubreasonCode , @cReceiptLineNo_Borrowed 
      FROM @tRD
      WHERE ReceiptLineNumber = @cReceiptLineNumber

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 60342
         SET @cErrMsg = 'Insert Receipt Detail Fail'
         GOTO RollBackTran
      END

      IF ISNULL(RTRIM(@cNewReceiptLineNumber),'') <> '' AND ISNULL(RTRIM(@cUCC),'') <> ''-- SOS# 249945
      BEGIN
         UPDATE @tUCC
         SET ReceiptLineNumber = @cNewReceiptLineNumber
         WHERE StorerKey = @cStorerKey
         AND ReceiptKey = @cReceiptKey
         AND UCCNo = @cUCC
         AND Id = @cToID
      END
   END
   ELSE
   BEGIN
      SET @cNewReceiptLineNumber = '' 
      -- Check if other process had updated ReceiptDetail
      DECLARE @cChkQtyExpected INT
      DECLARE @cChkBeforeReceivedQty INT

      SELECT
         @cChkQtyExpected = QtyExpected,
         @cChkBeforeReceivedQty = BeforeReceivedQty
      FROM dbo.ReceiptDetail (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND ReceiptLineNumber = @cReceiptLineNumber

      -- Check if ReceiptDetail deleted
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 60343
         SET @cErrMsg = 'Receipt Detail Not Found'
         GOTO RollBackTran
      END

      -- Check if ReceiptDetail changed
      IF @cChkQtyExpected <> @nOrg_QtyExpected OR
         @cChkBeforeReceivedQty <> @nOrg_BeforeReceivedQty
      BEGIN
         SET @nErrNo = 60344
         SET @cErrMsg = 'Receipt Detail Changed'
         GOTO RollBackTran
      END

      -- Update ReceiptDetail
      UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET
         QtyExpected = @nQtyExpected,
         BeforeReceivedQty = @nBeforeReceivedQty,
         ToID = @cToID,
         ToLOC = @cToLOC,
         Lottable01 = CASE WHEN @cSkipLottable01 = '1' THEN Lottable01 ELSE @cLottable01 END,
         Lottable02 = CASE WHEN @cSkipLottable02 = '1' THEN Lottable02 ELSE @cLottable02 END,
         Lottable03 = CASE WHEN @cSkipLottable03 = '1' THEN Lottable03 ELSE @cLottable03 END,
         Lottable04 = CASE WHEN @cSkipLottable04 = '1' THEN Lottable04 ELSE @dLottable04 END,
         Lottable06 = CASE WHEN @cSkipLottable06 = '1' THEN Lottable06 ELSE @cLottable06 END,
         Lottable07 = CASE WHEN @cSkipLottable07 = '1' THEN Lottable07 ELSE @cLottable07 END,
         Lottable08 = CASE WHEN @cSkipLottable08 = '1' THEN Lottable08 ELSE @cLottable08 END,
         Lottable09 = CASE WHEN @cSkipLottable09 = '1' THEN Lottable09 ELSE @cLottable09 END,
         Lottable10 = CASE WHEN @cSkipLottable10 = '1' THEN Lottable10 ELSE @cLottable10 END,
         Lottable11 = CASE WHEN @cSkipLottable11 = '1' THEN Lottable11 ELSE @cLottable11 END,
         Lottable12 = CASE WHEN @cSkipLottable12 = '1' THEN Lottable12 ELSE @cLottable12 END,
         Lottable13 = CASE WHEN @cSkipLottable13 = '1' THEN Lottable13 ELSE @dLottable13 END, 
         Lottable14 = CASE WHEN @cSkipLottable14 = '1' THEN Lottable14 ELSE @dLottable14 END,
         Lottable15 = CASE WHEN @cSkipLottable15 = '1' THEN Lottable15 ELSE @dLottable15 END, 
         ConditionCode = @cConditionCode,
         SubreasonCode = @cSubreasonCode, 
         UserDefine01 = @cUserDefine01 
      WHERE ReceiptKey = @cReceiptKey
         AND ReceiptLineNumber = @cReceiptLineNumber

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 60345
         SET @cErrMsg = 'Update Receipt Detail Fail'
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
   END

   FETCH NEXT FROM @curRD INTO
         @cOrg_ReceiptLineNumber, @cReceiptLineNumber,
         @nOrg_QtyExpected, @nQtyExpected,
         @nOrg_BeforeReceivedQty, @nBeforeReceivedQty,
         @cToID, @cToLOC, @cLottable01, @cLottable02, @cLottable03, @dLottable04, 
         @cLottable06, @cLottable07, @cLottable08,@cLottable09, @cLottable10, @cLottable11,  --(CS01)
         @cLottable12,@dLottable13,@dLottable14,@dLottable15 ,                                --(CS01)  
         @cReceiptLineNo_Borrowed, @cUserDefine01  
END

-- Loop changed UCC
--DECLARE @cUCCNo NVARCHAR( 20)
--DECLARE @curUCC CURSOR
--
--IF @cIncludePOKeyFilter = '1' 
--BEGIN
--   SET @curUCC = CURSOR FOR
--      SELECT UCCNo, ReceiptKey, ReceiptLineNumber, QTY, ID, LOC, POKey
--      FROM @tUCC
--      
--   OPEN @curUCC
--   FETCH NEXT FROM @curUCC INTO @cUCCNo, @cReceiptKey, @cReceiptLineNumber, @nQTY, @cToID, @cToLOC, @cUCCPOkey 
--   WHILE @@FETCH_STATUS = 0
--   BEGIN
--      IF EXISTS( SELECT 1
--         FROM dbo.UCC (NOLOCK)
--         WHERE StorerKey = @cStorerKey
--            AND UCCNo = @cUCC
--            AND Status = @cUCCStatus
--            AND LEFT(ISNULL(Sourcekey, ''),10) = @cUCCPOkey) 
--      BEGIN
--         -- Update UCC
--         UPDATE dbo.UCC WITH (ROWLOCK) SET
--            ID = @cToID,
--            LOC = @cToLOC,
--            QTY = @nQTY,
--            Status = '1', --1=Received
--            ReceiptKey = @cReceiptKey,
--            ReceiptLineNumber = @cReceiptLineNumber
--         WHERE StorerKey = @cStorerKey
--            AND UCCNo = @cUCC
--            AND Status = @cUCCStatus
--            AND LEFT(ISNULL(Sourcekey, ''),10) = @cUCCPOkey 
--         IF @@ERROR <> 0
--         BEGIN
--            SET @nErrNo = 60346
--            SET @cErrMsg = 'Update UCC Fail'
--            GOTO RollBackTran
--         END
--      END 
--      ELSE
--      BEGIN
--         -- Insert UCC
--         INSERT INTO dbo.UCC (StorerKey, UCCNo, Status, SKU, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, ExternKey)
--         VALUES (@cStorerKey, @cUCCNo, '1', @cSKU, @nQTY, @cToLOC, @cToID, @cReceiptKey, @cReceiptLineNumber, '')
--         IF @@ERROR <> 0
--         BEGIN
--            SET @nErrNo = 60347
--            SET @cErrMsg = 'Insert UCC Fail'
--            GOTO RollBackTran
--         END
--      END
--         FETCH NEXT FROM @curUCC INTO @cUCCNo, @cReceiptKey, @cReceiptLineNumber, @nQTY, @cToID, @cToLOC, @cUCCPOkey 
--   END
--   CLOSE @curUCC
--   DEALLOCATE @curUCC
--END
--ELSE
--BEGIN
--   SET @curUCC = CURSOR FOR
--      SELECT UCCNo, ReceiptKey, ReceiptLineNumber, QTY, ID, LOC
--      FROM @tUCC
--   OPEN @curUCC
--   FETCH NEXT FROM @curUCC INTO @cUCCNo, @cReceiptKey, @cReceiptLineNumber, @nQTY, @cToID, @cToLOC
--   WHILE @@FETCH_STATUS = 0
--   BEGIN
--      IF EXISTS( SELECT 1
--         FROM dbo.UCC (NOLOCK)
--         WHERE StorerKey = @cStorerKey
--            AND UCCNo = @cUCC
--            AND Status = @cUCCStatus)
--      BEGIN
--         -- Update UCC
--         UPDATE dbo.UCC WITH (ROWLOCK) SET
--            ID = @cToID,
--            LOC = @cToLOC,
--            QTY = @nQTY,
--            Status = '1', --1=Received
--            ReceiptKey = @cReceiptKey,
--            ReceiptLineNumber = @cReceiptLineNumber
--         WHERE StorerKey = @cStorerKey
--            AND UCCNo = @cUCC
--            AND Status = @cUCCStatus
--         IF @@ERROR <> 0
--         BEGIN
--            SET @nErrNo = 60346
--            SET @cErrMsg = 'Update UCC Failed'
--            GOTO RollBackTran
--         END
--      END
--      ELSE
--      BEGIN
--         -- Insert UCC
--         INSERT INTO dbo.UCC (StorerKey, UCCNo, Status, SKU, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, ExternKey)
--         VALUES (@cStorerKey, @cUCCNo, '1', @cSKU, @nQTY, @cToLOC, @cToID, @cReceiptKey, @cReceiptLineNumber, '')
--         IF @@ERROR <> 0
--         BEGIN
--            SET @nErrNo = 60347
--            SET @cErrMsg = 'Insert UCC Failed'
--            GOTO RollBackTran
--         END
--      END
--      FETCH NEXT FROM @curUCC INTO @cUCCNo, @cReceiptKey, @cReceiptLineNumber, @nQTY, @cToID, @cToLOC
--   END
--   CLOSE @curUCC
--   DEALLOCATE @curUCC
--END

-- Auto finalize upon receive
--IF RDTGetConfig( 0, 'RDT_NotFinalizeReceiptDetail', @cStorerKey) <> '1'  -- 1=Not finalize
--BEGIN
--   -- Bulk update (so that trigger fire only once, compare with row update that fire trigger each time)
--   UPDATE dbo.ReceiptDetail SET
--      QTYReceived = RD.BeforeReceivedQty,
--      FinalizeFlag = 'Y'
--   FROM dbo.ReceiptDetail RD
--      INNER JOIN @tRD T ON (T.ReceiptLineNumber = RD.ReceiptLineNumber)
--   WHERE RD.ReceiptKey = @cReceiptKey
--      AND T.BeforeReceivedQty <> T.Org_BeforeReceivedQty
--   IF @@ERROR <> 0
--   BEGIN
--      SET @nErrNo = 60348
--      SET @cErrMsg = 'Finalize Fail'
--      GOTO RollBackTran
--   END
--END

COMMIT TRAN isp_PostPieceReceiving -- Only commit change made in here
GOTO Quit

RollBackTran:
   ROLLBACK TRAN isp_PostPieceReceiving
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

GO