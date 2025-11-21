SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPCKH04                                          */
/* Creation Date: 08-May-2018                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-5856 HK PVH Pack confirm validation                     */   
/*                                                                      */
/* Called By: isp_PackHeaderTrigger_Wrapper from PackHeader Trigger     */
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

CREATE PROC [dbo].[ispPCKH04]   
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
     
   DECLARE @n_Continue        INT,
           @n_StartTCnt       INT,
           @c_Pickslipno      NVARCHAR(10),
           @c_Loadkey         NVARCHAR(10),
           @c_Orderkey        NVARCHAR(10)
                                                       
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   
               
	 IF @c_Action IN('UPDATE') 
	 BEGIN	 		 	
	    SELECT TOP 1 @c_Pickslipno = I.Pickslipno
	    FROM #INSERTED I
	    JOIN #DELETED D ON I.Pickslipno = D.Pickslipno
	    WHERE I.Status <> D.Status 
	    AND I.Status ='9'
	    AND I.Storerkey = @c_Storerkey
	    ORDER BY I.Pickslipno

      SELECT @c_Loadkey = ExternOrderKey
      FROM PICKHEADER (NOLOCK)
      WHERE PickHeaderKey = @c_PickSlipNo
      AND (Orderkey = '' OR Orderkey IS NULL)
      
      IF ISNULL(@c_Loadkey,'') = ''
      BEGIN
      	  SELECT @c_Loadkey = O.Loadkey
      	  FROM PICKHEADER PH (NOLOCK)
      	  JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
      	  WHERE PH.PickHeaderkey = @c_Pickslipno
      END
      
      IF ISNULL(@c_Loadkey,'') <> ''
      BEGIN
         SELECT TOP 1 @c_Orderkey = O.Orderkey
         FROM LOADPLANDETAIL LPD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.OrderKey
         JOIN STORER S (NOLOCK) ON O.BillToKey = S.Storerkey AND O.Storerkey = S.ConsigneeFor
         LEFT JOIN MBOLDETAIL MD (NOLOCK) ON O.Orderkey = MD.Orderkey
         WHERE LPD.Loadkey = @c_Loadkey
         AND O.OrderGroup = 'W'      
         AND S.VAT IN('1','2','3')      
         AND MD.OrderKey IS NULL
         ORDER BY O.Orderkey
         
         IF ISNULL(@c_Orderkey,'') <> ''
         BEGIN
            SELECT @n_continue = 3                                                                                       
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83010   -- Should Be Set To The SQL Errmessage but
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Pack Confirm Failed: Order# ''' + RTRIM(@c_Orderkey)  +  ''' Haven''t Build MBOL Yet. (isp_PrePackValidate02)' 
            GOTO QUIT_SP      	
         END

         SET @c_Orderkey = ''
         
         SELECT TOP 1 @c_Orderkey = O.Orderkey
         FROM LOADPLANDETAIL LPD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.OrderKey
         WHERE LPD.Loadkey = @c_Loadkey
         AND (O.Status < '5' OR O.Status = 'CANC')
         ORDER BY O.Orderkey
         
         IF ISNULL(@c_Orderkey,'') <> ''
         BEGIN
            SELECT @n_continue = 3                                                                                       
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83020   -- Should Be Set To The SQL Errmessage but
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Pack Confirm Failed: Order# ''' + RTRIM(@c_Orderkey)  +  ''' Not Picked Yet (Status < 5) Or Cancel. (isp_PrePackValidate02)' 
            GOTO QUIT_SP      	
         END
      END
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPCKH04'		
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