SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  CREATE PROC [dbo].[ispDBGetKey]  
   @c_DBName        NVARCHAR(20),  
   @c_KeyName       NVARCHAR(18),  
   @n_FieldLength   int,  
   @c_KeyString     NVARCHAR(25) OUTPUT,  
   @b_Success       int OUTPUT  
AS  
BEGIN  
   DECLARE @c_SQLStatement nvarchar(1024),  
           @b_debug        int,  
           @n_err          int,  
           @c_errmsg       NVARCHAR(512)  
  
   SELECT @b_Success = 1, @b_debug = 0  
  
   IF RTRIM(@c_KeyName) IS NULL OR RTRIM(@c_KeyName) = ''   
   BEGIN  
      SELECT @b_Success = 0  
      RETURN  
   END  
  
   IF @b_Success = 1  
   BEGIN  
      SELECT @c_SQLStatement = N'EXECUTE ' +  RTRIM(@c_DBName) + '..nspg_getkey N"' + @c_KeyName + '"'  
                                + ', ' + RTRIM(CAST(@n_FieldLength as NVARCHAR(3))) + ', @c_KeyString OUTPUT '  
                                + ', @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT '  
  
      IF @b_debug = 1  
      BEGIN  
         SELECT @c_SQLStatement  
      END  
  
      EXEC sp_executesql @c_SQLStatement, N'@c_KeyString NVARCHAR(10) OUTPUT, @b_success int OUTPUT, @n_err int OUTPUT, @c_errmsg NVARCHAR(255) OUTPUT '  
            , @c_KeyString output,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT  
  
        
        
      IF @b_debug = 1  
      BEGIN  
         select @c_KeyString  
      END  
     
      IF RTRIM(@c_KeyString) IS NULL OR RTRIM(@c_KeyString) = ''  
         SELECT @b_Success = 0  
  
   END  
END -- procedure  
  
  

GO