SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_GetDataType                                             */
/* Creation Date: 28-MAR-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  StockTakeSheet Extended Parameters                         */
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
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_GetDataType] 
      @c_TableName   NVARCHAR(20)
   ,  @c_FieldName   NVARCHAR(60)
   ,  @c_DB_DataType NVARCHAR(20)   OUTPUT
   ,  @c_PB_DataType NVARCHAR(20)   OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_ColumnTable     NVARCHAR(30)
         , @c_ColumnName      NVARCHAR(30)

         , @n_DotPOS          INT

   SET @c_DB_DataType = ''
   SET @c_PB_DataType = ''
   SET @n_DotPOS = 0

   SET @n_DotPOS = CHARINDEX('.', @c_FieldName)

   SET @c_ColumnTable = ''
   IF @n_DotPOS > 0 
   BEGIN 
      SET @c_ColumnTable  = SUBSTRING(@c_FieldName, 1, @n_DotPOS - 1) 
      SET @c_ColumnName = SUBSTRING(@c_FieldName, @n_DotPOS + 1, LEN(@c_FieldName) - @n_DotPOS)
 
   END
   ELSE
   BEGIN
      SET @c_ColumnName = @c_FieldName
   END
 
   IF ISNULL(RTRIM(@c_TableName),'') <> @c_ColumnTable AND @c_ColumnTable <> ''
   BEGIN
      SET @c_TableName = @c_ColumnTable
   END 

   IF ISNULL(RTRIM(@c_TableName),'') = ''
   BEGIN
      GOTO QUIT
   END
 
   SELECT @c_DB_DataType = DATA_TYPE 
   FROM [INFORMATION_SCHEMA].COLUMNS
   WHERE TABLE_NAME = @c_TableName
   AND COLUMN_NAME = @c_ColumnName

   SET @c_PB_DataType = CASE WHEN @c_DB_DataType IN ('char', 'nchar', 'varchar', 'nvarchar')
                             THEN 'STRING'
                             WHEN @c_DB_DataType = 'date'
                             THEN 'DATE'
                             WHEN @c_DB_DataType = 'datetime'
                             THEN 'DATETIME'
                             WHEN @c_DB_DataType IN ('real', 'float', 'numeric', 'int', 'bigint')
                             THEN 'NUMBER'
                             ELSE ''
                        END  
   
QUIT:
END -- procedure

GO