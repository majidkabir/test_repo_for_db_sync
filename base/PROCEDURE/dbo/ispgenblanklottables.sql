SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: ispGenBlankLottables                                */  
/* Copyright: IDS                                                       */  
/* Purpose: Generate blank lottable01-05 based on rdt storerconfig      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 2014-01-16   James     1.0   Created                                 */  
/* 2014-05-21   TKLIM     1.1   Added Lottables 06-15                   */
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispGenBlankLottables]  
     @c_Storerkey          NVARCHAR(15)
   , @c_Sku                NVARCHAR(20)
   , @c_Lottable01Value    NVARCHAR(18)
   , @c_Lottable02Value    NVARCHAR(18)
   , @c_Lottable03Value    NVARCHAR(18)
   , @dt_Lottable04Value   DATETIME
   , @dt_Lottable05Value   DATETIME
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
   , @c_Lottable01         NVARCHAR(18)            OUTPUT
   , @c_Lottable02         NVARCHAR(18)            OUTPUT
   , @c_Lottable03         NVARCHAR(18)            OUTPUT
   , @dt_Lottable04        DATETIME                OUTPUT
   , @dt_Lottable05        DATETIME                OUTPUT
   , @c_Lottable06         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable07         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable08         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable09         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable10         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable11         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable12         NVARCHAR(30)   = ''     OUTPUT
   , @dt_Lottable13        DATETIME       = NULL   OUTPUT
   , @dt_Lottable14        DATETIME       = NULL   OUTPUT
   , @dt_Lottable15        DATETIME       = NULL   OUTPUT
   , @b_Success            int            = 1      OUTPUT
   , @n_ErrNo              int            = 0      OUTPUT
   , @c_Errmsg             NVARCHAR(250)  = ''     OUTPUT
   , @c_Sourcekey          NVARCHAR(15)   = ''  
   , @c_Sourcetype         NVARCHAR(20)   = ''   
   , @c_LottableLabel      NVARCHAR(20)   = '' 

AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @c_SkipLottable01  NVARCHAR(1), 
           @c_SkipLottable02  NVARCHAR(1), 
           @c_SkipLottable03  NVARCHAR(1), 
           @c_SkipLottable04  NVARCHAR(1), 
           @c_SkipLottable05  NVARCHAR(1), 
           @c_SkipLottable06  NVARCHAR(1),
           @c_SkipLottable07  NVARCHAR(1),
           @c_SkipLottable08  NVARCHAR(1),
           @c_SkipLottable09  NVARCHAR(1),
           @c_SkipLottable10  NVARCHAR(1),
           @c_SkipLottable11  NVARCHAR(1),
           @c_SkipLottable12  NVARCHAR(1),
           @c_SkipLottable13  NVARCHAR(1),
           @c_SkipLottable14  NVARCHAR(1),
           @c_SkipLottable15  NVARCHAR(1),
           @c_Facility        NVARCHAR(5) 

   SET @c_SkipLottable01 = ''
   SET @c_SkipLottable02 = ''
   SET @c_SkipLottable03 = ''
   SET @c_SkipLottable04 = ''
   SET @c_SkipLottable05 = ''
   SET @c_SkipLottable06 = ''
   SET @c_SkipLottable07 = ''
   SET @c_SkipLottable08 = ''
   SET @c_SkipLottable09 = ''
   SET @c_SkipLottable10 = ''
   SET @c_SkipLottable11 = ''
   SET @c_SkipLottable12 = ''
   SET @c_SkipLottable13 = ''
   SET @c_SkipLottable14 = ''
   SET @c_SkipLottable15 = ''

   -- Storer config 'SkipLottable01'
   EXECUTE nspGetRight
      @c_Facility, 
      @c_storerkey,
      @c_sku,
      'SkipLottable01',
      @b_success              OUTPUT,
      @c_SkipLottable01       OUTPUT,
      @n_ErrNo                OUTPUT,
      @c_Errmsg               OUTPUT
      
   IF @b_success <> 1
   BEGIN
      SET @n_ErrNo = 84451
      SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' SkipLottable01 Fail (ispGenBlankLottables)'
      GOTO Quit
   END
   
   -- Storer config 'SkipLottable02'
   EXECUTE nspGetRight
      @c_Facility, 
      @c_storerkey,
      @c_sku,
      'SkipLottable02',
      @b_success              OUTPUT,
      @c_SkipLottable02       OUTPUT,
      @n_ErrNo                OUTPUT,
      @c_Errmsg               OUTPUT
      
   IF @b_success <> 1
   BEGIN
      SET @n_ErrNo = 84452
      SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' SkipLottable02 Fail (ispGenBlankLottables)'
      GOTO Quit
   END

   -- Storer config 'SkipLottable03'
   EXECUTE nspGetRight
      @c_Facility, 
      @c_storerkey,
      @c_sku,
      'SkipLottable03',
      @b_success              OUTPUT,
      @c_SkipLottable03       OUTPUT,
      @n_ErrNo                OUTPUT,
      @c_errmsg               OUTPUT
      
   IF @b_success <> 1
   BEGIN
      SET @n_ErrNo = 84453
      SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' SkipLottable03 Fail (ispGenBlankLottables)'
      GOTO Quit
   END

   -- Storer config 'SkipLottable04'
   EXECUTE nspGetRight
      @c_Facility, 
      @c_storerkey,
      @c_sku,
      'SkipLottable04',
      @b_success              OUTPUT,
      @c_SkipLottable04       OUTPUT,
      @n_ErrNo                OUTPUT,
  @c_errmsg               OUTPUT
      
   IF @b_success <> 1
   BEGIN
      SET @n_ErrNo = 84454
      SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' SkipLottable04 Fail (ispGenBlankLottables)'
      GOTO Quit
   END

   -- Storer config 'SkipLottable05'
   EXECUTE nspGetRight
      @c_Facility, 
      @c_storerkey,
      @c_sku,
      'SkipLottable05',
      @b_success              OUTPUT,
      @c_SkipLottable05       OUTPUT,
      @n_ErrNo                OUTPUT,
      @c_errmsg               OUTPUT
      
   IF @b_success <> 1
   BEGIN
      SET @n_ErrNo = 84455
      SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' SkipLottable05 Fail (ispGenBlankLottables)'
      GOTO Quit
   END
   
      -- Storer config 'SkipLottable06'
   EXECUTE nspGetRight
      @c_Facility, 
      @c_storerkey,
      @c_sku,
      'SkipLottable06',
      @b_success              OUTPUT,
      @c_SkipLottable06       OUTPUT,
      @n_ErrNo                OUTPUT,
      @c_Errmsg               OUTPUT
      
   IF @b_success <> 1
   BEGIN
      SET @n_ErrNo = 84451
      SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' SkipLottable06 Fail (ispGenBlankLottables)'
      GOTO Quit
   END
   
   -- Storer config 'SkipLottable07'
   EXECUTE nspGetRight
      @c_Facility, 
      @c_storerkey,
      @c_sku,
      'SkipLottable07',
      @b_success              OUTPUT,
      @c_SkipLottable07       OUTPUT,
      @n_ErrNo                OUTPUT,
      @c_Errmsg               OUTPUT
      
   IF @b_success <> 1
   BEGIN
      SET @n_ErrNo = 84452
      SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' SkipLottable07 Fail (ispGenBlankLottables)'
      GOTO Quit
   END

   -- Storer config 'SkipLottable08'
   EXECUTE nspGetRight
      @c_Facility, 
      @c_storerkey,
      @c_sku,
      'SkipLottable08',
      @b_success              OUTPUT,
      @c_SkipLottable08       OUTPUT,
      @n_ErrNo                OUTPUT,
      @c_errmsg               OUTPUT
      
   IF @b_success <> 1
   BEGIN
      SET @n_ErrNo = 84453
      SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' SkipLottable08 Fail (ispGenBlankLottables)'
      GOTO Quit
   END

   -- Storer config 'SkipLottable09'
   EXECUTE nspGetRight
      @c_Facility, 
      @c_storerkey,
      @c_sku,
      'SkipLottable09',
      @b_success              OUTPUT,
      @c_SkipLottable09       OUTPUT,
      @n_ErrNo                OUTPUT,
      @c_errmsg               OUTPUT
      
   IF @b_success <> 1
   BEGIN
      SET @n_ErrNo = 84454
      SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' SkipLottable09 Fail (ispGenBlankLottables)'
      GOTO Quit
   END

   -- Storer config 'SkipLottable10'
   EXECUTE nspGetRight
      @c_Facility, 
      @c_storerkey,
      @c_sku,
      'SkipLottable10',
      @b_success              OUTPUT,
      @c_SkipLottable10       OUTPUT,
      @n_ErrNo                OUTPUT,
      @c_errmsg               OUTPUT
      
   IF @b_success <> 1
   BEGIN
      SET @n_ErrNo = 84455
      SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' SkipLottable10 Fail (ispGenBlankLottables)'
      GOTO Quit
   END
      -- Storer config 'SkipLottable11'
   EXECUTE nspGetRight
      @c_Facility, 
      @c_storerkey,
      @c_sku,
      'SkipLottable11',
      @b_success              OUTPUT,
      @c_SkipLottable11       OUTPUT,
      @n_ErrNo                OUTPUT,
      @c_Errmsg               OUTPUT
      
   IF @b_success <> 1
   BEGIN
      SET @n_ErrNo = 84451
      SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' SkipLottable11 Fail (ispGenBlankLottables)'
      GOTO Quit
   END
   
   -- Storer config 'SkipLottable12'
   EXECUTE nspGetRight
      @c_Facility, 
      @c_storerkey,
      @c_sku,
      'SkipLottable12',
      @b_success              OUTPUT,
      @c_SkipLottable12       OUTPUT,
      @n_ErrNo                OUTPUT,
      @c_Errmsg               OUTPUT
      
   IF @b_success <> 1
   BEGIN
      SET @n_ErrNo = 84452
      SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' SkipLottable12 Fail (ispGenBlankLottables)'
      GOTO Quit
   END

   -- Storer config 'SkipLottable13'
   EXECUTE nspGetRight
      @c_Facility, 
      @c_storerkey,
      @c_sku,
      'SkipLottable13',
      @b_success              OUTPUT,
      @c_SkipLottable13       OUTPUT,
      @n_ErrNo                OUTPUT,
      @c_errmsg               OUTPUT
      
   IF @b_success <> 1
   BEGIN
      SET @n_ErrNo = 84453
      SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' SkipLottable13 Fail (ispGenBlankLottables)'
      GOTO Quit
   END

   -- Storer config 'SkipLottable14'
   EXECUTE nspGetRight
      @c_Facility, 
      @c_storerkey,
      @c_sku,
      'SkipLottable14',
      @b_success              OUTPUT,
      @c_SkipLottable14       OUTPUT,
      @n_ErrNo                OUTPUT,
      @c_errmsg               OUTPUT
      
   IF @b_success <> 1
   BEGIN
      SET @n_ErrNo = 84454
      SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' SkipLottable14 Fail (ispGenBlankLottables)'
      GOTO Quit
   END

   -- Storer config 'SkipLottable15'
   EXECUTE nspGetRight
      @c_Facility, 
      @c_storerkey,
      @c_sku,
      'SkipLottable15',
      @b_success              OUTPUT,
      @c_SkipLottable15       OUTPUT,
      @n_ErrNo                OUTPUT,
      @c_errmsg               OUTPUT
      
   IF @b_success <> 1
   BEGIN
      SET @n_ErrNo = 84455
      SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' SkipLottable15 Fail (ispGenBlankLottables)'
      GOTO Quit
   END

   SET @c_Lottable01 = CASE WHEN ISNULL( @c_SkipLottable01, '') = '1' THEN '' ELSE @c_Lottable01 END
   SET @c_Lottable02 = CASE WHEN ISNULL( @c_SkipLottable02, '') = '1' THEN '' ELSE @c_Lottable02 END
   SET @c_Lottable03 = CASE WHEN ISNULL( @c_SkipLottable03, '') = '1' THEN '' ELSE @c_Lottable03 END
   SET @dt_Lottable04 = CASE WHEN ISNULL( @c_SkipLottable04, '') = '1' THEN '' ELSE @dt_Lottable04 END
   SET @dt_Lottable05 = CASE WHEN ISNULL( @c_SkipLottable05, '') = '1' THEN '' ELSE @dt_Lottable05 END
   SET @c_Lottable06 = CASE WHEN ISNULL( @c_SkipLottable06, '') = '1' THEN '' ELSE @c_Lottable06 END
   SET @c_Lottable07 = CASE WHEN ISNULL( @c_SkipLottable07, '') = '1' THEN '' ELSE @c_Lottable07 END
   SET @c_Lottable08 = CASE WHEN ISNULL( @c_SkipLottable08, '') = '1' THEN '' ELSE @c_Lottable08 END
   SET @c_Lottable09 = CASE WHEN ISNULL( @c_SkipLottable09, '') = '1' THEN '' ELSE @c_Lottable09 END
   SET @c_Lottable10 = CASE WHEN ISNULL( @c_SkipLottable10, '') = '1' THEN '' ELSE @c_Lottable10 END
   SET @c_Lottable11 = CASE WHEN ISNULL( @c_SkipLottable11, '') = '1' THEN '' ELSE @c_Lottable11 END
   SET @c_Lottable12 = CASE WHEN ISNULL( @c_SkipLottable12, '') = '1' THEN '' ELSE @c_Lottable12 END
   SET @dt_Lottable13 = CASE WHEN ISNULL( @c_SkipLottable13, '') = '1' THEN '' ELSE @dt_Lottable13 END
   SET @dt_Lottable14 = CASE WHEN ISNULL( @c_SkipLottable14, '') = '1' THEN '' ELSE @dt_Lottable14 END
   SET @dt_Lottable15 = CASE WHEN ISNULL( @c_SkipLottable15, '') = '1' THEN '' ELSE @dt_Lottable15 END

Quit:

END  

GO