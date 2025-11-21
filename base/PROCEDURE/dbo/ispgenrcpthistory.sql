SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispGenRcptHistory                                  */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Generic Trigantic Receipt History Interface Records         */  
/*                                                                      */  
/* Called By: Schedule Job                                              */  
/*                                                                      */  
/* PVCS Version: 1.2                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 28-Nov-2005  Shong         Performance Tuning - Convert Select MIN   */  
/*                            To Cursor Loop (SHONG_20051128)           */   
/* 09-Apr-2013  Shong         Replace GetKey with isp_GetTriganticKey   */
/*                            to reduce blocking                        */
/* 22-May-2013  TLTING01      Call nspg_getkey to gen TriganticKey      */
/************************************************************************/  
CREATE PROCEDURE [dbo].[ispGenRcptHistory]
AS
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   DECLARE @cReceiptKey        NVARCHAR(10)
          ,@c_TriganticLogkey  NVARCHAR(10)
          ,@b_success          INT
          ,@n_continue         INT
          ,@n_err              INT
          ,@c_errmsg           NVARCHAR(252)  
   
   SELECT @n_continue = 1  
   SELECT @cReceiptKey = SPACE(10) 
   
   -- (SHONG_20051128)  
   DECLARE C_Trigantic_ReceiptHist CURSOR LOCAL FAST_FORWARD READ_ONLY 
   FOR
       SELECT t1.key1
       FROM   triganticlog t1(NOLOCK)
              LEFT OUTER JOIN (
                       SELECT key1
                       FROM   triganticlog(NOLOCK)
                       WHERE  tablename = 'RCPTHIST'
                   ) AS t2
                   ON  t1.key1 = t2.key1
       WHERE  t1.tablename = 'RECEIPT'
       AND    (t2.key1 IS NULL OR t2.key1 = NULL)
       AND    t1.transmitflag = '9'
       ORDER BY
              t1.key1 
   
   OPEN C_Trigantic_ReceiptHist   
   
   WHILE @@TRANCOUNT > 0 
         COMMIT TRAN 
   
   
   FETCH NEXT FROM C_Trigantic_ReceiptHist INTO @cReceiptKey   
   
   WHILE @@FETCH_STATUS <> -1
   AND   (@n_continue = 1 OR @n_continue = 2)
   BEGIN
       IF EXISTS(
              SELECT ReceiptKey
              FROM   Receipt(NOLOCK)
              WHERE  ReceiptKey = @cReceiptKey
              AND    DATEDIFF(DAY ,EditDate ,GETDATE()) > 3
          )
       BEGIN
           --TLTING01
           EXECUTE nspg_getkey 
           'TRIGANTICKEY' 
           ,10 
           , @c_TriganticLogkey OUTPUT 
           , @b_success OUTPUT 
           , @n_err OUTPUT 
           , @c_errmsg OUTPUT  

--           EXECUTE isp_GetTriganticKey  
--             10 
--           , @c_TriganticLogkey OUTPUT 
--           , @b_success OUTPUT 
--           , @n_err OUTPUT 
--           , @c_errmsg OUTPUT  
                      
           IF NOT @b_success = 1
           BEGIN
               SELECT @n_continue = 3
           END  
           
           IF (@n_continue = 1 OR @n_continue = 2)
           BEGIN
               BEGIN TRAN   
               
               INSERT TriganticLog
                 (
                   TriganticLogkey
                  ,tablename
                  ,key1
                  ,key2
                  ,key3
                 )
               VALUES
                 (
                   @c_TriganticLogkey
                  ,'RCPTHIST'
                  ,@cReceiptKey
                  ,''
                  ,''
                 )  
               
               SELECT @n_err = @@Error  
               IF NOT @n_err = 0
               BEGIN
                   SELECT @n_continue = 3 
                   ROLLBACK TRAN
               END
               ELSE
               BEGIN
                   COMMIT TRAN
               END
           END--  ( @n_continue = 1 or @n_continue = 2 )
       END -- if no transaction more then 3 days  
       
       FETCH NEXT FROM C_Trigantic_ReceiptHist INTO @cReceiptKey
   END -- While  
   CLOSE C_Trigantic_ReceiptHist 
   DEALLOCATE C_Trigantic_ReceiptHist   
   
   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
       WHILE @@TRANCOUNT > 0 
             COMMIT TRAN
   END
   ELSE
   BEGIN
       ROLLBACK TRAN
   END       
   

GO