SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispORD07                                           */
/* Creation Date: 04-Mar-2019                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-8171 - SG EDR – Default Route By Zip Code               */   
/*                                                                      */
/* Called By: isp_OrderTrigger_Wrapper from Orders Trigger              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 30/08/2019   WLChooi  1.1  WMS-10196 - Add new logic (WL01)          */
/* 24/03/2023   NJOW01   1.2  WMS-22094 - Retrieve route by storerkey   */
/* 24/03/2023   NJOW01   1.2  DEVOPS Combine Script                     */
/************************************************************************/

CREATE   PROC [dbo].[ispORD07]   
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
           @c_CCountry        NVARCHAR(60),
           @c_UDF01           NVARCHAR(120),
           @c_StorerkeyOpt1   NVARCHAR(15)='', --NJOW01
           @c_Orderkey        NVARCHAR(10)=''  --NJOW01
                                                       
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   

   IF @c_Action IN('INSERT', 'UPDATE')
   BEGIN   	     	
   	  SELECT @c_StorerkeyOpt1 = SC.Option1   	  
      FROM dbo.fnc_GetRight2('',@c_Storerkey,'','OrdersTrigger_SP') AS SC
      JOIN STORER S (NOLOCK) ON SC.Option1 = S.Storerkey

	    SELECT Orderkey
   	  INTO #ORD
   	  FROM #INSERTED
   	  WHERE Storerkey = @c_Storerkey
            	
   	  DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR --NJOW01
   	     SELECT Orderkey
   	     FROM #ORD
   	        	     
      OPEN CUR_ORD  

      FETCH NEXT FROM CUR_ORD INTO @c_Orderkey
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN          	   	   	     	     
         --WL01 Start
         SET @c_CCountry = ''
         SET @c_UDF01 = ''
         
         SELECT @c_CCountry = LTRIM(RTRIM(ISNULL(I.C_Country,'')))
         FROM ORDERS I (NOLOCK)
         WHERE I.Orderkey = @c_Orderkey --NJOW01
         
         IF(@c_CCountry IN ('SG','SIN','SINGAPORE'))
         BEGIN
            --Step 1 - Check Wholesaler postal code
            SELECT @c_UDF01 = LTRIM(RTRIM(ISNULL(CLK.UDF01,'')))
            FROM ORDERS I (NOLOCK) 
            JOIN CODELKUP CLK (NOLOCK) ON CLK.LISTNAME = 'ORDROUTE' AND CODE = LTRIM(RTRIM(I.C_ZIP))
            WHERE (CLK.Storerkey = @c_StorerkeyOpt1 OR (ISNULL(@c_StorerkeyOpt1,'')='' AND ISNULL(CLK.Storerkey,'')='')) --NJOW01
            AND I.Orderkey = @c_Orderkey --NJOW01
         
            --If no result from above, perform Step 2
            IF ISNULL(@c_UDF01,'') = ''
            BEGIN
               --Step 2 - Check first 2 digit of C_Zip
               SELECT @c_UDF01 = LTRIM(RTRIM(ISNULL(CLK.UDF01,'')))
               FROM ORDERS I (NOLOCK)
               JOIN CODELKUP CLK (NOLOCK) ON CLK.LISTNAME = 'ORDROUTE' AND CODE = SUBSTRING(LTRIM(I.C_ZIP),1,2)
               WHERE (CLK.Storerkey = @c_StorerkeyOpt1 OR (ISNULL(@c_StorerkeyOpt1,'')='' AND ISNULL(CLK.Storerkey,'')='')) --NJOW01
               AND I.Orderkey = @c_Orderkey --NJOW01
            END
         
            --If no result from above, perform Step 3
            IF ISNULL(@c_UDF01,'') = '' 
            BEGIN
               --Step 3 - Assign default route code as 99
               SET @c_UDF01 = '99'
            END
         
            UPDATE ORDERS
            SET ROUTE = @c_UDF01
               ,TrafficCop = NULL
               ,ArchiveCop = NULL
            --FROM #INSERTED I 
            --JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = I.ORDERKEY
            WHERE ORDERS.Orderkey = @c_Orderkey  --NJOW01          
         END
         --WL01 End
         FETCH NEXT FROM CUR_ORD INTO @c_Orderkey                     
      END
      CLOSE CUR_ORD
      DEALLOCATE CUR_ORD      
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispORD07'		
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