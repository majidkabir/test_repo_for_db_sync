SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispORD10                                           */
/* Creation Date: 11-Aug-2020                                           */
/* Copyright: LFL                                                       */
/* Written by: CHONGCS                                                  */
/*                                                                      */
/* Purpose: WMS-14238  - SG - MDM - Auto Trigger EDI to OTM             */   
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
/* 12-SEP-2020  CSCHONG  1.1  WMS-14238 add new trigger (CS01)          */
/************************************************************************/

CREATE PROC [dbo].[ispORD10]   
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
           @c_Option1         NVARCHAR(50) = '',
           @c_Option2         NVARCHAR(50) = '',
           @c_Option3         NVARCHAR(50) = '',
           @c_Option4         NVARCHAR(50) = '',
           @c_Option5         NVARCHAR(4000) = '',
           @c_Options         NVARCHAR(4000) = ''
           
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('UPDATE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END

   --IF(@n_Continue = 1 OR @n_Continue = 2)
   --BEGIN
   --   SELECT  @c_Option1 = ISNULL(Option1,'')
   --          ,@c_Option2 = ISNULL(Option2,'')
   --          ,@c_Option3 = ISNULL(Option3,'')
   --          ,@c_Option4 = ISNULL(Option4,'')
   --          ,@c_Option5 = ISNULL(Option5,'')
   --   FROM STORERCONFIG (NOLOCK)
   --   WHERE STORERKEY = @c_Storerkey AND CONFIGKEY = 'OrdersTrigger_SP'
   --   AND SValue = 'ispORD09' 

   --   SELECT @c_Options = LTRIM(RTRIM(@c_Option1)) + ',' + LTRIM(RTRIM(@c_Option2)) + ',' + LTRIM(RTRIM(@c_Option3)) + ',' + 
   --                       LTRIM(RTRIM(@c_Option4)) + ',' + LTRIM(RTRIM(@c_Option5))  
   --END   

   IF @c_Action IN('UPDATE')
   BEGIN
      IF NOT EXISTS(SELECT 1 
                    FROM #DELETED D
                    JOIN ORDERS O (NOLOCK) ON D.Orderkey = O.Orderkey
                    WHERE D.[Status] IN ('0','2','5') )
      BEGIN
         GOTO QUIT_SP
      END
   IF EXISTS(SELECT 1 
                    FROM #DELETED D
                    JOIN ORDERS O (NOLOCK) ON D.Orderkey = O.Orderkey 
                    WHERE D.[Status] IN ('2') 
                    AND (D.deliverydate <> O.deliverydate
                    OR ISNULL(D.notes,'') <> ISNULL(O.notes,'')
                    OR ISNULL(D.notes2,'') <> ISNULL(O.notes2,'')
                    OR D.containertype <> O.containertype
                    OR D.C_Zip <> O.C_Zip) )
   BEGIN
         INSERT INTO OTMLOG (tablename, key1, key2, key3, transmitflag, TransmitBatch)  
         SELECT'SOALLOCOTM', O.Orderkey, D.[Status], O.storerkey, '0', ''
         FROM #DELETED D
         JOIN ORDERS O (NOLOCK) ON D.Orderkey = O.Orderkey 
         WHERE D.[Status] IN ('2')  
   END
   ELSE IF EXISTS(SELECT 1 
                    FROM #DELETED D
                    JOIN ORDERS O (NOLOCK) ON D.Orderkey = O.Orderkey 
                    WHERE D.[Status] IN ('5') 
                    AND (D.deliverydate <> O.deliverydate
                    OR ISNULL(D.notes,'') <> ISNULL(O.notes,'')
                    OR ISNULL(D.notes2,'') <> ISNULL(O.notes2,'')
                    OR D.containertype <> O.containertype
                    OR D.C_Zip <> O.C_Zip) )
   BEGIN
         INSERT INTO OTMLOG (tablename, key1, key2, key3, transmitflag, TransmitBatch)  
         SELECT'SOPNPOTM', O.Orderkey, D.[Status], O.storerkey, '0', ''
         FROM #DELETED D
         JOIN ORDERS O (NOLOCK) ON D.Orderkey = O.Orderkey 
         WHERE D.[Status] IN ('5')  
   END 
   /*CS01 START*/
   ELSE IF EXISTS(SELECT 1 
                    FROM #DELETED D
                    JOIN ORDERS O (NOLOCK) ON D.Orderkey = O.Orderkey 
                    WHERE D.[Status] IN ('0') 
                    AND (D.deliverydate <> O.deliverydate
                    OR ISNULL(D.notes,'') <> ISNULL(O.notes,'')
                    OR ISNULL(D.notes2,'') <> ISNULL(O.notes2,'')
                    OR D.containertype <> O.containertype
                    OR D.C_Zip <> O.C_Zip) )
   BEGIN
         INSERT INTO OTMLOG (tablename, key1, key2, key3, transmitflag, TransmitBatch)  
         SELECT'SOADDOTM', O.Orderkey, D.[Status], O.storerkey, '0', ''
         FROM #DELETED D
         JOIN ORDERS O (NOLOCK) ON D.Orderkey = O.Orderkey 
         WHERE D.[Status] IN ('0')  
   END 

   /*CS01 END*/
      
      IF @@ERROR <> 0 
      BEGIN 
         SELECT @n_Continue = 3
         SELECT @n_Err = 38000
         SELECT @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': INSERT into OTMLOG Fail. (ispORD10)' 
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
       EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispORD10'     
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