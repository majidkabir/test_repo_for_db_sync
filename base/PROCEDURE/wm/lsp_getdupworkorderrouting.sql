SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: lsp_GetDupWorkOrderRouting                              */
/* Creation Date: 03-Sep-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWMS-1124 - SP for Duplicate functionality in Work Order   */
/*        : Routing                                                     */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 28-Dec-2020 SWT01    1.0   Adding Begin Try/Catch                    */
/* 15-Jan-2021 Wan01    1.1   Execute Login if @c_UserName<>SUSER_SNAME()*/
/************************************************************************/
CREATE PROC [WM].[lsp_GetDupWorkOrderRouting]
           @c_MasterWorkOrder NVARCHAR(50)
         , @c_WorkOrderName   NVARCHAR(50)
         , @c_TableName       NVARCHAR(50)
         , @c_UserName        NVARCHAR(128)  = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt    INT
         , @n_Continue     INT 
         , @b_Success      INT
         , @n_err          INT
         , @c_errmsg       NVARCHAR(255)

         , @c_SQL          NVARCHAR(4000) = ''
         , @c_SQLColumns   NVARCHAR(4000) = ''
         , @c_SQLParms     NVARCHAR(4000) = ''

         , @c_KeyColValue  NVARCHAR(10)   = ''
         , @c_RefKeyValue  NVARCHAR(50)   = ''
         , @c_GenKeyColumn NVARCHAR(50)   = ''

         , @c_StepNumber   NVARCHAR(10)   = ''

         , @n_TmpRowID     INT            = 0
         , @n_RowID        INT            = 0

         , @CUR_GENKEY     CURSOR
         , @CUR_REFKEY     CURSOR
         , @CUR_REF        CURSOR

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_GenKeyColumn = CASE WHEN @c_TableName = 'WorkOrderSteps' 
                              THEN 'StepNumber'
                              WHEN @c_TableName = 'WorkOrderInputs' 
                              THEN 'WkOrdInputsKey'
                              WHEN @c_TableName = 'WorkOrderOutputs' 
                              THEN 'WkOrdOutputsKey'
                              WHEN @c_TableName = 'WorkOrderPackets'
                              THEN 'WkOrdPacketsKey'
                              ELSE ''
                              END

   CREATE TABLE #TMP_WOM ( TmpRowid  INT NOT NULL IDENTITY(1,1) PRIMARY KEY )   

   SET @c_SQLColumns = ISNULL(CONVERT(VARCHAR(4000),
                     (  SELECT c.COLUMN_NAME + ' ' 
                             + c.DATA_TYPE 
                             + CASE WHEN DATA_TYPE = 'NVARCHAR' THEN '(' + CONVERT(NVARCHAR(4),CHARACTER_MAXIMUM_LENGTH)+ ')' 
                                                                ELSE '' END + ','
                        FROM INFORMATION_SCHEMA.COLUMNS c WITH (NOLOCK)
                        WHERE c.TABLE_NAME = @c_TableName --'WORKORDERROUTING'
                        AND c.COLUMN_NAME NOT IN ('AddWho', 'AddDate','EditWho','EditDate','TrafficCop','ArchiveCop')
                        ORDER BY c.ORDINAL_POSITION
                        FOR XML PATH(''), TYPE))
                     ,'')

   IF @c_SQLColumns <> ''
   BEGIN
      SET @c_SQLColumns = LEFT(@c_SQLColumns, LEN(@c_SQLColumns)-1)
   END

   SET @c_SQL = N'ALTER TABLE #TMP_WOM ADD ' + @c_SQLColumns

   EXECUTE ( @c_SQL )

   SET @c_SQLColumns = ''
 
   SET @c_SQLColumns = ISNULL(CONVERT(VARCHAR(4000),(SELECT c.Name + ','
   FROM tempdb.sys.columns c (NOLOCK)
   WHERE c.object_id = object_id('tempdb..#TMP_WOM') 
   AND c.Name <> 'TmpRowid'
   ORDER BY c.Column_id
   FOR XML PATH(''), TYPE)),'')

   IF @c_SQLColumns <> ''
   BEGIN
      SET @c_SQLColumns = LEFT(@c_SQLColumns, LEN(@c_SQLColumns)-1)
   END

   IF SUSER_SNAME() <> @c_UserName       --(Wan01) - START
   BEGIN
      SET @n_Err = 0 
      EXEC [WM].[lsp_SetUser] 
               @c_UserName = @c_UserName  OUTPUT
            ,  @n_Err      = @n_Err       OUTPUT
            ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
                
      EXECUTE AS LOGIN = @c_UserName

      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
   END                                   --(Wan01) - END
   
   BEGIN TRY -- SWT01 - Begin Outer Begin Try
   
      SET @c_SQL = N'INSERT INTO #TMP_WOM ('
                 + ' ' + @c_SQLColumns  + ')'            
                 + 'SELECT'
                 + ' ' + @c_SQLColumns
                 + ' FROM dbo.' + @c_TableName + ' WITH (NOLOCK)'
                 + ' WHERE MasterWorkOrder = @c_MasterWorkOrder'
                 + ' AND WorkOrderName = @c_WorkOrderName'
                 + CASE WHEN @c_GenKeyColumn = '' THEN '' ELSE ' ORDER BY ' + @c_GenKeyColumn END

      SET @c_SQLParms=N'@c_MasterWorkOrder   NVARCHAR(50)'
                     +',@c_WorkOrderName     NVARCHAR(50)'  


      EXEC sp_ExecuteSQL @c_SQL  
                        ,@c_SQLParms
                        ,@c_MasterWorkOrder
                        ,@c_WorkOrderName

      IF @c_GenKeyColumn <> ''
      BEGIN
         SET @CUR_GENKEY = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT TmpRowID      
         FROM #TMP_WOM
         ORDER BY TmpRowID

         OPEN @CUR_GENKEY

         FETCH NEXT FROM @CUR_GENKEY INTO @n_TmpRowID
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @c_KeyColValue = ''

            IF @c_TableName = 'WORKORDERSTEPS'
            BEGIN
               SET @c_KeyColValue = RIGHT('00000' + CONVERT(VARCHAR(5), @n_TmpRowID),5)
            END
            ELSE IF @c_TableName IN ( 'WORKORDERINPUTS', 'WORKORDEROUTPUTS', 'WORKORDERPACKETS'  )
            BEGIN
               BEGIN TRY
                  EXECUTE nspg_GetKey
                        @c_GenKeyColumn 
                     ,  10 
                     ,  @c_KeyColValue OUTPUT 
                     ,  @b_Success     OUTPUT 
                     ,  @n_Err         OUTPUT 
                     ,  @c_ErrMsg      OUTPUT
               END TRY

               BEGIN CATCH
                  SET @n_Continue = 3
                  GOTO EXIT_SP
               END CATCH  
            END

            SET @c_SQL = N'UPDATE #TMP_WOM'
                       + ' SET ' + @c_GenKeyColumn + ' = @c_KeyColValue'            
                       + ' WHERE TmpRowID = @n_TmpRowID'

            SET @c_SQLParms=N'@n_TmpRowID    INT'
                           +',@c_KeyColValue NVARCHAR(10)'  

            EXEC sp_ExecuteSQL @c_SQL  
                              ,@c_SQLParms
                              ,@n_TmpRowID
                              ,@c_KeyColValue

            FETCH NEXT FROM @CUR_GENKEY INTO @n_TmpRowID
         END
         CLOSE @CUR_GENKEY
         DEALLOCATE @CUR_GENKEY 
      END

      IF @c_TableName IN ('WORKORDERINPUTS', 'WORKORDEROUTPUTS')
      BEGIN
         SET @CUR_REFKEY = CURSOR FAST_FORWARD READ_ONLY FOR  
         SELECT TmpRowID
               ,StepNumber
         FROM #TMP_WOM

         OPEN @CUR_REFKEY

         FETCH NEXT FROM @CUR_REFKEY INTO @n_TmpRowID
                                       ,  @c_StepNumber
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SELECT @n_RowID = ISNULL(MAX(CASE WHEN t.StepNumber = @c_StepNumber THEN t.RowID ELSE 0 END),0)
            FROM (
                     SELECT RowID = ROW_NUMBER() OVER (ORDER BY StepNumber)
                           ,  StepNumber
                        FROM WORKORDERSTEPS WITH (NOLOCK)
                     WHERE MasterWorkOrder = @c_MasterWorkOrder 
                     AND WorkOrderName = @c_WorkOrderName 
                  ) t
    
            IF @n_RowID > 0 
            BEGIN
               SET @c_RefKeyValue = RIGHT('00000' + CONVERT(VARCHAR(5), @n_RowID),5)

               UPDATE #TMP_WOM
                  SET StepNumber = @c_RefKeyValue
               WHERE TmpRowID = @n_TmpRowID
            END

            FETCH NEXT FROM @CUR_REFKEY INTO @n_TmpRowID
                                             , @c_StepNumber
         END
         CLOSE @CUR_REFKEY
         DEALLOCATE @CUR_REFKEY 
      END
   
   END TRY  
  
   BEGIN CATCH 
      SET @n_Continue = 3                       --(Wan01)   
      GOTO EXIT_SP  
   END CATCH -- (SWT01) - End Big Outer Begin try.. end Try Begin Catch.. End Catch
EXIT_SP:

   IF @n_Continue = 3
   BEGIN
      TRUNCATE TABLE #TMP_WOM; 
   END
   
   SET @c_SQLColumns = REPLACE(@c_SQLColumns, 'WorkOrderName', 'WorkOrderName = ''''')

   SET @c_SQL = N'SELECT'
              + ' ' + @c_SQLColumns
              + ' FROM #TMP_WOM'

   EXEC sp_ExecuteSQL @c_SQL  

   DROP TABLE #TMP_WOM;

   REVERT
END -- procedure

GO