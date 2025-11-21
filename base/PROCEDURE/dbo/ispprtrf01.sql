SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ispPRTRF01                                                  */
/* Creation Date: 24-Jul-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-5839 CN IKEA - Pre-Finalize transfer Update lottable10  */
/*                                                                      */
/* Called By: ispPreFinalizeTransferWrapper                             */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[ispPRTRF01]  
(     @c_Transferkey          NVARCHAR(10)   
  ,   @b_Success              INT           OUTPUT
  ,   @n_Err                  INT           OUTPUT
  ,   @c_ErrMsg               NVARCHAR(255) OUTPUT 
  ,   @c_TransferLineNumber   NVARCHAR(5)   = '' 
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
         , @c_UDF03              NVARCHAR(60)
         , @c_UDF04              NVARCHAR(60)
         , @c_ToLottable10       NVARCHAR(30)

   SELECT @n_StartTCount = @@TRANCOUNT, @b_Success = 1, @n_Err = 0, @c_ErrMsg  = '', @b_Debug = 0, @n_Continue = 1  
   
   IF @n_continue IN(1,2)
   BEGIN
      DECLARE CUR_TRANSFER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT TD.TransferLineNumber, TD.ToLottable10, CL2.UDF03, CL2.UDF04
         FROM TRANSFER T (NOLOCK) 
         JOIN TRANSFERDETAIL TD (NOLOCK) ON T.Transferkey = TD.Transferkey
         JOIN LOC (NOLOCK) ON TD.ToLoc = LOC.Loc
         --JOIN CODELKUP CL (NOLOCK) ON T.Type = CL.Code AND CL.Listname =  'TRANTYPE'
         JOIN CODELKUP CL2 (NOLOCK) ON T.Type = CL2.Code AND T.FromStorerkey = CL2.Storerkey AND CL2.Listname = 'IKEAADJSCN' AND LOC.LocationCategory = CL2.Long
         WHERE T.Transferkey = @c_Transferkey
         ORDER BY TD.TransferLineNumber

      OPEN CUR_TRANSFER
      
      FETCH NEXT FROM CUR_TRANSFER INTO @c_TransferLineNumber, @c_ToLottable10, @c_UDF03, @c_UDF04      
                                          
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
      BEGIN
      	 SET @c_ToLottable10 = RTRIM(ISNULL(@c_ToLottable10,''))
      	 
      	 IF @c_UDF03 = '+'
      	    SET @c_ToLottable10 = @c_ToLottable10 + RTRIM(LTRIM(ISNULL(@c_UDF04,'')))
      	     
      	 IF @c_UDF03 = '-'
      	    SET @c_ToLottable10 = REPLACE(@c_ToLottable10, @c_UDF04, '')
      	   
      	 UPDATE TRANSFERDETAIL WITH (ROWLOCK)
      	 SET ToLottable10 = @c_ToLottable10,
      	     TrafficCop = NULL
      	 WHERE Transferkey = @c_Transferkey
      	 AND TransferLineNumber = @c_TransferLineNumber
      	 
      	 SET @n_Err = @@ERROR
      	 
         IF @n_Err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 61000
            SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Update Transferdetail Table Failed. (ispPRTRF01)' 
                                + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '
         END
      	       	
         FETCH NEXT FROM CUR_TRANSFER INTO @c_TransferLineNumber, @c_ToLottable10, @c_UDF03, @c_UDF04      
      END
      CLOSE CUR_TRANSFER
      DEALLOCATE CUR_TRANSFER      	
   END

   QUIT_SP:

   IF CURSOR_STATUS('LOCAL' , 'CUR_TRANSFER') in (0 , 1)
   BEGIN
      CLOSE CUR_TRANSFER
      DEALLOCATE CUR_TRANSFER
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
      Execute nsp_logerror @n_err, @c_errmsg, 'ispPRTRF01'
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