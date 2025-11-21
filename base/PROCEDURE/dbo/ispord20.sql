SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispORD20                                           */
/* Creation Date: 10-May-2023                                           */
/* Copyright: Maersk                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-22523 - SG AESOP - Update orders.route                  */   
/*                                                                      */
/* Called By: isp_OrderTrigger_Wrapper from Orders Trigger              */
/*            Storerconfig: OrdersTrigger_SP                            */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 01-May-2023  NJOW     1.0  DevOps Combine Script                     */
/************************************************************************/
CREATE   PROCEDURE [dbo].[ispORD20]      
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
           @c_CCountry        NVARCHAR(100),
           @c_DocType         NVARCHAR(20),
           @c_UDF01           NVARCHAR(120),
           @c_Orderkey        NVARCHAR(10),
           @c_DefaultRoute    NVARCHAR(10),
           @c_ByField         NVARCHAR(30)
                                                                 
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN ('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT I.Orderkey
   FROM #INSERTED I

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey

   WHILE @@FETCH_STATUS <> -1
   BEGIN  
   	  SELECT @c_UDF01 = '', @c_DefaultRoute = '', @c_ByField = '', @c_CCountry = '', @c_DocType = '', @c_Storerkey = ''
   	  
      IF @c_Action IN ('INSERT', 'UPDATE')
      BEGIN
         SELECT @c_CCountry  = TRIM(ISNULL(I.C_Country,''))
              , @c_DocType   = TRIM(ISNULL(I.DocType,''))
              , @c_Storerkey = TRIM(ISNULL(I.Storerkey,''))
         FROM #INSERTED I
         WHERE I.Orderkey = @c_Orderkey   
      
         IF NOT EXISTS (SELECT 1 
                        FROM CODELKUP CL (NOLOCK) 
                        WHERE CL.LISTNAME = 'ROUTEDOCTY'
                        AND CL.Storerkey = @c_Storerkey
                        AND CL.Code = @c_DocType)
         BEGIN 
            SET @c_UDF01 = '99'
            GOTO UPDATE_RESULT
         END
      
         IF @c_CCountry IN ('SG', 'SIN', 'SINGAPORE', 'SGP')
         BEGIN
            SELECT TOP 1 @c_UDF01 = LTRIM(RTRIM(ISNULL(CLK.UDF01,'')))  
            FROM ORDERS O (NOLOCK)
            JOIN CODELKUP CLK (NOLOCK) ON CLK.LISTNAME = 'CUORDROUTE' AND CLK.Storerkey = @c_Storerkey  
            WHERE O.C_Zip LIKE TRIM(CLK.Code) + '%'
            AND O.OrderKey = @c_Orderkey
            ORDER BY LEN(CLK.Code) DESC 
      
            IF ISNULL(@c_UDF01,'') = '' 
            BEGIN
               SET @c_UDF01 = '99'
            END
         END
         ELSE   --NOT IN SG List
         BEGIN
            SELECT TOP 1 @c_DefaultRoute = CL.UDF01,
                         @c_ByField = CL.UDF02
            FROM ORDERS O (NOLOCK)
            JOIN CODELKUP CL (NOLOCK) ON O.Storerkey = CL.storerkey AND O.C_Country = CL.Code2 AND CL.Code = 'DEFAULT'                                      
            WHERE O.Orderkey = @c_Orderkey
            AND CL.Listname = 'CUORDROUTE'
            
            IF ISNULL(@c_DefaultRoute,'') <> ''
            BEGIN
            	 SELECT TOP 1 @c_UDF01 = RTRIM(ISNULL(O.C_Country,'')) + ISNULL(CL.UDF01,'')
            	 FROM ORDERS O (NOLOCK)
               JOIN CODELKUP CL (NOLOCK) ON O.Storerkey = CL.storerkey AND O.C_Country = CL.Code2 
               WHERE O.Orderkey = @c_Orderkey            	
               AND CL.Code = CASE @c_ByField  WHEN 'CITY' THEN O.C_City ELSE O.C_State END
               AND CL.Listname = 'CUORDROUTE'
               
               IF ISNULL(@c_UDF01,'') = ''
                  SET @c_UDF01 = RTRIM(ISNULL(@c_CCountry,'')) + @c_DefaultRoute
            END
            ELSE
            BEGIN            	
            	 SELECT @c_UDF01 = ISNULL(@c_CCountry,'')
            END             
            
            IF ISNULL(@c_UDF01,'') = '' 
            BEGIN
               SET @c_UDF01 = '99'
            END                        
         END
      END    
      
      UPDATE_RESULT:
      
      IF @c_Action IN ('INSERT', 'UPDATE')
      BEGIN
         UPDATE ORDERS  
         SET [Route]    = @c_UDF01  
           , TrafficCop = NULL  
           , ArchiveCop = NULL  
           , EditDate   = GETDATE()  
           , EditWho    = SUSER_SNAME()  
         WHERE Orderkey = @c_Orderkey
      END    

      FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey
   END   
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP
                   
   QUIT_SP:

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispORD20'      
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