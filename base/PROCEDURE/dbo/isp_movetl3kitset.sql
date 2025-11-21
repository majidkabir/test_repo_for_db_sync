SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/            
/* Store Procedure: isp_MoveTL3KitSet                                   */            
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
/* 27-JAN-2022  CSCHONG   1.0    Devops Scripts Combine                 */             
/* 22-JUL-2021  CSCHONG   1.1    WMS-10009 add in key3 parameter (CS01) */       
/************************************************************************/            
            
CREATE PROCEDURE [dbo].[isp_MoveTL3KitSet]            
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
      , @c_Sku             NVARCHAR(20)            
      , @c_Lot             NVARCHAR(10)            
      , @c_Loc             NVARCHAR(10)                     
      , @c_ValidFlag       NVARCHAR(1)            
      , @c_ArchiveCop      NVARCHAR(1)            
      , @n_DummyQty        INT            
      , @c_ExecArguments   NVARCHAR(MAX)            
      , @b_RecFound        INT            
      , @n_continue        int             
          
           
      , @n_StartTCnt       INT             
      , @c_ExecSQL         NVARCHAR(MAX)             
      , @c_KitKey          NVARCHAR(20)              
      , @c_KitLineNumber   NVARCHAR(20)   
      , @c_ItrnKey         NVARCHAR(20)  
      , @c_sourcekey       NVARCHAR(60)        
      , @c_chkstorerkey    NVARCHAR(20)      --CS01       
          
            
   SELECT @n_continue=1            
            
   SET @c_ArchiveCop = NULL            
   SET @n_DummyQty   = '0'            
            
   SET @c_StorerKey = ''            
   SET @c_Sku       = ''            
   SET @c_Lot       = ''            
   SET @c_Loc       = ''            
          
            
   SET @c_SQL = ''          
      
SET @c_chkstorerkey  = ''   --CS01      
      
IF @b_Debug = 1      
BEGIN      
   SELECT 'KIT' , @c_TableName '@c_TableName', @c_DocKey '@c_dockey'      
END       
      
--CS01 START      
SET @c_SQL = N'SELECT  TOP 1 @c_chkstorerkey = KIT.Storerkey'  + CHAR(13) +              
                   'FROM ' +              
                   QUOTENAME(@c_SourceDB, '[') + '.dbo.KIT KIT (NOLOCK) ' + CHAR(13) +              
                   'WHERE KIT.KITKey =  @c_DocKey  '       
             
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
             SELECT TOP 1 @c_chkstorerkey = KIT.Storerkey      
             FROM KIT  WITH (NOLOCK)      
             WHERE KIT.KITKey =  @c_DocKey       
        END      
      
 IF ISNULL(@c_chkstorerkey,'') <> ''       
 BEGIN           
       IF @c_key3 <> @c_chkstorerkey      
       BEGIN      
             SET @n_continue=3         
             SET @n_err = 700003              
             SELECT @c_errmsg = 'Storerkey not match (isp_MoveTL3KitSet)'      
             GOTO QUIT        
       END        
END      
ELSE      
BEGIN      
        SET @n_continue=1        
        --SET @n_err = 700003              
        --SELECT @c_errmsg = 'NO Data found (isp_MoveTL3KitSet)'      
        GOTO QUIT        
END      
--CS01 END             
          
MOVE_KIT:           
BEGIN            
  IF @b_Debug = '1'      
  BEGIN      
      
     SELECT 'MOVE KIT',@c_DocKey '@c_DocKey'      
          
  END      
          
   EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'KIT', 'KITKey', @c_DocKey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug            
              
   IF @b_Success <> 1 AND @c_errmsg <> ''            
   BEGIN            
     SET @n_continue=3            
     GOTO QUIT            
   END            
END            
          
MOVE_KITDETAIL:          
BEGIN                
          
     SET @c_StorerKey = ''            
     SET @c_ExecSQL = ''            
            
     SET @c_ExecSQL=N' DECLARE CUR_KITDET CURSOR FAST_FORWARD READ_ONLY FOR'              
                 + ' SELECT DISTINCT KD.KITKey,KD.KITLineNumber'              
                 + ' FROM ' + @c_SourceDB + '.dbo.KITDETAIL KD WITH (NOLOCK)'              
                 + ' WHERE KD.Kitkey =  @c_DocKey '               
                 + ' ORDER BY  KD.KITKey,KD.KITLineNumber'              
              
   EXEC sp_executesql @c_ExecSQL,              
            N'@c_DocKey NVARCHAR(20)',               
              @c_DocKey             
               
   OPEN CUR_KITDET              
                 
   FETCH NEXT FROM CUR_KITDET INTO  @c_kitKey ,@c_kitLineNumber      
                 
   WHILE @@FETCH_STATUS <> -1              
   BEGIN              
      SET @n_Continue = 1              
               
     IF EXISTS (SELECT 1 FROM dbo.KIT WITH (NOLOCK) WHERE Kitkey = @c_kitKey)            
     BEGIN            
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'KITDETAIL', 'KitKey', @c_kitKey,'KITLineNumber',@c_kitLineNumber ,'','','','',             
                 @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug            
     END          
          
         IF @b_Success <> 1 AND @c_errmsg <> ''            
         BEGIN            
           SET @n_continue=3            
           GOTO QUIT            
         END            
            
   FETCH NEXT FROM CUR_KITDET INTO @c_kitKey ,@c_kitLineNumber      
   END              
              
   CLOSE CUR_KITDET              
   DEALLOCATE CUR_KITDET              
END         
          
MOVE_ITRN:           
BEGIN            
  IF @b_Debug = '1'      
  BEGIN      
      
     SELECT 'MOVE ITRN',@c_DocKey '@c_DocKey'      
          
  END      
   SET @c_ExecSQL = ''           
   SET @c_ItrnKey = ''  
            
     SET @c_ExecSQL=N' DECLARE CUR_KITITRN CURSOR FAST_FORWARD READ_ONLY FOR'              
                 + ' SELECT ITRN.ItrnKey'        
                 + ' FROM KITDETAIL KD WITH (NOLOCK)'              
                 + ' JOIN ' + @c_SourceDB + '.dbo.ITRN WITH (NOLOCK) '    
                 + ' ON ITRN.SourceKey = KD.KitKey + KD.KITLineNumber '    
                 + ' WHERE KD.Kitkey =  @c_DocKey '               
                 + ' ORDER BY  KD.KITKey,KD.KITLineNumber'        
              
   EXEC sp_executesql @c_ExecSQL,              
            N'@c_DocKey NVARCHAR(20)',               
              @c_DocKey             
               
   OPEN CUR_KITITRN              
                 
   FETCH NEXT FROM CUR_KITITRN INTO  @c_ItrnKey  
                 
   WHILE @@FETCH_STATUS <> -1              
   BEGIN              
      SET @n_Continue = 1        
      SET @c_sourcekey = ''      
      
      --SET @c_sourcekey = (@c_kitKey+@c_kitLineNumber)      
      
      EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'ITRN', 'ItrnKey', @c_ItrnKey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug            
              
               IF @b_Success <> 1 AND @c_errmsg <> ''            
               BEGIN            
   SET @n_continue=3            
                 GOTO QUIT            
               END         
      
   FETCH NEXT FROM CUR_KITITRN INTO @c_ItrnKey  
   END              
              
   CLOSE CUR_KITITRN              
   DEALLOCATE CUR_KITITRN         
END            
            
QUIT:            
            
   IF @n_continue=3  -- Error Occured - Process And Return            
   BEGIN   

      IF (SELECT CURSOR_STATUS('local','CUR_KITITRN')) >= -1
      BEGIN
       CLOSE CUR_KITITRN
       DEALLOCATE CUR_KITITRN
      END 

      IF (SELECT CURSOR_STATUS('local','CUR_KITDET')) >= -1
      BEGIN
       CLOSE CUR_KITITRN
       DEALLOCATE CUR_KITITRN
      END 

        
      SET @b_success = 0            
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