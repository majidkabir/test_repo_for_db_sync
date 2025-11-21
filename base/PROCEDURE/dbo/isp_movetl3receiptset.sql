SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store Procedure: isp_MoveTL3ReceiptSet                               */      
/* Creation Date:03-FEB-2020                                            */      
/* Copyright: IDS                                                       */      
/* Written by: LFL                                                      */      
/*                                                                      */      
/* Purpose: - To move archived table setup in codelkup back to live db. */      
/*                                                                      */      
/* Called By:                                                           */      
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Modifications:                                                       */      
/* Date         Author    Ver.  Purposes                                */   
/* Date         Author    Ver.  Purposes                                */  
/* 27-JAN-2022  CSCHONG   1.0    Devops Scripts Combine                 */ 
/* 22-JUL-2021  CSCHONG   1.1    WMS-10009 add in key3 parameter (CS01) */    
/************************************************************************/      
      
CREATE PROCEDURE [dbo].[isp_MoveTL3ReceiptSet]      
     @c_SourceDB    NVARCHAR(30)      
   , @c_TargetDB    NVARCHAR(30)      
   , @c_TableSchema NVARCHAR(10)      
   , @c_TableName   NVARCHAR(50)      
   , @c_KeyColumn   NVARCHAR(50) -- OrderKey      
   , @c_DocKey      NVARCHAR(50)      
   , @c_key3        NVARCHAR(20) =''--Storerkey 
   , @b_Success     int           OUTPUT      
   , @n_err         int           OUTPUT      
   , @c_errmsg      NVARCHAR(250) OUTPUT      
   , @b_Debug       INT = 0    
AS      
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
DECLARE @c_SQL             NVARCHAR(MAX)      
      , @c_StorerKey       NVARCHAR(15)                     
      , @c_ValidFlag       NVARCHAR(1)      
      , @c_ArchiveCop      NVARCHAR(1)      
      , @n_DummyQty        INT      
      , @c_ExecArguments   NVARCHAR(MAX)      
      , @b_RecFound        INT      
      , @n_continue        int       
      , @c_pokey           NVARCHAR(50)           
      , @c_orderkey        NVARCHAR(20)           
      , @n_StartTCnt       INT       
      , @c_ExecSQL         NVARCHAR(MAX)    
      , @c_OrderLineNumber  NVARCHAR(10)      
      , @c_getOrderKey      NVARCHAR(50)           
      , @c_getpokey            NVARCHAR(20)   
      , @c_POLineNumber        NVARCHAR(10)     
      , @n_UCC_RowRef          INT               
      , @c_receiptKey          NVARCHAR(20)        
      , @c_receiptLineNumber   NVARCHAR(20)    
      , @c_sourcekey           NVARCHAR(60)  
      , @c_chkstorerkey        NVARCHAR(20)      --CS01  
      , @c_UCCNo               NVARCHAR(20)
     
      
   SELECT @n_continue=1      
      
SET @c_ArchiveCop = NULL      
SET @n_DummyQty   = '0'      
      
SET @c_StorerKey = ''          
      
SET @c_SQL = ''     

SET @c_chkstorerkey  = ''   --CS01

IF @b_Debug = 1
BEGIN
   SELECT 'RECEIPT' , @c_TableName '@c_TableName', @c_DocKey '@c_dockey'
END 

--CS01 START
SET @c_SQL = N'SELECT  TOP 1 @c_chkstorerkey = RH.Storerkey'  + CHAR(13) +        
                   'FROM ' +        
                   QUOTENAME(@c_SourceDB, '[') + '.dbo.RECEIPT RH (NOLOCK) ' + CHAR(13) +        
                   'WHERE RH.Receiptkey =  @c_DocKey  ' 
       
        SET @c_ExecArguments = N'@c_DocKey NVARCHAR(50), @c_chkstorerkey NVARCHAR(20) OUTPUT'        
       
        EXEC sp_executesql @c_SQL        
            , @c_ExecArguments        
            , @c_DocKey         
           -- , @c_key3      
            , @c_chkstorerkey OUTPUT        
       
         IF @b_debug = '1'        
         BEGIN        
            SELECT @c_SQL '@c_SQL'        
            SELECT @c_Storerkey ' @c_Storerkey'        
         END   

        IF ISNULL(@c_chkstorerkey,'') = ''
        BEGIN
             SELECT TOP 1 @c_chkstorerkey = RH.Storerkey
             FROM RECEIPT RH WITH (NOLOCK)
             WHERE RH.Receiptkey =  @c_DocKey 
        END
IF ISNULL(@c_chkstorerkey,'') <> '' 
 BEGIN    
       IF @c_key3 <> @c_chkstorerkey
       BEGIN
             SET @n_continue=3   
             SET @n_err = 700003        
             SELECT @c_errmsg = 'Storerkey not match (isp_MoveTL3ReceiptSet)'
             GOTO QUIT  
       END 
END
ELSE
BEGIN
        SET @n_continue=1   
        --SET @n_err = 700003        
        --SELECT @c_errmsg = 'NO Data found (isp_MoveTL3ReceiptSet)'
        GOTO QUIT  
END 
--CS01 END       
    
MOVE_RECEIPT:       
BEGIN      
  IF @b_Debug = '1'
  BEGIN

     SELECT 'MOVE RECEIPT',@c_DocKey '@c_DocKey'
    
  END
    
   EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'RECEIPT', 'Receiptkey', @c_DocKey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
        
   IF @b_Success <> 1 AND @c_errmsg <> ''      
   BEGIN      
     SET @n_continue=3      
     GOTO QUIT      
   END      
END      
    
MOVE_RECEIPTDetail:      
BEGIN          
         
     SET @c_StorerKey = ''      
     SET @c_ExecSQL = ''      
      
     SET @c_ExecSQL=N' DECLARE CUR_RDET CURSOR FAST_FORWARD READ_ONLY FOR'        
                 + ' SELECT DISTINCT RD.ReceiptKey,RD.ReceiptLineNumber'        
                 + ' FROM ' + @c_SourceDB + '.dbo.RECEIPTDetail RD WITH (NOLOCK)'        
                 + ' WHERE RD.ReceiptKey =  @c_DocKey '         
                 + ' ORDER BY RD.ReceiptKey,RD.ReceiptLineNumber'        
        
   EXEC sp_executesql @c_ExecSQL,        
            N'@c_DocKey NVARCHAR(50)',         
              @c_DocKey       
         
   OPEN CUR_RDET        
           
   FETCH NEXT FROM CUR_RDET INTO  @c_receiptKey ,@c_receiptLineNumber
           
   WHILE @@FETCH_STATUS <> -1        
   BEGIN        
      SET @n_Continue = 1        
         
     IF EXISTS (SELECT 1 FROM dbo.RECEIPT WITH (NOLOCK) WHERE receiptKey = @c_receiptKey)      
     BEGIN      
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'RECEIPTDetail', 'ReceiptKey', @c_receiptKey,'ReceiptLineNumber',@c_receiptLineNumber ,'','','','',       
                 @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
     END    
    
         IF @b_Success <> 1 AND @c_errmsg <> ''      
         BEGIN      
           SET @n_continue=3      
           GOTO QUIT      
         END      
      
   FETCH NEXT FROM CUR_RDET INTO @c_receiptKey ,@c_receiptLineNumber
   END        
        
   CLOSE CUR_RDET        
   DEALLOCATE CUR_RDET        
END   
    
MOVE_PO:
BEGIN     
      SET @c_pokey = ''  
      SET @c_StorerKey = ''
      SELECT TOP 1 @c_pokey = POKey  
                  ,@c_StorerKey = storerkey  
      FROM Receiptdetail  WITH (NOLOCK)  
      WHERE receiptkey = @c_DocKey  
  
   EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PO', 'pokey', @c_pokey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
    
   IF @b_Success <> 1 AND @c_errmsg <> ''  
   BEGIN  
     SET @n_continue=3  
     GOTO QUIT  
   END  
END  

MOVE_PODETAIL:
BEGIN   
  
       SET @c_pokey = ''  
       SET @c_StorerKey = ''  
       SET @c_ExecSQL = ''  
  
      SET @c_pokey = ''  
      SET @c_StorerKey = ''
      SELECT TOP 1 @c_pokey = POKey  
                  ,@c_StorerKey = storerkey  
      FROM Receiptdetail  WITH (NOLOCK)  
      WHERE receiptkey = @c_DocKey   
  
     SET @c_ExecSQL=N' DECLARE CUR_PODET CURSOR FAST_FORWARD READ_ONLY FOR'    
                 + ' SELECT DISTINCT pokey,POLineNumber'    
                 + ' FROM ' + @c_SourceDB + '.dbo.PODETAIL POD WITH (NOLOCK)'     
                 + ' WHERE POD.pokey =  @c_pokey '     
                 + ' ORDER BY pokey,POLineNumber '    
    
   EXEC sp_executesql @c_ExecSQL,    
            N'@c_pokey NVARCHAR(20)',     
              @c_pokey  
     
   OPEN CUR_PODET    
       
   FETCH NEXT FROM CUR_PODET INTO @c_getpokey,@c_POLineNumber    
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      SET @n_Continue = 1    
   IF EXISTS (SELECT 1 FROM PO WITH (NOLOCK) WHERE pokey = @c_getpokey)  
   BEGIN  
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'PODETAIL', 'pokey', @c_getpokey,'POLineNumber',@c_POLineNumber ,'','','','',   
                 @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
         END  
   --END  
   IF @b_Success <> 1 AND @c_errmsg <> ''  
   BEGIN  
     SET @n_continue=3  
     GOTO QUIT  
   END  
  
   FETCH NEXT FROM CUR_PODET INTO @c_getpokey,@c_POLineNumber      
   END    
    
   CLOSE CUR_PODET    
   DEALLOCATE CUR_PODET    
END 

MOVE_UCC:
BEGIN  
  
       SET @c_receiptkey = ''  
       SET @c_StorerKey = ''  
       SET @c_ExecSQL = ''  
  
  
     SET @c_ExecSQL=N' DECLARE CUR_RECUCC CURSOR FAST_FORWARD READ_ONLY FOR'    
                 + ' SELECT DISTINCT UCC_RowRef,uccno'    
                 + ' FROM ' + @c_SourceDB + '.dbo.UCC UCC WITH (NOLOCK)'     
                 + ' WHERE UCC.receiptkey =  @c_dockey '      
    
   EXEC sp_executesql @c_ExecSQL,    
            N'@c_dockey NVARCHAR(50)',     
              @c_dockey
     
   OPEN CUR_RECUCC    
       
   FETCH NEXT FROM CUR_RECUCC INTO @n_UCC_RowRef,@c_UCCNo    
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      SET @n_Continue = 1    

      IF EXISTS (SELECT 1 FROM receipt WITH (NOLOCK) WHERE receiptkey = @c_dockey)  
      BEGIN  
         --EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'UCC', 'UCC_RowRef', @n_UCC_RowRef, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'UCC', 'UCC_RowRef', @n_UCC_RowRef,'UCCNo',@c_UCCNo ,'','','','',       
                 @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug    
      END  
 
   IF @b_Success <> 1 AND @c_errmsg <> ''  
   BEGIN  
     SET @n_continue=3  
     GOTO QUIT  
   END  
  
   FETCH NEXT FROM CUR_RECUCC INTO @n_UCC_RowRef,@c_UCCNo  
   END    
    
   CLOSE CUR_RECUCC    
   DEALLOCATE CUR_RECUCC    

END  


MOVE_ORDERS:     
     
BEGIN      
  IF @b_Debug = '1'
  BEGIN

     SELECT 'MOVE ORDERS',@c_DocKey '@c_DocKey'
    
  END
 --PRINT 'move orders'

   SET @c_ExecSQL = ''

  SET @c_ExecSQL=N' DECLARE CUR_ORDHD CURSOR FAST_FORWARD READ_ONLY FOR'          
                 + ' SELECT DISTINCT OH.Orderkey'          
                 + ' FROM ' + @c_SourceDB + '.dbo.ORDERS OH WITH (NOLOCK) '  
                 + ' JOIN RECEIPT RH WITH (NOLOCK) ON RH.ExternReceiptKey = OH.ExternOrderKey AND RH.storerkey = OH.Storerkey'       
                 + ' WHERE RH.receiptkey =  @c_DocKey '           
                 + ' ORDER BY OH.Orderkey '        
   
    EXEC sp_executesql @c_ExecSQL,          
                    N'@c_DocKey NVARCHAR(50)',           
                      @c_DocKey         
               
   OPEN CUR_ORDHD          
             
   FETCH NEXT FROM CUR_ORDHD INTO @c_orderkey        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN          
      SET @n_Continue = 1     
      
      EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'Orders', 'OrderKey', @c_orderkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
        
            IF @b_Success <> 1 AND @c_errmsg <> ''      
            BEGIN      
              SET @n_continue=3      
              GOTO QUIT      
            END 

   FETCH NEXT FROM CUR_ORDHD INTO @c_orderkey          
   END          
          
   CLOSE CUR_ORDHD          
   DEALLOCATE CUR_ORDHD         
END      
    
MOVE_ORDERDETAIL:      
BEGIN         
   -- PRINT 'move orderdetail'
          
     SET @c_StorerKey = ''      
     SET @c_ExecSQL = ''      
      
      SET @c_ExecSQL=N' DECLARE CUR_ODET CURSOR FAST_FORWARD READ_ONLY FOR'          
                 + ' SELECT DISTINCT OH.Orderkey,OD.OrderLineNumber '          
                  + ' FROM RECEIPT RH WITH (NOLOCK) '       
                 + ' JOIN ORDERS OH WITH (NOLOCK) ON RH.ExternReceiptKey = OH.ExternOrderKey AND RH.storerkey = OH.Storerkey'         
                 + ' JOIN ' + @c_SourceDB + '.dbo.ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey'                         
                 + ' WHERE RH.receiptkey =  @c_DocKey '           
                 + ' ORDER BY OH.Orderkey,OD.OrderLineNumber '         
       
--PRINT @c_ExecSQL 
   EXEC sp_executesql @c_ExecSQL,        
            N'@c_DocKey NVARCHAR(50)',         
              @c_DocKey       
         
   OPEN CUR_ODET        
           
   FETCH NEXT FROM CUR_ODET INTO @c_getOrderKey,@c_OrderLineNumber        
           
   WHILE @@FETCH_STATUS <> -1        
   BEGIN        
      SET @n_Continue = 1        
     
     IF EXISTS (SELECT 1 FROM Orders WITH (NOLOCK) WHERE OrderKey = @c_getOrderKey)      
     BEGIN      
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'ORDERDETAIL', 'OrderKey', @c_getOrderKey,'OrderLineNumber',@c_OrderLineNumber ,'','','','',       
                 @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
    END      
      
   IF @b_Success <> 1 AND @c_errmsg <> ''      
   BEGIN      
     SET @n_continue=3      
     GOTO QUIT      
   END      
      
   FETCH NEXT FROM CUR_ODET INTO @c_getOrderKey,@c_OrderLineNumber        
   END        
        
   CLOSE CUR_ODET        
   DEALLOCATE CUR_ODET        
END        
      
QUIT:      
      
IF @n_continue=3  -- Error Occured - Process And Return      
   BEGIN      
      SET @b_success = 0      
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt      
      BEGIN      
         ROLLBACK TRAN      
      END            ELSE      
      BEGIN      
         WHILE @@TRANCOUNT > @n_StartTCnt      
         BEGIN      
            COMMIT TRAN      
         END      
      END      
      --execute nsp_logerror @n_err, @c_errmsg, 'isp_RetriggerInterfaceSO'      
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
      RETURN      
   END      
   ELSE      
   BEGIN      
      SET @b_success = 1      
      WHILE @@TRANCOUNT > @n_StartTCnt      
      BEGIN      
         COMMIT TRAN      
      END      
      RETURN      
   END 


GO