SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
/* Stored Proc: isp_ASN_GetFromArch                                     */        
/* Creation Date: 16-JAN-2018                                           */        
/* Copyright: LF Logistics                                              */        
/* Written by: Wan                                                      */        
/*                                                                      */        
/* Purpose: WMS-3534 - Retrieve Archived ASNTrade ReturnXDock Infor in  */        
/*        :  Respective Screen                                          */        
/*        :                                                             */        
/* Called By: w_asn_maintenance.ue_presearch Event                      */        
/*          :                                                           */        
/* PVCS Version: 1.4                                                    */        
/*                                                                      */        
/* Version: 7.0                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date        Author   Ver   Purposes                                  */        
/* 07-Feb-2018 Leong    1.1   Join Live DB STORER (L01).                */        
/*                            Move by ArchiveCop 9. Then reset to NULL. */        
/* 07-MAY-2019 Grick    1.2   INC0690965 - Cater for RowVer from        */         
/*                            ReceiptDetail (G01)                       */ 
/* 26-OCT-2021 Wan01    1.4   LFWM-3589 - CN-SCE-ApplySearch to Retrieve*/
/*                            Archived ASNTrade ReturnXDock             */ 
/*                            DevOps Combine Script                     */
/************************************************************************/        
CREATE PROC [dbo].[isp_ASN_GetFromArch]        
     @c_SQLCondition NVARCHAR(MAX)        
   , @b_Success      INT            OUTPUT        
   , @n_Err          INT            OUTPUT        
   , @c_ErrMsg       NVARCHAR(255)  OUTPUT        
   , @b_debug        INT = 0        
AS        
BEGIN        
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
        
   DECLARE        
           @n_StartTCnt          INT        
         , @n_Continue           INT        
         , @c_ReceiptKey         NVARCHAR(10)        
         , @c_ArchiveDB          NVARCHAR(30)        
         , @c_ASNFromArchive     NVARCHAR(10)        
         , @c_ASNCols            NVARCHAR(MAX)        
         , @c_ASNCols_DET        NVARCHAR(MAX) 
         , @c_ASNCols_DET_FORMAT NVARCHAR(MAX)        
         , @c_SQL                NVARCHAR(MAX)        
         , @c_SQL_HDR            NVARCHAR(MAX)        
         , @c_SQL_DET            NVARCHAR(MAX) 
        
         , @c_SQL_DEL            NVARCHAR(MAX)        
         , @c_SQLParms           NVARCHAR(MAX)        
         , @c_SQL_HDR_UPD        NVARCHAR(MAX)        
         , @c_SQL_DET_UPD        NVARCHAR(MAX)        

         , @c_ASNCols_INFO       NVARCHAR(MAX)  = ''              --(Wan01)        
         , @c_SQL_HDR_INFO       NVARCHAR(MAX)  = ''              --(Wan01) 
         , @c_SQL_HDR_INFO_UPD   NVARCHAR(MAX)  = ''              --(Wan01) 
         
   SET @n_StartTCnt = @@TRANCOUNT        
   SET @n_Continue = 1        
   SET @n_err      = 0        
   SET @c_errmsg   = ''        
        
   SET @c_ArchiveDB = ''        
   SELECT @c_ArchiveDB = ISNULL(RTRIM(NSQLValue),'') FROM NSQLCONFIG WITH (NOLOCK)        
   WHERE ConfigKey='ArchiveDBName'        
        
   SET @c_ASNFromArchive = ''        
   SELECT @c_ASNFromArchive = ISNULL(NSQLValue,'')        
   FROM nSqlConfig (nolock)        
   WHERE ConfigKey = 'ASNFromArchive'        
        
   IF @c_ArchiveDB = '' OR @c_ASNFromArchive <> '1' OR ISNULL(@c_SQLCondition,'') = ''        
   BEGIN        
      GOTO QUIT_SP        
   END        
    
   SET @c_ASNCols = STUFF((SELECT ', ' + COLUMN_NAME        
                           FROM INFORMATION_SCHEMA.COLUMNS WITH (NOLOCK)        
                           WHERE TABLE_NAME = 'RECEIPT'        
                           FOR XML PATH('')        
                        ),1,1,'')        
        
   IF ISNULL(@c_ASNCols,'') = ''        
   BEGIN        
      GOTO QUIT_SP        
   END        
        
   SET @c_ASNCols_DET = STUFF((SELECT ', ' + COLUMN_NAME        
                              FROM INFORMATION_SCHEMA.COLUMNS WITH (NOLOCK)        
                              WHERE TABLE_NAME = 'RECEIPTDETAIL' AND DATA_TYPE <> 'TIMESTAMP' --G01         
                              FOR XML PATH('')        
                               ),1,1,'')        
        
   SET @c_ASNCols_DET_FORMAT = ISNULL(RTRIM(LTRIM(@c_ASNCols_DET)),'') -- (L01)        
        
   SET @c_ASNCols_DET_FORMAT = REPLACE(@c_ASNCols_DET_FORMAT, 'ArchiveCop', '9')        
   SET @c_ASNCols_DET_FORMAT = REPLACE(@c_ASNCols_DET_FORMAT, 'Lottable01', 'ISNULL(RTRIM(Lottable01),'''')')        
   SET @c_ASNCols_DET_FORMAT = REPLACE(@c_ASNCols_DET_FORMAT, 'Lottable02', 'ISNULL(RTRIM(Lottable02),'''')')        
   SET @c_ASNCols_DET_FORMAT = REPLACE(@c_ASNCols_DET_FORMAT, 'Lottable03', 'ISNULL(RTRIM(Lottable03),'''')')        
        
   SET @c_ASNCols_DET_FORMAT = REPLACE(@c_ASNCols_DET_FORMAT, 'Lottable06', 'ISNULL(RTRIM(Lottable06),'''')')        
   SET @c_ASNCols_DET_FORMAT = REPLACE(@c_ASNCols_DET_FORMAT, 'Lottable07', 'ISNULL(RTRIM(Lottable07),'''')')        
   SET @c_ASNCols_DET_FORMAT = REPLACE(@c_ASNCols_DET_FORMAT, 'Lottable08', 'ISNULL(RTRIM(Lottable08),'''')')        
   SET @c_ASNCols_DET_FORMAT = REPLACE(@c_ASNCols_DET_FORMAT, 'Lottable09', 'ISNULL(RTRIM(Lottable09),'''')')        
   SET @c_ASNCols_DET_FORMAT = REPLACE(@c_ASNCols_DET_FORMAT, 'Lottable10', 'ISNULL(RTRIM(Lottable10),'''')')        
   SET @c_ASNCols_DET_FORMAT = REPLACE(@c_ASNCols_DET_FORMAT, 'Lottable11', 'ISNULL(RTRIM(Lottable11),'''')')        
   SET @c_ASNCols_DET_FORMAT = REPLACE(@c_ASNCols_DET_FORMAT, 'Lottable12', 'ISNULL(RTRIM(Lottable12),'''')')        
    
   SET @c_ASNCols_INFO= STUFF((  SELECT ', ' + NAME                                 --(Wan01)        
                                 FROM sys.columns WITH (NOLOCK)        
                                 WHERE object_id = OBJECT_id('RECEIPTINFO') 
                                 AND is_identity = 0 
                                 FOR XML PATH('')        
                               ),1,1,'')   
                                       
   SET @c_SQL_HDR= N'INSERT INTO RECEIPT (' + @c_ASNCols + ')'        
                 + ' SELECT ' + REPLACE(@c_ASNCols, 'ArchiveCop', '9')        
                 + ' FROM ' + @c_ArchiveDB + '.dbo.RECEIPT WITH (NOLOCK)'        
                 + ' WHERE ReceiptKey = @c_ReceiptKey'        
        
   SET @c_SQL_DET= N'INSERT INTO RECEIPTDETAIL (' + @c_ASNCols_DET + ')'        
                 + ' SELECT ' + @c_ASNCols_DET_FORMAT        
                 + ' FROM ' + @c_ArchiveDB + '.dbo.RECEIPTDETAIL WITH (NOLOCK)'        
                 + ' WHERE ReceiptKey = @c_ReceiptKey'        
 
   SET @c_SQL_HDR_INFO = N'INSERT INTO RECEIPTINFO (' + @c_ASNCols_INFO + ')'       --(Wan01)        
                 + ' SELECT ' + @c_ASNCols_INFO        
                 + ' FROM ' + @c_ArchiveDB + '.dbo.RECEIPTINFO WITH (NOLOCK)'        
                 + ' WHERE ReceiptKey = @c_ReceiptKey'  
                        
   SET @c_SQL_HDR_UPD = N'UPDATE dbo.RECEIPT WITH (ROWLOCK)'        
                      + ' SET ArchiveCop = NULL'        
                      + ' WHERE ReceiptKey = @c_ReceiptKey'        
        
   SET @c_SQL_DET_UPD = N'UPDATE dbo.RECEIPTDETAIL WITH (ROWLOCK)'        
                      + ' SET ArchiveCop = NULL'        
                      + ' WHERE ReceiptKey = @c_ReceiptKey'        

   SET @c_SQL_HDR_INFO_UPD = N'UPDATE dbo.RECEIPTINFO WITH (ROWLOCK)'               --(Wan01)        
                           + ' SET ArchiveCop = NULL'        
                           + ' WHERE ReceiptKey = @c_ReceiptKey'
                                    
   IF CHARINDEX('RECEIPT.ExternReceiptKey', ISNULL(RTRIM(@c_SQLCondition),'')) > 0        
      OR CHARINDEX('RECEIPT.ReceiptKey', ISNULL(RTRIM(@c_SQLCondition),'')) > 0 -- To cater multiple ReceiptKey or ExternReceiptKey        
   BEGIN        
      SET @c_SQL  = N'DECLARE CUR_ASN CURSOR FAST_FORWARD READ_ONLY FOR'        
                  + ' SELECT TOP 50 RECEIPT.ReceiptKey'        
                  + ' FROM ' + @c_ArchiveDB + '.dbo.RECEIPT WITH (NOLOCK)'        
                  + ' JOIN ' + @c_ArchiveDB + '.dbo.RECEIPTDETAIL WITH (NOLOCK)'        
                  + ' ON (RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey)'        
                  + ' JOIN dbo.STORER WITH (NOLOCK) ON (RECEIPT.Storerkey = STORER.Storerkey)' -- (L01)
                  + IIF(CHARINDEX('RECEIPTINFO.', ISNULL(RTRIM(@c_SQLCondition),'')) = 0, '',
                    ' LEFT OUTER JOIN ' + @c_ArchiveDB + '.dbo.RECEIPTINFO WITH (NOLOCK)'
                  +                   ' ON RECEIPTINFO.ReceiptKey = RECEIPT.ReceiptKey')      -- (Wan01)        
                  + ' ' + @c_SQLCondition        
                  + ' GROUP BY RECEIPT.ReceiptKey, RECEIPT.EditDate'        
                  + ' ORDER BY RECEIPT.EditDate DESC '        
   END        
   ELSE        
   BEGIN              
      SET @c_SQL  = N'DECLARE CUR_ASN CURSOR FAST_FORWARD READ_ONLY FOR'        
                  + ' SELECT TOP 1 RECEIPT.ReceiptKey'        
                  + ' FROM ' + @c_ArchiveDB + '.dbo.RECEIPT WITH (NOLOCK)'        
                  + ' JOIN ' + @c_ArchiveDB + '.dbo.RECEIPTDETAIL WITH (NOLOCK)'        
                  + ' ON (RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey)'        
                  + ' JOIN dbo.STORER WITH (NOLOCK) ON (RECEIPT.Storerkey = STORER.Storerkey)' -- (L01)        
                  + IIF(CHARINDEX('RECEIPTINFO.', ISNULL(RTRIM(@c_SQLCondition),'')) = 0, '',
                    ' LEFT OUTER JOIN ' + @c_ArchiveDB + '.dbo.RECEIPTINFO WITH (NOLOCK)'
                  +                   ' ON RECEIPTINFO.ReceiptKey = RECEIPT.ReceiptKey')        -- (Wan01)
                  + ' ' + @c_SQLCondition        
                  + ' GROUP BY RECEIPT.ReceiptKey, RECEIPT.EditDate'        
                  + ' ORDER BY RECEIPT.EditDate DESC '        
   END        
        
   WHILE @@TRANCOUNT > 0        
   BEGIN        
      COMMIT TRAN        
   END        
        
   IF @b_debug = 1        
   BEGIN        
      SELECT @c_SQL '@c_SQL'        
   END        
        
   EXEC sp_ExecuteSQL @c_SQL        
        
   OPEN CUR_ASN        
   FETCH NEXT FROM CUR_ASN INTO @c_ReceiptKey        
   WHILE @@FETCH_STATUS <> -1        
   BEGIN        
      IF @b_debug = 1        
      BEGIN        
         SELECT @c_ReceiptKey '@c_ReceiptKey'        
      END    
          
      SET @n_Continue = 1                                                           --(Wan01)                                                      
         
      BEGIN TRAN        
        
      EXEC sp_executesql @c_SQL_HDR        
         , N'@c_ReceiptKey NVARCHAR(10)'        
         , @c_ReceiptKey 
         
       IF @@ERROR <> 0                                                              --(Wan01)        
       BEGIN        
          SET @n_Continue = 3        
          GOTO NEXT_ASN        
       END                  
        
      EXEC sp_executesql @c_SQL_HDR_UPD        
         , N'@c_ReceiptKey NVARCHAR(10)'        
         , @c_ReceiptKey    
    
       IF @@ERROR <> 0                                                              --(Wan01)    
       BEGIN        
          SET @n_Continue = 3        
          GOTO NEXT_ASN        
       END        
        
      EXEC sp_executesql @c_SQL_DET        
         , N'@c_ReceiptKey NVARCHAR(10)'        
         , @c_ReceiptKey 

      IF @@ERROR <> 0                                                               --(Wan01)  
      BEGIN        
         SET @n_Continue = 3        
         GOTO NEXT_ASN        
      END                 
        
      EXEC sp_executesql @c_SQL_DET_UPD        
         , N'@c_ReceiptKey NVARCHAR(10)'        
         , @c_ReceiptKey 
    
      IF @@ERROR <> 0                                                               --(Wan01)
      BEGIN        
         SET @n_Continue = 3        
         GOTO NEXT_ASN        
      END          
                
      EXEC sp_executesql @c_SQL_HDR_INFO                                            --(Wan01) - START      
         , N'@c_ReceiptKey NVARCHAR(10)'        
         , @c_ReceiptKey 
      
      IF @@ERROR <> 0        
      BEGIN        
         SET @n_Continue = 3        
         GOTO NEXT_ASN        
      END           
         
      EXEC sp_executesql @c_SQL_HDR_INFO_UPD                                                
         , N'@c_ReceiptKey NVARCHAR(10)'        
         , @c_ReceiptKey   
                 
      IF @@ERROR <> 0        
      BEGIN        
         SET @n_Continue = 3        
         GOTO NEXT_ASN        
      END                                                                           --(Wan01) - END
        
      SET @c_SQL_DEL= N'IF EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)        
                                    WHERE ReceiptKey = @c_ReceiptKey )'        
                     + ' BEGIN'        
                     + '   DELETE FROM ' + @c_ArchiveDB + '.dbo.RECEIPTDETAIL WITH (ROWLOCK)'        
                     + '   WHERE ReceiptKey = @c_ReceiptKey'        
                     + ' END'        
        
      EXEC sp_executesql @c_SQL_DEL        
         , N'@c_ReceiptKey NVARCHAR(10)'        
         , @c_ReceiptKey        
        
      IF @@ERROR <> 0        
      BEGIN        
         SET @n_Continue = 3        
         GOTO NEXT_ASN        
      END        
        
      SET @c_SQL_DEL= N'IF EXISTS ( SELECT 1 FROM dbo.RECEIPT WITH (NOLOCK)        
                                    WHERE ReceiptKey = @c_ReceiptKey )'        
                     + ' BEGIN'        
                     + '   DELETE FROM ' + @c_ArchiveDB + '.dbo.RECEIPT WITH (ROWLOCK)'        
                     + '   WHERE ReceiptKey = @c_ReceiptKey'        
                     + ' END'        
        
      EXEC sp_executesql @c_SQL_DEL        
         , N'@c_ReceiptKey NVARCHAR(10)'        
         , @c_ReceiptKey  
         
      --(Wan01) - START 
      IF @@ERROR <> 0        
      BEGIN        
         SET @n_Continue = 3        
         GOTO NEXT_ASN        
      END 
      
      SET @c_SQL_DEL= N'IF EXISTS ( SELECT 1 FROM dbo.RECEIPTINFO WITH (NOLOCK)        
                                    WHERE ReceiptKey = @c_ReceiptKey )'        
                     + ' BEGIN'        
                     + '   DELETE FROM ' + @c_ArchiveDB + '.dbo.RECEIPTINFO WITH (ROWLOCK)'        
                     + '   WHERE ReceiptKey = @c_ReceiptKey'        
                     + ' END'        
        
      EXEC sp_executesql @c_SQL_DEL        
         , N'@c_ReceiptKey NVARCHAR(10)'        
         , @c_ReceiptKey            
      
      IF @@ERROR <> 0        
      BEGIN        
         SET @n_Continue = 3        
         GOTO NEXT_ASN        
      END 
      --(Wan01) - END
      
      WHILE @@TRANCOUNT > 0        
      BEGIN        
         COMMIT TRAN        
      END        
        
      NEXT_ASN:        
      IF @n_Continue = 3        
      BEGIN  
         IF @@TRANCOUNT > 0                                                         --(Wan01)       
            ROLLBACK TRAN        
      END        
        
      FETCH NEXT FROM CUR_ASN INTO @c_ReceiptKey        
   END        
   CLOSE CUR_ASN        
   DEALLOCATE CUR_ASN        
QUIT_SP:        
        
   IF CURSOR_STATUS( 'GLOBAL', 'CUR_ASN') IN (0 , 1)        
   BEGIN        
      CLOSE CUR_ASN        
      DEALLOCATE CUR_ASN        
   END        
        
   IF @n_Continue = 3  -- Error Occured - Process And Return        
   BEGIN        
      SET @b_Success = 0        
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt        
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
        
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ASN_GetFromArch'        
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012        
   END        
   ELSE        
   BEGIN        
      SET @b_Success = 1        
      WHILE @@TRANCOUNT > @n_StartTCnt        
      BEGIN               
         COMMIT TRAN        
      END        
   END        
        
   WHILE @@TRANCOUNT < @n_StartTCnt        
   BEGIN        
      BEGIN TRAN        
   END        
END -- procedure 

GO