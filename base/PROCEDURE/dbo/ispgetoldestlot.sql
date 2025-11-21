SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************/
/* Stored Procedure: ispGetOldestLot                                        */
/* Creation Date:                                                           */
/* Copyright: LFL                                                           */
/* Written by:                                                              */
/*                                                                          */
/* Purpose:                                                                 */
/*                                                                          */
/* Called By:                                                               */
/*                                                                          */
/* PVCS Version: 1.0                                                        */
/*                                                                          */
/* Version: 7.0                                                             */
/*                                                                          */
/* Data Modifications:                                                      */
/*                                                                          */
/* Updates:                                                                 */  
/* Date         Author   Ver  Purposes                                      */  
/* 06-Jul-2017  NJOW01   1.0  WMS-2291 Retrun include receipt type 'RGR' for*/
/*                            extract oldest lot5 by matching lot1-4        */
/****************************************************************************/

-- Purpose: Get Oldest Lot From Inventory 
CREATE PROC [dbo].[ispGetOldestLot]
               @c_RecType      NVARCHAR(10) 
,              @c_Facility     NVARCHAR(5) 
,              @c_StorerKey    NVARCHAR(15)                
,              @c_SKU          NVARCHAR(20)
,              @c_Lottable01   NVARCHAR(18)    OUTPUT 
,              @c_Lottable02   NVARCHAR(18)    OUTPUT 
,              @c_Lottable03   NVARCHAR(18)    OUTPUT 
,              @d_Lottable04   datetime        OUTPUT 
,              @d_Lottable05   datetime        OUTPUT 
,              @c_lottable06   NVARCHAR(30) = '' OUTPUT		 
,              @c_lottable07   NVARCHAR(30) = '' OUTPUT	
,              @c_lottable08   NVARCHAR(30) = '' OUTPUT	
,              @c_lottable09   NVARCHAR(30) = '' OUTPUT	
,              @c_lottable10   NVARCHAR(30) = '' OUTPUT	
,              @c_lottable11   NVARCHAR(30) = '' OUTPUT	
,              @c_lottable12   NVARCHAR(30) = '' OUTPUT		
,              @d_lottable13   datetime = NULL OUTPUT		
,              @d_lottable14   datetime = NULL OUTPUT		
,              @d_lottable15   datetime = NULL OUTPUT
,              @b_Success      int             OUTPUT
,              @n_err          int             OUTPUT
,              @c_errmsg       NVARCHAR(250)   OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT TOP 1 
          @c_Lottable01 = ISNULL(A.Lottable01, ''), 
          @c_Lottable02 = ISNULL(A.Lottable02, ''),
          @c_Lottable03 = ISNULL(A.Lottable03, ''),
          @d_Lottable04 = A.Lottable04, 
          @d_Lottable05 = A.Lottable05,
          @c_Lottable06 = ISNULL(A.Lottable06, ''), 
          @c_Lottable07 = ISNULL(A.Lottable07, ''),
          @c_Lottable08 = ISNULL(A.Lottable08, ''),
          @c_Lottable09 = ISNULL(A.Lottable09, ''), 
          @c_Lottable10 = ISNULL(A.Lottable10, ''),
          @c_Lottable11 = ISNULL(A.Lottable11, ''),
          @c_Lottable12 = ISNULL(A.Lottable12, ''), 
          @d_Lottable13 = A.Lottable13, 
          @d_Lottable14 = A.Lottable14,
          @d_Lottable15 = A.Lottable15
   FROM  LOTATTRIBUTE A (NOLOCK)
   JOIN  LOTxLOCxID C (NOLOCK) ON (A.LOT = C.LOT) 
   JOIN  LOC B (NOLOCK) ON (B.LOC = C.LOC) 
   WHERE A.STORERKEY = @c_StorerKey
   AND   A.SKU = @c_Sku 
   AND   C.QTY > 0
   AND   B.Facility = @c_Facility 
   ORDER BY A.Lottable04, A.Lottable05

   IF @@ROWCOUNT = 0 
      SELECT @b_Success = 0 
   ELSE
      SELECT @b_Success = 1

   DECLARE @c_Lottable05Label NVARCHAR(20)
   
   
   -- SOS 3333 for HK
   -- for all return receipts (ERR, GRN types), the receipt date (Lottable05) of each sku will be defaulted to 1 day
   -- before the oldest date in the system with the same lot01, lot02, lot03, lot04.
   IF @c_RecType in ('ERR','GRN','RGR')  --NJOW01
   BEGIN
      SELECT @c_Lottable05Label = Lottable05Label 
      FROM   SKU WITH (NOLOCK) 
      WHERE  StorerKey = @c_storerkey 
      AND    SKU = @c_sku
         
      IF @c_Lottable05Label = 'RCP_DATE'
      BEGIN
         IF @d_Lottable04 <= '01/01/1900' OR @d_Lottable04 IS NULL
         BEGIN
            -- Change by June 10.Jul.03 SOS12281
            SELECT @d_Lottable05 = isnull(min(lotattribute.Lottable05), CONVERT(DATETIME, CONVERT(CHAR(20), getdate(), 106)))
            from lotattribute (nolock)
            where sku = @c_sku
            and storerkey = @c_storerkey
            and Lottable01 = @c_Lottable01
            and Lottable02 = @c_Lottable02
            and Lottable03 = @c_Lottable03
         END
         ELSE
         BEGIN
            -- Change by June 10.Jul.03 SOS12281
            select @d_Lottable05 = isnull(min(lotattribute.Lottable05), CONVERT(DATETIME, CONVERT(CHAR(20), getdate(), 106)))
            from lotattribute (nolock)
            where sku = @c_sku
            and storerkey = @c_storerkey
            and Lottable01 = @c_Lottable01
            and Lottable02 = @c_Lottable02
            and Lottable03 = @c_Lottable03
            and convert(char(8), Lottable04) = convert(char(8), @d_Lottable04)
         END               
      END 
   END    -- END SOS 3333
END -- Procedure 

GO