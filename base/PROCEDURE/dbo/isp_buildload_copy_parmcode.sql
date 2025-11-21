SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[isp_BuildLoad_Copy_ParmCode] 
 @c_StorerKey    NVARCHAR(15),
 @c_ParmGroup    NVARCHAR(10), 
 @c_FromParmCode NVARCHAR(20),
 @c_ToParmCode   NVARCHAR(20), 
 @c_ToParmDesc   NVARCHAR(250), 
 @b_Success      BIT = 1  OUTPUT, 
 @n_Err          INT = 0  OUTPUT,
 @c_ErrMsg       NVARCHAR(250) = '' OUTPUT 
AS
BEGIN
	DECLARE @n_continue INT = 1
	
	IF NOT EXISTS (SELECT 1 FROM StorerConfig AS sc WITH(NOLOCK)
	               WHERE sc.StorerKey = @c_StorerKey 
	                 AND sc.ConfigKey = 'BuildLoadParm'
	                 AND sc.SValue = @c_ParmGroup)
	BEGIN
      SELECT @n_continue = 3 
      SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=500038 
      SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+':Parameter Group not found in Storer Config Table (isp_BuildLoad_Copy_ParmCode)'
      GOTO EXIT_SP  		
	END
	
   IF NOT EXISTS (SELECT 1 FROM CODELIST AS c WITH(NOLOCK)
                  WHERE c.LISTNAME = @c_FromParmCode)
   BEGIN
      SELECT @n_continue = 3 
      SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=500036 
      SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+':Invalid Paramater Code (isp_BuildLoad_Copy_ParmCode)' 
   	GOTO EXIT_SP
   END	
   IF EXISTS (SELECT 1 FROM CODELIST AS c WITH(NOLOCK)
                  WHERE c.LISTNAME = @c_ToParmCode)
   BEGIN
      SELECT @n_continue = 3 
      SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=500037 
      SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+':Paramater Code already Exists (isp_BuildLoad_Copy_ParmCode)' 
   	GOTO EXIT_SP
   END	
   
   IF @n_continue IN (1,2)
   BEGIN
   	INSERT INTO CODELIST
   	(
   		LISTNAME,   	[DESCRIPTION], ListGroup,
   		UDF01,   		UDF02,   		UDF03,
   		UDF04,   		UDF05,   		[TYPE]
   	)
   	SELECT 
   		@c_ToParmCode, @c_ToParmDesc, ListGroup,
   		UDF01,   		UDF02,   		UDF03,
   		UDF04,   		UDF05,   		[TYPE]
   	FROM CODELIST AS c WITH(NOLOCK)
      WHERE c.LISTNAME = @c_FromParmCode 	
      
      
      INSERT INTO CODELKUP
      (
      	LISTNAME,      Code,      	[Description],
      	Short,      	Long,      	Notes,
      	Notes2,      	Storerkey,  UDF01,
      	UDF02,      	UDF03,      UDF04,
      	UDF05,      	code2
      )
      SELECT 
      	@c_ToParmCode, Code,      	[Description],
      	Short,      	Long,      	Notes,
      	Notes2,      	Storerkey,  UDF01,
      	UDF02,      	UDF03,      UDF04,
      	UDF05,      	code2
      FROM CODELKUP AS c WITH(NOLOCK) 
      WHERE c.LISTNAME = @c_FromParmCode       
   END
   
   EXIT_SP:
END

GO