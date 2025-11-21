SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPKD04                                           */
/* Creation Date: 15-Aug-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-1880 SG Unallocation Delete pallet from container       */   
/*                                                                      */
/* Called By: isp_PickDetailTrigger_Wrapper from Pickdetail Trigger     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/

CREATE PROC [dbo].[ispPKD04]   
   @c_Action        NVARCHAR(10),
   @c_Storerkey     NVARCHAR(15),  
   @b_Success       INT      OUTPUT,
   @n_Err           INT      OUTPUT, 
   @c_ErrMsg        NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue     INT,
           @n_StartTCnt    INT,
           @c_Containerkey NVARCHAR(10),
           @c_Palletkey    NVARCHAR(30)
                                             
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   
   
	 IF @c_Action = 'DELETE'
	 BEGIN
	 	  --Retrieve deleted whole pallet exist in container
   	  DECLARE CUR_ID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   	  	 	  
	 	     SELECT DISTINCT C.Containerkey, CD.Palletkey
	 	     FROM #DELETED D
	 	     JOIN ORDERS O (NOLOCK) ON D.Orderkey = O.Orderkey
	 	     JOIN LOADPLAN L (NOLOCK) ON O.Loadkey = L.Loadkey
	 	     JOIN CONTAINER C (NOLOCK) ON L.Loadkey = C.Loadkey
	 	     JOIN CONTAINERDETAIL CD (NOLOCK) ON C.Containerkey = CD.Containerkey AND D.Id = CD.Palletkey AND C.Status <> '9'
	 	     LEFT JOIN PICKDETAIL PD (NOLOCK) ON D.Id = PD.Id AND D.Storerkey = PD.Storerkey AND PD.Status <> '9' AND PD.Qty > 0   --check no more pickdetail of the pallet
	 	     WHERE D.Storerkey = @c_Storerkey
	 	     AND ISNULL(D.ID,'') <> ''
	 	     AND PD.Id IS NULL
	 	     ORDER BY C.Containerkey, CD.Palletkey

   	  OPEN CUR_ID   
      
      FETCH NEXT FROM CUR_ID INTO @c_Containerkey, @c_Palletkey

      WHILE @@FETCH_STATUS <> -1               
      BEGIN
      	 DELETE FROM CONTAINERDETAIL 
      	 WHERE Containerkey = @c_Containerkey
      	 AND Palletkey = @c_Palletkey

         SET @n_Err = @@ERROR
	                          
         IF @n_Err <> 0
         BEGIN
         	  SELECT @n_Continue = 3 
	          SELECT @n_Err = 35100
	          SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Delete CONTAINERDETAIL Failed. (ispPKD04)'
         END   	 	
      	
         FETCH NEXT FROM CUR_ID INTO @c_Containerkey, @c_Palletkey
      END
      CLOSE CUR_ID      	
      DEALLOCATE CUR_ID      	 	 	  
	 END
      
   QUIT_SP:
   
	 IF @n_Continue=3  -- Error Occured - Process AND Return
	 BEGIN
	    SELECT @b_Success = 0
	    IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPKD04'		
	    --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
	    RETURN
	 END
	 ELSE
	 BEGIN
	    SELECT @b_Success = 1
	    WHILE @@TRANCOUNT > @n_StartTCnt
	    BEGIN
	    	COMMIT TRAN
	    END
	    RETURN
	 END  
END  

GO