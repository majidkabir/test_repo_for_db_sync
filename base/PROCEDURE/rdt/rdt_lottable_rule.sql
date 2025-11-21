SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Lottable_Rule                                   */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Dynamic lottable                                            */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 08-10-2014  1.0  Ung         SOS317571. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_Lottable_Rule]
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nInputKey     INT,
   @cStorerKey    NVARCHAR( 15),
   @cSKU          NVARCHAR( 20),
   @cLottableCode NVARCHAR( 30), 
   @nLottableNo   INT,
   @cLottable     NVARCHAR( 30), 
   @cType         NVARCHAR( 10),  -- PRE/POST
   @cLottable01   NVARCHAR( 60) OUTPUT,
   @cLottable02   NVARCHAR( 60) OUTPUT,
   @cLottable03   NVARCHAR( 60) OUTPUT,
   @dLottable04   DATETIME      OUTPUT,
   @dLottable05   DATETIME      OUTPUT,
   @cLottable06   NVARCHAR( 60) OUTPUT,
   @cLottable07   NVARCHAR( 60) OUTPUT,
   @cLottable08   NVARCHAR( 60) OUTPUT,
   @cLottable09   NVARCHAR( 60) OUTPUT,
   @cLottable10   NVARCHAR( 60) OUTPUT,
   @cLottable11   NVARCHAR( 60) OUTPUT,
   @cLottable12   NVARCHAR( 60) OUTPUT,
   @dLottable13   DATETIME      OUTPUT,
   @dLottable14   DATETIME      OUTPUT,
   @dLottable15   DATETIME      OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT,
   @cSourceKey    NVARCHAR( 15),
   @cSourceType   NVARCHAR( 20)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess	   INT
   DECLARE @cListName   NVARCHAR( 10)
   DECLARE @cLabel      NVARCHAR( 20)
   DECLARE @cProcessSP  NVARCHAR( 250)
   DECLARE @nRDTProcess INT

   DECLARE @cTempLottable01 NVARCHAR( 18)
   DECLARE @cTempLottable02 NVARCHAR( 18)
   DECLARE @cTempLottable03 NVARCHAR( 18)
   DECLARE @dTempLottable04 DATETIME
   DECLARE @dTempLottable05 DATETIME
   DECLARE @cTempLottable06 NVARCHAR( 30)
   DECLARE @cTempLottable07 NVARCHAR( 30)
   DECLARE @cTempLottable08 NVARCHAR( 30)
   DECLARE @cTempLottable09 NVARCHAR( 30)
   DECLARE @cTempLottable10 NVARCHAR( 30)
   DECLARE @cTempLottable11 NVARCHAR( 30)
   DECLARE @cTempLottable12 NVARCHAR( 30)
   DECLARE @dTempLottable13 DATETIME
   DECLARE @dTempLottable14 DATETIME
   DECLARE @dTempLottable15 DATETIME
   
   -- Get ListName
   SET @cListName = 'LOTTABLE' + RIGHT( '0' + CAST( @nLottableNo AS NVARCHAR(2)), 2)

   -- Get lottable stored procedure
   SET @cProcessSP = ''
   
/*
         -- Get PRE store procedure
         SELECT TOP 1
            @cShort = C.Short,
            @cProcessSP = IsNULL( C.Long, ''),
            @cLottableLabel = S.SValue
         FROM dbo.CodeLkUp C WITH (NOLOCK)
            JOIN RDT.StorerConfig S WITH (NOLOCK)ON C.ListName = S.ConfigKey
         WHERE C.ListName = @cListName
            AND C.Code = S.SValue
            AND S.Storerkey = @cStorerKey -- NOTE: storer level
            AND (C.StorerKey = @cStorerKey OR C.StorerKey = '')
         ORDER BY C.StorerKey DESC
*/
   -- Get RDT stored procedure
   SELECT @cProcessSP = ProcessSP
   FROM rdt.rdtLottableCode WITH (NOLOCK)
   WHERE LottableCode = @cLottableCode
      AND LottableNo = @nLottableNo
      AND Function_ID = @nFunc
      AND StorerKey = @cStorerKey
      AND (ProcessType = @cType OR ProcessType = 'BOTH')

   IF @cProcessSP = ''
   BEGIN
      -- Get SKU lottable label
      SELECT 
         @cLabel = 
            CASE @nLottableNo 
               WHEN 1  THEN Lottable01Label
               WHEN 2  THEN Lottable02Label
               WHEN 3  THEN Lottable03Label
               WHEN 4  THEN Lottable04Label
               WHEN 5  THEN Lottable05Label
               WHEN 6  THEN Lottable06Label
               WHEN 7  THEN Lottable07Label
               WHEN 8  THEN Lottable08Label
               WHEN 9  THEN Lottable09Label
               WHEN 10 THEN Lottable10Label
               WHEN 11 THEN Lottable11Label
               WHEN 12 THEN Lottable12Label
               WHEN 13 THEN Lottable13Label
               WHEN 14 THEN Lottable14Label
               WHEN 15 THEN Lottable15Label
               ELSE '' 
            END
      FROM SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
      
      -- Get Exceed stored procedure
      IF @cLabel <> ''
         SELECT TOP 1
            @cProcessSP = ISNULL( RTRIM( Long), '')
         FROM dbo.Codelkup WITH (NOLOCK)
         WHERE ListName = @cListName
            AND Code = @cLabel
            AND (Short = @cType OR Short = 'BOTH')
            AND (StorerKey = @cStorerKey OR StorerKey = '')
         ORDER BY StorerKey DESC

      SET @nRDTProcess = 0    -- Exceed process
   END
   ELSE
      SET @nRDTProcess = 1    -- RDT process


   -- Lottable store procedure
   IF @cProcessSP <> ''
   BEGIN
      -- Backup to temp lottables
      SET @cTempLottable01 = @cLottable01
      SET @cTempLottable02 = @cLottable02
      SET @cTempLottable03 = @cLottable03
      SET @dTempLottable04 = @dLottable04
      SET @dTempLottable05 = @dLottable05
      SET @cTempLottable06 = @cLottable06
      SET @cTempLottable07 = @cLottable07
      SET @cTempLottable08 = @cLottable08
      SET @cTempLottable09 = @cLottable09
      SET @cTempLottable10 = @cLottable10
      SET @cTempLottable11 = @cLottable11
      SET @cTempLottable12 = @cLottable12
      SET @dTempLottable13 = @dLottable13
      SET @dTempLottable14 = @dLottable14
      SET @dTempLottable15 = @dLottable15
      
      IF @nRDTProcess = 1
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cProcessSP AND type = 'P')
         BEGIN
            DECLARE @cSQL NVARCHAR(MAX)
            DECLARE @cSQLParam NVARCHAR(MAX)
            
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cProcessSP) +
               ' @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, @nLottableNo, @cLottable, @cType, @cSourceKey, ' +  
               ' @cLottable01Value,   @cLottable02Value,   @cLottable03Value,   @dLottable04Value,   @dLottable05Value,   ' + 
               ' @cLottable06Value,   @cLottable07Value,   @cLottable08Value,   @cLottable09Value,   @cLottable10Value,   ' + 
               ' @cLottable11Value,   @cLottable12Value,   @dLottable13Value,   @dLottable14Value,   @dLottable15Value,   ' + 
               ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT, ' + 
               ' @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT, ' +  
               ' @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile          INT,           ' +
               '@nFunc            INT,           ' +
               '@cLangCode        NVARCHAR( 3),  ' +
               '@nInputKey        INT,           ' +
               '@cStorerKey       NVARCHAR( 15), ' +
               '@cSKU             NVARCHAR( 20), ' +
               '@cLottableCode    NVARCHAR( 30), ' + 
               '@nLottableNo      INT,           ' +
               '@cLottable        NVARCHAR( 30), ' + 
               '@cType            NVARCHAR( 10), ' + 
               '@cSourceKey       NVARCHAR( 15), ' + 
               '@cLottable01Value NVARCHAR( 18), ' +
               '@cLottable02Value NVARCHAR( 18), ' +
               '@cLottable03Value NVARCHAR( 18), ' +
               '@dLottable04Value DATETIME,      ' +
               '@dLottable05Value DATETIME,      ' +
               '@cLottable06Value NVARCHAR( 30), ' +
               '@cLottable07Value NVARCHAR( 30), ' +
               '@cLottable08Value NVARCHAR( 30), ' +
               '@cLottable09Value NVARCHAR( 30), ' +
               '@cLottable10Value NVARCHAR( 30), ' +
               '@cLottable11Value NVARCHAR( 30), ' +
               '@cLottable12Value NVARCHAR( 30), ' +
               '@dLottable13Value DATETIME,      ' +
               '@dLottable14Value DATETIME,      ' +
               '@dLottable15Value DATETIME,      ' +
               '@cLottable01      NVARCHAR( 18) OUTPUT, ' +
               '@cLottable02      NVARCHAR( 18) OUTPUT, ' +
               '@cLottable03      NVARCHAR( 18) OUTPUT, ' +
               '@dLottable04      DATETIME      OUTPUT, ' +
               '@dLottable05      DATETIME      OUTPUT, ' +
               '@cLottable06      NVARCHAR( 30) OUTPUT, ' +
               '@cLottable07      NVARCHAR( 30) OUTPUT, ' +
               '@cLottable08      NVARCHAR( 30) OUTPUT, ' +
               '@cLottable09      NVARCHAR( 30) OUTPUT, ' +
               '@cLottable10      NVARCHAR( 30) OUTPUT, ' +
               '@cLottable11      NVARCHAR( 30) OUTPUT, ' +
               '@cLottable12      NVARCHAR( 30) OUTPUT, ' +
               '@dLottable13      DATETIME      OUTPUT, ' +
               '@dLottable14      DATETIME      OUTPUT, ' +
               '@dLottable15      DATETIME      OUTPUT, ' +
               '@nErrNo           INT           OUTPUT, ' +
               '@cErrMsg          NVARCHAR( 20) OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, @nLottableNo, @cLottable, @cType, @cSourceKey, 
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,   
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,   
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,   
               @cTempLottable01 OUTPUT, @cTempLottable02 OUTPUT, @cTempLottable03 OUTPUT, @dTempLottable04 OUTPUT, @dTempLottable05 OUTPUT, 
               @cTempLottable06 OUTPUT, @cTempLottable07 OUTPUT, @cTempLottable08 OUTPUT, @cTempLottable09 OUTPUT, @cTempLottable10 OUTPUT,  
               @cTempLottable11 OUTPUT, @cTempLottable12 OUTPUT, @dTempLottable13 OUTPUT, @dTempLottable14 OUTPUT, @dTempLottable15 OUTPUT, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT
         END
      END
      ELSE
         EXEC dbo.ispLottableRule_Wrapper
            @c_SPName            = @cProcessSP,
            @c_ListName          = @cListName,
            @c_StorerKey         = @cStorerKey,
            @c_SKU               = @cSKU,
            @c_LottableLabel     = @cLabel,
            @c_Lottable01Value   = @cLottable01,
            @c_Lottable02Value   = @cLottable02,
            @c_Lottable03Value   = @cLottable03,
            @dt_Lottable04Value  = @dLottable04,
            @dt_Lottable05Value  = @dLottable05,
            @c_Lottable06Value   = @cLottable06,
            @c_Lottable07Value   = @cLottable07,
            @c_Lottable08Value   = @cLottable08,
            @c_Lottable09Value   = @cLottable09,
            @c_Lottable10Value   = @cLottable10,
            @c_Lottable11Value   = @cLottable11,
            @c_Lottable12Value   = @cLottable12,
            @dt_Lottable13Value  = @dLottable13,
            @dt_Lottable14Value  = @dLottable14,
            @dt_Lottable15Value  = @dLottable15,
            @c_Lottable01        = @cTempLottable01 OUTPUT,
            @c_Lottable02        = @cTempLottable02 OUTPUT,
            @c_Lottable03        = @cTempLottable03 OUTPUT,
            @dt_Lottable04       = @dTempLottable04 OUTPUT,
            @dt_Lottable05       = @dTempLottable05 OUTPUT,
            @c_Lottable06        = @cTempLottable06 OUTPUT,
            @c_Lottable07        = @cTempLottable07 OUTPUT,
            @c_Lottable08        = @cTempLottable08 OUTPUT,
            @c_Lottable09        = @cTempLottable09 OUTPUT,
            @c_Lottable10        = @cTempLottable10 OUTPUT,
            @c_Lottable11        = @cTempLottable11 OUTPUT,
            @c_Lottable12        = @cTempLottable12 OUTPUT,
            @dt_Lottable13       = @dTempLottable13 OUTPUT,
            @dt_Lottable14       = @dTempLottable14 OUTPUT,
            @dt_Lottable15       = @dTempLottable15 OUTPUT,
            @b_Success           = @bSuccess        OUTPUT,
            @n_Err               = @nErrNo          OUTPUT,
            @c_ErrMsg            = @cErrMsg         OUTPUT,
            @c_SourceKey         = @cSourceKey,
            @c_SourceType        = @cSourceType, 
            @c_Type              = @cType
      
      IF @nErrNo <> 0 AND
         @nErrNo <> -1     -- Retain in current screen
         GOTO Quit

      -- Save processed lottable
      SET @cLottable01 = @cTempLottable01
      SET @cLottable02 = @cTempLottable02
      SET @cLottable03 = @cTempLottable03
      SET @dLottable04 = @dTempLottable04
      SET @dLottable05 = @dTempLottable05
      SET @cLottable06 = @cTempLottable06
      SET @cLottable07 = @cTempLottable07
      SET @cLottable08 = @cTempLottable08
      SET @cLottable09 = @cTempLottable09
      SET @cLottable10 = @cTempLottable10
      SET @cLottable11 = @cTempLottable11
      SET @cLottable12 = @cTempLottable12
      SET @dLottable13 = @dTempLottable13
      SET @dLottable14 = @dTempLottable14
      SET @dLottable15 = @dTempLottable15
   END

Quit:

END -- End Procedure


GO