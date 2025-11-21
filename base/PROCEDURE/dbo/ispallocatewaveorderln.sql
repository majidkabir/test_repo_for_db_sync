SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispAllocateWaveOrderLn                             */
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
/* 20-May-2014  TKLIM      1.0   Added Lottables 06-15                  */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispAllocateWaveOrderLn] (
   @c_WaveKey     NVARCHAR(10), 
   @c_StorerKey   NVARCHAR(15), 
   @c_SKU         NVARCHAR(20), 
   @c_Lottable01  NVARCHAR(18),
   @c_Lottable02  NVARCHAR(18),
   @c_Lottable03  NVARCHAR(18),
   @c_Lottable06  NVARCHAR(30) = '' ,
   @c_Lottable07  NVARCHAR(30) = '' ,
   @c_Lottable08  NVARCHAR(30) = '' ,
   @c_Lottable09  NVARCHAR(30) = '' ,
   @c_Lottable10  NVARCHAR(30) = '' ,
   @c_Lottable11  NVARCHAR(30) = '' ,
   @c_Lottable12  NVARCHAR(30) = '' ,
   @n_UCC_Qty     INT )
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
DECLARE @c_OrderKey        NVARCHAR(10),
        @c_OrderLineNumber NVARCHAR(5),
        @c_ExecStatement   NVARCHAR(3000),
        @n_Qty             int 

SELECT @c_OrderKey = ''

WHILE 1=1 AND @n_UCC_Qty > 0 
BEGIN
   SELECT @c_OrderKey = MIN(OrderKey) 
   FROM   WaveOrderLn (NOLOCK)
   WHERE  WaveKey = @c_WaveKey
   AND    OrderKey > @c_OrderKey
   AND    StorerKey = @c_StorerKey
   AND    Lottable01 = @c_Lottable01
   AND    Lottable02 = @c_Lottable02
   AND    Lottable03 = @c_Lottable03
   AND    Lottable06 = @c_Lottable06
   AND    Lottable07 = @c_Lottable07
   AND    Lottable08 = @c_Lottable08
   AND    Lottable09 = @c_Lottable09
   AND    Lottable10 = @c_Lottable10
   AND    Lottable11 = @c_Lottable11
   AND    Lottable12 = @c_Lottable12
   AND    SKU = @c_SKU 

   IF dbo.fnc_RTrim(@c_OrderKey) IS NULL OR dbo.fnc_RTrim(@c_OrderKey) = ''
      BREAK

   SELECT @c_OrderLineNumber = ''

   WHILE 1=1 AND @n_UCC_Qty > 0 
   BEGIN
      SELECT @c_OrderLineNumber = MIN(OrderLineNumber) 
      FROM   WaveOrderLn (NOLOCK)
      WHERE  WaveKey = @c_WaveKey
      AND    StorerKey = @c_StorerKey
      AND    SKU = @c_SKU 
      AND    Lottable01 = @c_Lottable01
      AND    Lottable02 = @c_Lottable02
      AND    Lottable03 = @c_Lottable03
      AND    Lottable06 = @c_Lottable06
      AND    Lottable07 = @c_Lottable07
      AND    Lottable08 = @c_Lottable08
      AND    Lottable09 = @c_Lottable09
      AND    Lottable10 = @c_Lottable10
      AND    Lottable11 = @c_Lottable11
      AND    Lottable12 = @c_Lottable12
      AND    OrderKey = @c_OrderKey
      AND    OrderLineNumber > @c_OrderLineNumber
      AND    OpenQty > 0 
   
      IF dbo.fnc_RTrim(@c_OrderLineNumber) IS NULL OR dbo.fnc_RTrim(@c_OrderLineNumber) = ''
         BREAK

      
      SELECT @n_Qty = OpenQty 
      FROM WaveOrderLn (NOLOCK)
      WHERE OrderKey = @c_OrderKey 
      AND   OrderLineNumber = @c_OrderLineNumber 

      IF (@n_UCC_Qty > @n_Qty) OR (@n_UCC_Qty = @n_Qty)
      BEGIN      
				DELETE WaveOrderLn                   
	         WHERE OrderKey = @c_OrderKey 
	         AND   OrderLineNumber = @c_OrderLineNumber

--          UPDATE WaveOrderLn                   
--          SET OpenQty = OpenQty - @n_UCC_Qty, 
--              QtyAllocated = QtyAllocated + @n_UCC_Qty 
--          WHERE OrderKey = @c_OrderKey 
--          AND   OrderLineNumber = @c_OrderLineNumber 

         SELECT @n_UCC_Qty = @n_UCC_Qty - @n_Qty  
      END
		ELSE
      BEGIN
			UPDATE WaveOrderLn                   
         SET OpenQty = OpenQty - @n_UCC_Qty, 
             QtyAllocated = QtyAllocated + @n_UCC_Qty 
         WHERE OrderKey = @c_OrderKey 
         AND   OrderLineNumber = @c_OrderLineNumber 

--          DELETE WaveOrderLn                   
--          WHERE OrderKey = @c_OrderKey 
--          AND   OrderLineNumber = @c_OrderLineNumber 

         SELECT @n_UCC_Qty = @n_UCC_Qty - @n_Qty  
      END 
   END -- while order line 
END -- while orderkey 


GO