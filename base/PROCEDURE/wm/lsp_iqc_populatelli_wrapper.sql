SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_IQC_PopulateLLI_Wrapper                         */                                                                                  
/* Creation Date: 2023-03-28                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-3966 -[CN] SCE populate all for InventoryIQC population*/
/*                                                                      */
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.0                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date         Author   Ver.  Purposes                                 */
/* 2023-03-28   Wan      1.0   Created & DevOps Combine Script          */
/************************************************************************/                                                                                  
CREATE   PROC [WM].[lsp_IQC_PopulateLLI_Wrapper]                                                                                                                     
   @c_QC_Key               NVARCHAR(10)         
,  @c_LotxLocxID           NVARCHAR(MAX)    --Eacg set of Lot,Loc,ID seperated by '|'. Eg 0000000001,STAGE,ID1|0000000002,STAGE,ID2
,  @b_Success              INT            = 1  OUTPUT  
,  @n_Err                  INT            = 0  OUTPUT                                                                                                             
,  @c_ErrMsg               NVARCHAR(255)  = '' OUTPUT
,  @c_UserName             NVARCHAR(128)  = ''
,  @n_ErrGroupKey          INT            = 0  OUTPUT
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt                  INT = @@TRANCOUNT  
         ,  @n_Continue                   INT = 1

         ,  @n_RowID                      INT = 0
         ,  @n_Qty                        INT = 0

         ,  @c_FromFacility   NVARCHAR(5)    = ''
         ,  @c_ToFacility     NVARCHAR(5)    = ''
         ,  @c_Storerkey      NVARCHAR(15)   = '' 
         ,  @c_Type           NVARCHAR(12)   = ''
         ,  @c_QCLineNo       NVARCHAR(5)    = ''
         ,  @c_Sku            NVARCHAR(20)   = ''
         ,  @c_Packkey        NVARCHAR(10)   = ''
         ,  @c_UOM3           NVARCHAR(10)   = ''
         ,  @c_FromLot        NVARCHAR(10)   = ''
         ,  @c_FromLoc        NVARCHAR(10)   = ''
         ,  @c_FromID         NVARCHAR(18)   = ''
         
         ,  @c_TableName      NVARCHAR(50)   = 'InventoryQCDetail'
         ,  @c_SourceType     NVARCHAR(50)   = 'lsp_IQC_PopulateLLI_Wrapper' 
         ,  @c_Refkey1        NVARCHAR(20)   = ''
         ,  @c_Refkey2        NVARCHAR(20)   = ''
         ,  @c_Refkey3        NVARCHAR(20)   = ''
         ,  @c_WriteType      NVARCHAR(50)   = ''
         ,  @n_LogWarningNo   INT            = 0

         ,  @CUR_ERRLIST      CURSOR        
         
   DECLARE  @t_WMSErrorList   TABLE
         (  RowID             INT            IDENTITY(1,1)
         ,  TableName         NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  SourceType        NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  Refkey1           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey2           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey3           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  WriteType         NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  LogWarningNo      INT            NOT NULL DEFAULT(0)
         ,  ErrCode           INT            NOT NULL DEFAULT(0)
         ,  Errmsg            NVARCHAR(255)  NOT NULL DEFAULT('')
         )         

   SET @b_Success = 1
   SET @n_Err     = 0
   SET @c_ErrMsg  = ''
   
   SET @n_ErrGroupKey = 0
               
   SET @n_Err = 0 
   IF SUSER_SNAME() <> @c_UserName        --(Wan01) - START
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
    
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
                
      EXECUTE AS LOGIN = @c_UserName        
   END                                    

   BEGIN TRY  
      BEGIN TRAN                           
      /*-------------------------------------------------------*/
      /* BUILD TEMP TABLES & INSERT DATA - START               */
      /*-------------------------------------------------------*/
      IF OBJECT_ID('tempdb..#tLLI', 'U') IS NOT NULL
      BEGIN
         DROP TABLE #tLLI
      END

      CREATE TABLE #tLLI 
         (  RowID       INT            NOT NULL IDENTITY(1,1)    PRIMARY KEY
         ,  LotxLocxID  NVARCHAR(38)   NOT NULL DEFAULT('')
         ,  Lot         NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  Loc         NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  ID          NVARCHAR(18)   NOT NULL DEFAULT('')
         ,  CommaIdx1   INT            NOT NULL DEFAULT(0)
         ,  CommaIdx2   INT            NOT NULL DEFAULT(0)
         )
   
      INSERT INTO #tLLI (LotxLocxID, Lot, CommaIdx1)
      SELECT T.[Value]
            ,Lot = SUBSTRING(T.[Value],1,CHARINDEX(',',T.[Value],1) - 1) 
            ,CommaIdx1 = CHARINDEX(',',T.[Value],1)
      FROM string_split (@c_LotxLocxID, '|') T
      GROUP BY T.[Value]
      
      UPDATE #tLLI
          SET Loc = SUBSTRING(LotxLocxID
                            ,CommaIdx1+1
                            ,CHARINDEX(',', LotxLocxID, CommaIdx1+1) - 1 - CommaIdx1)  
            ,CommaIdx2 = CHARINDEX(',', LotxLocxID, CommaIdx1+1) 

      UPDATE #tLLI
          SET ID = SUBSTRING(LotxLocxID,CommaIdx2+1, LEN(LotxLocxID) - CommaIdx2) 
      /*-------------------------------------------------------*/
      /* BUILD TEMP TABLES & INSERT DATA - END                 */
      /*-------------------------------------------------------*/
   
      SET @c_FromFacility = ''
      SET @c_ToFacility = ''
      SET @c_Storerkey= ''
      SELECT @c_FromFacility  = iq.from_facility
            ,@c_ToFacility    = iq.to_facility
            ,@c_Storerkey     = iq.Storerkey
      FROM dbo.InventoryQC AS iq WITH (NOLOCK)
      WHERE iq.QC_Key = @c_QC_Key
      
      IF EXISTS ( SELECT 1 FROM #tLLI AS tl
                  LEFT OUTER JOIN dbo.LOC AS l WITH (NOLOCK) ON l.Loc = tl.Loc
                                                             AND l.Facility = @c_FromFacility
                  WHERE l.Loc IS NULL)
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 561351
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) + ': Populate Loc not belong to From Facility: ' + @c_FromFacility
                       + ' found. Populate Inventory Abort. (lsp_IQC_PopulateLLI_Wrapper) |' + @c_FromFacility
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
         VALUES (@c_TableName, @c_SourceType, @c_QC_Key, '', '', 'ERROR', 0, @n_Err, @c_ErrMsg)
      END
                 
      SET @c_QCLineNo = '00000'  
    
      SELECT TOP 1 @c_QCLineNo = iqd.QCLineNo
      FROM dbo.InventoryQCDetail AS iqd WITH (NOLOCK)
      WHERE iqd.QC_Key = @c_QC_Key
      ORDER BY iqd.QCLineNo DESC

      SET @n_RowID = 0                    
      WHILE 1 = 1
      BEGIN
         SET @c_Sku = ''
         SET @c_FromLot = ''
         SET @c_FromLoc = ''
         SET @c_FromID  = ''
         SET @n_Qty = 0
         SELECT Top 1
             @n_RowID  = tl.RowID
            ,@c_Sku    = ltlci.Sku
            ,@c_FromLot= ltlci.Lot
            ,@c_FromLoc= ltlci.Loc  
            ,@c_FromID = ltlci.ID 
            ,@n_Qty    = ltlci.Qty - ltlci.QtyAllocated - ltlci.QtyPicked
         FROM #tLLI AS tl
         JOIN dbo.LOTxLOCxID AS ltlci WITH (NOLOCK) ON  ltlci.Lot = tl.Lot 
                                                    AND ltlci.Loc = tl.Loc 
                                                    AND ltlci.Id = tl.ID
         WHERE tl.RowID > @n_RowID 
         AND ltlci.Qty - ltlci.QtyAllocated - ltlci.QtyPicked > 0 
         ORDER BY tl.RowID

         IF @@ROWCOUNT = 0 OR @c_Sku = ''
         BEGIN
            BREAK
         END
         
         SET @c_Packkey = ''
         SET @c_UOM3 = ''
  
         SELECT @c_Packkey = FS.Packkey
         FROM SKU  FS WITH (NOLOCK)
         WHERE FS.Storerkey = @c_Storerkey
         AND   FS.Sku = @c_Sku

         SELECT @c_UOM3 = FP.PackUOM3
         FROM PACK FP WITH (NOLOCK) 
         WHERE FP.Packkey = @c_Packkey

         SET @c_QCLineNo = RIGHT( '00000' + CONVERT(NVARCHAR(5), CONVERT(INT, @c_QCLineNo) + 1), 5 )
         INSERT INTO dbo.InventoryQCDetail
             (
                 QC_Key,
                 QCLineNo,
                 StorerKey,
                 SKU,
                 PackKey,
                 UOM,
                 OriginalQty,
                 Qty,
                 FromLoc,
                 FromLot,
                 FromID,
                 ToQty,
                 ToID,
                 ToLoc,
                 Reason,
                 Status,
                 UserDefine01,
                 UserDefine02,
                 UserDefine03,
                 UserDefine04,
                 UserDefine05,
                 UserDefine06,
                 UserDefine07,
                 UserDefine08,
                 UserDefine09,
                 UserDefine10,
                 FinalizeFlag,
                 Channel,
                 Channel_ID
             )
         VALUES
             (   @c_QC_Key,       
                 @c_QCLineNo,            
                 @c_Storerkey,         
                 @c_Sku,               
                 @c_Packkey,           
                 @c_UOM3,               
                 @n_Qty, 
                 0, 
                 @c_Fromloc, 
                 @c_Fromlot, 
                 @c_FromID,  
                 0,      
                 N'',    
                 N'',    
                 N'',    
                 N'0',   
                 N'',    
                 N'',    
                 N'',    
                 N'',    
                 N'',    
                 '1900-01-01', 
                 '1900-01-01', 
                 N'',       
                 N'',       
                 N'',       
                 N'N',      
                 N'',       
                 0          
             )

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            GOTO EXIT_SP
         END
      END
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg   = ERROR_MESSAGE() 
      
      INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
      VALUES (@c_TableName, @c_SourceType, @c_QC_Key, '', '', 'ERROR', 0, @n_Err, @c_Errmsg)
      GOTO EXIT_SP   
   END CATCH                              
EXIT_SP:
   IF (XACT_STATE()) = -1  
   BEGIN
      SET @n_Continue = 3
      ROLLBACK TRAN
   END  
    
   IF OBJECT_ID('tempdb..#tLLI', 'U') IS NOT NULL
   BEGIN
      DROP TABLE #tLLI
   END
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_IQC_PopulateLLI_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   
   SET @CUR_ERRLIST = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT   twl.TableName
         ,  twl.SourceType
         ,  twl.Refkey1
         ,  twl.Refkey2
         ,  twl.Refkey3
         ,  twl.WriteType
         ,  twl.LogWarningNo
         ,  twl.ErrCode
         ,  twl.Errmsg
   FROM @t_WMSErrorList AS twl
   ORDER BY twl.RowID

   OPEN @CUR_ERRLIST

   FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName
                                     , @c_SourceType
                                     , @c_Refkey1
                                     , @c_Refkey2
                                     , @c_Refkey3
                                     , @c_WriteType
                                     , @n_LogWarningNo
                                     , @n_Err
                                     , @c_Errmsg

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXEC [WM].[lsp_WriteError_List]
         @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
      ,  @c_TableName   = @c_TableName
      ,  @c_SourceType  = @c_SourceType
      ,  @c_Refkey1     = @c_Refkey1
      ,  @c_Refkey2     = @c_Refkey2
      ,  @c_Refkey3     = @c_Refkey3
      ,  @n_LogWarningNo= @n_LogWarningNo
      ,  @c_WriteType   = @c_WriteType
      ,  @n_err2        = @n_err
      ,  @c_errmsg2     = @c_errmsg
      ,  @b_Success     = @b_Success
      ,  @n_err         = @n_err
      ,  @c_errmsg      = @c_errmsg

      FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName
                                        , @c_SourceType
                                        , @c_Refkey1
                                        , @c_Refkey2
                                        , @c_Refkey3
                                        , @c_WriteType
                                        , @n_LogWarningNo
                                        , @n_Err
                                        , @c_Errmsg
   END
   CLOSE @CUR_ERRLIST
   DEALLOCATE @CUR_ERRLIST
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END  
         
   REVERT
END

GO