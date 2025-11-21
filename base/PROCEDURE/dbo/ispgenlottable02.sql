SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispGenLottable02                                   */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* 20-May-2014  TKLIM      1.1   Added Lottables 06-15                  */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenLottable02]  
   @c_Storerkey         NVARCHAR(15),  
   @c_Sku               NVARCHAR(20),  
   @c_Lottable01Value   NVARCHAR(18),  
   @c_Lottable02Value   NVARCHAR(18),  
   @c_Lottable03Value   NVARCHAR(18),  
   @dt_Lottable04Value  DATETIME,  
   @dt_Lottable05Value  DATETIME,  
   @c_Lottable06Value   NVARCHAR(30) = '',
   @c_Lottable07Value   NVARCHAR(30) = '',
   @c_Lottable08Value   NVARCHAR(30) = '',
   @c_Lottable09Value   NVARCHAR(30) = '',
   @c_Lottable10Value   NVARCHAR(30) = '',
   @c_Lottable11Value   NVARCHAR(30) = '',
   @c_Lottable12Value   NVARCHAR(30) = '',
   @dt_Lottable13Value  DATETIME = NULL,
   @dt_Lottable14Value  DATETIME = NULL,
   @dt_Lottable15Value  DATETIME = NULL,
   @c_Lottable01        NVARCHAR(18) OUTPUT,
   @c_Lottable02        NVARCHAR(18) OUTPUT,
   @c_Lottable03        NVARCHAR(18) OUTPUT,
   @dt_Lottable04       DATETIME OUTPUT,
   @dt_Lottable05       DATETIME OUTPUT,
   @c_Lottable06        NVARCHAR(30) = '' OUTPUT,
   @c_Lottable07        NVARCHAR(30) = '' OUTPUT,
   @c_Lottable08        NVARCHAR(30) = '' OUTPUT,
   @c_Lottable09        NVARCHAR(30) = '' OUTPUT,
   @c_Lottable10        NVARCHAR(30) = '' OUTPUT,
   @c_Lottable11        NVARCHAR(30) = '' OUTPUT,
   @c_Lottable12        NVARCHAR(30) = '' OUTPUT,
   @dt_Lottable13       DATETIME = NULL   OUTPUT,
   @dt_Lottable14       DATETIME = NULL   OUTPUT,
   @dt_Lottable15       DATETIME = NULL   OUTPUT,
   @b_Success           INT = 1  OUTPUT,  
   @n_ErrNo             INT = 0  OUTPUT,  
   @c_Errmsg            NVARCHAR(250) = '' OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_WARNINGS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue     INT,  
           @b_debug        INT  
  
   SELECT @n_continue = 1, @b_success = 1, @n_ErrNo = 0, @b_debug = 0  
--   SELECT @c_Lottable01  = '*' + substring( @c_Lottable01Value, 1, 16) + '*',  
--    @c_Lottable02  = '*' + substring( @c_Lottable02Value, 1, 16) + '*',  
--    @c_Lottable03  = '*' + substring( @c_Lottable03Value, 1, 16) + '*',  
--    @dt_Lottable04 = @dt_Lottable04Value + 1,  
--    @dt_Lottable05 = @dt_Lottable05Value + 1  
--   SELECT @c_Lottable02 = '2----------------2'  
   --if rdt.rdtIsValidDate( @c_Lottable02) = 0 --fail 
    
   if rdt.rdtIsValidDate( @c_Lottable02) = 0 --fail  
   begin  
      set @b_success = 0  
      set @n_ErrNo = 63360  
      set @c_Errmsg = 'post error'  
   end  
   else  
      --SET @dt_Lottable04 =  CONVERT( NVARCHAR( 10), @c_Lottable02, 120)  
    SET @dt_Lottable04 = CONVERT( datetime, LEFT( @c_Lottable02, 10))  
  
END -- End Procedure  
  

GO