SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: fnc_BuildVariableString                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-05-21 1.0  SHONG      Generic Function to Build Dynamic String  */
/* 2020-06-15 1.1  SHONG      Base on Variable type @n = Numeric        */
/************************************************************************/
CREATE FUNCTION [dbo].[fnc_BuildVariableString] (
   @c_VariableValue NVARCHAR(200),
   @c_VariableName  NVARCHAR(200),    
   @c_InString      NVARCHAR(1000)
)  
RETURNS NVARCHAR(1000) AS  
BEGIN 
   DECLARE @c_OutString NVARCHAR(1000)
   
   IF ( ISNULL(RTRIM(@c_VariableValue),'') <> '' AND LEFT(@c_VariableName, 2) = '@c'  ) OR 
      ( ISNULL(RTRIM(@c_VariableValue),'') <> '' AND ISNULL(RTRIM(@c_VariableValue),'0') <> '0' AND LEFT(@c_VariableName, 2) = '@n'  )
   BEGIN
      IF ISNULL(RTRIM(@c_InString),'') = ''
      BEGIN
         SET @c_OutString = @c_VariableName
      END         
      ELSE 
      BEGIN
         SET @c_OutString = RTRIM(@c_InString) + ', ' + @c_VariableName
      END
   END  
   ELSE 
      SET @c_OutString = RTRIM(@c_InString)                   
   
   RETURN @c_OutString
END

GO