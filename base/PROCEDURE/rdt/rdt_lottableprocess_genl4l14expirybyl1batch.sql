SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LottableProcess_GenL4L14ExpiryByL1Batch         */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Key-inYYMM, default DD                                      */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 17-11-2015  1.0  Ung         SOS356692. Created                      */
/* 11-02-2019  1.1  ChewKP      WMS-7928                                */
/* 09-12-2019  1.2  YeeKung     WMS-11326.  (yeekung01)                 */
/* 09-03-2020  1.3  YeeKung     WMS-12345 Batchcode Decoding (yeekung02)*/
/* 12-06-2020  1.4  YeeKung     WMS-13546 Add New Batch (yeekung03)     */
/* 2020-10-15  1.5  Chermaine   WMS-15454 not able decode condition (cc01)*/
/* 17-11-2020  1.6  YeeKung     WMS-15690 Add New Batch (yeekung04)     */
/* 2021-06-20  1.7  YeeKung     WMS-16535 Add New Batch (yeekung05)     */
/* 2022-02-14  1.8  Ung         WMS-18866 Add new batch, UDF3=SP name   */
/* 2022-08-18  1.9  Ung         WMS-20429 Add remain at lottable screen */
/*                              if L04 changes                          */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_LottableProcess_GenL4L14ExpiryByL1Batch]
    @nMobile          INT
   ,@nFunc            INT
   ,@cLangCode        NVARCHAR( 3)
   ,@nInputKey        INT
   ,@cStorerKey       NVARCHAR( 15)
   ,@cSKU             NVARCHAR( 20)
   ,@cLottableCode    NVARCHAR( 30)
   ,@nLottableNo      INT
   ,@cLottable        NVARCHAR( 30)
   ,@cType            NVARCHAR( 10)
   ,@cSourceKey       NVARCHAR( 15)
   ,@cLottable01Value NVARCHAR( 18)
   ,@cLottable02Value NVARCHAR( 18)
   ,@cLottable03Value NVARCHAR( 18)
   ,@dLottable04Value DATETIME
   ,@dLottable05Value DATETIME
   ,@cLottable06Value NVARCHAR( 30)
   ,@cLottable07Value NVARCHAR( 30)
   ,@cLottable08Value NVARCHAR( 30)
   ,@cLottable09Value NVARCHAR( 30)
   ,@cLottable10Value NVARCHAR( 30)
   ,@cLottable11Value NVARCHAR( 30)
   ,@cLottable12Value NVARCHAR( 30)
   ,@dLottable13Value DATETIME
   ,@dLottable14Value DATETIME
   ,@dLottable15Value DATETIME
   ,@cLottable01      NVARCHAR( 18) OUTPUT
   ,@cLottable02      NVARCHAR( 18) OUTPUT
   ,@cLottable03      NVARCHAR( 18) OUTPUT
   ,@dLottable04      DATETIME      OUTPUT
   ,@dLottable05      DATETIME      OUTPUT
   ,@cLottable06      NVARCHAR( 30) OUTPUT
   ,@cLottable07      NVARCHAR( 30) OUTPUT
   ,@cLottable08      NVARCHAR( 30) OUTPUT
   ,@cLottable09      NVARCHAR( 30) OUTPUT
   ,@cLottable10      NVARCHAR( 30) OUTPUT
   ,@cLottable11      NVARCHAR( 30) OUTPUT
   ,@cLottable12      NVARCHAR( 30) OUTPUT
   ,@dLottable13      DATETIME      OUTPUT
   ,@dLottable14      DATETIME      OUTPUT
   ,@dLottable15      DATETIME      OUTPUT
   ,@nErrNo           INT           OUTPUT
   ,@cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL        NVARCHAR(MAX)
   DECLARE @cSQLParam   NVARCHAR(MAX)

   DECLARE @cYearCode   NVARCHAR(5)
   DECLARE @cMonthCode  NVARCHAR(5)
   DECLARE @nShelfLife  INT
   DECLARE @cYear       NVARCHAR(10)
   DECLARE @cMonth      NVARCHAR(2)
   DECLARE @cExpDate    NVARCHAR(20)

   DECLARE @cSKUDay INT
   DECLARE @cSKUDay2    INT   --(cc01)
   DECLARE @cConDay INT
   DECLARE @cConExpDay  INT    --(cc01)
   DECLARE @cFormatSP NVARCHAR(20)
   DECLARE @cLottableValue NVARCHAR(20)
   --PRINT @cLottable + '??????'
   DECLARE @cBusr6 NVARCHAR(60)


   DECLARE @cDisplayErr NVARCHAR( 1)   --(cc01)
   DECLARE @b_success   INT            --(cc01)
   DECLARE @n_err       INT            --(cc01)
   DECLARE @c_errmsg    NVARCHAR( 200) --(cc01)

   SET @cYear = ''
   SET @cMonth = ''
   SET @cDisplayErr = '0'   --(cc01)

   SELECT @cSKUDay= SUSR1
     ,@cSKUDay2= SUSR2 --(cc01)
   FROM SKU (NOLOCK)
   WHERE SKU=@cSKU
      AND ISNULL(SUSR1,'')<>''
      AND STORERKEY=@cStorerKey

   DECLARE @cLastLottable03 NVARCHAR( 18),
           @cLastLottable14 DATETIME,
           @cLastLottable04 DATETIME

   SELECT @cLastLottable03 = I_Field06,
          @cLastLottable14 = V_Lottable14,
          @cLastLottable04 = V_Lottable04
    FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   -- Get SKU info
   SELECT @nShelfLife = ShelfLife FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU

   SET @cLottableValue=  @cLottable


   IF  (SUBSTRING(@cLottable,1,2)='ZZ')  AND @nFUNC=600 --(yeekung04)
   BEGIN
      SET @cLottable01= SUBSTRING(@cLottable,3,len(@cLottable)-2) --(yeekung01)
      -- Default to current date
      SET @dLottable14 = CONVERT( DATETIME, CONVERT( NVARCHAR(10), GETDATE(), 103), 103) --DD/MM/YYYY
      SET @dLottable04 = @dLottable14

      -- Add shelf life
      IF @nShelfLife > 0
         SET @dLottable04 = DATEADD( dd, @nShelfLife, @dLottable14)

       SET @dLottable05= CONVERT( DATETIME, CONVERT( NVARCHAR(10), GETDATE(), 103), 103)
       SET @cLottable12 ='11'
       GOTO Quit
   END

   --SOLVE ZZ ISSUE invalid batch
   IF ISNULL(@cLottable12,'') <>''
   BEGIN

      SET @cConDay=datediff(dayofyear,getdate(),@cLastLottable14)
      SET @cConExpDay = DATEDIFF(dayofyear,getdate(),@cLastLottable04)

      IF (@cConDay <0)
         SET @cConDay =(-@cConDay)

      IF ((@cConDay>@cSKUDay) AND  @cLastLottable03 ='OK') AND @nFunc = '600'
      BEGIN
         SET @nErrNo = 58319
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid date
         GOTO Quit
      END
      --(cc01)
      ELSE IF ((@cConExpDay<@cSKUDay2) AND  @cLastLottable03 IN ('OK','OK-RTN','PER-Tag')) AND @nFunc = '608'
      BEGIN
       SET @nErrNo = 58319
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid date
         SET @cDisplayErr = '1'
         GOTO Quit
      END
      --ELSE IF ((@cConExpDay>@cSKUDay2) AND  @cLastLottable03 NOT IN ('OK','OK-RTN','PER-Tag')) AND @nFunc = '608' --(cc01)
      --BEGIN
      --   SET @nErrNo = 58319
      --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid date
      --END
      ELSE
      BEGIN
         SET @nErrNo = 0
         SET @cLottable12 =' '
         GOTO QUIT
      END
   END

   SELECT @cBusr6=BUSR6 FROM SKU WITH (NOLOCK)
   WHERE Storerkey=@cStorerKey
   AND SKU=@cSKU

   DECLARE @cSP NVARCHAR( 60) = ''
   SELECT @cSP = UDF03
   FROM dbo.CodeLKUP WITH (NOLOCK)
   WHERE listname ='PRESTBRAND'
      AND StorerKey = @cStorerKey
      AND Long = @cBusr6

   IF @cSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cSP) +
            ' @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cSKU, ' +
            ' @cLottableCode, @nLottableNo, @cFormatSP, @cLottableValue, ' +
            ' @cLottable OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            ' @nMobile         INT,           ' +
            ' @nFunc           INT,           ' +
            ' @cLangCode       NVARCHAR( 3),  ' +
            ' @nInputKey       INT,           ' +
            ' @cStorerKey      NVARCHAR( 15), ' +
            ' @cSKU            NVARCHAR( 20), ' +
            ' @cLottableCode   NVARCHAR( 30), ' +
            ' @nLottableNo     INT,           ' +
            ' @cFormatSP       NVARCHAR( 50), ' +
            ' @cLottableValue  NVARCHAR( 20), ' +
            ' @cLottable       NVARCHAR( 30) OUTPUT, ' +
            ' @nErrNo          INT           OUTPUT, ' +
            ' @cErrMsg         NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cSKU, 
            @cLottableCode, @nLottableNo, @cFormatSP, @cLottableValue, 
            @cLottable OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo<>''
         BEGIN
            SET @dLottable14 = ''
            SET @dLottable04 = ''
            GOTO Quit
         END

         SET @cExpDate=@cLottable
      END
   END

   ELSE IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK)
          WHERE Storerkey=@cStorerKey
          AND SKU=@cSKU
    AND BUSR6<>'HERMES' AND @nFunc = '600')
   BEGIN

      SET @cYearCode = SUBSTRING( @cLottable, 1, 1)
      SET @cMonthCode = SUBSTRING( @cLottable, 2, 1)

      -- Get month
      SELECT @cMonth = LEFT( Short, 2)
      FROM CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTDecode'
         AND Code = 'BATCH'
         AND Code2 = @cMonthCode
         AND StorerKey = @cStorerKey

      -- Get year
      SELECT @cYear = LEFT( Short, 4)
      FROM CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTDecode'
         AND Code = 'BATCH'
         AND Code2 = @cYearCode
         AND StorerKey = @cStorerKey

      -- Check year valid
      IF @cYearCode NOT BETWEEN '0' AND '9'
      BEGIN
         SET @nErrNo = 58301
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch
         SET @dLottable14 = ''
         SET @dLottable04 = ''
   --      IF RIGHT( @cLottable, 2) = 'XX'
   --         SET @cLottable01 = 'NA'
         GOTO Quit
      END

      -- Check month valid
      IF @cMonthCode BETWEEN '0' AND '9' OR
         @cMonthCode = 'I' OR
         @cMonthCode = 'O' OR
         @cMonthCode = ''
      BEGIN
         SET @nErrNo = 58302
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch
         SET @dLottable14 = ''
         SET @dLottable04 = ''
  --      IF RIGHT( @cLottable, 2) = 'XX'
   --         SET @cLottable01 = 'NA'
         GOTO Quit
      END
      -- Generate expiry date
      SET @cExpDate = '01/' + @cMonth + '/' + @cYear
   END

   -- Check date valid
   IF rdt.rdtIsValidDate(@cExpDate) = 0
   BEGIN
      SET @nErrNo = 58303
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid date
      SET @dLottable14 = NULL
      SET @dLottable04 = NULL
      GOTO Quit
   END

 -- Save expiry date
   SET @dLottable14 = CONVERT( DATETIME, @cExpDate, 103) --DD/MM/YYYY
   SET @dLottable04 = @dLottable14

   -- Add shelf life
   IF @nShelfLife > 0
      SET @dLottable04 = DATEADD( dd, @nShelfLife, @dLottable14)

Quit:
   DECLARE @cLastLottable01 NVARCHAR( 18)
   DECLARE @dLastLottable04 DATETIME
   DECLARE @cArchiveDB  NVARCHAR(30)   --(cc01)
   
   SELECT 
      @cLastLottable01 = V_Lottable01, 
      @dLastLottable04 = V_Lottable04 
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   -- Setup error, or L01 changed
   IF (@dLottable14Value = 0 OR @dLottable14Value IS NULL) OR
      (@cLottable01Value <> @cLastLottable01) OR 
      (@dLottable04 <> @dLastLottable04) 
   BEGIN
      --(cc01)
      IF @nErrNo > 0 AND @nFunc = '608' AND @cDisplayErr = '0'
      BEGIN
         IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LOTATTRIBUTE WITH (NOLOCK) WHERE storerkey = @cStorerKey AND sku = @cSKU AND Lottable01 = @cLottable01Value)
         BEGIN
            SET @cArchiveDB = ''

            EXECUTE dbo.nspGetRight ''    --facility
                  , @cStorerKey         -- Storer
                , ''                   -- Sku
                  , 'ARCHIVEDBNAME'          -- ConfigKey
                  , @b_success   OUTPUT
                  , @cArchiveDB     OUTPUT
                  , @n_err       OUTPUT
                  , @c_errmsg    OUTPUT

            SET @cSQL = N' SELECT TOP 1 1 '
               + ' FROM ' +@cArchiveDB+ '.dbo.ITRN WITH (NOLOCK)'
               + ' WHERE LOTTABLE01 = @cLottable01Value'
               + ' AND SKU = @cSKU'
               + ' AND StorerKey = @cStorerKey'
               + ' AND tranType = ''DP'''


            SET @cSQLParam =
               '@cArchiveDB        NVARCHAR(30), ' +
               '@cLottable01Value  NVARCHAR(18), ' +
               '@cSKU              NVARCHAR(20), ' +
               '@cStorerKey        NVARCHAR(15)  '

            EXEC sp_executesql @cSQL ,@cSQLParam
            , @cArchiveDB
            , @cLottable01Value
            , @cSKU
            , @cStorerKey

            IF @@ROWCOUNT = 0
            BEGIN
               SET @dLottable14 = CONVERT(DATETIME, CONVERT(CHAR(20), GETDATE(), 112))
               SET @dLottable04 = CONVERT(DATETIME, CONVERT(CHAR(20), DATEADD(dd,@nShelfLife,@dLottable14), 112))
               SET @nErrNo = 0
               SET @cErrMsg = ''

            END
            ELSE
            BEGIN  -- exists in ARCHIVE db
               SET @cSQL = N' SELECT TOP 1 @dLottable04 = lottable04, @dLottable14 = Lottable14 '
                  + ' FROM ' +@cArchiveDB+ '.dbo.ITRN WITH (NOLOCK)'
                  + ' WHERE LOTTABLE01 = @cLottable01Value'
                  + ' AND SKU = @cSKU'
                  + ' AND StorerKey = @cStorerKey'
                  + ' AND tranType = ''DP'''
                  + ' ORDER BY Lottable04'


               SET @cSQLParam =
                  '@cArchiveDB         NVARCHAR(30)   , ' +
                  '@dLottable04        DATETIME OUTPUT, ' +
                  '@dLottable14        DATETIME OUTPUT, ' +
                  '@cLottable01Value   NVARCHAR(18)   , ' +
                  '@cSKU               NVARCHAR(20)   , ' +
                  '@cStorerKey         NVARCHAR(15)   '

               EXEC sp_executesql @cSQL ,@cSQLParam
               , @cArchiveDB
               , @dLottable04 OUTPUT
               , @dLottable14 OUTPUT
               , @cLottable01Value
               , @cSKU
               , @cStorerKey

               SET @nErrNo = 0
               SET @cErrMsg = ''
            END   -- exists in ARCHIVE db
         END  -- Not exists in LOTATTRIBUTE
         ELSE
         BEGIN  -- exists in LOTATTRIBUTE
            SELECT TOP 1 @dLottable04 = lottable04, @dLottable14 = Lottable14
            FROM dbo.LOTATTRIBUTE WITH (NOLOCK)
            WHERE storerkey = @cStorerKey AND sku = @cSKU AND Lottable01 = @cLottable01Value
            order by lottable04

            SET @nErrNo = 0
            SET @cErrMsg = ''
         END  -- exists in LOTATTRIBUTE
      END  --error>0

      -- Remain in current screen
      SET @nErrNo = -1
   END  --1st Enter
   ELSE
   BEGIN  --2nd Enter
      --(cc01)
      IF @nErrNo > 0  AND @nFunc = '608'  AND @cDisplayErr = '0'
      BEGIN
         IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LOTATTRIBUTE WITH (NOLOCK) WHERE storerkey = @cStorerKey AND sku = @cSKU AND Lottable01 = @cLottable01Value)
         BEGIN
            SET @cArchiveDB = ''

            EXECUTE dbo.nspGetRight ''  --facility
                  , @cStorerKey         -- Storer
                  , ''                  -- Sku
                  , 'ARCHIVEDBNAME'     -- ConfigKey
                  , @b_success   OUTPUT
                  , @cArchiveDB  OUTPUT
                  , @n_err       OUTPUT
                  , @c_errmsg    OUTPUT

            SET @cSQL = N' SELECT TOP 1 1 '
               + ' FROM ' +@cArchiveDB+ '.dbo.ITRN WITH (NOLOCK)'
               + ' WHERE LOTTABLE01 = @cLottable01Value'
               + ' AND SKU = @cSKU'
               + ' AND StorerKey = @cStorerKey'
               + ' AND tranType = ''DP'''


            SET @cSQLParam =
               '@cArchiveDB         NVARCHAR(30), ' +
               '@cLottable01Value   NVARCHAR(18), ' +
               '@cSKU               NVARCHAR(20), ' +
           '@cStorerKey         NVARCHAR(15)  '

            EXEC sp_executesql @cSQL ,@cSQLParam
            , @cArchiveDB
            , @cLottable01Value
            , @cSKU
            , @cStorerKey

            IF @@ROWCOUNT = 0
            BEGIN
               SET @dLottable14 = CONVERT(DATETIME, CONVERT(CHAR(20), GETDATE(), 112))
               SET @dLottable04 = CONVERT(DATETIME, CONVERT(CHAR(20), DATEADD(dd,@nShelfLife,@dLottable14), 112))
               SET @nErrNo = 0
               SET @cErrMsg = ''
            END
            ELSE
            BEGIN -- EXISTS ARCHIVE db
               SET @cSQL = N' SELECT TOP 1 @dLottable04 = lottable04, @dLottable14 = Lottable14 '
                        + ' FROM ' +@cArchiveDB+ '.dbo.ITRN WITH (NOLOCK)'
                        + ' WHERE LOTTABLE01 = @cLottable01Value'
                        + ' AND SKU = @cSKU'
                        + ' AND StorerKey = @cStorerKey'
                        + ' AND tranType = ''DP'''
                        + ' Order BY lottable04'

               SET @cSQLParam =
                  '@cArchiveDB         NVARCHAR(30),     ' +
                  '@dLottable04        DATETIME OUTPUT,  ' +
                  '@dLottable14        DATETIME OUTPUT,  ' +
                  '@cLottable01Value   NVARCHAR(18),     ' +
                  '@cSKU               NVARCHAR(20),     ' +
                  '@cStorerKey         NVARCHAR(15)      '

               EXEC sp_executesql @cSQL ,@cSQLParam
               , @cArchiveDB
               , @dLottable04 OUTPUT
               , @dLottable14 OUTPUT
               , @cLottable01Value
               , @cSKU
               , @cStorerKey

               SET @nErrNo = 0
               SET @cErrMsg = ''

               SET @cExpDate =  @dLottable14  --(yeekung small change)

               --IF (@cLastLottable14=rdt.rdtConvertToDate(@cExpDate))
               IF (@cLastLottable14=@dLottable14)
               BEGIN

                  SET @cConDay=datediff(dayofyear,getdate(),@cLastLottable14)
                  SET @cConExpDay = DATEDIFF(dayofyear,getdate(),@cLastLottable04)

                  --IF (@cConDay <0)
                  --   SET @cConDay =(-@cConDay)

                  IF ((@cConExpDay<@cSKUDay2) AND  @cLastLottable03 IN ('OK','OK-RTN','PER-Tag'))
                  BEGIN
                     SET @nErrNo = 58319
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid date
                     --GOTO Quit
                  END

                  --IF ((@cConExpDay>@cSKUDay2) AND  @cLastLottable03 NOT IN ('OK','OK-RTN','PER-Tag'))
                  --BEGIN
                  --   SET @nErrNo = 58319
                  --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid date
                  --END
               END
            END  -- EXISTS ARCHIVE db
         END   -- Not EXISTS LOTATTRIBUTE tb
         ELSE
         BEGIN --EXISTS LOTATTRIBUTE tb
            SELECT TOP 1 @dLottable04 = lottable04,@dLottable14=lottable14 --(yeekung small change)
            FROM dbo.LOTATTRIBUTE WITH (NOLOCK) WHERE storerkey = @cStorerKey
            AND sku = @cSKU AND Lottable01 = @cLottable01Value
            order by lottable04

            SET @nErrNo = 0
            SET @cErrMsg = ''

            --yeekung
            set @cExpDate=@dLottable14

            IF (@cLastLottable14=@cExpDate)
            BEGIN
               --SET @cConDay=datediff(dayofyear,getdate(),@cLastLottable14)
               IF (@cLastLottable14=@dLottable14)

               --IF (@cConDay <0)
               --   SET @cConDay =(-@cConDay)

               IF ((@cConDay>@cSKUDay) AND  @cLastLottable03 ='OK')
               BEGIN
                  SET @nErrNo = 58319
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid date
                  --GOTO Quit
               END

            END
         END   --EXISTS LOTATTRIBUTE tb
      END     --@nErrNo >0
      SET @cExpDate =  @dLottable14  --(yeekung small change)

      --IF (@cLastLottable14=rdt.rdtConvertToDate(@cExpDate))
      IF (@cLastLottable14=@dLottable14)
      BEGIN
       SET @cConDay=datediff(dayofyear,getdate(),@cLastLottable14)
       SET @cConExpDay = DATEDIFF(dayofyear,getdate(),@cLastLottable04)

         IF (@cConDay <0)
            SET @cConDay =(-@cConDay)

         IF ((@cConDay>@cSKUDay) AND  @cLastLottable03 ='OK') AND @nFunc = '600'
         BEGIN
            SET @nErrNo = 58319
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid date
         END

         IF ((@cConExpDay<@cSKUDay2) AND  @cLastLottable03 IN ('OK','OK-RTN','PER-Tag')) AND @nFunc = '608' --(cc01)
         BEGIN
            SET @nErrNo = 58319
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid date
         END

         --IF ((@cConExpDay>@cSKUDay2) AND  @cLastLottable03 NOT IN ('OK','OK-RTN','PER-Tag')) AND @nFunc = '608' --(cc01)
         --BEGIN
         --   SET @nErrNo = 58319
         --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid date
         --END

      END
   END


--   ELSE
--   BEGIN
--      -- If user still not change L01 after prompt error, let user pass
--      SET @nErrNo = 0
--      SET @cErrMsg = ''
--   END

END -- End Procedure

GO