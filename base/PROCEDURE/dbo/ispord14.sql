SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispORD14                                           */
/* Creation Date: 22-Oct-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-18209 - SG - Adidas SEA - Exceed Config OrdersTrigger_SP*/   
/*                                                                      */
/* Called By: isp_OrderTrigger_Wrapper from Orders Trigger              */
/*                                                                      */
/* GitLab Version: 1.2                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 22-Oct-2021  WLChooi  1.0  DevOps Combine Script                     */
/* 28-Feb-2022  WLChooi  1.1  Bug Fix - Update by orderkey (WL01)       */
/* 25-Aug-2022  WLChooi  1.2  Bug Fix - Update Route (WL02)             */
/************************************************************************/
CREATE PROCEDURE [dbo].[ispORD14]      
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
           @c_Orderkey        NVARCHAR(10)   --WL01
                                                       
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN ('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   

   --WL01 S
   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT I.Orderkey
   FROM #INSERTED I

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey

   WHILE @@FETCH_STATUS <> -1
   BEGIN   --WL01 E
      IF @c_Action IN ('INSERT', 'UPDATE')
      BEGIN
         SELECT @c_CCountry  = TRIM(ISNULL(I.C_Country,''))
              , @c_DocType   = TRIM(ISNULL(I.DocType,''))
              , @c_Storerkey = TRIM(ISNULL(I.Storerkey,''))
         FROM #INSERTED I
         WHERE I.Orderkey = @c_Orderkey   --WL01
      
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
            --WL02 S
            --SELECT @c_UDF01 = LTRIM(RTRIM(ISNULL(CLK.UDF01,'')))
            --FROM #INSERTED I 
            --JOIN CODELKUP CLK (NOLOCK) ON CLK.LISTNAME = 'CUORDROUTE' AND CLK.Storerkey = @c_Storerkey
            --WHERE I.C_Zip LIKE TRIM(CLK.Code) + '%'
            --ORDER BY LEN(CLK.Code) DESC

            SELECT TOP 1 @c_UDF01 = LTRIM(RTRIM(ISNULL(CLK.UDF01,'')))  
            FROM ORDERS O (NOLOCK)
            JOIN CODELKUP CLK (NOLOCK) ON CLK.LISTNAME = 'CUORDROUTE' AND CLK.Storerkey = @c_Storerkey  
            WHERE O.C_Zip LIKE TRIM(CLK.Code) + '%'
            AND O.OrderKey = @c_Orderkey
            ORDER BY LEN(CLK.Code) DESC 
            --WL02 E
      
            IF ISNULL(@c_UDF01,'') = '' 
            BEGIN
               SET @c_UDF01 = '99'
            END
         END
         ELSE   --NOT IN SG List
         BEGIN
            SET @c_UDF01 = LEFT(@c_CCountry, 10)
         END
      END    
      
      UPDATE_RESULT:
      
      IF @c_Action IN ('INSERT', 'UPDATE')
      BEGIN
         --WL02 S
         --UPDATE ORDERS
         --SET [Route]    = @c_UDF01
         --  , TrafficCop = NULL
         --  , ArchiveCop = NULL
         --  , EditDate   = GETDATE()
         --  , EditWho    = SUSER_SNAME()
         --FROM #INSERTED I 
         --JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = I.ORDERKEY
         --WHERE I.Orderkey = @c_Orderkey   --WL01

         UPDATE ORDERS  
         SET [Route]    = @c_UDF01  
           , TrafficCop = NULL  
           , ArchiveCop = NULL  
           , EditDate   = GETDATE()  
           , EditWho    = SUSER_SNAME()  
         WHERE Orderkey = @c_Orderkey
         --WL02 E
      END    

      --WL01 S
      FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey
   END   
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP
   --WL01 E
                   
   QUIT_SP:

   --WL01 S
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END
   --WL01 E

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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispORD14'      
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