SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*******************************************************************/
/* Modification History:                                           */ 
/*                                                                 */
/* 06/11/2002 Leo Ng  Program rewrite for IDS version 5            */
/* 2014-Mar-21  TLTING    1.1   SQL20112 Bug                      */
/* 2014-Nov-11  CSCHONG   2.0   Add Lottable06-15 (CS01)          */             
/* *****************************************************************/

CREATE PROC    [dbo].[nspInventoryHoldResultSet]
                @c_lot          NVARCHAR(10)
 ,              @c_Loc          NVARCHAR(10)
 ,              @c_ID           NVARCHAR(18)
 ,              @c_StorerKey    NVARCHAR(15) -- Added By SHONG 11.Apr.2002
 ,              @c_SKU          NVARCHAR(20) -- Added By SHONG 11.Apr.2002
 ,              @c_lottable01   NVARCHAR(18)
 ,              @c_lottable02   NVARCHAR(18)
 ,              @c_lottable03   NVARCHAR(18)
 ,              @dt_lottable04  datetime -- IDSV5 - Leo (For V5.1 Feature; remark by Ricky)
 ,              @dt_lottable05  datetime -- IDSV5 - Leo (For V5.1 Feature; remark by Ricky)
 ,              @c_Lottable06   NVARCHAR(30)   = ''    --(CS01)
 ,              @c_Lottable07   NVARCHAR(30)   = ''    --(CS01)
 ,              @c_Lottable08   NVARCHAR(30)   = ''    --(CS01)
 ,              @c_Lottable09   NVARCHAR(30)   = ''    --(CS01)
 ,              @c_Lottable10   NVARCHAR(30)   = ''    --(CS01)
 ,              @c_Lottable11   NVARCHAR(30)   = ''    --(CS01)
 ,              @c_Lottable12   NVARCHAR(30)   = ''    --(CS01)
 ,              @dt_Lottable13  DATETIME       = NULL  --(CS01) 
 ,              @dt_Lottable14  DATETIME       = NULL  --(CS01)
 ,              @dt_Lottable15  DATETIME       = NULL  --(CS01)
 ,              @c_Status       NVARCHAR(10)
 ,              @c_Hold         NVARCHAR(1)
 ,        	    @b_Success      int OUTPUT
 ,              @n_err          int OUTPUT
 ,              @c_errmsg       NVARCHAR(250) OUTPUT
 , 		       @c_remark	     NVARCHAR(260) = '' -- SOS89194
 AS
 BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
    /* IDSV5 - Leo */
    IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_hold)) <> "1" and dbo.fnc_LTrim(dbo.fnc_RTrim(@c_hold)) <> "0"
    BEGIN
      EXECUTE nsp_logerror 78405, 
              'NSQL78405: Insert Failed On InventoryHold. Hold flag should be 1 or 0! (nspItrnAddHold)', 
              'nspInventoryHold'
      --RAISERROR 78405 'NSQL78405: Insert Failed On InventoryHold. Hold flag should be 1 or 0! (nspItrnAddHold)'
      RAISERROR ('NSQL78405: Insert Failed On InventoryHold. Hold flag should be 1 or 0! (nspItrnAddHold)', 16, 1) WITH SETERROR  -- SQL2012
      RETURN
    END
    ELSE
    BEGIN
       EXECUTE nspInventoryHoldWrapper @c_lot
       ,     @c_Loc
       ,     @c_ID
       ,     @c_StorerKey -- Added By SHONG 11.Apr.2002
       ,     @c_SKU -- Added By SHONG 11.Apr.2002
       ,     @c_lottable01
       ,     @c_lottable02
       ,     @c_lottable03
       ,     @dt_lottable04	
       ,     @dt_lottable05 
       ,     @c_Lottable06    --(CS01)
       ,     @c_Lottable07    --(CS01)
       ,     @c_Lottable08    --(CS01)
       ,     @c_Lottable09    --(CS01)
       ,     @c_Lottable10    --(CS01)
       ,     @c_Lottable11    --(CS01)
       ,     @c_Lottable12    --(CS01)
       ,     @dt_Lottable13   --(CS01) 
       ,     @dt_Lottable14   --(CS01)
       ,     @dt_Lottable15   --(CS01) 
       ,     @c_Status
       ,     @c_Hold
       ,     @b_Success OUTPUT
       ,     @n_err OUTPUT 
       ,     @c_errmsg OUTPUT
		 , 	 @c_remark -- SOS89194
    END
 END


GO