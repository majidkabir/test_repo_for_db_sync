SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Trigger:  ispGenLottableDateByBatchno_HK01                           */
/* Creation Date: 14-Mar-2018                                           */
/* Copyright: LFL                                                       */
/*                                                                      */
/*                                                                      */
/* Purpose: WMS-4598 HK Generate Lottable Date By Batch No              */
/*           CODELKUP: GenDtByBat                                       */
/*                     Short  = ShelfLife                               */
/*                     Notes  = Sku Match Condition                     */
/*                     Notes2 = Date Calculation Formula                */
/*                     UDF01  = Lottable99 for Batch No                 */
/*                     UDF02  = Lottable99Label for Batch No            */
/*                     UDF03  = Lottable99 for Date                     */
/*                     UDF04  = Lottable99Label for Date                */
/*                     UDF05  = Override Value (Y/N)                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Who      Purpose                                        */
/* 14-Mar-2018  ML       Created                                        */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenLottableDateByBatchno_HK01]
     @c_Storerkey          NVARCHAR(15)
   , @c_Sku                NVARCHAR(20)
   , @c_Lottable01Value    NVARCHAR(18)   = ''
   , @c_Lottable02Value    NVARCHAR(18)   = ''
   , @c_Lottable03Value    NVARCHAR(18)   = ''
   , @dt_Lottable04Value   DATETIME       = NULL
   , @dt_Lottable05Value   DATETIME       = NULL
   , @c_Lottable06Value    NVARCHAR(30)   = ''
   , @c_Lottable07Value    NVARCHAR(30)   = ''
   , @c_Lottable08Value    NVARCHAR(30)   = ''
   , @c_Lottable09Value    NVARCHAR(30)   = ''
   , @c_Lottable10Value    NVARCHAR(30)   = ''
   , @c_Lottable11Value    NVARCHAR(30)   = ''
   , @c_Lottable12Value    NVARCHAR(30)   = ''
   , @dt_Lottable13Value   DATETIME       = NULL
   , @dt_Lottable14Value   DATETIME       = NULL
   , @dt_Lottable15Value   DATETIME       = NULL
   , @c_Lottable01         NVARCHAR(18)   = ''   OUTPUT
   , @c_Lottable02         NVARCHAR(18)   = ''   OUTPUT
   , @c_Lottable03         NVARCHAR(18)   = ''   OUTPUT
   , @dt_Lottable04        DATETIME       = NULL OUTPUT
   , @dt_Lottable05        DATETIME       = NULL OUTPUT
   , @c_Lottable06         NVARCHAR(30)   = ''   OUTPUT
   , @c_Lottable07         NVARCHAR(30)   = ''   OUTPUT
   , @c_Lottable08         NVARCHAR(30)   = ''   OUTPUT
   , @c_Lottable09         NVARCHAR(30)   = ''   OUTPUT
   , @c_Lottable10         NVARCHAR(30)   = ''   OUTPUT
   , @c_Lottable11         NVARCHAR(30)   = ''   OUTPUT
   , @c_Lottable12         NVARCHAR(30)   = ''   OUTPUT
   , @dt_Lottable13        DATETIME       = NULL OUTPUT
   , @dt_Lottable14        DATETIME       = NULL OUTPUT
   , @dt_Lottable15        DATETIME       = NULL OUTPUT
   , @b_Success            int            = 1    OUTPUT
   , @n_Err                int            = 0    OUTPUT
   , @c_Errmsg             NVARCHAR(250)  = ''   OUTPUT
   , @c_Sourcekey          NVARCHAR(15)   = ''
   , @c_Sourcetype         NVARCHAR(20)   = ''
   , @c_LottableLabel      NVARCHAR(20)   = ''

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nShelflife       INT
         , @nShelflife1      INT
         , @nShelflife2      INT
         , @cLottable01Label NVARCHAR( 20)
         , @cLottable02Label NVARCHAR( 20)
         , @cLottable03Label NVARCHAR( 20)
         , @cLottable04Label NVARCHAR( 20)
         , @cLottable05Label NVARCHAR( 20)
         , @cLottable06Label NVARCHAR( 20)
         , @cLottable07Label NVARCHAR( 20)
         , @cLottable08Label NVARCHAR( 20)
         , @cLottable09Label NVARCHAR( 20)
         , @cLottable10Label NVARCHAR( 20)
         , @cLottable11Label NVARCHAR( 20)
         , @cLottable12Label NVARCHAR( 20)
         , @cLottable13Label NVARCHAR( 20)
         , @cLottable14Label NVARCHAR( 20)
         , @cLottable15Label NVARCHAR( 20)
         , @cLotLabel_Batch  NVARCHAR( 20)
         , @cLotLabel_Date   NVARCHAR( 20)
         , @cSQL             NVARCHAR(MAX)
         , @cSQLParam        NVARCHAR(MAX)
         , @cCondition       NVARCHAR(MAX)
         , @cFormula         NVARCHAR(MAX)
         , @cBatchLottable   NVARCHAR( 60)
         , @cBatchLotLabel   NVARCHAR( 60)
         , @cDateLottable    NVARCHAR( 60)
         , @cDateLotLabel    NVARCHAR( 60)
         , @cOverideValue    NVARCHAR( 60)
         , @cBatchLottableValue NVARCHAR( 30)
         , @cDateLottableValue  NVARCHAR( 30)


   SELECT @b_success = 1
        , @n_Err = 0
        , @c_Lottable01  = @c_Lottable01Value
        , @c_Lottable02  = @c_Lottable02Value
        , @c_Lottable03  = @c_Lottable03Value
        , @dt_Lottable04 = @dt_Lottable04Value
        , @dt_Lottable05 = @dt_Lottable05Value
        , @c_Lottable06  = @c_Lottable06Value
        , @c_Lottable07  = @c_Lottable07Value
        , @c_Lottable08  = @c_Lottable08Value
        , @c_Lottable09  = @c_Lottable09Value
        , @c_Lottable10  = @c_Lottable10Value
        , @c_Lottable11  = @c_Lottable11Value
        , @c_Lottable12  = @c_Lottable12Value
        , @dt_Lottable13 = @dt_Lottable13Value
        , @dt_Lottable14 = @dt_Lottable14Value
        , @dt_Lottable15 = @dt_Lottable15Value
        , @nShelflife    = 0
        , @nShelflife1   = 0
        , @nShelflife2   = 0
        , @cBatchLottable   = ''
        , @cBatchLotLabel   = ''
        , @cDateLottable    = ''
        , @cDateLotLabel    = ''
        , @cOverideValue    = ''
        , @cLottable01Label = ''
        , @cLottable02Label = ''
        , @cLottable03Label = ''
        , @cLottable04Label = ''
        , @cLottable05Label = ''
        , @cLottable06Label = ''
        , @cLottable07Label = ''
        , @cLottable08Label = ''
        , @cLottable09Label = ''
        , @cLottable10Label = ''
        , @cLottable11Label = ''
        , @cLottable12Label = ''
        , @cLottable13Label = ''
        , @cLottable14Label = ''
        , @cLottable15Label = ''
        , @cBatchLottableValue = ''
        , @cDateLottableValue  = ''

   SELECT @cLottable01Label = RTRIM(Lottable01Label)
        , @cLottable02Label = RTRIM(Lottable02Label)
        , @cLottable03Label = RTRIM(Lottable03Label)
        , @cLottable04Label = RTRIM(Lottable04Label)
        , @cLottable05Label = RTRIM(Lottable05Label)
        , @cLottable06Label = RTRIM(Lottable06Label)
        , @cLottable07Label = RTRIM(Lottable07Label)
        , @cLottable08Label = RTRIM(Lottable08Label)
        , @cLottable09Label = RTRIM(Lottable09Label)
        , @cLottable10Label = RTRIM(Lottable10Label)
        , @cLottable11Label = RTRIM(Lottable11Label)
        , @cLottable12Label = RTRIM(Lottable12Label)
        , @cLottable13Label = RTRIM(Lottable13Label)
        , @cLottable14Label = RTRIM(Lottable14Label)
        , @cLottable15Label = RTRIM(Lottable15Label)
        , @nShelflife1      = Shelflife
     FROM SKU (NOLOCK)
    WHERE Storerkey = @c_Storerkey AND SKU = @c_Sku


   DECLARE C_FORMULA CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT ShelfLife = CASE WHEN ISNUMERIC(Short)=1 THEN CONVERT(INT, CONVERT(FLOAT, Short)) ELSE 0 END
        , Condition = LTRIM(RTRIM(Notes))
        , Formula   = LTRIM(RTRIM(Notes2))
        , BatchLottable = RTRIM(UDF01)
        , BatchLotLabel = RTRIM(UDF02)
        , DateLottable  = RTRIM(UDF03)
        , DateLotLabel  = RTRIM(UDF04)
        , OverideValue  = RTRIM(UDF05)
     FROM CODELKUP (NOLOCK)
    WHERE Listname = 'GenDtByBat' AND Storerkey = @c_Storerkey
      AND Notes2 <> ''
    ORDER BY Code, Code2

   OPEN C_FORMULA

   SET @cSQLParam =
         '@cStorerkey NVARCHAR(15)'
      + ',@cSku NVARCHAR(20)'
      + ',@cLottable01Value NVARCHAR(18)'
      + ',@cLottable02Value NVARCHAR(18)'
      + ',@cLottable03Value NVARCHAR(18)'
      + ',@dLottable04Value DATETIME'
      + ',@dLottable05Value DATETIME'
      + ',@cLottable06Value NVARCHAR(30)'
      + ',@cLottable07Value NVARCHAR(30)'
      + ',@cLottable08Value NVARCHAR(30)'
      + ',@cLottable09Value NVARCHAR(30)'
      + ',@cLottable10Value NVARCHAR(30)'
      + ',@cLottable11Value NVARCHAR(30)'
      + ',@cLottable12Value NVARCHAR(30)'
      + ',@dLottable13Value DATETIME'
      + ',@dLottable14Value DATETIME'
      + ',@dLottable15Value DATETIME'
      + ',@cLottable01 NVARCHAR(18) OUTPUT'
      + ',@cLottable02 NVARCHAR(18) OUTPUT'
      + ',@cLottable03 NVARCHAR(18) OUTPUT'
      + ',@dLottable04 DATETIME OUTPUT'
      + ',@dLottable05 DATETIME OUTPUT'
      + ',@cLottable06 NVARCHAR(30) OUTPUT'
      + ',@cLottable07 NVARCHAR(30) OUTPUT'
      + ',@cLottable08 NVARCHAR(30) OUTPUT'
      + ',@cLottable09 NVARCHAR(30) OUTPUT'
      + ',@cLottable10 NVARCHAR(30) OUTPUT'
      + ',@cLottable11 NVARCHAR(30) OUTPUT'
      + ',@cLottable12 NVARCHAR(30) OUTPUT'
      + ',@dLottable13 DATETIME OUTPUT'
      + ',@dLottable14 DATETIME OUTPUT'
      + ',@dLottable15 DATETIME OUTPUT'
      + ',@bSuccess int OUTPUT'
      + ',@nErrNo int OUTPUT'
      + ',@cErrmsg NVARCHAR(250) OUTPUT'
      + ',@cSourcekey NVARCHAR(15)'
      + ',@cSourcetype NVARCHAR(20)'
      + ',@cLottableLabel NVARCHAR(20)'
      + ',@nShelfLife INT'
      + ',@cBatchLottableValue NVARCHAR(30)'

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_FORMULA
       INTO @nShelflife2, @cCondition, @cFormula, @cBatchLottable, @cBatchLotLabel, @cDateLottable, @cDateLotLabel, @cOverideValue

      IF @@FETCH_STATUS<>0
         BREAK

      SET @nShelflife = CASE WHEN ISNULL(@nShelflife2,0)=0 THEN @nShelflife1 ELSE @nShelflife2 END

      -- Check Formula Condition
      SET @cSQL = 'SET @bSuccess = 0'
                +' IF EXISTS(SELECT TOP 1 1 FROM dbo.SKU AS SKU WITH(NOLOCK)'
                +' WHERE (SKU.Storerkey=@cStorerkey AND SKU.Sku=@cSku)'
                + CASE WHEN ISNULL(@cCondition,'')<>'' THEN
                     CASE WHEN @cCondition LIKE 'AND %' THEN ' ' + @cCondition
                          WHEN @cCondition LIKE 'OR %'  THEN ' OR (SKU.Storerkey=@cStorerkey AND ' + SUBSTRING(@cCondition,4,LEN(@cCondition)) + ')'
                          ELSE ' AND (' + @cCondition + ')'
                     END
                  ELSE '' END
                +') SET @bSuccess = 1'

      BEGIN TRY
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam
            , @c_Storerkey
            , @c_Sku
            , @c_Lottable01Value
            , @c_Lottable02Value
            , @c_Lottable03Value
            , @dt_Lottable04Value
            , @dt_Lottable05Value
            , @c_Lottable06Value
            , @c_Lottable07Value
            , @c_Lottable08Value
            , @c_Lottable09Value
            , @c_Lottable10Value
            , @c_Lottable11Value
            , @c_Lottable12Value
            , @dt_Lottable13Value
            , @dt_Lottable14Value
            , @dt_Lottable15Value
            , @c_Lottable01
            , @c_Lottable02
            , @c_Lottable03
            , @dt_Lottable04
            , @dt_Lottable05
            , @c_Lottable06
            , @c_Lottable07
            , @c_Lottable08
            , @c_Lottable09
            , @c_Lottable10
            , @c_Lottable11
            , @c_Lottable12
            , @dt_Lottable13
            , @dt_Lottable14
            , @dt_Lottable15
            , @b_Success OUTPUT
            , @n_Err OUTPUT
            , @c_Errmsg OUTPUT
            , @c_Sourcekey
            , @c_Sourcetype
            , @c_LottableLabel
            , @nShelflife
            , @cBatchLottableValue
      END TRY
      BEGIN CATCH
         SET @n_Err = 60001
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Invalid Condition Setup. (ispGenLottableDateByBatchno_HK01)'
         SET @b_Success = 0
      END CATCH

      IF @b_Success = 1
      BEGIN
         -- Validate Batch Lottable
         IF @cBatchLottable LIKE 'Lottable[0-9][0-9]' AND @cBatchLottable BETWEEN 'Lottable01' AND 'Lottable115'
         BEGIN
            SET @cLotLabel_Batch = ISNULL(CASE SUBSTRING(@cBatchLottable,9,2)
                  WHEN '01' THEN @cLottable01Label
                  WHEN '02' THEN @cLottable02Label
                  WHEN '03' THEN @cLottable03Label
                  WHEN '04' THEN @cLottable04Label
                  WHEN '05' THEN @cLottable05Label
                  WHEN '06' THEN @cLottable06Label
                  WHEN '07' THEN @cLottable07Label
                  WHEN '08' THEN @cLottable08Label
                  WHEN '09' THEN @cLottable09Label
                  WHEN '10' THEN @cLottable10Label
                  WHEN '11' THEN @cLottable11Label
                  WHEN '12' THEN @cLottable12Label
                  WHEN '13' THEN @cLottable13Label
                  WHEN '14' THEN @cLottable14Label
                  WHEN '15' THEN @cLottable15Label
               END, '')

            IF ISNULL(@c_LottableLabel,'')<>'' AND @c_LottableLabel<>@cLotLabel_Batch AND @c_LottableLabel<>@cBatchLottable
            BEGIN
               BREAK
            END
            -- Check Batch Lottable Label
            ELSE IF ISNULL(@cBatchLotLabel,'')<>'' AND @cBatchLotLabel<>@cLotLabel_Batch
            BEGIN
               SET @n_Err = 60002
               SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' L' + ISNULL(SUBSTRING(@cBatchLottable,9,2),'') + 'Label NotSet. (ispGenLottableDateByBatchno_HK01)'
               BREAK
            END
            -- If not updating Batchno, then skip
            ELSE
            BEGIN
               SET @cBatchLottableValue = ISNULL(CASE SUBSTRING(@cBatchLottable,9,2)
                     WHEN '01' THEN @c_Lottable01
                     WHEN '02' THEN @c_Lottable02
                     WHEN '03' THEN @c_Lottable03
                     WHEN '04' THEN CONVERT(NVARCHAR(30),@dt_Lottable04,121)
                     WHEN '05' THEN CONVERT(NVARCHAR(30),@dt_Lottable05,121)
                     WHEN '06' THEN @c_Lottable06
                     WHEN '07' THEN @c_Lottable07
                     WHEN '08' THEN @c_Lottable08
                     WHEN '09' THEN @c_Lottable09
                     WHEN '10' THEN @c_Lottable10
                     WHEN '11' THEN @c_Lottable11
                     WHEN '12' THEN @c_Lottable12
                     WHEN '13' THEN CONVERT(NVARCHAR(30),@dt_Lottable13,121)
                     WHEN '14' THEN CONVERT(NVARCHAR(30),@dt_Lottable14,121)
                     WHEN '15' THEN CONVERT(NVARCHAR(30),@dt_Lottable15,121)
               END, '')

               IF ISNULL(@cBatchLottableValue,'')=''
                  BREAK
            END
         END
         ELSE IF ISNULL(@cBatchLottable,'')<>''
         BEGIN
            SET @n_Err = 60003
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Bad ' + ISNULL(@cBatchLottable,'') + '. (ispGenLottableDateByBatchno_HK01)'
            BREAK
         END

         -- Validate Date Lottable
         IF @cDateLottable LIKE 'Lottable[0-9][0-9]' AND @cDateLottable BETWEEN 'Lottable01' AND 'Lottable115'
         BEGIN
            SET @cLotLabel_Date = ISNULL(CASE SUBSTRING(@cDateLottable,9,2)
                  WHEN '01' THEN @cLottable01Label
                  WHEN '02' THEN @cLottable02Label
                  WHEN '03' THEN @cLottable03Label
                  WHEN '04' THEN @cLottable04Label
                  WHEN '05' THEN @cLottable05Label
                  WHEN '06' THEN @cLottable06Label
                  WHEN '07' THEN @cLottable07Label
                  WHEN '08' THEN @cLottable08Label
                  WHEN '09' THEN @cLottable09Label
                  WHEN '10' THEN @cLottable10Label
                  WHEN '11' THEN @cLottable11Label
                  WHEN '12' THEN @cLottable12Label
                  WHEN '13' THEN @cLottable13Label
                  WHEN '14' THEN @cLottable14Label
                  WHEN '15' THEN @cLottable15Label
               END, '')

            -- Check Date Lottable Label
            IF ISNULL(@cDateLotLabel,'')<>'' AND @cDateLotLabel<>@cLotLabel_Date
            BEGIN
               SET @n_Err = 60004
               SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Bad L' + ISNULL(SUBSTRING(@cDateLottable,9,2),'') + 'Label NotMatch. (ispGenLottableDateByBatchno_HK01)'
               BREAK
            END

            SET @cDateLottableValue = ISNULL(CASE SUBSTRING(@cDateLottable,9,2)
                  WHEN '01' THEN @c_Lottable01
                  WHEN '02' THEN @c_Lottable02
                  WHEN '03' THEN @c_Lottable03
                  WHEN '04' THEN (CASE WHEN ISNULL(@dt_Lottable04,'')<>'' THEN CONVERT(NVARCHAR(30),@dt_Lottable04,121) END)
                  WHEN '05' THEN (CASE WHEN ISNULL(@dt_Lottable05,'')<>'' THEN CONVERT(NVARCHAR(30),@dt_Lottable05,121) END)
                  WHEN '06' THEN @c_Lottable06
                  WHEN '07' THEN @c_Lottable07
                  WHEN '08' THEN @c_Lottable08
                  WHEN '09' THEN @c_Lottable09
                  WHEN '10' THEN @c_Lottable10
                  WHEN '11' THEN @c_Lottable11
                  WHEN '12' THEN @c_Lottable12
                  WHEN '13' THEN (CASE WHEN ISNULL(@dt_Lottable13,'')<>'' THEN CONVERT(NVARCHAR(30),@dt_Lottable13,121) END)
                  WHEN '14' THEN (CASE WHEN ISNULL(@dt_Lottable14,'')<>'' THEN CONVERT(NVARCHAR(30),@dt_Lottable14,121) END)
                  WHEN '15' THEN (CASE WHEN ISNULL(@dt_Lottable15,'')<>'' THEN CONVERT(NVARCHAR(30),@dt_Lottable15,121) END)
            END, '')
         END
         ELSE
         BEGIN
            SET @n_Err = 60005
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Bad ' + IIF(@cDateLottable<>'',@cDateLottable,'DateLot') + '. (ispGenLottableDateByBatchno_HK01)'
            BREAK
         END

         IF ISNULL(@cDateLottableValue,'')='' OR ISNULL(@cOverideValue,'')='Y'
         BEGIN
            -- Calculate Date Lottable
            SET @cSQL = 'SET ' + CASE WHEN SUBSTRING(@cDateLottable,9,2) IN ('04', '05', '13', '14', '15') THEN '@d' ELSE '@c' END
                      + @cDateLottable + ' = (' + @cFormula + ')'

            BEGIN TRY
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam
                  , @c_Storerkey
                  , @c_Sku
                  , @c_Lottable01Value
                  , @c_Lottable02Value
                  , @c_Lottable03Value
                  , @dt_Lottable04Value
                  , @dt_Lottable05Value
                  , @c_Lottable06Value
                  , @c_Lottable07Value
                  , @c_Lottable08Value
                  , @c_Lottable09Value
                  , @c_Lottable10Value
                  , @c_Lottable11Value
                  , @c_Lottable12Value
                  , @dt_Lottable13Value
                  , @dt_Lottable14Value
                  , @dt_Lottable15Value
                  , @c_Lottable01  OUTPUT
                  , @c_Lottable02  OUTPUT
                  , @c_Lottable03  OUTPUT
                  , @dt_Lottable04 OUTPUT
                  , @dt_Lottable05 OUTPUT
                  , @c_Lottable06  OUTPUT
                  , @c_Lottable07  OUTPUT
                  , @c_Lottable08  OUTPUT
                  , @c_Lottable09  OUTPUT
                  , @c_Lottable10  OUTPUT
                  , @c_Lottable11  OUTPUT
                  , @c_Lottable12  OUTPUT
                  , @dt_Lottable13 OUTPUT
                  , @dt_Lottable14 OUTPUT
                  , @dt_Lottable15 OUTPUT
                  , @b_Success     OUTPUT
                  , @n_Err         OUTPUT
                  , @c_Errmsg      OUTPUT
                  , @c_Sourcekey
                  , @c_Sourcetype
                  , @c_LottableLabel
                  , @nShelflife
                  , @cBatchLottableValue
            END TRY
            BEGIN CATCH
               SET @n_Err = 60006
               SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Formula Err. (ispGenLottableDateByBatchno_HK01)'
            END CATCH
         END
         BREAK
      END
   END

   CLOSE C_FORMULA
   DEALLOCATE C_FORMULA

QUIT:

END -- End Procedure



GO