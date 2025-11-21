SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: ispWVH01                                                */
/* Creation Date: 20-OCT-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-21042 VN Carters Update orders based on wave type       */
/*                                                                      */
/* Called By: WAVE Add, Update, Delete                                  */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 20-OCT-2022 NJOW   	1.1	  DEVOPS Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[ispWVH01]
      @c_Action      NVARCHAR(10)
  ,   @c_Storerkey   NVARCHAR(15)
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt       INT
         , @n_Continue        INT
         , @c_UDF01           NVARCHAR(60)
         , @c_UDF02           NVARCHAR(60)
         , @c_UDF03           NVARCHAR(60)
         , @c_UDF04           NVARCHAR(60)
         , @c_UDF05           NVARCHAR(60)
         , @c_Notes           NVARCHAR(1000)
         , @c_Orderkey        NVARCHAR(10)
         , @c_OrderLineNumber NVARCHAR(5)
         , @c_Code2           NVARCHAR(10)
                  
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END

   IF @c_Action IN ('UPDATE')
   BEGIN
   	  DECLARE CUR_ORD CURSOR FAST_FORWARD LOCAL READ_ONLY FOR   	  
   	     SELECT O.Orderkey, ISNULL(CL.UDF01,''), ISNULL(CL.UDF02,''), ISNULL(CL.UDF03,''), 
   	            ISNULL(CL.UDF04,''), ISNULL(CL.UDF05,''), ISNULL(CL.Notes,''), ISNULL(CL.Code2,'')
   	     FROM #INSERTED I
   	     JOIN #DELETED D ON I.Wavekey = D.Wavekey
   	     JOIN WAVEDETAIL WD ON I.Wavekey = WD.Wavekey
   	     JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey   	  
   	     JOIN CODELKUP CL (NOLOCK) ON I.WaveType = CL.Code AND CL.Listname = 'WAVETYPE' AND CL.Storerkey = O.Storerkey
   	     WHERE O.Storerkey = @c_Storerkey
   	     AND O.Status <> '9'
   	     AND I.WaveType <> D.WaveType
   	     
   	  OPEN CUR_ORD   

      FETCH NEXT FROM CUR_ORD INTO @c_Orderkey, @c_UDF01, @c_UDF02, @c_UDF03, @c_UDF04, @c_UDF05, @c_Notes, @c_Code2
      
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
      BEGIN
      	 UPDATE ORDERS WITH (ROWLOCK)
      	 SET Type = @c_UDF01,
      	     ContainerType = @c_UDF02,
      	     SpecialHandling = @c_UDF03,
      	     Userdefine05 = @c_UDF04,
      	     InterModalVehicle = @c_UDF05,
      	     TrafficCop = NULL
      	 WHERE Orderkey = @c_Orderkey    
      	 
      	 SET @n_err = @@ERROR
      	 
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Orders Table Failed. (ispWVH01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         END      	 
      	 
      	 DECLARE CUR_ORDDET CURSOR FAST_FORWARD LOCAL READ_ONLY FOR   	
      	    SELECT OrderLineNumber
      	    FROM ORDERDETAIL (NOLOCK)
      	    WHERE Orderkey = @c_Orderkey
      	    
      	 OPEN CUR_ORDDET   

         FETCH NEXT FROM CUR_ORDDET INTO @c_OrderLineNumber

         WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
         BEGIN         
         	  UPDATE ORDERDETAIL WITH (ROWLOCK)
         	  SET Userdefine08 = @c_Notes,
         	      FreeGoodQty = CASE WHEN @c_Code2 = '1' THEN QtyToProcess ELSE FreeGoodQty END,
         	      TrafficCop = NULL
         	  WHERE Orderkey = @c_Orderkey
         	  AND OrderLineNumber = @c_OrderLineNumber

            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Orderdetail Table Failed. (ispWVH01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            END      	          	  
         	  
            FETCH NEXT FROM CUR_ORDDET INTO @c_OrderLineNumber
         END
         CLOSE CUR_ORDDET
         DEALLOCATE CUR_ORDDET
      	           	 
         FETCH NEXT FROM CUR_ORD INTO @c_Orderkey, @c_UDF01, @c_UDF02, @c_UDF03, @c_UDF04, @c_UDF05, @c_Notes, @c_Code2
      END
      CLOSE CUR_ORD
      DEALLOCATE CUR_ORD   	
   END
   
QUIT_SP:

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispWVH01'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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