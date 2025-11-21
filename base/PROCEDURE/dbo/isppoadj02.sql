SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispPOADJ02                                                  */
/* Creation Date: 02-Aug-2018                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-5911 SG CPV post finalize adj update EXTERNLOTATTRIBUTE */      
/*                                                                      */
/* Called By: ispPostFinalizeADJWrapper                                 */
/*          : Storerconfig PostFinalizeADJSP                            */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 29/03/2019   NJOW01    1.0 WMS-8486 Finalize adj clear qtyreplen     */ 
/************************************************************************/
CREATE PROC [dbo].[ispPOADJ02] 
            @c_AdjustmentKey  NVARCHAR(10)
         ,  @b_Success        INT = 1  OUTPUT 
         ,  @n_err            INT = 0  OUTPUT 
         ,  @c_errmsg         NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt            INT
         , @n_Continue             INT 
         , @c_Storerkey            NVARCHAR(15)
         , @c_Sku                  NVARCHAR(20)
         , @c_ExternLot            NVARCHAR(60)
         , @dt_Lottable04          DATETIME
         , @c_Lottable07           NVARCHAR(30)
         , @c_Lottable08           NVARCHAR(30)
         , @c_Lot                  NVARCHAR(10)
         , @C_lOC                  NVARCHAR(10)
         , @c_ID                   NVARCHAR(18)
         , @n_Qty                  INT
         
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   IF @@TRANCOUNT = 0
      BEGIN TRAN
      	
   IF @n_continue IN(1,2)
   BEGIN
      DECLARE CUR_AD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT DISTINCT ADJD.Storerkey, ADJD.Sku, ADJD.Lottable04, ADJD.Lottable07, ADJD.Lottable08
      FROM ADJUSTMENT ADJ (NOLOCK)
      JOIN ADJUSTMENTDETAIL ADJD (NOLOCK) ON ADJ.Adjustmentkey = ADJD.Adjustmentkey
      JOIN CODELKUP CL (NOLOCK) ON ADJD.Reasoncode = CL.Code AND CL.Listname = 'ADJREASON'
      WHERE ADJ.Adjustmentkey = @c_AdjustmentKey
      AND ADJD.Finalizedflag = 'Y'
      AND ADJD.Qty <> 0
      AND CL.UDF01 = 'Y'
      AND ADJD.Lottable07 <> '' 
      AND ADJD.Lottable07 IS NOT NULL
      
      OPEN CUR_AD
      
      FETCH NEXT FROM CUR_AD INTO @c_Storerkey, @c_Sku, @dt_Lottable04, @c_Lottable07, @c_Lottable08

      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
      BEGIN      	
      	 SET @c_ExternLot = LTRIM(RTRIM(ISNULL(@c_Lottable07,''))) + LTRIM(RTRIM(ISNULL(@c_Lottable08,'')))
      	 
      	 IF NOT EXISTS (SELECT 1 
      	                FROM EXTERNLOTATTRIBUTE (NOLOCK) 
      	                WHERE Storerkey = @c_Storerkey
      	                AND Sku = @c_Sku
      	                AND ExternLot = @c_ExternLot)
      	 BEGIN
      	    INSERT INTO EXTERNLOTATTRIBUTE (Storerkey, Sku, ExternLot, ExternLottable04, ExternLotStatus)
      	    VALUES (@c_Storerkey, @c_Sku, @c_ExternLot, @dt_Lottable04, 'Active')
      	    
            SET @n_err = @@ERROR
            
            IF @n_err <> 0 
            BEGIN 
               SET @n_continue= 3 
               SET @n_err  = 72810
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Insert EXTERNLOTATTRIBUTE Table Failed. (ispPOADJ02)'
            END       	          	    
      	 END                     	                
      	                                   	 
         FETCH NEXT FROM CUR_AD INTO @c_Storerkey, @c_Sku, @dt_Lottable04, @c_Lottable07, @c_Lottable08
      END
      CLOSE CUR_AD
      DEALLOCATE CUR_AD    
   END
   
   --NJOW01
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE CUR_ADJLOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT ADJD.Storerkey, ADJD.Sku, ADJD.LOT, ADJD.Loc, ADJD.ID, ADJD.Qty
      FROM ADJUSTMENT ADJ (NOLOCK)
      JOIN ADJUSTMENTDETAIL ADJD (NOLOCK) ON ADJ.Adjustmentkey = ADJD.Adjustmentkey
      WHERE ADJ.Adjustmentkey = @c_AdjustmentKey
      AND ADJD.Finalizedflag = 'Y'
      AND ADJD.Qty <> 0
      
      OPEN CUR_ADJLOT
      
      FETCH NEXT FROM CUR_ADJLOT INTO @c_Storerkey, @c_Sku, @c_Lot, @c_Loc, @c_ID, @n_Qty

      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
      BEGIN
      	 UPDATE LOTXLOCXID WITH (ROWLOCK)
      	 SET QtyReplen = 0,
      	     TrafficCop = NULL
      	 WHERE Lot = @c_Lot
      	 AND Loc = @c_Loc
      	 AND ID = @c_ID
      	 AND Storerkey = @c_Storerkey
      	 AND Sku = @c_Sku
      	 AND QtyReplen > 0

         SET @n_err = @@ERROR
         
         IF @n_err <> 0 
         BEGIN 
            SET @n_continue= 3 
            SET @n_err  = 72820
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Update LOTXLOCXID Table Failed. (ispPOADJ02)'
         END       	          	    
      	           	
         FETCH NEXT FROM CUR_ADJLOT INTO @c_Storerkey, @c_Sku, @c_Lot, @c_Loc, @c_ID, @n_Qty
      END
      CLOSE CUR_ADJLOT
      DEALLOCATE CUR_ADJLOT       	
   END
   
   QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_AD') in (0 , 1)  
   BEGIN
      CLOSE CUR_AD
      DEALLOCATE CUR_AD
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPOADJ02'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO