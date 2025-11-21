SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_addpicklocation                                */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 29-APR-2014  CSCHONG       Add Lottable06-15 (CS01)                  */
/* 27-Jul-2017  TLTING   1.1  Missng nolock                             */
/************************************************************************/

CREATE PROC         [dbo].[nsp_addpicklocation]
@c_storerkey   NVARCHAR(15)
,              @c_sku         NVARCHAR(20)
,              @c_loc         NVARCHAR(10)
,              @c_lot         NVARCHAR(10)  OUTPUT
,              @b_lotattributeadded     int  OUTPUT
,              @b_lotadded    int  OUTPUT
,              @b_lotxlocxidadded  int  OUTPUT
,              @b_Success     int  OUTPUT
,              @n_err         int  OUTPUT
,              @c_errmsg NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_process NVARCHAR(250) -- this process
			, @c_preprocess NVARCHAR(250) -- preprocess
			, @c_postprocess NVARCHAR(250) -- post process
   -- Set default values for variables
   SELECT @b_success=0,
			 @n_err=0,
			 @c_errmsg='',
			 @c_process='nsp_addpicklocation',
			 @b_lotattributeadded = 0,
			 @b_lotadded = 0,
			 @b_lotxlocxidadded = 0
   -- Start Main Processing
   -- This procedure is concerned with blank lots (empty strings for character lottables and NULLs for datetimes)
   DECLARE @c_lottable01 NVARCHAR(18),
			  @c_lottable02 NVARCHAR(18),
		     @c_lottable03 NVARCHAR(18),
			  @d_lottable04 datetime,
			  @d_lottable05 datetime,
			  @b_resultset integer,
			  /*CS01 start*/
			  @c_lottable06 NVARCHAR(30),
			  @c_lottable07 NVARCHAR(30),
		     @c_lottable08 NVARCHAR(30),
			  @c_lottable09 NVARCHAR(30),
			  @c_lottable10 NVARCHAR(30),
		     @c_lottable11 NVARCHAR(30),
			  @c_lottable12 NVARCHAR(30),
			  @d_lottable13 datetime,
			  @d_lottable14 datetime,
			  @d_lottable15 datetime,
			  @c_Facility   NVARCHAR(5)
		     

   SELECT @c_lottable01 = '',
			 @c_lottable02 = '',
			 @c_lottable03 = '',
			 @d_lottable04 = NULL,
			 @d_lottable05 = NULL,
			 @c_lottable06 = '',
			 @c_lottable07 = '',
			 @c_lottable08 = '',
			 @c_lottable09 = '',
			 @c_lottable10 = '',
			 @c_lottable11 = '',
			 @c_lottable12 = '',
			 @d_lottable13 = NULL,
			 @d_lottable14 = NULL,
			 @d_lottable15 = NULL,
			 @c_Facility = ''
    /*CS01 End*/
   -- Does a LotAttribute record (with blank lottables) exist for this SKU?
   EXECUTE nsp_lotlookup
			@c_storerkey,
			@c_sku,
			@c_lottable01,
			@c_lottable02,
			@c_lottable03,
			@d_lottable04,
			@d_lottable05,
			@c_lottable06,		--(CS01)
			@c_lottable07,		--(CS01)
			@c_lottable08,		--(CS01)
			@c_lottable09,		--(CS01)
			@c_lottable10,		--(CS01)
			@c_lottable11,		--(CS01)
			@c_lottable12,		--(CS01)
			@d_lottable13,		--(CS01)
			@d_lottable14,		--(CS01)
			@d_lottable15,		--(CS01)
			@c_lot OUTPUT,
			@b_Success OUTPUT,
			@n_err OUTPUT,
			@c_errmsg OUTPUT,
			@b_resultset
   IF @@ERROR <> 0
   BEGIN
      SELECT @n_err = 83003
      -- @c_errmsg populated by stored procedure
      SELECT @c_errmsg = "NSQL83003: Error in Lot Lookup: " + @c_errmsg
      GOTO PROCRETURN
   END
   -- If a Lot Number (lotattribute with blank lottables) does not exist, we create one
   IF @c_lot IS NULL
   BEGIN
      EXECUTE nsp_lotgen
      @c_storerkey,
      @c_sku,
      @c_lottable01,
      @c_lottable02,
      @c_lottable03,
      @d_lottable04,
      @d_lottable05,
		@c_lottable06,		--(CS01)
		@c_lottable07,		--(CS01)
		@c_lottable08,		--(CS01)
		@c_lottable09,		--(CS01)
		@c_lottable10,		--(CS01)
		@c_lottable11,		--(CS01)
		@c_lottable12,		--(CS01)
		@d_lottable13,		--(CS01)
		@d_lottable14,		--(CS01)
		@d_lottable15,		--(CS01)
      @c_lot OUTPUT,
      @b_Success OUTPUT,
      @n_err OUTPUT,
      @c_errmsg OUTPUT,
      @b_resultset
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_err = 83004
         -- @c_errmsg populated by stored procedure
         SELECT @c_errmsg = "NSQL83004: Error in Lot Generation: " + @c_errmsg
         GOTO PROCRETURN
      END
      SELECT @b_lotattributeadded = 1
   END
   DECLARE @n_count integer,
   @c_id NVARCHAR(18)
   SELECT @c_id = ''
   -- Does a LotXLocXID record exist (with the above Lot and a blank ID?)
   SELECT @n_count = count(1)
   FROM LOTxLOCxID WITH (NOLOCK)
   WHERE storerkey = @c_storerkey
   AND sku = @c_sku
   AND lot = @c_lot
   AND loc = @c_loc
   AND id = @c_id
   IF @@ERROR <> 0
   BEGIN
      SELECT @n_err = 83005
      SELECT @c_errmsg = CONVERT(char(250),@@ERROR)
      SELECT @c_errmsg="NSQL83005: Pick Location Add process failed because of failed SELECT on LOTxLOCxID. (" + @c_process + ") DB MESSAGE=" + @c_errmsg + " ) "
      GOTO PROCRETURN
   END
   -- If not, then we must create one
   IF @n_count = 0
   -- So far, we have only checked/added to LotAttribute Table.
   -- If nothing exists in LOTxLOCxID, then we need to add or use
   -- LOT table information
   BEGIN
      SELECT @n_count = count(1)
      FROM LOT WITH (NOLOCK)
      WHERE storerkey = @c_storerkey
      AND sku = @c_sku
      AND lot = @c_lot
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_err = 83006
         SELECT @c_errmsg = CONVERT(char(250),@@ERROR)
         SELECT @c_errmsg="NSQL83006: Pick Location Add process failed because of failed SELECT on LOT. (" + @c_process + ") DB MESSAGE=" + @c_errmsg + " ) "
         GOTO PROCRETURN
      END
      IF @n_count = 0
      BEGIN
         -- We must also add a LOT
         INSERT LOT
         (storerkey,
         sku,
         lot)
         VALUES
         (@c_storerkey,
         @c_sku,
         @c_lot)
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_err = 83007
            SELECT @c_errmsg = convert(char(250),@@ERROR)
            SELECT @c_errmsg = "NSQL83007: Error creating LOT: " + @c_errmsg
            GOTO PROCRETURN
         END
         SELECT @b_lotadded = 1
      END
      -- Either we already had a lot or we've just inserted one.
      INSERT LOTxLOCxID
      ( storerkey, sku, lot, loc, id )
      VALUES
      ( @c_storerkey, @c_sku, @c_lot, @c_loc, @c_id )
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_err = 83008
         SELECT @c_errmsg = convert(char(250),@@ERROR)
         SELECT @c_errmsg = "NSQL83006: Error creating LotXLocXID: " + @c_errmsg
         GOTO PROCRETURN
      END
      SELECT @b_lotxlocxidadded = 1
   END
   -- End Main Processing
   -- Return Statement
   PROCRETURN:
   IF @n_err > 0
   BEGIN
      SELECT @b_success = -1
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   -- End Return Statement
END

GO