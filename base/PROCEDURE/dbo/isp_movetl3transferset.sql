SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store Procedure: isp_MoveTL3TransferSet                              */      
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
      
CREATE PROCEDURE [dbo].[isp_MoveTL3TransferSet]      
     @c_SourceDB    NVARCHAR(30)      
   , @c_TargetDB    NVARCHAR(30)      
   , @c_TableSchema NVARCHAR(10)      
   , @c_TableName   NVARCHAR(50)      
   , @c_KeyColumn   NVARCHAR(50) -- OrderKey      
   , @c_DocKey      NVARCHAR(50)      
   , @c_key3        NVARCHAR(20) =''--Storerkey     t
   , @b_Success     int           OUTPUT      
   , @n_err         int           OUTPUT      
   , @c_errmsg      NVARCHAR(250) OUTPUT      
   , @b_Debug       INT = 0    
AS      
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
DECLARE @c_SQL                  NVARCHAR(MAX)      
      , @c_StorerKey            NVARCHAR(15)      
      , @c_Sku                  NVARCHAR(20)      
      , @c_Lot                  NVARCHAR(10)           
      , @c_ValidFlag            NVARCHAR(1)      
      , @c_ArchiveCop           NVARCHAR(1)      
      , @n_DummyQty             INT      
      , @c_ExecArguments        NVARCHAR(MAX)      
      , @b_RecFound             INT      
      , @n_continue             int            
      , @n_StartTCnt            INT       
      , @c_ExecSQL              NVARCHAR(MAX)        
      , @c_TransferKey          NVARCHAR(20)        
      , @c_TransferLineNumber   NVARCHAR(20)    
      , @c_sourcekey            NVARCHAR(60)  
      , @c_chkstorerkey         NVARCHAR(20)      --CS01   
      , @c_ExecDSQL             NVARCHAR(MAX)    
      , @c_getsourcekey         NVARCHAR(30)
      , @c_TranType             NVARCHAR(10)
   
      
   SELECT @n_continue=1      
      
SET @c_ArchiveCop = NULL      
SET @n_DummyQty   = '0'      
      
SET @c_StorerKey = ''      
SET @c_Sku       = ''      
SET @c_Lot       = ''          
      
SET @c_SQL = ''    

SET @c_chkstorerkey  = ''   --CS01

IF @b_Debug = 1
BEGIN
   SELECT 'Transfer' , @c_TableName '@c_TableName', @c_DocKey '@c_dockey'
END 

--CS01 START
SET @c_SQL = N'SELECT  TOP 1 @c_chkstorerkey = TF.FromStorerkey'  + CHAR(13) +        
                   'FROM ' +        
                   QUOTENAME(@c_SourceDB, '[') + '.dbo.TRANSFER TF (NOLOCK) ' + CHAR(13) +        
                   'WHERE TransferKey =  @c_DocKey  ' 
       
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
             SELECT TOP 1 @c_chkstorerkey = TF.FromStorerkey
             FROM TRANSFER TF WITH (NOLOCK)
             WHERE TransferKey =  @c_DocKey 
        END
  
 IF ISNULL(@c_chkstorerkey,'') <> '' 
 BEGIN     
       IF @c_key3 <> @c_chkstorerkey
       BEGIN
             SET @n_continue=1   
             --SET @n_err = 700003        
             --SELECT @c_errmsg = 'Storerkey not match (isp_MoveTL3TransferSet)'
             GOTO QUIT  
       END 
END
ELSE
BEGIN
        SET @n_continue=3   
        SET @n_err = 700003        
        SELECT @c_errmsg = 'NO Data found (isp_MoveTL3TransferSet)'
        GOTO QUIT  
END 
--CS01 END      
    
MOVE_TRANSFER:     

  IF @b_Debug = '1'
  BEGIN

     SELECT 'MOVE TRANSFER',@c_DocKey '@c_DocKey'
    
  END
    
   EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'TRANSFER', 'TransferKey', @c_DocKey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
        
   IF @b_Success <> 1 AND @c_errmsg <> ''      
   BEGIN      
     SET @n_continue=3      
     GOTO QUIT      
   END      
--END      
    
MOVE_TransferDetail:      
BEGIN          
          
     SET @c_StorerKey = ''      
     SET @c_ExecSQL = ''      
      
     SET @c_ExecSQL=N' DECLARE CUR_TFDET CURSOR FAST_FORWARD READ_ONLY FOR'        
                 + ' SELECT DISTINCT TD.TransferKey,TD.TransferLineNumber'        
                 + ' FROM ' + @c_SourceDB + '.dbo.transferdetail TD WITH (NOLOCK)'        
                 + ' WHERE TD.TransferKey =  @c_DocKey '         
                 + ' ORDER BY TD.TransferKey,TD.TransferLineNumber'        
        
   EXEC sp_executesql @c_ExecSQL,        
            N'@c_DocKey NVARCHAR(20)',         
              @c_DocKey       
         
   OPEN CUR_TFDET        
           
   FETCH NEXT FROM CUR_TFDET INTO  @c_TransferKey ,@c_TransferLineNumber
           
   WHILE @@FETCH_STATUS <> -1        
   BEGIN        
      SET @n_Continue = 1        
         
     IF EXISTS (SELECT 1 FROM dbo.TRANSFER WITH (NOLOCK) WHERE TransferKey = @c_TransferKey)      
     BEGIN      
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'transferdetail', 'TransferKey', @c_TransferKey,'TransferLineNumber',@c_TransferLineNumber ,'','','','',       
                 @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
     END    
    
         IF @b_Success <> 1 AND @c_errmsg <> ''      
         BEGIN      
           SET @n_continue=3      
           GOTO QUIT      
         END      
      
   FETCH NEXT FROM CUR_TFDET INTO @c_TransferKey ,@c_TransferLineNumber
   END        
        
   CLOSE CUR_TFDET        
   DEALLOCATE CUR_TFDET        
END   
    
MOVE_ITRN:        
BEGIN      
  IF @b_Debug = '1'
  BEGIN

     SELECT 'MOVE ITRN',@c_DocKey '@c_DocKey'
    
  END
   SET @c_ExecSQL = ''      
      
     SET @c_ExecSQL=N' DECLARE CUR_TFITRN CURSOR FAST_FORWARD READ_ONLY FOR'        
                 + ' SELECT DISTINCT TD.TransferKey,TD.TransferLineNumber'        
                 + ' FROM transferdetail TD WITH (NOLOCK)'        
                 + ' WHERE TD.TransferKey =  @c_DocKey '         
                 + ' ORDER BY TD.TransferKey,TD.TransferLineNumber'        
        
   EXEC sp_executesql @c_ExecSQL,        
            N'@c_DocKey NVARCHAR(20)',         
              @c_DocKey       
         
   OPEN CUR_TFITRN        
           
   FETCH NEXT FROM CUR_TFITRN INTO  @c_TransferKey ,@c_TransferLineNumber
           
   WHILE @@FETCH_STATUS <> -1        
   BEGIN        
      SET @n_Continue = 1  
      SET @c_sourcekey = ''
      SET @c_ExecDSQL = ''

                SET @c_sourcekey = (@c_TransferKey+@c_TransferLineNumber)

                SET @c_ExecDSQL=N' DECLARE CUR_TFTYPEITRN CURSOR FAST_FORWARD READ_ONLY FOR'        
                          + ' SELECT DISTINCT ITRN.Sourcekey,ITRN.TranType'        
                          + ' FROM ' + @c_SourceDB + '.dbo.ITRN ITRN WITH (NOLOCK)'         
                          + ' WHERE ITRN.sourcekey =  @c_sourcekey '         
                          + ' ORDER BY ITRN.sourcekey,ITRN.TranType '        
        
                        EXEC sp_executesql @c_ExecDSQL,        
                                 N'@c_sourcekey NVARCHAR(30)',         
                                   @c_sourcekey       
         
                        OPEN CUR_TFTYPEITRN        
           
                        FETCH NEXT FROM CUR_TFTYPEITRN INTO @c_getsourcekey,@c_TranType   
           
                        WHILE @@FETCH_STATUS <> -1        
                        BEGIN  
                         --     PRINT 'chk move itrn'
                          IF ISNULL(@c_getsourcekey,'') <> ''
                          BEGIN
                                 EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'ITRN', 'sourcekey', @c_sourcekey,'TranType',@c_TranType ,'','','','',       
                                      @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug    
                          -- EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'ITRN', 'sourcekey', @c_sourcekey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
      
                         END  
                               --  PRINT 'chk @b_Success ' +  CAST(@b_Success AS NVARCHAR(10))
                                    IF @b_Success <> 1 AND @c_errmsg <> ''      
                                    BEGIN      
                                      SET @n_continue=3      
                                      GOTO QUIT      
                                    END   

                      FETCH NEXT FROM CUR_TFTYPEITRN INTO @c_getsourcekey,@c_TranType  
                     END        
        
                     CLOSE CUR_TFTYPEITRN        
                     DEALLOCATE CUR_TFTYPEITRN 

   FETCH NEXT FROM CUR_TFITRN INTO @c_TransferKey ,@c_TransferLineNumber
   END        
        
   CLOSE CUR_TFITRN        
   DEALLOCATE CUR_TFITRN   
END      
    
MOVE_LOTATTRIBUTE:      
BEGIN          
     
     SET @c_StorerKey = ''      
     SET @c_ExecSQL = ''      
      
      SET @c_ExecSQL=N' DECLARE CUR_TFLOTT CURSOR FAST_FORWARD READ_ONLY FOR'        
                 + ' SELECT DISTINCT TD.Fromlot'        
                 + ' FROM dbo.transferdetail TD WITH (NOLOCK)'   
                 + ' JOIN ' + @c_SourceDB + '.dbo.LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.lot=TD.Fromlot '      
                 + ' WHERE TD.TransferKey =  @c_DocKey '         
                 + ' ORDER BY TD.Fromlot' 
        
   EXEC sp_executesql @c_ExecSQL,        
            N'@c_DocKey NVARCHAR(20)',         
              @c_DocKey       
         
   OPEN CUR_TFLOTT        
           
   FETCH NEXT FROM CUR_TFLOTT INTO @c_lot    
           
   WHILE @@FETCH_STATUS <> -1        
   BEGIN        
      SET @n_Continue = 1        
         
        EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'LOTATTRIBUTE', 'lot', @c_lot, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
 
         IF @b_Success <> 1 AND @c_errmsg <> ''      
         BEGIN      
           SET @n_continue=3      
           GOTO QUIT      
         END      
      
   FETCH NEXT FROM CUR_TFLOTT INTO @c_lot     
   END        
        
   CLOSE CUR_TFLOTT        
   DEALLOCATE CUR_TFLOTT        
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