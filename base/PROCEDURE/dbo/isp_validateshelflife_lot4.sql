SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger:  isp_ValidateShelflife_Lot4                                 */
/* Creation Date: 23-Apr-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                               	   */
/*                                                                      */
/* Purpose:  Validate receiving Shelf Life on lot04(Prod Date/BBdate)   */
/*           versus lot05(current date) SOS#131650                      */
/*                                                                      */
/* PVCS Version: 1.0                                                   	*/
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 15-Jul-2009  NJOW01    1.1   This validation only trigger at ASN and */
/*                              Kitting module SOS#131650               */
/* 09-Nov-2015  SPChin    1.2   SOS356557 - Add Lottables 06-15 and Type*/
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_ValidateShelflife_Lot4]
   @c_Storerkey        NVARCHAR(15),
   @c_Sku              NVARCHAR(20),
	@c_Lottable01Value  NVARCHAR(18),
	@c_Lottable02Value  NVARCHAR(18),
	@c_Lottable03Value  NVARCHAR(18),
	@dt_Lottable04Value datetime,
	@dt_Lottable05Value datetime,
   @c_Lottable06Value  NVARCHAR(30)   = '',					--SOS356557
   @c_Lottable07Value  NVARCHAR(30)   = '',					--SOS356557
   @c_Lottable08Value  NVARCHAR(30)   = '',					--SOS356557
   @c_Lottable09Value  NVARCHAR(30)   = '',					--SOS356557
   @c_Lottable10Value  NVARCHAR(30)   = '',					--SOS356557
   @c_Lottable11Value  NVARCHAR(30)   = '',					--SOS356557
   @c_Lottable12Value  NVARCHAR(30)   = '',					--SOS356557
   @dt_Lottable13Value DATETIME       = NULL,				--SOS356557
   @dt_Lottable14Value DATETIME       = NULL,				--SOS356557
   @dt_Lottable15Value DATETIME       = NULL,				--SOS356557
	@c_Lottable01       NVARCHAR(18) OUTPUT,
	@c_Lottable02       NVARCHAR(18) OUTPUT,
	@c_Lottable03       NVARCHAR(18) OUTPUT,
	@dt_Lottable04      datetime OUTPUT,
   @dt_Lottable05      datetime OUTPUT,
   @c_Lottable06       NVARCHAR(30)   = ''     OUTPUT,	--SOS356557
   @c_Lottable07       NVARCHAR(30)   = ''     OUTPUT,	--SOS356557
   @c_Lottable08       NVARCHAR(30)   = ''     OUTPUT,	--SOS356557
   @c_Lottable09       NVARCHAR(30)   = ''     OUTPUT,	--SOS356557
   @c_Lottable10       NVARCHAR(30)   = ''     OUTPUT,	--SOS356557
   @c_Lottable11       NVARCHAR(30)   = ''     OUTPUT,	--SOS356557
   @c_Lottable12       NVARCHAR(30)   = ''     OUTPUT,	--SOS356557
   @dt_Lottable13      DATETIME       = NULL   OUTPUT,	--SOS356557
   @dt_Lottable14      DATETIME       = NULL   OUTPUT,	--SOS356557
   @dt_Lottable15      DATETIME       = NULL   OUTPUT,	--SOS356557
   @b_Success          int OUTPUT,
   @n_Err              int OUTPUT,
   @c_Errmsg           NVARCHAR(250) OUTPUT,
   @c_Sourcekey        NVARCHAR(10) = '',
   @c_Sourcetype       NVARCHAR(20) = '',
   @c_LottableLabel    NVARCHAR(20) = '',
   @c_type             NVARCHAR(10)   = ''					--SOS356557
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Lottable04Label   NVARCHAR( 20),
      		 @n_SKUShelfLife      int,
      		 @n_SKURecShelfLife   int,
      		 @dt_currdate      datetime


   DECLARE @n_continue     int,
           @b_debug        int

   SELECT @n_continue = 1, @b_success = 1, @n_Err = 0, @b_debug = 0, @c_errmsg = ''
   SELECT @dt_currdate = CONVERT(datetime,CONVERT(char(10),GETDATE(),112))

   SELECT @c_Lottable01  = '',
		      @c_Lottable02  = '',
			    @c_Lottable03  = '',
			    @dt_Lottable04 = NULL,
			    @dt_Lottable05 = NULL

	 IF @c_sourcetype <> 'RECEIPT' AND @c_sourcetype <> 'KIT'
	    SELECT @n_continue = 4

	 IF @n_continue = 1 OR @n_continue = 2
	 BEGIN
	 	  -- Will generate lottable01 only when Lottable01Label = 'GEN_WEEK'
		 	EXEC ispGenLot1ByExpiryDate
	   			@c_Storerkey,
	   			@c_Sku,
					@c_Lottable01Value,
					@c_Lottable02Value,
					@c_Lottable03Value,
					@dt_Lottable04Value,
					@dt_Lottable05Value,
					@c_Lottable06Value,		--SOS356557
   				@c_Lottable07Value,		--SOS356557
   				@c_Lottable08Value,		--SOS356557
   				@c_Lottable09Value,		--SOS356557
   				@c_Lottable10Value,		--SOS356557
   				@c_Lottable11Value,		--SOS356557
   				@c_Lottable12Value,		--SOS356557
   				@dt_Lottable13Value,		--SOS356557
   				@dt_Lottable14Value,		--SOS356557
   				@dt_Lottable15Value,		--SOS356557
					@c_Lottable01 OUTPUT,
					@c_Lottable02 OUTPUT,
					@c_Lottable03 OUTPUT,
					@dt_Lottable04 OUTPUT,
	   			@dt_Lottable05 OUTPUT,
	   			@c_Lottable06  OUTPUT,	--SOS356557
   				@c_Lottable07  OUTPUT,	--SOS356557
   				@c_Lottable08  OUTPUT,	--SOS356557
   				@c_Lottable09  OUTPUT,	--SOS356557
   				@c_Lottable10  OUTPUT,	--SOS356557
   				@c_Lottable11  OUTPUT,	--SOS356557
   				@c_Lottable12  OUTPUT,	--SOS356557
   				@dt_Lottable13 OUTPUT,	--SOS356557
   				@dt_Lottable14 OUTPUT,	--SOS356557
   				@dt_Lottable15 OUTPUT,	--SOS356557
	   			@b_Success OUTPUT,
	   			@n_Err OUTPUT,
	   			@c_Errmsg OUTPUT,
	   			@c_Sourcekey,
	   			@c_Sourcetype,
	   			@c_LottableLabel
	   	IF @c_errmsg <> ''
	   	   SELECT @n_continue = 3
	 END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
     SELECT @c_Lottable04Label = Lottable04Label,
            @n_SKUShelfLife    = ISNULL(ShelfLife,0),
            @n_SKURecShelfLife = CONVERT(int,ISNULL(susr1,0))
     FROM SKU (NOLOCK)
		 WHERE Storerkey = @c_Storerkey
		 AND   SKU = @c_Sku

	   IF @b_debug = 1
	   BEGIN
         SELECT '@c_Lottable04Label', @c_Lottable04Label
         SELECT '@n_SKUShelfLife', CONVERT(char(5), @n_SKUShelfLife)
         SELECT '@n_SKURecShelfLife', CONVERT(char(5), @n_SKURecShelfLife)
	   END

     IF @c_Lottable04Label <> 'PRODN_DATE' AND @c_Lottable04Label <> 'BB_DATE'
     BEGIN
        SET @n_continue = 3
        --SET @b_Success = 0
        SET @n_Err = 10000
        SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' SKU.Lottable04Label is not PRODN_DATE or BB_DATE. (isp_ValidateShelflife_Lot4)'
     END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
   	  IF @c_Lottable04Label = 'PRODN_DATE'
   	  BEGIN
   	  	 IF @dt_currdate > DATEADD(Day, @n_SKURecShelfLife, @dt_Lottable04Value)
   	  	    OR DATEADD(Day,1,@dt_currdate) <= @dt_Lottable04Value
   	  	 BEGIN
  				  SET @n_continue = 3
   			--	  SET @b_Success = 0
   				  SET @n_Err = 10001
   				  SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' WARNING! Validation Failed. Lottable04 does not pass the allowed limits. (isp_ValidateShelflife_Lot4)'
   	  	 END
   	  END
   	  ELSE
   	  BEGIN
   	  	 IF @dt_currdate > DATEADD(Day, @n_SKURecShelfLife-@n_SKUShelfLife, @dt_Lottable04Value)
   	  	    OR DATEADD(Day,1,@dt_currdate) <= DATEADD(Day, @n_SKUShelfLife * -1, @dt_Lottable04Value)
   	  	 BEGIN
  				  SET @n_continue = 3
   		--		  SET @b_Success = 0
   				  SET @n_Err = 10002
   				  SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' WARNING! Validation Failed. Lottable04 does not pass the allowed limits. (isp_ValidateShelflife_Lot4)'
   	  	 END
   	  END
   END

   IF @n_continue = 3
   BEGIN
	   SELECT @c_Lottable01  = '',
			      @c_Lottable02  = '',
				    @c_Lottable03  = '',
				    @dt_Lottable04 = NULL,
				    @dt_Lottable05 = NULL
   END

   IF @b_debug = 1
   BEGIN
      SELECT '@c_errmsg', @c_errmsg
      SELECT '@n_err', CONVERT(char(5), @n_err)
   END

END -- End Procedure


GO