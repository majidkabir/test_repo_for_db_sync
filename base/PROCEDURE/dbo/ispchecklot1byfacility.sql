SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger:  ispCheckLot1ByFacility                                     */
/* Creation Date: 30-Nov-2007                                           */
/* Copyright: IDS                                                       */
/* Written by: Vicky                                         				*/
/*                                                                      */
/* Purpose:  Check Whether Receiptdetail.Lottable01 is 'CAN' or ''      */
/*           when Facility = 109. If Lottable01 is not '' but not 'CAN' */
/*           update Lottable01 = CAN                                    */
/*                                                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                   	*/
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Who      Purpose                                        */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispCheckLot1ByFacility]
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
   @n_Err              int = 0  OUTPUT,
   @c_Errmsg           NVARCHAR(250) = '' OUTPUT,
   @c_Sourcekey        NVARCHAR(10) = '',  -- (Vicky01)
   @c_Sourcetype       NVARCHAR(20) = '',  -- (Vicky01)
   @c_LottableLabel    NVARCHAR(20) = ''   -- (Vicky01)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF

   DECLARE 
      @c_Lottable01Label   NVARCHAR( 20),
      @c_Facility          NVARCHAR( 5),
      @c_sValue            NVARCHAR( 1)


   DECLARE @n_continue     INT,
           @b_debug        INT

   SELECT @n_continue = 1, @b_success = 1, @n_Err = 0, @b_debug = 0
   SELECT @c_Lottable01  = '',
			 @c_Lottable02  = '',
			 @c_Lottable03  = '',
			 @dt_Lottable04 = NULL,
			 @dt_Lottable05 = NULL

   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN 
      SELECT @c_Facility = RTRIM(Facility)
      FROM Receipt WITH (NOLOCK)
		WHERE Storerkey = RTRIM(@c_Storerkey)
		AND   ReceiptKey = @c_Sourcekey


      SELECT @c_sValue = RTRIM(sValue)
      FROM StorerConfig WITH (NOLOCK)
      WHERE Storerkey = @c_Storerkey
      AND   Configkey = 'UpdateLot1ToCAN'


	   IF @b_debug = 1
	   BEGIN
         SELECT '@c_Facility', @c_Facility
	   END

      IF @c_Facility = '109' AND ISNULL(@c_Lottable01Value, '') <> '' AND @c_sValue = '1'
      BEGIN
         SELECT @n_continue = 1
      END
      ELSE 
      BEGIN
         SET @n_continue = 3
         SET @b_Success = 1
      END         
   END

   -- Check Lottable01 
   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN 
     IF @c_Lottable01Value <> 'CAN'
     BEGIN
      SELECT @c_Lottable01 = 'CAN'
     END

      IF @b_debug = 1
      BEGIN
         SELECT '@c_Lottable01', @c_Lottable01
      END
   END
      
QUIT:
END -- End Procedure

GO