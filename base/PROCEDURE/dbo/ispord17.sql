SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispORD17                                           */
/* Creation Date: 03-Jan-2023                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-21429 - MY DSGMY Check duplicate externorderkey         */   
/*                                                                      */
/* Called By: isp_OrderTrigger_Wrapper from Orders Trigger              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 02-FEB-2020	ian(1.0) 1.0  amend storerky to storerkey				        */		
/* 20-JUL-2023  NJOW01   1.1  WMS-23140 add filter condition by codelkup*/
/* 20-JUL-2023  NJOW01   1.1  DEVOPS Combine Script                     */
/************************************************************************/

CREATE   PROC [dbo].[ispORD17]   
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
           @c_DupExternOrderkey NVARCHAR(50) = '',
           @c_DSGOrdType        NVARCHAR(15)            
           
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END

   IF @c_Action IN('INSERT','UPDATE')
   BEGIN      
   	  --NJOW01 S
   	  CREATE TABLE #TMP_DSGORD (ExternOrderkey NVARCHAR(50))
   	   
   	  DECLARE CUR_DSGORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   	     SELECT Short
   	     FROM CODELKUP (NOLOCK)
   	     WHERE ListName = 'DSGORDTYPE'
   	     AND Storerkey = @c_Storerkey   	     
   	           
      OPEN CUR_DSGORD  
      
      FETCH NEXT FROM CUR_DSGORD INTO @c_DSGOrdType
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN      
      	 SET @c_DSGOrdType = '%' + RTRIM(LTRIM(@c_DSGOrdType)) + '%'
      	 
      	 INSERT INTO #TMP_DSGORD (ExternOrderkey)
      	 SELECT O.ExternOrderkey
         FROM #INSERTED I 
         JOIN ORDERS O (NOLOCK) ON I.Orderkey = O.Orderkey
         WHERE O.Storerkey = @c_Storerkey
         AND O.ExternOrderkey LIKE @c_DSGOrdType
         AND O.ExternOrderkey <> ''
      	       	       	 
         FETCH NEXT FROM CUR_DSGORD INTO @c_DSGOrdType     		  
      END
      CLOSE CUR_DSGORD      
      DEALLOCATE CUR_DSGORD
      --NJOW01 E
         	     	
      SELECT TOP 1 @c_DupExternOrderkey = O.ExternOrderkey
      FROM #INSERTED I 
      JOIN ORDERS O (NOLOCK) ON I.Orderkey = O.Orderkey
      LEFT JOIN ORDERS O2 (NOLOCK) ON O.ExternOrderkey = O2.ExternOrderkey AND O.Storerkey = O2.Storerkey AND O.Orderkey <> O2.Orderkey   --ian1.0
      WHERE O.Storerkey = @c_Storerkey
      AND O.ExternOrderkey NOT IN (SELECT ExternOrderkey FROM #TMP_DSGORD)  --NJOW01
      --AND O.ExternOrderkey NOT LIKE '%SY%'
      AND O2.ExternOrderkey IS NOT NULL
      AND O.ExternOrderkey <> ''
      ORDER BY O.ExternOrderkey      
      
      IF ISNULL(@c_DupExternOrderkey,'') <> '' 
      BEGIN 
         SELECT @n_Continue = 3
         SELECT @n_Err = 38000
         SELECT @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Reject. Duplicate External Order# found ''' + RTRIM(@c_DupExternOrderkey) + ''' (ispORD17)' 
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispORD17'		
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