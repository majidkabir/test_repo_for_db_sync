SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP:  ispGenLottable02Pre_NikeTH                                      */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Purpose:  Generate Receiptdetail Lottable02 Default Value            */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Who      Purpose                                        */
/* 02-Jul-2007  Vicky    SOS 96822 Default lottable02 for NIKE          */
/* 30-Nov-2007  Vicky    Add Sourcekey and Sourcetype as Parameter      */
/*                       (Vicky01)                                      */
/* 13-Apr-2015  Ung      Split out from ispGenLottable02Pre_NikeCN      */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenLottable02Pre_NikeTH]
   @c_Storerkey        NVARCHAR(15),
   @c_Sku              NVARCHAR(20),
	@c_Lottable01Value  NVARCHAR(18),
	@c_Lottable02Value  NVARCHAR(18),
	@c_Lottable03Value  NVARCHAR(18),
	@dt_Lottable04Value datetime,
	@dt_Lottable05Value datetime,
	@c_Lottable01       NVARCHAR(18) OUTPUT,
	@c_Lottable02       NVARCHAR(18) OUTPUT,
	@c_Lottable03       NVARCHAR(18) OUTPUT,
	@dt_Lottable04      datetime OUTPUT,
   @dt_Lottable05      datetime OUTPUT,
   @b_Success          int = 1  OUTPUT,
   @n_ErrNo            int = 0  OUTPUT,
   @c_Errmsg           NVARCHAR(250) = '' OUTPUT,
   @c_Sourcekey        NVARCHAR(10) = '',  -- (Vicky01)
   @c_Sourcetype       NVARCHAR(20) = '',  -- (Vicky01)
   @c_LottableLabel    NVARCHAR(20) = ''   -- (Vicky01)

AS
BEGIN
	SET NOCOUNT ON
	SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF
 
   DECLARE @n_continue     INT,
           @b_debug        INT

   SELECT @n_continue = 1, @b_success = 1, @n_ErrNo = 0, @b_debug = 0

   -- For lottable02 = ISEG and POID  
   SELECT @c_Lottable02  = '01000'  
   
END -- End Procedure



GO