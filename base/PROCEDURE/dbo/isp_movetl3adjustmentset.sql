SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store Procedure: isp_MoveTL3AdjustmentSet                            */      
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
      
CREATE PROCEDURE [dbo].[isp_MoveTL3AdjustmentSet]      
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
      , @c_mbolkey         NVARCHAR(50)      
      , @c_loadkey         NVARCHAR(20)      
      , @c_Pickslipno      NVARCHAR(20)      
      , @c_ContainerKey    NVARCHAR(20)      
      , @c_palletkey       NVARCHAR(30)      
      , @c_labelno         NVARCHAR(20)      
      , @n_StartTCnt       INT       
      , @c_ExecSQL         NVARCHAR(MAX)         
      , @c_ADJKey          NVARCHAR(20)        
      , @c_ADJLineNumber   NVARCHAR(20)    
      , @c_sourcekey       NVARCHAR(60)  
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

SET @c_chkstorerkey  = ''   --CS01

IF @b_Debug = 1
BEGIN
   SELECT 'ADJUSTMENT' , @c_TableName '@c_TableName', @c_DocKey '@c_dockey'
END 

--CS01 START
SET @c_SQL = N'SELECT  TOP 1 @c_chkstorerkey = ADJ.Storerkey'  + CHAR(13) +        
                   'FROM ' +        
                   QUOTENAME(@c_SourceDB, '[') + '.dbo.ADJUSTMENT ADJ (NOLOCK) ' + CHAR(13) +        
                   'WHERE ADJ.AdjustmentKey =  @c_DocKey  ' 
       
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
             SELECT TOP 1 @c_chkstorerkey = ADJ.Storerkey
             FROM ADJUSTMENT ADJ WITH (NOLOCK)
             WHERE ADJ.AdjustmentKey =  @c_DocKey 
        END
 IF ISNULL(@c_chkstorerkey,'') <> ''       
 BEGIN   
       IF @c_key3 <> @c_chkstorerkey
       BEGIN
             SET @n_continue=3   
             SET @n_err = 700003        
             SELECT @c_errmsg = 'Storerkey not match (isp_MoveTL3AdjustmentSet)'
             GOTO QUIT  
       END 
END
ELSE      
BEGIN      
   SET @n_continue=1       
   --SET @n_err = 700003              
   --SELECT @c_errmsg = 'NO Data found (isp_MoveTL3AdjustmentSet)'      
   GOTO QUIT        
END       
--CS01 END       
    
    
MOVE_ADJUSTMENT:     
--SELECT @c_DocKey '@c_DocKey'  
    
  IF @b_Debug = '1'
  BEGIN

     SELECT 'MOVE ADJUSTMENT',@c_DocKey '@c_DocKey'
    
  END
    
   EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'ADJUSTMENT', 'AdjustmentKey', @c_DocKey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
        
   IF @b_Success <> 1 AND @c_errmsg <> ''      
   BEGIN      
     SET @n_continue=3      
     GOTO QUIT      
   END          
    
MOVE_AdjustmentDetail:       
BEGIN          
          
     SET @c_StorerKey = ''      
     SET @c_ExecSQL = ''      
      
     SET @c_ExecSQL=N' DECLARE CUR_ADJDET CURSOR FAST_FORWARD READ_ONLY FOR'        
                 + ' SELECT DISTINCT AD.AdjustmentKey,AD.AdjustmentLineNumber'        
                 + ' FROM ' + @c_SourceDB + '.dbo.adjustmentdetail AD WITH (NOLOCK)'        
                 + ' WHERE AD.AdjustmentKey =  @c_DocKey '         
                 + ' ORDER BY AD.AdjustmentKey,AD.AdjustmentLineNumber'        
        
   EXEC sp_executesql @c_ExecSQL,        
            N'@c_DocKey NVARCHAR(20)',         
              @c_DocKey       
         
   OPEN CUR_ADJDET        
           
   FETCH NEXT FROM CUR_ADJDET INTO  @c_ADJKey ,@c_ADJLineNumber
           
   WHILE @@FETCH_STATUS <> -1        
   BEGIN        
      SET @n_Continue = 1        
         
     IF EXISTS (SELECT 1 FROM dbo.ADJUSTMENT WITH (NOLOCK) WHERE AdjustmentKey = @c_ADJKey)      
     BEGIN      
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'ADJUSTMENTDETAIL', 'AdjustmentKey', @c_ADJKey,'AdjustmentLineNumber',@c_ADJLineNumber ,'','','','',       
                 @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
     END    
    
         IF @b_Success <> 1 AND @c_errmsg <> ''      
         BEGIN      
           SET @n_continue=3      
           GOTO QUIT      
         END      
      
   FETCH NEXT FROM CUR_ADJDET INTO @c_ADJKey ,@c_ADJLineNumber
   END        
        
   CLOSE CUR_ADJDET        
   DEALLOCATE CUR_ADJDET        
END   
    
MOVE_ITRN:     
--SELECT @c_DocKey '@c_DocKey'  
      
  IF @b_Debug = '1'
  BEGIN

     SELECT 'MOVE ITRN',@c_DocKey '@c_DocKey'
    
  END
   SET @c_ExecSQL = ''      
      
     SET @c_ExecSQL=N' DECLARE CUR_ADJITRNTBL CURSOR FAST_FORWARD READ_ONLY FOR'        
                 + ' SELECT DISTINCT AD.AdjustmentKey,AD.AdjustmentLineNumber'        
                 + ' FROM dbo.adjustmentdetail AD WITH (NOLOCK)'        
                 + ' WHERE AD.AdjustmentKey =  @c_DocKey '         
                 + ' ORDER BY AD.AdjustmentKey,AD.AdjustmentLineNumber'        
        
   EXEC sp_executesql @c_ExecSQL,        
            N'@c_DocKey NVARCHAR(20)',         
              @c_DocKey       
         
   OPEN CUR_ADJITRNTBL        
           
   FETCH NEXT FROM CUR_ADJITRNTBL INTO  @c_ADJKey ,@c_ADJLineNumber
           
   WHILE @@FETCH_STATUS <> -1        
   BEGIN        
      SET @n_Continue = 1  
      SET @c_sourcekey = ''

      SET @c_sourcekey = (@c_ADJKey+@c_ADJLineNumber)

      EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'ITRN', 'sourcekey', @c_sourcekey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
        
               IF @b_Success <> 1 AND @c_errmsg <> ''      
               BEGIN      
                 SET @n_continue=3      
                 GOTO QUIT      
               END   

   FETCH NEXT FROM CUR_ADJITRNTBL INTO @c_ADJKey ,@c_ADJLineNumber
   END        
        
   CLOSE CUR_ADJITRNTBL        
   DEALLOCATE CUR_ADJITRNTBL   
   
    
MOVE_LOTATTRIBUTE:    
BEGIN          
          
     SET @c_StorerKey = ''      
     SET @c_ExecSQL = ''      
      
      SET @c_ExecSQL=N' DECLARE CUR_ADJLOTT CURSOR FAST_FORWARD READ_ONLY FOR'        
                 + ' SELECT DISTINCT AD.sku,AD.lot'        
                 + ' FROM dbo.adjustmentdetail AD WITH (NOLOCK)'   
                 + ' JOIN ' + @c_SourceDB + '.dbo.LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.sku = AD.SKU and LOTT.lot=AD.lot AND LOTT.Storerkey = AD.Storerkey'      
                 + ' WHERE AD.AdjustmentKey =  @c_DocKey '         
                 + ' ORDER BY AD.sku,AD.lot' 
        
   EXEC sp_executesql @c_ExecSQL,        
            N'@c_DocKey NVARCHAR(20)',         
              @c_DocKey       
         
   OPEN CUR_ADJLOTT        
           
   FETCH NEXT FROM CUR_ADJLOTT INTO @c_sku,@c_lot    
           
   WHILE @@FETCH_STATUS <> -1        
   BEGIN        
      SET @n_Continue = 1        
         
        
        EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'LOTATTRIBUTE', 'sku', @c_sku,'lot',@c_lot ,'','','','',       
                 @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
         IF @b_Success <> 1 AND @c_errmsg <> ''      
         BEGIN      
           SET @n_continue=3      
           GOTO QUIT      
         END      
      
   FETCH NEXT FROM CUR_ADJLOTT INTO @c_sku,@c_lot     
   END        
        
   CLOSE CUR_ADJLOTT        
   DEALLOCATE CUR_ADJLOTT        
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