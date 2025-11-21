SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store Procedure: isp_MoveTL3ITRNSet                                 */      
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
      
CREATE PROCEDURE [dbo].[isp_MoveTL3ITRNSet]      
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
      , @c_Id              NVARCHAR(18)      
      , @c_PackKey         NVARCHAR(10)      
      , @c_ValidFlag       NVARCHAR(1)      
      , @c_ArchiveCop      NVARCHAR(1)      
      , @n_DummyQty        INT      
      , @c_ExecArguments   NVARCHAR(MAX)      
      , @b_RecFound        INT      
      , @n_continue        int            
      , @n_StartTCnt       INT       
      , @c_ExecSQL         NVARCHAR(MAX)    
      , @c_chkstorerkey    NVARCHAR(20)      --CS01  
      
      
   SELECT @n_continue=1      
      
SET @c_ArchiveCop = NULL      
SET @n_DummyQty   = '0'      
      
SET @c_StorerKey = ''      
SET @c_Sku       = ''      
SET @c_Lot       = ''      
SET @c_Loc       = ''      
SET @c_Id        = ''      
      
SET @c_SQL = ''   

SET @c_StorerKey = ''          
      
SET @c_SQL = ''     

SET @c_chkstorerkey  = ''   --CS01

IF @b_Debug = 1
BEGIN
   SELECT 'ITRN' , @c_TableName '@c_TableName', @c_DocKey '@c_dockey', @c_SourceDB '@c_SourceDB',@c_TargetDB '@c_TargetDB'
END 

--CS01 START
SET @c_SQL = N'SELECT  TOP 1 @c_chkstorerkey = ITRN.Storerkey'  + CHAR(13) +        
                   'FROM ' +        
                   QUOTENAME(@c_SourceDB, '[') + '.dbo.ITRN ITRN (NOLOCK) ' + CHAR(13) +        
                   'WHERE ITRN.ItrnKey =  @c_DocKey  ' 
       
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

 IF ISNULL(@c_chkstorerkey,'') <> '' 
 BEGIN 
        IF ISNULL(@c_chkstorerkey,'') = ''
        BEGIN
             SELECT TOP 1 @c_chkstorerkey = ITRN.Storerkey
             FROM ITRN ITRN WITH (NOLOCK)
             WHERE ITRN.ItrnKey =  @c_DocKey 
        END
     
       IF @c_key3 <> @c_chkstorerkey
       BEGIN
             SET @n_continue=3   
             SET @n_err = 700003        
             SELECT @c_errmsg = 'Storerkey not match (isp_MoveTL3ITRNSet)'
             GOTO QUIT  
       END
END
ELSE
BEGIN

        SET @n_continue=1   
        --SET @n_err = 700003        
        --SELECT @c_errmsg = @c_chkstorerkey + SPACE(2) + 'No Data moved in archive (isp_MoveTL3ITRNSet)'
        GOTO QUIT  

END  
--CS01 END      
    
MOVE_ITRN:     
--SELECT @c_DocKey '@c_DocKey'  
     
  IF @b_Debug = '1'
  BEGIN

     SELECT 'MOVE ITRN',@c_DocKey '@c_DocKey'
    
  END
    
   EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'ITRN', 'ItrnKey', @c_DocKey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
        
   IF @b_Success <> 1 AND @c_errmsg <> ''      
   BEGIN      
     SET @n_continue=3      
     GOTO QUIT      
   END          
    
MOVE_LOTATTRIBUTE:       
BEGIN          
         
     SET @c_StorerKey = ''      
     SET @c_ExecSQL = ''      
      
     SET @c_ExecSQL=N' DECLARE CUR_ITRNLOTT CURSOR FAST_FORWARD READ_ONLY FOR'        
                 + ' SELECT DISTINCT LOTT.lot'        
                 + ' FROM ' + @c_SourceDB + '.dbo.LOTATTRIBUTE LOTT WITH (NOLOCK)'   
                 + ' JOIN ITRN WITH (NOLOCK) ON ITRN.lot = LOTT.lot'      
                 + ' WHERE ITRN.ItrnKey =  @c_DocKey '         
                 + ' ORDER BY LOTT.Lot'        
        
   EXEC sp_executesql @c_ExecSQL,        
            N'@c_DocKey NVARCHAR(20)',         
              @c_DocKey       
         
   OPEN CUR_ITRNLOTT        
           
   FETCH NEXT FROM CUR_ITRNLOTT INTO @c_lot    
           
   WHILE @@FETCH_STATUS <> -1        
   BEGIN        
      SET @n_Continue = 1        
         
        EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'LOTATTRIBUTE', 'lot', @c_lot, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug           
    
         IF @b_Success <> 1 AND @c_errmsg <> ''      
         BEGIN      
           SET @n_continue=3      
           GOTO QUIT      
         END      
      
   FETCH NEXT FROM CUR_ITRNLOTT INTO @c_lot     
   END        
        
   CLOSE CUR_ITRNLOTT        
   DEALLOCATE CUR_ITRNLOTT        
END       
    
    
      
QUIT:      
      
IF @n_continue=3  -- Error Occured - Process And Return      
   BEGIN      
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