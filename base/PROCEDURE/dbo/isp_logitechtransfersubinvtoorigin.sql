SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_LogitechTransferSubInvToOrigin                      */
/* Creation Date: 21-Oct-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-18160 - SG - Logitech - Auto populate and Finalize      */
/*        : Transfer                                                    */
/*                                                                      */
/* Called By: SQL Job                                                   */
/*          :                                                           */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 21-Oct-2021  WLChooi   1.0 DevOps Combine Script                     */
/* 01-Dec-2022  WLChooi   1.1 WMS-21274 - Hardcode ToLoc (WL01)         */
/************************************************************************/
CREATE PROC [dbo].[isp_LogitechTransferSubInvToOrigin]
            @c_Storerkey  NVARCHAR(15) = ''
          , @b_debug      INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt           INT
         , @n_Continue            INT 
         , @b_Success             INT
         , @n_Err                 INT
         , @c_ErrMsg              NVARCHAR(255)
         , @n_StartTranCount      INT
         , @c_Sku                 NVARCHAR(20)
         , @c_Transferkey         NVARCHAR(10)
         , @c_Lot                 NVARCHAR(10)
         , @C_Loc                 NVARCHAR(10)
         , @c_ID                  NVARCHAR(18)
         , @c_Facility            NVARCHAR(5)
         , @n_QtyTransfer         INT
         , @c_Lottable08          NVARCHAR(30)
         , @c_Lottable09          NVARCHAR(30)
         , @c_Remark              NVARCHAR(200)
         , @c_ToLoc               NVARCHAR(10)

   SET @n_Continue = 1
   SET @n_StartTranCount = @@TRANCOUNT
   SET @b_Success = 1
   SET @n_Err = 0
   SET @c_ErrMsg = ''
   SET @b_debug = 0

   --WL01 S
   IF EXISTS (SELECT 1
              FROM LOC (NOLOCK)
              WHERE LOC = 'BTRXTEM2')
   BEGIN
      SET @c_ToLoc = 'BTRXTEM2'
   END
   --WL01 E

   CREATE TABLE #TMP_EXCLUDESKU (
      Storerkey   NVARCHAR(15)
    , SKU         NVARCHAR(20)
   )

   INSERT INTO #TMP_EXCLUDESKU (Storerkey, SKU)
   SELECT DISTINCT @c_Storerkey, CL.Code
   FROM CODELKUP CL (NOLOCK) 
   WHERE CL.Listname = 'LOGIRSP'
   AND CL.Code2 = 'AP1BCH' 
   AND CL.Storerkey = @c_Storerkey

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT LLI.StorerKey, LLI.SKU, LLI.Lot, LLI.Loc, LLI.Id, (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS QtyAvailable,
             LOC.Facility, LA.Lottable08, LA.Lottable09
      FROM LOTXLOCXID LLI (NOLOCK)
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
      JOIN ID (NOLOCK) ON LLI.Id = ID.Id
      JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
      JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
      LEFT JOIN #TMP_EXCLUDESKU TE ON TE.SKU = LLI.SKU AND TE.Storerkey = LLI.StorerKey
      WHERE LLI.Storerkey = @c_Storerkey
      AND LA.Lottable08 IN ('AP1BCH')
      AND TE.SKU IS NULL   --Not exists in Codelkup WHERE Listname = 'LOGIRSP'
      AND ID.Status = 'OK'
      AND LOC.LocationFlag = 'NONE'
      AND LOC.[Status] = 'OK'
      AND LOT.[Status] = 'OK'
      AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked > 0
      ORDER BY LA.Lottable05, LOC.LogicalLocation, LOC.Loc

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_Storerkey, @c_SKU, @c_Lot, @c_Loc, @c_ID, @n_QtyTransfer, @c_Facility, @c_Lottable08, @c_Lottable09

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Storerkey   AS '@c_Storerkey'  
              , @c_SKU         AS '@c_SKU'                
              , @c_Lot         AS '@c_Lot'           
              , @c_Loc         AS '@c_Loc'
              , @c_ID          AS '@c_ID'                
              , @n_QtyTransfer AS '@n_QtyTransfer'
              , @c_Facility    AS '@c_Facility'
              , @c_Lottable08  AS '@c_Lottable08'
              , @c_Lottable09  AS '@c_Lottable09'
      END

      SELECT @c_Remark = 'RT' + REPLACE(CONVERT(NVARCHAR,GETDATE(),5),'-','') 
                    
      SET @b_Success = 0
      EXEC ispCreateTransfer
           @c_Transferkey  = @c_Transferkey OUTPUT
         , @c_FromFacility = @c_Facility
         , @c_FromLot      = @c_Lot
         , @c_FromLoc      = @c_Loc
         , @c_FromID       = @c_ID
         , @n_FromQty      = @n_QtyTransfer                   
         , @c_ToLoc        = @c_ToLoc
         , @c_ToLottable08 = @c_Lottable09
         , @c_ToLottable09 = 'EMPTY'
         , @c_CopyLottable = 'Y'
         , @c_Finalize     = 'N'
         , @c_Type         = 'XA'
         , @c_ReasonCode   = 'CHLOT'
         , @c_Remarks      = @c_Remark   
         , @b_Success      = @b_Success OUTPUT
         , @n_Err          = @n_Err     OUTPUT
         , @c_ErrMsg       = @c_ErrMsg  OUTPUT
                 
         IF @b_Success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = RTRIM(@c_Errmsg) +  ' (isp_LogitechTransferSubInvToOrigin)'
         END
                    
      FETCH NEXT FROM CUR_LOOP INTO @c_Storerkey, @c_SKU, @c_Lot, @c_Loc, @c_ID, @n_QtyTransfer, @c_Facility, @c_Lottable08, @c_Lottable09
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP

   IF @n_continue IN (1,2) AND ISNULL(@c_Transferkey,'') <> ''
   BEGIN
      EXEC ispFinalizeTransfer @c_Transferkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
      
      IF @b_Success <> 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63110
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Transfer# ' + RTRIM(@c_Transferkey) + ' Failed! (isp_LogitechTransferSubInvToOrigin)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END      
   END

QUIT_SP:
   IF CURSOR_STATUS( 'LOCAL', 'CUR_LOOP') in (0 , 1)  
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END
   
   IF OBJECT_ID('tempdb..#TMP_EXCLUDESKU') IS NOT NULL
      DROP TABLE #TMP_EXCLUDESKU

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_LogitechTransferSubInvToOrigin'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012          
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
END -- procedure

GO