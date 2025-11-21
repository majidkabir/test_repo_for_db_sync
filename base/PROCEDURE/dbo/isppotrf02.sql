SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ispPOTRF02                                                  */
/* Creation Date: 21-Nov-2014                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Release Transfer Task;                                      */
/*        : SOS#315609 - Project Merlion - Transfer Release Task        */
/* Called By: ispPostFinalizeTransferWrapper                            */
/*          : Transferdetail del Trigger if AllowDelReleasedTransferID  */
/*          : is turn on                                                */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[ispPOTRF02]  
(     @c_Transferkey          NVARCHAR(10)   
  ,   @b_Success              INT           OUTPUT
  ,   @n_Err                  INT           OUTPUT
  ,   @c_ErrMsg               NVARCHAR(255) OUTPUT 
  ,   @c_TransferLineNumber   NVARCHAR(5)   = '' 
  ,   @c_ID                   NVARCHAR(18)  = '' 
  ,   @c_UpdateToID           NVARCHAR(1)   = 'Y'
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @b_Debug              INT
         , @n_Cnt                INT
         , @n_Continue           INT 
         , @n_StartTCount        INT 

         , @c_FromID             NVARCHAR(18)
         , @c_ToID               NVARCHAR(18)

         , @c_PalletFlag         NVARCHAR(30)
         , @c_Hold               NVARCHAR(10)
   
         , @c_InvHoldStatus      NVARCHAR(10)

   SET @b_Success = 1 
   SET @n_Err     = 0  
   SET @c_ErrMsg  = ''
   SET @b_Debug   = '0' 
   SET @n_Continue= 1  
   SET @n_StartTCount = @@TRANCOUNT  

     
   CREATE TABLE #TRFID
      (  Transferkey NVARCHAR(10)
      ,  FromID      NVARCHAR(18)
      ,  ToID        NVARCHAR(18)   DEFAULT ('')
      )
   
   IF @c_UpdateToID = 'N' -- passin from ntrtransferdetaildelete
   BEGIN
      INSERT INTO #TRFID(Transferkey, FromID)
      VALUES (@c_Transferkey, @c_ID)
   END
   ELSE
   BEGIN
      INSERT INTO #TRFID(Transferkey, FromID, ToID)
      SELECT TFD.Transferkey
            ,TFD.FromID
            ,TFD.ToID
      FROM TRANSFERDETAIL TFD WITH (NOLOCK)
      WHERE TFD.Transferkey = @c_TransferKey
      AND TFD.TransferLinenumber = CASE WHEN @c_TransferLinenumber = ''       --(Wan01) 
                                        THEN TFD.TransferLinenumber           --(Wan01) 
                                        ELSE @c_TransferLinenumber END        --(Wan01) 
      AND Status = '9'
      GROUP BY TFD.Transferkey
            ,  TFD.FromID
            ,  TFD.ToID
   END

   DECLARE CUR_FROMID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT FromID = FromID
   FROM #TRFID
   ORDER BY FromID
   

   OPEN CUR_FROMID

   FETCH NEXT FROM CUR_FROMID INTO  @c_FromID        
                                       
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT @c_PalletFlag = ISNULL(RTRIM(PalletFlag),'')
      FROM ID WITH (NOLOCK)
      WHERE ID = @c_FromID

      SET @c_Hold = CASE WHEN @c_PalletFlag = 'TRFZUNHOLD' THEN '0' 
                         WHEN @c_PalletFlag = 'TRFZHOLD' THEN '1' 
                         ELSE '' END

      DECLARE CUR_TOID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT ToID
      FROM #TRFID
      WHERE FromID = @c_FromID
      AND   FromID <> ToID
      AND @c_UpdateToID = 'Y'
      ORDER BY ToID

      OPEN CUR_TOID

      FETCH NEXT FROM CUR_TOID INTO @c_ToID            
    
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @c_Hold = 1   
         BEGIN
            SELECT @c_InvHoldStatus = ISNULL(RTRIM(Status),'')
            FROM InventoryHold WITH (NOLOCK)
            WHERE ID = @c_FromID

            EXEC nspInventoryHoldWrapper
                  '',               -- lot
                  '',               -- loc
                  @c_Toid,          -- id
                  '',               -- storerkey
                  '',               -- sku
                  '',               -- lottable01
                  '',               -- lottable02
                  '',               -- lottable03
                  NULL,             -- lottable04
                  NULL,             -- lottable05
                  '',               -- lottable06
                  '',               -- lottable07    
                  '',               -- lottable08
                  '',               -- lottable09
                  '',               -- lottable10
                  '',               -- lottable11
                  '',               -- lottable12
                  NULL,             -- lottable13
                  NULL,             -- lottable14
                  NULL,             -- lottable15
                  @c_InvHoldStatus, -- status  
                  @c_Hold,          -- hold
                  @b_success OUTPUT,
                  @n_err OUTPUT,
                  @c_errmsg OUTPUT,
                  '' -- remark

            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 61045
               SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Hold To ID Fail. (ispPOTRF02)' 
                                   + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '
            END
         END
         FETCH NEXT FROM CUR_TOID INTO  @c_ToID 
      END
      CLOSE CUR_TOID
      DEALLOCATE CUR_TOID

      IF NOT EXISTS (SELECT 1 
                     FROM TRANSFERDETAIL WITH (NOLOCK)
                     WHERE Transferkey = @c_Transferkey
                     and Fromid = @c_Fromid
                     AND Status <> 'CANC'
                     AND Status < '9'
                    )
      BEGIN
         IF @c_Hold = '0' AND 
            EXISTS (SELECT 1 FROM InventoryHold where id = @c_Fromid AND status = 'TRFHOLD')
         BEGIN
            EXEC nspInventoryHoldWrapper
                  '',               -- lot
                  '',               -- loc
                  @c_fromid,        -- id
                  '',               -- storerkey
                  '',               -- sku
                  '',               -- lottable01
                  '',               -- lottable02
                  '',               -- lottable03
                  NULL,             -- lottable04
                  NULL,             -- lottable05
                  '',               -- lottable06
                  '',               -- lottable07    
                  '',               -- lottable08
                  '',               -- lottable09
                  '',               -- lottable10
                  '',               -- lottable11
                  '',               -- lottable12
                  NULL,             -- lottable13
                  NULL,             -- lottable14
                  NULL,             -- lottable15
                  'TRFHOLD',        -- status  
                  @c_Hold,              -- hold
                  @b_success OUTPUT,
                  @n_err OUTPUT,
                  @c_errmsg OUTPUT,
                  '' -- remark

            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 61045
               SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Unhold From ID Fail. (ispPOTRF02)' 
                                   + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '
            END
         END

         UPDATE ID WITH (ROWLOCK)
         SET PalletFlag = ''
            ,Trafficcop = NULL
            ,EditDate   = GETDATE()
            ,EditWho    = SUSER_NAME()
         WHERE Id = @c_FromID
      
         SET @n_err = @@ERROR   

         IF @n_err <> 0    
         BEGIN  
            SET @n_continue = 3    
            SET @n_err = 61010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update From ID Failed. (ispPOTRF02)' 
            GOTO QUIT_SP  
         END 
      END         
      FETCH NEXT FROM CUR_FROMID INTO  @c_FromID        
   END
   CLOSE CUR_FROMID
   DEALLOCATE CUR_FROMID

   QUIT_SP:

   IF CURSOR_STATUS('LOCAL' , 'CUR_FROMID') in (0 , 1)
   BEGIN
      CLOSE CUR_FROMID
      DEALLOCATE CUR_FROMID
   END

   IF CURSOR_STATUS('LOCAL' , 'CUR_TOID') in (0 , 1)
   BEGIN
      CLOSE CUR_TOID
      DEALLOCATE CUR_TOID
   END

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCount
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCount
         BEGIN
            COMMIT TRAN
         END
      END
      Execute nsp_logerror @n_err, @c_errmsg, 'ispPOTRF02'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCount
      BEGIN
         COMMIT TRAN
      END 

      RETURN
   END 
END

GO