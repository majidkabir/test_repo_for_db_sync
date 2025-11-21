SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispREC08                                           */
/* Creation Date: 26-Jan-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-16147 CN & TW & HK Generate_Transmitlog2_for_Nike_SEC_  */   
/*          Goods_Receipt_Out_Interface                                 */ 
/*                                                                      */
/* Called By: isp_ReceiptTrigger_Wrapper from Receipt Trigger           */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 26-Jan-2021  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/

CREATE PROC [dbo].[ispREC08]
      @c_Action        NVARCHAR(10),
      @c_Storerkey     NVARCHAR(15),  
      @b_Success       INT           OUTPUT,
      @n_Err           INT           OUTPUT, 
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
           @c_Listname        NVARCHAR(50),
           @c_UDF01           NVARCHAR(50),
           @c_Userdefine03    NVARCHAR(30) = '',
           @c_TransmitLogKey  NVARCHAR(10),
           @c_Receiptkey      NVARCHAR(10)
                                                       
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
   
   SET @c_TableName = 'WSGRRCPTLOG'   
   SET @c_Listname  = 'RECTYPE'
   SET @c_UDF01     = 'GR'

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   

   IF @c_Action IN ('UPDATE')  
   BEGIN
      --Check if update ASNStatus = 9
      IF EXISTS (SELECT 1 FROM #INSERTED I 
                 JOIN #DELETED D ON I.Receiptkey = D.Receiptkey 
                 WHERE I.ASNStatus <> D.ASNStatus AND I.ASNStatus = '9' AND I.Storerkey = @c_Storerkey)
      BEGIN 
         --Check if Receipt.RecType is in Codelkup.Code where Listname = RECTYPE and UDF01 = GR
         IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
                    JOIN #INSERTED I (NOLOCK) ON I.RecType = CL.Code
                    WHERE CL.LISTNAME = @c_Listname
                    AND CL.Storerkey = @c_Storerkey
                    AND CL.UDF01 = @c_UDF01)
         BEGIN
            --Loop Every Distinct UserDefine03 and insert into TransmitLog2 table
            DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT RD.ReceiptKey, RD.UserDefine03
            FROM #INSERTED I
            JOIN RECEIPTDETAIL RD (NOLOCK) ON I.Receiptkey = RD.ReceiptKey
            ORDER BY RD.ReceiptKey, RD.UserDefine03
            
            OPEN CUR_LOOP
               
            FETCH NEXT FROM CUR_LOOP INTO @c_Receiptkey, @c_Userdefine03
            
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               SELECT @b_success = 1
               
               EXECUTE nspg_getkey      
                     'TransmitLogKey2'      
                     , 10      
                     , @c_TransmitLogKey OUTPUT      
                     , @b_success        OUTPUT      
                     , @n_err            OUTPUT      
                     , @c_errmsg         OUTPUT      
               
               IF NOT @b_success = 1      
               BEGIN      
                  SET @n_continue = 3      
                  SET @n_err = 63800   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                  SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain TransmitLogKey2. (ispREC08)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '      
                  GOTO QUIT_SP  
               END      
               
               INSERT INTO TRANSMITLOG2 (transmitlogkey, tablename, key1, key2, key3, transmitflag)
               SELECT @c_TransmitLogKey, @c_TableName, @c_Receiptkey, @c_Userdefine03, @c_Storerkey, '0'
               
               SELECT @n_err = @@ERROR  
               
               IF @n_err <> 0  
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63805    
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                                   + ': Insert Failed On Table TRANSMITLOG2. (ispREC08)'   
                                   + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
               END
               
               FETCH NEXT FROM CUR_LOOP INTO @c_Receiptkey, @c_Userdefine03
            END --Cursor
         END
      END         
   END         

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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispREC08'      
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