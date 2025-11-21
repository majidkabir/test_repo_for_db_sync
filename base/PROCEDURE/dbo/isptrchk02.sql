SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispTRCHK02                                         */
/* Creation Date: 28-JUL-2022                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-20353 CN PVH finalize transfer qty validation           */
/*                                                                      */
/* Called By: Finalize Transfer                                         */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver  Purposes                                   */
/* 28-Jul-2022  NJOW    1.0  DEVOPS combine script                      */
/************************************************************************/

CREATE   PROCEDURE dbo.ispTRCHK02
   @c_TransferKey      NVARCHAR(10),
   @b_Success          INT = 1  OUTPUT,
   @n_Err              INT = 0  OUTPUT,
   @c_Errmsg           NVARCHAR(250) = '' OUTPUT
,  @c_TransferLineNumber NVARCHAR(5) = '' 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_StartTranCount INT,
           @n_Continue INT
   
   SELECT @b_Success = 1, @n_Err = 0, @c_Errmsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT  
   
   IF EXISTS(SELECT 1
             FROM TRANSFER T (NOLOCK) 
             WHERE T.TransferKey = @c_TransferKey
             AND T.Type = 'NIF')
   BEGIN
      GOTO EXIT_SP
   END
   
   SELECT T.FromStorerkey, T.Facility, TD.FromChannel, TD.FromSku, LA.Lottable07, LA.Lottable08, LOC.HostWHCode,
          SUM(TD.FromQty) AS FromQty
   INTO #TMP_TRF          
   FROM TRANSFER T (NOLOCK)
   JOIN TRANSFERDETAIL TD (NOLOCK) ON T.Transferkey = TD.Transferkey
   JOIN LOC (NOLOCK) ON TD.FromLoc = LOC.Loc
   JOIN LOTATTRIBUTE LA (NOLOCK) ON TD.FromLot = LA.Lot
   WHERE T.TransferKey = @c_Transferkey
   GROUP BY T.FromStorerkey, T.Facility, TD.FromChannel, TD.FromSku, LA.Lottable07, LA.Lottable08, LOC.HostWHCode
   
   IF EXISTS(      
             SELECT 1
             FROM #TMP_TRF TRF   
             OUTER APPLY (SELECT (CI.Qty - CI.QtyAllocated - CI.QtyOnHold) AS ChannelAvaiQty
                          FROM CHANNELINV CI (NOLOCK) 
                          WHERE CI.Storerkey = TRF.FromStorerkey
                          AND CI.Facility = TRF.Facility
                          AND CI.Sku = TRF.FromSku
                          AND CI.Channel = TRF.FromChannel
                          AND CI.C_Attribute01 = TRF.Lottable07
                          AND CI.C_Attribute02 = TRF.Lottable08) CH
             OUTER APPLY (SELECT SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS BlockQty
                          FROM LOTXLOCXID LLI (NOLOCK) 
                          JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
                          JOIN LOC L (NOLOCK) ON LLI.Loc = L.Loc
                          WHERE LLI.Storerkey = TRF.FromStorerkey
                          AND L.Facility = TRF.Facility               
                          AND LLI.Sku = TRF.FromSku
                          AND L.HostWHCode = CASE WHEN TRF.FromChannel = 'B2B' THEN 'BL' ELSE 'HD' END
                          AND LA.Lottable07 = TRF.Lottable07
                          AND LA.Lottable08 = TRF.Lottable08) BLK
             WHERE TRF.FromQty > CASE WHEN TRF.HostWHCode = 'UR' THEN ISNULL(CH.ChannelAvaiQty,0) - ISNULL(BLK.BlockQty,0) ELSE ISNULL(BLK.BlockQty,0) END
            )
   BEGIN
   	  SET @n_continue = 3
   END
  
   EXIT_SP:  
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispTRCHK02'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN
   END    
END

GO