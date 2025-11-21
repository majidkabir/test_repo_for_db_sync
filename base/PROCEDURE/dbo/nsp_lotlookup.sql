SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************/
/* Store Procedure: nsp_LotLookup                                           */
/* Creation Date:                                                           */
/* Copyright: IDS                                                           */
/* Written by:                                                              */
/*                                                                          */
/* Purpose:  lookup Lot Number                                              */
/*                                                                          */
/* Input Parameters: @c_StorerKey, @c_Sku, @c_Lottable01, @c_Lottable02,    */
/*                   @c_Lottable03, @c_Lottable04, @c_Lottable05            */
/*                                                                          */
/* Output Parameters: @c_Lot                                                */
/*                                                                          */
/* Called By: nspItrnAddDepositCheck                                        */
/*                                                                          */
/* PVCS Version: 1.1                                                        */
/*                                                                          */
/* Version: 5.4                                                             */
/*                                                                          */
/* Data Modifications:                                                      */
/*                                                                          */
/* Updates:                                                                 */
/* Date         Author    Ver.  Purposes                                    */
/* 07-May-2012  Leong     1.1   SOS# 243646 - Revise Logic                  */
/* 24-Apr-2012  CSCHONG   1.2   Add Lottable06-15 (CS01)                    */
/* 27-Jul-2017  TLTING    1.3   SET Option                                  */
/****************************************************************************/

CREATE PROC [dbo].[nsp_LotLookup]
     @c_StorerKey  NVARCHAR(15)
   , @c_Sku        NVARCHAR(20)
   , @c_Lottable01 NVARCHAR(18) = ''
   , @c_Lottable02 NVARCHAR(18) = ''
   , @c_Lottable03 NVARCHAR(18) = ''
   , @c_Lottable04 DateTime  = NULL
   , @c_Lottable05 DateTime  = NULL
	, @c_Lottable06 NVARCHAR(30) = ''       --(CS01)
   , @c_Lottable07 NVARCHAR(30) = ''       --(CS01)
   , @c_Lottable08 NVARCHAR(30) = '' 	    --(CS01)
	, @c_Lottable09 NVARCHAR(30) = ''		 --(CS01)
   , @c_Lottable10 NVARCHAR(30) = ''  	    --(CS01)
   , @c_Lottable11 NVARCHAR(30) = ''		 --(CS01)
	, @c_Lottable12 NVARCHAR(30) = ''		 --(CS01)
	, @c_Lottable13 DateTime = NULL			 --(CS01)	
   , @c_Lottable14 DateTime = NULL			 --(CS01)
	, @c_Lottable15 DateTime = NULL			 --(CS01)	
   , @c_Lot         NVARCHAR(10)   OUTPUT
   , @b_Success     Int        OUTPUT
   , @n_err         Int        OUTPUT
   , @c_errmsg      NVARCHAR(250)  OUTPUT
   , @b_resultset   Int        = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue   Int
         , @n_starttcnt  Int        -- Holds the current transaction count
         , @c_preprocess NVARCHAR(250)  -- preprocess
         , @c_pstprocess NVARCHAR(250)  -- post process
         , @n_err2       Int        -- For Additional Error Detection

   SELECT @n_continue = 1, @b_success = 0, @n_err = 0, @c_errmsg = '', @n_starttcnt = @@TRANCOUNT
   /* #INCLUDE <SPLTLKUP1.SQL> */

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- SOS# 243646 (Start)
      -- SELECT @c_Lot = (SELECT LOT FROM LOTATTRIBUTE WHERE
      -- lottable01 = ISNULL(@c_Lottable01, ' ') AND
      -- lottable02 = ISNULL(@c_Lottable02, ' ') AND
      -- lottable03 = ISNULL(@c_Lottable03, ' ') AND
      -- lottable04=@c_Lottable04 AND
      -- lottable05=@c_Lottable05 AND
      -- sku=@c_Sku AND
      -- storerkey=@c_StorerKey )
		/*CS01 Start*/
      SELECT @c_Lot = ( SELECT TOP 1 LOT FROM LOTATTRIBUTE WITH (NOLOCK)
                        WHERE Lottable01 = ISNULL(@c_Lottable01, '')
                        AND Lottable02 = ISNULL(@c_Lottable02, '')
                        AND Lottable03 = ISNULL(@c_Lottable03, '')
                        AND Lottable04 = @c_Lottable04
                        AND Lottable05 = @c_Lottable05
								AND Lottable06 = ISNULL(@c_Lottable06, '')       
                        AND Lottable07 = ISNULL(@c_Lottable07, '')		 
                        AND Lottable08 = ISNULL(@c_Lottable08, '')		  
								AND Lottable09 = ISNULL(@c_Lottable09, '')		  
                        AND Lottable10 = ISNULL(@c_Lottable10, '')		  
                        AND Lottable11 = ISNULL(@c_Lottable11, '')		  
								AND Lottable12 = ISNULL(@c_Lottable12, '')		  
								AND Lottable13 = @c_Lottable13						 
								AND Lottable14 = @c_Lottable14						  
                        AND Lottable15 = @c_Lottable15						  
                        AND Sku = @c_Sku
                        AND Storerkey = @c_StorerKey
                        ORDER BY LOT )
      -- SOS# 243646 (End)
		/*CS01 End*/
      IF @@rowcount <> 1
      BEGIN
         SELECT @c_Lot = NULL, @b_success = 1
         SELECT @n_err = 61100
         SELECT @c_errmsg = 'NSQL ' + CONVERT(Char(5),@n_err) + ': Too Many Rows OR No Rows Returned From LotAttribute Lookup. (nsp_LotLookup) '
      END
      ELSE
      BEGIN
         SELECT @b_success = 1
      END
   END -- @n_continue =1 OR @n_continue=2

   /* #INCLUDE <SPLTLKUP2.SQL> */
   IF @b_resultset = 1
   BEGIN
      SELECT @c_Lot, @b_Success, @n_err, @c_errmsg
   END
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_LotLookup'
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