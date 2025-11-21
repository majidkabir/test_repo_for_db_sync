SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  rdt_LottableProcess_GenDtByBat_HK01                        */
/* Creation Date: 14-Mar-2018                                           */
/* Copyright: LFL                                                       */
/*                                                                      */
/*                                                                      */
/* Purpose:  WMS-4598 HK Generate Lottable Date By Batch No             */
/*           Calling ispGenLottableDateByBatchno_HK01                   */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Who      Purpose                                        */
/* 14-Mar-2018  ML       Created                                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_GenDtByBat_HK01]
    @nMobile          INT           = 0
   ,@nFunc            INT           = 0
   ,@cLangCode        NVARCHAR( 3)  = ''
   ,@nInputKey        INT           = 0
   ,@cStorerKey       NVARCHAR( 15)
   ,@cSKU             NVARCHAR( 20)
   ,@cLottableCode    NVARCHAR( 30) = ''
   ,@nLottableNo      INT           = 0
   ,@cLottable        NVARCHAR( 30) = ''
   ,@cType            NVARCHAR( 10) = ''
   ,@cSourceKey       NVARCHAR( 15) = ''
   ,@cLottable01Value NVARCHAR( 18) = ''
   ,@cLottable02Value NVARCHAR( 18) = ''
   ,@cLottable03Value NVARCHAR( 18) = ''
   ,@dLottable04Value DATETIME      = NULL
   ,@dLottable05Value DATETIME      = NULL
   ,@cLottable06Value NVARCHAR( 30) = ''
   ,@cLottable07Value NVARCHAR( 30) = ''
   ,@cLottable08Value NVARCHAR( 30) = ''
   ,@cLottable09Value NVARCHAR( 30) = ''
   ,@cLottable10Value NVARCHAR( 30) = ''
   ,@cLottable11Value NVARCHAR( 30) = ''
   ,@cLottable12Value NVARCHAR( 30) = ''
   ,@dLottable13Value DATETIME      = NULL
   ,@dLottable14Value DATETIME      = NULL
   ,@dLottable15Value DATETIME      = NULL
   ,@cLottable01      NVARCHAR( 18) = ''   OUTPUT
   ,@cLottable02      NVARCHAR( 18) = ''   OUTPUT
   ,@cLottable03      NVARCHAR( 18) = ''   OUTPUT
   ,@dLottable04      DATETIME      = NULL OUTPUT
   ,@dLottable05      DATETIME      = NULL OUTPUT
   ,@cLottable06      NVARCHAR( 30) = ''   OUTPUT
   ,@cLottable07      NVARCHAR( 30) = ''   OUTPUT
   ,@cLottable08      NVARCHAR( 30) = ''   OUTPUT
   ,@cLottable09      NVARCHAR( 30) = ''   OUTPUT
   ,@cLottable10      NVARCHAR( 30) = ''   OUTPUT
   ,@cLottable11      NVARCHAR( 30) = ''   OUTPUT
   ,@cLottable12      NVARCHAR( 30) = ''   OUTPUT
   ,@dLottable13      DATETIME      = NULL OUTPUT
   ,@dLottable14      DATETIME      = NULL OUTPUT
   ,@dLottable15      DATETIME      = NULL OUTPUT
   ,@nErrNo           INT           = 0    OUTPUT
   ,@cErrMsg          NVARCHAR( 20) = ''   OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLottableLabel NVARCHAR(20)
   SET @cLottableLabel = 'LOTTABLE' + RIGHT('00'+CONVERT(VARCHAR(10),@nLottableNo),2)

   EXEC ispGenLottableDateByBatchno_HK01
        @c_Storerkey          = @cStorerKey
      , @c_Sku                = @cSKU
      , @c_Lottable01Value    = @cLottable01Value
      , @c_Lottable02Value    = @cLottable02Value
      , @c_Lottable03Value    = @cLottable03Value
      , @dt_Lottable04Value   = @dLottable04Value
      , @dt_Lottable05Value   = @dLottable05Value
      , @c_Lottable06Value    = @cLottable06Value
      , @c_Lottable07Value    = @cLottable07Value
      , @c_Lottable08Value    = @cLottable08Value
      , @c_Lottable09Value    = @cLottable09Value
      , @c_Lottable10Value    = @cLottable10Value
      , @c_Lottable11Value    = @cLottable11Value
      , @c_Lottable12Value    = @cLottable12Value
      , @dt_Lottable13Value   = @dLottable13Value
      , @dt_Lottable14Value   = @dLottable14Value
      , @dt_Lottable15Value   = @dLottable15Value
      , @c_Lottable01         = @cLottable01 OUTPUT
      , @c_Lottable02         = @cLottable02 OUTPUT
      , @c_Lottable03         = @cLottable03 OUTPUT
      , @dt_Lottable04        = @dLottable04 OUTPUT
      , @dt_Lottable05        = @dLottable05 OUTPUT
      , @c_Lottable06         = @cLottable06 OUTPUT
      , @c_Lottable07         = @cLottable07 OUTPUT
      , @c_Lottable08         = @cLottable08 OUTPUT
      , @c_Lottable09         = @cLottable09 OUTPUT
      , @c_Lottable10         = @cLottable10 OUTPUT
      , @c_Lottable11         = @cLottable11 OUTPUT
      , @c_Lottable12         = @cLottable12 OUTPUT
      , @dt_Lottable13        = @dLottable13 OUTPUT
      , @dt_Lottable14        = @dLottable14 OUTPUT
      , @dt_Lottable15        = @dLottable15 OUTPUT
      , @b_Success            = 1
      , @n_Err                = @nErrNo      OUTPUT
      , @c_Errmsg             = @cErrMsg     OUTPUT
      , @c_Sourcekey          = @cSourceKey
      , @c_Sourcetype         = @cType
      , @c_LottableLabel      = @cLottableLabel

END


GO