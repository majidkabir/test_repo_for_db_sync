SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_BuildTmpTableColFrTable                             */
/* Creation Date: 2021-08-11                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-2962 - Populate Order details -Populate SO Detail fail.*/
/*          Build Temp Table Column from Original Table                 */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-08-11  Wan      1.0   Created.                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_BuildTmpTableColFrTable]
      @c_TempTableName      NVARCHAR(50)
   ,  @c_OrginalTableName   NVARCHAR(50)               
   ,  @c_TableColumnNames   NVARCHAR(MAX)    OUTPUT
   ,  @c_ColumnNames        NVARCHAR(MAX)    OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_column_ordinal  INT    = 0
      ,  @c_ColumnName      NVARCHAR(100) = ''
      ,  @c_TableColumnName NVARCHAR(100) = ''        
      ,  @c_AddColumn       NVARCHAR(255) = ''
      ,  @c_SQL             NVARCHAR(1000)= ''
   
   DECLARE @t_DMF           TABLE ( column_ordinal  INT , Name NVARCHAR(100), DataType NVARCHAR(255) )
   
   SET @c_ColumnNames = ''
   SET @c_TableColumnNames = ''
   
   SET @c_SQL = N'SELECT TOP 0 * FROM dbo.'+ @c_OrginalTableName + ' (NOLOCK)'
   
   INSERT INTO @t_DMF (column_ordinal, [Name], DataType)
   SELECT column_ordinal, [name] , system_type_name 
   FROM     sys.dm_exec_describe_first_result_set(@c_SQL, NULL, 0)
   ORDER BY column_ordinal;      
         
   WHILE 1 = 1
   BEGIN
      SET @c_AddColumn  = ''
      SET @c_ColumnName = ''
      SET @c_TableColumnName = ''
      SELECT TOP 1 @n_column_ordinal = td.column_ordinal
               , @c_TableColumnName = @c_OrginalTableName + '.' + td.[Name]
               , @c_ColumnName = td.[Name]            
               , @c_AddColumn = td.[Name] + N' ' 
                              + td.DataType + N' '
                              + CASE WHEN td.DataType = 'timestamp' THEN '' ELSE ' NULL ' END + N','
      FROM @t_DMF AS td
      WHERE td.column_ordinal > @n_column_ordinal
      ORDER BY td.column_ordinal
      
      IF @@ROWCOUNT = 0
      BEGIN
         BREAK
      END
      
      SET @c_AddColumn = SUBSTRING(@c_AddColumn, 1, LEN(@c_AddColumn) - 1) 
      SET @c_SQL = N'ALTER TABLE ' + @c_TempTableName + ' ADD ' + @c_AddColumn
      
      EXEC sp_ExecuteSQL @c_SQL
      
      IF @c_ColumnName <> '' SET @c_ColumnNames = @c_ColumnNames + @c_ColumnName + ','
      IF @c_TableColumnName <> '' SET @c_TableColumnNames = @c_TableColumnNames + @c_TableColumnName + ','
   END  
   
   IF @c_ColumnNames <> ''      SET @c_ColumnNames =  SUBSTRING(@c_ColumnNames, 1, LEN(@c_ColumnNames) - 1) 
   IF @c_TableColumnNames <> '' SET @c_TableColumnNames =  SUBSTRING(@c_TableColumnNames, 1, LEN(@c_TableColumnNames) - 1) 
QUIT_SP:

END -- procedure

GO