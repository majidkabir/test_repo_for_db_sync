SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP:  ispPopulateToASN_CONSORD                                        */
/* Creation Date: 30-Jun-2005                                           */
/* Copyright: IDS                                                       */
/* Written by:                                              				*/
/*                                                                      */
/* Purpose:                                                             */
/*				                                                  				*/		
/*                                                                      */
/* Called By:                                       							*/
/*                                                                      */
/* PVCS Version: 1.0                                                   	*/
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/*	06-Sep-2005  Shong     Bug Fix                                       */
/* 29-APR-2014  CSCHONG   Add Lottable06-15 (CS01)                      */
/************************************************************************/
CREATE PROC [dbo].[nsp_LotLookUpQtyAvailable]
               @c_storerkey    NVARCHAR(15)
,              @c_sku          NVARCHAR(20)
,              @c_lottable01   NVARCHAR(18) = '' 
,              @c_lottable02   NVARCHAR(18) = ''
,              @c_lottable03   NVARCHAR(18) = ''
,              @c_lottable04   datetime = NULL
,              @c_lottable05   datetime = NULL
,              @c_lottable06   NVARCHAR(30) = ''		--(CS01)
,              @c_lottable07   NVARCHAR(30) = '' 	   --(CS01)
,              @c_lottable08   NVARCHAR(30) = ''		--(CS01)
,              @c_lottable09   NVARCHAR(30) = ''		--(CS01)
,              @c_lottable10   NVARCHAR(30) = ''		--(CS01)
,              @c_lottable11   NVARCHAR(30) = ''		--(CS01)
,              @c_lottable12   NVARCHAR(30) = ''		--(CS01)
,              @c_lottable13   datetime = NULL			--(CS01)
,              @c_lottable14   datetime = NULL			--(CS01)
,              @c_lottable15   datetime = NULL			--(CS01)
,              @c_lot          NVARCHAR(10)   OUTPUT
,              @b_Success      int        OUTPUT
,              @n_err          int        OUTPUT
,              @c_errmsg       NVARCHAR(250)  OUTPUT
,              @b_resultset    int       = 0
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
DECLARE
       @n_continue int             
,      @n_starttcnt int         -- Holds the current transaction count
,      @c_preprocess NVARCHAR(250)  -- preprocess
,      @c_pstprocess NVARCHAR(250)  -- post process
,      @n_err2 int              -- For Additional Error Detection
SELECT @n_continue=1, @b_success=0, @n_err=0,@c_errmsg='',@n_starttcnt=@@TRANCOUNT
     /* #INCLUDE <SPLTLKUP1.SQL> */     

DECLARE @c_Condition NVARCHAR(225)

IF @n_continue =1 or @n_continue=2
BEGIN
   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) <> '' AND @c_Lottable01 IS NOT NULL
   BEGIN
      SELECT @c_Condition = " AND LOTTABLE01 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) + "'"
   END
   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> '' AND @c_Lottable02 IS NOT NULL
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE02 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) + "'"
   END
   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) <> '' AND @c_Lottable03 IS NOT NULL
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE03 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) + "'"
   END
   IF @c_Lottable04 IS NOT NULL
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE04 = N'" + CONVERT(CHAR(20), @c_Lottable04) + "'"
   END
   IF @c_Lottable05 IS NOT NULL
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE05 = N'" + CONVERT(CHAR(20), @c_Lottable05) + "'"
   END
	/*CS01 Start*/
	IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable06)) <> '' AND @c_Lottable06 IS NOT NULL
   BEGIN
      SELECT @c_Condition = " AND LOTTABLE06 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable06)) + "'"
   END
	IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable07)) <> '' AND @c_Lottable07 IS NOT NULL
   BEGIN
      SELECT @c_Condition = " AND LOTTABLE07 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable07)) + "'"
   END
   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable08)) <> '' AND @c_Lottable08 IS NOT NULL
   BEGIN
      SELECT @c_Condition = " AND LOTTABLE08 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable08)) + "'"
   END
   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable09)) <> '' AND @c_Lottable09 IS NOT NULL
   BEGIN
      SELECT @c_Condition = " AND LOTTABLE09 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable09)) + "'"
   END
   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable10)) <> '' AND @c_Lottable10 IS NOT NULL
   BEGIN
      SELECT @c_Condition = " AND LOTTABLE10 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable10)) + "'"
   END
	IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable11)) <> '' AND @c_Lottable11 IS NOT NULL
   BEGIN
      SELECT @c_Condition = " AND LOTTABLE11 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable11)) + "'"
   END
	IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable12)) <> '' AND @c_Lottable12 IS NOT NULL
   BEGIN
      SELECT @c_Condition = " AND LOTTABLE12 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable12)) + "'"
   END
	IF @c_Lottable13 IS NOT NULL
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE13= N'" + CONVERT(CHAR(20), @c_Lottable13) + "'"
   END
	IF @c_Lottable14 IS NOT NULL
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE14 = N'" + CONVERT(CHAR(20), @c_Lottable14) + "'"
   END
   IF @c_Lottable15 IS NOT NULL
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE15 = N'" + CONVERT(CHAR(20), @c_Lottable15) + "'"
   END
	/*CS01 End*/
   
   -- 06-Sep-2005  Shong
   EXEC ("DECLARE CURSOR_LOT CURSOR READ_ONLY FOR SELECT LOT.LOT FROM LOTATTRIBUTE (NOLOCK), LOT (NOLOCK) " +
            " WHERE LOT.SKU = N'" + @c_SKU + "'" +
            " AND LOT.STORERKEY = N'" + @c_storerkey + "'" 
            + " AND LOT.LOT = LOTATTRIBUTE.LOT "
            + " AND (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD) > 0 "
            + @c_Condition )


   OPEN CURSOR_LOT


   IF @@CURSOR_ROWS = -1
   BEGIN
      SELECT @c_lot=NULL, @b_success=1  
      SELECT @n_err = 61100
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Rows Returned From LotAttribute Lookup. (nsp_LotLookUpQtyAvailable)"
      END
   ELSE
   BEGIN
      SELECT @b_success=1
   END

   FETCH NEXT FROM CURSOR_LOT INTO @c_LOT
   CLOSE CURSOR_LOT
   DEALLOCATE CURSOR_LOT


END -- @n_continue =1 or @n_continue=2
     /* #INCLUDE <SPLTLKUP2.SQL> */
IF @b_resultset = 1
BEGIN
   SELECT @c_lot, @b_Success, @n_err, @c_errmsg
END
IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
   SELECT @b_success = 0
   execute nsp_logerror @n_err, @c_errmsg, "nsp_LotLookUpQtyAvailable"
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   RETURN
END
ELSE
   BEGIN
      SELECT @b_success = 1
      RETURN
   END
END


GO