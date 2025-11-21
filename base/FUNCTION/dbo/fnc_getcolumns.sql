SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE FUNCTION dbo.fnc_GetColumns
(
   @c_Schema    NVARCHAR(20), 
   @c_Prefix    NVARCHAR(40),
	 @c_TableName NVARCHAR(40)
)
RETURNS NVARCHAR(max)
AS
BEGIN
   DECLARE  @n_Err       int,
            @c_ErrMsg    NVARCHAR(215)

   DECLARE @b_CursorOpen   int
          ,@c_ColumnName   nvarchar(128)
          ,@n_ColLength    int
          ,@c_DataType     nvarchar(128)
          ,@n_Continue     int
          ,@n_Cnt          int
          ,@c_ReturnString NVARCHAR(max)

   SET @n_Continue = 1
   SET @c_ReturnString = ''
   SET @b_CursorOpen = 0
   DECLARE CUR_TABLE_COLUMNS CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT SysCol.Column_Name,
          SysCol.Character_Maximum_Length, 
          SysCol.Data_Type
   FROM  INFORMATION_SCHEMA.COLUMNS SysCol 
   WHERE SysCol.Table_Schema = @c_Schema 
   AND   SysCol.Table_Name   = @c_TableName
   ORDER By SysCol.Ordinal_Position

   OPEN CUR_TABLE_COLUMNS
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN  
      SET @n_Continue = 3
      RETURN ''
   END   
   ELSE
      SELECT @b_CursorOpen = 1

   FETCH NEXT FROM CUR_TABLE_COLUMNS INTO @c_ColumnName, @n_ColLength, @c_DataType
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @c_DataType <> 'timestamp' 
      BEGIN 
         IF LEN(@c_ReturnString) = 0 
            SET @c_ReturnString = @c_Prefix + '.' + @c_ColumnName
         ELSE
            SET @c_ReturnString = @c_ReturnString + ', ' + @c_Prefix + '.' + @c_ColumnName
      END

      FETCH NEXT FROM CUR_TABLE_COLUMNS INTO @c_ColumnName, @n_ColLength, @c_DataType
   END
   CLOSE CUR_TABLE_COLUMNS
   DEALLOCATE CUR_TABLE_COLUMNS

   RETURN @c_ReturnString
END

GO