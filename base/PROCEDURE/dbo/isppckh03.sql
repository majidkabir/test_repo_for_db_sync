SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPCKH03                                          */
/* Creation Date: 08-May-2018                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-4642 THA Pack confirm check packinfo                    */   
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

CREATE PROC [dbo].[ispPCKH03]   
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
           @c_TableName       NVARCHAR(30),
           @c_Pickslipno      NVARCHAR(10),
           @n_Cartonno        INT
                                                       
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   
               
	 IF @c_Action IN('UPDATE') 
	 BEGIN	 		 	
	    SELECT TOP 1 @c_Pickslipno = I.Pickslipno, 
	                 @n_Cartonno = PD.CartonNo	 	
	    FROM #INSERTED I
	    JOIN #DELETED D ON I.Pickslipno = D.Pickslipno
	    JOIN PACKDETAIL PD (NOLOCK) ON I.Pickslipno = PD.Pickslipno
	    LEFT JOIN PACKINFO PIF (NOLOCK) ON PD.Pickslipno = PIF.Pickslipno AND PD.Cartonno = PIF.CartonNo
	    WHERE I.Status <> D.Status 
	    AND I.Status ='9'
	    AND (PIF.Pickslipno IS NULL 	               
	         OR ISNULL(PIF.Cube,0) = 0
	         OR ISNULL(PIF.Weight,0) = 0)
	    ORDER BY I.Pickslipno, PD.Cartonno
	    
	    IF ISNULL(@c_Pickslipno,'') <> ''          
	    BEGIN
         SET @n_continue = 3    
         SET @n_err = 61900-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Pickslip# '+ RTRIM(@C_Pickslipno) + ' Carton# ' + RTRIM(CAST(@n_Cartonno AS NVARCHAR)) + ' found incomplete cube/weight capture. (ispPCKH03)'   
      
         GOTO QUIT_SP 	    	
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPCKH03'		
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